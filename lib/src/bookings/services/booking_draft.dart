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

  double get estimatedTotal {
    double total = 0;
    final servicePrice = service?['price'];
    if (servicePrice is num) {
      total += servicePrice.toDouble();
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
      final rawPkgId = serviceMap['packageId'] ?? serviceMap['PackageId'];
      if (rawPkgId != null) {
        packageId = int.tryParse(rawPkgId.toString());
      }

      final rawSvcId = serviceMap['serviceId'] ?? serviceMap['service_id'] ?? serviceMap['ServiceId'];
      if (rawSvcId != null) {
        serviceId = int.tryParse(rawSvcId.toString());
      }

      if (packageId == null && serviceId == null) {
        final isPkg = serviceMap['isPackage'] == true ||
            serviceMap.containsKey('package_name') ||
            serviceMap[Constants.database.COLUMN_PACKAGE_NAME] != null;

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
        .map((a) => int.tryParse((a['id'] ?? a['service_id'] ?? a['addOnId'])?.toString() ?? '0') ?? 0)
        .where((id) => id > 0)
        .toList();
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

  List<Map<String, dynamic>> addOns = [];

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
    date = null;
    timeSlot = null;
    endTime = null;
    selectedSlot = null;
    apiDurationMinutes = null;
    apiTotalPrice = null;
    appliedOffer = null;
    notifyListeners();
  }
}
