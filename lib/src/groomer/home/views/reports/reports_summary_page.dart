import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_report_summary.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';

/// Reports Summary Screen for the Groomer Portal (Step 12).
///
/// Features:
/// - Authoritative appointment volume and status breakdown (Total, Completed, Confirmed, In Progress, Ready for Checkout, Pending, Cancelled).
/// - Clear distinction between Forecast Revenue (unpaid prospective) and Actual Collected Revenue (verified paid checkouts).
/// - Unpaid appointments are strictly excluded from actual revenue (status completed alone never marks revenue as paid).
/// - Missing financial data (tax, tips, payment confirmation) is clearly disclosed without fabricating $0.00 figures.
/// - Date presets: Today, This Week, This Month, and Custom Date Range.
/// - Groomer filtering: All Groomers or Selected Groomer with strict isolation.
/// - Itemized appointment listing with multi-field search and secondary status filter.
class ReportsSummaryPage extends StatefulWidget {
  final List<GroomerBooking>? initialBookings;
  final List<SalonGroomer>? initialSalonGroomers;
  final ReportDatePreset? initialPreset;
  final String? initialGroomerFilterId;
  final DateTimeRange? initialCustomRange;
  final bool isEmbedded;

  const ReportsSummaryPage({
    super.key,
    this.initialBookings,
    this.initialSalonGroomers,
    this.initialPreset,
    this.initialGroomerFilterId,
    this.initialCustomRange,
    this.isEmbedded = false,
  });

  @override
  State<ReportsSummaryPage> createState() => _ReportsSummaryPageState();
}

class _ReportsSummaryPageState extends State<ReportsSummaryPage> {
  late ReportDatePreset _selectedPreset;
  late DateTimeRange _dateRange;

  // Groomer Filter: 'all' or specific groomer ID
  Set<String> _selectedGroomerFilterIds = {'all'};

  // Secondary Status Filter for itemized list
  String _selectedStatusFilter = 'all';

  bool _isLoading = false;
  String? _errorMessage;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _visibleDisplayLimit = 25;

  List<SalonGroomer> _salonGroomers = [];
  List<GroomerBooking> _allBookings = [];
  GroomerReportSummary? _serverReportSummary;

