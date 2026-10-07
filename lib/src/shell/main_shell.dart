import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/network_status_widget.dart';

/// Floating pill bottom dock matching the Figma "Group 75900" design.
///
/// Figma spec (Group 75900 @ app (18,732)):
///  - Pill (Rectangle 32): 355x78, radius ~39, white @ 0.6, background blur 30,
///    drop shadow black @ 0.1 blur 10, white @ 0.6 1px border.
///  - Center button (Rectangle 33): 56x55 radius 27.5, #3A3A3A -> black gradient,
///    white scissors icon 24x24.
///  - Selected tab: 50x50 rounded square (radius 16) with the dark gradient,
///    white icon — rounder than Figma's Rectangle 36/37/34 (radius ~10) while
///    keeping the rounded-square shape distinct from the center circle.
class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  static const LinearGradient _darkGradient = LinearGradient(
    colors: [Color(0xFF3A3A3A), Colors.black],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: NetworkStatusWidget(child: navigationShell),
      extendBody: true,
      bottomNavigationBar: keyboardOpen
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(17.5, 0, 17.5, 34),
              child: Container(
                height: 78,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(39),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(39),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
              child: Container(
                height: 78,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(39),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    _buildItem(
                      context,
                      index: 0,
                      child: const Icon(Icons.home_rounded, size: 30),
                    ),
                    _buildItem(
                      context,
                      index: 1,
                      child: const Icon(Icons.pets_rounded, size: 28),
                    ),
                    _buildItem(
                      context,
                      index: 2,
                      child: const Icon(Icons.chat_bubble_outline, size: 28),
                    ),
                    _buildItem(
                      context,
                      index: 3,
                      child: const Icon(Icons.calendar_month_outlined, size: 28),
                    ),
                    _buildItem(
                      context,
                      index: 4,
                      child: _profileIcon(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Applies the Figma #3A3A3A -> black gradient as the icon fill.
  Widget _gradientIcon(Widget child) {
    return ShaderMask(
      shaderCallback: (bounds) => _darkGradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: child,
    );
  }

  /// Applies a solid [color] as the icon fill (used for the selected white icon).
  Widget _solidIcon(Widget child, Color color) {
    return ShaderMask(
      shaderCallback: (bounds) =>
          LinearGradient(colors: [color, color]).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: child,
    );
  }

  Widget _profileIcon(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/common/fi_1077114_1_486.svg',
      width: 28,
      height: 28,
      errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.person_outline, size: 28),
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required int index,
    required Widget child,
  }) {
    final selected = navigationShell.currentIndex == index;
    Widget content;
    if (selected) {
      content = Container(
        width: 50,
        height: 50,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          gradient: _darkGradient,
        ),
        child: Center(child: _solidIcon(child, Colors.white)),
      );
    } else {
      content = _gradientIcon(Opacity(opacity: 0.3, child: child));
    }
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTap(index),
        child: Center(child: content),
      ),
    );
  }

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
