import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';

/// Card component for managing individual service line groomer assignments.
///
/// Workflow & Specification (matches live Web Portal & API):
/// - Header: "Service groomer assignments"
/// - Subtitle: "Calendar primary groomer: {primaryGroomerName} (booking owner).
///   Each service line starts unassigned — pick a groomer manually;
///   only then they see the visit and are blocked on the schedule."
/// - For each service task in [serviceProgress]:
///   - Displays task name, booked amount (e.g. "Booked $60.00"), and assignment status:
///     "Assigned: [Groomer Name]" or "Not assigned".
///   - Dropdown allows manual selection of an available salon groomer.
///   - Calls PUT /api/common/groomer/bookings/:id/service-progress/assign-groomer
/// - Preferred Groomer Restriction:
///   - If customer locked preferred groomer, manual reassignment is strictly disabled.
/// - Assignment history:
///   - Displays past assignment log: timestamp · service name → groomer (was previous groomer).
class ServiceGroomerAssignmentsCard extends StatefulWidget {
  final GroomerBooking booking;
  final List<SalonGroomer> groomers;
  final String? primaryGroomerName;
  final bool assignmentsLocked;
  final Future<void> Function(String taskKey, int groomerId)? onAssignGroomer;

  const ServiceGroomerAssignmentsCard({
    super.key,
    required this.booking,
    this.groomers = const [],
    this.primaryGroomerName,
    this.assignmentsLocked = false,
    this.onAssignGroomer,
  });

  @override
  State<ServiceGroomerAssignmentsCard> createState() =>
      _ServiceGroomerAssignmentsCardState();
}

