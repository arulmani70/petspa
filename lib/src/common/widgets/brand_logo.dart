import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  final double size;
  final bool dark;

  const BrandLogo({super.key, this.size = 44, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final iconColor = dark ? const Color(0xFF0F766E) : Colors.white;
    final bgColor = dark ? Colors.white : const Color(0xFF0F766E);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.12 * 255).round()),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(Icons.pets, size: size * 0.5, color: iconColor),
    );
  }
}
