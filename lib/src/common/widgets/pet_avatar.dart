import 'package:flutter/material.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';

class PetAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? name;
  final double size;

  const PetAvatar({
    super.key,
    this.photoUrl,
    this.name,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name != null && name!.isNotEmpty ? name![0].toUpperCase() : 'P';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF14B8A6), width: 2),
      ),
      child: photoUrl != null && photoUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                photoUrl!.startsWith('/') ? '${Constants.app.BASE_URL}$photoUrl' : photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFallback(initial),
              ),
            )
          : _buildFallback(initial),
    );
  }

  Widget _buildFallback(String initial) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF0F766E),
        ),
      ),
    );
  }
}
