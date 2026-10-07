import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';

class WelcomePageMobile extends StatefulWidget {
  const WelcomePageMobile({super.key});

  @override
  State<WelcomePageMobile> createState() => _WelcomePageMobileState();
}

class _WelcomePageMobileState extends State<WelcomePageMobile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final w = size.width;
    final h = size.height;

    // ─────────────────────────────────────────────────────────────────────────
    // Pixel-perfect measurements extracted directly from 390 × 844 reference:
    // ─────────────────────────────────────────────────────────────────────────

    // White dome panel:
    // Sides start at 554px (65.64% h) and peak at 522px (61.85% h) -> dome height = 32px
    final double domeH = h * (32.0 / 844.0);
    final double panelSidesTop = h * (554.0 / 844.0);
    final double panelPeakTop = panelSidesTop - domeH; // 522px on 844h

    // Dog: starts at 298px (35.31% h), height ~260px (extends behind white dome)
    final double dogTop = h * (298.0 / 844.0);
    final double dogHeight = h * (260.0 / 844.0);

    // Logo: starts at 107px (12.68% h), 152 × 85 px
    const double logoW = 152.0;
    const double logoH = 85.0;
    final double logoTop = h * (107.0 / 844.0);

    // Text block: starts at 582px (68.96% h)
    final double textTop = h * (582.0 / 844.0);

    // Arrow button: circle starts at 701px, bottom at 768px (76px from bottom)
    const double btnSize = 68.0;
    final double btnBottomInset = h * (76.0 / 844.0);

    // Skip button: status bar + 16 (or 64px on 844h)
    final double skipTop = pad.top > 0 ? pad.top + 16 : h * (64.0 / 844.0);
    const double skipRight = 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFF8DC8E8),
      body: Stack(
        children: [
          // ── 1. Background: sky & clouds full-bleed ──
          Positioned.fill(
            child: Image.asset(
              'assets/images/common/welcome_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (ctx, e, st) =>
                  const ColoredBox(color: Color(0xFF8DC8E8)),
            ),
          ),

          // ── 2. Dog image (placed in sky; bottom extends behind the dome) ──
          Positioned(
            left: 0,
            right: 0,
            top: dogTop,
            height: dogHeight,
            child: FadeTransition(
              opacity: _fade,
              child: Image.asset(
                'assets/images/splash/welcome_dog.png',
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                errorBuilder: (ctx, e, st) => const SizedBox.shrink(),
              ),
            ),
          ),

          // ── 3. White dome panel (curves over the dog's bottom with exact radius) ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: panelPeakTop,
            child: ClipPath(
              clipper: _DomeClipper(domeH),
              child: const ColoredBox(color: Colors.white),
            ),
          ),

          // ── 4. Logo at the top ──
          Positioned(
            left: 0,
            right: 0,
            top: logoTop,
            child: FadeTransition(
              opacity: _fade,
              child: Center(
                child: SvgPicture.asset(
                  'assets/images/common/logo.svg',
                  width: logoW,
                  height: logoH,
                  errorBuilder: (ctx, e, st) =>
                      const SizedBox(width: logoW, height: logoH),
                ),
              ),
            ),
          ),

          // ── 5. Welcome title + subtitle ──
          Positioned(
            left: 0,
            right: 0,
            top: textTop,
            child: SlideTransition(
              position: _slide,
              child: FadeTransition(
                opacity: _fade,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Welcome to\nShear Heaven Pet Spa',
                        textAlign: TextAlign.center,
                        style: AppFonts.parkinsans(
                          size: 26,
                          weight: FontWeight.w700,
                          height: 1.2,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: AppFonts.poppins(
                            size: 15,
                            weight: FontWeight.w400,
                            color: const Color(0xFF374151),
                            height: 1.4,
                          ),
                          children: const [
                            TextSpan(text: "Arlington's "),
                            TextSpan(
                              text: '#1',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: ' Pet Grooming Booking APP'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── 6. Pulsing black circular button ──
          Positioned(
            left: (w - btnSize) / 2,
            bottom: btnBottomInset,
            child: _PulseButton(
              onTap: () => context.goNamed(RouteNames.splash),
              child: Container(
                width: btnSize,
                height: btnSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF111827),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'assets/images/splash/fi_271226_1_52.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                  errorBuilder: (ctx, e, st) => const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),

          // ── 7. Skip pill button ──
          Positioned(
            top: skipTop,
            right: skipRight,
            child: GestureDetector(
              onTap: () => context.goNamed(RouteNames.home),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: const Color(0xFF111827),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  'Skip',
                  style: AppFonts.poppins(
                    size: 12,
                    weight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Clippers
// ─────────────────────────────────────────────────────────────────────────────

/// White panel — convex dome at top.
/// Sides sit at y = domeH; center peaks at y = 0 (top edge of widget).
///
/// Quadratic bézier:
/// - Start: (0, domeH)
/// - Control: (width / 2, -domeH)
/// - End: (width, domeH)
///
/// Midpoint at t=0.5:
///   peak_y = 0.25 * domeH + 0.5 * (-domeH) + 0.25 * domeH = 0
/// This matches the exact 32px dome arch curve from Figma.
class _DomeClipper extends CustomClipper<Path> {
  final double domeH;
  const _DomeClipper(this.domeH);

  @override
  Path getClip(Size s) {
    final p = Path()
      ..moveTo(0, s.height)
      ..lineTo(0, domeH)
      ..quadraticBezierTo(s.width / 2, -domeH, s.width, domeH)
      ..lineTo(s.width, s.height)
      ..close();
    return p;
  }

  @override
  bool shouldReclip(_DomeClipper o) => o.domeH != domeH;
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing button
// ─────────────────────────────────────────────────────────────────────────────

class _PulseButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PulseButton({required this.child, required this.onTap});

  @override
  State<_PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<_PulseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.065)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(scale: _scale, child: widget.child),
      );
}
