import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';

class OfferDetailsDialog extends StatelessWidget {
  final String imagePath;
  final String badgeText;
  final String title;
  final String timerText;
  final String promoCode;
  final String description;
  final String eligibleServices;
  final String termsConditions;
  final VoidCallback? onClaim;

  const OfferDetailsDialog({
    super.key,
    this.imagePath = 'assets/images/common/offer_1.png',
    this.badgeText = '50% OFF',
    this.title = '50% Off Full Grooming for\nNew Pets!',
    this.timerText = 'Ends in 2 days 14:32:10',
    this.promoCode = 'PAWSOME50',
    this.description =
        "Get 50% off your pet's first Full Grooming session with us. A perfect way to try the royal treatment your pet deserves.",
    this.eligibleServices = 'Full Grooming, Spa Package',
    this.termsConditions =
        'Valid for first-time customers only · Cannot be combined with other offers · Limit one redemption per pet · Valid at Shear Heaven Pet Spa, Calicut only.',
    this.onClaim,
  });

  static Future<void> show(
    BuildContext context, {
    String imagePath = 'assets/images/common/offer_1.png',
    String badgeText = '50% OFF',
    String title = '50% Off Full Grooming for\nNew Pets!',
    String timerText = 'Ends in 2 days 14:32:10',
    String promoCode = 'PAWSOME50',
    String description =
        "Get 50% off your pet's first Full Grooming session with us. A perfect way to try the royal treatment your pet deserves.",
    String eligibleServices = 'Full Grooming, Spa Package',
    String termsConditions =
        'Valid for first-time customers only · Cannot be combined with other offers · Limit one redemption per pet · Valid at Shear Heaven Pet Spa, Calicut only.',
    VoidCallback? onClaim,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) => OfferDetailsDialog(
        imagePath: imagePath,
        badgeText: badgeText,
        title: title,
        timerText: timerText,
        promoCode: promoCode,
        description: description,
        eligibleServices: eligibleServices,
        termsConditions: termsConditions,
        onClaim: onClaim,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      elevation: 0,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Image + Close Button + Discount Badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    child: imagePath.startsWith('http')
                        ? Image.network(
                            imagePath,
                            height: 230,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 230,
                              color: Colors.grey.shade300,
                              child: const Center(
                                child: Icon(Icons.image, color: Colors.grey),
                              ),
                            ),
                          )
                        : Image.asset(
                            imagePath,
                            height: 230,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 230,
                              color: Colors.grey.shade300,
                              child: const Center(
                                child: Icon(Icons.image, color: Colors.grey),
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFE5E5EA),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    bottom: -18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: AppFonts.parkinsans(
                          size: 15,
                          weight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Title
                    Text(
                      title,
                      style: AppFonts.parkinsans(
                        size: 22,
                        weight: FontWeight.w700,
                        color: Colors.black,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Countdown Tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Color(0xFFC62828),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            timerText,
                            style: AppFonts.poppins(
                              size: 12,
                              weight: FontWeight.w600,
                              color: const Color(0xFFC62828),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    // Promocode dashed container
                    CustomPaint(
                      painter: DashedRectPainter(
                        color: const Color(0xFFCCCCCC),
                        radius: 12.0,
                        strokeWidth: 1.2,
                        dash: 6.0,
                        gap: 4.0,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'PROMOCODE',
                                    style: AppFonts.poppins(
                                      size: 11,
                                      weight: FontWeight.w500,
                                      color: const Color(0xFF757575),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      promoCode,
                                      style: AppFonts.parkinsans(
                                        size: 22,
                                        weight: FontWeight.w800,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: promoCode),
                                );
                                ToastUtil.showSuccessToast(
                                  context,
                                  'Promo code copied to clipboard!',
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.copy_outlined,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'COPY',
                                      style: AppFonts.poppins(
                                        size: 13,
                                        weight: FontWeight.w600,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Description
                    Text(
                      description,
                      style: AppFonts.poppins(
                        size: 14,
                        weight: FontWeight.w400,
                        color: const Color(0xFF1E1E1E),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Eligible services
                    Text(
                      'Eligible services',
                      style: AppFonts.parkinsans(
                        size: 16,
                        weight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      eligibleServices,
                      style: AppFonts.poppins(
                        size: 14,
                        weight: FontWeight.w400,
                        color: const Color(0xFF222222),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Terms & conditions
                    Text(
                      'Terms & conditions',
                      style: AppFonts.parkinsans(
                        size: 16,
                        weight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      termsConditions,
                      style: AppFonts.poppins(
                        size: 13.5,
                        weight: FontWeight.w400,
                        color: const Color(0xFF757575),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Claim Offer Button
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        if (onClaim != null) {
                          onClaim!();
                        } else {
                          Clipboard.setData(ClipboardData(text: promoCode));
                          ServicesLocator.bookingDraft.applyOffer({
                            'promoCode': promoCode,
                            'title': title,
                            'description': description,
                            'badgeText': badgeText,
                          });
                          ToastUtil.showSuccessToast(
                            context,
                            'Promo $promoCode applied!',
                          );
                          context.pushNamed(RouteNames.bookingService);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141414),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: Text(
                            'Claim Offer',
                            style: AppFonts.parkinsans(
                              size: 17,
                              weight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dash;
  final double radius;

  DashedRectPainter({
    this.color = Colors.black,
    this.strokeWidth = 1.0,
    this.gap = 5.0,
    this.dash = 5.0,
    this.radius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    Path path = Path()..addRRect(rrect);

    Path dashPath = Path();
    double distance = 0.0;
    for (ui.PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dash),
          Offset.zero,
        );
        distance += dash + gap;
      }
      distance = 0.0;
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
