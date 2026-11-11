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
  final List<String> includes;
  final String? code;

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
    this.includes = const [],
    this.code,
  });

  // Legacy map used by home_page, services_page, review_page, etc.
  Map<String, dynamic> toMap() => {
    Constants.database.COLUMN_ID          : id,
    'serviceId'                           : (isPackage || isAddOn) ? null : id,
    'packageId'                           : isPackage ? id   : null,
    'packageMasterId'                     : isPackage ? id   : null,
    'serviceMasterId'                     : (!isPackage && !isAddOn) ? id : null,
    'package_id'                          : isPackage ? (code ?? id.toString()) : null,
    'addOnId'                             : isAddOn   ? id   : null,
    'id'                                  : id,
    'isPackage'                           : isPackage,
    'isAddOn'                             : isAddOn,
    'name'                                : name,
    Constants.database.COLUMN_SERVICE_NAME: name,
    'service_name'                        : name,
    Constants.database.COLUMN_PACKAGE_NAME: isPackage ? name : null,
    'package_name'                        : isPackage ? name : null,
    Constants.database.COLUMN_DESCRIPTION : description,
    'description'                         : description,
    Constants.database.COLUMN_PRICE       : price,
    'price'                               : price,
    'priceDisplay'                        : priceDisplay,
    'duration'     : durationMinutes > 0 ? '$durationMinutes min' : '',
    Constants.database.COLUMN_DURATION_MIN: durationMinutes,
    'durationMinutes': durationMinutes,
    'duration_min': durationMinutes,
    'imageUrl'     : imageUrl,
    'image_url'    : imageUrl,
    'includes'     : includes,
    'code'         : code,
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

  bool get isNotEmpty => !isEmpty;

  List<Map<String, dynamic>> get allServicesAsMap =>
      [...breeds, ...addOns, ...walkIn].map((s) => s.toMap()).toList();

  List<Map<String, dynamic>> get allPackagesAsMap =>
      packages.map((p) => p.toMap()).toList();

  factory BookingServicesResult.fallback() {
    return const BookingServicesResult(
      breeds: [
        ServiceItem(
          id: 1,
          isPackage: false,
          isAddOn: false,
          name: 'Small Dog (Under 20 lbs) — Grooming',
          description: 'Full grooming for small breeds under 20 lbs.',
          price: 55.0,
          priceDisplay: r'$55 & up',
          durationMinutes: 60,
          imageUrl: 'assets/images/common/svc_full_grooming.png',
        ),
        ServiceItem(
          id: 2,
          isPackage: false,
          isAddOn: false,
          name: 'Small Dog (Under 20 lbs) — Bathing',
          description: 'Deep cleansing bath for small breeds.',
          price: 35.0,
          priceDisplay: r'$35 & up',
          durationMinutes: 30,
          imageUrl: 'assets/images/common/svc_bath_blowdry.png',
        ),
        ServiceItem(
          id: 3,
          isPackage: false,
          isAddOn: false,
          name: 'Small Dog (Under 20 lbs) — Grooming & Bathing',
          description: 'Complete bath and grooming package for small breeds.',
          price: 65.0,
          priceDisplay: r'$65 & up',
          durationMinutes: 75,
          imageUrl: 'assets/images/common/svc_spa.png',
        ),
        ServiceItem(
          id: 4,
          isPackage: false,
          isAddOn: false,
          name: 'Medium Dog (21 - 50 lbs) — Grooming',
          description: 'Full grooming for medium dog breeds.',
          price: 68.0,
          priceDisplay: r'$68 & up',
          durationMinutes: 75,
          imageUrl: 'assets/images/common/svc_full_grooming.png',
        ),
        ServiceItem(
          id: 5,
          isPackage: false,
          isAddOn: false,
          name: 'Medium Dog (21 - 50 lbs) — Bathing',
          description: 'Refreshing bath for medium dog breeds.',
          price: 45.0,
          priceDisplay: r'$45 & up',
          durationMinutes: 45,
          imageUrl: 'assets/images/common/svc_bath_blowdry.png',
        ),
        ServiceItem(
          id: 6,
          isPackage: false,
          isAddOn: false,
          name: 'Medium Dog (21 - 50 lbs) — Grooming & Bathing',
          description: 'Complete bath and groom for medium dog breeds.',
          price: 80.0,
          priceDisplay: r'$80 & up',
          durationMinutes: 90,
          imageUrl: 'assets/images/common/svc_spa.png',
        ),
        ServiceItem(
          id: 7,
          isPackage: false,
          isAddOn: false,
          name: 'Large Dog (51 - 80 lbs) — Grooming',
          description: 'Full grooming for large dog breeds.',
          price: 85.0,
          priceDisplay: r'$85 & up',
          durationMinutes: 90,
          imageUrl: 'assets/images/common/svc_full_grooming.png',
        ),
        ServiceItem(
          id: 8,
          isPackage: false,
          isAddOn: false,
          name: 'Large Dog (51 - 80 lbs) — Bathing',
          description: 'Thorough cleansing bath for large dog breeds.',
          price: 55.0,
          priceDisplay: r'$55 & up',
          durationMinutes: 60,
          imageUrl: 'assets/images/common/svc_bath_blowdry.png',
        ),
        ServiceItem(
          id: 9,
          isPackage: false,
          isAddOn: false,
          name: 'Large Dog (51 - 80 lbs) — Grooming & Bathing',
          description: 'Complete grooming and bath experience for large breeds.',
          price: 100.0,
          priceDisplay: r'$100 & up',
          durationMinutes: 105,
          imageUrl: 'assets/images/common/svc_spa.png',
        ),
      ],
      walkIn: [
        ServiceItem(
          id: 10,
          isPackage: false,
          isAddOn: false,
          name: 'Full Grooming',
          description:
              'Complete pet grooming including bath, blow dry, brushing, haircut, styling, nail clipping, and ear cleaning.',
          price: 68.0,
          priceDisplay: r'$68 & up',
          durationMinutes: 75,
          imageUrl: 'assets/images/common/svc_full_grooming.png',
        ),
        ServiceItem(
          id: 11,
          isPackage: false,
          isAddOn: false,
          name: 'Bath & Blow Dry',
          description:
              'Deep cleansing bath with premium pet shampoo followed by blow dry and brush-out.',
          price: 40.0,
          priceDisplay: r'$40 & up',
          durationMinutes: 45,
          imageUrl: 'assets/images/common/svc_bath_blowdry.png',
        ),
        ServiceItem(
          id: 12,
          isPackage: false,
          isAddOn: false,
          name: 'Hair Trimming',
          description:
              'Neat and manageable coat trimming customized to your preference or breed style.',
          price: 30.0,
          priceDisplay: r'$30 & up',
          durationMinutes: 30,
          imageUrl: 'assets/images/common/svc_hair_trim.png',
        ),
        ServiceItem(
          id: 13,
          isPackage: false,
          isAddOn: false,
          name: 'Breed Styling',
          description:
              'Precision coat shaping according to traditional breed standards or custom styles.',
          price: 55.0,
          priceDisplay: r'$55 & up',
          durationMinutes: 60,
          imageUrl: 'assets/images/common/svc_breed_style.png',
        ),
        ServiceItem(
          id: 14,
          isPackage: false,
          isAddOn: false,
          name: 'Nail Trimming',
          description:
              'Carefully trimmed and smoothed nails to improve posture, mobility, and comfort.',
          price: 15.0,
          priceDisplay: r'$15',
          durationMinutes: 15,
          imageUrl: 'assets/images/common/svc_nail_trim.png',
        ),
        ServiceItem(
          id: 15,
          isPackage: false,
          isAddOn: false,
          name: 'Ear Cleaning',
          description:
              'Gentle ear cleaning to remove wax and debris while supporting healthy ears.',
          price: 12.0,
          priceDisplay: r'$12',
          durationMinutes: 10,
          imageUrl: 'assets/images/common/svc_ear_clean.png',
        ),
        ServiceItem(
          id: 16,
          isPackage: false,
          isAddOn: false,
          name: 'Teeth Brushing',
          description:
              'Oral hygiene care with pet-safe enzymatic toothpaste for fresh breath and cleaner teeth.',
          price: 14.0,
          priceDisplay: r'$14',
          durationMinutes: 10,
          imageUrl: 'assets/images/common/svc_teeth_brush.png',
        ),
        ServiceItem(
          id: 17,
          isPackage: false,
          isAddOn: false,
          name: 'Flea & Tick Treatment',
          description:
              'Specialized cleansing flea bath to cleanse the coat and keep your dog comfortable.',
          price: 25.0,
          priceDisplay: r'$25 & up',
          durationMinutes: 30,
          imageUrl: 'assets/images/common/svc_flea_tick.png',
        ),
        ServiceItem(
          id: 18,
          isPackage: false,
          isAddOn: false,
          name: 'Puppy Grooming',
          description:
              'Gentle introduction to grooming in a calm setting with light bath, brush, and trim.',
          price: 35.0,
          priceDisplay: r'$35 & up',
          durationMinutes: 45,
          imageUrl: 'assets/images/common/svc_puppy.png',
        ),
        ServiceItem(
          id: 19,
          isPackage: false,
          isAddOn: false,
          name: 'De-Shedding Treatment',
          description:
              'Undercoat removal process that minimizes shedding and keeps the coat healthy.',
          price: 28.0,
          priceDisplay: r'$28 & up',
          durationMinutes: 30,
          imageUrl: 'assets/images/common/svc_deshed.png',
        ),
        ServiceItem(
          id: 20,
          isPackage: false,
          isAddOn: false,
          name: 'Skin Care Treatment',
          description:
              'Nourishing shampoos and conditioners formulated to soothe dry skin and revitalize the coat.',
          price: 22.0,
          priceDisplay: r'$22 & up',
          durationMinutes: 20,
          imageUrl: 'assets/images/common/svc_skin_care.png',
        ),
      ],
      packages: [
        ServiceItem(
          id: 1,
          isPackage: true,
          isAddOn: false,
          name: 'Spa Package',
          description:
              'Full Service Pet Grooming, coat conditioning, nail clipping, ear cleaning, and finishing treatments.',
          price: 85.0,
          priceDisplay: r'$85 & up',
          durationMinutes: 90,
          imageUrl: 'assets/images/common/svc_spa.png',
        ),
        ServiceItem(
          id: 2,
          isPackage: true,
          isAddOn: false,
          name: 'Bath & Tidy Package',
          description:
              'Bath, blow dry, nail clipping, ear cleaning, and light sanitary trimming.',
          price: 50.0,
          priceDisplay: r'$50 & up',
          durationMinutes: 45,
          imageUrl: 'assets/images/common/svc_bath_blowdry.png',
        ),
        ServiceItem(
          id: 3,
          isPackage: true,
          isAddOn: false,
          name: 'Deluxe Puppy Spa',
          description:
              'Gentle puppy bath, brush out, nail trim, ear cleaning, and positive intro styling.',
          price: 45.0,
          priceDisplay: r'$45 & up',
          durationMinutes: 45,
          imageUrl: 'assets/images/common/svc_puppy.png',
        ),
      ],
      addOns: [
        ServiceItem(
          id: 1,
          code: 'A0001',
          isPackage: false,
          isAddOn: true,
          name: 'Nail Grinding',
          description:
              'Smooth round finish on nails using a professional rotary tool.',
          price: 18.0,
          priceDisplay: r'$18 & up',
          durationMinutes: 60,
          imageUrl: 'assets/images/common/svc_nail_trim.png',
        ),
        ServiceItem(
          id: 2,
          code: 'A0002',
          isPackage: false,
          isAddOn: true,
          name: 'Teeth Brushing',
          description:
              'Oral hygiene care with pet-safe enzymatic toothpaste for fresh breath and cleaner teeth.',
          price: 16.0,
          priceDisplay: r'$16 & up',
          durationMinutes: 60,
          imageUrl: 'assets/images/common/svc_teeth_brush.png',
        ),
        ServiceItem(
          id: 3,
          code: 'A0003',
          isPackage: false,
          isAddOn: true,
          name: 'Blueberry Facial',
          description:
              'Tearless, aromatic face cleanser that removes tear stains and dirt.',
          price: 12.0,
          priceDisplay: r'$12 & up',
          durationMinutes: 60,
          imageUrl: 'assets/images/common/svc_skin_care.png',
        ),
        ServiceItem(
          id: 4,
          code: 'A0004',
          isPackage: false,
          isAddOn: true,
          name: 'Flea Bath',
          description:
              'Specialized cleansing flea bath to cleanse the coat and keep your dog comfortable.',
          price: 14.0,
          priceDisplay: r'$14 & up',
          durationMinutes: 60,
          imageUrl: 'assets/images/common/svc_flea_tick.png',
        ),
        ServiceItem(
          id: 5,
          code: 'A0005',
          isPackage: false,
          isAddOn: true,
          name: 'Furminator',
          description:
              'Deep undercoat removal treatment that drastically reduces excess seasonal shedding.',
          price: 25.0,
          priceDisplay: r'$25 & up',
          durationMinutes: 60,
          imageUrl: 'assets/images/common/svc_deshed.png',
        ),
        ServiceItem(
          id: 6,
          code: 'A0006',
          isPackage: false,
          isAddOn: true,
          name: 'Dental Package',
          description:
              'Comprehensive oral care including teeth brushing, dental spray, and treat.',
          price: 20.0,
          priceDisplay: r'$20 & up',
          durationMinutes: 60,
          imageUrl: 'assets/images/common/svc_teeth_brush.png',
        ),
        ServiceItem(
          id: 7,
          code: 'A0007',
          isPackage: false,
          isAddOn: true,
          name: 'Medicated Bath',
          description:
              'Therapeutic bath treatment for sensitive or irritated skin.',
          price: 18.0,
          priceDisplay: r'$18',
          durationMinutes: 60,
          imageUrl: 'assets/images/common/svc_bath_blowdry.png',
        ),
        ServiceItem(
          id: 8,
          code: 'A0008',
          isPackage: false,
          isAddOn: true,
          name: 'De-Odorize',
          description:
              'Deep odor-eliminating shampoo treatment keeping pets smelling fresh for days.',
          price: 18.0,
          priceDisplay: r'$18',
          durationMinutes: 60,
          imageUrl: 'assets/images/common/svc_spa.png',
        ),
        ServiceItem(
          id: 9,
          code: 'A0009',
          isPackage: false,
          isAddOn: true,
          name: 'Brush/Dematt',
          description:
              'Gentle coat detangling and dead fur removal for knot-free, soft fur.',
          price: 10.0,
          priceDisplay: r'$10 (Per 15 min)',
          durationMinutes: 0,
          imageUrl: 'assets/images/common/svc_deshed.png',
        ),
        ServiceItem(
          id: 10,
          code: 'A0010',
          isPackage: false,
          isAddOn: true,
          name: 'Hard To Handle',
          description:
              'Extra care and patience for anxious, energetic, or reactive pets.',
          price: 18.0,
          priceDisplay: r'$18',
          durationMinutes: 60,
          imageUrl: 'assets/images/common/svc_puppy.png',
        ),
        ServiceItem(
          id: 11,
          code: 'A0011',
          isPackage: false,
          isAddOn: true,
          name: 'Express Service',
          description:
              'Expedited one-on-one grooming service without cage drying or waiting.',
          price: 18.0,
          priceDisplay: r'$18 & up',
          durationMinutes: 60,
          imageUrl: 'assets/images/common/svc_spa.png',
        ),
        ServiceItem(
          id: 12,
          code: 'A0012',
          isPackage: false,
          isAddOn: true,
          name: 'Scissoring',
          description:
              'Hand-scissored styling and neatening for breed-standard or customized looks.',
          price: 10.0,
          priceDisplay: r'$10 & up',
          durationMinutes: 60,
          imageUrl: 'assets/images/common/svc_hair_trim.png',
        ),
      ],
    );
  }
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

  static const List<String> _defaultPackageNames = [
    'Spa Package',
    'Bath & Tidy Package',
    'Deluxe Puppy Spa',
  ];

  static const List<String> _defaultPackageDescriptions = [
    'Full Service Pet Grooming, coat conditioning, nail clipping, ear cleaning, and finishing treatments.',
    'Bath, blow dry, nail clipping, ear cleaning, and light sanitary trimming.',
    'Gentle puppy bath, brush out, nail trim, ear cleaning, and positive intro styling.',
  ];

  static const List<List<String>> _defaultPackageIncludes = [
    ['Full Grooming', 'Coat Conditioning', 'Nail Clipping & Ear Cleaning', 'Finishing Spray'],
    ['Bath & Blow Dry', 'Nail Clipping', 'Ear Cleaning', 'Sanitary Trim'],
    ['Gentle Puppy Bath', 'Brush Out', 'Nail Trim', 'Positive Intro Styling'],
  ];

  /// Resolves relative, localhost, or outdated image URLs against the official API base URL or web portal host.
  static String? resolveImageUrl(dynamic rawUrl) {
    if (rawUrl == null) return null;
    final s = rawUrl.toString().trim();
    if (s.isEmpty || s == 'null' || s == 'undefined') return null;

    if (s.startsWith('assets/')) {
      return s;
    }

    final baseUrl = Constants.app.BASE_URL;

    if (s.startsWith('http://') || s.startsWith('https://')) {
      final uri = Uri.tryParse(s);
      if (uri != null) {
        final host = uri.host.toLowerCase();
        // Rewrite localhost / dev host / emulator IP to the configured BASE_URL
        if (host == 'localhost' ||
            host == '127.0.0.1' ||
            host == '10.0.2.2' ||
            host.contains('genzcodershub.com')) {
          final path = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
          final query = uri.hasQuery ? '?${uri.query}' : '';
          return '$baseUrl$path$query';
        }
        // Valid external or API URL
        return s;
      }
      return s;
    }

    // Static web portal assets (e.g. /assets/images/...) live on the web portal host
    if (s.startsWith('/assets/')) {
      return 'https://pcmdev.shearheavenpetspa.com$s';
    }

    // Relative path like /services_img/... or services_img/... or /uploads/...
    final clean = s.startsWith('/') ? s : '/$s';
    return '$baseUrl$clean';
  }

  /// Returns a live network image URL for a service or package by inspecting its API raw image or name.
  static String liveServiceImageUrl(String name, {String? rawUrl, int? id}) {
    if (rawUrl != null && rawUrl.trim().isNotEmpty) {
      final resolved = resolveImageUrl(rawUrl);
      if (resolved != null && resolved.isNotEmpty) return resolved;
    }

    final baseUrl = Constants.app.BASE_URL;
    final clean = name.toLowerCase();
    if (clean.contains('puppy')) {
      return '$baseUrl/services_img/svc_puppy.png';
    } else if (clean.contains('teeth') || clean.contains('breath') || clean.contains('dental')) {
      return '$baseUrl/services_img/svc_teeth_brush.png';
    } else if (clean.contains('nail')) {
      return '$baseUrl/services_img/svc_nail_trim.png';
    } else if (clean.contains('ear')) {
      return '$baseUrl/services_img/svc_ear_clean.png';
    } else if (clean.contains('flea') || clean.contains('tick')) {
      return '$baseUrl/services_img/svc_flea_tick.png';
    } else if (clean.contains('skin') || clean.contains('coat') || clean.contains('allergy') || clean.contains('medic') || clean.contains('facial')) {
      return '$baseUrl/services_img/svc_skin_care.png';
    } else if (clean.contains('deshed') || clean.contains('brush') || clean.contains('dematt') || clean.contains('shed')) {
      return '$baseUrl/services_img/svc_deshed.png';
    } else if (clean.contains('groom') && clean.contains('bath')) {
      return '$baseUrl/services_img/svc_full_grooming.png';
    } else if (clean.contains('hydro') || clean.contains('spa') || clean.contains('4hr') || clean.contains('4-hour')) {
      return '$baseUrl/services_img/svc_spa.png';
    } else if (clean.contains('bath') || clean.contains('wash')) {
      return '$baseUrl/services_img/svc_bath_blowdry.png';
    } else if (clean.contains('anal gland')) {
      return '$baseUrl/services_img/svc_ear_clean.png';
    } else if (clean.contains('trim') || clean.contains('hygiene') || clean.contains('sanitary') || clean.contains('touch-up') || clean.contains('face') || clean.contains('feet')) {
      return '$baseUrl/services_img/svc_hair_trim.png';
    } else if (clean.contains('breed')) {
      return '$baseUrl/services_img/svc_breed_style.png';
    } else if (clean.contains('groom') || clean.contains('cut') || clean.contains('style')) {
      return '$baseUrl/services_img/svc_full_grooming.png';
    }
    return '$baseUrl/services_img/svc_full_grooming.png';
  }

  static double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(s) ?? 0.0;
  }

  /// Returns a display-ready price string, e.g. "$45" or "$18 & up".
  static String _priceDisplay(dynamic rawPrice, dynamic suffix) {
    if (rawPrice == null) return '';
    final s = rawPrice.toString().trim();
    if (s.isEmpty || s == '0' || s == '0.0') return '';
    final leading = s.startsWith(r'$') ? s : '\$$s';
    final sfx = (suffix?.toString().trim() ?? '');
    if (sfx.isEmpty) return leading;
    // Multi-tier size breakdown like "small / $18 medium / $22 large" means price varies by pet size -> "& up"
    if (sfx.contains('/') || sfx.toLowerCase().contains('medium') || sfx.toLowerCase().contains('large')) {
      return '$leading & up';
    }
    return sfx.startsWith(' ') ? '$leading$sfx' : '$leading $sfx';
  }

  /// Returns resolved imageUrl from the map (checks several casing variants).
  static String? _imageUrl(Map<dynamic, dynamic> m) {
    final v = m['imageUrl'] ??
        m['ImageUrl'] ??
        m['image_url'] ??
        m['ImageURL'] ??
        m['image'] ??
        m['Image'] ??
        m['img'] ??
        m['Img'] ??
        m['photo_url'] ??
        m['photoUrl'] ??
        m['PhotoUrl'] ??
        m['photo'] ??
        m['Photo'] ??
        m['picture'] ??
        m['Picture'] ??
        m['pictureUrl'] ??
        m['picture_url'] ??
        m['banner'] ??
        m['Banner'] ??
        m['bannerUrl'] ??
        m['banner_url'] ??
        m['mediaUrl'] ??
        m['media_url'] ??
        m['thumbnail'] ??
        m['thumbnailUrl'] ??
        m['icon'] ??
        m['iconUrl'] ??
        m['imagePath'] ??
        m['image_path'];
    return resolveImageUrl(v);
  }

  /// Parses `TimeinMinutes`; returns 0 for "Not Applicable" or missing.
  static int _parseDuration(dynamic v) {
    if (v == null) return 0;
    final s = v.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'not applicable') return 0;
    final n = int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), ''));
    return (n != null && n > 0) ? n : 0;
  }

  static String _defaultWalkInDescription(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('nail') && lower.contains('grind')) {
      return 'Careful rotary nail grinding for smooth, rounded edges and optimal comfort.';
    } else if (lower.contains('nail')) {
      return 'Carefully trimmed and smoothed nails to improve posture, mobility, and comfort.';
    } else if (lower.contains('anal gland')) {
      return 'Gentle and hygienic anal gland expression supporting digestive comfort.';
    } else if (lower.contains('face') || lower.contains('feet')) {
      return 'Precision facial shaping and foot feather trimming for tidy and clear paws and eyes.';
    }
    return 'Walk-in express pet grooming service performed by skilled specialists.';
  }

  static String _defaultAddOnDescription(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('teeth') || lower.contains('dental')) {
      return 'Oral hygiene care with pet-safe enzymatic toothpaste for fresh breath and cleaner teeth.';
    } else if (lower.contains('blueberry') || lower.contains('facial')) {
      return 'Tearless, aromatic face cleanser that removes tear stains and refreshes facial fur.';
    } else if (lower.contains('flea') || lower.contains('tick')) {
      return 'Specialized cleansing bath to cleanse coat and soothe skin from external parasites.';
    } else if (lower.contains('furminator') || lower.contains('deshed')) {
      return 'Deep undercoat removal treatment that drastically reduces excess seasonal shedding.';
    } else if (lower.contains('medicated')) {
      return 'Therapeutic bath treatment formulated for sensitive, dry, or irritated coat and skin.';
    } else if (lower.contains('de-odorize')) {
      return 'Deep odor-eliminating shampoo treatment keeping pets smelling fresh for days.';
    } else if (lower.contains('dematt') || lower.contains('brush')) {
      return 'Gentle coat detangling and dead fur removal for knot-free, soft fur.';
    } else if (lower.contains('scissoring')) {
      return 'Hand-scissored styling and neatening for breed-standard or customized looks.';
    }
    return 'Specialized add-on grooming enhancement.';
  }

  // ── main fetch ────────────────────────────────────────────────────────────

  Future<BookingServicesResult> getBookingServices() async {
    log.d('ServiceRepository::getBookingServices::GET /api/service-packages');

    try {
      final response =
          await ServicesLocator.apiRepository.get('/api/service-packages');
      if (response == null || !response.containsKey('data')) {
        log.w('ServiceRepository::getBookingServices::Empty response, using fallback');
        return BookingServicesResult.fallback();
      }

      final data = response['data'] as Map<String, dynamic>;
      log.d('ServiceRepository::getBookingServices::keys=${data.keys.toList()}');

      // ── Breeds ────────────────────────────────────────────────────────────
      final breeds = <ServiceItem>[];
      int breedServiceCounter = 1; // starts at 1 per Postman catalog description
      if (data['Breeds'] is List) {
        for (final b in data['Breeds'] as List) {
          if (b is! Map) continue;
          final breedName = b['BreedType']?.toString() ?? 'Unknown Breed';
          final breedImg = _imageUrl(b);

          void addBreedSvc(
              String subType, Map<dynamic, dynamic> m, int catalogId) {
            final price = _parseDouble(m['Price'] ?? m['price']);
            final dur = _parseDuration(m['TimeinMinutes'] ?? m['timeInMinutes']);
            final rawImg = _imageUrl(m) ?? breedImg;
            final itemImg = liveServiceImageUrl(subType, rawUrl: rawImg, id: catalogId);
            breeds.add(ServiceItem(
              id: catalogId,
              isPackage: false,
              isAddOn: false,
              name: '$breedName — $subType',
              description: '$subType for $breedName',
              price: price,
              priceDisplay: _priceDisplay(m['Price'] ?? m['price'], null),
              durationMinutes: dur > 0 ? dur : 60,
              imageUrl: itemImg,
              includes: [
                '$subType tailored to $breedName coat',
                'Nail trim and ear cleanse included',
                'Blow dry and finishing fluff',
              ],
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

      // ── Main Services (catalog service_master items) ─────────────────────
      final rawMain = data['Main Services'] ??
          data['MainServices'] ??
          data['mainServices'] ??
          data['main'];
      if (rawMain is List) {
        for (final m in rawMain) {
          if (m is! Map) continue;
          final rawId = m['ServiceMasterId'] ?? m['id'] ?? m['MainServiceId'];
          int? intId;
          if (rawId is int) {
            intId = rawId;
          } else if (rawId != null) {
            intId = int.tryParse(rawId.toString().replaceAll(RegExp(r'[^0-9]'), ''));
          }
          final currentSvcId = (intId != null && intId > 0) ? intId : breedServiceCounter++;
          final code = (m['MainServiceId'] ?? m['id'] ?? 'SRV-$currentSvcId').toString().trim();
          final name = (m['Name'] ?? m['name'] ?? 'Grooming Service').toString().trim();
          final price = _parseDouble(m['Price'] ?? m['price']);
          final dur = _parseDuration(m['TimeinMinutes'] ?? m['timeInMinutes']);
          final desc = (m['Description'] ?? m['description'] ?? '$name at our pet spa salon.').toString().trim();
          final includes = (m['IncludedSubSteps'] is List)
              ? (m['IncludedSubSteps'] as List)
                  .map((e) => e?.toString().trim() ?? '')
                  .where((s) => s.isNotEmpty)
                  .toList()
              : <String>[];

          final rawImg = _imageUrl(m);
          final serviceImg = liveServiceImageUrl(name, rawUrl: rawImg, id: currentSvcId);

          breeds.add(ServiceItem(
            id: currentSvcId,
            code: code,
            isPackage: false,
            isAddOn: false,
            name: name,
            description: desc,
            price: price,
            priceDisplay: _priceDisplay(m['Price'] ?? m['price'], null),
            durationMinutes: dur > 0 ? dur : 60,
            imageUrl: serviceImg,
            includes: includes.isNotEmpty
                ? includes
                : [
                    name,
                    'Certified professional stylist',
                    'Coat assessment and gentle handling included',
                  ],
          ));
        }
      }

      // ── Walk-In Services ─────────────────────────────────────────────────
      final walkIn = <ServiceItem>[];
      int walkInCounter = breedServiceCounter; // e.g. 10 after 9 breed services
      final rawWalkin = data['Walk In Services'] ??
          data['WalkInServices'] ??
          data['walkInServices'] ??
          data['walkin'];
      if (rawWalkin is List) {
        for (final w in rawWalkin) {
          if (w is! Map) continue;
          final code = (w['WalkInServiceId'] ?? w['id'])?.toString().trim();
          final name =
              (w['Name'] ?? w['name'] ?? 'Walk-In Service').toString().trim();
          final price = _parseDouble(w['Price'] ?? w['price']);
          final dur = _parseDuration(w['TimeinMinutes'] ?? w['timeInMinutes']);
          var desc =
              (w['Description'] ?? w['description'] ?? '').toString().trim();
          if (desc.isEmpty) {
            desc = _defaultWalkInDescription(name);
          }
          final rawImg = _imageUrl(w);
          final walkInImg =
              liveServiceImageUrl(name, rawUrl: rawImg, id: walkInCounter);
          walkIn.add(ServiceItem(
            id: walkInCounter++,
            code: code,
            isPackage: false,
            isAddOn: false,
            name: name,
            description: desc,
            price: price,
            priceDisplay: _priceDisplay(w['Price'] ?? w['price'], null),
            durationMinutes: dur > 0 ? dur : 15,
            imageUrl: walkInImg,
            includes: [
              name,
              'Fast walk-in express service',
              'Safe handling by certified groomers',
            ],
          ));
        }
      }

      // ── Packages ─────────────────────────────────────────────────────────
      final packages = <ServiceItem>[];
      int pkgCounter = 1;
      if (data['Packages'] is List) {
        for (final p in data['Packages'] as List) {
          if (p is! Map) continue;
          final rawMasterId = p['PackageMasterId'] ?? p['packageMasterId'];
          final masterIdInt = int.tryParse(rawMasterId?.toString() ?? '');
          final currentPkgId = masterIdInt ?? pkgCounter++;
          final code = (p['PackageId'] ?? p['id'] ?? 'P000$currentPkgId').toString().trim();

          String name = (p['PackageName'] ?? p['packageName'] ?? p['name'] ?? '')
              .toString()
              .trim();
          // If name looks like a code (e.g. "P0003") or is empty, use descriptive name
          if (name.isEmpty || RegExp(r'^[A-Z]\d+$').hasMatch(name)) {
            final idx = currentPkgId - 1;
            if (idx >= 0 && idx < _defaultPackageNames.length) {
              name = _defaultPackageNames[idx];
            } else {
              name = 'Package $currentPkgId';
            }
          }

          final price = _parseDouble(p['Price'] ?? p['price']);
          final dur = _parseDuration(p['TimeinMinutes'] ?? p['timeInMinutes']);
          var includes = (p['Includes'] is List)
              ? (p['Includes'] as List)
                  .map((e) => e?.toString().trim() ?? '')
                  .where((s) => s.isNotEmpty)
                  .toList()
              : <String>[];
          if (includes.isEmpty) {
            final idx = currentPkgId - 1;
            if (idx >= 0 && idx < _defaultPackageIncludes.length) {
              includes = _defaultPackageIncludes[idx];
            }
          }

          var desc = (p['Description'] ?? p['description'] ?? '').toString().trim();
          if (desc.isEmpty) {
            final idx = currentPkgId - 1;
            if (idx >= 0 && idx < _defaultPackageDescriptions.length) {
              desc = _defaultPackageDescriptions[idx];
            } else if (includes.isNotEmpty) {
              desc = includes.join(', ');
            } else {
              desc = 'Comprehensive pet spa package with premium grooming services.';
            }
          }

          final rawImg = _imageUrl(p);
          final pkgImg =
              liveServiceImageUrl(name, rawUrl: rawImg, id: currentPkgId);

          packages.add(ServiceItem(
            id: currentPkgId,
            code: code,
            isPackage: true,
            isAddOn: false,
            name: name,
            description: desc,
            price: price,
            priceDisplay: _priceDisplay(p['Price'] ?? p['price'], null),
            durationMinutes: dur > 0 ? dur : 60,
            imageUrl: pkgImg,
            includes: includes,
          ));
        }
      }

      // ── Add-Ons ──────────────────────────────────────────────────────────
      // Backend catalog: add-ons 1–12 (independent sequence starting at 1)
      final addOns = <ServiceItem>[];
      int addonCounter = 1;
      if (data['AddOns'] is List) {
        for (final a in data['AddOns'] as List) {
          if (a is! Map) continue;
          final fallbackId = addonCounter++;
          final rawId = a['id'];
          final explicitId = (rawId is int)
              ? rawId
              : (rawId != null ? int.tryParse(rawId.toString()) : null);
          final currentAddonId = (explicitId != null && explicitId > 0)
              ? explicitId
              : fallbackId;
          final code = (a['AddOnId'] ?? a['id'])?.toString().trim();
          final name = (a['Name'] ?? a['name'] ?? 'Add-on').toString().trim();
          final price = _parseDouble(a['Price'] ?? a['price']);
          final suffix = a['Sufix'] ?? a['suffix'];
          final dur = _parseDuration(a['TimeinMinutes'] ?? a['timeInMinutes']);
          final includes = (a['Includes'] is List)
              ? (a['Includes'] as List)
                  .map((e) => e?.toString().trim() ?? '')
                  .where((s) => s.isNotEmpty)
                  .toList()
              : <String>[];
          var desc = (a['Description'] ?? a['description'] ?? '').toString().trim();
          if (desc.isEmpty && includes.isNotEmpty) {
            desc = includes.join(', ');
          }
          if (desc.isEmpty) {
            desc = _defaultAddOnDescription(name);
          }

          final rawImg = _imageUrl(a);
          final addOnImg = liveServiceImageUrl(name, rawUrl: rawImg, id: currentAddonId);

          addOns.add(ServiceItem(
            id: currentAddonId,
            code: code,
            isPackage: false,
            isAddOn: true,
            name: name,
            description: desc,
            price: price,
            priceDisplay: _priceDisplay(a['Price'] ?? a['price'], suffix),
            durationMinutes: dur,
            imageUrl: addOnImg,
            includes: includes.isNotEmpty ? includes : [name],
          ));
        }
      }

      log.d('ServiceRepository::getBookingServices::Result'
          ' breeds=${breeds.length}(ids 1–${breeds.isEmpty ? 0 : breeds.last.id})'
          ' walkIn=${walkIn.length}(ids ${breeds.isEmpty ? 1 : breeds.last.id + 1}–${walkIn.isEmpty ? 0 : walkIn.last.id})'
          ' packages=${packages.length}(ids 1–${packages.isEmpty ? 0 : packages.last.id})'
          ' addOns=${addOns.length}(ids 1–${addOns.isEmpty ? 0 : addOns.last.id})');

      final result = BookingServicesResult(
        breeds: breeds,
        packages: packages,
        addOns: addOns,
        walkIn: walkIn,
      );

      if (result.isEmpty) {
        log.w('ServiceRepository::getBookingServices::Result is empty, using fallback');
        return BookingServicesResult.fallback();
      }

      return result;
    } catch (e) {
      log.w('ServiceRepository::getBookingServices::Error fetching services ($e), using fallback');
      return BookingServicesResult.fallback();
    }
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

  /// Looks up a service by numeric ID, string code, name, and category.
  /// Resolves the collision between breeds (1..9), walkIn (10..13), and addOns (1..12).
  Future<Map<String, dynamic>?> getServiceDetail({
    dynamic id,
    String? code,
    String? name,
    bool? isAddOn,
    bool? isPackage,
    Map<String, dynamic>? initialService,
  }) async {
    final result = await getBookingServices();

    final idStr = (id ?? code ?? initialService?['code'] ?? initialService?['id'])?.toString().trim();
    final intId = id is int
        ? id
        : int.tryParse(id?.toString() ?? '') ??
            int.tryParse(initialService?['id']?.toString() ?? '');

    final targetName = (name ?? initialService?['name'] ?? initialService?['service_name'])?.toString().trim();
    final effectiveIsAddOn = isAddOn ??
        (initialService?['isAddOn'] == true ||
            initialService?['addOnId'] != null ||
            (idStr != null && (idStr.startsWith('addon_') || idStr.startsWith('A') || idStr.startsWith('a'))));
    final effectiveIsPackage = isPackage ??
        (initialService?['isPackage'] == true ||
            initialService?['packageId'] != null ||
            (idStr != null && (idStr.startsWith('pkg_') || idStr.startsWith('P') || idStr.startsWith('p'))));

    final targetCode = (code ?? initialService?['code'] ?? (idStr != null && RegExp(r'^[A-Za-z]\d+$').hasMatch(idStr) ? idStr : null))?.toString().trim();

    // 1. Match by Code if available (e.g. A0001, W0001, P0001)
    if (targetCode != null && targetCode.isNotEmpty) {
      final allServices = [...result.addOns, ...result.walkIn, ...result.packages, ...result.breeds];
      for (final s in allServices) {
        if (s.code != null && s.code!.toLowerCase() == targetCode.toLowerCase()) {
          return s.toMap();
        }
      }
    }

    // 2. If isAddOn is true, search addOns by id / code / name
    if (effectiveIsAddOn == true) {
      if (intId != null) {
        for (final s in result.addOns) {
          if (s.id == intId) return s.toMap();
        }
      }
      if (idStr != null && idStr.startsWith('addon_')) {
        final parsed = int.tryParse(idStr.replaceFirst('addon_', ''));
        if (parsed != null) {
          for (final s in result.addOns) {
            if (s.id == parsed) return s.toMap();
          }
        }
      }
      if (targetName != null && targetName.isNotEmpty) {
        for (final s in result.addOns) {
          if (s.name.toLowerCase() == targetName.toLowerCase()) return s.toMap();
        }
      }
    }

    // 3. If isPackage is true, search packages by id / code / name
    if (effectiveIsPackage == true) {
      if (intId != null) {
        for (final p in result.packages) {
          if (p.id == intId) return p.toMap();
        }
      }
      if (targetName != null && targetName.isNotEmpty) {
        for (final p in result.packages) {
          if (p.name.toLowerCase() == targetName.toLowerCase()) return p.toMap();
        }
      }
    }

    // 4. Match by Name if available
    if (targetName != null && targetName.isNotEmpty) {
      final nameLower = targetName.toLowerCase();
      final allServices = [...result.walkIn, ...result.breeds, ...result.addOns, ...result.packages];
      for (final s in allServices) {
        if (s.name.toLowerCase() == nameLower) {
          return s.toMap();
        }
      }
      for (final s in allServices) {
        if (s.name.toLowerCase().contains(nameLower) || nameLower.contains(s.name.toLowerCase())) {
          return s.toMap();
        }
      }
    }

    // 5. General search by numeric id
    if (intId != null) {
      // If caller knows it's not an add-on, search walkIn and breeds first
      if (effectiveIsAddOn == false) {
        for (final s in [...result.walkIn, ...result.breeds]) {
          if (s.id == intId) return s.toMap();
        }
      }

      // Default order: search walkIn, breeds, addOns, then packages
      for (final s in [...result.walkIn, ...result.breeds, ...result.addOns]) {
        if (s.id == intId) return s.toMap();
      }
      for (final p in result.packages) {
        if (p.id == intId) return p.toMap();
      }
    }

    return initialService;
  }

  /// Looks up a service by numeric ID.
  /// Delegates to [getServiceDetail] for comprehensive lookup across walkIn, breeds, and addOns.
  Future<Map<String, dynamic>?> getServiceById(int id) async {
    return getServiceDetail(id: id);
  }

  /// Looks up a package by ID, code, or name.
  Future<Map<String, dynamic>?> getPackageDetail({
    dynamic id,
    String? code,
    String? name,
    Map<String, dynamic>? initialPackage,
  }) async {
    final result = await getBookingServices();
    final idStr = (id ?? code ?? initialPackage?['code'] ?? initialPackage?['id'])?.toString().trim();
    final intId = id is int ? id : int.tryParse(idStr ?? '');
    final targetCode = (code ?? initialPackage?['code'] ?? (idStr != null && RegExp(r'^[A-Za-z]\d+$').hasMatch(idStr) ? idStr : null))?.toString().trim();
    final targetName = (name ?? initialPackage?['package_name'] ?? initialPackage?['name'])?.toString().trim();

    if (targetCode != null && targetCode.isNotEmpty) {
      for (final p in result.packages) {
        if (p.code != null && p.code!.toLowerCase() == targetCode.toLowerCase()) {
          return p.toMap();
        }
      }
    }

    if (targetName != null && targetName.isNotEmpty) {
      for (final p in result.packages) {
        if (p.name.toLowerCase() == targetName.toLowerCase()) {
          return p.toMap();
        }
      }
    }

    if (intId != null) {
      for (final p in result.packages) {
        if (p.id == intId) return p.toMap();
      }
      if (intId > 0 && intId <= result.packages.length) {
        return result.packages[intId - 1].toMap();
      }
    }

    return initialPackage;
  }

  /// Looks up a package specifically by numeric ID (e.g. 1, 2, 3).
  Future<Map<String, dynamic>?> getPackageById(int id) async {
    return getPackageDetail(id: id);
  }
}
