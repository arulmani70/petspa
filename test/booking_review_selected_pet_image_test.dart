import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/bookings/repo/booking_repository.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/booking_review_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/app_assets.dart';
import 'package:shear_heaven_pet_spa/src/offers/repos/offer_repository.dart';
import 'package:shear_heaven_pet_spa/src/store/repositories/store_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PetImageHelper Resolution & Extraction Tests', () {
    test('normalizeImageUrl handles full URLs, asset paths, and relative upload paths', () {
      expect(
        PetImageHelper.normalizeImageUrl('https://api.shearheavenpetspa.com/uploads/pets/rocky.jpg'),
        equals('https://api.shearheavenpetspa.com/uploads/pets/rocky.jpg'),
      );

      expect(
        PetImageHelper.normalizeImageUrl('/uploads/pets/rocky.jpg'),
        equals('${Constants.app.BASE_URL}/uploads/pets/rocky.jpg'),
      );

      expect(
        PetImageHelper.normalizeImageUrl('uploads/pets/rocky.jpg'),
        equals('${Constants.app.BASE_URL}/uploads/pets/rocky.jpg'),
      );

      expect(
        PetImageHelper.normalizeImageUrl('/assets/images/common/pet_1.png'),
        equals('assets/images/common/pet_1.png'),
      );

      expect(
        PetImageHelper.normalizeImageUrl('assets/images/common/pet_1.png'),
        equals('assets/images/common/pet_1.png'),
      );

      // Bare uploaded filename
      expect(
        PetImageHelper.normalizeImageUrl('pet-1793603406683-853781872.jpg'),
        equals('${Constants.app.BASE_URL}/uploads/pets/pet-1793603406683-853781872.jpg'),
      );

      // Null, empty, and invalid strings
      expect(PetImageHelper.normalizeImageUrl(null), isNull);
      expect(PetImageHelper.normalizeImageUrl(''), isNull);
      expect(PetImageHelper.normalizeImageUrl('   '), isNull);
      expect(PetImageHelper.normalizeImageUrl('null'), isNull);
      expect(PetImageHelper.normalizeImageUrl('undefined'), isNull);
    });

    test('extractPetPhoto extracts photo from flat and nested pet maps', () {
      // Backend profilePicture field
      final petWithProfilePicture = {
        'id': 10,
        'petName': 'Rocky',
        'profilePicture': '/uploads/pets/pet-1793603406683-853781872.jpg',
      };
      expect(
        PetImageHelper.extractPetPhoto(petWithProfilePicture),
        equals('${Constants.app.BASE_URL}/uploads/pets/pet-1793603406683-853781872.jpg'),
      );

      // Nested in 'pet' key
      final nestedPet = {
        'pet': {
          'petName': 'Rocky',
          'photo_url': 'https://example.com/rocky.png',
        },
      };
      expect(
        PetImageHelper.extractPetPhoto(nestedPet),
        equals('https://example.com/rocky.png'),
      );

      // Nested in 'data' key
      final dataWrappedPet = {
        'data': {
          'name': 'Bella',
          'profilePictureUrl': '/uploads/pets/bella.jpg',
        },
      };
      expect(
        PetImageHelper.extractPetPhoto(dataWrappedPet),
        equals('${Constants.app.BASE_URL}/uploads/pets/bella.jpg'),
      );
    });
  });

  group('BookingReviewPageMobile Selected Pet Image UI Tests', () {
    late BookingDraft draft;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});

      final session = SessionService();
      await session.initialize();
      await session.saveClientId('SHEAR-001');
      await session.saveRegionId('DWG-001');
      await session.saveStoreId('SHEAR-001');

      final apiRepo = ApiRepository();
      await apiRepo.initialize();

      GetIt.I.allowReassignment = true;
      GetIt.I.registerSingleton<SessionService>(session);
      GetIt.I.registerSingleton<ApiRepository>(apiRepo);

      draft = BookingDraft();
      GetIt.I.registerSingleton<BookingDraft>(draft);
      GetIt.I.registerSingleton<StoreRepository>(StoreRepository());
      GetIt.I.registerSingleton<BookingRepository>(BookingRepository());
      GetIt.I.registerSingleton<OfferRepository>(OfferRepository());
    });

    tearDown(() {
      draft.reset();
    });

    testWidgets('Selected pet with fallback image displays pet asset on Review & Confirm page', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      draft.setPet({
        'id': 10,
        'pet_name': 'Rocky',
        'breed': 'Red Poodle',
        'weight': 'Small',
        'age': '1yr',
      });
      draft.setService({
        'id': 1,
        'serviceId': 1,
        'service_name': 'Full Grooming',
        'price': 60.0,
        'durationMinutes': 60,
      });
      draft.date = DateTime(2026, 11, 6);
      draft.timeSlot = '10:00';
      draft.endTime = '11:00';

      await tester.pumpWidget(
        const MaterialApp(
          home: BookingReviewPageMobile(),
        ),
      );
      await tester.pumpAndSettle();

      // "Selected Pet" section is visible
      expect(find.text('Selected Pet'), findsOneWidget);
      expect(find.text('Rocky'), findsOneWidget);

      // Verified: renders an image (FigmaImage / Image.asset with fallback asset)
      expect(find.byType(FigmaImage), findsWidgets);
      final figmaImage = tester.widgetList<FigmaImage>(find.byType(FigmaImage)).first;
      expect(
        figmaImage.asset,
        anyOf(equals(PetImageHelper.defaultPetAsset1), equals(PetImageHelper.defaultPetAsset2)),
      );
    });

    testWidgets('Selected pet with uploaded profile picture renders pet photo on Review & Confirm page', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      draft.setPet({
        'id': 10,
        'pet_name': 'Rocky',
        'breed': 'Red Poodle',
        'weight': 'Small',
        'age': '1yr',
        'profilePicture': '/uploads/pets/pet-1793603406683-853781872.jpg',
      });
      draft.setService({
        'id': 1,
        'serviceId': 1,
        'service_name': 'Full Grooming',
        'price': 60.0,
        'durationMinutes': 60,
      });
      draft.date = DateTime(2026, 11, 6);
      draft.timeSlot = '10:00';
      draft.endTime = '11:00';

      await tester.pumpWidget(
        const MaterialApp(
          home: BookingReviewPageMobile(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Selected Pet'), findsOneWidget);
      expect(find.text('Rocky'), findsOneWidget);

      // Verifies Image.network is created for the remote/backend pet image URL
      final imageNetworkFinder = find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is NetworkImage,
      );
      expect(imageNetworkFinder, findsWidgets);

      final matchingNetworkImages = tester
          .widgetList<Image>(imageNetworkFinder)
          .map((img) => (img.image as NetworkImage).url)
          .toList();

      expect(
        matchingNetworkImages.any((url) => url.contains('pet-1793603406683-853781872.jpg')),
        isTrue,
      );
    });
  });
}
