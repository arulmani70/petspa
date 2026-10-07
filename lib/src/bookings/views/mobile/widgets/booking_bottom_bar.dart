import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';

/// Sticky bottom bar for the booking flow (Group 76062 @ (0,673) 390x182):
/// a grey summary pill + a full-width black Continue pill.
class BookingBottomBar extends StatelessWidget {
  final String summary;
  final VoidCallback? onContinue;
  final bool loading;
  final FontWeight summaryWeight;

  const BookingBottomBar({
    super.key,
    required this.summary,
    this.onContinue,
    this.loading = false,
    this.summaryWeight = FontWeight.w400,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(17, 17, 17, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 39,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.poppins(size: 14, weight: summaryWeight),
                  ),
                ),
                const SizedBox(width: 8),
                SvgPicture.asset(
                  'assets/images/bookings/fi_711239_1_1520.svg',
                  width: 17,
                  height: 17,
                  colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.search, size: 17, color: Colors.black),
                ),
              ],
            ),
          ),
          const SizedBox(height: 17),
          GestureDetector(
            onTap: onContinue,
            child: Container(
              width: double.infinity,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3A3A3A), Colors.black],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Continue',
                      style: AppFonts.parkinsans(size: 18, weight: FontWeight.w700, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
