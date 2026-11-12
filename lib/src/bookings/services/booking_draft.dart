import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';

enum BookingState {
  newBooking,
  existingPet,
}

class BookingDraft extends ChangeNotifier {
  final Logger log = Logger();

  Map<String, dynamic>? pet;
  /// Standalone service selection (independent of [package]).
  Map<String, dynamic>? service;
  /// Spa package selection (mandatory for Continue; independent of [service]).
  Map<String, dynamic>? package;
  Map<String, dynamic>? groomer;
  DateTime? date;
  String? timeSlot;
  String? endTime;

  /// The full backend slot object from `availableSlots`.
  /// Contains at minimum: `startTime`, `endTime`, `groomerId`, `groomerName`.
  Map<String, dynamic>? selectedSlot;

  /// Snapshot of the most recently confirmed booking, used by the
  /// "Booking Confirmed" screen after the draft has been reset.
  Map<String, dynamic>? lastBooking;

  BookingState get state => pet == null ? BookingState.newBooking : BookingState.existingPet;

  bool get isComplete =>
      pet != null && package != null && date != null && timeSlot != null && endTime != null;

  /// Whether a spa package is currently selected.
  bool get isPackageSelected => package != null;

  /// Primary catalog item for display (package preferred, then standalone service).
  Map<String, dynamic>? get primaryCatalogItem => package ?? service;

  String get primaryCatalogName {
    final item = primaryCatalogItem;
    if (item == null) return '';
    return item['service_name']?.toString() ??
        item['package_name']?.toString() ??
        item[Constants.database.COLUMN_SERVICE_NAME]?.toString() ??
        item[Constants.database.COLUMN_PACKAGE_NAME]?.toString() ??
        item['name']?.toString() ??
        '';
  }

