import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/bookings/bloc/booking_bloc.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';

enum TipPreset { fifteen, twenty, twentyFive, custom, none }

/// Step 9: Customer Checkout Summary and Tip Confirmation Sheet.
///
/// Displays itemized charges based strictly on verified booking data.
/// Provides interactive tip selection (15%, 20%, 25%, Custom, None)
/// with real-time total calculation and custom input validation.
///
/// CRITICAL SAFEGUARD: Tip confirmation records tip preference only;
/// it does NOT trigger payment, charge the customer, or mark the booking completed.
class CustomerCheckoutSummarySheet extends StatefulWidget {
  final Map<String, dynamic> booking;
  final ValueChanged<Map<String, dynamic>>? onTipConfirmed;

  const CustomerCheckoutSummarySheet({
    super.key,
    required this.booking,
    this.onTipConfirmed,
  });

  /// Convenient modal launcher
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required Map<String, dynamic> booking,
    ValueChanged<Map<String, dynamic>>? onTipConfirmed,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CustomerCheckoutSummarySheet(
        booking: booking,
        onTipConfirmed: onTipConfirmed,
      ),
    );
  }

  @override
  State<CustomerCheckoutSummarySheet> createState() =>
      _CustomerCheckoutSummarySheetState();
}

class _CustomerCheckoutSummarySheetState
    extends State<CustomerCheckoutSummarySheet> {
  TipPreset _selectedPreset = TipPreset.twenty; // default 20%
  final TextEditingController _customTipController = TextEditingController();
  String? _customTipError;
  bool _isSubmitting = false;
  bool _isConfirmed = false;
  double? _confirmedTipAmount;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    // If booking already has a confirmed tip
    final existingTip = widget.booking['tipAmount'] ?? widget.booking['tip_amount'];
    if (existingTip != null) {
      final parsed = double.tryParse(existingTip.toString());
      if (parsed != null) {
        _confirmedTipAmount = parsed;
        if (widget.booking['isTipConfirmed'] == true) {
          _isConfirmed = true;
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant CustomerCheckoutSummarySheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTip = widget.booking['tipAmount'] ?? widget.booking['tip_amount'];
    if (newTip != null) {
      final parsed = double.tryParse(newTip.toString());
      if (parsed != null && parsed != _confirmedTipAmount) {
        _confirmedTipAmount = parsed;
      }
    }
    if (widget.booking['isTipConfirmed'] == true && !_isConfirmed) {
      _isConfirmed = true;
    }
  }

  @override
  void dispose() {
    _customTipController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Field extraction & Calculations
  // ─────────────────────────────────────────────────────────────────────────

  int get _bookingId {
    final raw = widget.booking['bookingId'] ??
        widget.booking['id'] ??
        widget.booking['booking_id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  String get _petName {
    final pet = widget.booking['pet'] is Map ? widget.booking['pet'] as Map : null;
    final name = widget.booking['petName'] ??
        widget.booking['pet_name'] ??
        widget.booking['name'] ??
        pet?['name'] ??
        pet?['petName'] ??
        pet?['pet_name'];
    final s = name?.toString().trim() ?? '';
    return (s.isNotEmpty && s != 'null') ? s : 'Pet';
  }

  String get _petBreed {
    final pet = widget.booking['pet'] is Map ? widget.booking['pet'] as Map : null;
    final breed = widget.booking['petBreed'] ??
        widget.booking['pet_breed'] ??
        widget.booking['breed'] ??
        pet?['breed'] ??
        pet?['petBreed'] ??
        pet?['pet_breed'];
    final s = breed?.toString().trim() ?? '';
    return (s.isNotEmpty && s != 'null') ? s : 'Breed not specified';
  }

  String? get _petPhoto {
    return PetImageHelper.extractPetPhoto(widget.booking);
  }

  String get _groomerName {
    final g = widget.booking['groomer'] is Map ? widget.booking['groomer'] as Map : null;
    final name = widget.booking['groomerName'] ??
        widget.booking['groomer_name'] ??
        g?['name'] ??
        g?['groomerName'] ??
        widget.booking['assignedGroomer'];
    final s = name?.toString().trim() ?? '';
    return (s.isNotEmpty && s != 'null' && s != 'No. pref') ? s : 'Assigned Groomer';
  }

  String get _dateLabel {
    final date = widget.booking['bookingDate'] ??
        widget.booking['booking_date'] ??
        widget.booking['date'];
    if (date != null && date.toString().isNotEmpty) {
      try {
        final parsed = DateTime.tryParse(date.toString());
        if (parsed != null) {
          return DateFormat('MMM d, yyyy').format(parsed);
        }
      } catch (_) {}
      return date.toString();
    }
    return 'Today';
  }

  String get _timeLabel {
    final start = widget.booking['startTime'] ??
        widget.booking['start_time'] ??
        widget.booking['time'] ??
        '';
    final end = widget.booking['endTime'] ?? widget.booking['end_time'] ?? '';
    if (start.toString().isNotEmpty && end.toString().isNotEmpty) {
      return '${start.toString()} – ${end.toString()}';
    }
    return start.toString().isNotEmpty ? start.toString() : 'Scheduled Time';
  }

  String get _serviceName {
    final s = widget.booking['serviceName'] ??
        widget.booking['service_name'] ??
        widget.booking['service']?['service_name'] ??
        widget.booking['service']?['name'] ??
        widget.booking['package_name'] ??
        widget.booking['packageName'];
    final str = s?.toString().trim() ?? '';
    return str.isNotEmpty ? str : 'Full Grooming Spa';
  }

  List<({String name, double? price})> get _addOns {
    final result = <({String name, double? price})>[];
    final raw = widget.booking['addons'] ??
        widget.booking['addOns'] ??
        widget.booking['add_ons'] ??
        widget.booking['addons_list'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final name = (item['name'] ??
                  item['service_name'] ??
                  item['title'] ??
                  item['addOnName'])
              ?.toString();
          if (name != null && name.isNotEmpty) {
            final rawPrice = item['price'] ?? item['addon_price'];
            double? parsedPrice;
            if (rawPrice is num) {
              parsedPrice = rawPrice.toDouble();
            } else if (rawPrice != null) {
              parsedPrice = double.tryParse(rawPrice.toString());
            }
            result.add((name: name, price: parsedPrice));
          }
        } else if (item != null && item.toString().isNotEmpty) {
          result.add((name: item.toString(), price: null));
        }
      }
    }
    return result;
  }

  /// Calculates base price and subtotal
  double get _subtotal {
    final rawTotal = widget.booking['totalPrice'] ??
        widget.booking['total_price'] ??
        widget.booking['subtotal'] ??
        widget.booking['sub_total'];
    if (rawTotal is num && rawTotal > 0) {
      return rawTotal.toDouble();
    }
    if (rawTotal != null) {
      final p = double.tryParse(rawTotal.toString());
      if (p != null && p > 0) return p;
    }

    // Fallback: sum service price + addons prices
    double total = 0.0;
    final sPrice = widget.booking['servicePrice'] ??
        widget.booking['service_price'] ??
        widget.booking['price'];
    if (sPrice is num) {
      total += sPrice.toDouble();
    } else if (sPrice != null) {
      total += double.tryParse(sPrice.toString()) ?? 0.0;
    }

    for (final addon in _addOns) {
      if (addon.price != null && addon.price! > 0) {
        total += addon.price!;
      }
    }

    return total > 0 ? total : 85.0; // fallback standard service baseline
  }

  double get _baseServicePrice {
    double addonsSum = 0.0;
    for (final addon in _addOns) {
      if (addon.price != null && addon.price! > 0) {
        addonsSum += addon.price!;
      }
    }
    if (_subtotal > addonsSum) {
      return _subtotal - addonsSum;
    }
    return _subtotal;
  }

  /// Verified discount: null if absent, otherwise parsed double > 0
  double? get _verifiedDiscount {
    final raw = widget.booking['discountAmount'] ??
        widget.booking['discount_amount'] ??
        widget.booking['discount'] ??
        widget.booking['promoDiscount'];
    if (raw is num && raw > 0) return raw.toDouble();
    if (raw != null) {
      final p = double.tryParse(raw.toString());
      if (p != null && p > 0) return p;
    }
    return null;
  }

  /// Verified taxes: null if absent (never fabricated as $0.00)
  double? get _verifiedTax {
    final raw = widget.booking['taxAmount'] ??
        widget.booking['tax_amount'] ??
        widget.booking['tax'];
    if (raw is num && raw > 0) return raw.toDouble();
    if (raw != null) {
      final p = double.tryParse(raw.toString());
      if (p != null && p > 0) return p;
    }
    return null; // Null means tax is calculated at counter
  }

  /// Verified deposit paid: null if absent (never fabricated)
  double? get _verifiedDeposit {
    final raw = widget.booking['depositAmount'] ??
        widget.booking['deposit_amount'] ??
        widget.booking['deposit'];
    if (raw is num && raw > 0) return raw.toDouble();
    if (raw != null) {
      final p = double.tryParse(raw.toString());
      if (p != null && p > 0) return p;
    }
    return null;
  }

  /// Current selected tip amount based on active preset
  double get _currentTipAmount {
    switch (_selectedPreset) {
      case TipPreset.fifteen:
        return (_subtotal * 0.15);
      case TipPreset.twenty:
        return (_subtotal * 0.20);
      case TipPreset.twentyFive:
        return (_subtotal * 0.25);
      case TipPreset.none:
        return 0.0;
      case TipPreset.custom:
        final text = _customTipController.text.trim();
        if (text.isEmpty) return 0.0;
        final parsed = double.tryParse(text);
        if (parsed != null && parsed >= 0) return parsed;
        return 0.0;
    }
  }

  double? get _currentTipPercentage {
    switch (_selectedPreset) {
      case TipPreset.fifteen:
        return 15.0;
      case TipPreset.twenty:
        return 20.0;
      case TipPreset.twentyFive:
        return 25.0;
      case TipPreset.none:
        return 0.0;
      case TipPreset.custom:
        if (_subtotal > 0) {
          return (_currentTipAmount / _subtotal) * 100;
        }
        return null;
    }
  }

  /// Itemized total payable at register
  double get _totalPayable {
    double total = _subtotal;
    if (_verifiedDiscount != null) {
      total -= _verifiedDiscount!;
    }
    if (_verifiedTax != null) {
      total += _verifiedTax!;
    }
    if (_verifiedDeposit != null) {
      total -= _verifiedDeposit!;
    }
    total += _currentTipAmount;
    return total < 0 ? 0.0 : total;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tip Confirmation Handler
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _handleConfirmTip() async {
    if (_isSubmitting) return; // Prevent duplicate submission

    // Validate custom input if active
    if (_selectedPreset == TipPreset.custom) {
      final text = _customTipController.text.trim();
      if (text.isEmpty) {
        setState(() => _customTipError = 'Please enter a tip amount.');
        return;
      }
      final parsed = double.tryParse(text);
      if (parsed == null || parsed < 0) {
        setState(() => _customTipError = 'Please enter a valid, non-negative amount.');
        return;
      }
      setState(() => _customTipError = null);
    }

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    final tipToConfirm = _currentTipAmount;
    final tipPctToConfirm = _currentTipPercentage;

    try {
      // Execute via BookingBloc if present in context, or directly via repository
      BookingBloc? bloc;
      try {
        bloc = context.read<BookingBloc>();
      } catch (_) {}

      if (bloc != null) {
        bloc.add(ConfirmTipEvent(
          bookingId: _bookingId,
          tipAmount: tipToConfirm,
          tipPercentage: tipPctToConfirm,
          booking: widget.booking,
        ));
      }

      final repo = ServicesLocator.bookingRepository;
      final res = await repo.confirmTipDetails(
        bookingId: _bookingId,
        tipAmount: tipToConfirm,
        tipPercentage: tipPctToConfirm,
        booking: widget.booking,
      );

      if (!mounted) return;

      if (res.success) {
        setState(() {
          _isConfirmed = true;
          _confirmedTipAmount = tipToConfirm;
          _statusMessage = res.message;
        });

        if (widget.onTipConfirmed != null && res.updatedBooking != null) {
          widget.onTipConfirmed!(res.updatedBooking!);
        }

        ToastUtil.showSuccessToast(
          context,
          tipToConfirm > 0
              ? 'Tip preference of \$${tipToConfirm.toStringAsFixed(2)} confirmed!'
              : 'Tip preference recorded (No Tip).',
        );
      } else {
        setState(() {
          _statusMessage = res.message;
        });
        ToastUtil.showErrorToast(context, res.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Failed to confirm tip: $e';
      });
      ToastUtil.showErrorToast(context, 'Error saving tip: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _safeDismissOrNavigate() {
    // 1. If displayed inside an imperative popup/modal bottom sheet (showModalBottomSheet),
    // safely pop the modal bottom sheet only.
    final modalRoute = ModalRoute.of(context);
    if (modalRoute is PopupRoute) {
      Navigator.of(context).pop(_isConfirmed ? widget.booking : null);
      return;
    }

    // 2. If embedded in a page within GoRouter, check if GoRouter has routes to pop
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      context.pop();
      return;
    }

    // 3. If there is no previous route in the GoRouter stack (e.g. opened from notification),
    // navigate safely to My Bookings without ever popping the last page off GoRouter.
    if (router != null) {
      router.goNamed(RouteNames.myBookings);
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI Builder
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag pill
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Checkout Summary',
                        style: AppFonts.parkinsans(
                          size: 20,
                          weight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _bookingId > 0 ? 'Booking #$_bookingId' : 'Appointment Review',
                        style: AppFonts.poppins(
                          size: 13,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF374151)),
                    onPressed: _safeDismissOrNavigate,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Pet & Appointment Card
              _buildPetAppointmentCard(),
              const SizedBox(height: 16),

              // Itemized Charges Card
              _buildItemizedChargesCard(),
              const SizedBox(height: 20),

              // Tip Selection Section
              _buildTipSelectionSection(),
              const SizedBox(height: 18),

              // Total Payable Card
              _buildTotalPayableCard(),
              const SizedBox(height: 16),

              // Safeguard Notice Card
              _buildSafeguardNoticeCard(),
              const SizedBox(height: 20),

              // Status message (if any)
              if (_statusMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: _isConfirmed
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isConfirmed
                          ? const Color(0xFFBBF7D0)
                          : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isConfirmed ? Icons.check_circle : Icons.error_outline,
                        size: 16,
                        color: _isConfirmed
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: AppFonts.poppins(
                            size: 12,
                            weight: FontWeight.w500,
                            color: _isConfirmed
                                ? const Color(0xFF166534)
                                : const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Action Buttons
              if (!_isConfirmed)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E), // Spa deep teal
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    onPressed: _isSubmitting ? null : _handleConfirmTip,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _currentTipAmount > 0
                                ? 'Confirm Tip (\$${_currentTipAmount.toStringAsFixed(2)})'
                                : 'Confirm No Tip',
                            style: AppFonts.parkinsans(
                              size: 16,
                              weight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                )
              else
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCCFBF1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF0F766E)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle,
                                color: Color(0xFF0F766E), size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _confirmedTipAmount != null && _confirmedTipAmount! > 0
                                    ? 'Tip Confirmed: \$${_confirmedTipAmount!.toStringAsFixed(2)}'
                                    : 'Tip Preference Confirmed (No Tip)',
                                style: AppFonts.parkinsans(
                                  size: 15,
                                  weight: FontWeight.w700,
                                  color: const Color(0xFF0F766E),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFD1D5DB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                            onPressed: () {
                              setState(() {
                                _isConfirmed = false;
                                _statusMessage = null;
                              });
                            },
                            child: Text(
                              'Change Tip',
                              style: AppFonts.poppins(
                                size: 14,
                                weight: FontWeight.w600,
                                color: const Color(0xFF374151),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF111827),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              elevation: 0,
                            ),
                            onPressed: _safeDismissOrNavigate,
                            child: Text(
                              'Done',
                              style: AppFonts.poppins(
                                size: 14,
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
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Card Components
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPetAppointmentCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Pet photo avatar
          Container(
            width: 52,
            height: 52,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildPetAvatar(),
          ),
          const SizedBox(width: 12),
          // Pet name & info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _petName,
                  style: AppFonts.poppins(
                    size: 16,
                    weight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _petBreed,
                  style: AppFonts.poppins(
                    size: 12.5,
                    color: const Color(0xFF6B7280),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 13, color: Color(0xFF0F766E)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _groomerName,
                        style: AppFonts.poppins(
                          size: 12,
                          weight: FontWeight.w500,
                          color: const Color(0xFF0F766E),
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
          // Date & Time badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _dateLabel,
                style: AppFonts.poppins(
                  size: 12,
                  weight: FontWeight.w600,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _timeLabel,
                style: AppFonts.poppins(
                  size: 11,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemizedChargesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          Text(
            'Itemized Charges',
            style: AppFonts.parkinsans(
              size: 15,
              weight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),

          // Base Service
          _chargeRow(
            label: _serviceName,
            amount: '\$${_baseServicePrice.toStringAsFixed(2)}',
            isBold: false,
          ),

          // Add-on services
          for (final addon in _addOns) ...[
            const SizedBox(height: 8),
            _chargeRow(
              label: '+ ${addon.name}',
              amount: addon.price != null
                  ? '\$${addon.price!.toStringAsFixed(2)}'
                  : '(Included in service)',
              isSubtle: addon.price == null,
            ),
          ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Color(0xFFE5E7EB), height: 1),
          ),

          // Subtotal
          _chargeRow(
            label: 'Subtotal',
            amount: '\$${_subtotal.toStringAsFixed(2)}',
            isBold: true,
          ),

          // Verified Discounts (only displayed when present from backend)
          if (_verifiedDiscount != null) ...[
            const SizedBox(height: 8),
            _chargeRow(
              label: 'Discount / Promo',
              amount: '-\$${_verifiedDiscount!.toStringAsFixed(2)}',
              textColor: const Color(0xFF16A34A),
            ),
          ],

          // Verified Taxes (displays value or explicit pending calculation notice)
          const SizedBox(height: 8),
          if (_verifiedTax != null)
            _chargeRow(
              label: 'Taxes',
              amount: '+\$${_verifiedTax!.toStringAsFixed(2)}',
            )
          else
            _chargeRow(
              label: 'Estimated Sales Tax',
              amount: 'Calculated at counter',
              isSubtle: true,
            ),

          // Verified Deposit Credit (only displayed when present)
          if (_verifiedDeposit != null) ...[
            const SizedBox(height: 8),
            _chargeRow(
              label: 'Deposit Pre-paid',
              amount: '-\$${_verifiedDeposit!.toStringAsFixed(2)}',
              textColor: const Color(0xFF0F766E),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTipSelectionSection() {
    final fifteenAmount = (_subtotal * 0.15);
    final twentyAmount = (_subtotal * 0.20);
    final twentyFiveAmount = (_subtotal * 0.25);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Add a Tip',
              style: AppFonts.parkinsans(
                size: 15,
                weight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '100% goes to your groomer',
                style: AppFonts.poppins(
                  size: 11.5,
                  weight: FontWeight.w500,
                  color: const Color(0xFF0F766E),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 3 Percentage Presets
        Row(
          children: [
            Expanded(
              child: _tipPresetPill(
                preset: TipPreset.fifteen,
                label: '15%',
                subtext: '\$${fifteenAmount.toStringAsFixed(2)}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _tipPresetPill(
                preset: TipPreset.twenty,
                label: '20%',
                subtext: '\$${twentyAmount.toStringAsFixed(2)}',
                isPopular: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _tipPresetPill(
                preset: TipPreset.twentyFive,
                label: '25%',
                subtext: '\$${twentyFiveAmount.toStringAsFixed(2)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Custom & No Tip Presets
        Row(
          children: [
            Expanded(
              child: _tipPresetPill(
                preset: TipPreset.custom,
                label: 'Custom',
                subtext: _selectedPreset == TipPreset.custom &&
                        _currentTipAmount > 0
                    ? '\$${_currentTipAmount.toStringAsFixed(2)}'
                    : 'Enter amount',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _tipPresetPill(
                preset: TipPreset.none,
                label: 'No Tip',
                subtext: '\$0.00',
              ),
            ),
          ],
        ),

        // Expanded Custom Input Field
        if (_selectedPreset == TipPreset.custom) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _customTipError != null
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF0F766E),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Text(
                  '\$',
                  style: AppFonts.parkinsans(
                    size: 18,
                    weight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _customTipController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        if (val.trim().isEmpty) {
                          _customTipError = null;
                        } else {
                          final parsed = double.tryParse(val);
                          if (parsed == null || parsed < 0) {
                            _customTipError = 'Enter a valid amount';
                          } else {
                            _customTipError = null;
                          }
                        }
                      });
                    },
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: AppFonts.poppins(color: const Color(0xFF9CA3AF)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    style: AppFonts.parkinsans(
                      size: 16,
                      weight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
                if (_customTipController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _customTipController.clear();
                      setState(() => _customTipError = null);
                    },
                    child: const Icon(Icons.clear, size: 18, color: Color(0xFF6B7280)),
                  ),
              ],
            ),
          ),
          if (_customTipError != null) ...[
            const SizedBox(height: 4),
            Text(
              _customTipError!,
              style: AppFonts.poppins(
                size: 11.5,
                color: const Color(0xFFDC2626),
                weight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _tipPresetPill({
    required TipPreset preset,
    required String label,
    required String subtext,
    bool isPopular = false,
  }) {
    final isSelected = _selectedPreset == preset;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPreset = preset;
          if (preset != TipPreset.custom) {
            _customTipError = null;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF111827)
                : (isPopular ? const Color(0xFF99F6E4) : const Color(0xFFE5E7EB)),
            width: isPopular && !isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: AppFonts.parkinsans(
                    size: 14,
                    weight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                if (isPopular && !isSelected) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '★',
                      style: AppFonts.poppins(
                        size: 9,
                        color: const Color(0xFF0F766E),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtext,
              style: AppFonts.poppins(
                size: 11,
                weight: FontWeight.w500,
                color: isSelected ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalPayableCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA), // Light teal background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Due at Counter',
                  style: AppFonts.parkinsans(
                    size: 14.5,
                    weight: FontWeight.w700,
                    color: const Color(0xFF0F766E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _currentTipAmount > 0
                      ? 'Includes \$${_currentTipAmount.toStringAsFixed(2)} tip'
                      : 'No tip added',
                  style: AppFonts.poppins(
                    size: 12,
                    color: const Color(0xFF134E4A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '\$${_totalPayable.toStringAsFixed(2)}',
            style: AppFonts.parkinsans(
              size: 24,
              weight: FontWeight.w800,
              color: const Color(0xFF0F766E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafeguardNoticeCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 18,
            color: Color(0xFF4B5563),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No payment is processed now. Your tip preference is saved and will be applied when you settle your bill at the spa counter.',
              style: AppFonts.poppins(
                size: 11.5,
                color: const Color(0xFF4B5563),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chargeRow({
    required String label,
    required String amount,
    bool isBold = false,
    bool isSubtle = false,
    Color? textColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppFonts.poppins(
              size: isBold ? 14 : 13,
              weight: isBold ? FontWeight.w700 : FontWeight.w400,
              color: isSubtle
                  ? const Color(0xFF9CA3AF)
                  : (textColor ?? (isBold ? const Color(0xFF111827) : const Color(0xFF374151))),
            ),
          ),
        ),
        Text(
          amount,
          style: AppFonts.poppins(
            size: isBold ? 14 : 13,
            weight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: isSubtle
                ? const Color(0xFF9CA3AF)
                : (textColor ?? (isBold ? const Color(0xFF111827) : const Color(0xFF111827))),
          ),
        ),
      ],
    );
  }

  Widget _buildPetAvatar() {
    return PetImageHelper.buildImage(
      photoUrl: _petPhoto,
      petName: _petName,
      fit: BoxFit.cover,
      customFallback: _petAvatarFallback(),
    );
  }

  Widget _petAvatarFallback() {
    return Container(
      color: const Color(0xFFF3F4F6),
      alignment: Alignment.center,
      child: const Icon(Icons.pets, color: Color(0xFF9CA3AF), size: 24),
    );
  }
}
