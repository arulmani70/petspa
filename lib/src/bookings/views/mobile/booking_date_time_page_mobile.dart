import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/widgets/booking_bottom_bar.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/widgets/booking_header.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/shared_calendar.dart';
import 'package:shear_heaven_pet_spa/src/bookings/models/slot_capacity.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Slot state enum
// ─────────────────────────────────────────────────────────────────────────────
enum _SlotStatus {
  available,     // free / has capacity — can be booked
  booked,        // fully occupied (single-booking mode, slot taken)
  atCapacity,    // multi-booking enabled but slot limit reached (e.g. 3/3)
  alreadyBooked, // active booking already exists for the currently logged-in customer
  selected,      // currently chosen by the user
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal data model for a rendered slot
// ─────────────────────────────────────────────────────────────────────────────
class _Slot {
  final String       startTime;
  final String       endTime;
  final int?         groomerId;
  final String?      groomerName;
  final _SlotStatus  status;

  /// Capacity info — populated for every slot so the UI can show
  /// "2 / 3" labels when multi-booking is enabled.
  /// When the API does not (yet) provide per-slot booking counts this
  /// is a default SlotCapacity with bookingCount = 0, which is safe.
  final SlotCapacity capacity;

  const _Slot({
    required this.startTime,
    required this.endTime,
    this.groomerId,
    this.groomerName,
    required this.status,
    required this.capacity,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Page widget
// ─────────────────────────────────────────────────────────────────────────────
class BookingDateTimePageMobile extends StatefulWidget {
  const BookingDateTimePageMobile({super.key});

  @override
  State<BookingDateTimePageMobile> createState() =>
      _BookingDateTimePageMobileState();
}

class _BookingDateTimePageMobileState
    extends State<BookingDateTimePageMobile> {
  // ── design constants ───────────────────────────────────────────────────────
  static const Color _kBookedBg       = Color(0xFFF3F4F6);
  static const Color _kBookedFg       = Color(0xFFAFAFAF);
  static const Color _kSectionText    = Color(0xFF111827);
  static const Color _kSubText        = Color(0xFF6B7280);
  static const Color _kPageBg         = Color(0xFFFAFAFA);
  static const Color _kCardBg         = Color(0xFFFFFFFF);
  static const Color _kBorderLight    = Color(0xFFE5E7EB);
  static const Color _kTeal           = Color(0xFF0F766E);
  static const Color _kRed            = Color(0xFFE23232);
  static const Color _kAmber          = Color(0xFFD97706);

  // ── state ──────────────────────────────────────────────────────────────────
  late final BookingDraft _draft;
  final Logger _log = Logger();

  // Loading flags
  bool _loadingStep1 = false;   // POST /api/availability (duration + price)
  bool _loadingStep2 = false;   // GET  /api/groomer-availability

  // Store state from Step 2 response
  bool _storeClosed    = false;
  String? _holidayName;
  String? _storeOpenTime;   // e.g. "08:00"
  String? _storeCloseTime;  // e.g. "17:30"

  // Error state
  bool _slotsError = false;
  String? _slotsErrorMessage;

  // Groomer list (includes synthetic "No Preference" at index 0)
  List<Map<String, dynamic>> _groomerList = [];

  // Currently selected groomer ID ("any" = no preference)
  String _selectedGroomerId = 'any';

  // Slots to render — built from API response
  List<_Slot> _slots = [];

  // Booked slot raw data for the current groomer / all groomers
  List<Map<String, dynamic>> _bookedSlots = [];

  // Raw groomers from last Step 2 response (needed when user switches chips)
  List<dynamic> _rawGroomers = [];

  // Multi-booking slot capacity data from Step 1 POST /api/availability
  Map<String, Map<String, dynamic>> _step1SlotDataByStartTime = {};
  Map<String, int> _step1BookingCounts = {};

  // Active bookings for current authenticated customer (used strictly for duplicate booking validation)
  List<Map<String, dynamic>> _userActiveBookings = [];

  // ── lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _draft = ServicesLocator.bookingDraft;
    if (_draft.date == null || !BookingDateUtils.isDateAllowed(_draft.date)) {
      final firstAvail = BookingDateUtils.findFirstAvailableDate(
        isDateUnavailable: _isDateUnavailable,
      );
      _draft.setDate(firstAvail);
    }
    _loadSchedule();
    _loadAvailability();
  }

  Future<void> _loadSchedule() async {
    try {
      await Future.wait([
        ServicesLocator.storeRepository.getStoreSchedule(),
        ServicesLocator.storeRepository.getHolidays(),
      ]);
      if (mounted) {
        if (_draft.date == null || _isDateUnavailable(_draft.date!)) {
          final firstOpen = BookingDateUtils.findFirstAvailableDate(
            isDateUnavailable: _isDateUnavailable,
            preferredStart: _draft.date,
          );
          _draft.setDate(firstOpen);
          _loadAvailability();
        }
        setState(() {});
      }
    } catch (_) {}
  }

  bool _isDateUnavailable(DateTime d) {
    if (!BookingDateUtils.isDateAllowed(d)) return true;
    if (ServicesLocator.storeRepository.isHoliday(d)) return true;
    if (ServicesLocator.storeRepository.isStoreClosedDay(d)) return true;
    return false;
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  /// Converts "HH:mm" to total minutes since midnight.
  int _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  /// Returns true if two DateTimes fall on the same calendar day.
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Formats "HH:mm" to 12h display, e.g. "09:00" → "9:00 AM"
  String _fmt12(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return hhmm;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final period = h < 12 ? 'AM' : 'PM';
    final displayH = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayH:${m.toString().padLeft(2, '0')} $period';
  }

  // ── two-step availability load ─────────────────────────────────────────────

  Future<void> _loadAvailability() async {
    if (_draft.date == null || _draft.service == null) return;

    if (!BookingDateUtils.isDateAllowed(_draft.date)) {
      setState(() {
        _slotsError = true;
        _slotsErrorMessage = BookingDateUtils.invalidDateMessage;
      });
      return;
    }

    setState(() {
      _loadingStep1 = true;
      _loadingStep2 = false;
      _slotsError = false;
      _slotsErrorMessage = null;
      _slots = [];
      _bookedSlots = [];
      _rawGroomers = [];
      _storeClosed = false;
      _holidayName = null;
      _storeOpenTime = null;
      _storeCloseTime = null;
      _groomerList = [
        {'id': 'any', 'initial': 'ANY', 'name': 'No Pref', 'available': true},
      ];
    });

    final dateStr = DateFormat('yyyy-MM-dd').format(_draft.date!);
    final ids       = _draft.extractServiceIds();
    final serviceId = ids['serviceId'] as int?;
    final packageId = ids['packageId'] as int?;
    final addOnIds  = _draft.extractAddOnIds();

    // Resolve current groomer ID (0 = no preference)
    int groomerId = 0;
    final gId = _selectedGroomerId;
    if (gId != 'any') {
      groomerId = int.tryParse(gId) ?? 0;
    }

    // Fetch active bookings for current authenticated user (for duplicate validation)
    List<Map<String, dynamic>> userBookings = [];
    try {
      if (ServicesLocator.sessionService.isLoggedIn) {
        userBookings = await ServicesLocator.bookingRepository.getUpcomingBookingsApi();
      }
    } catch (e) {
      _log.d('BookingDateTimePageMobile::_loadAvailability::Could not fetch user active bookings: $e');
    }
    _userActiveBookings = userBookings;

    // ── Step 1: POST /api/availability ─────────────────────────────────────
    _log.d('BookingDateTimePageMobile::_loadAvailability::Step1 POST /api/availability'
        ' date=$dateStr serviceId=$serviceId packageId=$packageId'
        ' addOnIds=$addOnIds groomerId=${groomerId > 0 ? groomerId : "any"}');

    int durationMinutes = 60; // safe fallback
    try {
      final availResp = await ServicesLocator.bookingRepository.getAvailability(
        date: dateStr,
        serviceId: serviceId,
        packageId: packageId,
        addOnIds: addOnIds.isEmpty ? null : addOnIds,
        groomerId: groomerId > 0 ? groomerId : null,
      );

      _log.d('BookingDateTimePageMobile::_loadAvailability::Step1 response='
          '${availResp?.toString().substring(0, (availResp.toString().length > 200) ? 200 : availResp.toString().length)}');

      if (availResp != null &&
          availResp['success'] == true &&
          availResp['data'] != null) {
        final d = availResp['data'] as Map<String, dynamic>;
        final apiDur   = d['totalDurationMinutes'];
        final apiPrice = d['totalPrice'];

        if (apiDur is num && apiDur > 0) {
          durationMinutes = apiDur.toInt();
        }
        _draft.apiDurationMinutes = durationMinutes;

        if (apiPrice is num) {
          _draft.apiTotalPrice = apiPrice.toDouble();
        } else if (apiPrice is String) {
          _draft.apiTotalPrice =
              double.tryParse(apiPrice.replaceAll(RegExp(r'[^0-9.]'), ''));
        }

        final rawAvailSlots = d['availableSlots'] as List<dynamic>? ?? [];
        final slotMap = <String, Map<String, dynamic>>{};
        final countMap = <String, int>{};
        for (final s in rawAvailSlots) {
          if (s is Map) {
            final st = s['startTime']?.toString() ?? '';
            if (st.isNotEmpty) {
              final map = Map<String, dynamic>.from(s);
              slotMap[st] = map;
              final bCount = map['bookingCount'];
              if (bCount is num) {
                countMap[st] = bCount.toInt();
              }
            }
          }
        }
        _step1SlotDataByStartTime = slotMap;
        _step1BookingCounts = countMap;

        _log.d('BookingDateTimePageMobile::_loadAvailability::Step1 result'
            ' totalDurationMinutes=$durationMinutes totalPrice=${_draft.apiTotalPrice}'
            ' availableSlotsCount=${rawAvailSlots.length}');
      } else {
        _draft.apiDurationMinutes = durationMinutes;
        _log.w('BookingDateTimePageMobile::_loadAvailability::Step1 failed or empty'
            ' — falling back to durationMinutes=$durationMinutes');
      }
    } catch (e) {
      _draft.apiDurationMinutes = durationMinutes;
      _log.w('BookingDateTimePageMobile::_loadAvailability::Step1 exception=$e'
          ' — falling back to durationMinutes=$durationMinutes');
    }

    if (!mounted) return;
    setState(() {
      _loadingStep1 = false;
      _loadingStep2 = true;
    });

    // ── Step 2: GET /api/groomer-availability ─────────────────────────────
    _log.d('BookingDateTimePageMobile::_loadAvailability::Step2 GET /api/groomer-availability'
        ' date=$dateStr durationMinutes=$durationMinutes'
        ' groomerId=${groomerId > 0 ? groomerId : "all"}');

    try {
      final resp = await ServicesLocator.bookingRepository.getGroomerAvailability(
        date: dateStr,
        durationMinutes: durationMinutes,
        groomerId: groomerId > 0 ? groomerId : null,
      );

      _log.d('BookingDateTimePageMobile::_loadAvailability::Step2 response success='
          '${resp?["success"]}');

      if (!mounted) return;

      if (resp == null || resp['success'] != true || resp['data'] == null) {
        setState(() {
          _loadingStep2 = false;
          _slotsError = true;
          _slotsErrorMessage =
              resp?['message']?.toString() ?? 'Unable to load availability.';
        });
        return;
      }

      final data       = resp['data'] as Map<String, dynamic>;
      final storeData  = data['store']  as Map<String, dynamic>?;
      final rawGroomers = data['groomers'] as List<dynamic>? ?? [];

      // Store hours
      final opHours = storeData?['operationalHours'] as Map<String, dynamic>?;
      final isClosed  = storeData?['closed'] == true;
      final holiday   = storeData?['holiday'];

      _rawGroomers = rawGroomers;

      // Build groomer chip list
      final chips = <Map<String, dynamic>>[
        {'id': 'any', 'initial': 'ANY', 'name': 'No Pref', 'available': true},
      ];
      for (final g in rawGroomers.whereType<Map>()) {
        final firstName = g['firstName']?.toString() ?? g['name']?.toString() ?? '';
        final lastName  = g['lastName']?.toString() ?? '';
        final fullName  = lastName.isNotEmpty ? '$firstName $lastName' : firstName;
        chips.add(<String, dynamic>{
          'id'          : (g['id'] ?? '').toString(),
          'initial'     : fullName.isNotEmpty ? fullName[0].toUpperCase() : 'G',
          'name'        : fullName,
          'role'        : g['role']?.toString() ?? '',
          'type'        : g['type']?.toString() ?? '',
          'available'   : g['available'] ?? false,
          'reason'      : g['reason']?.toString(),
          // raw lists for slot computation
          'availableSlots'  : g['availableSlots']  ?? [],
          'bookedSlots'     : g['bookedSlots']     ?? [],
          'unavailable'     : g['unavailable']     ?? [],
          'workingHours'    : g['workingHours'],
          'availableWindows': g['availableWindows'] ?? [],
        });
      }

      // Compute slots for current groomer selection
      final slots    = _buildSlots(
        rawGroomers,
        _selectedGroomerId,
        bookingCountsByStartTime: _step1BookingCounts,
        slotDataByStartTime: _step1SlotDataByStartTime,
      );
      final booked   = _buildBookedSlots(rawGroomers, _selectedGroomerId);

      setState(() {
        _loadingStep2    = false;
        _storeClosed     = isClosed;
        _holidayName     = holiday?.toString();
        _storeOpenTime   = opHours?['startTime']?.toString();
        _storeCloseTime  = opHours?['endTime']?.toString();
        _groomerList     = chips;
        _slots           = slots;
        _bookedSlots     = booked;
        _slotsError      = false;
        _slotsErrorMessage = null;
      });

      _validateSelectedSlot();
    } catch (e) {
      _log.e('BookingDateTimePageMobile::_loadAvailability::Step2 exception=$e');
      if (mounted) {
        setState(() {
          _loadingStep2 = false;
          _slotsError   = true;
          _slotsErrorMessage =
              'Unable to load time slots. Please try again.';
        });
      }
    }
  }

  // ── slot building ──────────────────────────────────────────────────────────

  /// Converts "HH:mm" string to total minutes since midnight.
  /// Also used externally by the filter logic.
  // _toMinutes is already defined above as a helper.

  /// Converts total minutes since midnight back to "HH:mm".
  String _fromMinutes(int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// Returns count of active/existing bookings overlapping candidate window [startMin, startMin+duration).
  int _countOverlappingBookings(
    int startMin,
    int durationMin,
    List<Map<String, dynamic>> bookedSlots,
  ) {
    final endMin = startMin + durationMin;
    int count = 0;
    for (final b in bookedSlots) {
      final bStart = _toMinutes(b['startTime']?.toString() ?? '');
      final bEnd   = _toMinutes(b['endTime']?.toString()   ?? '');
      if (bStart >= bEnd) continue; // malformed slot — skip
      if (startMin < bEnd && endMin > bStart) {
        count++;
      }
    }
    return count;
  }



  /// Generates continuous slots for one groomer from its working hours/available windows
  /// and `bookedSlots[]`, stepping by [durationMin].
  ///
  /// Each slot carries [SlotCapacity] built from the groomer-level API data and overlapping bookings.
  List<Map<String, dynamic>> _generateSlotsForGroomer(
    Map groomer,
    int durationMin, {
    Map<String, int>? bookingCountsByStartTime,
    Map<String, Map<String, dynamic>>? slotDataByStartTime,
  }) {
    _log.d("BookingDateTimePage::_generateSlotsForGroomer::Processing groomer availability for groomerId=${groomer['id']}");

    final bool isMulti = groomer['multiBookingEnabled'] == true;
    final int  limit   = () {
      final raw = groomer['slotBookingLimit'] ?? groomer['maxBookings'];
      if (raw == null) return isMulti ? 3 : 1;
      if (raw is int) return raw;
      return int.tryParse(raw.toString()) ?? (isMulti ? 3 : 1);
    }();

    final workingHoursMap = groomer['workingHours'] is Map ? (groomer['workingHours'] as Map) : null;
    final workingStartStr = workingHoursMap?['startTime']?.toString() ??
        workingHoursMap?['effectiveStartTime']?.toString() ??
        workingHoursMap?['open']?.toString();
    final workingEndStr = workingHoursMap?['endTime']?.toString() ??
        workingHoursMap?['effectiveEndTime']?.toString() ??
        workingHoursMap?['close']?.toString();

    final List<dynamic> windows;
    if (workingStartStr != null &&
        workingEndStr != null &&
        workingStartStr.isNotEmpty &&
        workingEndStr.isNotEmpty) {
      windows = [
        {'startTime': workingStartStr, 'endTime': workingEndStr}
      ];
    } else {
      final rawWindows = groomer['availableWindows'] as List<dynamic>?;
      windows = (rawWindows != null && rawWindows.isNotEmpty)
          ? rawWindows
          : (workingHoursMap != null ? [workingHoursMap] : <dynamic>[]);
    }

    final rawBooked   = groomer['bookedSlots']    as List<dynamic>? ?? [];
    final rawAvail    = groomer['availableSlots'] as List<dynamic>? ?? [];
    final groomerId   = groomer['id'];
    final groomerName = _groomerDisplayName(groomer);

    // Build map from availableSlots if provided by API (groomer.availableSlots or Step 1 slotDataByStartTime)
    final availSlotMap = <String, Map<String, dynamic>>{};
    for (final s in rawAvail) {
      if (s is Map) {
        final st = s['startTime']?.toString() ?? '';
        if (st.isNotEmpty) {
          availSlotMap[st] = Map<String, dynamic>.from(s);
        }
      }
    }
    if (slotDataByStartTime != null) {
      for (final entry in slotDataByStartTime.entries) {
        final st = entry.key;
        final sData = entry.value;
        final sGroomId = sData['groomerId']?.toString();
        if (sGroomId == null || sGroomId.isEmpty || sGroomId == groomerId?.toString() || sGroomId == 'any') {
          if (!availSlotMap.containsKey(st)) {
            availSlotMap[st] = Map<String, dynamic>.from(sData);
          }
        }
      }
    }

    // Parse booked slots once
    final bookedSlots = rawBooked
        .whereType<Map>()
        .map((b) => Map<String, dynamic>.from(b))
        .toList();

    final slots = <Map<String, dynamic>>[];
    final addedKeys = <String>{};

    // Dynamic grid step based on service/package duration
    final int step = durationMin > 0 ? durationMin : 60;

    for (final w in windows.whereType<Map>()) {
      final windowStart = _toMinutes(w['startTime']?.toString() ?? '');
      final windowEnd   = _toMinutes(w['endTime']?.toString()   ?? '');
      if (windowStart >= windowEnd) continue;

      int cursor = windowStart;
      while (cursor + durationMin <= windowEnd) {
        final startKey = _fromMinutes(cursor);
        final endKey   = _fromMinutes(cursor + durationMin);
        final int overlapCount = _countOverlappingBookings(cursor, durationMin, bookedSlots);

        // Check if slot-level capacity data is provided by API
        final slotApiData = availSlotMap[startKey];
        SlotCapacity capacity;
        if (slotApiData != null) {
          final slotDataWithCount = Map<String, dynamic>.from(slotApiData);
          if (!slotDataWithCount.containsKey('bookingCount') || slotDataWithCount['bookingCount'] == null) {
            slotDataWithCount['bookingCount'] = bookingCountsByStartTime?[startKey] ?? overlapCount;
          }
          capacity = SlotCapacity.fromSlotData(slotDataWithCount, groomerData: groomer);
        } else {
          final count = bookingCountsByStartTime?[startKey] ?? overlapCount;
          capacity = SlotCapacity.fromGroomerData(
            groomer,
            maxBookingsForSlot: limit,
            bookingCountForSlot: count,
          );
        }

        final physicallyFree = overlapCount == 0;

        slots.add({
          'startTime'   : startKey,
          'endTime'     : endKey,
          'groomerId'   : slotApiData?['groomerId'] ?? groomerId,
          'groomerName' : slotApiData?['groomerName']?.toString() ?? groomerName,
          'bookingCount': capacity.bookingCount,
          'maxBookings' : capacity.maxBookings,
          'remaining'   : capacity.remaining,
          'isAvailable' : capacity.isAvailable,
          '_capacity'   : capacity,
          '_physFree'   : physicallyFree,
        });
        addedKeys.add(startKey);

        cursor += step;
      }
    }

    // Direct ingestion of any explicit slots from API that weren't inside the window loop
    for (final entry in availSlotMap.entries) {
      final st = entry.key;
      if (!addedKeys.contains(st)) {
        final slotApiData = entry.value;
        final slotDataWithCount = Map<String, dynamic>.from(slotApiData);
        final overlapCount = _countOverlappingBookings(_toMinutes(st), durationMin, bookedSlots);
        if (!slotDataWithCount.containsKey('bookingCount') || slotDataWithCount['bookingCount'] == null) {
          slotDataWithCount['bookingCount'] = bookingCountsByStartTime?[st] ?? overlapCount;
        }
        final capacity = SlotCapacity.fromSlotData(slotDataWithCount, groomerData: groomer);

        slots.add({
          'startTime'   : st,
          'endTime'     : (slotApiData['endTime'] != null && slotApiData['endTime'].toString().isNotEmpty)
              ? slotApiData['endTime'].toString()
              : _fromMinutes(_toMinutes(st) + durationMin),
          'groomerId'   : slotApiData['groomerId'] ?? groomerId,
          'groomerName' : slotApiData['groomerName']?.toString() ?? groomerName,
          'bookingCount': capacity.bookingCount,
          'maxBookings' : capacity.maxBookings,
          'remaining'   : capacity.remaining,
          'isAvailable' : capacity.isAvailable,
          '_capacity'   : capacity,
          '_physFree'   : overlapCount == 0,
        });
        addedKeys.add(st);
      }
    }

    return slots;
  }

  /// Builds the combined list of [_Slot] objects.
  ///
  /// Capacity-aware: each slot carries a [SlotCapacity] that encodes whether
  /// multi-booking is enabled and how many bookings remain.
  List<_Slot> _buildSlots(
    List<dynamic> rawGroomers,
    String selectedId, {
    Map<String, int>? bookingCountsByStartTime,
    Map<String, Map<String, dynamic>>? slotDataByStartTime,
  }) {
    _log.d("BookingDateTimePage::_buildSlots::Building slots for selectedId=$selectedId");
    final selectedStartTime = _draft.timeSlot;
    final durationMin       = _draft.apiDurationMinutes ?? 60;

    // ── Generate slots from groomers ─────────────────────────────────────────
    final availMap = <String, Map<String, dynamic>>{};

    if (selectedId == 'any') {
      for (final g in rawGroomers.whereType<Map>()) {
        if (g['available'] != true) continue;
        final generated = _generateSlotsForGroomer(
          g, durationMin,
          bookingCountsByStartTime: bookingCountsByStartTime,
          slotDataByStartTime: slotDataByStartTime,
        );
        for (final s in generated) {
          final st = s['startTime']?.toString() ?? '';
          if (st.isNotEmpty) {
            if (!availMap.containsKey(st)) {
              availMap[st] = s;
            } else {
              // If already in availMap, prioritize slot with available capacity
              final existingCap = availMap[st]!['_capacity'] as SlotCapacity?;
              final newCap = s['_capacity'] as SlotCapacity?;
              if (existingCap != null && newCap != null) {
                if (!existingCap.isAvailable && newCap.isAvailable) {
                  availMap[st] = s;
                } else if (newCap.remaining > existingCap.remaining) {
                  availMap[st] = s;
                }
              }
            }
          }
        }
      }
    } else {
      final g = rawGroomers.whereType<Map>().firstWhere(
        (g) => (g['id'] ?? '').toString() == selectedId,
        orElse: () => <String, dynamic>{},
      );
      if (g.isNotEmpty && g['available'] == true) {
        for (final s in _generateSlotsForGroomer(
          g, durationMin,
          bookingCountsByStartTime: bookingCountsByStartTime,
          slotDataByStartTime: slotDataByStartTime,
        )) {
          final st = s['startTime']?.toString() ?? '';
          if (st.isNotEmpty) availMap[st] = s;
        }
      }
    }

    // Direct ingestion of any remaining available slots from slotDataByStartTime (POST /api/availability)
    if (slotDataByStartTime != null) {
      for (final entry in slotDataByStartTime.entries) {
        final st = entry.key;
        final slotData = entry.value;
        if (selectedId != 'any') {
          final sGroomerId = (slotData['groomerId'] ?? '').toString();
          if (sGroomerId.isNotEmpty && sGroomerId != selectedId) {
            continue;
          }
        }
        if (!availMap.containsKey(st)) {
          final matchedGroomer = rawGroomers.whereType<Map>().firstWhere(
            (g) => (g['id'] ?? '').toString() == (slotData['groomerId'] ?? '').toString(),
            orElse: () => <String, dynamic>{},
          );
          final cap = SlotCapacity.fromSlotData(slotData, groomerData: matchedGroomer.isNotEmpty ? matchedGroomer : null);

          availMap[st] = {
            'startTime'   : st,
            'endTime'     : (slotData['endTime'] != null && slotData['endTime'].toString().isNotEmpty)
                ? slotData['endTime'].toString()
                : _fromMinutes(_toMinutes(st) + durationMin),
            'groomerId'   : slotData['groomerId'],
            'groomerName' : slotData['groomerName']?.toString() ?? '',
            'bookingCount': cap.bookingCount,
            'maxBookings' : cap.maxBookings,
            'remaining'   : cap.remaining,
            'isAvailable' : cap.isAvailable,
            '_capacity'   : cap,
            '_physFree'   : cap.bookingCount == 0,
          };
        }
      }
    }

    // ── Sort by startTime ────────────────────────────────────────────────────
    final sortedKeys = availMap.keys.toList()
      ..sort((a, b) => _toMinutes(a).compareTo(_toMinutes(b)));

    // ── Filter past slots for today ──────────────────────────────────────────
    final isToday    = _draft.date != null && _isSameDay(_draft.date!, DateTime.now());
    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    const kBuffer    = 5;

    final filteredKeys = isToday
        ? sortedKeys.where((st) => _toMinutes(st) > nowMinutes + kBuffer).toList()
        : sortedKeys;

    // ── Build _Slot objects with capacity-aware status ────────────────────────
    return filteredKeys.map((st) {
      final raw        = availMap[st]!;
      final capacity   = raw['_capacity'] as SlotCapacity? ?? const SlotCapacity.singleBooking();
      final isSelected = st == selectedStartTime;
      final rawGroomId = raw['groomerId'];
      final int? gId   = rawGroomId is int ? rawGroomId : int.tryParse(rawGroomId?.toString() ?? '');

      // ── Customer-Specific Active Duplicate Check ───────────────────────────
      final dateStr = _draft.date != null ? DateFormat('yyyy-MM-dd').format(_draft.date!) : '';
      final bool isAlreadyBooked = BookingDateUtils.isSlotAlreadyBookedByUser(
        slotDate: dateStr,
        slotStartTime: st,
        slotEndTime: raw['endTime']?.toString() ?? '',
        slotGroomerId: gId,
        slotDurationMinutes: _draft.apiDurationMinutes,
        userBookings: _userActiveBookings,
      );

      // ── Availability & selectability rule ──────────────────────────────────
      // Only capacity exhaustion (or isAvailable == false / remaining <= 0) blocks the slot globally
      final bool isSelectable = capacity.isAvailable &&
          capacity.remaining > 0 &&
          capacity.bookingCount < capacity.maxBookings;

      _SlotStatus slotStatus;
      if (isSelected) {
        slotStatus = _SlotStatus.selected;
      } else if (isAlreadyBooked) {
        // Disabled specifically for this customer who already holds an active booking
        slotStatus = _SlotStatus.alreadyBooked;
      } else if (isSelectable) {
        slotStatus = _SlotStatus.available;
      } else if (capacity.isMultiBookingEnabled || capacity.maxBookings > 1) {
        slotStatus = _SlotStatus.atCapacity;
      } else {
        slotStatus = _SlotStatus.booked;
      }

      final disabledReason = isAlreadyBooked
          ? 'alreadyBooked (current customer holds active booking)'
          : (isSelectable
              ? 'none (selectable)'
              : (capacity.isMultiBookingEnabled
                  ? 'atCapacity (bookingCount=${capacity.bookingCount} >= maxBookings=${capacity.maxBookings})'
                  : 'booked (single-booking overlap)'));

      _log.d('BookingDateTimePage::_buildSlots::Slot $st-${raw['endTime']}'
          ' bookingCount=${capacity.bookingCount} maxBookings=${capacity.maxBookings}'
          ' remaining=${capacity.remaining} isAvailable=${capacity.isAvailable}'
          ' isAlreadyBooked=$isAlreadyBooked status=$slotStatus reason=$disabledReason');

      return _Slot(
        startTime   : st,
        endTime     : raw['endTime']?.toString() ?? '',
        groomerId   : gId,
        groomerName : raw['groomerName']?.toString(),
        status      : slotStatus,
        capacity    : capacity,
      );
    }).toList();
  }

  String _groomerDisplayName(Map g) {
    final firstName = g['firstName']?.toString() ?? '';
    final lastName  = g['lastName']?.toString()  ?? '';
    final name      = g['name']?.toString()       ?? '';
    if (firstName.isNotEmpty) {
      return lastName.isNotEmpty ? '$firstName $lastName' : firstName;
    }
    return name;
  }

  List<Map<String, dynamic>> _buildBookedSlots(
      List<dynamic> rawGroomers, String selectedId) {
    final result = <Map<String, dynamic>>[];
    if (selectedId == 'any') {
      for (final g in rawGroomers.whereType<Map>()) {
        final bs = g['bookedSlots'] as List<dynamic>? ?? [];
        for (final b in bs.whereType<Map>()) {
          result.add(Map<String, dynamic>.from(b));
        }
      }
    } else {
      final g = rawGroomers.whereType<Map>().firstWhere(
        (g) => (g['id'] ?? '').toString() == selectedId,
        orElse: () => <String, dynamic>{},
      );
      final bs = g['bookedSlots'] as List<dynamic>? ?? [];
      for (final b in bs.whereType<Map>()) {
        result.add(Map<String, dynamic>.from(b));
      }
    }
    return result;
  }

  // ── slot selection ─────────────────────────────────────────────────────────

  void _selectSlot(_Slot slot) {
    final isSelectable = (slot.status == _SlotStatus.available || slot.status == _SlotStatus.selected) &&
        slot.status != _SlotStatus.booked &&
        slot.status != _SlotStatus.atCapacity &&
        slot.status != _SlotStatus.alreadyBooked &&
        slot.capacity.isAvailable &&
        slot.capacity.remaining > 0 &&
        slot.capacity.bookingCount < slot.capacity.maxBookings;

    if (!isSelectable) {
      if (slot.status == _SlotStatus.alreadyBooked) {
        ToastUtil.showErrorToast(
          context,
          'You already have an active booking for this time slot. Please choose another time.',
        );
      }
      final reason = slot.status == _SlotStatus.alreadyBooked
          ? 'alreadyBooked (current customer holds active booking)'
          : ((slot.status == _SlotStatus.atCapacity || slot.capacity.bookingCount >= slot.capacity.maxBookings)
              ? 'atCapacity (bookingCount=${slot.capacity.bookingCount} >= maxBookings=${slot.capacity.maxBookings})'
              : (slot.status == _SlotStatus.booked
                  ? 'booked (single-booking overlap)'
                  : (!slot.capacity.isAvailable
                      ? 'isAvailable=false'
                      : 'remaining<=0')));

      _log.w('BookingDateTimePage::_selectSlot::Slot selection blocked: ${slot.startTime}-${slot.endTime}'
          ' bookingCount=${slot.capacity.bookingCount} maxBookings=${slot.capacity.maxBookings}'
          ' remaining=${slot.capacity.remaining} isAvailable=${slot.capacity.isAvailable}'
          ' isSelectable=false reason=$reason');
      return;
    }

    final dateStr = _draft.date != null ? DateFormat('yyyy-MM-dd').format(_draft.date!) : '';
    final isDuplicate = BookingDateUtils.isSlotAlreadyBookedByUser(
      slotDate: dateStr,
      slotStartTime: slot.startTime,
      slotEndTime: slot.endTime,
      slotGroomerId: slot.groomerId,
      slotDurationMinutes: _draft.apiDurationMinutes,
      userBookings: _userActiveBookings,
    );

    if (isDuplicate) {
      _log.w('BookingDateTimePage::_selectSlot::Customer already owns an active booking overlapping ${slot.startTime}-${slot.endTime} on $dateStr');
      ToastUtil.showErrorToast(
        context,
        'You already have an active booking for this time slot. Please choose another time.',
      );
      return;
    }

    _log.i('BookingDateTimePage::_selectSlot::Slot selected: ${slot.startTime}-${slot.endTime}'
        ' bookingCount=${slot.capacity.bookingCount} maxBookings=${slot.capacity.maxBookings}'
        ' remaining=${slot.capacity.remaining} isAvailable=${slot.capacity.isAvailable}'
        ' isSelectable=true');

    _draft.setSelectedSlot({
      'startTime'  : slot.startTime,
      'endTime'    : slot.endTime,
      'groomerId'  : slot.groomerId,
      'groomerName': slot.groomerName ?? '',
    });

    // If "No Preference" and slot carries a groomer, pin that groomer in draft
    if (_selectedGroomerId == 'any' &&
        slot.groomerId != null &&
        slot.groomerId! > 0) {
      _draft.setGroomer({
        'id'     : slot.groomerId.toString(),
        'name'   : slot.groomerName ?? '',
        'initial': (slot.groomerName?.isNotEmpty == true)
            ? slot.groomerName![0].toUpperCase()
            : 'G',
      });
    }

    // Rebuild slots so the selected chip re-renders
    setState(() {
      _slots = _buildSlots(
        _rawGroomers,
        _selectedGroomerId,
        bookingCountsByStartTime: _step1BookingCounts,
        slotDataByStartTime: _step1SlotDataByStartTime,
      );
    });
  }

  void _validateSelectedSlot() {
    if (_draft.timeSlot == null) return;
    final stillAvailable = _slots.any(
        (s) => s.startTime == _draft.timeSlot &&
               s.status != _SlotStatus.booked &&
               s.status != _SlotStatus.atCapacity &&
               s.status != _SlotStatus.alreadyBooked &&
               s.capacity.isAvailable &&
               s.capacity.remaining > 0);
    if (!stillAvailable) {
      _log.d('BookingDateTimePage::_validateSelectedSlot::Selected slot is no longer available — clearing.');
      _draft.clearSelectedSlot();
      setState(() {
        _slots = _buildSlots(
          _rawGroomers,
          _selectedGroomerId,
          bookingCountsByStartTime: _step1BookingCounts,
          slotDataByStartTime: _step1SlotDataByStartTime,
        );
      });
    }
  }

  // ── groomer chip selection ─────────────────────────────────────────────────

  void _onGroomerTap(Map<String, dynamic> chip) {
    final newId = chip['id']?.toString() ?? 'any';
    if (newId == _selectedGroomerId) return;
    if (newId != 'any' && chip['available'] != true) return;

    setState(() => _selectedGroomerId = newId);

    if (newId == 'any') {
      _draft.setGroomer(null);
    } else {
      _draft.setGroomer(chip);
    }
    _draft.clearSelectedSlot();

    // Rebuild slots from cached raw groomers (no network call needed for chip switch)
    setState(() {
      _slots      = _buildSlots(
        _rawGroomers,
        newId,
        bookingCountsByStartTime: _step1BookingCounts,
        slotDataByStartTime: _step1SlotDataByStartTime,
      );
      _bookedSlots = _buildBookedSlots(_rawGroomers, newId);
    });

    // Reload with the groomer filter so the backend can scope availability
    _loadAvailability();
  }

  // ── date selection ─────────────────────────────────────────────────────────

  void _onDateSelected(DateTime date) {
    if (!BookingDateUtils.isDateAllowed(date)) {
      _showSnack(BookingDateUtils.invalidDateMessage);
      return;
    }
    if (ServicesLocator.storeRepository.isHoliday(date)) {
      final holiday = ServicesLocator.storeRepository.getHolidayName(date) ?? 'Holiday';
      _showSnack('$holiday — the store is closed on this date.');
      return;
    }
    if (ServicesLocator.storeRepository.isStoreClosedDay(date)) {
      _showSnack('The store is closed on this date. Please select another date.');
      return;
    }
    _draft.setDate(date);         // clears timeSlot / endTime / selectedSlot
    _loadAvailability();
  }

  // ── navigation ─────────────────────────────────────────────────────────────

  void _onContinue() {
    if (_draft.date == null || !BookingDateUtils.isDateAllowed(_draft.date)) {
      _showSnack(BookingDateUtils.invalidDateMessage);
      return;
    }
    if (ServicesLocator.storeRepository.isHoliday(_draft.date!) || _holidayName != null) {
      final holiday = _holidayName ?? ServicesLocator.storeRepository.getHolidayName(_draft.date!) ?? 'Holiday';
      _showSnack('$holiday — the store is closed. Please select another date.');
      return;
    }
    if (ServicesLocator.storeRepository.isStoreClosedDay(_draft.date!) || _storeClosed) {
      _showSnack('The store is closed on this date. Please select another date.');
      return;
    }
    final slot = _draft.timeSlot;
    final end  = _draft.endTime;
    if (slot == null || slot.isEmpty || end == null || end.isEmpty) {
      _showSnack('Please select a time slot.');
      return;
    }
    final still = _slots.any(
        (s) => s.startTime == slot &&
               s.status != _SlotStatus.booked &&
               s.status != _SlotStatus.atCapacity &&
               s.status != _SlotStatus.alreadyBooked);
    if (!still) {
      _showSnack('The selected slot is no longer available. Please choose another.');
      return;
    }
    final dateStr = DateFormat('yyyy-MM-dd').format(_draft.date!);
    final isDuplicate = BookingDateUtils.isSlotAlreadyBookedByUser(
      slotDate: dateStr,
      slotStartTime: slot,
      slotEndTime: end,
      slotGroomerId: _draft.selectedSlot?['groomerId'] ?? _draft.groomer?['id'],
      slotDurationMinutes: _draft.apiDurationMinutes,
      userBookings: _userActiveBookings,
    );
    if (isDuplicate) {
      _showSnack('You already have an active booking for this time slot. Please choose another time.');
      return;
    }
    context.pushNamed(RouteNames.bookingReview);
  }

  void _showSnack(String msg) {
    ToastUtil.showErrorToast(context, msg);
  }

  // ── bottom-bar summary ─────────────────────────────────────────────────────

  String _buildSummary() {
    final date = _draft.date;
    final slot = _draft.timeSlot;
    if (date == null || slot == null || slot.isEmpty) {
      return 'No date & time selected';
    }
    final dateLabel    = DateFormat('EEE, MMM d').format(date);
    final slotLabel    = _fmt12(slot);
    final groomerName  = _draft.groomer?['name']?.toString() ?? '';
    final groomerLabel =
        (groomerName.isEmpty || groomerName == 'No Pref') ? '' : ' · $groomerName';
    return '$dateLabel  $slotLabel$groomerLabel';
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _draft,
      builder: (context, _) {
        final canContinue = !_storeClosed &&
            _holidayName == null &&
            _draft.timeSlot != null &&
            _draft.timeSlot!.isNotEmpty &&
            _draft.endTime != null &&
            _draft.endTime!.isNotEmpty;

        return Scaffold(
          backgroundColor: _kPageBg,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const BookingHeader(
                  title: 'Date & Time',
                  step: 3,
                  subtitle: 'Step 3 of 4 — Select Date & Time',
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: _kTeal,
                    onRefresh: _loadAvailability,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(17, 20, 17, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Calendar ───────────────────────────────────
                          _sectionTitle('Select Date'),
                          const SizedBox(height: 10),
                          SharedCalendar(
                            initialDate: _draft.date,
                            minDate: BookingDateUtils.minAllowedDate,
                            maxDate: BookingDateUtils.maxAllowedDate,
                            isDateUnavailable: _isDateUnavailable,
                            onDateSelected: _onDateSelected,
                          ),
                          const SizedBox(height: 24),

                          // ── Groomer chips ──────────────────────────────
                          _sectionTitle('Preferred Groomer'),
                          const SizedBox(height: 4),
                          Text(
                            'Choose a groomer or keep "No Pref" to see all available slots.',
                            style: AppFonts.poppins(
                                size: 12,
                                weight: FontWeight.w400,
                                color: _kSubText),
                          ),
                          const SizedBox(height: 12),
                          _buildGroomerChips(),
                          const SizedBox(height: 24),

                          // ── Store-level banners ────────────────────────
                          if (_storeClosed) ...[
                            _buildBanner(
                              icon: Icons.storefront_outlined,
                              iconColor: _kRed,
                              title: 'Store Closed',
                              message:
                                  'The store is closed on this date. Please select another date.',
                            ),
                            const SizedBox(height: 24),
                          ] else if (_holidayName != null) ...[
                            _buildBanner(
                              icon: Icons.celebration_outlined,
                              iconColor: _kAmber,
                              title: 'Holiday — $_holidayName',
                              message:
                                  'The store is closed for this holiday. Please select another date.',
                            ),
                            const SizedBox(height: 24),
                          ],

                          // ── Store hours info strip ─────────────────────
                          if (!_storeClosed &&
                              _holidayName == null &&
                              _storeOpenTime != null &&
                              _storeCloseTime != null) ...[
                            _buildHoursStrip(),
                            const SizedBox(height: 16),
                          ],

                          // ── Slot section ───────────────────────────────
                          _sectionTitle('Select Time'),
                          const SizedBox(height: 4),
                          if (_draft.apiDurationMinutes != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Service duration: ${_draft.apiDurationMinutes} min'
                                '${_draft.apiTotalPrice != null ? '  ·  Est. \$${_draft.apiTotalPrice!.toStringAsFixed(0)}' : ''}',
                                style: AppFonts.poppins(
                                    size: 12,
                                    weight: FontWeight.w500,
                                    color: _kTeal),
                              ),
                            ),
                          const SizedBox(height: 8),
                          _buildSlotSection(),
                          const SizedBox(height: 24),

                          // ── Legend ─────────────────────────────────────
                          if (!_storeClosed && _holidayName == null)
                            _buildLegend(),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Bottom bar ─────────────────────────────────────────
                BookingBottomBar(
                  summary: _buildSummary(),
                  onContinue: canContinue ? _onContinue : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── sub-builders ──────────────────────────────────────────────────────────

  Widget _sectionTitle(String label) {
    return Text(label,
        style: AppFonts.poppins(
            size: 15, weight: FontWeight.w600, color: _kSectionText));
  }

  // ── Groomer chips row ─────────────────────────────────────────────────────

  Widget _buildGroomerChips() {
    if (_loadingStep1 || _loadingStep2) {
      return const SizedBox(
        height: 80,
        child: Center(
            child: CircularProgressIndicator(
                color: Colors.black, strokeWidth: 2)),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _groomerList.map((chip) {
          final chipId      = chip['id']?.toString() ?? 'any';
          final isSelected  = chipId == _selectedGroomerId;
          final isAvailable = chipId == 'any' || chip['available'] == true;
          final isNoPreff   = chipId == 'any';
          final initial     = chip['initial']?.toString() ?? 'G';
          final name        = chip['name']?.toString()    ?? '';
          final reason      = chip['reason']?.toString();

          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: isAvailable ? () => _onGroomerTap(chip) : null,
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Avatar circle
                      Opacity(
                        opacity: isAvailable ? 1.0 : 0.35,
                        child: Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.black : const Color(0xFF111827),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: Colors.black, width: 2.5)
                                : null,
                          ),
                          child: Text(
                            initial,
                            style: AppFonts.poppins(
                              size: isNoPreff ? 13 : 22,
                              weight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Selected check-mark badge
                      if (isSelected)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: Color(0xFF16A34A),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check,
                                size: 13, color: Colors.white),
                          ),
                        ),
                      // Unavailable dot badge
                      if (!isAvailable)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              color: _kRed,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 13, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 64,
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppFonts.poppins(
                        size: 11,
                        weight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected ? Colors.black : _kSectionText,
                      ),
                    ),
                  ),
                  if (!isAvailable && reason != null) ...[
                    const SizedBox(height: 2),
                    SizedBox(
                      width: 68,
                      child: Text(
                        reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppFonts.poppins(
                            size: 9,
                            weight: FontWeight.w400,
                            color: _kRed),
                      ),
                    ),
                  ],
                  if (!isAvailable && reason == null) ...[
                    const SizedBox(height: 2),
                    SizedBox(
                      width: 64,
                      child: Text(
                        'Unavailable',
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: AppFonts.poppins(
                            size: 9,
                            weight: FontWeight.w400,
                            color: _kRed),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Store hours strip ─────────────────────────────────────────────────────

  Widget _buildHoursStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF6EE7B7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time, size: 16, color: _kTeal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Store hours: ${_fmt12(_storeOpenTime!)} – ${_fmt12(_storeCloseTime!)}'
              '   Last appointment: ${_fmt12(_storeCloseTime!)}',
              style: AppFonts.poppins(
                  size: 11,
                  weight: FontWeight.w500,
                  color: const Color(0xFF065F46)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Slot section ──────────────────────────────────────────────────────────

  Widget _buildSlotSection() {
    // Loading
    if (_loadingStep1 || _loadingStep2) {
      return Container(
        width: double.infinity,
        height: 130,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorderLight),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                color: _kSectionText,
                strokeWidth: 2.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _loadingStep1
                  ? 'Calculating service duration…'
                  : 'Loading available slots…',
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                size: 13,
                weight: FontWeight.w400,
                color: _kSubText,
              ),
            ),
          ],
        ),
      );
    }

    // Error
    if (_slotsError) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorderLight),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
                border: Border.all(color: _kBorderLight),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 26,
                color: _kSectionText,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Unable to Load Availability',
              textAlign: TextAlign.center,
              style: AppFonts.parkinsans(
                size: 15,
                weight: FontWeight.w600,
                color: _kSectionText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _slotsErrorMessage ?? 'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                size: 13,
                weight: FontWeight.w400,
                color: _kSubText,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadAvailability,
              icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
              label: Text(
                'Retry',
                style: AppFonts.poppins(
                  size: 13,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kSectionText,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 11,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Store closed / holiday — no slots to show
    if (_storeClosed || _holidayName != null) {
      return const SizedBox.shrink();
    }

    // No available groomers (but store is open)
    final hasAvailableGroomer =
        _rawGroomers.whereType<Map>().any((g) => g['available'] == true);
    if (!hasAvailableGroomer && _rawGroomers.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorderLight),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.person_off_outlined,
                size: 26,
                color: _kAmber,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No Groomers Available',
              textAlign: TextAlign.center,
              style: AppFonts.parkinsans(
                size: 15,
                weight: FontWeight.w600,
                color: _kSectionText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No groomers are available on this date. Please try another date.',
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                size: 13,
                weight: FontWeight.w400,
                color: _kSubText,
              ),
            ),
          ],
        ),
      );
    }

    // No slots after filtering
    if (_slots.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorderLight),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
                border: Border.all(color: _kBorderLight),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.event_busy_rounded,
                size: 26,
                color: _kSubText,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No Available Slots',
              textAlign: TextAlign.center,
              style: AppFonts.parkinsans(
                size: 15,
                weight: FontWeight.w600,
                color: _kSectionText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedGroomerId == 'any'
                  ? 'No slots available on this date. Please select another date.'
                  : 'No available slots for this groomer on this date.',
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                size: 13,
                weight: FontWeight.w400,
                color: _kSubText,
              ),
            ),
          ],
        ),
      );
    }

    // ── Render the slot grid (fixed 4-column layout) ──────────────────────
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Booked-slots info header (when a specific groomer is selected)
          if (_selectedGroomerId != 'any' && _bookedSlots.isNotEmpty) ...[
            _buildBookedSlotsInfo(),
            const SizedBox(height: 12),
            const Divider(color: _kBorderLight, height: 1),
            const SizedBox(height: 12),
          ],
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _slots.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 8,
              mainAxisExtent: 40,
            ),
            itemBuilder: (context, index) {
              final slot = _slots[index];
              return _SlotButton(
                slot: slot,
                onTap: (slot.status != _SlotStatus.booked &&
                        slot.status != _SlotStatus.atCapacity &&
                        slot.status != _SlotStatus.alreadyBooked)
                    ? () => _selectSlot(slot)
                    : null,
                fmt12: _fmt12,
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Booked slots info strip ───────────────────────────────────────────────

  Widget _buildBookedSlotsInfo() {
    if (_bookedSlots.isEmpty) return const SizedBox.shrink();
    final labels = _bookedSlots.map((b) {
      final st = b['startTime']?.toString() ?? '';
      final et = b['endTime']?.toString()   ?? '';
      return st.isNotEmpty && et.isNotEmpty
          ? '${_fmt12(st)} – ${_fmt12(et)}'
          : st.isNotEmpty
              ? _fmt12(st)
              : '';
    }).where((s) => s.isNotEmpty).join('   ');

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: _kBookedBg,
            border: Border.all(color: _kBorderLight),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Already booked: $labels',
            style: AppFonts.poppins(
                size: 11,
                weight: FontWeight.w400,
                color: _kBookedFg),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ── Legend ────────────────────────────────────────────────────────────────

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _legendItem(Colors.white, Colors.black, 'Available', borderColor: Colors.black),
        _legendItem(Colors.black, Colors.white, 'Selected', borderColor: Colors.black),
        _legendItem(_kBookedBg, _kBookedFg, 'Already Booked', borderColor: _kBorderLight),
      ],
    );
  }

  Widget _legendItem(Color bg, Color fg, String label,
      {Color? borderColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor ?? _kBorderLight, width: 1.2),
          ),
          child: Text('–',
              style: AppFonts.poppins(
                  size: 10, weight: FontWeight.w700, color: fg)),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: AppFonts.poppins(
                size: 12,
                weight: FontWeight.w500,
                color: Colors.black)),
      ],
    );
  }

  // ── Status banner ─────────────────────────────────────────────────────────

  Widget _buildBanner({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppFonts.poppins(
                        size: 13,
                        weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(message,
                    style: AppFonts.poppins(
                        size: 12,
                        weight: FontWeight.w400,
                        color: _kSubText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slot Button widget
// ─────────────────────────────────────────────────────────────────────────────
class _SlotButton extends StatelessWidget {
  final _Slot slot;
  final VoidCallback? onTap;
  final String Function(String) fmt12;

  const _SlotButton({
    required this.slot,
    required this.onTap,
    required this.fmt12,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected      = slot.status == _SlotStatus.selected;
    final isBooked        = slot.status == _SlotStatus.booked;
    final isAtCapacity    = slot.status == _SlotStatus.atCapacity;
    final isAlreadyBooked = slot.status == _SlotStatus.alreadyBooked;
    final isUnavailable   = isBooked || isAtCapacity || isAlreadyBooked;

    Color bg, fg, borderColor;
    if (isSelected) {
      bg          = Colors.black;
      fg          = Colors.white;
      borderColor = Colors.black;
    } else if (isUnavailable) {
      bg          = const Color(0xFFF3F4F6);
      fg          = const Color(0xFFAFAFAF);
      borderColor = const Color(0xFFE5E7EB);
    } else {
      // available: white background, sharp black border, black text
      bg          = Colors.white;
      fg          = Colors.black;
      borderColor = Colors.black;
    }

    return GestureDetector(
      onTap: isUnavailable
          ? () {
              if (isAlreadyBooked) {
                ToastUtil.showErrorToast(
                  context,
                  'You already have an active booking for this time slot. Please choose another time.',
                );
              }
              final reason = isAlreadyBooked
                  ? 'alreadyBooked (current customer holds active booking)'
                  : (isBooked
                      ? 'booked (single-booking overlap)'
                      : 'atCapacity (bookingCount=${slot.capacity.bookingCount} >= maxBookings=${slot.capacity.maxBookings})');
              Logger().d('BookingDateTimePage::_SlotButton::Tapped disabled slot ${slot.startTime}-${slot.endTime}'
                  ' bookingCount=${slot.capacity.bookingCount} maxBookings=${slot.capacity.maxBookings}'
                  ' remaining=${slot.capacity.remaining} isAvailable=${slot.capacity.isAvailable}'
                  ' isSelectable=false reason=$reason');
            }
          : onTap,
      child: AnimatedContainer(
        duration    : const Duration(milliseconds: 150),
        height      : 40,
        alignment   : Alignment.center,
        decoration  : BoxDecoration(
          color       : bg,
          borderRadius: BorderRadius.circular(20),
          border      : Border.all(color: borderColor, width: 1.4),
        ),
        child: Text(
          fmt12(slot.startTime),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily     : 'Poppins',
            fontSize       : 13,
            fontWeight     : (isSelected || !isUnavailable) ? FontWeight.w600 : FontWeight.w400,
            color          : fg,
            decoration     : isUnavailable ? TextDecoration.lineThrough : null,
            decorationColor: fg,
          ),
        ),
      ),
    );
  }
}
