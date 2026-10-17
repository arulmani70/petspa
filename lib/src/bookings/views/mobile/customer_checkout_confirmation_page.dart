import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/app/routes.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/widgets/customer_checkout_summary_sheet.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';

/// Full-page Customer Checkout Confirmation Screen.
///
/// Deep-link and notification destination for "Ready for Checkout" alerts.
/// Features:
/// 1. Takes [bookingId] and loads freshest booking & financial details from backend API.
/// 2. Gracefully handles missing booking ID with safe fallback.
/// 3. Gracefully handles unauthenticated / expired customer sessions.
/// 4. Validates eligibility: if booking is already completed or cancelled, presents clear status & options.
/// 5. Embeds itemized service fee, sales tax (authentic/pending), tip selection, and total.
/// 6. Allows customer to review & confirm tip, updating backend and groomer real-time view.
/// 7. PopScope and safe Back navigation returning to My Bookings if root route.
class CustomerCheckoutConfirmationPage extends StatefulWidget {
  final int? bookingId;
  final Map<String, dynamic>? initialBookingData;

  const CustomerCheckoutConfirmationPage({
    super.key,
    this.bookingId,
    this.initialBookingData,
  });

  @override
  State<CustomerCheckoutConfirmationPage> createState() =>
      _CustomerCheckoutConfirmationPageState();
}

