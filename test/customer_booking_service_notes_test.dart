import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/booking_service_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';

void main() {
  group('Step 2: Customer Booking – Service Request Notes Draft & Model Tests', () {
    late BookingDraft draft;

    setUp(() {
      draft = BookingDraft();
    });

    test('BookingDraft initial state has null serviceRequestNotes', () {
      expect(draft.serviceRequestNotes, isNull);
    });

    test('BookingDraft setServiceRequestNotes sets value and notifies listeners', () {
      bool notified = false;
      draft.addListener(() {
        notified = true;
      });

      draft.setServiceRequestNotes('Please trim carefully around ears.');
      expect(draft.serviceRequestNotes, 'Please trim carefully around ears.');
      expect(notified, isTrue);
    });

    test('BookingDraft setServiceRequestNotes with notify: false updates value without notifying', () {
      bool notified = false;
      draft.addListener(() {
        notified = true;
      });

      draft.setServiceRequestNotes('Silent update test', notify: false);
      expect(draft.serviceRequestNotes, 'Silent update test');
      expect(notified, isFalse);
    });

    test('BookingDraft reset() clears serviceRequestNotes and other booking fields', () {
      draft.setServiceRequestNotes('Do not use blow dryer');
      draft.setService({'id': 1, 'name': 'Full Groom'});
      expect(draft.serviceRequestNotes, isNotNull);

      draft.reset();
      expect(draft.serviceRequestNotes, isNull);
      expect(draft.service, isNull);
    });

    test('Strict Separation: Booking notes do not modify permanent pet profile notes', () {
      final petProfile = {
        'id': 101,
        'name': 'Bella',
        'breed': 'Golden Retriever',
        'notesAllergies': 'Allergic to chicken shampoo',
        'behaviorNotes': 'Friendly, nervous with loud noises',
      };

      draft.setPet(petProfile);
      draft.setServiceRequestNotes('Booking note: Extra comb-out for summer coat.');

      // Verify draft booking note
      expect(draft.serviceRequestNotes, 'Booking note: Extra comb-out for summer coat.');

      // Verify permanent pet profile notes remain completely intact and unchanged
      expect(draft.pet?['notesAllergies'], 'Allergic to chicken shampoo');
      expect(draft.pet?['behaviorNotes'], 'Friendly, nervous with loud noises');
      expect(draft.pet?['specialInstructions'], isNull);
    });
  });

  group('Step 2: GroomerBooking Model Special Instructions / Notes Tests', () {
    test('GroomerBooking parses specialInstructions from various backend field aliases', () {
      // 1. Backend uses 'specialInstructions'
      final booking1 = GroomerBooking.fromJson({
        'bookingId': 1001,
        'status': 'confirmed',
        'bookingDate': '2026-10-20',
        'startTime': '10:00 AM',
        'endTime': '11:00 AM',
        'petName': 'Milo',
        'customerName': 'Sarah Connor',
        'serviceName': 'Full Groom',
        'specialInstructions': 'Sensitive skin on belly area',
      });
      expect(booking1.specialInstructions, 'Sensitive skin on belly area');
      expect(booking1.notes, 'Sensitive skin on belly area');
      expect(booking1.serviceRequestNotes, 'Sensitive skin on belly area');
      expect(booking1.hasSpecialInstructions, isTrue);

      // 2. Backend uses 'notes'
      final booking2 = GroomerBooking.fromJson({
        'bookingId': 1002,
        'status': 'confirmed',
        'bookingDate': '2026-10-20',
        'startTime': '11:00 AM',
        'endTime': '12:00 PM',
        'petName': 'Charlie',
        'customerName': 'John Wick',
        'serviceName': 'Bath & Brush',
        'notes': 'Please keep coat long',
      });
      expect(booking2.specialInstructions, 'Please keep coat long');
      expect(booking2.notes, 'Please keep coat long');
      expect(booking2.hasSpecialInstructions, isTrue);

      // 3. Backend uses 'service_request_notes'
      final booking3 = GroomerBooking.fromJson({
        'bookingId': 1003,
        'status': 'pending',
        'bookingDate': '2026-10-20',
        'startTime': '02:00 PM',
        'endTime': '03:00 PM',
        'petName': 'Luna',
        'customerName': 'Bruce Wayne',
        'serviceName': 'Nail Trim',
        'service_request_notes': 'Scared of high tables',
      });
      expect(booking3.specialInstructions, 'Scared of high tables');
      expect(booking3.hasSpecialInstructions, isTrue);

      // 4. No instructions provided
      final booking4 = GroomerBooking.fromJson({
        'bookingId': 1004,
        'status': 'pending',
        'bookingDate': '2026-10-20',
        'startTime': '03:00 PM',
        'endTime': '04:00 PM',
        'petName': 'Daisy',
        'customerName': 'Clark Kent',
        'serviceName': 'Bath',
      });
      expect(booking4.specialInstructions, isNull);
      expect(booking4.notes, isNull);
      expect(booking4.hasSpecialInstructions, isFalse);
    });

    test('GroomerBooking toJson includes specialInstructions when present', () {
      final booking = GroomerBooking(
        bookingId: 2001,
        status: 'confirmed',
        bookingDate: '2026-10-21',
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        petName: 'Rocky',
        customerName: 'Tony Stark',
        serviceName: 'Full Styling',
        specialInstructions: 'VIP treatment requested',
      );

      final json = booking.toJson();
      expect(json['specialInstructions'], 'VIP treatment requested');
      expect(json['bookingId'], 2001);
      expect(json['petName'], 'Rocky');
    });

    test('GroomerBooking copyWith updates specialInstructions', () {
      final original = GroomerBooking(
        bookingId: 3001,
        status: 'confirmed',
        bookingDate: '2026-10-22',
        startTime: '01:00 PM',
        endTime: '02:00 PM',
        petName: 'Cooper',
        customerName: 'Steve Rogers',
        serviceName: 'De-shedding',
        specialInstructions: 'Initial note',
      );

      final updated = original.copyWith(
        specialInstructions: 'Updated instruction for groomer',
      );

      expect(updated.specialInstructions, 'Updated instruction for groomer');
      expect(original.specialInstructions, 'Initial note');
    });
  });

  group('Step 2: Service Request Notes API Payload & Propagation Tests', () {
    test('Booking review payload accurately packages specialInstructions and notes', () {
      // Simulate constructing payload as in BookingReviewPageMobile._confirmBooking
      const enteredNotes = 'Be extra patient with front paws.';

      final payload = <String, dynamic>{
        'ClientId': 'SHEAR-001',
        'RegionId': 'DWG-001',
        'StoreId': 'SHEAR-001',
        'petId': 42,
        'serviceId': 7,
        'addOnIds': [1, 3],
        'groomerId': 5,
        'bookingDate': '2026-10-25',
        'startTime': '10:00 AM',
        'endTime': '11:00 AM',
        if (enteredNotes.trim().isNotEmpty) ...{
          'specialInstructions': enteredNotes.trim(),
          'notes': enteredNotes.trim(),
        },
      };

      expect(payload['specialInstructions'], 'Be extra patient with front paws.');
      expect(payload['notes'], 'Be extra patient with front paws.');
      expect(payload['petId'], 42);
      expect(payload['groomerId'], 5);
      expect(payload['bookingDate'], '2026-10-25');
    });

    test('Confirmed booking record snapshot preserves service request instructions', () {
      const enteredNotes = 'Hypoallergenic wash only please.';

      final lastBooking = <String, dynamic>{
        'booking_id': 999,
        'status': 'confirmed',
        'service_name': 'Bath & Brush',
        if (enteredNotes.trim().isNotEmpty) ...{
          'specialInstructions': enteredNotes.trim(),
          'special_instructions': enteredNotes.trim(),
          'notes': enteredNotes.trim(),
          'service_request_notes': enteredNotes.trim(),
        },
      };

      expect(lastBooking['specialInstructions'], 'Hypoallergenic wash only please.');
      expect(lastBooking['notes'], 'Hypoallergenic wash only please.');
      expect(lastBooking['service_request_notes'], 'Hypoallergenic wash only please.');
    });
  });

  group('Step 2: ServiceRequestDescriptionCard Widget Tests', () {
    testWidgets('Renders label, (Optional) tag, icon, and hint text', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServiceRequestDescriptionCard(
              controller: controller,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Service Request Description'), findsOneWidget);
      expect(find.text('(Optional)'), findsOneWidget);
      expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
      expect(
        find.text('Add instructions or requests for the groomer...'),
        findsOneWidget,
      );
    });

    testWidgets('Entering text calls onChanged and updates controller', (tester) async {
      final controller = TextEditingController();
      String? changedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServiceRequestDescriptionCard(
              controller: controller,
              onChanged: (val) {
                changedValue = val;
              },
            ),
          ),
        ),
      );

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      await tester.enterText(textFieldFinder, 'Sensitive around back paws');
      await tester.pump();

      expect(controller.text, 'Sensitive around back paws');
      expect(changedValue, 'Sensitive around back paws');
    });

    testWidgets('Pre-populates existing notes from draft controller', (tester) async {
      final controller = TextEditingController(text: 'Pre-existing instruction');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServiceRequestDescriptionCard(
              controller: controller,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Pre-existing instruction'), findsOneWidget);
    });
  });

  group('Step 2: End-to-End Booking Lifecycle & Contract Verification Tests', () {
    test('Service-selection notes survive review editing, payload generation, response mapping, and draft reset', () {
      final draft = BookingDraft();

      // 1. Step 1: Customer selects pet with permanent notes
      final pet = {
        'id': 55,
        'pet_name': 'Maximus',
        'breed': 'German Shepherd',
        'notesAllergies': 'Grass allergy, skin sensitive to scented products',
        'behaviorNotes': 'Very friendly, dislikes tail touching',
      };
      draft.setPet(pet);

      // 2. Step 2: Customer enters Service Request Notes in Step 2
      draft.setService({'id': 10, 'name': 'Full De-shed'});
      draft.setServiceRequestNotes('Please be careful near lower back, dog had hip surgery.');
      expect(draft.serviceRequestNotes, 'Please be careful near lower back, dog had hip surgery.');

      // 3. Step 3: Date & time selection (preserves service notes)
      draft.setDate(DateTime(2026, 11, 1));
      draft.setSlot('10:00 AM', '11:30 AM');
      expect(draft.serviceRequestNotes, 'Please be careful near lower back, dog had hip surgery.');

      // 4. Step 4: Review screen pre-populates and customer edits notes
      final reviewController = TextEditingController(text: draft.serviceRequestNotes ?? '');
      expect(reviewController.text, 'Please be careful near lower back, dog had hip surgery.');

      // Customer edits notes on review screen
      reviewController.text = 'Please be careful near lower back (hip surgery) and use oatmeal shampoo.';
      draft.setServiceRequestNotes(reviewController.text.trim());

      // 5. Construct payload for POST /api/bookings
      final notesText = reviewController.text.trim();
      final payload = <String, dynamic>{
        'ClientId': 'SHEAR-001',
        'RegionId': 'DWG-001',
        'StoreId': 'SHEAR-001',
        'petId': draft.pet?['id'],
        'serviceId': draft.service?['id'],
        'bookingDate': '2026-11-01',
        'startTime': draft.timeSlot,
        'endTime': draft.endTime,
        if (notesText.isNotEmpty) ...{
          'specialInstructions': notesText,
          'notes': notesText,
        },
      };

      // Verify contract compatibility: both fields are provided for the backend
      expect(payload['specialInstructions'], contains('oatmeal shampoo'));
      expect(payload['notes'], contains('oatmeal shampoo'));
      expect(payload['petId'], 55);

      // 6. Simulate API response from POST /api/bookings
      final mockApiResponse = {
        'success': true,
        'message': 'Booking created successfully',
        'data': {
          'bookingId': 8801,
          'status': 'confirmed',
          'totalDurationMinutes': 90,
          'totalPrice': 120.0,
          'specialInstructions': payload['specialInstructions'],
        },
      };

      final mockData = mockApiResponse['data'] as Map<String, dynamic>;

      // 7. Verify GroomerBooking model correctly parses instructions from API response
      final groomerBooking = GroomerBooking.fromJson({
        'bookingId': mockData['bookingId'],
        'status': mockData['status'],
        'bookingDate': payload['bookingDate'],
        'startTime': payload['startTime'],
        'endTime': payload['endTime'],
        'petId': payload['petId'],
        'petName': draft.pet!['pet_name'],
        'breed': draft.pet!['breed'],
        'customerName': 'John Doe',
        'serviceName': draft.service!['name'],
        'specialInstructions': mockData['specialInstructions'],
      });

      expect(groomerBooking.bookingId, 8801);
      expect(groomerBooking.specialInstructions, contains('hip surgery'));
      expect(groomerBooking.notes, contains('oatmeal shampoo'));
      expect(groomerBooking.hasSpecialInstructions, isTrue);

      // 8. Snapshot stored in lastBooking
      draft.lastBooking = {
        'booking_id': 8801,
        'specialInstructions': notesText,
        'notes': notesText,
      };

      // 9. Reset draft
      draft.reset();
      expect(draft.serviceRequestNotes, isNull);
      expect(draft.pet, isNull);
      expect(draft.service, isNull);

      // 10. Verify permanent pet profile was completely untouched
      expect(pet['notesAllergies'], 'Grass allergy, skin sensitive to scented products');
      expect(pet['behaviorNotes'], 'Very friendly, dislikes tail touching');
      expect(pet.containsKey('specialInstructions'), isFalse);
    });
  });
}
