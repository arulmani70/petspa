import 'package:flutter/material.dart';

/// Maps the 12 Figma service names to their downloaded thumbnail assets,
/// plus aliases for the alternate DB seed names so every catalogue entry
/// resolves to a real image.
///
/// Files are produced by `fetch_all_images.py` (assets/images/*.png). While a
/// file has not been downloaded yet, every consumer shows its fallback.
const Map<String, String> _serviceAssets = {
  'full grooming': 'assets/images/common/svc_full_grooming.png',
  'grooming': 'assets/images/common/svc_full_grooming.png',
  'bath & blow dry': 'assets/images/common/svc_bath_blowdry.png',
  'bathing': 'assets/images/common/svc_bath_blowdry.png',
  'grooming & bathing': 'assets/images/common/svc_full_grooming.png',
  'hair trimming': 'assets/images/common/svc_hair_trim.png',
  'breed styling': 'assets/images/common/svc_breed_style.png',
  'nail trimming': 'assets/images/common/svc_nail_trim.png',
  'ear cleaning': 'assets/images/common/svc_ear_clean.png',
  'teeth brushing': 'assets/images/common/svc_teeth_brush.png',
  'flea & tick treatment': 'assets/images/common/svc_flea_tick.png',
  'puppy grooming': 'assets/images/common/svc_puppy.png',
  'de-shedding treatment': 'assets/images/common/svc_deshed.png',
  'skin care treatment': 'assets/images/common/svc_skin_care.png',
  'spa package': 'assets/images/common/svc_spa.png',
  'bath & brush': 'assets/images/common/svc_bath_blowdry.png',
  'haircut & styling': 'assets/images/common/svc_breed_style.png',
  'nail clipping': 'assets/images/common/svc_nail_trim.png',
  'puppy package': 'assets/images/common/svc_puppy.png',
  'nail grinding & buffing': 'assets/images/common/svc_nail_trim.png',
  'nail grinding': 'assets/images/common/svc_nail_trim.png',
  'anal gland expression': 'assets/images/common/svc_skin_care.png',
  'face & feet trim': 'assets/images/common/svc_hair_trim.png',
  'medicated shampoo': 'assets/images/common/svc_bath_blowdry.png',
  'blueberry facial': 'assets/images/common/svc_skin_care.png',
  'paw balm treatment': 'assets/images/common/svc_skin_care.png',
  'paw balm': 'assets/images/common/svc_skin_care.png',
  'breath freshener spray': 'assets/images/common/svc_teeth_brush.png',
  'breath freshener': 'assets/images/common/svc_teeth_brush.png',
  'de-matting treatment': 'assets/images/common/svc_deshed.png',
  'de-matting': 'assets/images/common/svc_deshed.png',
  'dematting': 'assets/images/common/svc_deshed.png',
  'deshedding': 'assets/images/common/svc_deshed.png',
  'bath & tidy package': 'assets/images/common/svc_bath_blowdry.png',
  'deluxe puppy spa': 'assets/images/common/svc_puppy.png',
  'small breeds': 'assets/images/common/svc_breed_style.png',
  'medium breeds': 'assets/images/common/svc_breed_style.png',
  'large breeds': 'assets/images/common/svc_breed_style.png',
  'small dog': 'assets/images/common/svc_breed_style.png',
  'medium dog': 'assets/images/common/svc_breed_style.png',
  'large dog': 'assets/images/common/svc_breed_style.png',
  'breed style': 'assets/images/common/svc_breed_style.png',
  'breed': 'assets/images/common/svc_breed_style.png',
  'breeds': 'assets/images/common/svc_breed_style.png',
};

/// Asset path for a service by its display name, or null when unknown.
String? serviceAssetFor(String? serviceName) {
  if (serviceName == null) return null;
  final clean = serviceName.trim().toLowerCase();
  if (clean.isEmpty) return null;

  // Direct match
  if (_serviceAssets.containsKey(clean)) {
    return _serviceAssets[clean];
  }

  // Split on " — " or " - " (e.g. "Small Breeds — Grooming" -> "Grooming")
  if (clean.contains('—') || clean.contains('-')) {
    final sub = clean.split(RegExp(r'[—-]\s*')).last.trim();
    if (_serviceAssets.containsKey(sub)) {
      return _serviceAssets[sub];
    }
  }

  // Keyword-based fallback matching
  if (clean.contains('breed')) return 'assets/images/common/svc_breed_style.png';
  if (clean.contains('groom')) return 'assets/images/common/svc_full_grooming.png';
  if (clean.contains('bath')) return 'assets/images/common/svc_bath_blowdry.png';
  if (clean.contains('nail')) return 'assets/images/common/svc_nail_trim.png';
  if (clean.contains('teeth') || clean.contains('dental')) return 'assets/images/common/svc_teeth_brush.png';
  if (clean.contains('ear')) return 'assets/images/common/svc_ear_clean.png';
  if (clean.contains('hair') || clean.contains('scissor')) return 'assets/images/common/svc_hair_trim.png';
  if (clean.contains('puppy')) return 'assets/images/common/svc_puppy.png';
  if (clean.contains('spa')) return 'assets/images/common/svc_spa.png';
  if (clean.contains('shed')) return 'assets/images/common/svc_deshed.png';
  if (clean.contains('skin') || clean.contains('facial')) return 'assets/images/common/svc_skin_care.png';
  if (clean.contains('flea') || clean.contains('tick')) return 'assets/images/common/svc_flea_tick.png';

  return null;
}

/// `Image.asset` wired to a Figma asset with a safe fallback while the PNG
/// has not been downloaded yet (the Figma REST API is currently rate-limited).
class FigmaImage extends StatelessWidget {
  final String? asset;
  final Widget? fallback;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;

  const FigmaImage({
    super.key,
    this.asset,
    this.fallback,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final path = asset;
    if (path == null || path.isEmpty) {
      return fallback ?? const SizedBox.shrink();
    }
    return Image.asset(
      path,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) =>
          fallback ?? const SizedBox.shrink(),
    );
  }
}

/// BoxDecoration image layer referencing a Figma asset. Paints nothing over
/// the base color while the PNG has not been downloaded yet.
DecorationImage? figmaDecorationImage(String? asset) {
  if (asset == null || asset.isEmpty) return null;
  return DecorationImage(
    image: AssetImage(asset),
    fit: BoxFit.cover,
    onError: (Object error, StackTrace? stackTrace) {},
  );
}
