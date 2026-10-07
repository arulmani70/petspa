import 'dart:async';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GalleryRepository {
  final Logger _log = Logger();
  static const String _kStorageKey = 'custom_gallery_images';

  static const List<String> defaultShowcaseImages = [
    'assets/images/home/promo_dog.png',
    'assets/images/common/offer_1.png',
    'assets/images/common/offer_2.png',
    'assets/images/common/offer_3.png',
    'assets/images/common/pet_1.png',
    'assets/images/common/pet_2.png',
    'assets/images/common/svc_full_grooming.png',
    'assets/images/common/svc_spa.png',
    'assets/images/common/svc_bath_blowdry.png',
    'assets/images/common/svc_breed_style.png',
  ];

  final List<String> _userImages = [];
  final StreamController<List<String>> _galleryStreamController =
      StreamController<List<String>>.broadcast();

  Stream<List<String>> get galleryStream => _galleryStreamController.stream;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_kStorageKey);
      if (saved != null && saved.isNotEmpty) {
        _userImages.clear();
        _userImages.addAll(saved);
      }
      _notify();
      _log.d('GalleryRepository::initialize::Loaded ${_userImages.length} user images');
    } catch (e) {
      _log.e('GalleryRepository::initialize::Error: $e');
    }
  }

  List<String> getAllImages() {
    return [..._userImages, ...defaultShowcaseImages];
  }

  List<String> getUserImages() {
    return List.unmodifiable(_userImages);
  }

  Future<bool> addImage(String filePath) async {
    if (filePath.trim().isEmpty) return false;
    try {
      final trimmed = filePath.trim();
      _userImages.remove(trimmed);
      _userImages.insert(0, trimmed);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kStorageKey, _userImages);
      _notify();
      _log.i('GalleryRepository::addImage::Added image: $trimmed');
      return true;
    } catch (e) {
      _log.e('GalleryRepository::addImage::Error: $e');
      return false;
    }
  }

  Future<bool> removeImage(String filePath) async {
    try {
      final removed = _userImages.remove(filePath.trim());
      if (removed) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_kStorageKey, _userImages);
        _notify();
        _log.i('GalleryRepository::removeImage::Removed image: $filePath');
      }
      return removed;
    } catch (e) {
      _log.e('GalleryRepository::removeImage::Error: $e');
      return false;
    }
  }

  void _notify() {
    if (!_galleryStreamController.isClosed) {
      _galleryStreamController.add(getAllImages());
    }
  }

  void dispose() {
    _galleryStreamController.close();
  }
}
