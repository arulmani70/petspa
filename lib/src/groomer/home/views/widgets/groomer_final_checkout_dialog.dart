import 'package:flutter/material.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';

/// Modal dialog for Groomer Final Checkout (Step 10).
///
/// Features:
/// - Authoritative display of booking charges, itemized add-ons, confirmed tip,
///   and verified tax without fabricating values ($0.00 is never used for missing taxes).
/// - Enforces lifecycle rule: final checkout is only permitted for bookings
///   in the verified `ready_for_checkout` state.
/// - Salon counter settlement disclosure for cash / card payment verification.
/// - Duplicate submission prevention (local submission guard + button disabling).
/// - Submits to verified endpoint POST /api/groomer-auth/bookings/:id/complete.
/// - Status is transitioned to 'completed' only upon confirmed server success.
class GroomerFinalCheckoutDialog extends StatefulWidget {
  final GroomerBooking booking;
  final ValueChanged<GroomerBooking>? onCheckoutSuccess;

  const GroomerFinalCheckoutDialog({
    super.key,
    required this.booking,
    this.onCheckoutSuccess,
  });

  static Future<GroomerBooking?> show(
    BuildContext context, {
    required GroomerBooking booking,
    ValueChanged<GroomerBooking>? onCheckoutSuccess,
  }) {
    return showModalBottomSheet<GroomerBooking>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GroomerFinalCheckoutDialog(
        booking: booking,
        onCheckoutSuccess: onCheckoutSuccess,
      ),
    );
  }

  @override
  State<GroomerFinalCheckoutDialog> createState() => _GroomerFinalCheckoutDialogState();
}

class _GroomerFinalCheckoutDialogState extends State<GroomerFinalCheckoutDialog> {
  bool _isSubmitting = false;

  bool get _isReadyForCheckout => widget.booking.isReadyForCheckout;

