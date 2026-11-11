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

  _Slot copyWith({
    String? startTime,
    String? endTime,
    int? groomerId,
    String? groomerName,
    _SlotStatus? status,
    SlotCapacity? capacity,
  }) {
    return _Slot(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      groomerId: groomerId ?? this.groomerId,
      groomerName: groomerName ?? this.groomerName,
      status: status ?? this.status,
      capacity: capacity ?? this.capacity,
    );
  }
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
  bool _loadingStep1 = false;   // POST /api/availability
  bool _loadingStep2 = false;   // Fallback / legacy

  // Store state from availability response
  bool _storeClosed    = false;
  String? _holidayName;
  String? _storeOpenTime;   // e.g. "08:00"
  String? _storeCloseTime;  // e.g. "17:30"
  Map<String, dynamic>? _groomerWorkingHours;
  String? _scheduleStatus;
  String? _scheduleReason;
  List<Map<String, dynamic>> _slotTimeline = [];
  Map<String, dynamic> _slotColors = {};

  // Error state
  bool _slotsError = false;
  String? _slotsErrorMessage;

  // Groomer list (includes synthetic "No Preference" at index 0)
  List<Map<String, dynamic>> _groomerList = [
    {'id': 'any', 'initial': 'ANY', 'name': 'No Pref', 'available': true},
  ];

  // Currently selected groomer ID ("any" = no preference)
  String _selectedGroomerId = 'any';

  // Slots to render — built from API response
  List<_Slot> _slots = [];

  // Booked slot raw data for the current groomer / all groomers
  List<Map<String, dynamic>> _bookedSlots = [];

  // Raw groomers from last Step 2 response (needed when user switches chips)
  List<dynamic> _rawGroomers = [];

  // Multi-booking slot capacity data from Step 1 POST /api/availability
  final Map<String, Map<String, dynamic>> _step1SlotDataByStartTime = {};
  final Map<String, int> _step1BookingCounts = {};
  final Map<String, int> _dynamicGroomerMap = {};

  // Active bookings for current authenticated customer (used strictly for duplicate booking validation)
  List<Map<String, dynamic>> _userActiveBookings = [];

  // Tracks slots for which the customer has already acknowledged the conflict warning
  final Set<String> _warnedSlots = {};

  Future<bool?> _showPetConflictWarningDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 24),
            const SizedBox(width: 8),
            Text(
              'Booking Notice',
              style: AppFonts.parkinsans(
                size: 18,
                weight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ),
        content: Text(
          BookingDateUtils.duplicatePetBookingWarningMessage,
          style: AppFonts.poppins(
            size: 14,
            color: const Color(0xFF4B5563),
            height: 1.45,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              'Cancel',
              style: AppFonts.poppins(size: 14, weight: FontWeight.w500),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111827),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'Continue',
              style: AppFonts.poppins(
                size: 14,
                weight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
      final results = await Future.wait([
        ServicesLocator.storeRepository.getStoreSchedule(),
        ServicesLocator.storeRepository.getHolidays(),
        ServicesLocator.storeRepository.getGroomers(),
      ]);
      final groomers = (results[2] as List<dynamic>?) ?? ServicesLocator.storeRepository.cachedGroomers;
      if (mounted) {
        if (_rawGroomers.isEmpty && groomers.isNotEmpty) {
          _updateGroomerChips(groomers);
        }
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

  // ── Web-aligned availability load ──────────────────────────────────────────

  Future<void> _loadAvailability() async {
    if (_draft.date == null || _draft.package == null) return;

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
    });

    final dateStr = DateFormat('yyyy-MM-dd').format(_draft.date!);
    final ids = _draft.extractServiceIds();
    final serviceId = ids['serviceId'] as int?;
    final packageId = ids['packageId'] as int?;
    final addOnIds = _draft.extractAddOnIds();
    final petId = BookingDateUtils.parsePetIdFromPet(_draft.pet);
    final petSizeKey = _draft.petSizeKey;

    // Resolve current groomer ID (0 = any / no preference)
    int groomerId = 0;
    final gId = _selectedGroomerId;
    if (gId != 'any') {
      final parsed = int.tryParse(gId) ?? 0;
      groomerId = BookingDateUtils.resolveCanonicalGroomerId(parsed) ?? parsed;
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

    _log.d('BookingDateTimePageMobile::_loadAvailability::Calling POST /api/availability'
        ' date=$dateStr serviceId=$serviceId packageId=$packageId'
        ' addOnIds=$addOnIds groomerId=$groomerId petId=$petId petSizeKey=$petSizeKey');

    int durationMinutes = 60; // safe fallback
    try {
      final availResp = await ServicesLocator.bookingRepository.getAvailability(
        date: dateStr,
        serviceId: serviceId,
        packageId: packageId,
        addOnIds: addOnIds.isEmpty ? null : addOnIds,
        groomerId: groomerId > 0 ? groomerId : 0,
        petId: (petId != null && petId > 0) ? petId : null,
        petSizeKey: petSizeKey,
      );

      _log.d('BookingDateTimePageMobile::_loadAvailability::Response received: ${availResp?["success"]}');

      if (!mounted) return;

      if (availResp != null &&
          availResp['success'] == true &&
          availResp['data'] != null) {
        final d = availResp['data'] as Map<String, dynamic>;
        final apiDur = d['totalDurationMinutes'];
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

        final sSub = d['serviceSubtotal'];
        if (sSub is num) {
          _draft.apiServiceSubtotal = sSub.toDouble();
        } else if (sSub is String) {
          _draft.apiServiceSubtotal =
              double.tryParse(sSub.replaceAll(RegExp(r'[^0-9.]'), ''));
        }

        final pSub = d['packageSubtotal'];
        if (pSub is num) {
          _draft.apiPackageSubtotal = pSub.toDouble();
        } else if (pSub is String) {
          _draft.apiPackageSubtotal =
              double.tryParse(pSub.replaceAll(RegExp(r'[^0-9.]'), ''));
        }

        final tax = d['salesTax'];
        if (tax is num) {
          _draft.apiSalesTax = tax.toDouble();
        } else if (tax is String) {
          _draft.apiSalesTax =
              double.tryParse(tax.replaceAll(RegExp(r'[^0-9.]'), ''));
        }

        final tRate = d['taxRate'];
        if (tRate is num) {
          _draft.apiTaxRate = tRate.toDouble();
        } else if (tRate is String) {
          _draft.apiTaxRate = double.tryParse(tRate);
        }

        final totWithTax = d['totalWithTax'];
        if (totWithTax is num) {
          _draft.apiTotalWithTax = totWithTax.toDouble();
        } else if (totWithTax is String) {
          _draft.apiTotalWithTax =
              double.tryParse(totWithTax.replaceAll(RegExp(r'[^0-9.]'), ''));
        }

        final stateName = d['stateName']?.toString() ?? d['stateCode']?.toString();
        if (stateName != null && stateName.isNotEmpty && stateName != 'null') {
          _draft.apiStateName = stateName;
        }

        final isClosed = d['closed'] == true;
        final holiday = d['holiday'];
        final storeHours = d['storeWorkingHours'] as Map<String, dynamic>?;
        final groomerHours = d['groomerWorkingHours'] as Map<String, dynamic>?;
        final scheduleStatus = d['scheduleStatus']?.toString();
        final scheduleReason = d['scheduleReason']?.toString();
        final slotTimeline = (d['slotTimeline'] as List<dynamic>?)
            ?.whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList() ?? [];
        final slotColors = d['slotColors'] as Map<String, dynamic>? ?? {};

        final apiGroomers = (d['groomers'] as List<dynamic>?) ?? [];
        _rawGroomers = apiGroomers;

        _updateGroomerChips(apiGroomers);

        final hasSlotChoices = (d['timeSlotChoices'] is List && (d['timeSlotChoices'] as List).isNotEmpty) ||
            (d['availableSlots'] is List && (d['availableSlots'] as List).isNotEmpty);

        if (!hasSlotChoices && !isClosed && holiday == null) {
          await _fallbackLoadGroomerAvailability(dateStr, groomerId, durationMinutes);
          return;
        }

        final slots = _buildSlotsFromAvailability(
          data: d,
          selectedId: _selectedGroomerId,
          dateStr: dateStr,
        );

        final booked = _extractBookedSlots(d);

        setState(() {
          _loadingStep1 = false;
          _loadingStep2 = false;
          _storeClosed = isClosed;
          _holidayName = (holiday is Map ? holiday['name'] : holiday)?.toString();
          _storeOpenTime = storeHours?['open']?.toString();
          _storeCloseTime = storeHours?['close']?.toString();
          _groomerWorkingHours = groomerHours;
          _scheduleStatus = scheduleStatus;
          _scheduleReason = scheduleReason;
          _slotTimeline = slotTimeline;
          _slotColors = slotColors;
          _slots = slots;
          _bookedSlots = booked;
          _slotsError = false;
          _slotsErrorMessage = null;
        });

        _validateSelectedSlot();
        return;
      }
    } catch (e) {
      _log.w('BookingDateTimePageMobile::_loadAvailability::POST /api/availability error=$e');
    }

    // Graceful fallback to GET /api/groomer-availability if POST failed or returned empty
    await _fallbackLoadGroomerAvailability(dateStr, groomerId, durationMinutes);
  }

  Future<void> _fallbackLoadGroomerAvailability(
    String dateStr,
    int groomerId,
    int durationMinutes,
  ) async {
    if (!mounted) return;
    setState(() {
      _loadingStep1 = false;
      _loadingStep2 = true;
    });

    try {
      final resp = await ServicesLocator.bookingRepository.getGroomerAvailability(
        date: dateStr,
        durationMinutes: durationMinutes,
        groomerId: groomerId > 0 ? groomerId : null,
      );

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

      final data = resp['data'] as Map<String, dynamic>;
      final storeData = data['store'] as Map<String, dynamic>?;
      final rawGroomers = data['groomers'] as List<dynamic>? ?? [];

      final opHours = storeData?['operationalHours'] as Map<String, dynamic>?;
      final isClosed = storeData?['closed'] == true;
      final holiday = storeData?['holiday'];

      _rawGroomers = rawGroomers;
      _updateGroomerChips(rawGroomers);

      final slots = _buildSlots(
        rawGroomers,
        _selectedGroomerId,
        bookingCountsByStartTime: _step1BookingCounts,
        slotDataByStartTime: _step1SlotDataByStartTime,
      );
      final booked = _buildBookedSlots(rawGroomers, _selectedGroomerId);

      setState(() {
        _loadingStep2 = false;
        _storeClosed = isClosed;
        _holidayName = holiday?.toString();
        _storeOpenTime = opHours?['startTime']?.toString();
        _storeCloseTime = opHours?['endTime']?.toString();
        _slots = slots;
        _bookedSlots = booked;
        _slotsError = false;
        _slotsErrorMessage = null;
      });

      _validateSelectedSlot();
    } catch (e) {
      _log.e('BookingDateTimePageMobile::_fallbackLoadGroomerAvailability::Exception: $e');
      if (mounted) {
        setState(() {
          _loadingStep2 = false;
          _slotsError = true;
          _slotsErrorMessage =
              'Unable to load time slots. Please try again.';
        });
      }
    }
  }

  void _updateGroomerChips(List<dynamic> apiGroomers) {
    final chips = <Map<String, dynamic>>[
      {'id': 'any', 'initial': 'ANY', 'name': 'No Pref', 'available': true},
    ];

    final groomerSource = apiGroomers.isNotEmpty
        ? apiGroomers
        : ServicesLocator.storeRepository.cachedGroomers;

    final seenIds = <String>{};
    for (final g in groomerSource.whereType<Map>()) {
      final rawId = g['id'] ?? g['groomerId'] ?? g['GroomerId'] ?? g['batherId'] ?? g['BatherId'];
      final gIdStr = (rawId ?? '').toString();
      if (gIdStr.isEmpty || seenIds.contains(gIdStr)) continue;
      seenIds.add(gIdStr);

      final firstName = g['firstName']?.toString() ?? g['FirstName']?.toString() ?? '';
      final lastName = g['lastName']?.toString() ?? g['LastName']?.toString() ?? '';
      final fullName = (g['name'] ?? (lastName.isNotEmpty ? '$firstName $lastName' : firstName)).toString().trim();
      final role = (g['role'] ?? g['Role'] ?? 'Groomer').toString().trim();
      final gCode = (g['groomerCode'] ?? g['GroomerId'] ?? g['BatherId'] ?? '').toString();
      final schedStatus = g['scheduleStatus']?.toString();
      final isAvail = g['available'] != false && g['isAvailable'] != false && schedStatus != 'time_off' && schedStatus != 'week_off';

      chips.add({
        'id': gIdStr,
        'groomerCode': gCode,
        'initial': fullName.isNotEmpty ? fullName[0].toUpperCase() : 'G',
        'name': fullName.isNotEmpty ? fullName : 'Groomer $gIdStr',
        'role': role,
        'available': isAvail,
        'scheduleStatus': schedStatus,
        'scheduleReason': g['scheduleReason']?.toString(),
      });
    }

    _groomerList = chips;
  }

  List<Map<String, dynamic>> _extractBookedSlots(Map<String, dynamic> d) {
    final rawBooked = d['bookedSlots'] as List<dynamic>?;
    if (rawBooked != null && rawBooked.isNotEmpty) {
      return rawBooked
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    final choices = d['timeSlotChoices'] as List<dynamic>?;
    if (choices != null) {
      return choices
          .whereType<Map>()
          .where((m) => m['status'] == 'booked' || m['isAvailable'] == false)
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return [];
  }

  List<_Slot> _buildSlotsFromAvailability({
    required Map<String, dynamic> data,
    required String selectedId,
    required String dateStr,
  }) {
    final rawChoices = data['timeSlotChoices'] as List<dynamic>? ?? [];
    final rawAvail = data['availableSlots'] as List<dynamic>? ?? [];
    final selectedStartTime = _draft.timeSlot;

    final isToday = _draft.date != null && _isSameDay(_draft.date!, DateTime.now());
    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;

    bool isPast(String st) {
      if (!isToday) return false;
      return _toMinutes(st) <= nowMinutes;
    }

    final int groomerIdInt = selectedId != 'any' ? (int.tryParse(selectedId) ?? 0) : 0;
    List<Map<String, dynamic>> candidateSlots = [];

    if (rawChoices.isNotEmpty) {
      for (final c in rawChoices.whereType<Map>()) {
        final st = BookingDateUtils.normalizeTimeString(c['startTime']?.toString() ?? '') ?? '';
        final et = BookingDateUtils.normalizeTimeString(c['endTime']?.toString() ?? '') ?? '';
        if (st.isEmpty || isPast(st)) continue;

        candidateSlots.add({
          'startTime': st,
          'endTime': et,
          'status': c['status']?.toString() ?? (c['isAvailable'] == true ? 'available' : 'booked'),
          'isAvailable': c['isAvailable'] == true,
          'groomerId': c['groomerId'],
          'groomerName': c['groomerName']?.toString() ?? '',
          'bookingCount': c['bookingCount'] ?? (c['isAvailable'] == true ? 0 : 1),
          'maxBookings': c['maxBookings'] ?? 1,
          'remaining': c['remaining'] ?? (c['isAvailable'] == true ? 1 : 0),
        });
      }
    } else {
      // Fallback to availableSlots
      final seenTimes = <String>{};
      for (final a in rawAvail.whereType<Map>()) {
        final st = BookingDateUtils.normalizeTimeString(a['startTime']?.toString() ?? '') ?? '';
        final et = BookingDateUtils.normalizeTimeString(a['endTime']?.toString() ?? '') ?? '';
        if (st.isEmpty || isPast(st)) continue;
        if (groomerIdInt == 0) {
          if (seenTimes.contains(st)) continue;
          seenTimes.add(st);
        } else {
          final sGId = (a['groomerId'] ?? '').toString();
          if (sGId.isNotEmpty && sGId != selectedId) continue;
        }

        candidateSlots.add({
          'startTime': st,
          'endTime': et,
          'status': 'available',
          'isAvailable': a['isAvailable'] != false,
          'groomerId': a['groomerId'],
          'groomerName': a['groomerName']?.toString() ?? '',
          'bookingCount': a['bookingCount'] ?? 0,
          'maxBookings': a['maxBookings'] ?? 1,
          'remaining': a['remaining'] ?? 1,
        });
      }
    }

    // Apply web HD filter:
    // Available slots are always kept.
    // Non-available slots (booked, break, unavailable) are only kept if they do not overlap with any available slot.
    final availTimes = candidateSlots.where((s) => s['isAvailable'] == true).toList();
    final filtered = candidateSlots.where((s) {
      if (s['isAvailable'] == true) return true;
      if (availTimes.isEmpty) return true;
      final sStart = _toMinutes(s['startTime']);
      final sEnd = _toMinutes(s['endTime']);
      return !availTimes.any((a) {
        final aStart = _toMinutes(a['startTime']);
        final aEnd = _toMinutes(a['endTime']);
        return sStart < aEnd && sEnd > aStart;
      });
    }).toList();

    filtered.sort((a, b) => _toMinutes(a['startTime']).compareTo(_toMinutes(b['startTime'])));

    final petId = BookingDateUtils.parsePetIdFromPet(_draft.pet);
    final petName = BookingDateUtils.parsePetNameFromPet(_draft.pet);

    return filtered.map((s) {
      final st = s['startTime'] as String;
      final et = s['endTime'] as String;
      final isAvail = s['isAvailable'] == true;
      final statusStr = s['status'] as String? ?? 'available';
      final isSelected = BookingDateUtils.isSameTimeSlot(st, selectedStartTime);
      final rawGroomId = s['groomerId'];
      final int? gId = rawGroomId is int ? rawGroomId : int.tryParse(rawGroomId?.toString() ?? '');

      final isCustomerDuplicate = BookingDateUtils.isSlotAlreadyBookedByUser(
        slotDate: dateStr,
        slotStartTime: st,
        slotEndTime: et,
        slotDurationMinutes: _draft.apiDurationMinutes,
        slotGroomerId: gId,
        targetPetId: petId,
        targetPetName: petName,
        userBookings: _userActiveBookings,
      );

      _SlotStatus status;
      if (isCustomerDuplicate) {
        status = _SlotStatus.alreadyBooked;
      } else if (isSelected) {
        status = _SlotStatus.selected;
      } else if (!isAvail || statusStr == 'booked' || statusStr == 'break' || statusStr == 'unavailable') {
        status = _SlotStatus.booked;
      } else {
        status = _SlotStatus.available;
      }

      final cap = SlotCapacity(
        isMultiBookingEnabled: s['maxBookings'] != null && (s['maxBookings'] as int) > 1,
        maxBookings: s['maxBookings'] as int? ?? 1,
        bookingCount: isAvail ? (s['bookingCount'] as int? ?? 0) : 1,
        isAlreadyBookedByCurrentUser: isCustomerDuplicate,
        remaining: isAvail ? (s['remaining'] as int? ?? 1) : 0,
        isAvailable: isAvail && !isCustomerDuplicate,
      );

      return _Slot(
        startTime: st,
        endTime: et,
        groomerId: gId,
        groomerName: s['groomerName']?.toString(),
        status: status,
        capacity: cap,
      );
    }).toList();
  }

  String get _selectedGroomerName {
    if (_selectedGroomerId == 'any') return 'Any available';
    final match = _groomerList.firstWhere(
      (g) => g['id']?.toString() == _selectedGroomerId,
      orElse: () => <String, dynamic>{},
    );
    return match['name']?.toString() ?? 'Groomer';
  }

  Widget _buildGroomerStatusAndTimeline() {
    if (_selectedGroomerId == 'any') {
      if (_storeOpenTime != null && _storeCloseTime != null) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.storefront_outlined, size: 16, color: _kTeal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Store hours: ${_fmt12(_storeOpenTime!)} – ${_fmt12(_storeCloseTime!)}. Times depend on each groomer\'s schedule.',
                  style: AppFonts.poppins(size: 12, weight: FontWeight.w400, color: _kSubText),
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final isClosed = _groomerWorkingHours?['closed'] == true ||
        _scheduleStatus == 'time_off' ||
        _scheduleStatus == 'week_off';
    final reason = _groomerWorkingHours?['reason']?.toString() ?? _scheduleReason;
    final open = _groomerWorkingHours?['open']?.toString();
    final close = _groomerWorkingHours?['close']?.toString();

    if (isClosed) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 18, color: _kAmber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_selectedGroomerName is not available on this date',
                    style: AppFonts.poppins(size: 13, weight: FontWeight.w600, color: const Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                reason,
                style: AppFonts.poppins(size: 12, weight: FontWeight.w400, color: const Color(0xFF92400E)),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (open != null && close != null && open.isNotEmpty && close.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF6EE7B7)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: _kTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_selectedGroomerName works ${_fmt12(open)} – ${_fmt12(close)} on this day.',
                    style: AppFonts.poppins(size: 12, weight: FontWeight.w500, color: _kTeal),
                  ),
                ),
              ],
            ),
          ),
        if (_slotTimeline.isNotEmpty) ...[
          _buildDayTimeline(),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildDayTimeline() {
    if (_slotTimeline.isEmpty) return const SizedBox.shrink();

    int totalDuration = 0;
    for (final seg in _slotTimeline) {
      final s = _toMinutes(seg['startTime']?.toString() ?? '');
      final e = _toMinutes(seg['endTime']?.toString() ?? '');
      if (e > s) totalDuration += (e - s);
    }
    if (totalDuration <= 0) return const SizedBox.shrink();

    Color getSegmentColor(String status) {
      final hex = _slotColors[status.toLowerCase()]?.toString();
      if (hex != null && hex.isNotEmpty) {
        final clean = hex.replaceAll('#', '');
        if (clean.length == 6) {
          final val = int.tryParse('FF$clean', radix: 16);
          if (val != null) return Color(val);
        }
      }
      switch (status.toLowerCase()) {
        case 'available':
          return const Color(0xFF0D9488); // Teal
        case 'break':
          return const Color(0xFFFBBF24); // Amber
        case 'booked':
          return const Color(0xFF64748B); // Slate
        case 'unavailable':
        default:
          return const Color(0xFFCBD5E1); // Slate light
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Groomer day schedule timeline',
          style: AppFonts.poppins(size: 12, weight: FontWeight.w500, color: _kSubText),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 18,
            width: double.infinity,
            color: const Color(0xFFE2E8F0),
            child: Row(
              children: _slotTimeline.map((seg) {
                final s = _toMinutes(seg['startTime']?.toString() ?? '');
                final e = _toMinutes(seg['endTime']?.toString() ?? '');
                final dur = (e - s).clamp(1, totalDuration);
                final color = getSegmentColor(seg['status']?.toString() ?? '');
                return Flexible(
                  flex: dur,
                  child: Container(
                    color: color,
                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _buildTimelineLegendItem(const Color(0xFF0D9488), 'Open'),
            _buildTimelineLegendItem(const Color(0xFF64748B), 'Booked'),
            _buildTimelineLegendItem(const Color(0xFFFBBF24), 'Break'),
            _buildTimelineLegendItem(const Color(0xFFCBD5E1), 'Unavailable'),
          ],
        ),
      ],
    );
  }

  Widget _buildTimelineLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppFonts.poppins(size: 11, weight: FontWeight.w400, color: _kSubText),
        ),
      ],
    );
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
        final normSt = BookingDateUtils.normalizeTimeString(st);
        if (normSt != null && normSt.isNotEmpty) {
          final sMap = Map<String, dynamic>.from(s);
          sMap['startTime'] = normSt;
          if (sMap['endTime'] != null) {
            sMap['endTime'] = BookingDateUtils.normalizeTimeString(sMap['endTime']) ?? sMap['endTime'];
          }
          if (!availSlotMap.containsKey(normSt)) {
            availSlotMap[normSt] = sMap;
          } else {
            final existingAvail = availSlotMap[normSt]!['isAvailable'] != false;
            final newAvail = sMap['isAvailable'] != false;
            if (!existingAvail && newAvail) {
              availSlotMap[normSt] = sMap;
            }
          }
        }
      }
    }
    if (slotDataByStartTime != null) {
      for (final entry in slotDataByStartTime.entries) {
        final normSt = BookingDateUtils.normalizeTimeString(entry.key);
        if (normSt == null || normSt.isEmpty) continue;
        final sData = entry.value;
        final sGroomId = sData['groomerId']?.toString();
        if (sGroomId == null || sGroomId.isEmpty || sGroomId == groomerId?.toString() || sGroomId == 'any') {
          if (!availSlotMap.containsKey(normSt)) {
            final sMap = Map<String, dynamic>.from(sData);
            sMap['startTime'] = normSt;
            if (sMap['endTime'] != null) {
              sMap['endTime'] = BookingDateUtils.normalizeTimeString(sMap['endTime']) ?? sMap['endTime'];
            }
            availSlotMap[normSt] = sMap;
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
      final st = BookingDateUtils.normalizeTimeString(entry.key) ?? entry.key;
      if (!addedKeys.contains(st)) {
        final slotApiData = entry.value;
        final slotDataWithCount = Map<String, dynamic>.from(slotApiData);
        final overlapCount = _countOverlappingBookings(_toMinutes(st), durationMin, bookedSlots);
        if (!slotDataWithCount.containsKey('bookingCount') || slotDataWithCount['bookingCount'] == null) {
          slotDataWithCount['bookingCount'] = bookingCountsByStartTime?[st] ?? overlapCount;
        }
        final capacity = SlotCapacity.fromSlotData(slotDataWithCount, groomerData: groomer);

        final rawEnd = slotApiData['endTime']?.toString();
        final normEnd = (rawEnd != null && rawEnd.isNotEmpty)
            ? (BookingDateUtils.normalizeTimeString(rawEnd) ?? rawEnd)
            : _fromMinutes(_toMinutes(st) + durationMin);

        slots.add({
          'startTime'   : st,
          'endTime'     : normEnd,
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
          final rawSt = s['startTime']?.toString() ?? '';
          final st = BookingDateUtils.normalizeTimeString(rawSt);
          if (st != null && st.isNotEmpty) {
            s['startTime'] = st;
            if (s['endTime'] != null) {
              s['endTime'] = BookingDateUtils.normalizeTimeString(s['endTime']) ?? s['endTime'];
            }
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
          final rawSt = s['startTime']?.toString() ?? '';
          final st = BookingDateUtils.normalizeTimeString(rawSt);
          if (st != null && st.isNotEmpty) {
            s['startTime'] = st;
            if (s['endTime'] != null) {
              s['endTime'] = BookingDateUtils.normalizeTimeString(s['endTime']) ?? s['endTime'];
            }
            if (!availMap.containsKey(st)) {
              availMap[st] = s;
            } else {
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
    }

    // Direct ingestion of any remaining available slots from slotDataByStartTime (POST /api/availability)
    if (slotDataByStartTime != null) {
      for (final entry in slotDataByStartTime.entries) {
        final st = BookingDateUtils.normalizeTimeString(entry.key);
        if (st == null || st.isEmpty) continue;
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

          final rawEnd = slotData['endTime']?.toString();
          final normEnd = (rawEnd != null && rawEnd.isNotEmpty)
              ? (BookingDateUtils.normalizeTimeString(rawEnd) ?? rawEnd)
              : _fromMinutes(_toMinutes(st) + durationMin);

          availMap[st] = {
            'startTime'   : st,
            'endTime'     : normEnd,
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
      final isSelected = BookingDateUtils.isSameTimeSlot(st, selectedStartTime);
      final rawGroomId = raw['groomerId'];
      final int? gId   = rawGroomId is int ? rawGroomId : int.tryParse(rawGroomId?.toString() ?? '');

      // ── Customer & Pet Specific Active Duplicate Check ───────────────────────────
      final dateStr = _draft.date != null ? DateFormat('yyyy-MM-dd').format(_draft.date!) : '';
      final petId = BookingDateUtils.parsePetIdFromPet(_draft.pet);
      final petName = BookingDateUtils.parsePetNameFromPet(_draft.pet);
      final bool isAlreadyBooked = BookingDateUtils.isSlotAlreadyBookedByUser(
        slotDate: dateStr,
        slotStartTime: st,
        slotEndTime: raw['endTime']?.toString() ?? '',
        slotGroomerId: gId,
        slotDurationMinutes: _draft.apiDurationMinutes,
        targetPetId: petId,
        targetPetName: petName,
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
    final seen = <String>{};
    void addSlot(Map b) {
      final st = BookingDateUtils.normalizeTimeString(b['startTime']) ?? b['startTime']?.toString() ?? '';
      final et = BookingDateUtils.normalizeTimeString(b['endTime']) ?? b['endTime']?.toString() ?? '';
      final key = '$st-$et';
      if (key.isNotEmpty && key != '-' && !seen.contains(key)) {
        seen.add(key);
        final copy = Map<String, dynamic>.from(b);
        copy['startTime'] = st;
        copy['endTime'] = et;
        result.add(copy);
      }
    }

    if (selectedId == 'any') {
      for (final g in rawGroomers.whereType<Map>()) {
        final bs = g['bookedSlots'] as List<dynamic>? ?? [];
        for (final b in bs.whereType<Map>()) {
          addSlot(b);
        }
      }
    } else {
      final g = rawGroomers.whereType<Map>().firstWhere(
        (g) => (g['id'] ?? '').toString() == selectedId,
        orElse: () => <String, dynamic>{},
      );
      final bs = g['bookedSlots'] as List<dynamic>? ?? [];
      for (final b in bs.whereType<Map>()) {
        addSlot(b);
      }
    }
    return result;
  }

  // ── slot selection ─────────────────────────────────────────────────────────

  void _selectSlot(_Slot slot) async {
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
          'You already have an active booking with this groomer for this time slot.',
        );
      }
      final reason = slot.status == _SlotStatus.alreadyBooked
          ? 'alreadyBooked (user already has active booking with this groomer)'
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
    final petId = BookingDateUtils.parsePetIdFromPet(_draft.pet);
    final petName = BookingDateUtils.parsePetNameFromPet(_draft.pet);
    final slotKey = '$dateStr-${slot.startTime}';

    final conflictingBooking = BookingDateUtils.findConflictingBookingForPetWithAnotherGroomer(
      slotDate: dateStr,
      slotStartTime: slot.startTime,
      slotEndTime: slot.endTime,
      slotDurationMinutes: _draft.apiDurationMinutes,
      slotGroomerId: slot.groomerId,
      targetPetId: petId,
      targetPetName: petName,
      userBookings: _userActiveBookings,
    );

    if (conflictingBooking != null && !_warnedSlots.contains(slotKey)) {
      _log.w('BookingDateTimePage::_selectSlot::Pet has overlapping booking with another groomer during ${slot.startTime}-${slot.endTime}. Showing warning.');
      final shouldProceed = await _showPetConflictWarningDialog();
      if (shouldProceed != true) {
        _log.d('BookingDateTimePage::_selectSlot::Customer cancelled after warning dialog.');
        return;
      }
      _warnedSlots.add(slotKey);
    }

    if (!mounted) return;

    _log.i('BookingDateTimePage::_selectSlot::Slot selected: ${slot.startTime}-${slot.endTime}'
        ' bookingCount=${slot.capacity.bookingCount} maxBookings=${slot.capacity.maxBookings}'
        ' remaining=${slot.capacity.remaining} isAvailable=${slot.capacity.isAvailable}'
        ' isSelectable=true');

    final canonicalSlotGroomId = BookingDateUtils.resolveCanonicalGroomerId(
      slot.groomerId,
      groomerName: slot.groomerName,
      dynamicGroomerMap: _dynamicGroomerMap,
    ) ?? slot.groomerId;

    _draft.setSelectedSlot({
      'startTime'  : slot.startTime,
      'endTime'    : slot.endTime,
      'groomerId'  : canonicalSlotGroomId,
      'groomerName': slot.groomerName ?? '',
    });

    // If "No Preference" and slot carries a groomer, pin that groomer in draft
    if (_selectedGroomerId == 'any' &&
        canonicalSlotGroomId != null &&
        canonicalSlotGroomId > 0) {
      final matchedChip = _groomerList.firstWhere(
        (c) => c['id'] == canonicalSlotGroomId.toString(),
        orElse: () => <String, dynamic>{},
      );
      _draft.setGroomer({
        'id'         : canonicalSlotGroomId.toString(),
        'groomerCode': matchedChip['groomerCode'] ?? '',
        'name'       : (slot.groomerName?.isNotEmpty == true)
            ? slot.groomerName!
            : (matchedChip['name'] ?? ''),
        'initial'    : (slot.groomerName?.isNotEmpty == true)
            ? slot.groomerName![0].toUpperCase()
            : (matchedChip['initial'] ?? 'G'),
        'role'       : matchedChip['role'] ?? '',
      });
    }

    // Update slots so the selected button re-renders
    setState(() {
      _slots = _slots.map((s) {
        if (s.status == _SlotStatus.booked ||
            s.status == _SlotStatus.atCapacity ||
            s.status == _SlotStatus.alreadyBooked) {
          return s;
        }
        final isSelected = BookingDateUtils.isSameTimeSlot(s.startTime, slot.startTime);
        return s.copyWith(
          status: isSelected ? _SlotStatus.selected : _SlotStatus.available,
        );
      }).toList();
    });
  }

  void _validateSelectedSlot() {
    if (_draft.timeSlot == null) return;
    final stillAvailable = _slots.any(
        (s) => BookingDateUtils.isSameTimeSlot(s.startTime, _draft.timeSlot) &&
               s.status != _SlotStatus.booked &&
               s.status != _SlotStatus.atCapacity &&
               s.status != _SlotStatus.alreadyBooked &&
               s.capacity.isAvailable &&
               s.capacity.remaining > 0);
    if (!stillAvailable) {
      _log.d('BookingDateTimePage::_validateSelectedSlot::Selected slot is no longer available — clearing.');
      _draft.clearSelectedSlot();
      setState(() {
        _slots = _slots.map((s) {
          if (s.status == _SlotStatus.selected) {
            return s.copyWith(status: _SlotStatus.available);
          }
          return s;
        }).toList();
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

  void _onContinue() async {
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
    final petId = BookingDateUtils.parsePetIdFromPet(_draft.pet);
    final petName = BookingDateUtils.parsePetNameFromPet(_draft.pet);
    final slotKey = '$dateStr-$slot';

    final conflictingBooking = BookingDateUtils.findConflictingBookingForPetWithAnotherGroomer(
      slotDate: dateStr,
      slotStartTime: slot,
      slotEndTime: end,
      slotDurationMinutes: _draft.apiDurationMinutes,
      slotGroomerId: _draft.selectedSlot?['groomerId'] ?? _draft.groomer?['id'],
      targetPetId: petId,
      targetPetName: petName,
      userBookings: _userActiveBookings,
    );
    if (conflictingBooking != null && !_warnedSlots.contains(slotKey)) {
      final shouldProceed = await _showPetConflictWarningDialog();
      if (shouldProceed != true) {
        return;
      }
      _warnedSlots.add(slotKey);
    }

    if (!mounted) return;
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
    final endSlot      = _draft.endTime;
    final slotLabel    = (endSlot != null && endSlot.isNotEmpty)
        ? '${_fmt12(slot)} – ${_fmt12(endSlot)}'
        : _fmt12(slot);
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

        bool canPop = false;
        try {
          canPop = context.canPop();
        } catch (_) {
          try {
            canPop = Navigator.of(context).canPop();
          } catch (_) {}
        }

        return PopScope(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            try {
              context.goNamed(RouteNames.bookingService);
            } catch (_) {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            }
          },
          child: Scaffold(
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
                          const SizedBox(height: 16),

                          // ── Groomer schedule info & timeline ──────────
                          if (!_storeClosed && _holidayName == null) ...[
                            _buildGroomerStatusAndTimeline(),
                          ],

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
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 560 ? 3 : 2;
              final isAny = _selectedGroomerId == 'any';
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _slots.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: isAny ? 52 : 46,
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
                    toMinutes: _toMinutes,
                    fromMinutes: _fromMinutes,
                    durationMinutes: _draft.apiDurationMinutes ?? 60,
                    showGroomerSubtitle: isAny,
                  );
                },
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
  final int Function(String)? toMinutes;
  final String Function(int)? fromMinutes;
  final int durationMinutes;
  final bool showGroomerSubtitle;

  const _SlotButton({
    required this.slot,
    required this.onTap,
    required this.fmt12,
    this.toMinutes,
    this.fromMinutes,
    this.durationMinutes = 60,
    this.showGroomerSubtitle = false,
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

    String endHhmm = slot.endTime;
    if (endHhmm.isEmpty && toMinutes != null && fromMinutes != null) {
      final startMin = toMinutes!(slot.startTime);
      endHhmm = fromMinutes!(startMin + (durationMinutes > 0 ? durationMinutes : 60));
    }
    final endStr = endHhmm.isNotEmpty ? fmt12(endHhmm) : '';

    final hasGroomer = showGroomerSubtitle &&
        slot.groomerName != null &&
        slot.groomerName!.isNotEmpty &&
        slot.groomerName != 'No Pref' &&
        !isUnavailable;

    return GestureDetector(
      onTap: isUnavailable
          ? () {
              if (isAlreadyBooked) {
                ToastUtil.showErrorToast(
                  context,
                  'You already have an active booking with this groomer for this time slot.',
                );
              }
              final reason = isAlreadyBooked
                  ? 'alreadyBooked (user already holds active booking with this groomer)'
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
        alignment   : Alignment.center,
        padding     : const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration  : BoxDecoration(
          color       : bg,
          borderRadius: BorderRadius.circular(14),
          border      : Border.all(color: borderColor, width: 1.4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 13,
                    color: fg.withValues(alpha: 0.75),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    fmt12(slot.startTime),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily     : 'Poppins',
                      fontSize       : 12,
                      fontWeight     : (isSelected || !isUnavailable) ? FontWeight.w600 : FontWeight.w400,
                      color          : fg,
                      decoration     : isUnavailable ? TextDecoration.lineThrough : null,
                      decorationColor: fg,
                    ),
                  ),
                  if (endStr.isNotEmpty)
                    Text(
                      ' – $endStr',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily     : 'Poppins',
                        fontSize       : 12,
                        fontWeight     : (isSelected || !isUnavailable) ? FontWeight.w600 : FontWeight.w400,
                        color          : fg,
                        decoration     : isUnavailable ? TextDecoration.lineThrough : null,
                        decorationColor: fg,
                      ),
                    ),
                ],
              ),
            ),
            if (hasGroomer) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '· ',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF6B7280),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      slot.groomerName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
