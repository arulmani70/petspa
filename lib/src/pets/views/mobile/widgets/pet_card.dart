import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/app_assets.dart';

/// Pet card matching the Figma design:
/// White card with vertically centered photo and details,
/// Name (Parkinsans 700), Breed row with dog head outline icon,
/// Weight row with KG kettlebell icon, and Age row with Paw icon.
/// Uses FittedBox on metadata rows to completely prevent right overflow on all device sizes.
class PetCard extends StatelessWidget {
  final String name;
  final String breed;
  final String weight;
  final String age;
  final String? photoUrl;
  final String? assetFallback;
  final bool selected;
  final bool showDelete;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const PetCard({
    super.key,
    required this.name,
    required this.breed,
    required this.weight,
    required this.age,
    this.photoUrl,
    this.assetFallback,
    this.selected = false,
    this.showDelete = false,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 114,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.black : Colors.transparent,
            width: selected ? 1.5 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildPhoto(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name.isNotEmpty ? name : 'Pet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.parkinsans(
                            size: 18,
                            weight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ),
                      if (showDelete)
                        GestureDetector(
                          onTap: onDelete,
                          child: const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.delete_outline,
                              color: Color(0xFF991B1B),
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SvgPicture.asset(
                        'assets/images/pets/icon_dog_breed.svg',
                        width: 14,
                        height: 14,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFF111827),
                          BlendMode.srcIn,
                        ),
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.pets, size: 14, color: Color(0xFF111827)),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: AppFonts.poppins(
                              size: 13,
                              color: const Color(0xFF111827),
                            ),
                            children: [
                              const TextSpan(
                                text: 'Breed: ',
                                style: TextStyle(fontWeight: FontWeight.w400),
                              ),
                              TextSpan(
                                text: breed.isNotEmpty ? breed : 'Unknown',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Weight
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              'assets/images/pets/icon_pet_weight.svg',
                              width: 13,
                              height: 13,
                              colorFilter: const ColorFilter.mode(
                                Color(0xFF111827),
                                BlendMode.srcIn,
                              ),
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.fitness_center, size: 13, color: Color(0xFF111827)),
                            ),
                            const SizedBox(width: 4),
                            RichText(
                              text: TextSpan(
                                style: AppFonts.poppins(
                                  size: 13,
                                  color: const Color(0xFF111827),
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Weight: ',
                                    style: TextStyle(fontWeight: FontWeight.w400),
                                  ),
                                  TextSpan(
                                    text: weight.endsWith('kg') ? weight : '${weight}kg',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // Age (Two paw prints)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              'assets/images/pets/icon_pet_age.svg',
                              width: 14,
                              height: 14,
                              colorFilter: const ColorFilter.mode(
                                Color(0xFF111827),
                                BlendMode.srcIn,
                              ),
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.pets, size: 14, color: Color(0xFF111827)),
                            ),
                            const SizedBox(width: 4),
                            RichText(
                              text: TextSpan(
                                style: AppFonts.poppins(
                                  size: 13,
                                  color: const Color(0xFF111827),
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'Age: ',
                                    style: TextStyle(fontWeight: FontWeight.w400),
                                  ),
                                  TextSpan(
                                    text: age.isNotEmpty ? age : '0yrs',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoto() {
    final raw = photoUrl?.trim();
    final hasPhoto = raw != null && raw.isNotEmpty && raw != 'null';
    if (!hasPhoto) {
      return _fallback();
    }
    final path = raw;
    Widget img;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      img = Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => _fallback(),
      );
    } else if (path.startsWith('assets/')) {
      img = Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => _fallback(),
      );
    } else {
      try {
        final file = File(path);
        if (file.existsSync()) {
          img = Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => _fallback(),
          );
        } else {
          final clean = path.startsWith('/') ? path.substring(1) : path;
          img = Image.network(
            '${Constants.app.BASE_URL}/$clean',
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => _fallback(),
          );
        }
      } catch (_) {
        final clean = path.startsWith('/') ? path.substring(1) : path;
        img = Image.network(
          '${Constants.app.BASE_URL}/$clean',
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => _fallback(),
        );
      }
    }

    return Container(
      width: 88,
      height: 88,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5E5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: img,
    );
  }

  Widget _fallback() {
    return FigmaImage(
      asset: assetFallback,
      fit: BoxFit.cover,
      fallback: const Icon(Icons.pets, color: Colors.white, size: 34),
    );
  }
}
