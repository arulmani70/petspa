import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/groomer_check_in_dialog.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/groomer_milestone_dialog.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/groomer_final_checkout_dialog.dart';
import 'package:shear_heaven_pet_spa/src/bookings/models/booking_receipt.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/booking_receipt_page_mobile.dart';

/// Dedicated screen for viewing salon-wide appointment schedules across all salon groomers.
///
/// Features:
/// - Consolidated salon schedule with dynamic groomer-based filtering ("All Groomers" + individual groomers).
/// - 4 dynamic summary stat cards (Total, Pending, Confirmed, Completed) reflecting current filter & date.
/// - Interactive date selector bar with day navigation and calendar picker.
/// - Appointment cards displaying Customer name, Pet name, Groomer name, Date & Time, Services, and Status.
/// - Appointment actions (Approve, Reject, Start, Complete) with real-time status updates.
/// - Strictly isolated state that never interferes with the individual groomer's personal home dashboard.
class AllGroomersSchedulePage extends StatefulWidget {
  final List<GroomerBooking>? initialBookings;
  final List<SalonGroomer>? initialSalonGroomers;
  final String? initialGroomerFilterId;

  const AllGroomersSchedulePage({
    super.key,
    this.initialBookings,
    this.initialSalonGroomers,
    this.initialGroomerFilterId,
  });

  @override
  State<AllGroomersSchedulePage> createState() => _AllGroomersSchedulePageState();
}

