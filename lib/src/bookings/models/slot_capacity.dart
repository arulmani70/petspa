// ─────────────────────────────────────────────────────────────────────────────
// SlotCapacity — multi-booking capacity model for a single time slot.
//
// PURPOSE
// -------
// Encapsulates all data needed to decide whether a slot is available when
// multi-booking is enabled on a groomer's profile.
//
// API-READINESS
// -------------
// The fields map directly to what the backend will eventually return per slot
// or per groomer in the /api/groomer-availability response:
//
//   groomer.multiBookingEnabled   → isMultiBookingEnabled
//   groomer.slotBookingLimit      → maxBookings
//   slot.bookingCount  (pending)  → bookingCount  (not yet in API response)
//
// When the backend adds `bookingCount` per slot, the only change needed is:
//   SlotCapacity.fromGroomerSlot(groomerData, slotData)
// — no changes to the UI or slot-generation logic.
//
// CURRENT BEHAVIOUR (no API endpoint for booking counts yet)
// -----------------------------------------------------------
// `bookingCount` defaults to 0 when no API data is available.
// This means every slot that is not in `bookedSlots[]` is shown as available.
// Exactly the same behaviour as before — no regression.
//
// ─────────────────────────────────────────────────────────────────────────────

/// Holds the capacity state for one time slot.
class SlotCapacity {
  /// Whether the groomer has multi-booking enabled.
  /// When `false`, the standard single-booking rule applies:
  ///   any existing booking → slot is blocked.
  final bool isMultiBookingEnabled;

  /// Maximum simultaneous bookings allowed in this slot.
  /// Meaningful only when [isMultiBookingEnabled] is `true`.
  final int maxBookings;

  /// Current number of pending/confirmed bookings occupying this slot.
  /// Source: API field `bookingCount` per slot.
  final int bookingCount;

  /// Whether the currently authenticated customer already owns an active booking
  /// for this exact slot (same groomer, date, startTime, endTime).
  final bool isAlreadyBookedByCurrentUser;

  /// Explicit `isAvailable` override if returned directly by the backend API.
  final bool? _explicitIsAvailable;

  /// Explicit `remaining` override if returned directly by the backend API.
  final int? _explicitRemaining;

  const SlotCapacity({
    required this.isMultiBookingEnabled,
    required this.maxBookings,
    required this.bookingCount,
    this.isAlreadyBookedByCurrentUser = false,
    bool? isAvailable,
    int? remaining,
  })  : _explicitIsAvailable = isAvailable,
        _explicitRemaining = remaining;

  // ── Convenience constructors ──────────────────────────────────────────────

  /// Standard single-booking capacity (multi-booking disabled).
  /// Used when the groomer has not enabled multi-booking.
  const SlotCapacity.singleBooking()
      : isMultiBookingEnabled           = false,
        maxBookings                     = 1,
        bookingCount                    = 0,
        isAlreadyBookedByCurrentUser    = false,
        _explicitIsAvailable            = null,
        _explicitRemaining              = null;

  /// Build capacity from the groomer-level API data map.
  ///
  /// Currently reads [multiBookingEnabled] and [slotBookingLimit] from the
  /// groomer object returned by /api/groomer-availability.
  factory SlotCapacity.fromGroomerData(
    Map<dynamic, dynamic> groomerData, {
    int? bookingCountForSlot,
    int? maxBookingsForSlot,
    int? remainingForSlot,
    bool? isAvailableForSlot,
    bool isAlreadyBookedByCurrentUser = false,
  }) {
    final isMulti = groomerData['multiBookingEnabled'] == true;
    final rawLimit = maxBookingsForSlot ??
        groomerData['slotBookingLimit'] ??
        groomerData['maxBookings'];
    final limit = _parseInt(rawLimit) ?? (isMulti ? 3 : 1);
    final count = bookingCountForSlot ?? _parseInt(groomerData['bookingCount']) ?? 0;

    return SlotCapacity(
      isMultiBookingEnabled: isMulti,
      maxBookings          : limit.clamp(1, 999),
      bookingCount         : count,
      isAlreadyBookedByCurrentUser: isAlreadyBookedByCurrentUser,
      isAvailable          : isAvailableForSlot,
      remaining            : remainingForSlot,
    );
  }