  Future<void> _handleConfirmCheckout() async {
    if (_isSubmitting) return;

    if (!_isReadyForCheckout) {
      ToastUtil.showErrorToast(
        context,
        'Appointment must be in Ready for Checkout state before final checkout.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final res = await ServicesLocator.groomerHomeRepository.completeBookingDetails(
        widget.booking.bookingId,
        booking: widget.booking,
      );

      if (!mounted) return;

      if (res.success) {
        ToastUtil.showSuccessToast(context, res.message);
        final updated = res.updatedBooking ??
            widget.booking.copyWith(
              status: 'completed',
            );

        widget.onCheckoutSuccess?.call(updated);
        Navigator.of(context).pop(updated);
      } else {
        ToastUtil.showErrorToast(context, res.message);
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.showErrorToast(context, 'Failed to complete checkout: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

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
          // ── Drag Handle ───────────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.point_of_sale_rounded,
                    color: Color(0xFF0F766E),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Final Checkout',
                        style: AppFonts.poppins(
                          size: 17,
                          weight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      Text(
                        'Booking #${booking.bookingId} • ${booking.petName}',
                        style: AppFonts.poppins(
                          size: 12,
                          weight: FontWeight.w400,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF6B7280)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // ── Scrollable Body ───────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Appointment Overview Card
                  _buildAppointmentOverviewCard(booking),
                  const SizedBox(height: 16),

                  // 2. Authoritative Charges Breakdown Card
                  _buildChargesBreakdownCard(booking),
                  const SizedBox(height: 16),

                  // 3. Salon Counter Payment Settlement Card
                  _buildSalonSettlementCard(),
                  const SizedBox(height: 16),

                  // 4. Ineligibility Warning (if not ready_for_checkout)
                  if (!_isReadyForCheckout) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This appointment is not marked as Ready for Checkout. Final checkout can only be submitted once grooming is completed and marked ready for checkout.',
                              style: AppFonts.poppins(
                                size: 12,
                                weight: FontWeight.w500,
                                color: const Color(0xFFB91C1C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),

          // ── Bottom Action Footer ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                    ),
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
                    onPressed: (_isSubmitting || !_isReadyForCheckout)
                        ? null
                        : _handleConfirmCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF9CA3AF),
                      disabledForegroundColor: Colors.white70,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      _isSubmitting ? 'Completing Checkout...' : 'Confirm & Complete Checkout',
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
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentOverviewCard(GroomerBooking booking) {
    return Container(
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
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFCCFBF1),
                child: Text(
                  booking.petName.isNotEmpty ? booking.petName[0].toUpperCase() : 'P',
                  style: AppFonts.poppins(
                    size: 15,
                    weight: FontWeight.w700,
                    color: const Color(0xFF0F766E),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.petName,
                      style: AppFonts.poppins(
                        size: 14.5,
                        weight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      booking.breed.isNotEmpty ? booking.breed : 'Breed not specified',
                      style: AppFonts.poppins(
                        size: 12,
                        weight: FontWeight.w400,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: booking.isReadyForCheckout
                      ? const Color(0xFFCCFBF1)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: booking.isReadyForCheckout
                        ? const Color(0xFF99F6E4)
                        : const Color(0xFFFDE68A),
                  ),
                ),
                child: Text(
                  booking.isReadyForCheckout ? 'Ready for Checkout' : booking.status,
                  style: AppFonts.poppins(
                    size: 11,
                    weight: FontWeight.w600,
                    color: booking.isReadyForCheckout
                        ? const Color(0xFF0F766E)
                        : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.person_outline_rounded, 'Customer', '${booking.customerName} (${booking.customerMobile})'),
          const SizedBox(height: 6),
          _buildInfoRow(Icons.content_cut_rounded, 'Service', booking.fullServiceDescription),
          const SizedBox(height: 6),
          _buildInfoRow(Icons.badge_outlined, 'Assigned Groomer', booking.effectiveGroomerName),
          const SizedBox(height: 6),
          _buildInfoRow(Icons.calendar_today_rounded, 'Schedule', '${booking.formattedBookingDate} • ${booking.formattedTimeRange}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF6B7280)),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: AppFonts.poppins(
            size: 11.5,
            weight: FontWeight.w500,
            color: const Color(0xFF6B7280),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppFonts.poppins(
              size: 11.5,
              weight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChargesBreakdownCard(GroomerBooking booking) {
    final hasConfirmedTip = booking.tipAmount != null && booking.tipAmount! > 0;
    final hasConfirmedTax = booking.taxAmount != null && booking.taxAmount! > 0;

    return Container(
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
              const Icon(Icons.receipt_long_rounded, size: 17, color: Color(0xFF0F766E)),
              const SizedBox(width: 8),
              Text(
                'Authoritative Charges',
                style: AppFonts.poppins(
                  size: 13.5,
                  weight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 10),

          // Base Service Price
          _buildChargeRow(
            'Base Service / Package',
            '\$${booking.totalPrice.toStringAsFixed(2)}',
            isBold: false,
          ),
          const SizedBox(height: 8),

          // Itemized Add-ons (if any)
          if (booking.addOns.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: booking.addOns
                    .map(
                      (addon) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.add_circle_outline_rounded, size: 12, color: Color(0xFF0F766E)),
                            const SizedBox(width: 5),
                            Text(
                              addon,
                              style: AppFonts.poppins(
                                size: 11,
                                weight: FontWeight.w500,
                                color: const Color(0xFF4B5563),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],

          // Confirmed Tip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Tip',
                    style: AppFonts.poppins(
                      size: 12,
                      weight: FontWeight.w500,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                  if (hasConfirmedTip) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDEF7EC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Customer Confirmed',
                        style: AppFonts.poppins(
                          size: 9.5,
                          weight: FontWeight.w600,
                          color: const Color(0xFF03543F),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                hasConfirmedTip
                    ? '\$${booking.tipAmount!.toStringAsFixed(2)}'
                    : 'No tip confirmed on server',
                style: AppFonts.poppins(
                  size: 12,
                  weight: hasConfirmedTip ? FontWeight.w600 : FontWeight.w400,
                  color: hasConfirmedTip ? const Color(0xFF0F766E) : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Taxes (Strict Rule: never fabricate $0.00)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Taxes',
                style: AppFonts.poppins(
                  size: 12,
                  weight: FontWeight.w500,
                  color: const Color(0xFF4B5563),
                ),
              ),
              Text(
                hasConfirmedTax
                    ? '\$${booking.taxAmount!.toStringAsFixed(2)}'
                    : 'Calculated at counter',
                style: AppFonts.poppins(
                  size: 12,
                  weight: hasConfirmedTax ? FontWeight.w600 : FontWeight.w400,
                  color: hasConfirmedTax ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 10),

          // Total Due
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Authoritative Total',
                style: AppFonts.poppins(
                  size: 14,
                  weight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              Text(
                '\$${booking.totalAuthoritativeAmountDue.toStringAsFixed(2)}',
                style: AppFonts.poppins(
                  size: 16,
                  weight: FontWeight.w800,
                  color: const Color(0xFF0F766E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChargeRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppFonts.poppins(
            size: 12,
            weight: isBold ? FontWeight.w600 : FontWeight.w500,
            color: const Color(0xFF4B5563),
          ),
        ),
        Text(
          value,
          style: AppFonts.poppins(
            size: 12,
            weight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: const Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _buildSalonSettlementCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.store_rounded, size: 18, color: Color(0xFF15803D)),
              const SizedBox(width: 8),
              Text(
                'Salon Counter Settlement',
                style: AppFonts.poppins(
                  size: 13,
                  weight: FontWeight.w700,
                  color: const Color(0xFF166534),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Payment Method: Cash or Card at Salon Register',
            style: AppFonts.poppins(
              size: 11.5,
              weight: FontWeight.w600,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Collect and verify customer payment at the counter prior to completing checkout. Online payment gateway and cash drawer tendered API contracts are pending backend deployment.',
            style: AppFonts.poppins(
              size: 11,
              weight: FontWeight.w400,
              color: const Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}
