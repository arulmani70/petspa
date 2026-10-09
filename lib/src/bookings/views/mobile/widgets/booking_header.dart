import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/widgets/booking_progress.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';

/// White app bar + booking progress header matching the Figma booking
/// flow screens (Rectangle 153 @ (0,47) 390x67, segments @ (17,139)).
class BookingHeader extends StatelessWidget {
  final String title;
  final int step;
  final String subtitle;
  final VoidCallback? onBack;

  const BookingHeader({
    super.key,
    required this.title,
    required this.step,
    required this.subtitle,
    this.onBack,
  });

  void _handleBack(BuildContext context) {
    if (onBack != null) {
      onBack!();
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    switch (step) {
      case 2:
        context.goNamed(RouteNames.petSelect);
        break;
      case 3:
        context.goNamed(RouteNames.bookingService);
        break;
      case 4:
        context.goNamed(RouteNames.bookingDateTime);
        break;
      default:
        context.goNamed(RouteNames.home);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 10, 17, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                icon: const Icon(Icons.arrow_back, size: 24, color: Colors.black),
                onPressed: () => _handleBack(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.parkinsans(size: 20, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          BookingProgress(
            step: step,
            label: subtitle,
          ),
        ],
      ),
    );
  }
}
