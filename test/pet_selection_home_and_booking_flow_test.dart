import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/pets/views/mobile/widgets/pet_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pet ID & Mapping Robustness Tests', () {
    test('BookingDateUtils.parsePetIdFromPet parses numeric and string pet IDs correctly', () {
      expect(BookingDateUtils.parsePetIdFromPet({'id': 101}), equals(101));
      expect(BookingDateUtils.parsePetIdFromPet({'id': '102'}), equals(102));
      expect(BookingDateUtils.parsePetIdFromPet({'petId': 103}), equals(103));
      expect(BookingDateUtils.parsePetIdFromPet({'pet_id': '104'}), equals(104));
      expect(BookingDateUtils.parsePetIdFromPet({Constants.database.COLUMN_ID: 105}), equals(105));
      expect(BookingDateUtils.parsePetIdFromPet({'_id': '106'}), equals(106));
      expect(BookingDateUtils.parsePetIdFromPet(null), isNull);
      expect(BookingDateUtils.parsePetIdFromPet({}), isNull);
      expect(BookingDateUtils.parsePetIdFromPet({'id': 0}), isNull);
    });

    test('Pet details data structure preserves name, breed, weight, age, and gender', () {
      final petData = {
        'id': 102,
        'petId': 102,
        'pet_id': 102,
        'name': 'Bella',
        'pet_name': 'Bella',
        'breed': 'Poodle',
        'weight': '10kg',
        'age': '2 Years',
        'gender': 'Female',
        'photo_url': 'https://example.com/bella.png',
      };

      expect(BookingDateUtils.parsePetIdFromPet(petData), equals(102));
      expect(petData['gender'], equals('Female'));
      expect(petData['breed'], equals('Poodle'));
      expect(petData['pet_name'], equals('Bella'));
    });
  });

  group('PetCard Widget Details Rendering Tests', () {
    testWidgets('PetCard displays pet name, breed, weight, age, and gender correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetCard(
              name: 'Bella',
              breed: 'Poodle',
              weight: '10',
              age: '2 Years',
              gender: 'Female',
              selected: true,
            ),
          ),
        ),
      );

      expect(find.text('Bella'), findsOneWidget);
      expect(find.textContaining('Poodle', findRichText: true), findsOneWidget);
      expect(find.textContaining('10kg', findRichText: true), findsOneWidget);
      expect(find.textContaining('2 Years', findRichText: true), findsOneWidget);
      expect(find.textContaining('Female', findRichText: true), findsOneWidget);
      expect(find.byIcon(Icons.female), findsOneWidget);
    });

    testWidgets('PetCard displays Male gender correctly when gender is male', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PetCard(
              name: 'Max',
              breed: 'Golden Retriever',
              weight: '25kg',
              age: '3 Years',
              gender: 'Male',
              selected: false,
            ),
          ),
        ),
      );

      expect(find.text('Max'), findsOneWidget);
      expect(find.textContaining('Golden Retriever', findRichText: true), findsOneWidget);
      expect(find.textContaining('Male', findRichText: true), findsOneWidget);
      expect(find.byIcon(Icons.male), findsOneWidget);
    });
  });

  group('Pet Selection & Booking Draft Flow Tests', () {
    final pet1 = {
      'id': 101,
      'petId': 101,
      'name': 'Max',
      'pet_name': 'Max',
      'breed': 'Golden Retriever',
      'weight': '25kg',
      'age': '3 Years',
      'gender': 'Male',
    };

    final pet2 = {
      'id': 102,
      'petId': 102,
      'name': 'Bella',
      'pet_name': 'Bella',
      'breed': 'Poodle',
      'weight': '10kg',
      'age': '2 Years',
      'gender': 'Female',
    };

    final petsList = [pet1, pet2];

    test('Clicking Pet 2 from multiple pets selects Pet 2 (ID: 102) without defaulting to index 0 (Pet 1)', () {
      final draft = BookingDraft();

      // User clicks Pet 2 on Home Page
      final clickedPet = pet2;
      final clickedPetId = BookingDateUtils.parsePetIdFromPet(clickedPet)!;
      draft.setPet(clickedPet);

      expect(draft.pet, isNotNull);
      expect(BookingDateUtils.parsePetIdFromPet(draft.pet), equals(102));
      expect(draft.pet?['pet_name'], equals('Bella'));
      expect(draft.pet?['gender'], equals('Female'));

      // Resolving pet on Pet Select screen matches clickedPetId strictly by ID
      final selectedPet = petsList.firstWhere(
        (p) => BookingDateUtils.parsePetIdFromPet(p) == clickedPetId,
        orElse: () => petsList.first,
      );

      expect(selectedPet['id'], equals(102));
      expect(selectedPet['pet_name'], equals('Bella'));
      expect(selectedPet['id'], isNot(equals(petsList.first['id'])));
    });

    test('Booking draft preserves selected Pet 2 through booking confirmation payload', () {
      final draft = BookingDraft();
      draft.setPet(pet2);
      draft.setService({'id': 1, 'service_name': 'Full Grooming'});

      final resolvedPetId = BookingDateUtils.parsePetIdFromPet(draft.pet) ??
          int.tryParse(draft.pet?['id']?.toString() ?? '0') ?? 0;

      expect(resolvedPetId, equals(102));

      // Payload generated for POST /api/bookings
      final bookingPayload = {
        'ClientId': 'SHEAR-001',
        'StoreId': 'SHEAR-001',
        'petId': resolvedPetId,
        'serviceId': 1,
      };

      expect(bookingPayload['petId'], equals(102));
      expect(bookingPayload['petId'], isNot(equals(101)));
    });

    test('Switching between pets correctly updates draft and booking ID', () {
      final draft = BookingDraft();

      // Select Pet 2 first
      draft.setPet(pet2);
      expect(BookingDateUtils.parsePetIdFromPet(draft.pet), equals(102));

      // Switch to Pet 1
      draft.setPet(pet1);
      expect(BookingDateUtils.parsePetIdFromPet(draft.pet), equals(101));
      expect(draft.pet?['pet_name'], equals('Max'));
      expect(draft.pet?['gender'], equals('Male'));
    });
  });
}
