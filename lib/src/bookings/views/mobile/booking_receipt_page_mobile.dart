import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shear_heaven_pet_spa/src/bookings/models/booking_receipt.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';

/// Dedicated screen and sheet for viewing authoritative receipts and invoices (Step 11).
///
/// Features:
/// - Official Shear Heaven Pet Spa receipt styling with itemized charges.
/// - Authoritative display of base price, add-ons, confirmed tip, and taxes.
/// - Fetches live authoritative receipt from GET /api/bookings/:bookingId/receipt.
/// - Never fabricates fake receipt numbers, transaction references, or tax values.
/// - Payment status is confirmed ONLY when explicit server payment data exists;
///   an appointment with status 'completed' is never falsely marked as paid.
/// - Copy-to-clipboard functionality for sharing receipt summaries.
/// - Clean unavailable state when receipt data is missing or incomplete.
class BookingReceiptPageMobile extends StatefulWidget {
  final BookingReceipt receipt;

  const BookingReceiptPageMobile({
    super.key,
    required this.receipt,
  });

  static Future<void> show(
    BuildContext context, {
    required BookingReceipt receipt,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BookingReceiptPageMobile(receipt: receipt),
    );
  }

  @override
  State<BookingReceiptPageMobile> createState() => _BookingReceiptPageMobileState();
}

class _BookingReceiptPageMobileState extends State<BookingReceiptPageMobile> {
  late BookingReceipt _receipt;
  bool _isFetchingServerReceipt = false;

  BookingReceipt get receipt => _receipt;

  @override
  void initState() {
    super.initState();
    _receipt = widget.receipt;
    _fetchServerReceipt();
  }

  Future<void> _fetchServerReceipt() async {
    final bId = widget.receipt.bookingId;
    if (bId <= 0) return;

    if (mounted) setState(() => _isFetchingServerReceipt = true);
    try {
      // 1. Fetch live authoritative receipt from {{baseUrl}}/api/bookings/{{bookingId}}/receipt
      Map<String, dynamic>? data =
          await ServicesLocator.bookingRepository.getReceipt(bId);

      // 2. Fallback to groomer repository if groomer session is active
      if (data == null && ServicesLocator.sessionService.isGroomerLoggedIn) {
        data = await ServicesLocator.groomerHomeRepository.getReceipt(bId);
      }

      if (data != null && mounted) {
        final serverReceipt = BookingReceipt.fromMap(data);
        setState(() {
          _receipt = _mergeReceipts(_receipt, serverReceipt);
        });
      }
    } catch (_) {
      // Maintain initial receipt without disruption
    } finally {
      if (mounted) setState(() => _isFetchingServerReceipt = false);
    }
  }

  BookingReceipt _mergeReceipts(BookingReceipt initial, BookingReceipt server) {
    return BookingReceipt(
      bookingId: server.bookingId > 0 ? server.bookingId : initial.bookingId,
      transactionId: server.transactionId ?? initial.transactionId,
      status: server.status.isNotEmpty && server.status != 'unknown' ? server.status : initial.status,
      isPaid: server.isPaid ?? initial.isPaid,
      paymentStatus: server.paymentStatus ?? initial.paymentStatus,
      paymentMethod: server.paymentMethod ?? initial.paymentMethod,
      petName: server.petName.isNotEmpty && server.petName != 'Pet' ? server.petName : initial.petName,
      breed: server.breed.isNotEmpty ? server.breed : initial.breed,
      customerName: server.customerName.isNotEmpty && server.customerName != 'Customer' ? server.customerName : initial.customerName,
      customerPhone: server.customerPhone.isNotEmpty ? server.customerPhone : initial.customerPhone,
      customerEmail: server.customerEmail.isNotEmpty ? server.customerEmail : initial.customerEmail,
      groomerName: server.groomerName.isNotEmpty && server.groomerName != 'Assigned Staff' ? server.groomerName : initial.groomerName,
      serviceName: server.serviceName.isNotEmpty && server.serviceName != 'Grooming Service' ? server.serviceName : initial.serviceName,
      packageName: server.packageName ?? initial.packageName,
      addOns: server.addOns.isNotEmpty ? server.addOns : initial.addOns,
      basePrice: server.basePrice > 0 ? server.basePrice : initial.basePrice,
      tipAmount: server.tipAmount ?? initial.tipAmount,
      taxAmount: server.taxAmount ?? initial.taxAmount,
      discountAmount: server.discountAmount ?? initial.discountAmount,
      depositAmount: server.depositAmount ?? initial.depositAmount,
      totalAuthoritativeAmount: server.totalAuthoritativeAmount > 0 ? server.totalAuthoritativeAmount : initial.totalAuthoritativeAmount,
      appointmentDate: server.appointmentDate.isNotEmpty ? server.appointmentDate : initial.appointmentDate,
      appointmentTime: server.appointmentTime.isNotEmpty ? server.appointmentTime : initial.appointmentTime,
      completedAt: server.completedAt ?? initial.completedAt,
    );
  }

