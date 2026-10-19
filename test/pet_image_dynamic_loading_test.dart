import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/pet_avatar.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/models/customer_summary.dart';

void main() {
  group('PetImageHelper - Dynamic Image Extraction and Normalization Tests', () {
    test('normalizes remote URLs unchanged', () {
      expect(
        PetImageHelper.normalizeImageUrl('https://cdn.example.com/pets/dog.png'),
        equals('https://cdn.example.com/pets/dog.png'),
      );
      expect(
        PetImageHelper.normalizeImageUrl('http://cdn.example.com/pets/cat.jpg'),
        equals('http://cdn.example.com/pets/cat.jpg'),
      );
    });

    test('normalizes asset paths unchanged', () {
      expect(
        PetImageHelper.normalizeImageUrl('assets/images/common/pet_1.png'),
        equals('assets/images/common/pet_1.png'),
      );
    });

    test('normalizes server relative paths with and without leading slash', () {
      final base = Constants.app.BASE_URL;
      expect(
        PetImageHelper.normalizeImageUrl('/uploads/pets/beagle.png'),
        equals('$base/uploads/pets/beagle.png'),
      );
      expect(
        PetImageHelper.normalizeImageUrl('uploads/pets/golden.png'),
        equals('$base/uploads/pets/golden.png'),
      );
    });

    test('handles null, empty, and pseudo-null string values gracefully', () {
      expect(PetImageHelper.normalizeImageUrl(null), isNull);
      expect(PetImageHelper.normalizeImageUrl(''), isNull);
      expect(PetImageHelper.normalizeImageUrl('   '), isNull);
      expect(PetImageHelper.normalizeImageUrl('null'), isNull);
      expect(PetImageHelper.normalizeImageUrl('NULL'), isNull);
      expect(PetImageHelper.normalizeImageUrl('undefined'), isNull);
    });

    test('extracts photo from diverse backend response keys', () {
      final base = Constants.app.BASE_URL;

      // petImage
      expect(
        PetImageHelper.extractPetPhoto({'petImage': 'uploads/dog1.png'}),
        equals('$base/uploads/dog1.png'),
      );

      // pet_image
      expect(
        PetImageHelper.extractPetPhoto({'pet_image': '/uploads/dog2.png'}),
        equals('$base/uploads/dog2.png'),
      );

      // profilePictureUrl
      expect(
        PetImageHelper.extractPetPhoto({'profilePictureUrl': 'https://example.com/dog3.png'}),
        equals('https://example.com/dog3.png'),
      );

      // profilePicture
      expect(
        PetImageHelper.extractPetPhoto({'profilePicture': 'uploads/dog4.png'}),
        equals('$base/uploads/dog4.png'),
      );

      // photoUrl
      expect(
        PetImageHelper.extractPetPhoto({'photoUrl': 'uploads/dog5.png'}),
        equals('$base/uploads/dog5.png'),
      );

      // photo_url
      expect(
        PetImageHelper.extractPetPhoto({'photo_url': 'uploads/dog6.png'}),
        equals('$base/uploads/dog6.png'),
      );

      // petPhoto
      expect(
        PetImageHelper.extractPetPhoto({'petPhoto': 'uploads/dog7.png'}),
        equals('$base/uploads/dog7.png'),
      );

      // imageUrl
      expect(
        PetImageHelper.extractPetPhoto({'imageUrl': 'uploads/dog8.png'}),
        equals('$base/uploads/dog8.png'),
      );

      // image
      expect(
        PetImageHelper.extractPetPhoto({'image': 'uploads/dog9.png'}),
        equals('$base/uploads/dog9.png'),
      );

      // avatar
      expect(
        PetImageHelper.extractPetPhoto({'avatar': 'uploads/dog10.png'}),
        equals('$base/uploads/dog10.png'),
      );
    });

    test('extracts photo from nested pet map', () {
      final payload = {
        'bookingId': 101,
        'pet': {
          'id': 1,
          'name': 'Bella',
          'photoUrl': 'https://example.com/bella.jpg',
        },
      };
      expect(
        PetImageHelper.extractPetPhoto(payload),
        equals('https://example.com/bella.jpg'),
      );
    });

    test('getFallbackAsset resolves appropriate asset based on name or index', () {
      expect(
        PetImageHelper.getFallbackAsset(petName: 'Teddy Bear'),
        equals(PetImageHelper.defaultPetAsset2),
      );
      expect(
        PetImageHelper.getFallbackAsset(petName: 'Goldendoodles'),
        equals(PetImageHelper.defaultPetTeddy),
      );
      expect(
        PetImageHelper.getFallbackAsset(index: 1),
        equals(PetImageHelper.defaultPetAsset2),
      );
      expect(
        PetImageHelper.getFallbackAsset(index: 0),
        equals(PetImageHelper.defaultPetAsset1),
      );
      expect(
        PetImageHelper.getFallbackAsset(petName: 'Max'),
        equals(PetImageHelper.defaultPetAsset1),
      );
    });
  });

  group('Model Integration with Dynamic Pet Image Extraction', () {
    test('CustomerPetSummary extracts image dynamically from any valid key', () {
      final petJson = {
        'id': 42,
        'name': 'Coco',
        'breed': 'Poodle',
        'petImage': '/uploads/pets/coco.jpg',
      };
      final summary = CustomerPetSummary.fromJson(petJson);
      expect(summary.name, equals('Coco'));
      expect(
        summary.profilePictureUrl,
        equals('${Constants.app.BASE_URL}/uploads/pets/coco.jpg'),
      );
    });

    test('GroomerBooking parses and normalizes pet image from root and nested keys', () {
      final bookingJson = {
        'bookingId': 501,
        'status': 'confirmed',
        'petName': 'Luna',
        'petProfilePicture': 'uploads/pets/luna.jpg',
      };
      final booking = GroomerBooking.fromJson(bookingJson);
      expect(booking.petName, equals('Luna'));
      expect(
        booking.profilePicture,
        equals('${Constants.app.BASE_URL}/uploads/pets/luna.jpg'),
      );
    });
  });

  group('Widget Rendering with PetImageHelper and PetAvatar', () {
    testWidgets('PetImageHelper.buildImage renders fallback asset when photoUrl is null',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PetImageHelper.buildImage(
              photoUrl: null,
              petName: 'Milo',
              width: 50,
              height: 50,
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('PetImageHelper.buildImage renders customFallback when provided on null photo',
        (tester) async {
      const customKey = Key('custom_fallback_icon');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PetImageHelper.buildImage(
              photoUrl: '',
              customFallback: const Icon(Icons.pets, key: customKey),
            ),
          ),
        ),
      );

      expect(find.byKey(customKey), findsOneWidget);
    });

    testWidgets('PetAvatar widget renders fallback initial when photoUrl is null',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetAvatar(
              photoUrl: null,
              name: 'Teddy',
              size: 40,
            ),
          ),
        ),
      );

      expect(find.byType(PetAvatar), findsOneWidget);
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('PetAvatar widget renders Image when photoUrl is present',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetAvatar(
              photoUrl: 'assets/images/common/pet_1.png',
              name: 'Teddy',
              size: 40,
            ),
          ),
        ),
      );

      expect(find.byType(PetAvatar), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });
  });
}