  /// Build capacity directly from a slot-level API data map (as returned in
  /// `availableSlots[]` from `POST /api/availability` or `GET /api/groomer-availability`).
  ///
  /// Maps:
  ///   slotData['bookingCount'] → bookingCount
  ///   slotData['maxBookings']  → maxBookings (or fallback to groomerData['slotBookingLimit'])
  ///   slotData['remaining']    → remaining
  ///   slotData['isAvailable']  → isAvailable
  ///   slotData['isAlreadyBookedByCurrentUser'] → isAlreadyBookedByCurrentUser
  ///   groomerData['multiBookingEnabled'] → isMultiBookingEnabled
  factory SlotCapacity.fromSlotData(
    Map<dynamic, dynamic> slotData, {
    Map<dynamic, dynamic>? groomerData,
  }) {
    final isMulti = groomerData?['multiBookingEnabled'] == true ||
        slotData['multiBookingEnabled'] == true ||
        (slotData.containsKey('maxBookings') && (_parseInt(slotData['maxBookings']) ?? 1) > 1) ||
        (groomerData != null && (_parseInt(groomerData['slotBookingLimit']) ?? 1) > 1);

    final rawLimit = slotData['maxBookings'] ??
        slotData['slotBookingLimit'] ??
        groomerData?['slotBookingLimit'] ??
        groomerData?['maxBookings'];
    final limit = _parseInt(rawLimit) ?? (isMulti ? 3 : 1);

    final count = _parseInt(slotData['bookingCount']) ?? 0;

    final rawIsAvailable = slotData['isAvailable'];
    final bool? explicitAvailable = rawIsAvailable is bool
        ? rawIsAvailable
        : (rawIsAvailable != null
            ? rawIsAvailable.toString().toLowerCase() == 'true'
            : null);

    final explicitRemaining = _parseInt(slotData['remaining']);

    final rawAlreadyBooked = slotData['isAlreadyBookedByCurrentUser'] ??
        slotData['alreadyBookedByCurrentUser'] ??
        slotData['isBookedByCurrentUser'];
    final bool alreadyBooked = rawAlreadyBooked is bool
        ? rawAlreadyBooked
        : (rawAlreadyBooked != null
            ? rawAlreadyBooked.toString().toLowerCase() == 'true'
            : false);

    return SlotCapacity(
      isMultiBookingEnabled: isMulti,
      maxBookings          : limit.clamp(1, 999),
      bookingCount         : count,
      isAlreadyBookedByCurrentUser: alreadyBooked,
      isAvailable          : explicitAvailable,
      remaining            : explicitRemaining,
    );
  }

  // ── Core availability & selectability decision ────────────────────────────

  /// Returns `true` when the slot has available capacity.
  ///
  /// Note: [isAvailable] represents global capacity for bookings.
  /// To check if the current user can select this slot, use [isSelectable].
  bool get isAvailable {
    if (_explicitIsAvailable != null) {
      return _explicitIsAvailable;
    }
    return bookingCount < maxBookings;
  }

  /// How many more bookings can be accepted for this slot.
  ///
  /// Represents TOTAL remaining capacity for other customers.
  int get remaining {
    if (_explicitRemaining != null) {
      return _explicitRemaining;
    }
    return (maxBookings - bookingCount).clamp(0, maxBookings);
  }

  /// Whether the slot is selectable.
  ///
  /// Final capacity rule:
  /// `isSelectable = isAvailable && remaining > 0 && bookingCount < maxBookings`
  bool get isSelectable =>
      isAvailable && remaining > 0 && bookingCount < maxBookings;

  /// Human-readable capacity label for the UI, e.g. "2 / 3".
  /// Returns `null` when multi-booking is disabled (no label needed).
  String? get capacityLabel =>
      isMultiBookingEnabled ? '$bookingCount / $maxBookings' : null;

  SlotCapacity copyWith({
    bool? isMultiBookingEnabled,
    int? maxBookings,
    int? bookingCount,
    bool? isAlreadyBookedByCurrentUser,
    bool? isAvailable,
    int? remaining,
  }) {
    return SlotCapacity(
      isMultiBookingEnabled: isMultiBookingEnabled ?? this.isMultiBookingEnabled,
      maxBookings: maxBookings ?? this.maxBookings,
      bookingCount: bookingCount ?? this.bookingCount,
      isAlreadyBookedByCurrentUser:
          isAlreadyBookedByCurrentUser ?? this.isAlreadyBookedByCurrentUser,
      isAvailable: isAvailable ?? _explicitIsAvailable,
      remaining: remaining ?? _explicitRemaining,
    );
  }

  Map<String, dynamic> toMap() => {
    'isMultiBookingEnabled': isMultiBookingEnabled,
    'maxBookings': maxBookings,
    'bookingCount': bookingCount,
    'remaining': remaining,
    'isAvailable': isAvailable,
    'isAlreadyBookedByCurrentUser': isAlreadyBookedByCurrentUser,
    'isSelectable': isSelectable,
    'capacityLabel': capacityLabel,
  };

  @override
  String toString() =>
      'SlotCapacity(multiBooking=$isMultiBookingEnabled, '
      '$bookingCount/$maxBookings, available=$isAvailable, remaining=$remaining, '
      'alreadyBookedByCurrentUser=$isAlreadyBookedByCurrentUser, isSelectable=$isSelectable)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Standalone helper (mirrors the example in the spec)
// ─────────────────────────────────────────────────────────────────────────────

/// Centralised availability decision.
///
/// ```text
/// Multi-booking disabled  → always true  (existing overlap logic decides)
/// Multi-booking enabled   → bookingCount < maxBookings
/// ```
bool isSlotAvailable({
  required int  bookingCount,
  required int  maxBookings,
  required bool isMultiBookingEnabled,
  bool? isAvailableOverride,
}) {
  if (isAvailableOverride != null) return isAvailableOverride;
  if (!isMultiBookingEnabled) return true;
  return bookingCount < maxBookings;
}

// ── Private helpers ───────────────────────────────────────────────────────────

int? _parseInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}
