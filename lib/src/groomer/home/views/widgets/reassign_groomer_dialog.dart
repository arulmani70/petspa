import 'package:flutter/material.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';

/// Modal dialog for Manual Appointment Reassignment (Admin & Groomer Access).
///
/// Workflow:
/// 1. Verifies authorization (Admin or currently assigned groomer).
/// 2. Verifies customer Preferred Groomer restriction (blocks reassignment if set).
/// 3. Checks other groomers' availability for the exact same date and time slot.
/// 4. Displays ONLY available groomers.
/// 5. Prompts for manual confirmation before updating the appointment.
/// 6. Preserves existing appointment ID, customer, pet, services, date, time, and price.
class ReassignGroomerDialog extends StatefulWidget {
  final GroomerBooking booking;
  final ValueChanged<GroomerBooking>? onReassigned;

  const ReassignGroomerDialog({
    super.key,
    required this.booking,
    this.onReassigned,
  });

  static Future<GroomerBooking?> show(
    BuildContext context, {
    required GroomerBooking booking,
    ValueChanged<GroomerBooking>? onReassigned,
  }) {
    // Frontend restriction check
    final session = ServicesLocator.sessionService;
    if (booking.isPreferredGroomer) {
      ToastUtil.showErrorToast(
        context,
        'This appointment was booked with a Preferred Groomer and cannot be reassigned.',
      );
      return Future.value(null);
    }

    if (!session.canReassignBooking(booking)) {
      final reason = session.getReassignDisabledReason(booking) ??
          'Unauthorized: Only an Administrator or the currently assigned groomer can reassign this appointment.';
      ToastUtil.showErrorToast(context, reason);
      return Future.value(null);
    }

    return showDialog<GroomerBooking>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReassignGroomerDialog(
        booking: booking,
        onReassigned: onReassigned,
      ),
    );
  }

  @override
  State<ReassignGroomerDialog> createState() => _ReassignGroomerDialogState();
}

