import 'package:intl/intl.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';

/// Utilities for enforcing customer booking date constraints.
///
/// Requirement:
/// Customer may only book from TODAY through TODAY + 14 DAYS (inclusive).
class BookingDateUtils {
  BookingDateUtils._();

  /// Maximum future days allowed from today (14 days).
  static const int maxBookingDaysAhead = 14;

  /// User-facing validation error message.
  static const String invalidDateMessage =
      'Please select a date within the next 14 days.';

  /// Optional custom current time for unit tests.
  static DateTime? customNow;

  /// Optional flag to disable 14-day date range restriction in UI/widget unit tests.
  static bool disableDateRangeValidationForTesting = false;

  /// Optional store timezone offset for store-localized calendar comparisons.
  /// When not null, [getStoreNow] adjusts UTC time by this offset instead of device local time.
  static Duration? storeTimeZoneOffset;

  /// Returns normalized today (00:00:00.000).
  static DateTime get minAllowedDate {
    if (disableDateRangeValidationForTesting) return DateTime(2000, 1, 1);
    final now = customNow ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Returns normalized max allowed booking date (today + 14 days).
  static DateTime get maxAllowedDate {
    if (disableDateRangeValidationForTesting) return DateTime(2100, 1, 1);
    final today = minAllowedDate;
    return DateTime(today.year, today.month, today.day + maxBookingDaysAhead);
  }

  /// Normalizes any [DateTime] to start of day (midnight) for accurate date comparisons.
  static DateTime normalize(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Parses a calendar date representation (DateTime, 'YYYY-MM-DD', ISO string)
  /// into a pure local calendar [DateTime] at midnight (00:00:00).
  ///
  /// CRITICAL: This avoids timezone shifts (e.g. UTC midnight shifting to previous day).
  static DateTime? parseCalendarDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) {
      return DateTime(raw.year, raw.month, raw.day);
    }
    final str = raw.toString().trim();
    if (str.isEmpty) return null;

    final norm = normalizeDateString(str);
    if (norm != null) {
      final parts = norm.split('-');
      if (parts.length >= 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) {
          return DateTime(y, m, d);
        }
      }
    }

