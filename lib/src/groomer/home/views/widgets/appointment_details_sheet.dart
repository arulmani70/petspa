import 'package:flutter/material.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/groomer_milestone_dialog.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/service_groomer_assignments_card.dart';

/// Modal bottom sheet presenting full details for an appointment.
///
/// Workflow:
/// - Admin or current groomer opens appointment details.
/// - Clearly indicates if customer selected a Preferred Groomer (which strictly locks reassignment).
/// - Displays assigned groomer and past reassignment history.
/// - Allows manual groomer assignment and reassignment via Service Groomer Assignments dropdown.
class AppointmentDetailsSheet extends StatefulWidget {
  final GroomerBooking booking;
  final ValueChanged<GroomerBooking>? onReassigned;

  const AppointmentDetailsSheet({
    super.key,
    required this.booking,
    this.onReassigned,
  });

  static Future<void> show(
    BuildContext context, {
    required GroomerBooking booking,
    ValueChanged<GroomerBooking>? onReassigned,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppointmentDetailsSheet(
        booking: booking,
        onReassigned: onReassigned,
      ),
    );
  }

  @override
  State<AppointmentDetailsSheet> createState() => _AppointmentDetailsSheetState();
}

class _AppointmentDetailsSheetState extends State<AppointmentDetailsSheet> {
  late GroomerBooking _booking;
  List<SalonGroomer> _salonGroomers = [];

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _loadGroomersAndLatestData();
  }

  Future<void> _loadGroomersAndLatestData() async {
    try {
      final repo = ServicesLocator.groomerHomeRepository;
      final groomersFuture = repo.getSalonGroomers();
      final latestBookingFuture = repo.fetchBookingMilestonesAndProgress(
        _booking.bookingId,
        storeId: _booking.storeId,
        currentBooking: _booking,
      );

      final groomers = await groomersFuture;
      final latestBooking = await latestBookingFuture;

      if (mounted) {
        setState(() {
          _salonGroomers = groomers;
          if (latestBooking != null) {
            _booking = latestBooking;
          }
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Drag Handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Sheet Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appointment Details',
                        style: AppFonts.poppins(
                          size: 19,
                          weight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Booking #${_booking.bookingId}',
                        style: AppFonts.poppins(
                          size: 12.5,
                          weight: FontWeight.w500,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 16, color: Color(0xFFF3F4F6)),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Preferred Groomer Restriction Banner
                    if (_booking.isPreferredGroomer) ...[
                      Container(
                        key: const Key('preferred_groomer_banner'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 20,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Preferred Groomer Selection',
                                    style: AppFonts.poppins(
                                      size: 13,
                                      weight: FontWeight.w700,
                                      color: const Color(0xFF92400E),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'The customer requested this specific groomer during booking. '
                                    'Reassignment to another groomer is strictly prohibited to preserve customer preference.',
                                    style: AppFonts.poppins(
                                      size: 11.5,
                                      color: const Color(0xFFB45309),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Schedule & Status Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 15,
                                    color: Color(0xFF4B5563),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _booking.formattedBookingDate,
                                    style: AppFonts.poppins(
                                      size: 13,
                                      weight: FontWeight.w600,
                                      color: const Color(0xFF1F2937),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _booking.status.toUpperCase(),
                                  style: AppFonts.poppins(
                                    size: 11,
                                    weight: FontWeight.w700,
                                    color: const Color(0xFF166534),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 15,
                                color: Color(0xFF4B5563),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _booking.formattedTimeRange,
                                style: AppFonts.poppins(
                                  size: 13,
                                  weight: FontWeight.w500,
                                  color: const Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Pet & Customer Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: const Color(0xFF111827),
                                child: Text(
                                  _booking.petName.isNotEmpty
                                      ? _booking.petName[0].toUpperCase()
                                      : 'P',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _booking.petName,
                                      style: AppFonts.poppins(
                                        size: 15,
                                        weight: FontWeight.w700,
                                        color: const Color(0xFF111827),
                                      ),
                                    ),
                                    Text(
                                      _booking.breed.isNotEmpty
                                          ? _booking.breed
                                          : 'Standard Breed',
                                      style: AppFonts.poppins(
                                        size: 12,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20, color: Color(0xFFF3F4F6)),
                          _buildDetailRow(
                            Icons.person_outline,
                            'Customer',
                            _booking.customerName,
                          ),
                          if (_booking.customerMobile.isNotEmpty)
                            _buildDetailRow(
                              Icons.phone_outlined,
                              'Mobile',
                              _booking.customerMobile,
                            ),
                          if (_booking.customerEmail.isNotEmpty)
                            _buildDetailRow(
                              Icons.email_outlined,
                              'Email',
                              _booking.customerEmail,
                            ),
                          if (_booking.hasPetMedicalNotes) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.medical_services_outlined,
                                    size: 14,
                                    color: Color(0xFFDC2626),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Medical Alert: ${_booking.petMedicalNotes}',
                                      style: AppFonts.poppins(
                                        size: 11.5,
                                        color: const Color(0xFF991B1B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Service & Price Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            Icons.content_cut_rounded,
                            'Service',
                            _booking.fullServiceDescription.isNotEmpty
                                ? _booking.fullServiceDescription
                                : 'Full Grooming',
                          ),
                          _buildDetailRow(
                            Icons.attach_money_rounded,
                            'Total Price',
                            '\$${_booking.totalPrice.toStringAsFixed(2)}',
                          ),
                          if (_booking.hasSpecialInstructions)
                            _buildDetailRow(
                              Icons.notes_rounded,
                              'Instructions',
                              _booking.specialInstructions!,
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Assigned Groomer Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.badge_outlined,
                            size: 20,
                            color: Color(0xFF166534),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assigned Groomer (Primary / Calendar Owner)',
                                  style: AppFonts.poppins(
                                    size: 11.5,
                                    color: const Color(0xFF15803D),
                                  ),
                                ),
                                Text(
                                  _booking.effectivePrimaryGroomerName,
                                  style: AppFonts.poppins(
                                    size: 14,
                                    weight: FontWeight.w700,
                                    color: const Color(0xFF166534),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Service Groomer Assignments Card (matches web portal LI component)
                    ServiceGroomerAssignmentsCard(
                      booking: _booking.serviceProgress.isEmpty
                          ? _booking.copyWith(
                              serviceProgress: [
                                ServiceProgressItem(
                                  taskKey: 'svc-${_booking.bookingId}-parent',
                                  taskName: _booking.serviceName,
                                  lineServiceAmount: _booking.totalPrice,
                                  assignedGroomerId: _booking.groomerId,
                                  assignedGroomerName: _booking.effectiveGroomerName,
                                  primaryGroomerName: _booking.effectivePrimaryGroomerName,
                                  primaryGroomerId: _booking.effectivePrimaryGroomerId,
                                ),
                              ],
                            )
                          : _booking,
                      groomers: _salonGroomers,
                      primaryGroomerName: _booking.effectivePrimaryGroomerName,
                      assignmentsLocked: _booking.isGroomerAssignmentLocked,
                      onAssignGroomer: (taskKey, groomerId) async {
                        final messenger = ScaffoldMessenger.of(context);
                        final res = await ServicesLocator.groomerHomeRepository.assignServiceGroomer(
                          bookingId: _booking.bookingId,
                          taskKey: taskKey,
                          groomerId: groomerId,
                          storeId: _booking.storeId,
                          currentBooking: _booking,
                        );
                        if (!mounted) return;
                        if (res.success && res.updatedBooking != null) {
                          setState(() {
                            _booking = res.updatedBooking!;
                          });
                          widget.onReassigned?.call(res.updatedBooking!);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(res.message),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        } else if (!res.success) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(res.message),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          );
                        }
                      },
                    ),

                    // Reassignment History Section (if present)
                    if (_booking.reassignmentHistory.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Assignment History',
                        style: AppFonts.poppins(
                          size: 14,
                          weight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _booking.reassignmentHistory.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final entry = _booking.reassignmentHistory[index];
                          final fromGroomer = entry['fromGroomerName'] ?? 'Previous Groomer';
                          final toGroomer = entry['toGroomerName'] ?? 'New Groomer';
                          final by = entry['reassignedBy'] ?? 'Admin';
                          final at = entry['reassignedAt']?.toString() ?? '';

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 16,
                                  color: Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Reassigned: $fromGroomer → $toGroomer',
                                        style: AppFonts.poppins(
                                          size: 12,
                                          weight: FontWeight.w600,
                                          color: const Color(0xFF1F2937),
                                        ),
                                      ),
                                      Text(
                                        'By $by${at.isNotEmpty ? ' • ${at.split('T').first}' : ''}',
                                        style: AppFonts.poppins(
                                          size: 11,
                                          color: const Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],

                    // Milestone Update Action (matching web portal)
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          final updated = await GroomerMilestoneDialog.show(
                            context,
                            booking: _booking,
                            onMilestoneSuccess: (ub) {
                              if (mounted) setState(() => _booking = ub);
                              widget.onReassigned?.call(ub);
                            },
                          );
                          if (updated != null && mounted) {
                            setState(() => _booking = updated);
                            widget.onReassigned?.call(updated);
                          }
                        },
                        icon: Icon(Icons.sync_rounded, size: 18, color: Theme.of(context).colorScheme.onPrimary),
                        label: Text(
                          _booking.isCompleted ? 'View Milestones' : 'Update Milestone',
                          style: AppFonts.parkinsans(
                            size: 13.5,
                            weight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: AppFonts.poppins(
              size: 12.5,
              weight: FontWeight.w500,
              color: const Color(0xFF6B7280),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppFonts.poppins(
                size: 12.5,
                weight: FontWeight.w600,
                color: const Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
