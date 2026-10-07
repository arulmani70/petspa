import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/home/repo/gallery_repository.dart';
import 'package:shear_heaven_pet_spa/src/home/views/mobile/gallery_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GalleryRepository galleryRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'custom_gallery_images': ['/mock/path/custom_pet1.jpg'],
    });

    galleryRepo = GalleryRepository();
    await galleryRepo.initialize();

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<GalleryRepository>(galleryRepo);
  });

  group('GalleryRepository', () {
    test('initializes with custom and default showcase images', () {
      final images = galleryRepo.getAllImages();
      expect(images, contains('/mock/path/custom_pet1.jpg'));
      expect(images, contains('assets/images/home/promo_dog.png'));
      expect(images.first, equals('/mock/path/custom_pet1.jpg'));
    });

    test('addImage adds new image to the front and persists', () async {
      final success = await galleryRepo.addImage('/mock/path/new_pet2.png');
      expect(success, isTrue);

      final images = galleryRepo.getAllImages();
      expect(images.first, equals('/mock/path/new_pet2.png'));
      expect(galleryRepo.getUserImages(), contains('/mock/path/new_pet2.png'));
    });

    test('removeImage removes image and updates list', () async {
      await galleryRepo.addImage('/mock/path/temp.png');
      expect(galleryRepo.getAllImages(), contains('/mock/path/temp.png'));

      final removed = await galleryRepo.removeImage('/mock/path/temp.png');
      expect(removed, isTrue);
      expect(galleryRepo.getAllImages(), isNot(contains('/mock/path/temp.png')));
    });
  });

  group('GalleryView Widget', () {
    testWidgets('renders Gallery UI elements and grid', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GalleryView(isModal: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gallery'), findsWidgets);
      expect(find.text('Explore our pet spa & grooming moments'), findsOneWidget);
      expect(find.text('Upload Image'), findsOneWidget);
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('shows image picker options on Upload Image tap', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GalleryView(isModal: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Upload Image'));
      await tester.pumpAndSettle();

      expect(find.text('Upload to Gallery'), findsOneWidget);
      expect(find.text('Choose from Photo Library'), findsOneWidget);
      expect(find.text('Take a New Photo'), findsOneWidget);
    });
  });
}