  @override
  void initState() {
    super.initState();
    _selectedPreset = widget.initialPreset ?? ReportDatePreset.today;
    _dateRange = widget.initialCustomRange ?? _selectedPreset.resolveRange();

    if (widget.initialGroomerFilterId != null &&
        widget.initialGroomerFilterId!.isNotEmpty) {
      _selectedGroomerFilterIds = {widget.initialGroomerFilterId!};
    } else {
      _selectedGroomerFilterIds = {'all'};
    }

    if (widget.initialBookings != null) {
      _allBookings = List.from(widget.initialBookings!);
      _salonGroomers = List.from(widget.initialSalonGroomers ?? []);
      _isLoading = false;
    } else {
      _loadData();
    }
  }

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
      _visibleDisplayLimit = 25;
    });
  }

  // ── Data Loading & API Integration ────────────────────────────────────────

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
        final groomers =
            await ServicesLocator.groomerHomeRepository.getSalonGroomers();
        if (mounted) {
          setState(() {
            _salonGroomers = groomers;
          });
        }
      }

      final startStr = DateFormat('yyyy-MM-dd').format(_dateRange.start);
      final endStr = DateFormat('yyyy-MM-dd').format(_dateRange.end);
      try {
        final serverReport = await ServicesLocator.groomerHomeRepository.getReportsSummary(
          startDate: startStr,
          endDate: endStr,
        );
        if (mounted && serverReport != null) {
          _serverReportSummary = serverReport;
        }
      } catch (_) {}

      await _loadSchedule();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to load appointments for report. Pull to refresh.';
      });
    }
  }

  Future<void> _loadSchedule() async {
    if (widget.initialBookings != null && widget.initialBookings!.isNotEmpty) {
      return;
    }
    if (!mounted) return;

    final start = BookingDateUtils.normalize(_dateRange.start);
    final end = BookingDateUtils.normalize(_dateRange.end);
    final days = end.difference(start).inDays.clamp(0, 92);

    final List<String> datesToFetch = [];
    for (int i = 0; i <= days; i++) {
      datesToFetch.add(DateFormat('yyyy-MM-dd').format(start.add(Duration(days: i))));
    }

    try {
      final isAllSelected = _selectedGroomerFilterIds.contains('all') ||
          _selectedGroomerFilterIds.isEmpty;
      final selectedIds = _selectedGroomerFilterIds
          .map((s) => int.tryParse(s))
          .whereType<int>()
          .where((id) => id > 0)
          .toList();

      Future<List<GroomerBooking>> fetchForDate(String dateStr) async {
        final List<int> groomersToFetch = isAllSelected
            ? _salonGroomers.map((g) => g.id).where((id) => id > 0).toSet().toList()
            : selectedIds;

        if (groomersToFetch.isEmpty) return [];

        final results = await Future.wait(
          groomersToFetch.map((gid) async {
            final List<GroomerBooking> groomerList = [];
            int page = 1;
            bool hasMore = true;
            const int maxPagesSafetyThreshold = 30; // Up to 3,000 records
            while (hasMore) {
              final result = await ServicesLocator.groomerHomeRepository
                  .getGroomerAvailabilityAppointmentsWithPagination(
                groomerId: gid,
                date: dateStr,
                page: page,
                limit: 100,
              );
              final pageAppointments = result.appointments;
              if (pageAppointments.isEmpty) {
                hasMore = false;
                break;
              }
              groomerList.addAll(pageAppointments);
              if (!result.hasNextPage) {
                hasMore = false;
              } else {
                page++;
                if (page > maxPagesSafetyThreshold) {
                  hasMore = false;
                }
              }
            }
            return groomerList;
          }),
        );

        final Map<String, GroomerBooking> dateMap = {};
        for (final list in results) {
          for (final b in list) {
            final key = b.bookingId > 0
                ? 'id_${b.bookingId}'
                : 'slot_${b.groomerId}_${b.bookingDate}_${b.startTime}_${b.endTime}';
            dateMap[key] = b;
          }
        }
        return dateMap.values.toList();
      }

      final results = await Future.wait(datesToFetch.map((d) => fetchForDate(d)));
      final List<GroomerBooking> appointments = [];
      for (final list in results) {
        appointments.addAll(list);
      }

      if (!mounted) return;
      setState(() {
        _visibleDisplayLimit = 25;
        final Map<String, GroomerBooking> unique = {};
        for (final b in appointments) {
          final key = b.bookingId > 0
              ? 'id_${b.bookingId}'
              : 'slot_${b.groomerId}_${b.bookingDate}_${b.startTime}_${b.endTime}';
          unique[key] = b;
        }
        _allBookings = unique.values.toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to refresh report data. Please try again.';
      });
    }
  }

  // ── Filtered Datasets & Metrics ───────────────────────────────────────────

  /// Bookings matching the selected date range.
  List<GroomerBooking> get _bookingsForDateRange {
    final start = BookingDateUtils.normalize(_dateRange.start);
    final end = BookingDateUtils.normalize(_dateRange.end);

    return _allBookings.where((b) {
      final dt = BookingDateUtils.parseCalendarDate(b.bookingDate);
      if (dt == null) return false;
      final norm = BookingDateUtils.normalize(dt);
      return (norm.isAfter(start) || norm.isAtSameMomentAs(start)) &&
          (norm.isBefore(end) || norm.isAtSameMomentAs(end));
    }).toList();
  }

  /// Bookings matching both the date range and the selected groomer(s).
  List<GroomerBooking> get _filteredBookings {
    final list = _bookingsForDateRange;
    if (_selectedGroomerFilterIds.contains('all') ||
        _selectedGroomerFilterIds.isEmpty) {
      return list;
    }

    return list.where((b) {
      for (final selectedId in _selectedGroomerFilterIds) {
        final targetId = int.tryParse(selectedId);
        final targetGroomer = _salonGroomers
            .where((g) => g.id.toString() == selectedId)
            .firstOrNull;
        final targetCode = targetGroomer?.groomerCode.toLowerCase();
        final targetName = targetGroomer?.name.toLowerCase();

        if (targetId != null && b.groomerId == targetId) return true;
        if (targetCode != null &&
            targetCode.isNotEmpty &&
            b.groomerCode?.toLowerCase() == targetCode) {
          return true;
        }
        if (targetName != null &&
            targetName.isNotEmpty &&
            b.groomerName?.toLowerCase() == targetName) {
          return true;
        }
        if (targetName != null &&
            targetName.isNotEmpty &&
            b.effectiveGroomerName.toLowerCase().contains(targetName)) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  /// Authoritative report summary derived from server summary when available, or filtered appointments.
  GroomerReportSummary get _reportSummary {
    if (_serverReportSummary != null &&
        (_selectedGroomerFilterIds.contains('all') || _selectedGroomerFilterIds.isEmpty) &&
        _selectedStatusFilter == 'all' &&
        _searchQuery.isEmpty) {
      return _serverReportSummary!;
    }
    return GroomerReportSummary.fromBookings(_filteredBookings);
  }

  /// Per-groomer summary calculation for staff breakdown.
  GroomerReportSummary _summaryForGroomer(SalonGroomer groomer) {
    final groomerBookings = _bookingsForDateRange.where((b) {
      if (b.groomerId != null && b.groomerId == groomer.id) return true;
      if (b.groomerCode != null &&
          b.groomerCode!.toLowerCase() == groomer.groomerCode.toLowerCase()) {
        return true;
      }
      if (b.groomerName != null &&
          b.groomerName!.toLowerCase() == groomer.name.toLowerCase()) {
        return true;
      }
      return false;
    });

    return GroomerReportSummary.fromBookings(groomerBookings);
  }

  /// Appointments displayed in the itemized list after search and status filter.
  List<GroomerBooking> get _displayedAppointments {
    List<GroomerBooking> list = _filteredBookings;

    // Secondary Status Filter
    if (_selectedStatusFilter != 'all') {
      final f = _selectedStatusFilter.toLowerCase();
      list = list.where((b) {
        final s = b.status.toLowerCase();
        if (f == 'completed') return s == 'completed' || b.isCompleted;
        if (f == 'confirmed') return s == 'confirmed';
        if (f == 'in_progress') {
          return s == 'in_progress' ||
              s == 'in-progress' ||
              s == 'checked_in' ||
              s == 'bath_completed' ||
              s == 'grooming_completed';
        }
        if (f == 'ready_for_checkout') return s == 'ready_for_checkout';
        if (f == 'pending') return s == 'pending';
        if (f == 'cancelled') return s == 'cancelled' || s == 'canceled' || s == 'rejected';
        return true;
      }).toList();
    }

    // Search Query
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return list;

    final normalizedPhone = _normalizePhone(query);
    final cleanId = query.replaceAll('#', '').trim();

    return list.where((b) {
      if (b.customerName.toLowerCase().contains(query)) return true;
      if (b.petName.toLowerCase().contains(query)) return true;
      if (b.breed.toLowerCase().contains(query)) return true;
      if (b.serviceName.toLowerCase().contains(query)) return true;
      if (b.effectiveGroomerName.toLowerCase().contains(query)) return true;
      if (b.bookingId > 0) {
        final idStr = b.bookingId.toString();
        if (idStr.contains(query) || (cleanId.isNotEmpty && idStr.contains(cleanId))) {
          return true;
        }
      }
      if (b.customerMobile.isNotEmpty) {
        if (b.customerMobile.toLowerCase().contains(query)) return true;
        if (normalizedPhone.isNotEmpty &&
            _normalizePhone(b.customerMobile).contains(normalizedPhone)) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  String _formatDateRangeDisplay() {
    final s = DateFormat('d MMM yyyy').format(_dateRange.start);
    final e = DateFormat('d MMM yyyy').format(_dateRange.end);

    if (_dateRange.start.year == _dateRange.end.year &&
        _dateRange.start.month == _dateRange.end.month &&
        _dateRange.start.day == _dateRange.end.day) {
      if (BookingDateUtils.isToday(_dateRange.start)) {
        return 'Today, $s';
      }
      return s;
    }
    final days = _dateRange.duration.inDays + 1;
    return '$s – $e ($days days)';
  }

  // ── Filter Interaction Handlers ───────────────────────────────────────────

  void _onPresetSelected(ReportDatePreset preset) async {
    if (preset == ReportDatePreset.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020, 1, 1),
        lastDate: DateTime(2035, 12, 31),
        initialDateRange: _dateRange,
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF111827),
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Color(0xFF111827),
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        setState(() {
          _selectedPreset = ReportDatePreset.custom;
          _dateRange = picked;
          _visibleDisplayLimit = 25;
        });
        _loadSchedule();
      }
    } else {
      setState(() {
        _selectedPreset = preset;
        _dateRange = preset.resolveRange();
        _visibleDisplayLimit = 25;
      });
      _loadSchedule();
    }
  }

  void _onGroomerToggled(String id) {
    setState(() {
      if (id == 'all') {
        _selectedGroomerFilterIds = {'all'};
      } else {
        _selectedGroomerFilterIds.remove('all');
        if (_selectedGroomerFilterIds.contains(id)) {
          _selectedGroomerFilterIds.remove(id);
          if (_selectedGroomerFilterIds.isEmpty) {
            _selectedGroomerFilterIds = {'all'};
          }
        } else {
          _selectedGroomerFilterIds.add(id);
        }
      }
      _visibleDisplayLimit = 25;
    });
    _loadSchedule();
  }

  // ── UI Builder ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final summary = _reportSummary;
    final matchingAppointments = _displayedAppointments;
    final visibleAppointments =
        matchingAppointments.take(_visibleDisplayLimit).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: !widget.isEmbedded,
        centerTitle: false,
        leading: widget.isEmbedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 20, color: Color(0xFF111827)),
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
              'Reports Summary',
              style: AppFonts.parkinsans(
                size: 18,
                weight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            Text(
              'Appointment analytics & verified revenue metrics',
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
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF111827)),
                  )
                : const Icon(Icons.refresh_rounded,
                    size: 22, color: Color(0xFF111827)),
            tooltip: 'Refresh report',
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
          padding: EdgeInsets.fromLTRB(16, 16, 16, widget.isEmbedded ? 120 : 40),
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
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppFonts.poppins(
                            size: 12, color: const Color(0xFFDC2626)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Section 1: Date Filter Presets Bar ──
            _buildDatePresetsBar(),

            const SizedBox(height: 14),

            // ── Section 2: Groomer Filter Bar ──
            _buildGroomerFilterBar(),

            const SizedBox(height: 18),

            // ── Section 3: Revenue Cards (Forecast vs Actual Collected) ──
            _buildRevenueSummarySection(summary),

            const SizedBox(height: 18),

            // ── Section 4: Appointment Status Breakdown Grid ──
            _buildStatusBreakdownSection(summary),

            const SizedBox(height: 18),

            // ── Section 5: Staff Performance Breakdown (When All Groomers) ──
            if (_selectedGroomerFilterIds.contains('all') &&
                _salonGroomers.isNotEmpty) ...[
              _buildStaffBreakdownSection(),
              const SizedBox(height: 18),
            ],

            // ── Section 6: Search & Filtered Appointment List ──
            _buildSearchAndListHeader(matchingAppointments.length),
            const SizedBox(height: 12),

            if (_isLoading && matchingAppointments.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40.0),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF111827)),
                ),
              )
            else if (matchingAppointments.isEmpty)
              _buildEmptyAppointmentsView()
            else ...[
              ...visibleAppointments.map((b) => _buildAppointmentCard(b)),
              if (matchingAppointments.length > _visibleDisplayLimit) ...[
                const SizedBox(height: 12),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _visibleDisplayLimit += 25;
                      });
                    },
                    icon: const Icon(Icons.expand_more_rounded, size: 16),
                    label: Text(
                      'Show More (${matchingAppointments.length - _visibleDisplayLimit} remaining)',
                      style: AppFonts.poppins(
                        size: 12.5,
                        weight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF111827),
                      side: const BorderSide(color: Color(0xFF111827)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ── Section 1: Date Filter Presets ────────────────────────────────────────

  Widget _buildDatePresetsBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
            children: [
              const Icon(Icons.calendar_month_rounded,
                  size: 16, color: Color(0xFF111827)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Reporting Period',
                  style: AppFonts.parkinsans(
                    size: 13.5,
                    weight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  _formatDateRangeDisplay(),
                  style: AppFonts.poppins(
                    size: 11,
                    weight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: ReportDatePreset.values.map((preset) {
              final isSelected = _selectedPreset == preset;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _onPresetSelected(preset),
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF111827)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                        border: isSelected
                            ? null
                            : Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        preset.label,
                        style: AppFonts.poppins(
                          size: 12,
                          weight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Section 2: Groomer Filter Bar ─────────────────────────────────────────

  Widget _buildGroomerFilterBar() {
    final isAll = _selectedGroomerFilterIds.contains('all');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_outlined,
                  size: 15, color: Color(0xFF111827)),
              const SizedBox(width: 6),
              Text(
                'Staff Scope',
                style: AppFonts.parkinsans(
                  size: 13,
                  weight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              const Spacer(),
              Text(
                isAll
                    ? 'All Salon Staff'
                    : '${_selectedGroomerFilterIds.length} Staff Selected',
                style: AppFonts.poppins(
                  size: 11,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildGroomerChip(
                  label: 'All Groomers',
                  isSelected: isAll,
                  onTap: () => _onGroomerToggled('all'),
                ),
                ..._salonGroomers.map((g) {
                  final isSelected =
                      _selectedGroomerFilterIds.contains(g.id.toString());
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _buildGroomerChip(
                      label: g.name,
                      isSelected: isSelected,
                      onTap: () => _onGroomerToggled(g.id.toString()),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroomerChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF111827)
                : const Color(0xFFD1D5DB),
          ),
        ),
        child: Text(
          label,
          style: AppFonts.poppins(
            size: 11.5,
            weight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  // ── Section 3: Revenue Cards (Forecast vs Actual Collected) ───────────────

  Widget _buildRevenueSummarySection(GroomerReportSummary summary) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildFinancialMetricCard(
                title: 'Forecast Revenue',
                amount: summary.formattedForecastRevenue,
                subtitle:
                    '${summary.totalAppointments - summary.completedAppointments - summary.cancelledAppointments} active unpaid appts',
                disclosure: 'Projected pure service charges',
                accentColor: const Color(0xFF111827),
                icon: Icons.trending_up_rounded,
                isWarning: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFinancialMetricCard(
                title: 'Actual Collected',
                amount: summary.formattedActualRevenue,
                subtitle: !summary.isActualRevenueAvailable
                    ? 'Payment data unavailable'
                    : (summary.completedAppointments == 1
                        ? '1 completed appt'
                        : '${summary.completedAppointments} completed appts'),
                disclosure: summary.isActualRevenueAvailable
                    ? 'Verified server checkout payments'
                    : 'Pending counter settlement sync',
                accentColor: const Color(0xFF2563EB),
                icon: Icons.payments_outlined,
                isWarning: !summary.isActualRevenueAvailable,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildFinancialMetricCard(
                title: 'Confirmed Tips',
                amount: summary.formattedActualTips,
                subtitle: !summary.isTipsAvailable
                    ? 'Omitted by server API'
                    : 'Tips recorded on server',
                disclosure: 'Non-taxable gratuities',
                accentColor: const Color(0xFFD97706),
                icon: Icons.volunteer_activism_outlined,
                isWarning: !summary.isTipsAvailable,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildFinancialMetricCard(
                title: 'Total Collected',
                amount: summary.formattedActualTotalCollected,
                subtitle: !summary.isTotalCollectedAvailable
                    ? 'Pending checkout sync'
                    : 'Sales + tax + tips',
                disclosure: 'Gross settled receipts',
                accentColor: const Color(0xFF10B981),
                icon: Icons.account_balance_wallet_outlined,
                isWarning: !summary.isTotalCollectedAvailable,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFinancialMetricCard({
    required String title,
    required String amount,
    required String subtitle,
    required String disclosure,
    required Color accentColor,
    required IconData icon,
    bool isWarning = false,
  }) {
    final isUnavailable = amount.toLowerCase() == 'unavailable';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWarning
              ? const Color(0xFFFDE68A)
              : const Color(0xFFE5E7EB),
        ),
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
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isUnavailable
                      ? const Color(0xFF9CA3AF).withValues(alpha: 0.15)
                      : accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isUnavailable ? const Color(0xFF6B7280) : accentColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppFonts.poppins(
                    size: 11.5,
                    weight: FontWeight.w600,
                    color: const Color(0xFF4B5563),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: AppFonts.poppins(
                size: isUnavailable ? 16 : 20,
                weight: FontWeight.w700,
                color: isUnavailable
                    ? const Color(0xFF9CA3AF)
                    : (isWarning
                        ? const Color(0xFFB45309)
                        : const Color(0xFF111827)),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppFonts.poppins(
              size: 10.5,
              weight: isWarning ? FontWeight.w500 : FontWeight.w400,
              color:
                  isWarning ? const Color(0xFFB45309) : const Color(0xFF6B7280),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            disclosure,
            style: AppFonts.poppins(
              size: 9.5,
              color: const Color(0xFF9CA3AF),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Section 4: Status Breakdown Grid ──────────────────────────────────────

  Widget _buildStatusBreakdownSection(GroomerReportSummary summary) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              const Icon(Icons.pie_chart_outline_rounded,
                  size: 16, color: Color(0xFF111827)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Appointment Status Breakdown',
                  style: AppFonts.parkinsans(
                    size: 14,
                    weight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Completion: ${summary.completionRatePercentage}',
                  style: AppFonts.poppins(
                    size: 11,
                    weight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStatusCountCard(
                  label: 'Total',
                  count: summary.totalAppointments,
                  color: const Color(0xFF111827),
                  bgColor: const Color(0xFFF3F4F6),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusCountCard(
                  label: 'Completed',
                  count: summary.completedAppointments,
                  color: const Color(0xFF4338CA),
                  bgColor: const Color(0xFFEEF2FF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusCountCard(
                  label: 'Confirmed',
                  count: summary.confirmedAppointments,
                  color: const Color(0xFF111827),
                  bgColor: const Color(0xFFF3F4F6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatusCountCard(
                  label: 'In Progress',
                  count: summary.inProgressAppointments,
                  color: const Color(0xFF0284C7),
                  bgColor: const Color(0xFFF0F9FF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusCountCard(
                  label: 'Pending',
                  count: summary.pendingAppointments,
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFFFBEB),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusCountCard(
                  label: 'Cancelled',
                  count: summary.cancelledAppointments,
                  color: const Color(0xFFDC2626),
                  bgColor: const Color(0xFFFEF2F2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCountCard({
    required String label,
    required int count,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(
            count < 10 ? '0$count' : '$count',
            style: AppFonts.parkinsans(
              size: 18,
              weight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppFonts.poppins(
              size: 11,
              weight: FontWeight.w500,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Section 5: Staff Performance Breakdown ────────────────────────────────

  Widget _buildStaffBreakdownSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_outlined,
                  size: 16, color: Color(0xFF111827)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Staff Performance Summary',
                  style: AppFonts.parkinsans(
                    size: 14,
                    weight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _salonGroomers.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final g = _salonGroomers[i];
                final gSummary = _summaryForGroomer(g);

                return Container(
                  width: 220,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: const Color(0xFFF3F4F6),
                            child: Text(
                              g.name.isNotEmpty ? g.name[0].toUpperCase() : 'G',
                              style: AppFonts.poppins(
                                size: 11,
                                weight: FontWeight.w700,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              g.name,
                              style: AppFonts.poppins(
                                size: 12,
                                weight: FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Appts:',
                              style: AppFonts.poppins(
                                  size: 11, color: const Color(0xFF6B7280))),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${gSummary.totalAppointments} (${gSummary.completedAppointments} done)',
                              style: AppFonts.poppins(
                                size: 11,
                                weight: FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                              textAlign: TextAlign.end,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Forecast:',
                              style: AppFonts.poppins(
                                  size: 11, color: const Color(0xFF6B7280))),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              gSummary.formattedForecastRevenue,
                              style: AppFonts.poppins(
                                size: 11,
                                weight: FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                              textAlign: TextAlign.end,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Actual Sales:',
                              style: AppFonts.poppins(
                                  size: 11, color: const Color(0xFF6B7280))),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              gSummary.formattedActualRevenue,
                              style: AppFonts.poppins(
                                size: 11,
                                weight: FontWeight.w600,
                                color: gSummary.isActualRevenueAvailable
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF9CA3AF),
                              ),
                              textAlign: TextAlign.end,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 6: Search & Appointment Listing ───────────────────────────────

  Widget _buildSearchAndListHeader(int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input Field
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: TextField(
            controller: _searchController,
            style: AppFonts.poppins(size: 13, color: const Color(0xFF111827)),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _visibleDisplayLimit = 25;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search by pet, customer, phone, breed...',
              hintStyle: AppFonts.poppins(size: 12.5, color: const Color(0xFF9CA3AF)),
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 20, color: Color(0xFF6B7280)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded,
                          size: 18, color: Color(0xFF6B7280)),
                      onPressed: _clearSearch,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Secondary Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildSecondaryStatusChip('all', 'All ($count)'),
              _buildSecondaryStatusChip('completed', 'Completed'),
              _buildSecondaryStatusChip('confirmed', 'Confirmed'),
              _buildSecondaryStatusChip('in_progress', 'In Progress'),
              _buildSecondaryStatusChip('ready_for_checkout', 'Ready for Checkout'),
              _buildSecondaryStatusChip('pending', 'Pending'),
              _buildSecondaryStatusChip('cancelled', 'Cancelled'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryStatusChip(String filterKey, String label) {
    final isSelected = _selectedStatusFilter == filterKey;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedStatusFilter = filterKey;
              _visibleDisplayLimit = 25;
            });
          }
        },
        labelStyle: AppFonts.poppins(
          size: 11.5,
          weight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF4B5563),
        ),
        selectedColor: const Color(0xFF111827),
        backgroundColor: const Color(0xFFF3F4F6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFF111827)
                : const Color(0xFFE5E7EB),
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(GroomerBooking b) {
    final isPaid = b.isPaidVerified;
    final statusColor = _resolveStatusColor(b.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pet Avatar Initial
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFF3F4F6),
            child: Text(
              b.petName.isNotEmpty ? b.petName[0].toUpperCase() : 'P',
              style: AppFonts.poppins(
                size: 14,
                weight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${b.petName} (${b.breed.isNotEmpty ? b.breed : "Dog"})',
                        style: AppFonts.poppins(
                          size: 13.5,
                          weight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '\$${b.totalPrice.toStringAsFixed(2)}',
                      style: AppFonts.poppins(
                        size: 13.5,
                        weight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Customer: ${b.customerName} • ${b.formattedBookingDate} ${b.formattedTimeRange}',
                  style: AppFonts.poppins(
                    size: 11,
                    color: const Color(0xFF6B7280),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        b.status.toUpperCase(),
                        style: AppFonts.poppins(
                          size: 10,
                          weight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Payment Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isPaid ? 'PAID' : 'UNPAID',
                        style: AppFonts.poppins(
                          size: 10,
                          weight: FontWeight.w700,
                          color: isPaid
                              ? const Color(0xFF166534)
                              : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Staff: ${b.effectiveGroomerName}',
                          style: AppFonts.poppins(
                            size: 10.5,
                            color: const Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _resolveStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF4338CA);
      case 'confirmed':
        return const Color(0xFF10B981);
      case 'in_progress':
      case 'in-progress':
      case 'checked_in':
      case 'bath_completed':
      case 'grooming_completed':
        return const Color(0xFF0284C7);
      case 'ready_for_checkout':
        return const Color(0xFF111827);
      case 'pending':
        return const Color(0xFFD97706);
      case 'cancelled':
      case 'canceled':
      case 'rejected':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Widget _buildEmptyAppointmentsView() {
    return Container(
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_busy_rounded,
              size: 40, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 10),
          Text(
            'No Appointments Found',
            style: AppFonts.parkinsans(
              size: 15,
              weight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _searchQuery.isNotEmpty
                ? 'No appointments match your search criteria.'
                : 'No appointments recorded for the selected period and staff scope.',
            textAlign: TextAlign.center,
            style: AppFonts.poppins(size: 12, color: const Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}
