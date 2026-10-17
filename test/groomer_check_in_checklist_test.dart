import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_check_in_record.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/all_groomers/all_groomers_schedule_page.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/groomer_check_in_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  group('Step 6 – GroomerCheckInRecord Model Tests', () {
    test('Correctly serializes and deserializes check-in record JSON', () {
      final json = {
        'vaccinationVerified': true,
        'healthVerified': true,
        'customerRequestAcknowledged': true,
        'groomerCheckInNotes': 'Coat lightly matted behind ears. Demeanor is calm.',
        'checkInTimestamp': '2026-10-16T10:05:22Z',
        'checkedInByGroomerId': 2,
      };

      final record = GroomerCheckInRecord.fromJson(json);
      expect(record.vaccinationVerified, isTrue);
      expect(record.healthVerified, isTrue);
      expect(record.customerRequestAcknowledged, isTrue);
      expect(record.isFullyVerified, isTrue);
      expect(record.groomerCheckInNotes, equals('Coat lightly matted behind ears. Demeanor is calm.'));
      expect(record.checkInTimestamp, equals('2026-10-16T10:05:22Z'));
      expect(record.checkedInByGroomerId, equals(2));

      final serialized = record.toJson();
      expect(serialized['vaccinationVerified'], isTrue);
      expect(serialized['healthVerified'], isTrue);
      expect(serialized['customerRequestAcknowledged'], isTrue);
      expect(serialized['groomerCheckInNotes'], equals('Coat lightly matted behind ears. Demeanor is calm.'));
      expect(serialized['checkInTimestamp'], equals('2026-10-16T10:05:22Z'));
      expect(serialized['checkedInByGroomerId'], equals(2));
    });

    test('Parses truthy strings and integers correctly', () {
      final json = {
        'vaccination_verified': 'true',
        'health_verified': 1,
        'customer_request_acknowledged': 'yes',
      };

      final record = GroomerCheckInRecord.fromJson(json);
      expect(record.vaccinationVerified, isTrue);
      expect(record.healthVerified, isTrue);
      expect(record.customerRequestAcknowledged, isTrue);
    });

    test('Defaults to false and null when fields are missing', () {
      final record = GroomerCheckInRecord.fromJson({});
      expect(record.vaccinationVerified, isFalse);
      expect(record.healthVerified, isFalse);
      expect(record.customerRequestAcknowledged, isFalse);
      expect(record.isFullyVerified, isFalse);
      expect(record.groomerCheckInNotes, isNull);
      expect(record.checkInTimestamp, isNull);
    });
  });

  group('Step 6 – GroomerBooking Check-in Integration & Separation of Notes Tests', () {
    test('GroomerBooking parses checkInRecord, specialInstructions, and petMedicalNotes separately', () {
      final json = {
        'bookingId': 901,
        'status': 'checked_in',
        'bookingDate': '2026-10-16',
        'startTime': '09:00',
        'endTime': '10:00',
        'petName': 'Luna',
        'breed': 'Golden Retriever',
        'customerName': 'Emma Watson',
        'serviceName': 'Full Grooming',
        'specialInstructions': 'Please do not cut tail fur too short',
        'notesAllergies': 'Allergic to chicken and sensitive skin shampoo only',
        'checkInRecord': {
          'vaccinationVerified': true,
          'healthVerified': true,
          'customerRequestAcknowledged': true,
          'groomerCheckInNotes': 'Checked skin; no hot spots found. Calm behavior.',
          'checkInTimestamp': '2026-10-16T09:02:15Z',
          'checkedInByGroomerId': 1,
        },
      };

      final booking = GroomerBooking.fromJson(json);

      // Note 1: Customer booking instructions
      expect(booking.specialInstructions, equals('Please do not cut tail fur too short'));
      expect(booking.hasSpecialInstructions, isTrue);

      // Note 2: Permanent pet medical/allergy notes
      expect(booking.petMedicalNotes, equals('Allergic to chicken and sensitive skin shampoo only'));
      expect(booking.hasPetMedicalNotes, isTrue);

      // Note 3: Groomer intake notes & verification
      expect(booking.checkInRecord, isNotNull);
      expect(booking.groomerCheckInNotes, equals('Checked skin; no hot spots found. Calm behavior.'));
      expect(booking.checkInTimestamp, equals('2026-10-16T09:02:15Z'));
      expect(booking.isVaccinationVerified, isTrue);
      expect(booking.isHealthVerified, isTrue);
      expect(booking.isCustomerRequestAcknowledged, isTrue);
      expect(booking.isCheckedIn, isTrue);
    });

    test('Identifies confirmed booking ready for check-in', () {
      const confirmedBooking = GroomerBooking(
        bookingId: 902,
        status: 'confirmed',
        bookingDate: '2026-10-16',
        startTime: '10:00',
        endTime: '11:00',
        petName: 'Rocky',
        customerName: 'John Wick',
        serviceName: 'De-shedding Treatment',
      );

      expect(confirmedBooking.isConfirmedReadyForCheckIn, isTrue);
      expect(confirmedBooking.isCheckedIn, isFalse);
      expect(confirmedBooking.hasCheckInRecord, isFalse);
    });
  });

  group('Step 6 – GroomerCheckInDialog UI & Checklist Behavior Tests', () {
    testWidgets('Renders separate cards for Customer Instructions, Medical Notes, and Checklist', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const testBooking = GroomerBooking(
        bookingId: 501,
        status: 'confirmed',
        bookingDate: '2026-10-16',
        startTime: '11:00 AM',
        endTime: '12:00 PM',
        petName: 'Milo',
        breed: 'Poodle',
        customerName: 'Claire Redfield',
        serviceName: 'Full Grooming',
        specialInstructions: 'Trim face rounded, leave eyelashes long',
        petMedicalNotes: 'Mild hip dysplasia - handle rear legs gently',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GroomerCheckInDialog(booking: testBooking),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header check
      expect(find.text('Pet Intake & Check-in'), findsOneWidget);
      expect(find.textContaining('Milo'), findsWidgets);

      // Note 1: Customer Instructions
      expect(find.text('Customer Service Instructions'), findsOneWidget);
      expect(find.text('"Trim face rounded, leave eyelashes long"'), findsOneWidget);

      // Note 2: Pet Medical Notes
      expect(find.text('Pet Medical & Allergy Notes (Permanent Profile)'), findsOneWidget);
      expect(find.text('Mild hip dysplasia - handle rear legs gently'), findsOneWidget);

      // Note 3: Groomer Notes Field
      expect(find.text('Groomer Check-in Notes'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Checklist items
      expect(find.text('Vaccination Verified'), findsOneWidget);
      expect(find.text("Dog's Health & Coat Verified"), findsOneWidget);
      expect(find.text('Customer Request Acknowledged'), findsOneWidget);

      // Confirm button is present
      expect(find.text('Confirm Check-in'), findsOneWidget);
    });

    testWidgets('Confirm Check-in button requires both Vaccination and Health verifications', (tester) async {
      const testBooking = GroomerBooking(
        bookingId: 502,
        status: 'confirmed',
        bookingDate: '2026-10-16',
        startTime: '01:00 PM',
        endTime: '02:00 PM',
        petName: 'Charlie',
        breed: 'Beagle',
        customerName: 'Sam Fisher',
        serviceName: 'Bath & Brush',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GroomerCheckInDialog(booking: testBooking),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially, checkboxes are unchecked -> Confirm button should be disabled (ElevatedButton onPressed is null)
      final confirmBtnFinder = find.widgetWithText(ElevatedButton, 'Confirm Check-in');
      expect(confirmBtnFinder, findsOneWidget);
      ElevatedButton btn = tester.widget<ElevatedButton>(confirmBtnFinder);
      expect(btn.onPressed, isNull);

      // Tap Vaccination Verified
      await tester.tap(find.text('Vaccination Verified'));
      await tester.pumpAndSettle();

      // Still disabled because Health Verified is not checked
      btn = tester.widget<ElevatedButton>(confirmBtnFinder);
      expect(btn.onPressed, isNull);

      // Tap Health Verified
      await tester.tap(find.text("Dog's Health & Coat Verified"));
      await tester.pumpAndSettle();

      // Now both are checked -> Confirm button becomes enabled
      btn = tester.widget<ElevatedButton>(confirmBtnFinder);
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('Displays Server Check-in Timestamp banner when present', (tester) async {
      const testBooking = GroomerBooking(
        bookingId: 503,
        status: 'checked_in',
        bookingDate: '2026-10-16',
        startTime: '02:00 PM',
        endTime: '03:00 PM',
        petName: 'Bailey',
        customerName: 'Leon Kennedy',
        serviceName: 'Puppy Cut',
        checkInRecord: GroomerCheckInRecord(
          vaccinationVerified: true,
          healthVerified: true,
          customerRequestAcknowledged: true,
          checkInTimestamp: '2026-10-16T14:05:00Z',
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GroomerCheckInDialog(booking: testBooking),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Server Check-in Timestamp:'), findsOneWidget);
    });
  });

  group('Step 6 – AllGroomersSchedulePage Check-In Integration Tests', () {
    testWidgets('Shows Check In button for confirmed booking owned by groomer', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Mock logged-in groomer as Merisa Brown (id: 1)
      await ServicesLocator.sessionService.saveGroomerUser({
        'id': 1,
        'groomerCode': 'G001',
        'firstName': 'Merisa',
        'lastName': 'Brown',
        'email': 'merisa@shearheaven.com',
        'role': 'Groomer',
      });

      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final salonGroomers = <SalonGroomer>[
        const SalonGroomer(
          id: 1,
          groomerCode: 'G001',
          firstName: 'Merisa',
          lastName: 'Brown',
          name: 'Merisa Brown',
          role: 'Senior Groomer',
        ),
        const SalonGroomer(
          id: 2,
          groomerCode: 'G002',
          firstName: 'Richard',
          lastName: 'Cooke',
          name: 'Richard Cooke',
          role: 'Groomer',
        ),
      ];

      final bookings = [
        GroomerBooking(
          bookingId: 701,
          status: 'confirmed',
          bookingDate: todayStr,
          startTime: '09:00',
          endTime: '10:00',
          petName: 'Teddy',
          customerName: 'Sarah Connor',
          serviceName: 'Full Grooming',
          groomerId: 1, // matches current groomer Merisa Brown
          groomerName: 'Merisa Brown',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: bookings,
            initialSalonGroomers: salonGroomers,
            initialGroomerFilterId: '1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check In button should be visible for confirmed booking
      expect(find.text('Check In'), findsOneWidget);
    });

    testWidgets('Shows Checked In badge when booking is already checked in', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await ServicesLocator.sessionService.saveGroomerUser({
        'id': 1,
        'groomerCode': 'G001',
        'firstName': 'Merisa',
        'lastName': 'Brown',
        'email': 'merisa@shearheaven.com',
        'role': 'Groomer',
      });

      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final salonGroomers = <SalonGroomer>[
        const SalonGroomer(
          id: 1,
          groomerCode: 'G001',
          firstName: 'Merisa',
          lastName: 'Brown',
          name: 'Merisa Brown',
          role: 'Senior Groomer',
        ),
      ];

      final bookings = [
        GroomerBooking(
          bookingId: 702,
          status: 'checked_in',
          bookingDate: todayStr,
          startTime: '10:00',
          endTime: '11:00',
          petName: 'Cooper',
          customerName: 'Ellen Ripley',
          serviceName: 'Full Grooming',
          groomerId: 1,
          groomerName: 'Merisa Brown',
          checkInRecord: const GroomerCheckInRecord(
            vaccinationVerified: true,
            healthVerified: true,
            customerRequestAcknowledged: true,
            groomerCheckInNotes: 'Clean coat',
            checkInTimestamp: '2026-10-16T10:00:00Z',
          ),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: bookings,
            initialSalonGroomers: salonGroomers,
            initialGroomerFilterId: '1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Badge should display Checked In
      expect(find.textContaining('Checked In'), findsWidgets);
    });
  });
}
