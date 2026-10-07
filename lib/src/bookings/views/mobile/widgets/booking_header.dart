import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/widgets/booking_progress.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';

/// White app bar + booking progress header matching the Figma booking
/// flow screens (Rectangle 153 @ (0,47) 390x67, segments @ (17,139)).
class BookingHeader extends StatelessWidget {
  final String title;
  final int step;
  final String subtitle;

  const BookingHeader({
    super.key,
    required this.title,
    required this.step,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(17, 14, 17, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.goNamed('home');
                  }
                },
                child: const Icon(Icons.arrow_back, size: 21, color: Colors.black),
              ),
              const SizedBox(width: 16),
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