class _CustomerCheckoutConfirmationPageState
    extends State<CustomerCheckoutConfirmationPage> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _bookingData;

  @override
  void initState() {
    super.initState();
    if (widget.initialBookingData != null &&
        widget.initialBookingData!.isNotEmpty &&
        (widget.initialBookingData!['serviceName'] != null ||
            widget.initialBookingData!['totalPrice'] != null ||
            widget.initialBookingData!['petName'] != null)) {
      _bookingData = Map<String, dynamic>.from(widget.initialBookingData!);
      _isLoading = false;
    }
    _fetchLatestDetails();
  }

  int? get _resolvedBookingId {
    if (widget.bookingId != null && widget.bookingId! > 0) {
      return widget.bookingId;
    }
    final raw = widget.initialBookingData?['bookingId'] ??
        widget.initialBookingData?['id'] ??
        widget.initialBookingData?['booking_id'];
    if (raw is int) return raw;
    return raw != null ? int.tryParse(raw.toString()) : null;
  }

  Future<void> _fetchLatestDetails() async {
    final bId = _resolvedBookingId;
    if (bId == null || bId <= 0) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Booking ID is missing. Unable to load checkout confirmation.';
        });
      }
      return;
    }

    // Check session
    final session = ServicesLocator.sessionService;
    if (!session.isLoggedIn) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'session_expired';
        });
      }
      return;
    }

    try {
      final repo = ServicesLocator.bookingRepository;
      final latest = await repo.getCheckoutConfirmationDetails(bId);

      if (!mounted) return;

      if (latest != null && latest.isNotEmpty) {
        setState(() {
          _bookingData = latest;
          _isLoading = false;
          _errorMessage = null;
        });
      } else if (_bookingData != null) {
        // Keep initial data if backend call returned null
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Booking #$bId was not found or is no longer available.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (_bookingData != null) {
        setState(() => _isLoading = false);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load booking details: $e';
        });
      }
    }
  }


  void _navigateBack(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      context.pop();
    } else {
      _navigateToMyBookings(context);
    }
  }

  void _navigateToMyBookings(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.goNamed(RouteNames.myBookings);
    }
  }

  void _navigateToReceipt(BuildContext context, Map<String, dynamic> data) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.pushNamed(RouteNames.bookingReceipt, extra: data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _navigateBack(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF111827), size: 22),
            onPressed: () => _navigateBack(context),
          ),
          title: Text(
            'Checkout Confirmation',
            style: AppFonts.parkinsans(
              size: 19,
              weight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF4B5563), size: 22),
              tooltip: 'Refresh',
              onPressed: () {
                setState(() => _isLoading = true);
                _fetchLatestDetails();
              },
            ),
          ],
        ),
        body: SafeArea(
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final bId = _resolvedBookingId;

    // 1. Missing Booking ID
    if (bId == null || bId <= 0) {
      return _buildFallbackCard(
        icon: Icons.error_outline_rounded,
        iconColor: const Color(0xFFEF4444),
        title: 'Missing Booking Information',
        message: 'No booking ID was provided with this notification. Please locate your appointment in My Bookings.',
        primaryButtonText: 'Go to My Bookings',
        onPrimaryPressed: () => _navigateToMyBookings(context),
      );
    }

    // 2. Session Expired / Not Logged In
    if (_errorMessage == 'session_expired') {
      return _buildFallbackCard(
        icon: Icons.lock_outline_rounded,
        iconColor: const Color(0xFFF59E0B),
        title: 'Sign In Required',
        message: 'Your customer session has expired or you are not signed in. Please log in to confirm your checkout for Booking #$bId.',
        primaryButtonText: 'Log In',
        onPrimaryPressed: () => Routes.redirectToLogin(isGroomer: false),
      );
    }

    // 3. Loading
    if (_isLoading && _bookingData == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading checkout details...',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
            ),
          ],
        ),
      );
    }

    // 4. Generic error / Not found
    if (_errorMessage != null && _bookingData == null) {
      return _buildFallbackCard(
        icon: Icons.search_off_rounded,
        iconColor: const Color(0xFF6B7280),
        title: 'Booking Unavailable',
        message: _errorMessage!,
        primaryButtonText: 'Try Again',
        onPrimaryPressed: () {
          setState(() => _isLoading = true);
          _fetchLatestDetails();
        },
        secondaryButtonText: 'Go to My Bookings',
        onSecondaryPressed: () => _navigateToMyBookings(context),
      );
    }

    // 5. Ineligibility checks on loaded booking data
    final data = _bookingData ?? widget.initialBookingData ?? <String, dynamic>{};
    final status = (data['status'] ?? data['bookingStatus'] ?? data['serviceStage'] ?? '')
        .toString()
        .toLowerCase();
    final isCompleted = status == 'completed' ||
        status == 'checkout_completed' ||
        status == 'paid' ||
        data['isCompleted'] == true ||
        data['isPaid'] == true;
    final isCancelled = status == 'cancelled' ||
        status == 'canceled' ||
        status == 'rejected';

    if (isCompleted) {
      return _buildFallbackCard(
        icon: Icons.check_circle_outline_rounded,
        iconColor: const Color(0xFF10B981),
        title: 'Checkout Already Completed',
        message: 'Booking #$bId has already been completed by the groomer. You can review your verified invoice and receipt below.',
        primaryButtonText: 'View Receipt & Invoice',
        onPrimaryPressed: () => _navigateToReceipt(context, data),
        secondaryButtonText: 'Go to My Bookings',
        onSecondaryPressed: () => _navigateToMyBookings(context),
      );
    }

    if (isCancelled) {
      return _buildFallbackCard(
        icon: Icons.cancel_outlined,
        iconColor: const Color(0xFFEF4444),
        title: 'Booking Cancelled',
        message: 'Booking #$bId was cancelled and is no longer eligible for checkout confirmation.',
        primaryButtonText: 'Go to My Bookings',
        onPrimaryPressed: () => _navigateToMyBookings(context),
      );
    }

    // 6. Eligible and ready for checkout: Embed CustomerCheckoutSummarySheet
    return RefreshIndicator(
      color: const Color(0xFF0F766E),
      onRefresh: _fetchLatestDetails,
      child: CustomerCheckoutSummarySheet(
        booking: data,
        onTipConfirmed: (updated) {
          setState(() {
            _bookingData = updated;
          });
        },
      ),
    );
  }

  Widget _buildFallbackCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String primaryButtonText,
    required VoidCallback onPrimaryPressed,
    String? secondaryButtonText,
    VoidCallback? onSecondaryPressed,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFF3F4F6), width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 34),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppFonts.parkinsans(
                  size: 19,
                  weight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppFonts.poppins(
                  size: 13.5,
                  weight: FontWeight.w400,
                  color: const Color(0xFF4B5563),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  onPressed: onPrimaryPressed,
                  child: Text(
                    primaryButtonText,
                    style: AppFonts.poppins(
                      size: 14,
                      weight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (secondaryButtonText != null && onSecondaryPressed != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: onSecondaryPressed,
                    child: Text(
                      secondaryButtonText,
                      style: AppFonts.poppins(
                        size: 14,
                        weight: FontWeight.w600,
                        color: const Color(0xFF374151),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