class _AllGroomersSchedulePageState extends State<AllGroomersSchedulePage> {
  DateTime _selectedDate = DateTime.now();
  bool _isDateRangeMode = false;
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now().add(const Duration(days: 6)),
  );
  Set<String> _selectedGroomerFilterIds = {'all'};
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasNextPage = false;
  String? _errorMessage;
  int _currentPage = 1;
  final int _pageSize = 10;
  final Map<int, int> _cachedGroomerCounts = {};

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<SalonGroomer> _salonGroomers = [];
  List<GroomerBooking> _allBookings = [];
  final Set<int> _processingBookingIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static String _normalizePhone(String input) {
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  @override
  void initState() {
    super.initState();
    final currentGroomer = ServicesLocator.groomerHomeRepository.getCurrentGroomer();
    if (widget.initialGroomerFilterId != null && widget.initialGroomerFilterId!.isNotEmpty) {
      _selectedGroomerFilterIds = {widget.initialGroomerFilterId!};
    } else if (currentGroomer != null && currentGroomer.id > 0) {
      _selectedGroomerFilterIds = {currentGroomer.id.toString()};
    } else {
      _selectedGroomerFilterIds = {'all'};
    }

    if (widget.initialBookings != null) {
      _allBookings = List.from(widget.initialBookings!);
      _salonGroomers = List.from(widget.initialSalonGroomers ?? []);
      _isLoading = false;
      if (_salonGroomers.isEmpty && _allBookings.isNotEmpty) {
        final Map<int, SalonGroomer> extracted = {};
        for (final b in _allBookings) {
          final canonicalId = BookingDateUtils.resolveCanonicalGroomerId(
            b.groomerId,
            groomerCode: b.groomerCode,
            groomerName: b.groomerName ?? b.effectiveGroomerName,
          ) ?? b.groomerId ?? 0;
          if (canonicalId > 0 && !extracted.containsKey(canonicalId)) {
            final name = b.groomerName ?? b.effectiveGroomerName;
            final code = b.groomerCode ?? 'G00$canonicalId';
            final parts = name.split(' ');
            extracted[canonicalId] = SalonGroomer(
              id: canonicalId,
              groomerCode: code,
              firstName: parts.first,
              lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
              name: name,
            );
          }
        }
        if (extracted.isNotEmpty) {
          _salonGroomers = extracted.values.toList();
        }
      }
      _updateCachedGroomerCounts();
    } else {
      _loadData();
    }
  }

  Future<void> _loadSchedule({bool showLoading = true, bool isLoadMore = false}) async {
    if (widget.initialBookings != null && widget.initialBookings!.isNotEmpty && !isLoadMore) {
      return;
    }
    if (!mounted) return;

    if (isLoadMore) {
      if (_isLoadingMore) return;
      setState(() {
        _isLoadingMore = true;
      });
    } else {
      if (showLoading) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
          _currentPage = 1;
        });
      }
    }

    final targetPage = isLoadMore ? _currentPage + 1 : 1;
    final allSalonGroomerIds = _salonGroomers.map((g) => g.id).where((id) => id > 0).toSet().toList();
    final List<int>? groomerIdsToFetch = allSalonGroomerIds.isNotEmpty ? allSalonGroomerIds : null;

    try {
      final result = await ServicesLocator.groomerHomeRepository.getAllGroomersBookingsWithPagination(
        groomerIds: groomerIdsToFetch,
        date: !_isDateRangeMode ? DateFormat('yyyy-MM-dd').format(_selectedDate) : null,
        startDate: _isDateRangeMode ? DateFormat('yyyy-MM-dd').format(_selectedDateRange.start) : null,
        endDate: _isDateRangeMode ? DateFormat('yyyy-MM-dd').format(_selectedDateRange.end) : null,
        page: targetPage,
        limit: _pageSize,
      );

      final appointments = result.appointments;

      if (!mounted) return;
      setState(() {
        if (isLoadMore) {
          _currentPage = targetPage;
          _isLoadingMore = false;
          _hasNextPage = result.hasNextPage;

          final existingKeys = _allBookings.map((b) => b.bookingId > 0 ? 'id_${b.bookingId}' : 'slot_${b.groomerId}_${b.bookingDate}_${b.startTime}_${b.endTime}').toSet();
          for (final b in appointments) {
            final key = b.bookingId > 0 ? 'id_${b.bookingId}' : 'slot_${b.groomerId}_${b.bookingDate}_${b.startTime}_${b.endTime}';
            if (!existingKeys.contains(key)) {
              _allBookings.add(b);
              existingKeys.add(key);
            }
          }
        } else {
          _currentPage = 1;
          _allBookings = appointments;
          _isLoading = false;
          _hasNextPage = result.hasNextPage;
        }

        _updateCachedGroomerCounts();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        if (!isLoadMore) {
          final displayTimeline = !_isDateRangeMode
              ? DateFormat('yyyy-MM-dd').format(_selectedDate)
              : '${DateFormat('yyyy-MM-dd').format(_selectedDateRange.start)} to ${DateFormat('yyyy-MM-dd').format(_selectedDateRange.end)}';
          _errorMessage = 'Unable to load salon appointments for $displayTimeline. Pull to refresh.';
        }
      });
    }
  }

  Future<void> _loadData() async {
    if (widget.initialBookings != null && _allBookings.isNotEmpty) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_salonGroomers.isEmpty) {
        final groomers = await ServicesLocator.groomerHomeRepository.getSalonGroomers();
        if (mounted) {
          setState(() {
            _salonGroomers = groomers;
            _updateCachedGroomerCounts();
          });
        }
      }

      // Default to logged-in groomer if not explicitly set
      if (widget.initialGroomerFilterId == null && (_selectedGroomerFilterIds.contains('all') || _selectedGroomerFilterIds.isEmpty)) {
        final cur = ServicesLocator.groomerHomeRepository.getCurrentGroomer();
        if (cur != null && cur.id > 0) {
          _selectedGroomerFilterIds = {cur.id.toString()};
        }
      }

      await _loadSchedule(showLoading: false);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load salon appointments. Pull to refresh.';
      });
    }
  }

  List<GroomerBooking> get _bookingsForDate {
    if (!_isDateRangeMode) {
      return _allBookings
          .where((b) => BookingDateUtils.isSameCalendarDay(b.bookingDate, _selectedDate))
          .toList();
    } else {
      final start = BookingDateUtils.normalize(_selectedDateRange.start);
      final end = BookingDateUtils.normalize(_selectedDateRange.end);
      return _allBookings.where((b) {
        final dt = BookingDateUtils.parseCalendarDate(b.bookingDate);
        if (dt == null) return false;
        final norm = BookingDateUtils.normalize(dt);
        return (norm.isAfter(start) || norm.isAtSameMomentAs(start)) &&
            (norm.isBefore(end) || norm.isAtSameMomentAs(end));
      }).toList();
    }
  }

  List<GroomerBooking> get _filteredBookings {
    final list = _bookingsForDate;
    List<GroomerBooking> results;

    if (_selectedGroomerFilterIds.contains('all') || _selectedGroomerFilterIds.isEmpty) {
      results = list;
    } else {
      results = list.where((b) {
        for (final selectedId in _selectedGroomerFilterIds) {
          final targetId = int.tryParse(selectedId);
          final targetGroomer = _salonGroomers.where((g) => g.id.toString() == selectedId).firstOrNull;

          if (targetGroomer != null && _bookingMatchesGroomer(b, targetGroomer)) {
            return true;
          }
          final targetCode = targetGroomer?.groomerCode.toLowerCase();
          final targetName = targetGroomer?.name.toLowerCase();

          if (targetId != null && b.groomerId == targetId) return true;
          if (targetCode != null && targetCode.isNotEmpty && b.groomerCode?.toLowerCase() == targetCode) return true;
          if (targetName != null && targetName.isNotEmpty && b.groomerName?.toLowerCase() == targetName) return true;
          if (targetName != null && targetName.isNotEmpty && b.effectiveGroomerName.toLowerCase().contains(targetName)) return true;
        }
        return false;
      }).toList();
    }

    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return results;
    }

    final normalizedQueryPhone = _normalizePhone(query);
    final cleanQueryId = query.replaceAll('#', '').trim();

    return results.where((b) {
      // 1. Groomer Name
      if (b.groomerName != null && b.groomerName!.toLowerCase().contains(query)) {
        return true;
      }
      if (b.effectiveGroomerName.toLowerCase().contains(query)) {
        return true;
      }

      // 2. Customer Name
      if (b.customerName.toLowerCase().contains(query)) {
        return true;
      }

      // 3. Pet Name
      if (b.petName.toLowerCase().contains(query)) {
        return true;
      }

      // 4. Booking or appointment ID
      if (b.bookingId > 0) {
        final idStr = b.bookingId.toString();
        if (idStr.contains(query) || (cleanQueryId.isNotEmpty && idStr.contains(cleanQueryId))) {
          return true;
        }
      }

      // 5. Customer Mobile Number
      if (b.customerMobile.isNotEmpty) {
        final rawMobile = b.customerMobile.toLowerCase();
        if (rawMobile.contains(query)) {
          return true;
        }
        if (normalizedQueryPhone.isNotEmpty) {
          final normalizedMobile = _normalizePhone(b.customerMobile);
          if (normalizedMobile.contains(normalizedQueryPhone)) {
            return true;
          }
        }
      }

      // 6. Service Name
      if (b.serviceName.toLowerCase().contains(query)) {
        return true;
      }

      // 7. Customer special instructions (Step 2 & 5)
      if (b.specialInstructions != null && b.specialInstructions!.toLowerCase().contains(query)) {
        return true;
      }

      // 8. Pet Breed
      if (b.breed.toLowerCase().contains(query)) {
        return true;
      }

      return false;
    }).toList();
  }

  int get _statTotal => _filteredBookings.length;

  int get _statPending => _filteredBookings
      .where((b) => b.status.toLowerCase() == 'pending')
      .length;

  int get _statConfirmed => _filteredBookings
      .where((b) =>
          b.status.toLowerCase() == 'confirmed' ||
          b.status.toLowerCase() == 'in_progress' ||
          b.status.toLowerCase() == 'in-progress')
      .length;

  int get _statCompleted => _filteredBookings
      .where((b) =>
          b.status.toLowerCase() == 'completed' ||
          b.status.toLowerCase() == 'past')
      .length;

  String _formatCount(int count) {
    return count < 10 ? '0$count' : '$count';
  }

  String _formatDateRangeDisplay() {
    if (!_isDateRangeMode) {
      if (BookingDateUtils.isToday(_selectedDate)) {
        return 'Today, ${DateFormat('d MMM yyyy').format(_selectedDate)}';
      }
      return DateFormat('d MMM yyyy').format(_selectedDate);
    } else {
      final s = DateFormat('d MMM yyyy').format(_selectedDateRange.start);
      final e = DateFormat('d MMM yyyy').format(_selectedDateRange.end);
      final days = _selectedDateRange.duration.inDays + 1;
      return '$s – $e ($days days)';
    }
  }

  String _formatBookingDateDisplay(DateTime dt) {
    return _formatDateRangeDisplay();
  }

  Future<void> _pickSingleDate() async {
    final firstDate = DateTime(2020, 1, 1);
    final lastDate = DateTime(2035, 12, 31);
    final initialDate = _selectedDate.isBefore(firstDate)
        ? firstDate
        : (_selectedDate.isAfter(lastDate) ? lastDate : _selectedDate);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) => _datePickerTheme(child),
    );

    if (picked != null && mounted) {
      setState(() {
        _isDateRangeMode = false;
        _selectedDate = BookingDateUtils.normalize(picked);
        _currentPage = 1;
      });
      _loadSchedule();
    }
  }

  Future<void> _pickDateRange() async {
    final firstDate = DateTime(2020, 1, 1);
    final lastDate = DateTime(2035, 12, 31);

    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) => _datePickerTheme(child),
    );

    if (picked != null && mounted) {
      setState(() {
        _isDateRangeMode = true;
        _selectedDateRange = picked;
        _currentPage = 1;
      });
      _loadSchedule();
    }
  }

  Widget _datePickerTheme(Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF111827),
          onPrimary: Colors.white,
          onSurface: Color(0xFF111827),
        ),
        datePickerTheme: DatePickerThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          headerBackgroundColor: const Color(0xFF111827),
          headerForegroundColor: Colors.white,
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  void _showDatePickerOptionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Schedule Timeline',
                  style: AppFonts.parkinsans(
                    size: 17,
                    weight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Past, present, and future dates are unrestricted',
                  style: AppFonts.poppins(size: 12, color: const Color(0xFF6B7280)),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.today_rounded, color: Color(0xFF111827)),
                  title: Text('Single Date Picker', style: AppFonts.poppins(size: 14, weight: FontWeight.w600)),
                  subtitle: Text('View schedule for a specific single day', style: AppFonts.poppins(size: 12)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: !_isDateRangeMode ? const Color(0xFFF3F4F6) : null,
                  onTap: () {
                    Navigator.pop(context);
                    _pickSingleDate();
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.date_range_rounded, color: Color(0xFF111827)),
                  title: Text('Date Range Picker', style: AppFonts.poppins(size: 14, weight: FontWeight.w600)),
                  subtitle: Text('Select custom multi-day range (up to 92 days)', style: AppFonts.poppins(size: 12)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: _isDateRangeMode ? const Color(0xFFF3F4F6) : null,
                  onTap: () {
                    Navigator.pop(context);
                    _pickDateRange();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool get _isGroomerFiltered =>
      !_selectedGroomerFilterIds.contains('all') && _selectedGroomerFilterIds.isNotEmpty;

  SalonGroomer? get _currentFilteredGroomer {
    if (!_isGroomerFiltered) return null;
    return _salonGroomers
        .where((g) => _selectedGroomerFilterIds.contains(g.id.toString()))
        .firstOrNull;
  }

  List<SalonGroomer> get _sortedSalonGroomers {
    final cur = ServicesLocator.groomerHomeRepository.getCurrentGroomer();
    if (cur == null || cur.id <= 0) return _salonGroomers;
    final list = List<SalonGroomer>.from(_salonGroomers);
    list.sort((a, b) {
      final aIsMe = a.id == cur.id || a.groomerCode.toLowerCase() == cur.groomerCode.toLowerCase();
      final bIsMe = b.id == cur.id || b.groomerCode.toLowerCase() == cur.groomerCode.toLowerCase();
      if (aIsMe) return -1;
      if (bIsMe) return 1;
      return a.name.compareTo(b.name);
    });
    return list;
  }

  bool _bookingMatchesGroomer(GroomerBooking b, SalonGroomer g) {
    if (b.groomerId != null && b.groomerId! > 0 && b.groomerId == g.id) {
      return true;
    }
    final resolvedBookingId = BookingDateUtils.resolveCanonicalGroomerId(
      b.groomerId,
      groomerCode: b.groomerCode,
      groomerName: b.groomerName ?? b.effectiveGroomerName,
    );
    final resolvedGroomerId = BookingDateUtils.resolveCanonicalGroomerId(
      g.id,
      groomerCode: g.groomerCode,
      groomerName: g.name,
    ) ?? g.id;
    if (resolvedBookingId != null && resolvedBookingId == resolvedGroomerId) {
      return true;
    }
    if (b.groomerCode != null && b.groomerCode!.trim().isNotEmpty && g.groomerCode.trim().isNotEmpty) {
      if (b.groomerCode!.trim().toLowerCase() == g.groomerCode.trim().toLowerCase()) {
        return true;
      }
    }
    final targetName = g.name.trim().toLowerCase();
    if (targetName.isNotEmpty) {
      if (b.groomerName != null && b.groomerName!.trim().toLowerCase() == targetName) {
        return true;
      }
      final eff = b.effectiveGroomerName.trim().toLowerCase();
      if (eff == targetName || eff.contains(targetName)) {
        return true;
      }
      final fName = g.firstName.trim().toLowerCase();
      if (fName.isNotEmpty && (eff == fName || eff.startsWith('$fName ') || eff.contains(fName))) {
        return true;
      }
    }
    return false;
  }

  void _updateCachedGroomerCounts() {
    for (final g in _salonGroomers) {
      _cachedGroomerCounts[g.id] = _bookingsForDate.where((b) => _bookingMatchesGroomer(b, g)).length;
    }
  }

  int get _allGroomersTotalCount {
    if (_cachedGroomerCounts.isNotEmpty) {
      final sum = _cachedGroomerCounts.values.fold(0, (sum, count) => sum + count);
      if (sum > 0) return sum;
    }
    return _bookingsForDate.length;
  }

  int _countForGroomer(SalonGroomer groomer) {
    if (_cachedGroomerCounts.containsKey(groomer.id)) {
      final cached = _cachedGroomerCounts[groomer.id]!;
      if (cached > 0) return cached;
      final computed = _bookingsForDate.where((b) => _bookingMatchesGroomer(b, groomer)).length;
      return computed > 0 ? computed : cached;
    }
    return _bookingsForDate.where((b) => _bookingMatchesGroomer(b, groomer)).length;
  }

  bool _isOwnBooking(GroomerBooking booking) {
    final currentGroomer = ServicesLocator.groomerHomeRepository.getCurrentGroomer();
    if (currentGroomer == null) return false;

    if (booking.groomerId != null && booking.groomerId! > 0) {
      if (booking.groomerId == currentGroomer.id) return true;
    }
    if (booking.groomerCode != null && booking.groomerCode!.trim().isNotEmpty) {
      if (booking.groomerCode!.trim().toLowerCase() == currentGroomer.groomerCode.trim().toLowerCase()) {
        return true;
      }
    }
    final resolvedBookingId = BookingDateUtils.resolveCanonicalGroomerId(
      booking.groomerId,
      groomerCode: booking.groomerCode,
      groomerName: booking.groomerName,
    );
    final resolvedCurrentId = BookingDateUtils.resolveCanonicalGroomerId(
      currentGroomer.id,
      groomerCode: currentGroomer.groomerCode,
      groomerName: currentGroomer.fullName,
    );
    if (resolvedBookingId != null && resolvedCurrentId != null && resolvedBookingId == resolvedCurrentId) {
      return true;
    }
    final gName = booking.groomerName?.trim().toLowerCase();
    final curName = currentGroomer.fullName.trim().toLowerCase();
    if (gName != null && gName.isNotEmpty && curName.isNotEmpty && gName == curName) {
      return true;
    }
    return false;
  }

  Future<void> _handleApprove(GroomerBooking booking) async {
    if (!_isOwnBooking(booking)) {
      ToastUtil.showErrorToast(context, 'You cannot approve another groomer\'s appointment.');
      return;
    }
    if (_processingBookingIds.contains(booking.bookingId)) return;
    setState(() => _processingBookingIds.add(booking.bookingId));
    try {
      final res = await ServicesLocator.groomerHomeRepository.approveBookingDetails(
        booking.bookingId,
        booking: booking,
      );
      if (mounted) {
        if (res.success) {
          ToastUtil.showSuccessToast(context, 'Booking #${booking.bookingId} approved');
        } else {
          ToastUtil.showErrorToast(context, res.message);
        }
        await _loadSchedule();
      }
    } finally {
      if (mounted) setState(() => _processingBookingIds.remove(booking.bookingId));
    }
  }

  Future<void> _handleReject(GroomerBooking booking) async {
    if (!_isOwnBooking(booking)) {
      ToastUtil.showErrorToast(context, 'You cannot reject another groomer\'s appointment.');
      return;
    }
    if (_processingBookingIds.contains(booking.bookingId)) return;
    setState(() => _processingBookingIds.add(booking.bookingId));
    try {
      final res = await ServicesLocator.groomerHomeRepository.rejectBookingDetails(
        booking.bookingId,
        booking: booking,
      );
      if (mounted) {
        if (res.success) {
          ToastUtil.showSuccessToast(context, 'Booking #${booking.bookingId} rejected');
          await _loadSchedule();
        } else {
          ToastUtil.showErrorToast(context, res.message);
        }
      }
    } finally {
      if (mounted) setState(() => _processingBookingIds.remove(booking.bookingId));
    }
  }

  Future<void> _handleStart(GroomerBooking booking) async {
    if (!_isOwnBooking(booking)) {
      ToastUtil.showErrorToast(context, 'You cannot start another groomer\'s appointment.');
      return;
    }
    if (_processingBookingIds.contains(booking.bookingId)) return;
    setState(() => _processingBookingIds.add(booking.bookingId));
    try {
      final res = await ServicesLocator.groomerHomeRepository.startBookingDetails(
        booking.bookingId,
        booking: booking,
      );
      if (mounted) {
        if (res.success) {
          ToastUtil.showSuccessToast(context, 'Booking #${booking.bookingId} is in progress');
          await _loadSchedule();
        } else {
          ToastUtil.showErrorToast(context, res.message);
        }
      }
    } finally {
      if (mounted) setState(() => _processingBookingIds.remove(booking.bookingId));
    }
  }

  Future<void> _handleComplete(GroomerBooking booking) async {
    if (!_isOwnBooking(booking)) {
      ToastUtil.showErrorToast(context, 'You cannot complete another groomer\'s appointment.');
      return;
    }
    if (_processingBookingIds.contains(booking.bookingId)) return;

    await GroomerFinalCheckoutDialog.show(
      context,
      booking: booking,
      onCheckoutSuccess: (updated) async {
        await _loadSchedule();
      },
    );
  }

  Future<void> _handleCheckIn(GroomerBooking booking) async {
    if (!booking.isCheckedIn && !booking.canCheckIn()) {
      if (booking.isBeforeScheduledDate()) {
        ToastUtil.showErrorToast(
          context,
          'Check-in is only allowed on the scheduled booking date (${booking.formattedBookingDate}).',
        );
      } else if (booking.isAfterScheduledDate()) {
        ToastUtil.showErrorToast(
          context,
          'Check-in is closed because the scheduled booking date (${booking.formattedBookingDate}) has passed.',
        );
      } else {
        ToastUtil.showErrorToast(
          context,
          'Check-in is only allowed on the scheduled booking date.',
        );
      }
      return;
    }
    if (!_isOwnBooking(booking)) {
      ToastUtil.showErrorToast(context, 'You cannot check in another groomer\'s appointment.');
      return;
    }
    final updated = await GroomerCheckInDialog.show(
      context,
      booking: booking,
      onCheckInSuccess: (updatedBooking) {
        if (!mounted) return;
        setState(() {
          final idx = _allBookings.indexWhere((b) => b.bookingId == updatedBooking.bookingId);
          if (idx >= 0) {
            _allBookings[idx] = updatedBooking;
          }
        });
      },
    );
    if (updated != null && mounted) {
      await _loadSchedule();
    }
  }

  Future<void> _handleMilestone(GroomerBooking booking, MilestoneType milestoneType) async {
    if (!_isOwnBooking(booking)) {
      ToastUtil.showErrorToast(context, 'You cannot update milestones on another groomer\'s appointment.');
      return;
    }
    final updated = await GroomerMilestoneDialog.show(
      context,
      booking: booking,
      milestoneType: milestoneType,
      onMilestoneSuccess: (updatedBooking) {
        if (!mounted) return;
        setState(() {
          final idx = _allBookings.indexWhere((b) => b.bookingId == updatedBooking.bookingId);
          if (idx >= 0) {
            _allBookings[idx] = updatedBooking;
          }
        });
      },
    );
    if (updated != null && mounted) {
      await _loadSchedule();
    }
  }

  Future<void> _handleReadyForCheckout(GroomerBooking booking) async {
    if (!_isOwnBooking(booking)) {
      ToastUtil.showErrorToast(context, 'You cannot mark another groomer\'s appointment ready for checkout.');
      return;
    }
    if (_processingBookingIds.contains(booking.bookingId)) return;
    setState(() => _processingBookingIds.add(booking.bookingId));

    try {
      final res = await ServicesLocator.groomerHomeRepository.markReadyForCheckoutDetails(
        bookingId: booking.bookingId,
        booking: booking,
      );

      if (!mounted) return;

      if (res.success) {
        ToastUtil.showSuccessToast(context, res.message);
        final updatedBooking = res.updatedBooking ?? booking.copyWith(status: 'ready_for_checkout');
        setState(() {
          final idx = _allBookings.indexWhere((b) => b.bookingId == updatedBooking.bookingId);
          if (idx >= 0) {
            _allBookings[idx] = updatedBooking;
          }
        });
        await _loadSchedule();
      } else {
        ToastUtil.showErrorToast(context, res.message);
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.showErrorToast(context, 'Failed to mark ready for checkout: $e');
      }
    } finally {
      if (mounted) setState(() => _processingBookingIds.remove(booking.bookingId));
    }
  }

  Future<void> _handleSkipMilestones(GroomerBooking booking, {bool showConfirmation = false}) async {
    if (!_isOwnBooking(booking)) {
      ToastUtil.showErrorToast(context, 'You cannot skip milestones on another groomer\'s appointment.');
      return;
    }
    if (_processingBookingIds.contains(booking.bookingId)) return;

    if (showConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.fast_forward_rounded, color: Color(0xFFD97706), size: 22),
              const SizedBox(width: 8),
              Text(
                'Skip Milestones?',
                style: AppFonts.poppins(size: 16, weight: FontWeight.w600, color: const Color(0xFF1F2937)),
              ),
            ],
          ),
          content: Text(
            'Skip intermediate service milestones and mark booking #${booking.bookingId} (${booking.petName}) ready for checkout?',
            style: AppFonts.poppins(size: 13, color: const Color(0xFF4B5563)),
          ),
          actions: [
            TextButton(
              key: const Key('appointment_skip_cancel_button'),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: AppFonts.poppins(size: 13, weight: FontWeight.w500, color: const Color(0xFF6B7280)),
              ),
            ),
            ElevatedButton(
              key: const Key('appointment_skip_confirm_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Skip & Ready',
                style: AppFonts.poppins(size: 13, weight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;
    setState(() => _processingBookingIds.add(booking.bookingId));

    try {
      final res = await ServicesLocator.groomerHomeRepository.markReadyForCheckoutDetails(
        bookingId: booking.bookingId,
        booking: booking,
        skipMilestones: true,
      );

      if (!mounted) return;

      if (res.success) {
        ToastUtil.showSuccessToast(context, res.message);
        final updatedBooking = res.updatedBooking ?? booking.copyWith(status: 'ready_for_checkout');
        setState(() {
          final idx = _allBookings.indexWhere((b) => b.bookingId == updatedBooking.bookingId);
          if (idx >= 0) {
            _allBookings[idx] = updatedBooking;
          }
        });
        await _loadSchedule();
      } else {
        ToastUtil.showErrorToast(context, res.message);
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.showErrorToast(context, 'Failed to skip milestones: $e');
      }
    } finally {
      if (mounted) setState(() => _processingBookingIds.remove(booking.bookingId));
    }
  }

  String _formatCheckInTimestamp(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('h:mm a').format(dt.toLocal());
    } catch (_) {
      return raw;
    }
  }

  String _formatMilestoneTimestamp(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('h:mm a').format(dt.toLocal());
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedList = _filteredBookings;
    final formattedDate = _formatBookingDateDisplay(_selectedDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF111827)),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/groomer-home');
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All Groomers Schedule',
              style: AppFonts.parkinsans(
                size: 18,
                weight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            Text(
              'Consolidated salon appointment calendar',
              style: AppFonts.poppins(
                size: 11.5,
                weight: FontWeight.w400,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF111827)),
                  )
                : const Icon(Icons.refresh_rounded, size: 22, color: Color(0xFF111827)),
            tooltip: 'Refresh appointments',
            onPressed: _isLoading ? null : _loadData,
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE5E7EB), height: 1),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF111827),
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(
                  _errorMessage!,
                  style: AppFonts.poppins(size: 12, color: const Color(0xFFDC2626)),
                ),
              ),
            ],
            // ── Section 1: Dynamic Summary Stat Cards ──
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    number: _formatCount(_statTotal),
                    label: 'Total Bookings',
                    accentColor: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    number: _formatCount(_statPending),
                    label: 'Pending',
                    accentColor: const Color(0xFFD97706),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    number: _formatCount(_statConfirmed),
                    label: 'Confirmed',
                    accentColor: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    number: _formatCount(_statCompleted),
                    label: 'Completed',
                    accentColor: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Section 2: Date Selector Bar ──
            _buildDateSelectorBar(formattedDate),

            const SizedBox(height: 14),

            // ── Search Field ──
            _buildSearchField(),

            const SizedBox(height: 16),

            // ── Section 3: Groomer Filter Bar ──
            _buildGroomerFilterSection(),

            const SizedBox(height: 18),

            // ── Section 4: Appointment Schedule List ──
            Row(
              children: [
                Expanded(
                  child: Text(
                    _searchQuery.trim().isNotEmpty
                        ? 'Search Results (${displayedList.length})'
                        : 'Appointments (${displayedList.length})',
                    style: AppFonts.parkinsans(
                      size: 16.5,
                      weight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isGroomerFiltered) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        _selectedGroomerFilterIds.length > 1
                            ? '${_selectedGroomerFilterIds.length} Groomers'
                            : (_currentFilteredGroomer?.name ?? 'Filtered'),
                        style: AppFonts.poppins(
                          size: 11.5,
                          weight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            if (_isLoading && displayedList.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40.0),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF111827)),
                ),
              )
            else if (_errorMessage != null && _allBookings.isEmpty)
              _buildErrorRetryState()
            else if (displayedList.isEmpty)
              _searchQuery.trim().isNotEmpty
                  ? _buildSearchEmptyState()
                  : _buildEmptyState(formattedDate)
            else ...[
              ...displayedList.map((b) => _buildAppointmentCard(b)),
              if (_hasNextPage) ...[
                const SizedBox(height: 12),
                Center(
                  child: _isLoadingMore
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(color: Color(0xFF111827)),
                        )
                      : OutlinedButton.icon(
                          icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                          label: Text(
                            'Load More Appointments (Page ${_currentPage + 1})',
                            style: AppFonts.poppins(
                              size: 13,
                              weight: FontWeight.w600,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF111827),
                            side: const BorderSide(color: Color(0xFF111827)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                          ),
                          onPressed: () => _loadSchedule(isLoadMore: true),
                        ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String number,
    required String label,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: AppFonts.poppins(
                    size: 12.5,
                    weight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            number,
            style: AppFonts.poppins(
              size: 24,
              weight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelectorBar(String formattedDate) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          children: [
            // Previous Day / Period Button
            Tooltip(
              message: _isDateRangeMode ? 'Previous Period' : 'Previous Day',
              child: InkWell(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                onTap: () {
                  setState(() {
                    if (!_isDateRangeMode) {
                      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                    } else {
                      final diff = _selectedDateRange.duration;
                      _selectedDateRange = DateTimeRange(
                        start: _selectedDateRange.start.subtract(diff),
                        end: _selectedDateRange.end.subtract(diff),
                      );
                    }
                    _currentPage = 1;
                  });
                  _loadSchedule();
                },
                child: const SizedBox(
                  width: 48,
                  height: 52,
                  child: Center(
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 26,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ),
            ),

            // Date Text & Calendar / Date-Range Picker
            Expanded(
              child: Tooltip(
                message: 'Select Date or Date Range',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _showDatePickerOptionsModal,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isDateRangeMode ? Icons.date_range_rounded : Icons.calendar_today_outlined,
                            size: 16,
                            color: const Color(0xFF111827),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formattedDate,
                            style: AppFonts.poppins(
                              size: 14.5,
                              weight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down_rounded, size: 20, color: Color(0xFF6B7280)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Next Day / Period Button
            Tooltip(
              message: _isDateRangeMode ? 'Next Period' : 'Next Day',
              child: InkWell(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                onTap: () {
                  setState(() {
                    if (!_isDateRangeMode) {
                      _selectedDate = _selectedDate.add(const Duration(days: 1));
                    } else {
                      final diff = _selectedDateRange.duration;
                      _selectedDateRange = DateTimeRange(
                        start: _selectedDateRange.start.add(diff),
                        end: _selectedDateRange.end.add(diff),
                      );
                    }
                    _currentPage = 1;
                  });
                  _loadSchedule();
                },
                child: const SizedBox(
                  width: 48,
                  height: 52,
                  child: Center(
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 26,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: AppFonts.poppins(
          size: 13.5,
          color: const Color(0xFF111827),
          weight: FontWeight.w500,
        ),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search groomer, customer, phone, pet, ID...',
          hintStyle: AppFonts.poppins(
            size: 13,
            color: const Color(0xFF9CA3AF),
            weight: FontWeight.w400,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: Color(0xFF6B7280),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF6B7280),
                  ),
                  tooltip: 'Clear search',
                  onPressed: _clearSearch,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none,
          isDense: true,
        ),
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
      ),
    );
  }

  void _handleGroomerChipTap(String id) {
    setState(() {
      if (id == 'all') {
        _selectedGroomerFilterIds = {'all'};
      } else {
        // If multi-select is already active with multiple groomers, toggle this groomer
        if (_selectedGroomerFilterIds.length > 1 && !_selectedGroomerFilterIds.contains('all')) {
          if (_selectedGroomerFilterIds.contains(id)) {
            _selectedGroomerFilterIds.remove(id);
            if (_selectedGroomerFilterIds.isEmpty) {
              _selectedGroomerFilterIds = {'all'};
            }
          } else {
            _selectedGroomerFilterIds.add(id);
          }
        } else {
          // Single select switches to this groomer (preserves 100% existing test & user behavior)
          _selectedGroomerFilterIds = {id};
        }
      }
      _currentPage = 1;
    });
    _loadSchedule(showLoading: _allBookings.isEmpty);
  }

  void _handleGroomerChipLongPress(String id) {
    if (id == 'all') return;
    setState(() {
      _selectedGroomerFilterIds.remove('all');
      if (_selectedGroomerFilterIds.contains(id)) {
        _selectedGroomerFilterIds.remove(id);
        if (_selectedGroomerFilterIds.isEmpty) {
          _selectedGroomerFilterIds = {'all'};
        }
      } else {
        _selectedGroomerFilterIds.add(id);
      }
      _currentPage = 1;
    });
    _loadSchedule();
  }

  Widget _buildGroomerFilterSection() {
    final isFiltered = _isGroomerFiltered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Filter by Groomer',
                style: AppFonts.parkinsans(
                  size: 14.5,
                  weight: FontWeight.w600,
                  color: const Color(0xFF111827),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isFiltered) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  if (_isGroomerFiltered) {
                    setState(() {
                      _selectedGroomerFilterIds = {'all'};
                      _currentPage = 1;
                    });
                    _loadSchedule();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.close_rounded, size: 12, color: Color(0xFF111827)),
                      const SizedBox(width: 4),
                      Text(
                        'Show All',
                        style: AppFonts.poppins(
                          size: 11,
                          weight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),

        // Horizontal filter chips
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // "All Groomers" chip
              _buildFilterChip(
                id: 'all',
                label: 'All Groomers',
                count: _allGroomersTotalCount,
                isSelected: _selectedGroomerFilterIds.contains('all') || _selectedGroomerFilterIds.isEmpty,
              ),
              const SizedBox(width: 8),

              // Dynamic salon groomers chips (login groomer sorted first with '(You)')
              ..._sortedSalonGroomers.map((g) {
                final isSelected = _selectedGroomerFilterIds.contains(g.id.toString());
                final count = _countForGroomer(g);
                final cur = ServicesLocator.groomerHomeRepository.getCurrentGroomer();
                final isMe = cur != null && (g.id == cur.id || g.groomerCode.toLowerCase() == cur.groomerCode.toLowerCase());
                final rawName = g.firstName.isNotEmpty ? g.firstName : g.name;
                final displayName = isMe ? '$rawName (You)' : rawName;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildFilterChip(
                    id: g.id.toString(),
                    label: displayName,
                    count: count,
                    isSelected: isSelected,
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String id,
    required String label,
    required int count,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => _handleGroomerChipTap(id),
      onLongPress: () => _handleGroomerChipLongPress(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFE5E7EB),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppFonts.poppins(
                size: 12.5,
                weight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFFF4F6F8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: AppFonts.poppins(
                  size: 11,
                  weight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorRetryState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: Color(0xFFDC2626),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Unable to Load Salon Appointments',
            textAlign: TextAlign.center,
            style: AppFonts.poppins(
              size: 15,
              weight: FontWeight.w600,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? 'Please check your connection and try again.',
            textAlign: TextAlign.center,
            style: AppFonts.poppins(
              size: 12.5,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              'Retry',
              style: AppFonts.poppins(size: 13, weight: FontWeight.w600, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111827),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: _loadData,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String formattedDate) {
    final filteredGroomer = _currentFilteredGroomer;
    final isGroomerFilter = filteredGroomer != null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy_outlined,
              size: 40,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isGroomerFilter
                ? 'No appointments found for ${filteredGroomer.name}'
                : 'No salon appointments found',
            textAlign: TextAlign.center,
            style: AppFonts.poppins(
              size: 15,
              weight: FontWeight.w600,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isGroomerFilter
                ? 'There are no bookings assigned to ${filteredGroomer.name} on $formattedDate.'
                : 'No groomers have appointments scheduled on $formattedDate.',
            textAlign: TextAlign.center,
            style: AppFonts.poppins(
              size: 12.5,
              color: const Color(0xFF6B7280),
            ),
          ),
          if (isGroomerFilter) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.people_outline, size: 16),
              label: Text(
                'View All Groomers',
                style: AppFonts.poppins(
                  size: 13,
                  weight: FontWeight.w600,
                  color: const Color(0xFF111827),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF111827),
                side: const BorderSide(color: Color(0xFF111827)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () {
                setState(() {
                  _selectedGroomerFilterIds = {'all'};
                  _currentPage = 1;
                });
                _loadSchedule();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 38,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No matching appointments',
            textAlign: TextAlign.center,
            style: AppFonts.poppins(
              size: 15,
              weight: FontWeight.w600,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No appointments match "$_searchQuery". Try searching with a different groomer, customer, mobile number, pet, or booking ID.',
            textAlign: TextAlign.center,
            style: AppFonts.poppins(
              size: 12.5,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.close_rounded, size: 16),
                label: Text(
                  'Clear Search',
                  style: AppFonts.poppins(size: 13, weight: FontWeight.w600, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                ),
                onPressed: _clearSearch,
              ),
              if (_hasNextPage)
                OutlinedButton.icon(
                  icon: _isLoadingMore
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF111827)),
                        )
                      : const Icon(Icons.arrow_downward_rounded, size: 16),
                  label: Text(
                    _isLoadingMore ? 'Searching...' : 'Search Next Page (Page ${_currentPage + 1})',
                    style: AppFonts.poppins(
                      size: 13,
                      weight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF111827),
                    side: const BorderSide(color: Color(0xFF111827)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  ),
                  onPressed: _isLoadingMore ? null : () => _loadSchedule(isLoadMore: true),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(GroomerBooking booking) {
    Color borderColor;
    Color badgeBgColor;
    Color badgeTextColor;
    String badgeText;

    final statusLower = booking.status.toLowerCase();

    switch (statusLower) {
      case 'in_progress':
      case 'in-progress':
        borderColor = const Color(0xFF2563EB);
        badgeBgColor = const Color(0xFFDBEAFE);
        badgeTextColor = const Color(0xFF1D4ED8);
        badgeText = 'In Progress';
        break;
      case 'checked_in':
        borderColor = const Color(0xFF10B981);
        badgeBgColor = const Color(0xFFDCFCE7);
        badgeTextColor = const Color(0xFF15803D);
        badgeText = 'Checked In';
        break;
      case 'bath_completed':
        borderColor = const Color(0xFF0284C7);
        badgeBgColor = const Color(0xFFE0F2FE);
        badgeTextColor = const Color(0xFF0369A1);
        badgeText = 'Bath Completed';
        break;
      case 'grooming_completed':
        borderColor = const Color(0xFF7C3AED);
        badgeBgColor = const Color(0xFFEDE9FE);
        badgeTextColor = const Color(0xFF6D28D9);
        badgeText = 'Grooming Completed';
        break;
      case 'ready_for_checkout':
        borderColor = const Color(0xFF111827);
        badgeBgColor = const Color(0xFFF3F4F6);
        badgeTextColor = const Color(0xFF111827);
        badgeText = 'Ready for Checkout';
        break;
      case 'confirmed':
        borderColor = const Color(0xFF10B981);
        badgeBgColor = const Color(0xFFDCFCE7);
        badgeTextColor = const Color(0xFF166534);
        badgeText = 'Confirmed';
        break;
      case 'pending':
        if (booking.isExpiredPending) {
          borderColor = const Color(0xFFF87171);
          badgeBgColor = const Color(0xFFFEE2E2);
          badgeTextColor = const Color(0xFFDC2626);
          badgeText = 'Expired';
        } else {
          borderColor = const Color(0xFFF59E0B);
          badgeBgColor = const Color(0xFFFEF3C7);
          badgeTextColor = const Color(0xFFD97706);
          badgeText = 'Pending';
        }
        break;
      case 'cancellation_requested':
        borderColor = const Color(0xFF8B5CF6);
        badgeBgColor = const Color(0xFFEDE9FE);
        badgeTextColor = const Color(0xFF6D28D9);
        badgeText = 'Cancellation Requested';
        break;
      case 'completed':
      case 'past':
        borderColor = const Color(0xFFE5E7EB);
        badgeBgColor = const Color(0xFFF3F4F6);
        badgeTextColor = const Color(0xFF374151);
        badgeText = 'Completed';
        break;
      case 'rejected':
      case 'cancelled':
      default:
        borderColor = const Color(0xFFF87171);
        badgeBgColor = const Color(0xFFFEE2E2);
        badgeTextColor = const Color(0xFFDC2626);
        badgeText = statusLower == 'cancelled' ? 'Cancelled' : 'Rejected';
        break;
    }

    final isPending = statusLower == 'pending';
    final isConfirmed = statusLower == 'confirmed';
    final isInProgress = statusLower == 'in_progress' ||
        statusLower == 'in-progress' ||
        statusLower == 'bath_completed' ||
        statusLower == 'grooming_in_progress' ||
        statusLower == 'grooming_completed' ||
        statusLower == 'in_service';
    final isCheckedInStatus = statusLower == 'checked_in';
    final isReadyForCheckout = statusLower == 'ready_for_checkout' || booking.isReadyForCheckout;
    final isProcessing = _processingBookingIds.contains(booking.bookingId);
    final canManage = _isOwnBooking(booking);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pet Thumbnail Image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: _buildPetImage(booking.profilePicture, booking.petName),
                ),
              ),
              const SizedBox(width: 12),

              // Details Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Pet Name + Booking ID + Status Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  booking.petName,
                                  style: AppFonts.poppins(
                                    size: 15.5,
                                    weight: FontWeight.w700,
                                    color: const Color(0xFF111827),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (booking.bookingId > 0) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '#${booking.bookingId}',
                                  style: AppFonts.poppins(
                                    size: 11.5,
                                    weight: FontWeight.w600,
                                    color: const Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: badgeBgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isInProgress) ...[
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1D4ED8),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                badgeText,
                                style: AppFonts.poppins(
                                  size: 11,
                                  weight: FontWeight.w600,
                                  color: badgeTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 3),

                    // Customer Name & Mobile
                    Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF6B7280)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            booking.customerMobile.isNotEmpty
                                ? '${booking.customerName.isNotEmpty ? booking.customerName : 'Customer'} • ${booking.customerMobile}'
                                : (booking.customerName.isNotEmpty ? booking.customerName : 'Customer'),
                            style: AppFonts.poppins(
                              size: 12,
                              weight: FontWeight.w500,
                              color: const Color(0xFF4B5563),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 3),

                    // Time Range
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF6B7280)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            booking.formattedTimeRange,
                            style: AppFonts.poppins(
                              size: 12,
                              weight: FontWeight.w400,
                              color: const Color(0xFF4B5563),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 3),

                    // Service Description
                    Row(
                      children: [
                        const Icon(Icons.content_cut_rounded, size: 13, color: Color(0xFF111827)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            booking.fullServiceDescription.isNotEmpty
                                ? booking.fullServiceDescription
                                : 'Grooming',
                            style: AppFonts.poppins(
                              size: 12.5,
                              weight: FontWeight.w500,
                              color: const Color(0xFF1F2937),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Date badge when in date-range mode
          if (_isDateRangeMode && booking.bookingDate.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.event_note_outlined, size: 13, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                Text(
                  booking.bookingDate,
                  style: AppFonts.poppins(
                    size: 11.5,
                    weight: FontWeight.w500,
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ],

          // Customer Service Request Notes (Step 2 & Step 5)
          if (booking.specialInstructions != null &&
              booking.specialInstructions!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.speaker_notes_outlined, size: 14, color: Color(0xFF4B5563)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Customer Instructions: "${booking.specialInstructions!.trim()}"',
                      style: AppFonts.poppins(
                        size: 11.5,
                        color: const Color(0xFF374151),
                      ).copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Permanent Pet Medical & Allergy Notes (Strictly distinct from booking instructions)
          if (booking.hasPetMedicalNotes) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.medical_services_outlined, size: 14, color: Color(0xFFB45309)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Medical / Allergy Alert: "${booking.petMedicalNotes}"',
                      style: AppFonts.poppins(
                        size: 11.5,
                        color: const Color(0xFF78350F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Step 6 Check-in Record & Server Timestamp Badge
          if (booking.isCheckedIn || booking.hasCheckInRecord) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  Text(
                    booking.checkInTimestamp != null && booking.checkInTimestamp!.isNotEmpty
                        ? 'Checked In • ${_formatCheckInTimestamp(booking.checkInTimestamp!)}'
                        : 'Checked In',
                    style: AppFonts.poppins(
                      size: 11.5,
                      weight: FontWeight.w600,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                  if (booking.groomerCheckInNotes != null &&
                      booking.groomerCheckInNotes!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '• Notes: "${booking.groomerCheckInNotes}"',
                        style: AppFonts.poppins(
                          size: 11,
                          color: const Color(0xFF166534),
                        ).copyWith(fontStyle: FontStyle.italic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Step 7 Milestone Badges & Optional Notes
          if (booking.isBathCompleted || booking.isGroomingCompleted) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF16A34A)),
                      const SizedBox(width: 6),
                      Text(
                        booking.requiresBath && booking.requiresGrooming
                            ? (booking.isGroomingCompleted
                                ? 'Milestones: Bath & Grooming Completed'
                                : 'Milestone: Bath Completed')
                            : (booking.requiresBath
                                ? 'Milestone: Bath Completed'
                                : 'Milestone: Grooming Completed'),
                        style: AppFonts.poppins(
                          size: 11.5,
                          weight: FontWeight.w600,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                      if (booking.bathCompletedAt != null && booking.bathCompletedAt!.isNotEmpty && !booking.isGroomingCompleted) ...[
                        const SizedBox(width: 4),
                        Text(
                          '• ${_formatMilestoneTimestamp(booking.bathCompletedAt!)}',
                          style: AppFonts.poppins(
                            size: 11,
                            color: const Color(0xFF166534),
                          ),
                        ),
                      ],
                      if (booking.groomingCompletedAt != null && booking.groomingCompletedAt!.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          '• ${_formatMilestoneTimestamp(booking.groomingCompletedAt!)}',
                          style: AppFonts.poppins(
                            size: 11,
                            color: const Color(0xFF166534),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (booking.bathNotes != null && booking.bathNotes!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '• Bath Notes: "${booking.bathNotes}"',
                      style: AppFonts.poppins(
                        size: 11,
                        color: const Color(0xFF166534),
                      ).copyWith(fontStyle: FontStyle.italic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (booking.groomingNotes != null && booking.groomingNotes!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '• Grooming Notes: "${booking.groomingNotes}"',
                      style: AppFonts.poppins(
                        size: 11,
                        color: const Color(0xFF166534),
                      ).copyWith(fontStyle: FontStyle.italic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 8),

          // Bottom Bar: Groomer Badge + Actions
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              spacing: 8,
              children: [
                // Left Side: Dedicated Groomer Badge + Optional Skip Button (after check-in)
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Container(
                      constraints: const BoxConstraints(maxWidth: 190),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.badge_outlined, size: 13, color: Color(0xFF111827)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Groomer: ${booking.effectiveGroomerName}',
                              style: AppFonts.poppins(
                                size: 11.5,
                                weight: FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canManage && booking.canShowSkipOption)
                      _buildSkipButton(booking),
                  ],
                ),

                // Action Buttons (Only enabled for the logged-in groomer's own appointments)
                if (isProcessing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF111827)),
                  )
                else if (canManage && isPending && !booking.isExpiredPending && booking.bookingId > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _handleReject(booking),
                        child: Text(
                          'Reject',
                          style: AppFonts.poppins(
                            size: 12,
                            weight: FontWeight.w600,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _handleApprove(booking),
                        child: Text(
                          'Approve',
                          style: AppFonts.poppins(
                            size: 12,
                            weight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  )
                else if (canManage && isConfirmed && booking.bookingId > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!booking.isCheckedIn)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF111827), // Brand Deep Slate
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFE5E7EB),
                            disabledForegroundColor: const Color(0xFF9CA3AF),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            minimumSize: const Size(0, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: !booking.canCheckIn()
                              ? null
                              : () => _handleCheckIn(booking),
                          icon: const Icon(Icons.assignment_turned_in_outlined, size: 15),
                          label: Text(
                            'Check In',
                            style: AppFonts.poppins(
                              size: 12,
                              weight: FontWeight.w600,
                            ),
                          ),
                        )
                      else ...[
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF111827),
                            side: const BorderSide(color: Color(0xFF111827)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            minimumSize: const Size(0, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _handleCheckIn(booking),
                          icon: const Icon(Icons.checklist_rounded, size: 14, color: Color(0xFF111827)),
                          label: Text(
                            'Checklist',
                            style: AppFonts.poppins(
                              size: 11.5,
                              weight: FontWeight.w600,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF111827), // Brand Deep Slate
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            minimumSize: const Size(0, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _handleStart(booking),
                          icon: const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
                          label: Text(
                            'Start',
                            style: AppFonts.poppins(
                              size: 12,
                              weight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  )
                else if (canManage && (statusLower == 'completed' || booking.isCompleted) && booking.bookingId > 0)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      final receipt = BookingReceipt.fromGroomerBooking(booking);
                      BookingReceiptPageMobile.show(context, receipt: receipt);
                    },
                    icon: const Icon(Icons.receipt_long_rounded, size: 14, color: Colors.white),
                    label: Text(
                      'Receipt',
                      style: AppFonts.poppins(
                        size: 11.5,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  )
                else if (canManage && (isInProgress || isCheckedInStatus) && !booking.areRequiredMilestonesCompleted && booking.bookingId > 0) ...[
                  if (booking.nextPendingMilestone == 'bath_completed')
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7), // Blue for Bath
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _handleMilestone(booking, MilestoneType.bath),
                      icon: const Icon(Icons.bathtub_outlined, size: 15, color: Colors.white),
                      label: Text(
                        'Bath Done',
                        style: AppFonts.poppins(
                          size: 12,
                          weight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else if (booking.nextPendingMilestone == 'grooming_completed') ...[
                    if (booking.requiresBath && booking.isBathCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF0284C7)),
                            const SizedBox(width: 4),
                            Text(
                              'Bath Done',
                              style: AppFonts.poppins(
                                size: 11.5,
                                weight: FontWeight.w600,
                                color: const Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED), // Purple for Grooming
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _handleMilestone(booking, MilestoneType.grooming),
                      icon: const Icon(Icons.content_cut_rounded, size: 15, color: Colors.white),
                      label: Text(
                        'Grooming Done',
                        style: AppFonts.poppins(
                          size: 12,
                          weight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ]
                else if (canManage && booking.areRequiredMilestonesCompleted && !isReadyForCheckout && !booking.isCompleted && statusLower != 'completed' && booking.bookingId > 0)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF16A34A)),
                            const SizedBox(width: 4),
                            Text(
                              booking.requiresGrooming ? 'Grooming Done' : 'Bath Done',
                              style: AppFonts.poppins(
                                size: 11.5,
                                weight: FontWeight.w600,
                                color: const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF111827), // Brand Deep Slate
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: isProcessing ? null : () => _handleReadyForCheckout(booking),
                        icon: isProcessing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.point_of_sale_rounded, size: 15, color: Colors.white),
                        label: Text(
                          isProcessing ? 'Updating...' : 'Ready for Checkout',
                          style: AppFonts.poppins(
                            size: 11.5,
                            weight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  )
                else if (canManage && isReadyForCheckout && booking.bookingId > 0)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF111827)),
                            const SizedBox(width: 4),
                            Text(
                              'Ready for Checkout',
                              style: AppFonts.poppins(
                                size: 11.5,
                                weight: FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F2937),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => _handleComplete(booking),
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 15, color: Colors.white),
                        label: Text(
                          'Complete',
                          style: AppFonts.poppins(
                            size: 11.5,
                            weight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  )
                else if (!canManage)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 12, color: Color(0xFF6B7280)),
                        const SizedBox(width: 4),
                        Text(
                          'Read-only',
                          style: AppFonts.poppins(
                            size: 11,
                            weight: FontWeight.w500,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkipButton(GroomerBooking booking) {
    final isProcessing = _processingBookingIds.contains(booking.bookingId);
    return OutlinedButton.icon(
      key: Key('appointment_skip_button_${booking.bookingId}'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFD97706),
        backgroundColor: const Color(0xFFFFFBEB),
        side: const BorderSide(color: Color(0xFFFCD34D), width: 1.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: isProcessing ? null : () => _handleSkipMilestones(booking),
      icon: isProcessing
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: Color(0xFFD97706),
              ),
            )
          : const Icon(Icons.fast_forward_rounded, size: 14, color: Color(0xFFD97706)),
      label: Text(
        isProcessing ? 'Skipping...' : 'Skip',
        style: AppFonts.poppins(
          size: 11.5,
          weight: FontWeight.w600,
          color: const Color(0xFFD97706),
        ),
      ),
    );
  }

  Widget _buildPetImage(String? url, String petName) {
    return PetImageHelper.buildImage(
      photoUrl: url,
      petName: petName,
      fit: BoxFit.cover,
      loadingWidget: Container(
        color: const Color(0xFFF3F4F6),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF111827)),
          ),
        ),
      ),
      customFallback: Image.asset(
        PetImageHelper.getFallbackAsset(petName: petName),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(petName),
      ),
    );
  }

  Widget _buildAvatarFallback(String petName) {
    final initial = petName.isNotEmpty ? petName[0].toUpperCase() : 'P';
    return Container(
      color: const Color(0xFFE5E7EB),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppFonts.poppins(
          size: 24,
          weight: FontWeight.w700,
          color: const Color(0xFF4B5563),
        ),
      ),
    );
  }
}
