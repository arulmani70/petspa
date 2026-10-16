import 'package:flutter/material.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';

enum MilestoneType {
  bath,
  grooming,
}

class GroomerMilestoneDialog extends StatefulWidget {
  final GroomerBooking booking;
  final MilestoneType milestoneType;
  final ValueChanged<GroomerBooking>? onMilestoneSuccess;

  const GroomerMilestoneDialog({
    super.key,
    required this.booking,
    required this.milestoneType,
    this.onMilestoneSuccess,
  });

  static Future<GroomerBooking?> show(
    BuildContext context, {
    required GroomerBooking booking,
    required MilestoneType milestoneType,
    ValueChanged<GroomerBooking>? onMilestoneSuccess,
  }) {
    return showModalBottomSheet<GroomerBooking>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GroomerMilestoneDialog(
        booking: booking,
        milestoneType: milestoneType,
        onMilestoneSuccess: onMilestoneSuccess,
      ),
    );
  }

  @override
  State<GroomerMilestoneDialog> createState() => _GroomerMilestoneDialogState();
}

class _GroomerMilestoneDialogState extends State<GroomerMilestoneDialog> {
  late final TextEditingController _notesController;
  bool _isSubmitting = false;

  bool get _isBath => widget.milestoneType == MilestoneType.bath;

