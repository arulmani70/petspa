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
  Map<String, dynamic>? service;
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
      pet != null && service != null && date != null && timeSlot != null && endTime != null;

  /// Whether the currently selected item is a spa package rather than a standalone service.
  bool get isPackageSelected {
    final s = service;
    if (s == null) return false;
    if (s['isPackage'] == true) return true;
    if (s['isPackage'] == false) return false;
    final pkgId = s['packageId'] ?? s['PackageId'];
    if (pkgId != null && pkgId.toString().isNotEmpty) return true;
    final pkgName = s['package_name'] ?? s[Constants.database.COLUMN_PACKAGE_NAME];
    if (pkgName != null && pkgName.toString().trim().isNotEmpty) return true;
    return false;
  }

  /// Service subtotal (main service + add-ons, or if a package is selected, just add-ons).
  double get serviceSubtotal {
    if (apiServiceSubtotal != null) return apiServiceSubtotal!;
    if (isPackageSelected) {
      double addOnTotal = 0.0;
      for (final a in addOns) {
        final p = a['price'] ?? a[Constants.database.COLUMN_PRICE];
        if (p is num) {
          addOnTotal += p.toDouble();
        } else if (p != null) {
          addOnTotal += double.tryParse(p.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        }
      }
      return addOnTotal;
    } else {
      return totalPrice ?? estimatedTotal;
    }
  }

  /// Package subtotal (package price if a package is selected, else 0.0).
  double get packageSubtotal {
    if (apiPackageSubtotal != null) return apiPackageSubtotal!;
    if (isPackageSelected) {
      final s = service;
      final p = s?['price'] ?? s?[Constants.database.COLUMN_PRICE];
      if (p is num) return p.toDouble();
      if (p != null) {
        final parsed = double.tryParse(p.toString().replaceAll(RegExp(r'[^0-9.]'), ''));
        if (parsed != null) return parsed;
      }
      return totalPrice ?? estimatedTotal;
    }
    return 0.0;
  }

  double get estimatedTotal {
    double total = 0;
    final servicePrice = service?['price'] ?? service?[Constants.database.COLUMN_PRICE];
    if (servicePrice is num) {
      total += servicePrice.toDouble();
    } else if (servicePrice != null) {
      total += double.tryParse(servicePrice.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    }
    for (final addOn in addOns) {
      final p = addOn['price'] ?? addOn[Constants.database.COLUMN_PRICE];
      if (p is num) {
        total += p.toDouble();
      } else if (p != null) {
        total += double.tryParse(p.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
      }
    }
    return total;
  }

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

  /// Extracts `serviceId` and `packageId` from the current [_draft.service] map.
  Map<String, dynamic> extractServiceIds() {
    final serviceMap = service;
    int? packageId;
    int? serviceId;

    if (serviceMap != null) {
      final rawPkgId = serviceMap['packageMasterId'] ??
          serviceMap['PackageMasterId'] ??
          serviceMap['packageId'] ??
          serviceMap['PackageId'];
      if (rawPkgId != null) {
        packageId = int.tryParse(rawPkgId.toString());
      }

      final rawSvcId = serviceMap['serviceMasterId'] ??
          serviceMap['ServiceMasterId'] ??
          serviceMap['serviceId'] ??
          serviceMap['service_id'] ??
          serviceMap['ServiceId'];
      if (rawSvcId != null) {
        serviceId = int.tryParse(rawSvcId.toString());
      }

      if (packageId == null && serviceId == null) {
        final isPkg = serviceMap['isPackage'] == true ||
            (serviceMap['package_name'] != null && serviceMap['package_name'].toString().trim().isNotEmpty) ||
            (serviceMap[Constants.database.COLUMN_PACKAGE_NAME] != null && serviceMap[Constants.database.COLUMN_PACKAGE_NAME].toString().trim().isNotEmpty);

        final rawId = serviceMap['id'] ?? serviceMap[Constants.database.COLUMN_ID];
        int? extractedId = int.tryParse(rawId?.toString() ?? '');
        if (extractedId == null && rawId != null) {
          final match = RegExp(r'\d+').firstMatch(rawId.toString());
          if (match != null) {
            extractedId = int.tryParse(match.group(0)!);
          }
        }

        if (isPkg) {
          packageId = extractedId;
        } else {
          serviceId = extractedId;
        }
      }
    }

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

  // Legacy names kept for backward compat (lastBooking, confirmed page).
  int? get duration => apiDurationMinutes;
  double? get totalPrice => apiTotalPrice;

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
    notifyListeners();
  }

  void reset() {
    pet = null;
    service = null;
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
    appliedOffer = null;
    notifyListeners();
  }
}
