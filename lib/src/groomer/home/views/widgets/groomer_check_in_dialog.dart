import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_check_in_record.dart';

/// Modal dialog for Groomer Intake & Check-in Checklist (Step 6).
///
/// Features:
/// - Clear separation of 3 note types:
///   1. Customer Service Request Description (from booking)
///   2. Permanent Pet Medical & Allergy Notes (from pet profile)
///   3. Groomer Intake Notes (entered at physical intake)
/// - Interactive Checklist for Vaccination, Health, and Customer Request Acknowledgment.
/// - Authoritative submission to POST /api/groomer-auth/bookings/:id/check-in.
/// - Does not fabricate timestamps; renders server-provided check-in timestamp.
class GroomerCheckInDialog extends StatefulWidget {
  final GroomerBooking booking;
  final ValueChanged<GroomerBooking>? onCheckInSuccess;

  const GroomerCheckInDialog({
    super.key,
    required this.booking,
    this.onCheckInSuccess,
  });

  static Future<GroomerBooking?> show(
    BuildContext context, {
    required GroomerBooking booking,
    ValueChanged<GroomerBooking>? onCheckInSuccess,
  }) {
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
      return Future.value(null);
    }
    return showModalBottomSheet<GroomerBooking>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GroomerCheckInDialog(
        booking: booking,
        onCheckInSuccess: onCheckInSuccess,
      ),
    );
  }

  @override
  State<GroomerCheckInDialog> createState() => _GroomerCheckInDialogState();
}

class _GroomerCheckInDialogState extends State<GroomerCheckInDialog> {
  bool _vaccinationVerified = false;
  bool _healthVerified = false;
  bool _customerRequestAcknowledged = false;
  late final TextEditingController _groomerNotesController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate if already checked in or partially recorded
    final record = widget.booking.checkInRecord;
    _vaccinationVerified = record?.vaccinationVerified ?? false;
    _healthVerified = record?.healthVerified ?? false;
    _customerRequestAcknowledged = record?.customerRequestAcknowledged ?? false;
    _groomerNotesController = TextEditingController(
      text: record?.groomerCheckInNotes ?? '',
    );

