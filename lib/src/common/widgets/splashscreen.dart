import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';

/// App launch splash — shown for 2 s.
/// Figma frame: 390 × 844
///   Background: welcome_bg.png  (fills screen behind 60 % white overlay)
///   Logo: logo.svg  258 × 145  centered, fades + scales in
///   Status bar: transparent (white icons)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final _log = Logger();
  late final AnimationController _ctrl;
  late final Animation<double>   _fade;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();

    // Force white status-bar icons so they show on the light background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor           : Colors.transparent,
      statusBarIconBrightness  : Brightness.dark,
      statusBarBrightness      : Brightness.light,
    ));

    _ctrl = AnimationController(
      vsync   : this,
      duration: const Duration(milliseconds: 900),
    );

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.82, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    _ctrl.forward();

    // Navigate after 2.4 s (gives the animation time to finish + brief hold)
    Timer(const Duration(milliseconds: 2400), _navigate);
  }

  void _navigate() {
    if (!mounted) return;

    if (ServicesLocator.sessionService.isGroomerLoggedIn) {
      final groomer = ServicesLocator.groomerAuthRepository.getCurrentGroomer();
      if (groomer != null) {
        _log.d('SplashScreen::_navigate::Groomer session active (${groomer.fullName})');
        if (groomer.mustChangePassword) {
          context.goNamed(RouteNames.groomerRegister);
        } else {
          context.goNamed(RouteNames.groomerHome);
        }
        return;
      }
    }

    _log.d('SplashScreen::_navigate::isLoggedIn='
        '${ServicesLocator.sessionService.isLoggedIn}');
    if (ServicesLocator.sessionService.isLoggedIn) {
      context.goNamed(RouteNames.home);
    } else {
      context.goNamed(RouteNames.welcome);
    }
  }


  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background texture ────────────────────────────────────────
          Image.asset(
            'assets/images/common/welcome_bg.png',
            width : size.width,
            height: size.height,
            fit   : BoxFit.cover,
            errorBuilder: (ctx, err, st) => const ColoredBox(color: Colors.white),
          ),
          // 60 % white overlay — keeps background subtle, logo pops
          const ColoredBox(color: Color(0x99FFFFFF)),

          // ── Logo (fade + gentle scale) ────────────────────────────────
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: SvgPicture.asset(
                  'assets/images/common/logo.svg',
                  width : 224,
                  height: 126,
                  errorBuilder: (ctx, err, st) => const SizedBox(width: 224, height: 126),
                ),
              ),
            ),
          ),

          // ── Tagline (fades in slightly after logo) ────────────────────
          Positioned(
            left  : 0,
            right : 0,
            bottom: 60,
            child : FadeTransition(
              opacity: _fade,
              child  : const Text(
                "Arlington's #1 Pet Grooming Booking APP",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize  : 13,
                  fontWeight: FontWeight.w400,
                  color     : Color(0xFF6B7280),
                  height    : 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