    final dt = DateTime.tryParse(str);
    if (dt != null) {
      return DateTime(dt.year, dt.month, dt.day);
    }
    return null;
  }

  /// Checks whether two calendar dates represent the same year, month, and day.
  ///
  /// Compares ONLY year + month + day (ignores hours, minutes, seconds).
  static bool isSameCalendarDay(dynamic a, dynamic b) {
    final parsedA = parseCalendarDate(a);
    final parsedB = parseCalendarDate(b);
    if (parsedA == null || parsedB == null) return false;
    return parsedA.year == parsedB.year &&
        parsedA.month == parsedB.month &&
        parsedA.day == parsedB.day;
  }

  /// Checks whether [date] is the device's local Today.
  /// Compares ONLY year + month + day against [referenceDate] (defaults to DateTime.now()).
  static bool isToday(dynamic date, [DateTime? referenceDate]) {
    final ref = referenceDate ?? customNow ?? DateTime.now();
    return isSameCalendarDay(date, ref);
  }

  /// Extracts timezone offset from an ISO 8601 string if present (e.g. "+05:30", "-05:00", "Z").
  static Duration? extractTimeZoneOffset(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim();
    if (str.isEmpty) return null;

    if (str.endsWith('Z') || str.endsWith('z')) {
      return Duration.zero;
    }

    // Pure date strings like "2026-10-20" or "10/20/2026" do NOT have a timezone offset
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(str) ||
        RegExp(r'^\d{1,2}/\d{1,2}/\d{4}$').hasMatch(str)) {
      return null;
    }

    final match = RegExp(r'(?:(?:T|\s)\d{1,2}:\d{2}(?::\d{2})?(?:\.\d+)?|^)\s*([+-])(\d{2}):?(\d{2})?$').firstMatch(str);
    if (match != null) {
      final sign = match.group(1) == '-' ? -1 : 1;
      final hours = int.tryParse(match.group(2) ?? '0') ?? 0;
      final minutes = int.tryParse(match.group(3) ?? '0') ?? 0;
      if (hours <= 14 && minutes < 60) {
        return Duration(minutes: sign * (hours * 60 + minutes));
      }
    }

    return null;
  }

  /// Returns the current DateTime in the store / appointment's local timezone.
  ///
  /// Precedence:
  /// 1. [referenceDate] (explicit override, e.g. for testing)
  /// 2. [customNow] (global testing hook)
  /// 3. [timeZoneOffset] (explicit timezone offset parameter)
  /// 4. Timezone offset extracted from [bookingDate] (e.g. from an ISO 8601 string)
  /// 5. [storeTimeZoneOffset] (configured store timezone offset)
  /// 6. Device's [DateTime.now()]
  static DateTime getStoreNow({
    DateTime? referenceDate,
    Duration? timeZoneOffset,
    dynamic bookingDate,
  }) {
    if (referenceDate != null) return referenceDate;
    if (customNow != null) return customNow!;

    final offset = timeZoneOffset ??
        extractTimeZoneOffset(bookingDate) ??
        storeTimeZoneOffset;

    if (offset != null) {
      return DateTime.now().toUtc().add(offset);
    }

    return DateTime.now();
  }

  /// Checks whether [bookingDate] is on its scheduled calendar day in the store/appointment timezone.
  static bool isBookingDateToday(
    dynamic bookingDate, {
    DateTime? referenceDate,
    Duration? timeZoneOffset,
  }) {
    if (bookingDate == null) return false;
    final ref = getStoreNow(
      referenceDate: referenceDate,
      timeZoneOffset: timeZoneOffset,
      bookingDate: bookingDate,
    );
    return isSameCalendarDay(bookingDate, ref);
  }

  /// Checks whether current store time is strictly before the appointment [bookingDate].
  static bool isBeforeBookingDate(
    dynamic bookingDate, {
    DateTime? referenceDate,
    Duration? timeZoneOffset,
  }) {
    if (bookingDate == null) return false;
    final parsedBooking = parseCalendarDate(bookingDate);
    if (parsedBooking == null) return false;

    final ref = getStoreNow(
      referenceDate: referenceDate,
      timeZoneOffset: timeZoneOffset,
      bookingDate: bookingDate,
    );
    final refDay = DateTime(ref.year, ref.month, ref.day);
    final bookingDay = DateTime(parsedBooking.year, parsedBooking.month, parsedBooking.day);

    return refDay.isBefore(bookingDay);
  }

  /// Checks whether current store time is strictly after the appointment [bookingDate].
  static bool isAfterBookingDate(
    dynamic bookingDate, {
    DateTime? referenceDate,
    Duration? timeZoneOffset,
  }) {
    if (bookingDate == null) return false;
    final parsedBooking = parseCalendarDate(bookingDate);
    if (parsedBooking == null) return false;

    final ref = getStoreNow(
      referenceDate: referenceDate,
      timeZoneOffset: timeZoneOffset,
      bookingDate: bookingDate,
    );
    final refDay = DateTime(ref.year, ref.month, ref.day);
    final bookingDay = DateTime(parsedBooking.year, parsedBooking.month, parsedBooking.day);

    return refDay.isAfter(bookingDay);
  }

  /// Evaluates whether check-in is allowed based strictly on appointment booking date.
  /// Allowed ONLY on the booking date in the store/appointment timezone.
  static bool isCheckInDateAllowed(
    dynamic bookingDate, {
    DateTime? referenceDate,
    Duration? timeZoneOffset,
  }) {
    return isBookingDateToday(
      bookingDate,
      referenceDate: referenceDate,
      timeZoneOffset: timeZoneOffset,
    );
  }

  /// Formats a booking date for UI display:
  /// - If [date] is today (same calendar day): "Today, 24 Sep 2026"
  /// - For any other date: "25 Sep 2026" (d MMM yyyy)
  static String formatBookingDateDisplay(dynamic date, [DateTime? referenceDate]) {
    if (date == null) return '';
    final parsed = parseCalendarDate(date);
    if (parsed == null) return date.toString();

    final formatted = DateFormat('d MMM yyyy').format(parsed);
    if (isToday(parsed, referenceDate)) {
      return 'Today, $formatted';
    }
    return formatted;
  }

  /// Returns true if [date] is within [minAllowedDate, maxAllowedDate] inclusive.
  static bool isDateAllowed(DateTime? date) {
    if (date == null) return false;
    if (disableDateRangeValidationForTesting) return true;
    final norm = normalize(date);
    final min = minAllowedDate;
    final max = maxAllowedDate;
    return !norm.isBefore(min) && !norm.isAfter(max);
  }

  /// Validates a [DateTime] or throws an [ArgumentError] with [invalidDateMessage].
  static void validateDate(DateTime? date) {
    if (!isDateAllowed(date)) {
      throw ArgumentError(invalidDateMessage);
    }
  }

  /// Validates a date string (yyyy-MM-dd) or throws an [ArgumentError] with [invalidDateMessage].
  static void validateDateString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      throw ArgumentError(invalidDateMessage);
    }
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null || !isDateAllowed(parsed)) {
      throw ArgumentError(invalidDateMessage);
    }
  }

  /// Formats date to 'yyyy-MM-dd'.
  static String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Finds the first available date starting from [preferredStart] or [minAllowedDate]
  /// that satisfies:
  /// 1. Within allowed 14-day booking window.
  /// 2. Not unavailable according to [isDateUnavailable] callback (holiday / closed).
  static DateTime findFirstAvailableDate({
    required bool Function(DateTime) isDateUnavailable,
    DateTime? preferredStart,
  }) {
    if (preferredStart != null && isDateAllowed(preferredStart) && !isDateUnavailable(preferredStart)) {
      return normalize(preferredStart);
    }

    for (int dayOffset = 0; dayOffset <= maxBookingDaysAhead; dayOffset++) {
      final candidate = DateTime(minAllowedDate.year, minAllowedDate.month, minAllowedDate.day + dayOffset);
      if (!isDateUnavailable(candidate)) {
        return candidate;
      }
    }

    return minAllowedDate;
  }

  // ── Date & Time String Normalization Helpers ─────────────────────────────

  /// Normalizes any date representation (DateTime, ISO string, 'yyyy-MM-dd', 'MM/dd/yyyy')
  /// to a standard 'yyyy-MM-dd' string.
  static String? normalizeDateString(dynamic date) {
    if (date == null) return null;
    if (date is DateTime) {
      return '${date.year.toString().padLeft(4, "0")}-${date.month.toString().padLeft(2, "0")}-${date.day.toString().padLeft(2, "0")}';
    }
    final str = date.toString().trim();
    if (str.isEmpty) return null;

    if (str.contains('T')) {
      final datePart = str.split('T').first;
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(datePart)) {
        return datePart;
      }
    }

    if (str.contains(' ') && str.contains('-')) {
      final datePart = str.split(' ').first;
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(datePart)) {
        return datePart;
      }
    }

    if (str.contains('/')) {
      final parts = str.split('/');
      if (parts.length == 3) {
        if (parts[2].length == 4) {
          // MM/DD/YYYY
          final m = parts[0].padLeft(2, '0');
          final d = parts[1].padLeft(2, '0');
          final y = parts[2];
          return '$y-$m-$d';
        } else if (parts[0].length == 4) {
          // YYYY/MM/DD
          final y = parts[0];
          final m = parts[1].padLeft(2, '0');
          final d = parts[2].padLeft(2, '0');
          return '$y-$m-$d';
        }
      }
    }

    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(str)) {
      return str;
    }

    final parsed = DateTime.tryParse(str);
    if (parsed != null) {
      return '${parsed.year.toString().padLeft(4, "0")}-${parsed.month.toString().padLeft(2, "0")}-${parsed.day.toString().padLeft(2, "0")}';
    }

    return str;
  }

  /// Normalizes any time representation ('09:00', '9:00', '09:00:00', '9:00 AM', ISO)
  /// to a standard 24-hour 'HH:mm' string.
  static String? normalizeTimeString(dynamic time) {
    if (time == null) return null;
    String str = time.toString().trim();
    if (str.isEmpty) return null;

    if (str.contains('T')) {
      str = str.split('T').last;
    } else if (str.contains(' ') && (str.contains('-') || str.contains('/'))) {
      str = str.split(' ').last;
    }

    final upper = str.toUpperCase();
    if (upper.contains('AM') || upper.contains('PM')) {
      final isPm = upper.contains('PM');
      final clean = upper.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = clean.split(':');
      if (parts.isNotEmpty) {
        int h = int.tryParse(parts[0]) ?? 0;
        final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
        if (isPm && h < 12) h += 12;
        if (!isPm && h == 12) h = 0;
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      }
    }

    final parts = str.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    }

    return str;
  }

  /// Converts a time representation to total minutes since midnight (0..1439).
  static int? timeToMinutes(dynamic time) {
    if (time == null) return null;
    final normalized = normalizeTimeString(time);
    if (normalized == null) return null;
    final parts = normalized.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// Returns true if two time representations point to the exact same hour and minute.
  static bool isSameTimeSlot(dynamic a, dynamic b) {
    if (a == null || b == null) return false;
    final normA = normalizeTimeString(a);
    final normB = normalizeTimeString(b);
    if (normA == null || normB == null) return false;
    return normA == normB;
  }

  /// Formats any time representation to 12-hour display, e.g. "09:00" → "9:00 AM".
  static String format12Hour(dynamic time) {
    if (time == null) return '';
    final norm = normalizeTimeString(time);
    if (norm == null) return time.toString();
    final parts = norm.split(':');
    if (parts.length < 2) return norm;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final period = h < 12 ? 'AM' : 'PM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayH:${m.toString().padLeft(2, '0')} $period';
  }

  /// Resolves the canonical salon booking/availability groomer ID (1..4)
  /// from any groomer representation (portal database ID, groomerCode, or name).
  ///
  /// Background:
  /// The salon's booking and availability engine (/api/availability, /api/bookings)
  /// indexes the core salon staff by canonical catalog IDs:
  ///   1: Merisa Brown (Lead Groomer, code: G001)
  ///   2: Richard Cooke (Senior Groomer, code: G002)
  ///   3: Tracie Jamison (Groomer, code: G003)
  ///   4: Jeremiah Smith (Junior Bather, code: B001)
  ///
  /// In the groomer portal auth/admin database, re-registered or newly created groomer
  /// accounts may receive higher auto-increment IDs (e.g. Merisa Brown = 11, code G001).
  /// This method maps all representations to the canonical ID expected by the booking engine.
  static int? resolveCanonicalGroomerId(
    dynamic groomerId, {
    String? groomerCode,
    String? groomerName,
    Map<String, int>? dynamicGroomerMap,
  }) {
    if (groomerId == null && groomerCode == null && groomerName == null) return null;

    final idInt = groomerId is int
        ? groomerId
        : (int.tryParse(groomerId?.toString() ?? '') ?? 0);

    // 1. Dynamic groomer map match (populated directly from API response)
    if (dynamicGroomerMap != null && dynamicGroomerMap.isNotEmpty) {
      final cleanName = (groomerName ?? '').toLowerCase().trim();
      if (cleanName.isNotEmpty && dynamicGroomerMap.containsKey(cleanName)) {
        return dynamicGroomerMap[cleanName];
      }
      final cleanCode = (groomerCode ?? '').toUpperCase().trim();
      if (cleanCode.isNotEmpty && dynamicGroomerMap.containsKey(cleanCode)) {
        return dynamicGroomerMap[cleanCode];
      }
      if (idInt > 0 && dynamicGroomerMap.containsKey(idInt.toString())) {
        return dynamicGroomerMap[idInt.toString()];
      }
    }

    // 2. Dynamic store repository catalog match (from GET /api/groomers)
    try {
      final cached = ServicesLocator.storeRepository.cachedGroomers;
      if (cached.isNotEmpty) {
        final cleanName = (groomerName ?? '').toLowerCase().trim();
        final cleanCode = (groomerCode ?? '').toUpperCase().trim();
        for (final g in cached) {
          final gName = (g['name'] ?? '').toString().toLowerCase().trim();
          final gCode = (g['groomerCode'] ?? g['GroomerId'] ?? g['BatherId'] ?? '')
              .toString()
              .toUpperCase()
              .trim();
          final gId = int.tryParse(g['id']?.toString() ?? '');
          if (gId != null && gId > 0) {
            if (cleanCode.isNotEmpty && gCode.isNotEmpty && cleanCode == gCode) {
              return gId;
            }
            if (cleanName.isNotEmpty && gName.isNotEmpty &&
                (cleanName == gName || cleanName.contains(gName) || gName.contains(cleanName))) {
              return gId;
            }
          }
        }
      }
    } catch (_) {}

    // 3. Dynamic groomer code extraction (e.g. G001 -> 1, B001 -> 4)
    final cleanCode = (groomerCode ?? '').toUpperCase().trim();
    if (cleanCode.isNotEmpty) {
      final digits = cleanCode.replaceAll(RegExp(r'[^0-9]'), '');
      final numVal = int.tryParse(digits);
      if (numVal != null && numVal > 0) {
        if (cleanCode.startsWith('B')) {
          return numVal + 3; // Bathers follow groomers (B001 -> 4)
        }
        return numVal; // G001 -> 1, G002 -> 2, etc.
      }
    }

    // 4. Catalog range ID (1-4 are valid catalog IDs)
    if (idInt >= 1 && idInt <= 4) {
      return idInt;
    }

    // 5. Fallback name-based token match against known catalog roles/names
    final cleanName = (groomerName ?? '').toLowerCase().trim();
    if (cleanName.contains('merisa') || cleanName.contains('brown')) {
      return 1;
    }
    if (cleanName.contains('richard') || cleanName.contains('cooke')) {
      return 2;
    }
    if (cleanName.contains('tracie') || cleanName.contains('jamison')) {
      return 3;
    }
    if (cleanName.contains('jeremiah') || cleanName.contains('smith')) {
      return 4;
    }

    // 6. Fallback known ID mapping
    if (idInt == 11) return 1;

    return idInt > 0 ? idInt : null;
  }

  /// Resolves the human-readable groomer name from a catalog/numeric groomer ID.
  static String? resolveGroomerNameById(int id) {
    if (id <= 0) return null;
    try {
      final cached = ServicesLocator.storeRepository.cachedGroomers;
      for (final g in cached) {
        final gid = int.tryParse(g['id']?.toString() ?? g['groomerId']?.toString() ?? '');
        if (gid == id) {
          final name = (g['name'] ?? '${g['firstName'] ?? ''} ${g['lastName'] ?? ''}').toString().trim();
          if (name.isNotEmpty) return name;
        }
      }
    } catch (_) {}
    switch (id) {
      case 1:
        return 'Merisa Brown';
      case 2:
        return 'Richard Cooke';
      case 3:
        return 'Tracie Jamison';
      case 4:
        return 'Jeremiah Smith';
      default:
        return null;
    }
  }

  /// Safely deduplicates a list of time slot maps while preserving original order and capacity rules.
  ///
  /// - Normalizes all startTime and endTime values to standard 'HH:mm'.
  /// - In "all/any groomers" context ([specificGroomerId] is null or <= 0), distinct start times appear exactly once.
  ///   If multiple groomers provide the same slot, availability is merged (available if ANY groomer is available,
  ///   maximum remaining capacity).
  /// - In specific groomer context ([specificGroomerId] > 0), deduplicates identical slots for that groomer.
  static List<Map<String, dynamic>> deduplicateSlots(
    List<dynamic> rawSlots, {
    int? specificGroomerId,
  }) {
    final Map<String, Map<String, dynamic>> deduped = {};

    for (final raw in rawSlots) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final rawStart = map['startTime']?.toString() ?? '';
      final normStart = normalizeTimeString(rawStart);
      if (normStart == null) continue;

      final rawEnd = map['endTime']?.toString() ?? '';
      final normEnd = normalizeTimeString(rawEnd) ?? rawEnd;

      map['startTime'] = normStart;
      map['endTime'] = normEnd;

      final slotGroomId = map['groomerId']?.toString() ?? '';
      final String key = (specificGroomerId != null && specificGroomerId > 0)
          ? '$normStart-$slotGroomId'
          : normStart;

      if (!deduped.containsKey(key)) {
        deduped[key] = map;
      } else {
        final existing = deduped[key]!;
        final bool existingAvail = existing['isAvailable'] != false;
        final bool newAvail = map['isAvailable'] != false;

        final int existingRem = existing['remaining'] is num
            ? (existing['remaining'] as num).toInt()
            : (int.tryParse(existing['remaining']?.toString() ?? '1') ?? 1);
        final int newRem = map['remaining'] is num
            ? (map['remaining'] as num).toInt()
            : (int.tryParse(map['remaining']?.toString() ?? '1') ?? 1);

        if (specificGroomerId == null || specificGroomerId <= 0) {
          // Salon-wide ("Any Groomer") aggregation
          final bool mergedAvail = existingAvail || newAvail;
          final int mergedRem = existingRem > newRem ? existingRem : newRem;

          if (!existingAvail && newAvail) {
            deduped[key] = map;
          }
          deduped[key]!['isAvailable'] = mergedAvail;
          deduped[key]!['remaining'] = mergedRem;
        } else {
          // Specific groomer duplicate from API
          if (!existingAvail && newAvail) {
            deduped[key] = map;
          } else if (newRem > existingRem) {
            deduped[key] = map;
          }
        }
      }
    }

    return deduped.values.toList();
  }

  /// Checks whether a booking status from the user's booking history is considered
  /// an active / slot-occupying booking.
  ///
  /// Active statuses: pending, confirmed, cancellation_requested, in_progress, scheduled, accepted (or empty).
  /// Inactive statuses: cancelled, canceled, rejected, completed, expired.
  static bool isBookingActive(Map<dynamic, dynamic> booking) {
    final status = (booking['status'] ?? booking['Status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (status == 'cancelled' ||
        status == 'canceled' ||
        status == 'rejected' ||
        status == 'completed' ||
        status == 'expired') {
      return false;
    }
    return true;
  }

  /// Parses groomerId from various possible keys in a booking object.
  static int? parseGroomerId(Map<dynamic, dynamic> booking) {
    final raw = booking['groomerId'] ??
        booking['GroomerId'] ??
        booking['groomer_id'] ??
        (booking['groomer'] is Map ? booking['groomer']['id'] : null);
    if (raw == null) return null;
    if (raw is int) return raw;
    return int.tryParse(raw.toString());
  }

  /// Extracts pet ID from a booking object map.
  static int? parsePetIdFromBooking(Map<dynamic, dynamic> booking) {
    final nested = booking['pet'] ??
        booking['Pet'] ??
        booking['petData'] ??
        booking['pet_data'] ??
        booking['petProfile'] ??
        booking['pet_profile'] ??
        booking['PetProfile'] ??
        booking['petInfo'] ??
        booking['pet_info'] ??
        booking['PetInfo'];
    if (nested is Map) {
      final rawNested = nested['id'] ??
          nested['petId'] ??
          nested['pet_id'] ??
          nested['PetId'] ??
          nested['pet_ID'];
      if (rawNested is int && rawNested > 0) return rawNested;
      final parsed = int.tryParse(rawNested?.toString().trim() ?? '');
      if (parsed != null && parsed > 0) return parsed;
    }

    final raw = booking['petId'] ??
        booking['pet_id'] ??
        booking['PetId'] ??
        booking['pet_ID'] ??
        booking['petID'] ??
        booking['_id'] ??
        booking['id'];
    if (raw is int && raw > 0) return raw;
    final parsed = int.tryParse(raw?.toString().trim() ?? '');
    if (parsed != null && parsed > 0) return parsed;

    return null;
  }

  /// Extracts pet ID from a pet map (e.g. `_draft.pet`).
  static int? parsePetIdFromPet(Map<dynamic, dynamic>? pet) {
    if (pet == null) return null;
    final raw = pet['id'] ??
        pet['_id'] ??
        pet['petId'] ??
        pet['pet_id'] ??
        pet['PetId'] ??
        pet['pet_ID'] ??
        pet['petID'];
    if (raw is int && raw > 0) return raw;
    final parsed = int.tryParse(raw?.toString().trim() ?? '');
    if (parsed != null && parsed > 0) return parsed;
    return null;
  }

  /// Extracts pet name from a booking object.
  static String parsePetNameFromBooking(Map<dynamic, dynamic> booking) {
    final nested = booking['pet'] ??
        booking['Pet'] ??
        booking['petData'] ??
        booking['pet_data'] ??
        booking['petProfile'] ??
        booking['pet_profile'] ??
        booking['PetProfile'] ??
        booking['petInfo'] ??
        booking['pet_info'] ??
        booking['PetInfo'];
    if (nested is Map) {
      final n = (nested['pet_name'] ??
              nested['petName'] ??
              nested['name'] ??
              nested['PetName'])
          ?.toString()
          .trim();
      if (n != null && n.isNotEmpty && n.toLowerCase() != 'null') return n;
    }

    final direct = (booking['petName'] ??
            booking['pet_name'] ??
            booking['PetName'] ??
            booking['name'])
        ?.toString()
        .trim();
    if (direct != null &&
        direct.isNotEmpty &&
        direct.toLowerCase() != 'null') {
      return direct;
    }
    return '';
  }

  /// Extracts pet name from a pet map.
  static String parsePetNameFromPet(Map<dynamic, dynamic>? pet) {
    if (pet == null) return '';
    final direct = (pet['pet_name'] ??
            pet['petName'] ??
            pet['name'] ??
            pet['PetName'])
        ?.toString()
        .trim();
    if (direct != null &&
        direct.isNotEmpty &&
        direct.toLowerCase() != 'null') {
      return direct;
    }
    return '';
  }

  /// Checks whether a booking matches the given target pet (by ID or fallback to name).
  static bool isBookingForSamePet({
    required Map<dynamic, dynamic> booking,
    int? targetPetId,
    String? targetPetName,
  }) {
    final bPetId = parsePetIdFromBooking(booking);
    if (targetPetId != null && targetPetId > 0 && bPetId != null && bPetId > 0) {
      return bPetId == targetPetId;
    }

    final bPetName = parsePetNameFromBooking(booking).trim().toLowerCase();
    final tName = (targetPetName ?? '').trim().toLowerCase();

    if (tName.isNotEmpty && bPetName.isNotEmpty && tName != 'null' && bPetName != 'null') {
      return bPetName == tName;
    }

    return false;
  }

  /// User-facing warning message for duplicate pet bookings with another groomer.
  static const String duplicatePetBookingWarningMessage =
      'This pet already has a booking with another groomer during this time slot. Do you want to continue?';

  /// User-facing validation error message for conflicting pet bookings (legacy reference).
  static const String duplicatePetBookingMessage =
      'This pet already has a booking with another groomer during this time slot. Do you want to continue?';

  /// Finds an active booking for the target pet that overlaps with the candidate
  /// slot on the given date across ANY groomer.
  ///
  /// Criteria for conflict:
  /// 1. Booking status is active (pending, confirmed, in_progress, etc. — NOT cancelled/rejected).
  /// 2. Booking is for the same pet (matching petId or petName).
  /// 3. Booking date matches [slotDate] ('yyyy-MM-dd').
  /// 4. Time ranges overlap: [sStartMin, sEndMin) overlaps [bStartMin, bEndMin).
  ///
  /// Returns the conflicting booking map if found, or null otherwise.
  static Map<String, dynamic>? findConflictingBookingForPet({
    required dynamic slotDate,
    required dynamic slotStartTime,
    dynamic slotEndTime,
    int? slotDurationMinutes,
    int? targetPetId,
    String? targetPetName,
    required List<Map<String, dynamic>> userBookings,
    int? excludeBookingId,
  }) {
    if (userBookings.isEmpty) return null;

    final normSlotDate = normalizeDateString(slotDate);
    if (normSlotDate == null || normSlotDate.isEmpty) return null;

    final normSlotStart = normalizeTimeString(slotStartTime);
    if (normSlotStart == null) return null;

    final sStartMin = timeToMinutes(normSlotStart);
    if (sStartMin == null) return null;

    final dur = (slotDurationMinutes != null && slotDurationMinutes > 0)
        ? slotDurationMinutes
        : 60;

    final normSlotEnd = normalizeTimeString(slotEndTime) ??
        normalizeTimeString(
            '${(sStartMin + dur) ~/ 60}:${((sStartMin + dur) % 60).toString().padLeft(2, '0')}');

    final sEndMin = normSlotEnd != null
        ? (timeToMinutes(normSlotEnd) ?? (sStartMin + dur))
        : (sStartMin + dur);

    if (sStartMin >= sEndMin) return null;

    for (final b in userBookings) {
      if (!isBookingActive(b)) continue;

      if (excludeBookingId != null && excludeBookingId > 0) {
        final rawId = b['bookingId'] ?? b['id'] ?? b['booking_id'];
        final bId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
        if (bId == excludeBookingId) continue;
      }

      final bDateRaw =
          b['bookingDate'] ?? b['BookingDate'] ?? b['date'] ?? b['booking_date'];
      final normBDate = normalizeDateString(bDateRaw);
      if (normBDate == null || normBDate.isEmpty || normBDate != normSlotDate) {
        continue;
      }

      final matchesPet = isBookingForSamePet(
        booking: b,
        targetPetId: targetPetId,
        targetPetName: targetPetName,
      );
      if (!matchesPet) continue;

      final bStartRaw = b['startTime'] ?? b['StartTime'] ?? b['start_time'];
      final bEndRaw = b['endTime'] ?? b['EndTime'] ?? b['end_time'];

      final normBStart = normalizeTimeString(bStartRaw);
      final normBEnd = normalizeTimeString(bEndRaw);

      if (normBStart == null) continue;
      final bStartMin = timeToMinutes(normBStart);
      if (bStartMin == null) continue;

      final bEndMin = normBEnd != null
          ? (timeToMinutes(normBEnd) ?? (bStartMin + dur))
          : (bStartMin + dur);

      if (bStartMin >= bEndMin) continue;

      // Overlap condition: startA < endB && endA > startB
      if (sStartMin < bEndMin && sEndMin > bStartMin) {
        return b;
      }
    }

    return null;
  }

  /// Finds an active booking for the target pet that overlaps with the candidate
  /// slot on the given date with another groomer.
  static Map<String, dynamic>? findConflictingBookingForPetWithAnotherGroomer({
    required dynamic slotDate,
    required dynamic slotStartTime,
    dynamic slotEndTime,
    int? slotDurationMinutes,
    dynamic slotGroomerId,
    int? targetPetId,
    String? targetPetName,
    required List<Map<String, dynamic>> userBookings,
    int? excludeBookingId,
  }) {
    if (userBookings.isEmpty) return null;

    final normSlotDate = normalizeDateString(slotDate);
    if (normSlotDate == null || normSlotDate.isEmpty) return null;

    final normSlotStart = normalizeTimeString(slotStartTime);
    if (normSlotStart == null) return null;

    final sStartMin = timeToMinutes(normSlotStart);
    if (sStartMin == null) return null;

    final dur = (slotDurationMinutes != null && slotDurationMinutes > 0)
        ? slotDurationMinutes
        : 60;

    final normSlotEnd = normalizeTimeString(slotEndTime) ??
        normalizeTimeString(
            '${(sStartMin + dur) ~/ 60}:${((sStartMin + dur) % 60).toString().padLeft(2, '0')}');

    final sEndMin = normSlotEnd != null
        ? (timeToMinutes(normSlotEnd) ?? (sStartMin + dur))
        : (sStartMin + dur);

    if (sStartMin >= sEndMin) return null;

    final int? targetGroomId = slotGroomerId is int
        ? slotGroomerId
        : (slotGroomerId != null
            ? int.tryParse(slotGroomerId.toString())
            : null);

    for (final b in userBookings) {
      if (!isBookingActive(b)) continue;

      if (excludeBookingId != null && excludeBookingId > 0) {
        final rawId = b['bookingId'] ?? b['id'] ?? b['booking_id'];
        final bId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
        if (bId == excludeBookingId) continue;
      }

      final bDateRaw =
          b['bookingDate'] ?? b['BookingDate'] ?? b['date'] ?? b['booking_date'];
      final normBDate = normalizeDateString(bDateRaw);
      if (normBDate == null || normBDate.isEmpty || normBDate != normSlotDate) {
        continue;
      }

      final matchesPet = isBookingForSamePet(
        booking: b,
        targetPetId: targetPetId,
        targetPetName: targetPetName,
      );
      if (!matchesPet) continue;

      // If slot specifies a groomer and existing booking is with the same groomer,
      // it is handled as same-groomer duplicate, not "another groomer".
      if (targetGroomId != null && targetGroomId > 0) {
        final bGroomId = parseGroomerId(b);
        if (bGroomId != null && bGroomId > 0 && bGroomId == targetGroomId) {
          continue;
        }
      }

      final bStartRaw = b['startTime'] ?? b['StartTime'] ?? b['start_time'];
      final bEndRaw = b['endTime'] ?? b['EndTime'] ?? b['end_time'];

      final normBStart = normalizeTimeString(bStartRaw);
      final normBEnd = normalizeTimeString(bEndRaw);

      if (normBStart == null) continue;
      final bStartMin = timeToMinutes(normBStart);
      if (bStartMin == null) continue;

      final bEndMin = normBEnd != null
          ? (timeToMinutes(normBEnd) ?? (bStartMin + dur))
          : (bStartMin + dur);

      if (bStartMin >= bEndMin) continue;

      // Overlap condition: startA < endB && endA > startB
      if (sStartMin < bEndMin && sEndMin > bStartMin) {
        return b;
      }
    }

    return null;
  }

  /// Convenience boolean check for pet booking conflict.
  static bool isSlotAlreadyBookedForPet({
    required dynamic slotDate,
    required dynamic slotStartTime,
    dynamic slotEndTime,
    int? slotDurationMinutes,
    int? targetPetId,
    String? targetPetName,
    required List<Map<String, dynamic>> userBookings,
    int? excludeBookingId,
  }) {
    return findConflictingBookingForPet(
          slotDate: slotDate,
          slotStartTime: slotStartTime,
          slotEndTime: slotEndTime,
          slotDurationMinutes: slotDurationMinutes,
          targetPetId: targetPetId,
          targetPetName: targetPetName,
          userBookings: userBookings,
          excludeBookingId: excludeBookingId,
        ) !=
        null;
  }

  /// Checks whether the current user has already booked this slot with the SAME groomer.
  /// (Different groomers remain selectable so warning dialog can be displayed).
  static bool isSlotAlreadyBookedByUser({
    required dynamic slotDate,
    required dynamic slotStartTime,
    dynamic slotEndTime,
    dynamic slotGroomerId,
    int? slotDurationMinutes,
    int? targetPetId,
    String? targetPetName,
    required List<Map<String, dynamic>> userBookings,
    int? excludeBookingId,
  }) {
    if (userBookings.isEmpty) return false;

    final normSlotDate = normalizeDateString(slotDate);
    if (normSlotDate == null || normSlotDate.isEmpty) return false;

    final normSlotStart = normalizeTimeString(slotStartTime);
    if (normSlotStart == null) return false;

    final sStartMin = timeToMinutes(normSlotStart);
    if (sStartMin == null) return false;

    final dur = (slotDurationMinutes != null && slotDurationMinutes > 0)
        ? slotDurationMinutes
        : 60;

    final normSlotEnd = normalizeTimeString(slotEndTime) ??
        normalizeTimeString(
            '${(sStartMin + dur) ~/ 60}:${((sStartMin + dur) % 60).toString().padLeft(2, '0')}');

    final sEndMin = normSlotEnd != null
        ? (timeToMinutes(normSlotEnd) ?? (sStartMin + dur))
        : (sStartMin + dur);

    final int? targetGroomId = slotGroomerId is int
        ? slotGroomerId
        : (slotGroomerId != null
            ? int.tryParse(slotGroomerId.toString())
            : null);

    for (final b in userBookings) {
      if (!isBookingActive(b)) continue;

      if (excludeBookingId != null && excludeBookingId > 0) {
        final rawId = b['bookingId'] ?? b['id'] ?? b['booking_id'];
        final bId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
        if (bId == excludeBookingId) continue;
      }

      final bDateRaw =
          b['bookingDate'] ?? b['BookingDate'] ?? b['date'] ?? b['booking_date'];
      final normBDate = normalizeDateString(bDateRaw);
      if (normBDate != null && normBDate.isNotEmpty && normBDate != normSlotDate) {
        continue;
      }

      if (targetGroomId != null && targetGroomId > 0) {
        final bGroomId = parseGroomerId(b);
        if (bGroomId != null && bGroomId > 0 && bGroomId != targetGroomId) {
          continue;
        }
      }

      final bStartRaw = b['startTime'] ?? b['StartTime'] ?? b['start_time'];
      final bEndRaw = b['endTime'] ?? b['EndTime'] ?? b['end_time'];

      final normBStart = normalizeTimeString(bStartRaw);
      final normBEnd = normalizeTimeString(bEndRaw);

      if (normBStart != null && normBStart == normSlotStart) {
        if (normBEnd == null || normSlotEnd == null || normBEnd == normSlotEnd) {
          return true;
        }
      }

      final bStartMin = timeToMinutes(normBStart);
      if (bStartMin == null) continue;

      final bEndMin = normBEnd != null
          ? (timeToMinutes(normBEnd) ?? (bStartMin + dur))
          : (bStartMin + dur);

      if (bStartMin < bEndMin &&
          sStartMin < sEndMin) {
        if (sStartMin < bEndMin && sEndMin > bStartMin) {
          return true;
        }
      }
    }

    return false;
  }
}