  double _priceOf(Map<String, dynamic>? item) {
    if (item == null) return 0.0;
    final p = item['price'] ?? item[Constants.database.COLUMN_PRICE];
    if (p is num) return p.toDouble();
    if (p != null) {
      return double.tryParse(p.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    }
    return 0.0;
  }

  /// Total price of all selected add-ons.
  double get addOnsTotal {
    double addOnTotal = 0.0;
    for (final a in addOns) {
      addOnTotal += _priceOf(a);
    }
    return addOnTotal;
  }

  /// Standalone service price (excluding add-ons).
  double get standaloneServicePrice {
    if (apiServiceSubtotal != null && apiServiceSubtotal! > 0) {
      return apiServiceSubtotal!;
    }
    return _priceOf(service);
  }

  /// Package subtotal (package price if a package is selected, else 0.0).
  double get packageSubtotal {
    if (apiPackageSubtotal != null && apiPackageSubtotal! > 0) {
      return apiPackageSubtotal!;
    }
    return _priceOf(package);
  }

  /// Service subtotal: standalone service price + add-ons (package priced separately).
  double get serviceSubtotal => standaloneServicePrice + addOnsTotal;

  /// Estimated subtotal before tax and discounts: package + standalone service + add-ons.
  double get estimatedTotal => packageSubtotal + standaloneServicePrice + addOnsTotal;

  // ---------------------------------------------------------------------------
  // Setters
  // ---------------------------------------------------------------------------

  void setPet(Map<String, dynamic>? value) {
    log.d("BookingDraft::setPet::Pet: ${value?['pet_name']}");
    pet = value;
    notifyListeners();
  }

  void setGroomer(Map<String, dynamic>? value) {
    log.d("BookingDraft::setGroomer::Groomer: ${value?['name']}");
    groomer = value;
    notifyListeners();
  }

  void setService(Map<String, dynamic>? value) {
    log.d("BookingDraft::setService::Service: ${value?['service_name']}");
    service = value;
    apiTotalPrice = null;
    apiServiceSubtotal = null;
    apiSalesTax = null;
    apiTaxRate = null;
    apiTotalWithTax = null;
    notifyListeners();
  }

  void setPackage(Map<String, dynamic>? value) {
    log.d("BookingDraft::setPackage::Package: ${value?['service_name'] ?? value?['package_name']}");
    package = value;
    apiTotalPrice = null;
    apiPackageSubtotal = null;
    apiSalesTax = null;
    apiTaxRate = null;
    apiTotalWithTax = null;
    notifyListeners();
  }

  void clearCatalogSelections() {
    package = null;
    service = null;
    addOns.clear();
    apiTotalPrice = null;
    apiServiceSubtotal = null;
    apiPackageSubtotal = null;
    apiSalesTax = null;
    apiTaxRate = null;
    apiTotalWithTax = null;
    notifyListeners();
  }

  void setDate(DateTime? value) {
    if (value != null) {
      final norm = BookingDateUtils.normalize(value);
      log.d("BookingDraft::setDate::Date: $norm");
      date = norm;
    } else {
      log.d("BookingDraft::setDate::Date: null");
      date = null;
    }
    timeSlot = null;
    endTime = null;
    selectedSlot = null;
    notifyListeners();
  }

  void setTimeSlot(String? value) {
    log.d("BookingDraft::setTimeSlot::Slot: $value");
    timeSlot = value;
    endTime = null;
    selectedSlot = null;
    notifyListeners();
  }

  /// Atomically set both startTime and endTime from a selected availability slot.
  /// [slot] is the full backend slot object — stored as-is.
  void setSelectedSlot(Map<String, dynamic> slot) {
    final startTime = slot['startTime']?.toString() ?? '';
    final slotEndTime = slot['endTime']?.toString() ?? '';
    log.d("BookingDraft::setSelectedSlot::$startTime → $slotEndTime (full object stored)");
    timeSlot = startTime;
    endTime = slotEndTime;
    selectedSlot = Map<String, dynamic>.from(slot);
    notifyListeners();
  }

  /// Legacy setter — prefer [setSelectedSlot] which stores the full object.
  void setSlot(String startTime, String slotEndTime) {
    log.d("BookingDraft::setSlot::$startTime → $slotEndTime (no slot object)");
    timeSlot = startTime;
    endTime = slotEndTime;
    selectedSlot = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Service / add-on ID extraction (used by date-time & review pages)
  // ---------------------------------------------------------------------------

  int? _extractIdFromMap(
    Map<String, dynamic>? map, {
    required List<String> keys,
  }) {
    if (map == null) return null;
    for (final key in keys) {
      final raw = map[key];
      if (raw != null) {
        final parsed = int.tryParse(raw.toString());
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    final rawId = map['id'] ?? map[Constants.database.COLUMN_ID];
    int? extractedId = int.tryParse(rawId?.toString() ?? '');
    if (extractedId == null && rawId != null) {
      final match = RegExp(r'\d+').firstMatch(rawId.toString());
      if (match != null) {
        extractedId = int.tryParse(match.group(0)!);
      }
    }
    if (extractedId != null && extractedId > 0) return extractedId;
    return null;
  }

  /// Extracts `serviceId` from [service] and `packageId` from [package].
  Map<String, dynamic> extractServiceIds() {
    final packageId = _extractIdFromMap(
      package,
      keys: const [
        'packageMasterId',
        'PackageMasterId',
        'packageId',
        'PackageId',
      ],
    );

    final serviceId = _extractIdFromMap(
      service,
      keys: const [
        'serviceMasterId',
        'ServiceMasterId',
        'serviceId',
        'service_id',
        'ServiceId',
      ],
    );

    return {'serviceId': serviceId, 'packageId': packageId};
  }

  /// Returns a list of integer add-on IDs from the current selection.
  List<int> extractAddOnIds() {
    return addOns
        .map((a) => int.tryParse((a['addOnId'] ?? a['id'] ?? a['service_id'])?.toString() ?? '0') ?? 0)
        .where((id) => id > 0)
        .toList();
  }

  /// Returns normalized pet size key matching backend API enum:
  /// 'small', 'medium', 'large', 'extralarge'
  String get petSizeKey {
    final w = (pet?['weight'] ?? pet?['weightClass'] ?? pet?['size'])
        ?.toString()
        .trim()
        .toLowerCase() ?? '';
    if (w.isEmpty) return 'small';
    if (w.contains('extra large') || w.contains('xlarge') || w.contains('xl')) return 'extralarge';
    if (w.contains('extra small') || w.contains('xsmall') || w.contains('xs') || w.contains('small')) return 'small';
    if (w.contains('large')) return 'large';
    if (w.contains('medium')) return 'medium';
    return 'small';
  }

  /// Clears the selected time slot. Called when service / add-ons / groomer /
  /// date changes so stale slots are never carried forward.
  void clearSelectedSlot() {
    log.d("BookingDraft::clearSelectedSlot");
    timeSlot = null;
    endTime = null;
    selectedSlot = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // API-sourced values (from POST /api/availability)
  // ---------------------------------------------------------------------------

  /// API-computed total duration in minutes (set from /api/availability response).
  int? apiDurationMinutes;

  /// API-computed total price (set from /api/availability response).
  double? apiTotalPrice;

  /// API-computed service subtotal (set from /api/availability response).
  double? apiServiceSubtotal;

  /// API-computed package subtotal (set from /api/availability response).
  double? apiPackageSubtotal;

  /// API-computed sales tax (set from /api/availability response).
  double? apiSalesTax;

  /// API-computed tax rate (set from /api/availability response).
  double? apiTaxRate;

  /// API-computed total with tax (set from /api/availability response).
  double? apiTotalWithTax;

  /// API-computed state name or state code (set from /api/availability response).
  String? apiStateName;

  // Legacy names kept for backward compat (lastBooking, confirmed page).
  int? get duration => apiDurationMinutes;

  /// Effective total price (pre-tax subtotal): prefers apiTotalPrice if valid and >= estimatedTotal,
  /// otherwise falls back to estimatedTotal.
  double? get totalPrice {
    if (apiTotalPrice != null && apiTotalPrice! >= estimatedTotal) {
      return apiTotalPrice;
    }
    return estimatedTotal > 0 ? estimatedTotal : apiTotalPrice;
  }

  double? get salesTax => apiSalesTax;
  double? get taxRate => apiTaxRate;

  /// Effective total with tax: prefers apiTotalWithTax if valid and >= totalPrice,
  /// otherwise calculates (totalPrice + salesTax).
  double? get totalWithTax {
    final sub = totalPrice ?? estimatedTotal;
    if (apiTotalWithTax != null && apiTotalWithTax! >= sub) {
      return apiTotalWithTax;
    }
    final tax = salesTax ?? 0.0;
    return sub > 0 ? ((sub + tax) * 100).round() / 100 : null;
  }

  // ---------------------------------------------------------------------------
  // Offers & Promo Code State
  // ---------------------------------------------------------------------------

  /// Currently applied offer/promo details.
  /// Keys: `promoCode`, `discountAmount`, `discountType`, `discountValue`, `finalAmount`, `description`.
  Map<String, dynamic>? appliedOffer;

  String? get appliedPromoCode => appliedOffer?['promoCode']?.toString();

  double? get discountAmount {
    if (appliedOffer == null) return null;
    final raw = appliedOffer!['discountAmount'];
    if (raw is num) return raw.toDouble();
    if (raw != null) return double.tryParse(raw.toString());
    return null;
  }

  /// Final price after applying discount to `totalPrice` (or `estimatedTotal`).
  double? get discountedTotalPrice {
    final basePrice = totalPrice ?? (estimatedTotal > 0 ? estimatedTotal : null);
    if (basePrice == null) return null;
    final discount = discountAmount ?? 0.0;
    return (basePrice - discount).clamp(0.0, double.infinity);
  }

  void applyOffer(Map<String, dynamic> offer) {
    log.d("BookingDraft::applyOffer::Applying offer: ${offer['promoCode']}");
    appliedOffer = Map<String, dynamic>.from(offer);
    notifyListeners();
  }

  void removeOffer() {
    log.d("BookingDraft::removeOffer::Removing applied offer");
    appliedOffer = null;
    notifyListeners();
  }

  /// Explicit helper to reset booking-specific offer state when exiting the flow.
  void resetOffer() {
    removeOffer();
  }

  List<Map<String, dynamic>> addOns = [];

  /// Optional customer-entered service request instructions / notes for the groomer.
  /// Distinct from permanent pet profile notes (medical/behavioral).
  String? serviceRequestNotes;

  void setServiceRequestNotes(String? value, {bool notify = true}) {
    log.d("BookingDraft::setServiceRequestNotes::Notes: $value");
    serviceRequestNotes = value;
    if (notify) {
      notifyListeners();
    }
  }

  void toggleAddOn(Map<String, dynamic> addOn) {
    final id = addOn['id'] ?? addOn['service_id'];
    final index = addOns.indexWhere((e) => (e['id'] ?? e['service_id']) == id);
    if (index >= 0) {
      addOns.removeAt(index);
    } else {
      addOns.add(addOn);
    }
    apiTotalPrice = null;
    apiSalesTax = null;
    apiTaxRate = null;
    apiTotalWithTax = null;
    notifyListeners();
  }

  void reset() {
    pet = null;
    service = null;
    package = null;
    groomer = null;
    addOns.clear();
    serviceRequestNotes = null;
    date = null;
    timeSlot = null;
    endTime = null;
    selectedSlot = null;
    apiDurationMinutes = null;
    apiTotalPrice = null;
    apiServiceSubtotal = null;
    apiPackageSubtotal = null;
    apiSalesTax = null;
    apiTaxRate = null;
    apiTotalWithTax = null;
    apiStateName = null;
    appliedOffer = null;
    notifyListeners();
  }
}
