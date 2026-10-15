import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';

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
  String _selectedGroomerFilterId = 'all';
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
      _selectedGroomerFilterId = widget.initialGroomerFilterId!;
    } else if (currentGroomer != null && currentGroomer.id > 0) {
      _selectedGroomerFilterId = currentGroomer.id.toString();
    } else {
      _selectedGroomerFilterId = 'all';
    }

    if (widget.initialBookings != null) {
      _allBookings = List.from(widget.initialBookings!);
      _salonGroomers = List.from(widget.initialSalonGroomers ?? []);
      _isLoading = false;
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
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    try {
      List<GroomerBooking> appointments;
      if (_selectedGroomerFilterId == 'all') {
        final groomerIds = _salonGroomers.map((g) => g.id).where((id) => id > 0).toSet().toList();
        appointments = await ServicesLocator.groomerHomeRepository.getAllGroomersAvailabilityAppointments(
          groomerIds: groomerIds,
          date: dateStr,
          page: targetPage,
          limit: _pageSize,
        );
      } else {
        final targetGroomerId = int.tryParse(_selectedGroomerFilterId);
        if (targetGroomerId != null && targetGroomerId > 0) {
          appointments = await ServicesLocator.groomerHomeRepository.getGroomerAvailabilityAppointments(
            groomerId: targetGroomerId,
            date: dateStr,
            page: targetPage,
            limit: _pageSize,
          );
        } else {
          appointments = [];
        }
      }

      if (!mounted) return;
      setState(() {
        if (isLoadMore) {
          _currentPage = targetPage;
          _isLoadingMore = false;
          _hasNextPage = appointments.length >= _pageSize;

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
          _hasNextPage = appointments.length >= _pageSize;
        }

        for (final g in _salonGroomers) {
          _cachedGroomerCounts[g.id] = _allBookings.where((b) => b.groomerId == g.id).length;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        if (!isLoadMore) {
          _errorMessage = 'Unable to load salon appointments for $dateStr. Pull to refresh.';
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
          });
        }
      }

      // Default to logged-in groomer if not explicitly set
      if (widget.initialGroomerFilterId == null && _selectedGroomerFilterId == 'all') {
        final cur = ServicesLocator.groomerHomeRepository.getCurrentGroomer();
        if (cur != null && cur.id > 0) {
          _selectedGroomerFilterId = cur.id.toString();
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
    return _allBookings
        .where((b) => BookingDateUtils.isSameCalendarDay(b.bookingDate, _selectedDate))
        .toList();
  }

  List<GroomerBooking> get _filteredBookings {
    final list = _bookingsForDate;
    List<GroomerBooking> results;

    if (_selectedGroomerFilterId == 'all') {
      results = list;
    } else {
      final targetId = int.tryParse(_selectedGroomerFilterId);
      final targetGroomer = _salonGroomers.where((g) => g.id.toString() == _selectedGroomerFilterId).firstOrNull;
      final targetCode = targetGroomer?.groomerCode.toLowerCase();
      final targetName = targetGroomer?.name.toLowerCase();

      results = list.where((b) {
        if (targetId != null && b.groomerId == targetId) return true;
        if (targetCode != null && targetCode.isNotEmpty && b.groomerCode?.toLowerCase() == targetCode) return true;
        if (targetName != null && targetName.isNotEmpty && b.groomerName?.toLowerCase() == targetName) return true;
        if (targetName != null && targetName.isNotEmpty && b.effectiveGroomerName.toLowerCase().contains(targetName)) return true;
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

  String _formatBookingDateDisplay(DateTime dt) {
    if (BookingDateUtils.isToday(dt)) {
      return 'Today, ${DateFormat('d MMM yyyy').format(dt)}';
    }
    return DateFormat('d MMM yyyy').format(dt);
  }

  Future<void> _pickDateFromCalendar() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = today.subtract(const Duration(days: 365));
    final lastDate = today.add(const Duration(days: 365));
    final initialDate = _selectedDate.isBefore(firstDate)
        ? firstDate
        : (_selectedDate.isAfter(lastDate) ? lastDate : _selectedDate);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
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
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = BookingDateUtils.normalize(picked);
        _currentPage = 1;
      });
      _loadSchedule();
    }
  }

  SalonGroomer? get _currentFilteredGroomer {
    if (_selectedGroomerFilterId == 'all') return null;
    return _salonGroomers
        .where((g) => g.id.toString() == _selectedGroomerFilterId)
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

  int get _allGroomersTotalCount {
    if (_cachedGroomerCounts.isNotEmpty) {
      return _cachedGroomerCounts.values.fold(0, (sum, count) => sum + count);
    }
    return _bookingsForDate.length;
  }

  int _countForGroomer(SalonGroomer groomer) {
    if (_cachedGroomerCounts.containsKey(groomer.id)) {
      return _cachedGroomerCounts[groomer.id]!;
    }
    return _bookingsForDate.where((b) {
      if (b.groomerId == groomer.id) return true;
      if (b.groomerCode != null && b.groomerCode!.toLowerCase() == groomer.groomerCode.toLowerCase()) return true;
      if (b.groomerName != null && b.groomerName!.toLowerCase() == groomer.name.toLowerCase()) return true;
      return false;
    }).length;
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
          await _loadSchedule();
        } else {
          ToastUtil.showErrorToast(context, res.message);
        }
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
    setState(() => _processingBookingIds.add(booking.bookingId));
    try {
      final res = await ServicesLocator.groomerHomeRepository.completeBookingDetails(
        booking.bookingId,
        booking: booking,
      );
      if (mounted) {
        if (res.success) {
          ToastUtil.showSuccessToast(context, 'Booking #${booking.bookingId} marked as completed');
          await _loadSchedule();
        } else {
          ToastUtil.showErrorToast(context, res.message);
        }
      }
    } finally {
      if (mounted) setState(() => _processingBookingIds.remove(booking.bookingId));
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
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F766E)),
                  )
                : const Icon(Icons.refresh_rounded, size: 22, color: Color(0xFF0F766E)),
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
        color: const Color(0xFF0F766E),
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
                    accentColor: const Color(0xFF0F766E),
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
                if (_selectedGroomerFilterId != 'all') ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        _currentFilteredGroomer?.name ?? 'Filtered',
                        style: AppFonts.poppins(
                          size: 11.5,
                          weight: FontWeight.w600,
                          color: const Color(0xFF0F766E),
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
                  child: CircularProgressIndicator(color: Color(0xFF0F766E)),
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
                          child: CircularProgressIndicator(color: Color(0xFF0F766E)),
                        )
                      : OutlinedButton.icon(
                          icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                          label: Text(
                            'Load More Appointments (Page ${_currentPage + 1})',
                            style: AppFonts.poppins(
                              size: 13,
                              weight: FontWeight.w600,
                              color: const Color(0xFF0F766E),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F766E),
                            side: const BorderSide(color: Color(0xFF0F766E)),
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
            // Previous Day Button
            Tooltip(
              message: 'Previous Day',
              child: InkWell(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                onTap: () {
                  setState(() {
                    _selectedDate = _selectedDate.subtract(const Duration(days: 1));
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

            // Date Text & Calendar Picker
            Expanded(
              child: Tooltip(
                message: 'Select Date from Calendar',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _pickDateFromCalendar,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: Color(0xFF111827),
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Next Day Button
            Tooltip(
              message: 'Next Day',
              child: InkWell(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                onTap: () {
                  setState(() {
                    _selectedDate = _selectedDate.add(const Duration(days: 1));
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

  Widget _buildGroomerFilterSection() {
    final isFiltered = _selectedGroomerFilterId != 'all';

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
                  if (_selectedGroomerFilterId != 'all') {
                    setState(() {
                      _selectedGroomerFilterId = 'all';
                      _currentPage = 1;
                    });
                    _loadSchedule();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.close_rounded, size: 12, color: Color(0xFF0F766E)),
                      const SizedBox(width: 4),
                      Text(
                        'Show All',
                        style: AppFonts.poppins(
                          size: 11,
                          weight: FontWeight.w600,
                          color: const Color(0xFF0F766E),
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
                isSelected: _selectedGroomerFilterId == 'all',
              ),
              const SizedBox(width: 8),

              // Dynamic salon groomers chips (login groomer sorted first with '(You)')
              ..._sortedSalonGroomers.map((g) {
                final isSelected = _selectedGroomerFilterId == g.id.toString();
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
      onTap: () {
        if (_selectedGroomerFilterId != id) {
          setState(() {
            _selectedGroomerFilterId = id;
            _currentPage = 1;
          });
          _loadSchedule();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F766E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.2),
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
              backgroundColor: const Color(0xFF0F766E),
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
                  color: const Color(0xFF0F766E),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F766E),
                side: const BorderSide(color: Color(0xFF0F766E)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () {
                setState(() {
                  _selectedGroomerFilterId = 'all';
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
                  backgroundColor: const Color(0xFF0F766E),
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F766E)),
                        )
                      : const Icon(Icons.arrow_downward_rounded, size: 16),
                  label: Text(
                    _isLoadingMore ? 'Searching...' : 'Search Next Page (Page ${_currentPage + 1})',
                    style: AppFonts.poppins(
                      size: 13,
                      weight: FontWeight.w600,
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                    side: const BorderSide(color: Color(0xFF0F766E)),
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
      case 'confirmed':
        borderColor = const Color(0xFF10B981);
        badgeBgColor = const Color(0xFFDCFCE7);
        badgeTextColor = const Color(0xFF166534);
        badgeText = 'Confirmed';
        break;
      case 'pending':
        borderColor = const Color(0xFFF59E0B);
        badgeBgColor = const Color(0xFFFEF3C7);
        badgeTextColor = const Color(0xFFD97706);
        badgeText = 'Pending';
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
    final isInProgress = statusLower == 'in_progress' || statusLower == 'in-progress';
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
                        const Icon(Icons.content_cut_rounded, size: 13, color: Color(0xFF0F766E)),
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
                // Dedicated Groomer Badge
                Container(
                  constraints: const BoxConstraints(maxWidth: 190),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.badge_outlined, size: 13, color: Color(0xFF0F766E)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Groomer: ${booking.effectiveGroomerName}',
                          style: AppFonts.poppins(
                            size: 11.5,
                            weight: FontWeight.w600,
                            color: const Color(0xFF0F766E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Buttons (Only enabled for the logged-in groomer's own appointments)
                if (isProcessing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F766E)),
                  )
                else if (canManage && isPending && booking.bookingId > 0)
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
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E), // Brand Teal
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
                  )
                else if (canManage && isInProgress && booking.bookingId > 0)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E), // Brand Teal
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
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.white),
                    label: Text(
                      'Complete',
                      style: AppFonts.poppins(
                        size: 12,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
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

  Widget _buildPetImage(String? url, String petName) {
    final fallbackAsset = petName.toLowerCase().contains('teddy')
        ? 'assets/images/common/pet_2.png'
        : (petName.toLowerCase().contains('doodles')
            ? 'assets/images/chat/pet_teddy.png'
            : 'assets/images/common/pet_1.png');

    if (url != null && url.isNotEmpty) {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: const Color(0xFFF3F4F6),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F766E)),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              fallbackAsset,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(petName),
            );
          },
        );
      } else {
        return Image.asset(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              fallbackAsset,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(petName),
            );
          },
        );
      }
    }

    return Image.asset(
      fallbackAsset,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(petName),
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
