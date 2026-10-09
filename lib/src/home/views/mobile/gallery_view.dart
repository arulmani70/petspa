import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/home/repo/gallery_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';

/// Full-featured, sleek Gallery Bottom Sheet & Widget for Shear Heaven Pet Spa.
class GalleryView extends StatefulWidget {
  final bool isModal;
  const GalleryView({super.key, this.isModal = true});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const GalleryView(isModal: true),
    );
  }

  @override
  State<GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends State<GalleryView> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  late GalleryRepository _galleryRepo;
  List<String> _images = [];

  @override
  void initState() {
    super.initState();
    _galleryRepo = serviceLocator.isRegistered<GalleryRepository>()
        ? serviceLocator<GalleryRepository>()
        : GalleryRepository()..initialize();
    _images = _galleryRepo.getAllImages();
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (picked == null) return;

      setState(() => _isUploading = true);

      final success = await _galleryRepo.addImage(picked.path);

      if (mounted) {
        setState(() {
          _isUploading = false;
          _images = _galleryRepo.getAllImages();
        });

        if (success) {
          ToastUtil.showSuccessToast(context, 'Image uploaded to Gallery successfully!');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ToastUtil.showErrorToast(context, 'Could not upload image');
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Upload to Gallery',
              style: AppFonts.parkinsans(
                size: 18,
                weight: FontWeight.w700,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library_outlined, color: Colors.black),
              ),
              title: Text(
                'Choose from Photo Library',
                style: AppFonts.poppins(size: 15, weight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_outlined, color: Colors.black),
              ),
              title: Text(
                'Take a New Photo',
                style: AppFonts.poppins(size: 15, weight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showFullImageView(String path) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              clipBehavior: Clip.none,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _buildImageItem(path, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageItem(String path, {BoxFit fit = BoxFit.cover}) {
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: fit,
        errorBuilder: (ctx, err, st) => Container(
          color: const Color(0xFFEEEEEE),
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 36),
        ),
      );
    } else if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: fit,
        errorBuilder: (ctx, err, st) => Container(
          color: const Color(0xFFEEEEEE),
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 36),
        ),
      );
    } else {
      if (!kIsWeb) {
        final file = File(path);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: fit,
            errorBuilder: (ctx, err, st) => Container(
              color: const Color(0xFFEEEEEE),
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 36),
            ),
          );
        }
      }
      return Image.asset(
        'assets/images/home/promo_dog.png',
        fit: fit,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gallery',
                      style: AppFonts.parkinsans(
                        size: 22,
                        weight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Explore our pet spa & grooming moments',
                      style: AppFonts.poppins(
                        size: 13,
                        weight: FontWeight.w400,
                        color: const Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
                if (widget.isModal)
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300, width: 0.5),
                      ),
                      child: const Icon(Icons.close, size: 20, color: Colors.black),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Upload Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: _isUploading ? null : _showImageSourcePicker,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isUploading) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Uploading...',
                        style: AppFonts.poppins(
                          size: 15,
                          weight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ] else ...[
                      const Icon(Icons.add_photo_alternate_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Upload Image',
                        style: AppFonts.poppins(
                          size: 15,
                          weight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Gallery Grid
          Expanded(
            child: _images.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          'No images in gallery yet',
                          style: AppFonts.poppins(size: 15, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      final path = _images[index];
                      final isUserUploaded = !path.startsWith('assets/');
                      return GestureDetector(
                        onTap: () => _showFullImageView(path),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: _buildImageItem(path),
                              ),
                            ),
                            if (isUserUploaded)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Uploaded',
                                    style: AppFonts.poppins(
                                      size: 10,
                                      weight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    if (widget.isModal) {
      return body;
    }

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.goNamed(RouteNames.home);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          title: Text(
            'Gallery',
            style: AppFonts.parkinsans(size: 20, weight: FontWeight.w700),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18, color: Colors.black),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.goNamed(RouteNames.home);
              }
            },
          ),
        ),
        body: body,
      ),
    );
  }
}
