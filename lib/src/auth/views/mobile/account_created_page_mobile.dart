import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/auth_pill_field.dart';

class AccountCreatedPageMobile extends StatelessWidget {
  const AccountCreatedPageMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FD),
      body: Stack(
        children: [
          // ── Background image: sky & clouds ──
          Positioned.fill(
            child: Image.asset(
              'assets/images/common/welcome_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const ColoredBox(color: Color(0xFFF0F8FD)),
            ),
          ),
          // ── Gradient overlay matching the design ──
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.70),
                    Colors.white.withValues(alpha: 0.55),
                    Colors.white.withValues(alpha: 0.75),
                    Colors.white.withValues(alpha: 0.90),
                  ],
                  stops: const [0.0, 0.35, 0.70, 1.0],
                ),
              ),
            ),
          ),

          // ── Content ──
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 36),

                  // ── Top Logo ──
                  SvgPicture.asset(
                    'assets/images/common/logo.svg',
                    width: 146,
                    height: 82,
                  ),
                  const SizedBox(height: 36),

                  // ── Pug Dog Celebrating Illustration ("Success!") ──
                  Image.asset(
                    'assets/images/auth/account_success_dog.png',
                    width: 180,
                    height: 240,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 180,
                      height: 240,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.pets,
                        size: 80,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Title: "You're all set" ──
                  Text(
                    "You're all set",
                    textAlign: TextAlign.center,
                    style: AppFonts.parkinsans(
                      size: 22,
                      weight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Subtitle ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      "Your account is verified. Add your pet's details anytime before booking an appointment.",
                      textAlign: TextAlign.center,
                      style: AppFonts.poppins(
                        size: 14,
                        weight: FontWeight.w400,
                        color: const Color(0xFF374151),
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // ── Continue Button ──
                  BlackPillButton(
                    label: 'Continue',
                    onTap: () => context.goNamed(RouteNames.home),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