  void _copyReceiptToClipboard(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln('--- SHEAR HEAVEN PET SPA ---');
    buffer.writeln('OFFICIAL SERVICE RECEIPT & INVOICE');
    buffer.writeln('Booking Ref: #${receipt.bookingId}');
    if (receipt.transactionId != null) {
      buffer.writeln('Transaction Ref: ${receipt.transactionId}');
    }
    buffer.writeln('Date: ${receipt.appointmentDate} at ${receipt.appointmentTime}');
    buffer.writeln('Customer: ${receipt.customerName}');
    buffer.writeln('Pet: ${receipt.petName} (${receipt.breed})');
    buffer.writeln('Assigned Groomer: ${receipt.groomerName}');
    buffer.writeln('Service: ${receipt.fullServiceDescription}');
    if (receipt.addOns.isNotEmpty) {
      buffer.writeln('Add-ons: ${receipt.addOns.join(", ")}');
    }
    buffer.writeln('Base Amount: \$${receipt.basePrice.toStringAsFixed(2)}');
    if (receipt.hasTip) {
      buffer.writeln('Confirmed Tip: \$${receipt.tipAmount!.toStringAsFixed(2)}');
    }
    if (receipt.hasTax) {
      buffer.writeln('Tax: \$${receipt.taxAmount!.toStringAsFixed(2)}');
    }
    buffer.writeln('Total Authoritative: \$${receipt.totalAuthoritativeAmount.toStringAsFixed(2)}');
    buffer.writeln('Payment Status: ${receipt.isAuthoritativelyPaid ? "PAID" : "COUNTER SETTLEMENT"}');
    buffer.writeln('----------------------------');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ToastUtil.showSuccessToast(context, 'Receipt summary copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    if (!receipt.hasReceiptData) {
      return _buildUnavailableState(context);
    }

    final isPaid = receipt.isAuthoritativelyPaid;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
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

          // ── Header Bar ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Color(0xFF0F766E),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Receipt & Invoice',
                    style: AppFonts.parkinsans(
                      size: 16,
                      weight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isFetchingServerReceipt) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20, color: Color(0xFF0F766E)),
                  tooltip: 'Copy Receipt Summary',
                  onPressed: () => _copyReceiptToClipboard(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF6B7280)),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // ── Scrollable Receipt Paper Body ─────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Brand Logo & Title
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFCCFBF1),
                      child: const Icon(
                        Icons.pets_rounded,
                        color: Color(0xFF0F766E),
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Shear Heaven Pet Spa',
                      style: AppFonts.parkinsans(
                        size: 18,
                        weight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Official Service Receipt • Arlington, TX',
                      style: AppFonts.poppins(
                        size: 12,
                        weight: FontWeight.w400,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Payment Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isPaid ? const Color(0xFFDEF7EC) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isPaid ? const Color(0xFF31C48D) : const Color(0xFFF59E0B),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                              size: 15,
                              color: isPaid ? const Color(0xFF03543F) : const Color(0xFFB45309),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isPaid ? 'PAID IN FULL' : 'COUNTER SETTLEMENT PENDING',
                              style: AppFonts.poppins(
                                size: 11.5,
                                weight: FontWeight.w700,
                                color: isPaid ? const Color(0xFF03543F) : const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Dashed Ticket Divider
                    _buildDashedDivider(),
                    const SizedBox(height: 16),

                    // Metadata Table
                    _buildMetadataRow('Booking Ref', '#${receipt.bookingId}'),
                    const SizedBox(height: 6),
                    _buildMetadataRow(
                      'Transaction Ref',
                      receipt.transactionId ?? 'Pending counter sync',
                      isItalicIfEmpty: receipt.transactionId == null,
                    ),
                    const SizedBox(height: 6),
                    _buildMetadataRow('Date & Time', '${receipt.appointmentDate} • ${receipt.appointmentTime}'),
                    const SizedBox(height: 6),
                    if (receipt.completedAt != null && receipt.completedAt!.isNotEmpty) ...[
                      _buildMetadataRow('Completed On', receipt.completedAt!),
                      const SizedBox(height: 6),
                    ],

                    const SizedBox(height: 12),
                    _buildDashedDivider(),
                    const SizedBox(height: 16),

                    // Customer & Pet Information
                    _buildSectionHeader('Client & Appointment Details'),
                    const SizedBox(height: 10),
                    _buildMetadataRow('Customer', '${receipt.customerName}${receipt.customerPhone.isNotEmpty ? " (${receipt.customerPhone})" : ""}'),
                    const SizedBox(height: 6),
                    _buildMetadataRow('Pet Name', '${receipt.petName}${receipt.breed.isNotEmpty ? " • ${receipt.breed}" : ""}'),
                    const SizedBox(height: 6),
                    _buildMetadataRow('Assigned Staff', receipt.groomerName),
                    const SizedBox(height: 6),
                    _buildMetadataRow('Service Package', receipt.fullServiceDescription),

                    const SizedBox(height: 14),
                    _buildDashedDivider(),
                    const SizedBox(height: 16),

                    // Authoritative Charges Breakdown
                    _buildSectionHeader('Authoritative Itemized Charges'),
                    const SizedBox(height: 10),

                    _buildChargeRow('Base Service', '\$${receipt.basePrice.toStringAsFixed(2)}'),
                    const SizedBox(height: 6),

                    if (receipt.addOns.isNotEmpty) ...[
                      ...receipt.addOns.map((addon) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 8),
                                      const Icon(Icons.subdirectory_arrow_right_rounded, size: 13, color: Color(0xFF0F766E)),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          addon,
                                          style: AppFonts.poppins(
                                            size: 11.5,
                                            weight: FontWeight.w400,
                                            color: const Color(0xFF4B5563),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Selected add-on',
                                  style: AppFonts.poppins(
                                    size: 11,
                                    weight: FontWeight.w400,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 6),
                    ],

                    // Confirmed Tip
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Confirmed Tip',
                          style: AppFonts.poppins(
                            size: 12,
                            weight: FontWeight.w500,
                            color: const Color(0xFF4B5563),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            receipt.hasTip
                                ? '\$${receipt.tipAmount!.toStringAsFixed(2)}'
                                : 'No tip recorded on server',
                            textAlign: TextAlign.end,
                            style: AppFonts.poppins(
                              size: 12,
                              weight: receipt.hasTip ? FontWeight.w600 : FontWeight.w400,
                              color: receipt.hasTip ? const Color(0xFF0F766E) : const Color(0xFF9CA3AF),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Taxes
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
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            receipt.hasTax
                                ? '\$${receipt.taxAmount!.toStringAsFixed(2)}'
                                : 'Calculated at counter',
                            textAlign: TextAlign.end,
                            style: AppFonts.poppins(
                              size: 12,
                              weight: receipt.hasTax ? FontWeight.w600 : FontWeight.w400,
                              color: receipt.hasTax ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Discount (if present)
                    if (receipt.hasDiscount) ...[
                      _buildChargeRow('Discount Applied', '-\$${receipt.discountAmount!.toStringAsFixed(2)}', isNegative: true),
                      const SizedBox(height: 6),
                    ],

                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    const SizedBox(height: 10),

                    // Total Authoritative
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Total Amount',
                            style: AppFonts.parkinsans(
                              size: 15,
                              weight: FontWeight.w800,
                              color: const Color(0xFF111827),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '\$${receipt.totalAuthoritativeAmount.toStringAsFixed(2)}',
                          style: AppFonts.parkinsans(
                            size: 18,
                            weight: FontWeight.w800,
                            color: const Color(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                    _buildDashedDivider(),
                    const SizedBox(height: 14),

                    // Payment Settlement Details Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF4B5563)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Payment Settlement Disclosure',
                                  style: AppFonts.poppins(
                                    size: 11,
                                    weight: FontWeight.w600,
                                    color: const Color(0xFF1F2937),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            receipt.isAuthoritativelyPaid
                                ? 'Payment method and transaction settlement confirmed by salon register record.'
                                : 'All service charges are settled in person at our salon register. Payment confirmation relies strictly on authoritative server sync.',
                            style: AppFonts.poppins(
                              size: 10.5,
                              weight: FontWeight.w400,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom Action Bar ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyReceiptToClipboard(context),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Copy Receipt',
                        style: AppFonts.poppins(
                          size: 13,
                          weight: FontWeight.w600,
                          color: const Color(0xFF0F766E),
                        ),
                        maxLines: 1,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Color(0xFF0F766E)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Done',
                        style: AppFonts.poppins(
                          size: 13,
                          weight: FontWeight.w600,
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

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: AppFonts.poppins(
          size: 11,
          weight: FontWeight.w700,
          color: const Color(0xFF6B7280),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value, {bool isItalicIfEmpty = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppFonts.poppins(
            size: 12,
            weight: FontWeight.w500,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppFonts.poppins(
              size: 12,
              weight: FontWeight.w600,
              color: isItalicIfEmpty ? const Color(0xFF9CA3AF) : const Color(0xFF1F2937),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChargeRow(String label, String amount, {bool isNegative = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppFonts.poppins(
              size: 12,
              weight: FontWeight.w500,
              color: const Color(0xFF4B5563),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          amount,
          style: AppFonts.poppins(
            size: 12,
            weight: FontWeight.w600,
            color: isNegative ? const Color(0xFFDC2626) : const Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _buildDashedDivider() {
    return Row(
      children: List.generate(
        32,
        (index) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Container(
              height: 1,
              color: const Color(0xFFD1D5DB),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnavailableState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 14),
            Text(
              'Receipt Unavailable',
              style: AppFonts.parkinsans(
                size: 18,
                weight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Detailed receipt data could not be found for this booking.',
              textAlign: TextAlign.center,
              style: AppFonts.poppins(
                size: 13,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Close',
                  style: AppFonts.poppins(size: 13, weight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
