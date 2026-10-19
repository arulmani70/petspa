import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shear_heaven_pet_spa/src/common/constants/constansts.dart';

/// Centralized helper for robust, dynamic pet image resolution, normalization,
/// and rendering across the entire Shear Heaven Pet Spa app.
class PetImageHelper {
  const PetImageHelper._();

  static const String defaultPetAsset1 = 'assets/images/common/pet_1.png';
  static const String defaultPetAsset2 = 'assets/images/common/pet_2.png';
  static const String defaultPetTeddy = 'assets/images/chat/pet_teddy.png';

  /// Returns an asset fallback image path based on pet name or list index.
  static String getFallbackAsset({String? petName, int? index}) {
    if (petName != null && petName.trim().isNotEmpty) {
      final lower = petName.trim().toLowerCase();
      if (lower.contains('teddy')) return defaultPetAsset2;
      if (lower.contains('doodles')) return defaultPetTeddy;
    }
    if (index != null && index.isOdd) {
      return defaultPetAsset2;
    }
    return defaultPetAsset1;
  }

  /// Normalizes a pet image path or URL into a fully-qualified URL, asset path,
  /// or local file path.
  static String? normalizeImageUrl(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim();
    if (str.isEmpty ||
        str.toLowerCase() == 'null' ||
        str.toLowerCase() == 'undefined') {
      return null;
    }

    // Full remote URLs
    if (str.startsWith('http://') || str.startsWith('https://')) {
      return str;
    }

    // App assets
    if (str.startsWith('assets/')) {
      return str;
    }

    // Local file path (e.g. from image picker)
    try {
      final file = File(str);
      if (file.existsSync()) {
        return str;
      }
    } catch (_) {}

    // Relative backend paths
    final base = Constants.app.BASE_URL;
    if (str.startsWith('/')) {
      return '$base$str';
    }
    return '$base/$str';
  }

  /// Extracts the pet photo URL or path from any pet or booking data structure,
  /// checking all possible field naming conventions returned by backend APIs.
  static String? extractPetPhoto(dynamic source) {
    if (source == null) return null;
    if (source is String) {
      return normalizeImageUrl(source);
    }
    if (source is! Map) return null;

    final map = source;

    // Check nested pet map first if present
    if (map['pet'] is Map) {
      final petPhoto = extractPetPhoto(map['pet']);
      if (petPhoto != null && petPhoto.isNotEmpty) {
        return petPhoto;
      }
    }

    const candidateKeys = [
      'petImage',
      'pet_image',
      'profilePictureUrl',
      'profilePicture',
      'profile_picture_url',
      'profile_picture',
      'petProfilePictureUrl',
      'petProfilePicture',
      'pet_profile_picture_url',
      'pet_profile_picture',
      'photoUrl',
      'photo_url',
      'PhotoUrl',
      'petPhotoUrl',
      'pet_photo_url',
      'petPhoto',
      'pet_photo',
      'PetPhoto',
      'imageUrl',
      'image_url',
      'image',
      'avatar',
      'Avatar',
      'photo',
      'picture',
    ];

    for (final key in candidateKeys) {
      final val = map[key]?.toString().trim();
      if (val != null &&
          val.isNotEmpty &&
          val.toLowerCase() != 'null' &&
          val.toLowerCase() != 'undefined') {
        return normalizeImageUrl(val);
      }
    }

    return null;
  }

  /// Builds a dynamic Image widget that renders any valid URL, asset, or file,
  /// while gracefully falling back to placeholder assets on missing data or
  /// image-loading failures.
  static Widget buildImage({
    String? photoUrl,
    dynamic source,
    String? petName,
    int? index,
    String? fallbackAsset,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    Widget? customFallback,
    Widget? loadingWidget,
  }) {
    final raw = (photoUrl != null &&
            photoUrl.trim().isNotEmpty &&
            photoUrl.toLowerCase() != 'null' &&
            photoUrl.toLowerCase() != 'undefined')
        ? photoUrl
        : extractPetPhoto(source);

    final resolved = normalizeImageUrl(raw);
    final asset = fallbackAsset ?? getFallbackAsset(petName: petName, index: index);

    Widget fallbackWidget() {
      if (customFallback != null) return customFallback;
      return Image.asset(
        asset,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (c, e, s) => Container(
          width: width,
          height: height,
          color: const Color(0xFFF3F4F6),
          alignment: Alignment.center,
          child: const Icon(Icons.pets, color: Color(0xFF9CA3AF), size: 28),
        ),
      );
    }

    if (resolved == null || resolved.isEmpty) {
      return fallbackWidget();
    }

    if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
      return Image.network(
        resolved,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: loadingWidget != null
            ? (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return loadingWidget;
              }
            : null,
        errorBuilder: (context, error, stackTrace) => fallbackWidget(),
      );
    }

    if (resolved.startsWith('assets/')) {
      return Image.asset(
        resolved,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => fallbackWidget(),
      );
    }

    try {
      final file = File(resolved);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => fallbackWidget(),
        );
      }
    } catch (_) {}

    final clean = resolved.startsWith('/') ? resolved.substring(1) : resolved;
    return Image.network(
      '${Constants.app.BASE_URL}/$clean',
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => fallbackWidget(),
    );
  }
}
