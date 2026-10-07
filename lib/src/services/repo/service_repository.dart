import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ServiceItem — typed model for one bookable entry.
// id is always > 0 (we generate a stable hash when the API has no integer id).
// ─────────────────────────────────────────────────────────────────────────────
class ServiceItem {
  final int id;
  final bool isPackage;
  final bool isAddOn;
  final String name;
  final String description;
  final double price;
  final String priceDisplay;
  final int durationMinutes;   // 0 when "Not Applicable"
  final String? imageUrl;

  const ServiceItem({
    required this.id,
    required this.isPackage,
    required this.isAddOn,
    required this.name,
    required this.description,
    required this.price,
    required this.priceDisplay,
    required this.durationMinutes,
    this.imageUrl,
  });

  // Legacy map used by home_page, services_page, review_page, etc.
  Map<String, dynamic> toMap() => {
    Constants.database.COLUMN_ID          : id,
    'serviceId'                           : isPackage ? null : id,
    'packageId'                           : isPackage ? id   : null,
    'addOnId'                             : isAddOn   ? id   : null,
    'id'                                  : id,
    'isPackage'                           : isPackage,
    'isAddOn'                             : isAddOn,
    Constants.database.COLUMN_SERVICE_NAME: name,
    'service_name'                        : name,
    Constants.database.COLUMN_PACKAGE_NAME: isPackage ? name : null,
    Constants.database.COLUMN_DESCRIPTION : description,
    Constants.database.COLUMN_PRICE       : price,
    'price'                               : priceDisplay,
    'duration'     : durationMinutes > 0 ? '$durationMinutes min' : '',
    'durationMinutes': durationMinutes,
    'imageUrl'     : imageUrl,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// BookingServicesResult
// ─────────────────────────────────────────────────────────────────────────────
class BookingServicesResult {
  final List<ServiceItem> breeds;
  final List<ServiceItem> packages;
  final List<ServiceItem> addOns;
  final List<ServiceItem> walkIn;

  const BookingServicesResult({
    required this.breeds,
    required this.packages,
    required this.addOns,
    required this.walkIn,
  });

  bool get isEmpty =>
      breeds.isEmpty && packages.isEmpty && addOns.isEmpty && walkIn.isEmpty;

  List<Map<String, dynamic>> get allServicesAsMap =>
      [...breeds, ...addOns, ...walkIn].map((s) => s.toMap()).toList();

  List<Map<String, dynamic>> get allPackagesAsMap =>
      packages.map((p) => p.toMap()).toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// ServiceRepository
// ─────────────────────────────────────────────────────────────────────────────
class ServiceRepository {
  final Logger log = Logger();

  Future<void> initialize() async {
    log.d('ServiceRepository::initialize::Initialized');
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  static double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num)  return v.toDouble();
    final s = v.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(s) ?? 0.0;
  }

  /// Returns a display-ready price string, e.g. "$45" or "$18.00 & up".
  static String _priceDisplay(dynamic rawPrice, dynamic suffix) {
    if (rawPrice == null) return '';
    final s = rawPrice.toString().trim();
    if (s.isEmpty || s == '0' || s == '0.0') return '';
    final leading = s.startsWith(r'$') ? s : '\$$s';
    final sfx = (suffix?.toString().trim() ?? '');
    return sfx.isNotEmpty ? '$leading$sfx' : leading;
  }

  /// Returns imageUrl from the map (checks several casing variants).
  static String? _imageUrl(Map<dynamic, dynamic> m) {
    final v = m['imageUrl'] ?? m['ImageUrl'] ?? m['image_url'] ??
              m['ImageURL'] ?? m['image'];
    final s = v?.toString().trim();
    return (s != null && s.isNotEmpty) ? s : null;
  }

  /// Parses `TimeinMinutes`; returns 0 for "Not Applicable" or missing.
  static int _parseDuration(dynamic v) {
    if (v == null) return 0;
    final s = v.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'not applicable') return 0;
    final n = int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), ''));
    return (n != null && n > 0) ? n : 0;
  }

  // ── main fetch ────────────────────────────────────────────────────────────

  Future<BookingServicesResult> getBookingServices() async {
    log.d('ServiceRepository::getBookingServices::GET /api/service-packages');

    final response =
        await ServicesLocator.apiRepository.get('/api/service-packages');
    if (response == null || !response.containsKey('data')) {
      throw Exception('Failed to fetch services: empty response');
    }

    final data = response['data'] as Map<String, dynamic>;
    log.d('ServiceRepository::getBookingServices::keys=${data.keys.toList()}');

    // ── Breeds ────────────────────────────────────────────────────────────
    // Backend catalog: services 1–9
    //   Each breed type has up to 3 sub-services (Grooming, Bathing,
    //   GroomingAndBathing). The backend assigns them sequential integer IDs
    //   starting at 1 in the order they appear in the catalog.
    //   The /api/service-packages response does NOT include these integers —
    //   we must assign them by position (1-based across all sub-services).
    final breeds = <ServiceItem>[];
    int breedServiceCounter = 1; // starts at 1 per Postman catalog description
    if (data['Breeds'] is List) {
      for (final b in data['Breeds'] as List) {
        if (b is! Map) continue;
        final breedName = b['BreedType']?.toString() ?? 'Unknown Breed';
        final breedImg  = _imageUrl(b);

        void addBreedSvc(
            String subType, Map<dynamic, dynamic> m, int catalogId) {
          final price = _parseDouble(m['Price'] ?? m['price']);
          final dur   = _parseDuration(m['TimeinMinutes'] ?? m['timeInMinutes']);
          breeds.add(ServiceItem(
            id             : catalogId,
            isPackage      : false,
            isAddOn        : false,
            name           : '$breedName — $subType',
            description    : '$subType for $breedName',
            price          : price,
            priceDisplay   : _priceDisplay(m['Price'] ?? m['price'], null),
            durationMinutes: dur,
            imageUrl       : _imageUrl(m) ?? breedImg,
          ));
        }

        if (b['Grooming'] is Map) {
          addBreedSvc('Grooming', b['Grooming'], breedServiceCounter++);
        }
        if (b['Bathing'] is Map) {
          addBreedSvc('Bathing', b['Bathing'], breedServiceCounter++);
        }
        if (b['GroomingAndBathing'] is Map) {
          addBreedSvc('Grooming & Bathing', b['GroomingAndBathing'],
              breedServiceCounter++);
        }
      }
    }

    // ── Walk-In Services ─────────────────────────────────────────────────
    // Backend catalog: services 10–13 (immediately after breeds)
    // The counter continues from breedServiceCounter so Walk-In IDs start
    // at breedServiceCounter (which should be 10 for the standard 9-breed-svc
    // catalog). This matches the Postman description exactly.
    final walkIn = <ServiceItem>[];
    int walkInCounter = breedServiceCounter; // e.g. 10 after 9 breed services
    final rawWalkin = data['Walk In Services'] ??
                      data['WalkInServices']  ??
                      data['walkInServices']  ??
                      data['walkin'];
    if (rawWalkin is List) {
      for (final w in rawWalkin) {
        if (w is! Map) continue;
        final name  = (w['Name'] ?? w['name'] ?? 'Walk-In Service').toString().trim();
        final price = _parseDouble(w['Price'] ?? w['price']);
        final dur   = _parseDuration(w['TimeinMinutes'] ?? w['timeInMinutes']);
        final desc  = (w['Description'] ?? w['description'] ?? '').toString().trim();
        walkIn.add(ServiceItem(
          id             : walkInCounter++,
          isPackage      : false,
          isAddOn        : false,
          name           : name,
          description    : desc,
          price          : price,
          priceDisplay   : _priceDisplay(w['Price'] ?? w['price'], null),
          durationMinutes: dur,
          imageUrl       : _imageUrl(w),
        ));
      }
    }

    // ── Packages ─────────────────────────────────────────────────────────
    // Backend catalog: packages 1–3 (independent sequence from services)
    final packages = <ServiceItem>[];
    int pkgCounter = 1;
    if (data['Packages'] is List) {
      for (final p in data['Packages'] as List) {
        if (p is! Map) continue;
        final currentPkgId = pkgCounter++;

        String name = (p['PackageName'] ?? p['packageName'] ?? p['name'] ?? '')
                          .toString().trim();
        // If name looks like a code (e.g. "P0003") or is empty, generate one
        if (name.isEmpty || RegExp(r'^[A-Z]\d+$').hasMatch(name)) {
          name = 'Package $currentPkgId';
        }

        final price = _parseDouble(p['Price'] ?? p['price']);
        final dur   = _parseDuration(p['TimeinMinutes'] ?? p['timeInMinutes']);
        final includes = (p['Includes'] is List)
            ? (p['Includes'] as List)
                .map((e) => e?.toString().trim() ?? '')
                .where((s) => s.isNotEmpty)
                .toList()
            : <String>[];
        final desc = includes.isNotEmpty ? includes.join(', ') : 'Package service';

        packages.add(ServiceItem(
          id             : currentPkgId,
          isPackage      : true,
          isAddOn        : false,
          name           : name,
          description    : desc,
          price          : price,
          priceDisplay   : _priceDisplay(p['Price'] ?? p['price'], null),
          durationMinutes: dur,
          imageUrl       : _imageUrl(p),
        ));
      }
    }

    // ── Add-Ons ──────────────────────────────────────────────────────────
    // Backend catalog: add-ons 1–12 (independent sequence)
    final addOns = <ServiceItem>[];
    int addonCounter = 1;
    if (data['AddOns'] is List) {
      for (final a in data['AddOns'] as List) {
        if (a is! Map) continue;
        final currentAddonId = addonCounter++;
        final name   = (a['Name'] ?? a['name'] ?? 'Add-on').toString().trim();
        final price  = _parseDouble(a['Price'] ?? a['price']);
        final suffix = a['Sufix'] ?? a['suffix'];
        final dur    = _parseDuration(a['TimeinMinutes'] ?? a['timeInMinutes']);
        final includes = (a['Includes'] is List)
            ? (a['Includes'] as List)
                .map((e) => e?.toString().trim() ?? '')
                .where((s) => s.isNotEmpty)
                .toList()
            : <String>[];
        final desc = includes.isNotEmpty ? includes.join(', ') : '';

        addOns.add(ServiceItem(
          id             : currentAddonId,
          isPackage      : false,
          isAddOn        : true,
          name           : name,
          description    : desc,
          price          : price,
          priceDisplay   : _priceDisplay(a['Price'] ?? a['price'], suffix),
          durationMinutes: dur,
          imageUrl       : _imageUrl(a),
        ));
      }
    }

    log.d('ServiceRepository::getBookingServices::Result'
        ' breeds=${breeds.length}(ids 1–${breeds.isEmpty ? 0 : breeds.last.id})'
        ' walkIn=${walkIn.length}(ids ${breeds.isEmpty ? 1 : breeds.last.id + 1}–${walkIn.isEmpty ? 0 : walkIn.last.id})'
        ' packages=${packages.length}(ids 1–${packages.isEmpty ? 0 : packages.last.id})'
        ' addOns=${addOns.length}(ids 1–${addOns.isEmpty ? 0 : addOns.last.id})');

    return BookingServicesResult(
      breeds  : breeds,
      packages: packages,
      addOns  : addOns,
      walkIn  : walkIn,
    );
  }

  // ── Legacy surface ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllServices() async {
    final result = await getBookingServices();
    return result.allServicesAsMap;
  }

  Future<List<Map<String, dynamic>>> getAllPackages() async {
    final result = await getBookingServices();
    return result.allPackagesAsMap;
  }

  Future<Map<String, dynamic>?> getServiceById(int id) async {
    final result = await getBookingServices();
    final all = [
      ...result.breeds, ...result.packages,
      ...result.addOns, ...result.walkIn,
    ];
    for (final s in all) {
      if (s.id == id) return s.toMap();
    }
    return null;
  }
}