class _ReassignGroomerDialogState extends State<ReassignGroomerDialog> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<SalonGroomer> _availableGroomers = [];
  SalonGroomer? _selectedGroomer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAvailableGroomers();
  }

  Future<void> _loadAvailableGroomers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final groomers =
          await ServicesLocator.groomerHomeRepository.getAvailableGroomersForSlot(
        date: widget.booking.bookingDate,
        startTime: widget.booking.startTime,
        endTime: widget.booking.endTime,
        excludeGroomerId: widget.booking.groomerId,
        currentBookingId: widget.booking.bookingId,
      );

      if (mounted) {
        setState(() {
          _availableGroomers = groomers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to check groomer availability: $e';
        });
      }
    }
  }

  Future<void> _handleConfirmReassignment() async {
    if (_selectedGroomer == null || _isSubmitting) return;

    final target = _selectedGroomer!;

    // Show manual confirmation prompt
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm Reassignment',
          style: AppFonts.poppins(size: 17, weight: FontWeight.w700),
        ),
        content: Text(
          'Reassign appointment #${widget.booking.bookingId} (${widget.booking.petName}) to ${target.name}?\n\n'
          'The appointment date (${widget.booking.formattedBookingDate}), time (${widget.booking.formattedTimeRange}), '
          'customer, and services will remain unchanged.',
          style: AppFonts.poppins(size: 13.5, color: const Color(0xFF374151)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(confirmCtx).pop(false),
            child: Text(
              'Cancel',
              style: AppFonts.poppins(
                size: 13,
                weight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111827),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(confirmCtx).pop(true),
            child: Text(
              'Confirm',
              style: AppFonts.poppins(size: 13, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    final result = await ServicesLocator.groomerHomeRepository.reassignBooking(
      booking: widget.booking,
      targetGroomer: target,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success && result.updatedBooking != null) {
      ToastUtil.showSuccessToast(context, result.message);
      widget.onReassigned?.call(result.updatedBooking!);
      Navigator.of(context).pop(result.updatedBooking);
    } else {
      ToastUtil.showErrorToast(context, result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reassign Groomer',
                          style: AppFonts.poppins(
                            size: 18,
                            weight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Appointment #${widget.booking.bookingId} • ${widget.booking.petName}',
                          style: AppFonts.poppins(
                            size: 12.5,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Current Slot & Assigned Groomer Summary Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.event_outlined,
                          size: 14,
                          color: Color(0xFF4B5563),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Date: ${widget.booking.formattedBookingDate}',
                          style: AppFonts.poppins(
                            size: 12,
                            weight: FontWeight.w500,
                            color: const Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: Color(0xFF4B5563),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.booking.formattedTimeRange,
                          style: AppFonts.poppins(
                            size: 12,
                            weight: FontWeight.w500,
                            color: const Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_pin_outlined,
                          size: 14,
                          color: Color(0xFF4B5563),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Currently Assigned: ${widget.booking.effectiveGroomerName}',
                          style: AppFonts.poppins(
                            size: 12,
                            weight: FontWeight.w600,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Available Groomers',
                style: AppFonts.poppins(
                  size: 14,
                  weight: FontWeight.w600,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select an available groomer for the exact same date and time slot:',
                style: AppFonts.poppins(
                  size: 11.5,
                  color: const Color(0xFF6B7280),
                ),
              ),

              const SizedBox(height: 10),

              // Groomer List Section
              Expanded(
                child: _buildGroomerListContent(),
              ),

              const SizedBox(height: 14),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: AppFonts.poppins(
                        size: 13,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    key: const Key('confirm_reassignment_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE5E7EB),
                      disabledForegroundColor: const Color(0xFF9CA3AF),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                    ),
                    onPressed:
                        (_selectedGroomer == null || _isSubmitting || _isLoading)
                            ? null
                            : _handleConfirmReassignment,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Confirm Reassignment',
                            style: AppFonts.poppins(
                              size: 13,
                              weight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroomerListContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF111827),
            ),
            SizedBox(height: 12),
            Text(
              'Checking groomer availability...',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 28, color: Color(0xFFDC2626)),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: AppFonts.poppins(size: 12, color: const Color(0xFFDC2626)),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadAvailableGroomers,
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_availableGroomers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.event_busy_outlined,
              size: 34,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 8),
            Text(
              'No Available Groomers',
              style: AppFonts.poppins(
                size: 14,
                weight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'All other groomers are busy or booked during this date and time slot.',
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                size: 12,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: _availableGroomers.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final groomer = _availableGroomers[index];
        final isSelected = _selectedGroomer?.id == groomer.id;

        return InkWell(
          key: Key('groomer_option_${groomer.id}'),
          onTap: () {
            setState(() {
              _selectedGroomer = groomer;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFF3F4F6) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF111827)
                    : const Color(0xFFE5E7EB),
                width: isSelected ? 1.8 : 1.0,
              ),
            ),
            child: Row(
              children: [
                // Radio indicator
                Radio<int>(
                  value: groomer.id,
                  groupValue: _selectedGroomer?.id,
                  activeColor: const Color(0xFF111827),
                  onChanged: (val) {
                    setState(() {
                      _selectedGroomer = groomer;
                    });
                  },
                ),
                const SizedBox(width: 4),

                // Groomer Avatar / Initials
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF111827),
                  child: Text(
                    groomer.firstName.isNotEmpty
                        ? groomer.firstName[0].toUpperCase()
                        : 'G',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Groomer Name & Role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        groomer.name,
                        style: AppFonts.poppins(
                          size: 13.5,
                          weight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      Text(
                        groomer.role.isNotEmpty ? groomer.role : 'Groomer',
                        style: AppFonts.poppins(
                          size: 11.5,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),

                // "Available" Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 12,
                        color: Color(0xFF166534),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Available',
                        style: AppFonts.poppins(
                          size: 11,
                          weight: FontWeight.w600,
                          color: const Color(0xFF166534),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