class _ServiceGroomerAssignmentsCardState
    extends State<ServiceGroomerAssignmentsCard> {
  String? _busyTaskKey;
  final Map<String, int?> _selectedGroomerMap = {};

  @override
  void initState() {
    super.initState();
    _syncSelectedMap();
  }

  @override
  void didUpdateWidget(covariant ServiceGroomerAssignmentsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.booking != widget.booking) {
      _syncSelectedMap();
    }
  }

  void _syncSelectedMap() {
    for (final task in widget.booking.serviceProgress) {
      if (task.assignedGroomerId != null && task.assignedGroomerId! > 0) {
        _selectedGroomerMap[task.taskKey] = task.assignedGroomerId;
      }
    }
  }

  List<ServiceProgressItem> get _sortedTasks {
    final list = List<ServiceProgressItem>.from(widget.booking.serviceProgress);
    list.sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
    return list;
  }

  List<SalonGroomer> get _effectiveGroomers {
    final list = List<SalonGroomer>.from(widget.groomers);
    for (final task in widget.booking.serviceProgress) {
      final gId = task.assignedGroomerId;
      if (gId != null && gId > 0 && !list.any((g) => g.id == gId)) {
        final gName = task.assignedGroomerName ??
            BookingDateUtils.resolveGroomerNameById(gId) ??
            'Groomer #$gId';
        final parts = gName.split(' ');
        final fName = parts.isNotEmpty ? parts.first : gName;
        final lName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        list.add(SalonGroomer(
          id: gId,
          groomerCode: task.assignedGroomerCode ?? 'G00$gId',
          firstName: fName,
          lastName: lName,
          name: gName,
        ));
      }
    }
    final pId = widget.booking.effectivePrimaryGroomerId;
    if (pId != null && pId > 0 && !list.any((g) => g.id == pId)) {
      final pName = widget.booking.effectivePrimaryGroomerName;
      final parts = pName.split(' ');
      final fName = parts.isNotEmpty ? parts.first : pName;
      final lName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      list.add(SalonGroomer(
        id: pId,
        groomerCode: 'G00$pId',
        firstName: fName,
        lastName: lName,
        name: pName,
      ));
    }
    return list;
  }

  String _formatActivityTime(dynamic timeValue) {
    if (timeValue == null) return '';
    try {
      final dt = DateTime.parse(timeValue.toString()).toLocal();
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (_) {
      return timeValue.toString();
    }
  }

  Future<void> _handleGroomerChanged(String taskKey, int? newGroomerId) async {
    if (newGroomerId == null || newGroomerId <= 0) return;
    if (_busyTaskKey != null) return;

    setState(() {
      _busyTaskKey = taskKey;
      _selectedGroomerMap[taskKey] = newGroomerId;
    });

    try {
      if (widget.onAssignGroomer != null) {
        await widget.onAssignGroomer!(taskKey, newGroomerId);
      } else {
        await ServicesLocator.groomerHomeRepository.assignServiceGroomer(
          bookingId: widget.booking.bookingId,
          taskKey: taskKey,
          groomerId: newGroomerId,
          storeId: widget.booking.storeId,
          currentBooking: widget.booking,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign groomer: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busyTaskKey = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _sortedTasks;
    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    final effectiveGroomers = _effectiveGroomers;
    final effectivePrimary = widget.primaryGroomerName ??
        widget.booking.effectivePrimaryGroomerName;
    final isLocked = widget.assignmentsLocked || widget.booking.isGroomerAssignmentLocked;
    final isPreferredLocked = widget.booking.isPreferredGroomer;
    final currentUserId = int.tryParse(ServicesLocator.sessionService.currentUserId?.toString() ?? '');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.content_cut_rounded,
                  size: 16,
                  color: Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Service groomer assignments',
                  style: AppFonts.poppins(
                    size: 14,
                    weight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Subtitle
          Text(
            'Calendar primary groomer: $effectivePrimary (booking owner). '
            'Each service line starts unassigned — pick a groomer manually; '
            'only then they see the visit and are blocked on the schedule.',
            style: AppFonts.poppins(
              size: 11.5,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),

          // Lock notice if checkout completed or started
          if (isLocked) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Groomer assignments are locked — all booked services are complete or checkout has started.',
                      style: AppFonts.poppins(
                        size: 11.5,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Preferred Groomer notice
          if (isPreferredLocked && !isLocked) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.stars_rounded,
                    size: 16,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Customer requested preferred groomer. Reassignment to other groomers is disabled.',
                      style: AppFonts.poppins(
                        size: 11.5,
                        color: const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // List of Service Lines
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tasks.length,
            separatorBuilder: (_, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final task = tasks[index];
              final isBusy = _busyTaskKey == task.taskKey;
              final isTaskAssignable = task.assignable && !isLocked && !isPreferredLocked;
              final assignedGroomerId = _selectedGroomerMap[task.taskKey] ?? task.assignedGroomerId;
              final assignedName = task.assignedGroomerName;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Service Details (Name, Price, Status)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.displayName,
                            style: AppFonts.poppins(
                              size: 13,
                              weight: FontWeight.w600,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${task.lineServiceAmount != null && task.lineServiceAmount! > 0 ? "Booked \$${task.lineServiceAmount!.toStringAsFixed(2)} · " : ""}'
                            '${!isTaskAssignable ? "Not assignable — primary groomer only" : (assignedName != null && assignedName.isNotEmpty ? "Assigned: $assignedName" : "Not assigned")}',
                            style: AppFonts.poppins(
                              size: 11,
                              color: !isTaskAssignable
                                  ? const Color(0xFF94A3B8)
                                  : (assignedName != null && assignedName.isNotEmpty
                                      ? const Color(0xFF059669)
                                      : const Color(0xFF64748B)),
                              weight: assignedName != null && assignedName.isNotEmpty
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Groomer Selection Dropdown
                    if (!isTaskAssignable)
                      Text(
                        'Assignment disabled',
                        style: AppFonts.poppins(
                          size: 11,
                          weight: FontWeight.w500,
                          color: const Color(0xFF94A3B8),
                        ),
                      )
                    else if (isBusy)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF4F46E5),
                        ),
                      )
                    else
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: effectiveGroomers.any((g) => g.id == assignedGroomerId)
                                ? assignedGroomerId
                                : null,
                            hint: Text(
                              'Select groomer…',
                              style: AppFonts.poppins(
                                size: 11.5,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              size: 18,
                              color: Color(0xFF64748B),
                            ),
                            style: AppFonts.poppins(
                              size: 12,
                              weight: FontWeight.w500,
                              color: const Color(0xFF1E293B),
                            ),
                            items: effectiveGroomers.map((g) {
                              final isSelf = g.isSelf || (currentUserId != null && g.id == currentUserId);
                              return DropdownMenuItem<int>(
                                value: g.id,
                                child: Text(
                                  '${g.name}${isSelf ? " (you)" : ""}',
                                  style: AppFonts.poppins(
                                    size: 12,
                                    weight: FontWeight.w500,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (newId) => _handleGroomerChanged(task.taskKey, newId),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // Assignment History Section (matches web portal LI)
          if (widget.booking.serviceAssignmentActivity.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFF1F5F9)),
            const SizedBox(height: 8),
            Text(
              'ASSIGNMENT HISTORY',
              style: AppFonts.poppins(
                size: 10.5,
                weight: FontWeight.w700,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.booking.serviceAssignmentActivity.length,
                separatorBuilder: (_, index) => const SizedBox(height: 6),
                itemBuilder: (context, idx) {
                  final act = widget.booking.serviceAssignmentActivity[idx];
                  final at = _formatActivityTime(act['at'] ?? act['timestamp']);
                  final taskLabel = act['taskLabel'] ?? act['taskKey'] ?? 'Service';
                  final groomerName = act['groomerName'] ?? 'Groomer #${act['groomerId']}';
                  final prevName = act['previousGroomerName'];

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text.rich(
                      TextSpan(
                        style: AppFonts.poppins(
                          size: 11,
                          color: const Color(0xFF475569),
                        ),
                        children: [
                          TextSpan(
                            text: at,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                          const TextSpan(text: ' · '),
                          TextSpan(text: '$taskLabel → '),
                          TextSpan(
                            text: groomerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                          if (prevName != null && prevName.toString().isNotEmpty)
                            TextSpan(
                              text: ' (was $prevName)',
                              style: const TextStyle(color: Color(0xFF94A3B8)),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
