import 'package:flutter/material.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';

/// Booking step progress bar matching the Figma design:
/// four 5px-tall rounded segments with a "Step X of 4" label.
class BookingProgress extends StatelessWidget {
  final int step;
  final String label;

  const BookingProgress({super.key, required this.step, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (int i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < step ? Colors.black : const Color(0xFFDADADA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.poppins(size: 14, weight: FontWeight.w400, height: 16 / 14),
        ),
      ],
    );
  }
}
