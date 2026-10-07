import 'package:flutter/material.dart';

/// Maps the 12 Figma service names to their downloaded thumbnail assets,
/// plus aliases for the alternate DB seed names so every catalogue entry
/// resolves to a real image.
///
/// Files are produced by `fetch_all_images.py` (assets/images/*.png). While a
/// file has not been downloaded yet, every consumer shows its fallback.
const Map<String, String> _serviceAssets = {
  'full grooming': 'assets/images/common/svc_full_grooming.png',
  'bath & blow dry': 'assets/images/common/svc_bath_blowdry.png',
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
};

/// Asset path for a service by its display name, or null when unknown.
String? serviceAssetFor(String? serviceName) {
  if (serviceName == null) return null;
  return _serviceAssets[serviceName.trim().toLowerCase()];
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