    // If no instructions, automatically acknowledge
    if (!widget.booking.hasSpecialInstructions) {
      _customerRequestAcknowledged = true;
    }
  }

  @override
  void dispose() {
    _groomerNotesController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_isSubmitting) return false;
    // Check-in allowed only on the scheduled booking date if not already checked in

    if (!widget.booking.isCheckedIn && !widget.booking.canCheckIn()) {
      return false;
    }
    // Both vaccination and health verification are strictly required for intake
    if (!_vaccinationVerified || !_healthVerified) return false;
    // Customer request must be acknowledged if customer left instructions
    if (widget.booking.hasSpecialInstructions && !_customerRequestAcknowledged) {
      return false;
    }
    return true;
  }

  Future<void> _submitCheckIn() async {
    if (!_canSubmit || _isSubmitting) return;

    if (!widget.booking.isCheckedIn && !widget.booking.canCheckIn()) {
      ToastUtil.showErrorToast(
        context,
        'Check-in is only allowed on the scheduled booking date.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final res = await ServicesLocator.groomerHomeRepository.checkInBooking(
        bookingId: widget.booking.bookingId,
        vaccinationVerified: _vaccinationVerified,
        healthVerified: _healthVerified,
        customerRequestAcknowledged: _customerRequestAcknowledged,
        groomerCheckInNotes: _groomerNotesController.text.trim().isNotEmpty
            ? _groomerNotesController.text.trim()
            : null,
        booking: widget.booking,
      );

      if (!mounted) return;

      if (res.success) {
        ToastUtil.showSuccessToast(context, res.message);
        final updated = res.updatedBooking ??
            widget.booking.copyWith(
              status: 'checked_in',
              checkInRecord: res.checkInRecord ??
                  GroomerCheckInRecord(
                    vaccinationVerified: _vaccinationVerified,
                    healthVerified: _healthVerified,
                    customerRequestAcknowledged: _customerRequestAcknowledged,
                    groomerCheckInNotes: _groomerNotesController.text.trim(),
                  ),
            );

        widget.onCheckInSuccess?.call(updated);
        Navigator.of(context).pop(updated);
      } else {
        ToastUtil.showErrorToast(context, res.message);
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.showErrorToast(context, 'Check-in failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final booking = widget.booking;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.assignment_turned_in_outlined,
                    color: Color(0xFF111827),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pet Intake & Check-in',
                        style: AppFonts.parkinsans(
                          size: 17,
                          weight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Booking #${booking.bookingId} • ${booking.petName} (${booking.breed.isNotEmpty ? booking.breed : "Dog"})',
                        style: AppFonts.poppins(
                          size: 12,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF6B7280)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // Scrollable Checklist Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Check-in Date Restriction Notice (if not on scheduled date) ──
                  if (!booking.isCheckedIn && !booking.canCheckIn()) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              booking.isBeforeScheduledDate()
                                  ? 'Check-in will open on the scheduled booking date: ${booking.formattedBookingDate}.'
                                  : 'Check-in is closed because the scheduled booking date (${booking.formattedBookingDate}) has passed.',
                              style: AppFonts.poppins(
                                size: 12,
                                weight: FontWeight.w500,
                                color: const Color(0xFF991B1B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Existing Server Check-in Timestamp (if present) ──
                  if (booking.checkInTimestamp != null &&
                      booking.checkInTimestamp!.isNotEmpty) ...[
                    _buildTimestampBanner(booking.checkInTimestamp!),
                    const SizedBox(height: 16),
                  ],

                  // ── Section 1: Customer Service Request Instructions ──
                  _buildCustomerInstructionsCard(booking),

                  const SizedBox(height: 14),

                  // ── Section 2: Permanent Pet Medical & Allergy Notes ──
                  if (booking.hasPetMedicalNotes) ...[
                    _buildPetMedicalNotesCard(booking.petMedicalNotes!),
                    const SizedBox(height: 14),
                  ],

                  // ── Section 3: Physical Intake Verification Checklist ──
                  Text(
                    'Intake Verification Checklist',
                    style: AppFonts.parkinsans(
                      size: 14.5,
                      weight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All required safety verifications must be completed before starting service.',
                    style: AppFonts.poppins(
                      size: 11.5,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Checkbox 1: Vaccination Verified
                  _buildChecklistItem(
                    title: 'Vaccination Verified',
                    subtitle: 'Confirmed pet has current rabies and core vaccinations on file or presented by customer.',
                    value: _vaccinationVerified,
                    isRequired: true,
                    onChanged: (val) => setState(() => _vaccinationVerified = val ?? false),
                    icon: Icons.verified_user_outlined,
                  ),

                  const SizedBox(height: 10),

                  // Checkbox 2: Dog Health & Physical Assessment Verified
                  _buildChecklistItem(
                    title: "Dog's Health & Coat Verified",
                    subtitle: 'Intake coat/skin check complete. No open wounds, parasites, or medical distress.',
                    value: _healthVerified,
                    isRequired: true,
                    onChanged: (val) => setState(() => _healthVerified = val ?? false),
                    icon: Icons.health_and_safety_outlined,
                  ),

                  const SizedBox(height: 10),

                  // Checkbox 3: Customer Request Acknowledged
                  _buildChecklistItem(
                    title: 'Customer Request Acknowledged',
                    subtitle: booking.hasSpecialInstructions
                        ? 'Customer\'s service instructions have been reviewed and noted for grooming.'
                        : 'No additional instructions were requested by the customer.',
                    value: _customerRequestAcknowledged,
                    isRequired: booking.hasSpecialInstructions,
                    onChanged: (val) => setState(() => _customerRequestAcknowledged = val ?? false),
                    icon: Icons.speaker_notes_outlined,
                  ),

                  const SizedBox(height: 18),

                  // ── Section 4: Groomer Check-in Notes ──
                  Text(
                    'Groomer Check-in Notes',
                    style: AppFonts.parkinsans(
                      size: 14.5,
                      weight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Record coat condition, matting, demeanor, or pre-existing conditions.',
                    style: AppFonts.poppins(
                      size: 11.5,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: TextField(
                      controller: _groomerNotesController,
                      maxLines: 3,
                      minLines: 2,
                      style: AppFonts.poppins(
                        size: 13,
                        color: const Color(0xFF111827),
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. Coat lightly matted behind ears, calm demeanor, skin clear...',
                        hintStyle: AppFonts.poppins(
                          size: 12.5,
                          color: const Color(0xFF9CA3AF),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // Bottom Action Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: AppFonts.poppins(
                        size: 13.5,
                        weight: FontWeight.w600,
                        color: const Color(0xFF374151),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _canSubmit
                          ? const Color(0xFF111827)
                          : const Color(0xFF9CA3AF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _canSubmit ? _submitCheckIn : null,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Confirm Check-in',
                              style: AppFonts.parkinsans(
                                size: 13.5,
                                weight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildTimestampBanner(String rawIso) {
    String formatted = rawIso;
    try {
      final dt = DateTime.parse(rawIso);
      formatted = DateFormat('MMM d, yyyy • h:mm a').format(dt.toLocal());
    } catch (_) {}

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF16A34A)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Server Check-in Timestamp: $formatted',
              style: AppFonts.poppins(
                size: 11.5,
                weight: FontWeight.w600,
                color: const Color(0xFF15803D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInstructionsCard(GroomerBooking booking) {
    final instructions = booking.specialInstructions?.trim();
    final hasInstructions = instructions != null && instructions.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speaker_notes_outlined, size: 15, color: Color(0xFF111827)),
              const SizedBox(width: 6),
              Text(
                'Customer Service Instructions',
                style: AppFonts.parkinsans(
                  size: 12.5,
                  weight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hasInstructions
                ? '"$instructions"'
                : 'No specific instructions were submitted for this booking.',
            style: AppFonts.poppins(
              size: 12,
              color: hasInstructions ? const Color(0xFF334155) : const Color(0xFF94A3B8),
            ).copyWith(fontStyle: hasInstructions ? FontStyle.italic : FontStyle.normal),
          ),
        ],
      ),
    );
  }

  Widget _buildPetMedicalNotesCard(String medicalNotes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.medical_services_outlined, size: 15, color: Color(0xFFB45309)),
              const SizedBox(width: 6),
              Text(
                'Pet Medical & Allergy Notes (Permanent Profile)',
                style: AppFonts.parkinsans(
                  size: 12.5,
                  weight: FontWeight.w700,
                  color: const Color(0xFFB45309),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            medicalNotes,
            style: AppFonts.poppins(
              size: 12,
              color: const Color(0xFF78350F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem({
    required String title,
    required String subtitle,
    required bool value,
    required bool isRequired,
    required ValueChanged<bool?> onChanged,
    required IconData icon,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: value ? const Color(0xFFF3F4F6) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
            width: value ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF111827),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 15, color: value ? const Color(0xFF111827) : const Color(0xFF6B7280)),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: AppFonts.poppins(
                          size: 13,
                          weight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      if (isRequired) ...[
                        const SizedBox(width: 4),
                        const Text(
                          '*',
                          style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: AppFonts.poppins(
                      size: 11.5,
                      color: const Color(0xFF6B7280),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