  @override
  void initState() {
    super.initState();
    final existingNote = _isBath ? widget.booking.bathNotes : widget.booking.groomingNotes;
    _notesController = TextEditingController(text: existingNote ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitMilestone() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final res = await ServicesLocator.groomerHomeRepository.updateServiceMilestone(
        bookingId: widget.booking.bookingId,
        milestone: _isBath ? 'bath_completed' : 'grooming_completed',
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        booking: widget.booking,
      );

      if (!mounted) return;

      if (res.success) {
        ToastUtil.showSuccessToast(context, res.message);
        final updated = res.updatedBooking ??
            widget.booking.copyWith(
              status: _isBath ? 'bath_completed' : 'grooming_completed',
              milestoneRecord: res.milestoneRecord,
            );

        widget.onMilestoneSuccess?.call(updated);
        Navigator.of(context).pop(updated);
      } else {
        ToastUtil.showErrorToast(context, res.message);
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.showErrorToast(context, 'Failed to update milestone: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final booking = widget.booking;

    final title = _isBath ? 'Bath Completed' : 'Grooming Completed';
    final subtitle = _isBath
        ? 'Record bath milestone & advance to styling'
        : 'Record grooming milestone & finish service';
    final buttonLabel = _isBath ? 'Confirm Bath Completed' : 'Confirm Grooming Completed';
    final iconData = _isBath ? Icons.bathtub_outlined : Icons.content_cut_rounded;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                    color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconData, size: 22, color: const Color(0xFF0F766E)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppFonts.parkinsans(
                          size: 17,
                          weight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: AppFonts.poppins(
                          size: 12,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF)),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service Stage Tracker
                  _buildServiceStageTracker(booking),
                  const SizedBox(height: 16),

                  // Pet Info Header Card
                  _buildPetInfoCard(booking),
                  const SizedBox(height: 14),

                  // Customer Special Instructions (if present)
                  if (booking.hasSpecialInstructions) ...[
                    _buildCustomerNotesCard(booking.specialInstructions!),
                    const SizedBox(height: 12),
                  ],

                  // Pet Medical Alert Notes (if present)
                  if (booking.hasPetMedicalNotes) ...[
                    _buildMedicalNotesCard(booking.petMedicalNotes!),
                    const SizedBox(height: 12),
                  ],

                  // Prior Milestone note (if grooming and bath has notes)
                  if (!_isBath && booking.bathNotes != null && booking.bathNotes!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bath Note Recorded:',
                                  style: AppFonts.poppins(
                                    size: 11,
                                    weight: FontWeight.w600,
                                    color: const Color(0xFF1E40AF),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '"${booking.bathNotes}"',
                                  style: AppFonts.poppins(
                                    size: 12,
                                    color: const Color(0xFF1E3A8A),
                                  ).copyWith(fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Optional Milestone Notes input
                  Text(
                    'Milestone Notes (Optional)',
                    style: AppFonts.poppins(
                      size: 13,
                      weight: FontWeight.w600,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isBath
                        ? 'Record any shampoo type, coat condition, or drying observations'
                        : 'Record styling details, hair trimming notes, or finished look',
                    style: AppFonts.poppins(
                      size: 11.5,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    maxLength: 300,
                    style: AppFonts.poppins(size: 13, color: const Color(0xFF111827)),
                    decoration: InputDecoration(
                      hintText: _isBath
                          ? 'e.g., Hypoallergenic oatmeal shampoo used. Blow dry complete...'
                          : 'e.g., Teddy bear face trim complete. Nails clipped & buffed...',
                      hintStyle: AppFonts.poppins(size: 12.5, color: const Color(0xFF9CA3AF)),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4B5563),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                          child: Text(
                            'Cancel',
                            style: AppFonts.poppins(
                              size: 13,
                              weight: FontWeight.w600,
                              color: const Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _isSubmitting ? null : _submitMilestone,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Icon(iconData, size: 18, color: Colors.white),
                          label: Text(
                            _isSubmitting ? 'Saving...' : buttonLabel,
                            style: AppFonts.poppins(
                              size: 13,
                              weight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceStageTracker(GroomerBooking booking) {
    final stages = [
      ('Check-in', booking.isCheckedIn),
      ('Bath', booking.isBathCompleted || _isBath),
      ('Grooming', booking.isGroomingCompleted || (!_isBath)),
      ('Checkout', false),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(stages.length, (i) {
          final label = stages[i].$1;
          final isDoneOrCurrent = stages[i].$2;
          final isCurrent = (_isBath && i == 1) || (!_isBath && i == 2);

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent
                      ? const Color(0xFF0F766E)
                      : (isDoneOrCurrent ? const Color(0xFF10B981) : const Color(0xFFE5E7EB)),
                ),
                child: Center(
                  child: isDoneOrCurrent && !isCurrent
                      ? const Icon(Icons.check, size: 13, color: Colors.white)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isCurrent ? Colors.white : const Color(0xFF6B7280),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppFonts.poppins(
                  size: 11,
                  weight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: isCurrent ? const Color(0xFF0F766E) : const Color(0xFF4B5563),
                ),
              ),
              if (i < stages.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildPetInfoCard(GroomerBooking booking) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.1),
            backgroundImage: (booking.profilePicture != null &&
                    booking.profilePicture!.isNotEmpty &&
                    !booking.profilePicture!.contains('default_avatar'))
                ? NetworkImage(booking.profilePicture!)
                : null,
            child: (booking.profilePicture == null ||
                    booking.profilePicture!.isEmpty ||
                    booking.profilePicture!.contains('default_avatar'))
                ? const Icon(Icons.pets_rounded, size: 20, color: Color(0xFF0F766E))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      booking.petName,
                      style: AppFonts.parkinsans(
                        size: 14,
                        weight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    if (booking.breed.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '• ${booking.breed}',
                        style: AppFonts.poppins(
                          size: 12,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  booking.fullServiceDescription,
                  style: AppFonts.poppins(
                    size: 11.5,
                    weight: FontWeight.w500,
                    color: const Color(0xFF0F766E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerNotesCard(String notes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote_rounded, size: 16, color: Color(0xFF0F766E)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer Request:',
                  style: AppFonts.poppins(
                    size: 11,
                    weight: FontWeight.w600,
                    color: const Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '"$notes"',
                  style: AppFonts.poppins(
                    size: 12,
                    color: const Color(0xFF134E4A),
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalNotesCard(String medicalNotes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Medical Alert:',
                  style: AppFonts.poppins(
                    size: 11,
                    weight: FontWeight.w600,
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '"$medicalNotes"',
                  style: AppFonts.poppins(
                    size: 12,
                    color: const Color(0xFF78350F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
