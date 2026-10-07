import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model for onboarding pages
// ─────────────────────────────────────────────────────────────────────────────
class _OnboardPage {
  final String image;
  final String title;
  final String buttonLabel;

  const _OnboardPage({
    required this.image,
    required this.title,
    required this.buttonLabel,
  });
}

const _kPages = <_OnboardPage>[
  _OnboardPage(
    image: 'assets/images/splash/group2.png',
    title: 'Booking made simple',
    buttonLabel: 'Next',
  ),
  _OnboardPage(
    image: 'assets/images/splash/splash2_dog.png',
    title: "Every pet, every breed,\nwe've got you",
    buttonLabel: 'Next',
  ),
  _OnboardPage(
    image: 'assets/images/splash/splash3_dog.png',
    title: "Track your pet's\ngrooming history",
    buttonLabel: 'Get Started',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Splash / Onboarding Screens
// ─────────────────────────────────────────────────────────────────────────────
class SplashScreensMobile extends StatefulWidget {
  const SplashScreensMobile({super.key});

  @override
  State<SplashScreensMobile> createState() => _SplashScreensMobileState();
}

class _SplashScreensMobileState extends State<SplashScreensMobile>
    with TickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _current = 0;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    _buildAnim();
  }

  void _buildAnim() {
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_current < _kPages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOut,
      );
    } else {
      context.goNamed(RouteNames.login);
    }
  }

  void _onPageChanged(int index) {
    setState(() => _current = index);
    _fadeCtrl
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final w = size.width;
    final h = size.height;

    // ─────────────────────────────────────────────────────────────────────────
    // Pixel-perfect measurements from Figma 390 × 844 reference:
    // ─────────────────────────────────────────────────────────────────────────

    // White dome panel:
    // Sides start at 609px (72.16% h) and peak at 577px (68.36% h) -> dome height = 32px
    final double domeH = h * (32.0 / 844.0);
    final double panelSidesTop = h * (609.0 / 844.0);
    final double panelPeakTop = panelSidesTop - domeH; // 577px on 844h

    // Illustration in sky: starts at ~290px, height ~320px (extends behind dome)
    final double imgTop = h * (290.0 / 844.0);
    final double imgHeight = h * (320.0 / 844.0);

    // Logo: 152 × 85 px, top at 107px (12.68% h)
    const double logoW = 152.0;
    const double logoH = 85.0;
    final double logoTop = h * (107.0 / 844.0);

    // Title: starts at 657px (77.84% h)
    final double titleTop = h * (657.0 / 844.0);

    // Next / Get Started button:
    const double btnWidth = 260.0;
    const double btnHeight = 49.0;
    final double btnBottom = h * (68.0 / 844.0);

    // Skip button:
    final double skipTop = pad.top > 0 ? pad.top + 16 : h * (64.0 / 844.0);
    const double skipRight = 16.0;

    final page = _kPages[_current];

    return Scaffold(
      backgroundColor: const Color(0xFF8DC8E8),
      body: Stack(
        children: [
          // ── 1. Sky & clouds full-bleed background (no wash out overlay) ──
          Positioned.fill(
            child: Image.asset(
              'assets/images/common/welcome_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) =>
                  const ColoredBox(color: Color(0xFF8DC8E8)),
            ),
          ),

          // ── 2. Swipe detector ──────────────────────────────────────────
          PageView.builder(
            controller: _pageCtrl,
            onPageChanged: _onPageChanged,
            itemCount: _kPages.length,
            itemBuilder: (ctx, idx) => const SizedBox.expand(),
          ),

          // ── 3. Illustration in sky (extends behind dome) ───────────────
          Positioned(
            left: 0,
            right: 0,
            top: imgTop,
            height: imgHeight,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Image.asset(
                  page.image,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  errorBuilder: (ctx, err, st) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),

          // ── 4. White dome panel (curves over illustration's bottom) ────
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

          // ── 5. Logo at the top ─────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            top: logoTop,
            child: Center(
              child: SvgPicture.asset(
                'assets/images/common/logo.svg',
                width: logoW,
                height: logoH,
                errorBuilder: (ctx, err, st) =>
                    const SizedBox(width: logoW, height: logoH),
              ),
            ),
          ),

          // ── 6. Title text inside white dome ───────────────────────────
          Positioned(
            left: 24,
            right: 24,
            top: titleTop,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Text(
                  page.title,
                  textAlign: TextAlign.center,
                  style: AppFonts.parkinsans(
                    size: 26,
                    weight: FontWeight.w700,
                    height: 1.2,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),

          // ── 7. Next / Get Started button ──────────────────────────────
          Positioned(
            left: (w - btnWidth) / 2,
            bottom: btnBottom,
            child: GestureDetector(
              onTap: _onNext,
              child: Container(
                width: btnWidth,
                height: btnHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3A3A3A), Color(0xFF000000)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(60),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    page.buttonLabel,
                    key: ValueKey(page.buttonLabel),
                    style: AppFonts.parkinsans(
                      size: 18,
                      weight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── 8. Skip button ────────────────────────────────────────────
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
// Clipper for dome arch
// ─────────────────────────────────────────────────────────────────────────────
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
