import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_milestone_record.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/all_groomers/all_groomers_schedule_page.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/groomer_milestone_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  group('Step 7 – GroomerMilestoneRecord Model Tests', () {
    test('Correctly serializes and deserializes milestone record JSON', () {
      final json = {
        'bathCompleted': true,
        'bathCompletedAt': '2026-10-16T11:00:00Z',
        'bathNotes': 'Hypoallergenic shampoo applied.',
        'groomingCompleted': true,
        'groomingCompletedAt': '2026-10-16T11:45:00Z',
        'groomingNotes': 'Teddy bear trim finished.',
        'completedByGroomerId': 2,
      };

      final record = GroomerMilestoneRecord.fromJson(json);
      expect(record.bathCompleted, isTrue);
      expect(record.bathCompletedAt, equals('2026-10-16T11:00:00Z'));
      expect(record.bathNotes, equals('Hypoallergenic shampoo applied.'));
      expect(record.groomingCompleted, isTrue);
      expect(record.groomingCompletedAt, equals('2026-10-16T11:45:00Z'));
      expect(record.groomingNotes, equals('Teddy bear trim finished.'));
      expect(record.completedByGroomerId, equals(2));
      expect(record.areAllMilestonesDone, isTrue);
      expect(record.hasAnyMilestone, isTrue);

      final serialized = record.toJson();
      expect(serialized['bathCompleted'], isTrue);
      expect(serialized['bathCompletedAt'], equals('2026-10-16T11:00:00Z'));
      expect(serialized['bathNotes'], equals('Hypoallergenic shampoo applied.'));
      expect(serialized['groomingCompleted'], isTrue);
      expect(serialized['groomingCompletedAt'], equals('2026-10-16T11:45:00Z'));
      expect(serialized['groomingNotes'], equals('Teddy bear trim finished.'));
      expect(serialized['completedByGroomerId'], equals(2));
    });

    test('Parses snake_case and alternative boolean fields correctly', () {
      final json = {
        'bath_completed': 'true',
        'bath_completed_at': '2026-10-16T10:30:00Z',
        'bath_notes': 'Deep conditioning done.',
        'grooming_completed': 1,
        'grooming_completed_at': '2026-10-16T11:15:00Z',
        'grooming_notes': 'Nails ground smooth.',
        'completed_by_groomer_id': '3',
      };

      final record = GroomerMilestoneRecord.fromJson(json);
      expect(record.bathCompleted, isTrue);
      expect(record.bathCompletedAt, equals('2026-10-16T10:30:00Z'));
      expect(record.bathNotes, equals('Deep conditioning done.'));
      expect(record.groomingCompleted, isTrue);
      expect(record.groomingCompletedAt, equals('2026-10-16T11:15:00Z'));
      expect(record.groomingNotes, equals('Nails ground smooth.'));
      expect(record.completedByGroomerId, equals(3));
    });

    test('copyWith updates fields without altering others', () {
      const initial = GroomerMilestoneRecord(
        bathCompleted: true,
        bathCompletedAt: '2026-10-16T10:00:00Z',
        bathNotes: 'First bath note',
      );

      final updated = initial.copyWith(
        groomingCompleted: true,
        groomingCompletedAt: '2026-10-16T11:00:00Z',
        groomingNotes: 'First grooming note',
      );

      expect(updated.bathCompleted, isTrue);
      expect(updated.bathNotes, equals('First bath note'));
      expect(updated.groomingCompleted, isTrue);
      expect(updated.groomingCompletedAt, equals('2026-10-16T11:00:00Z'));
      expect(updated.groomingNotes, equals('First grooming note'));
    });
  });

  group('Step 7 – GroomerBooking Milestone Helpers & Deserialization', () {
    test('GroomerBooking parses milestoneRecord from nested JSON', () {
      final json = {
        'bookingId': 701,
        'status': 'bath_completed',
        'bookingDate': '2026-10-16',
        'startTime': '10:00 AM',
        'endTime': '11:00 AM',
        'petName': 'Milo',
        'customerName': 'Sarah Connor',
        'serviceName': 'Full Grooming',
        'milestoneRecord': {
          'bathCompleted': true,
          'bathCompletedAt': '2026-10-16T10:30:00Z',
          'bathNotes': 'De-shed shampoo applied.',
        },
      };

      final booking = GroomerBooking.fromJson(json);
      expect(booking.isBathCompleted, isTrue);
      expect(booking.isGroomingCompleted, isFalse);
      expect(booking.canCompleteBath, isFalse); // Already completed
      expect(booking.canCompleteGrooming, isTrue); // Eligible for grooming
      expect(booking.bathNotes, equals('De-shed shampoo applied.'));
      expect(booking.bathCompletedAt, equals('2026-10-16T10:30:00Z'));
    });

    test('GroomerBooking derives milestone flags from status string', () {
      final bathBooking = GroomerBooking.fromJson({
        'bookingId': 702,
        'status': 'bath_completed',
        'bookingDate': '2026-10-16',
        'startTime': '10:00 AM',
        'endTime': '11:00 AM',
        'petName': 'Buddy',
        'customerName': 'John Wick',
        'serviceName': 'Bath & Brush',
      });

      expect(bathBooking.isBathCompleted, isTrue);
      expect(bathBooking.canCompleteGrooming, isTrue);

      final groomingBooking = GroomerBooking.fromJson({
        'bookingId': 703,
        'status': 'grooming_completed',
        'bookingDate': '2026-10-16',
        'startTime': '10:00 AM',
        'endTime': '11:00 AM',
        'petName': 'Bella',
        'customerName': 'Emma Watson',
        'serviceName': 'Full Service Groom',
      });

      expect(groomingBooking.isBathCompleted, isTrue);
      expect(groomingBooking.isGroomingCompleted, isTrue);
      expect(groomingBooking.canCompleteBath, isFalse);
      expect(groomingBooking.canCompleteGrooming, isFalse);
    });
  });

  group('Step 7 – Repository Milestone Transition Validation Tests', () {
    test('Prevents milestone progression on pending or cancelled bookings', () async {
      const pendingBooking = GroomerBooking(
        bookingId: 704,
        status: 'pending',
        bookingDate: '2026-10-16',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Rocky',
        customerName: 'Robert',
        serviceName: 'Full Groom',
      );

      final resPending = await ServicesLocator.groomerHomeRepository.updateServiceMilestone(
        bookingId: 704,
        milestone: 'bath_completed',
        booking: pendingBooking,
      );

      expect(resPending.success, isFalse);
      expect(resPending.message, contains('Cannot update milestone for a pending appointment'));

      const cancelledBooking = GroomerBooking(
        bookingId: 705,
        status: 'cancelled',
        bookingDate: '2026-10-16',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Rocky',
        customerName: 'Robert',
        serviceName: 'Full Groom',
      );

      final resCancelled = await ServicesLocator.groomerHomeRepository.updateServiceMilestone(
        bookingId: 705,
        milestone: 'bath_completed',
        booking: cancelledBooking,
      );

      expect(resCancelled.success, isFalse);
      expect(resCancelled.message, contains('Cannot update milestone for a cancelled appointment'));
    });

    test('Prevents repeated transitions when milestone is already completed', () async {
      const bathDoneBooking = GroomerBooking(
        bookingId: 706,
        status: 'bath_completed',
        bookingDate: '2026-10-16',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Daisy',
        customerName: 'David',
        serviceName: 'Full Groom',
        milestoneRecord: GroomerMilestoneRecord(bathCompleted: true),
      );

      final resRepeatBath = await ServicesLocator.groomerHomeRepository.updateServiceMilestone(
        bookingId: 706,
        milestone: 'bath_completed',
        booking: bathDoneBooking,
      );

      expect(resRepeatBath.success, isFalse);
      expect(resRepeatBath.message, contains('Bath milestone has already been completed'));

      const groomingDoneBooking = GroomerBooking(
        bookingId: 707,
        status: 'grooming_completed',
        bookingDate: '2026-10-16',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Daisy',
        customerName: 'David',
        serviceName: 'Full Groom',
        milestoneRecord: GroomerMilestoneRecord(bathCompleted: true, groomingCompleted: true),
      );

      final resRepeatGrooming = await ServicesLocator.groomerHomeRepository.updateServiceMilestone(
        bookingId: 707,
        milestone: 'grooming_completed',
        booking: groomingDoneBooking,
      );

      expect(resRepeatGrooming.success, isFalse);
      expect(resRepeatGrooming.message, contains('Grooming milestone has already been completed'));
    });

    test('Prevents grooming completed before bath completed', () async {
      const inProgressBooking = GroomerBooking(
        bookingId: 708,
        status: 'checked_in',
        bookingDate: '2026-10-16',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Buster',
        customerName: 'Alice',
        serviceName: 'Full Groom',
      );

      final resInvalidGrooming = await ServicesLocator.groomerHomeRepository.updateServiceMilestone(
        bookingId: 708,
        milestone: 'grooming_completed',
        booking: inProgressBooking,
      );

      expect(resInvalidGrooming.success, isFalse);
      expect(resInvalidGrooming.message, contains('Bath milestone must be completed before marking grooming completed'));
    });
  });

  group('Step 7 – GroomerMilestoneDialog Widget Tests', () {
    testWidgets('Renders pet details, stage tracker, and notes text field for Bath milestone', (tester) async {
      const testBooking = GroomerBooking(
        bookingId: 709,
        status: 'in_progress',
        bookingDate: '2026-10-16',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Copper',
        breed: 'Beagle',
        customerName: 'Laura',
        serviceName: 'Bath & Styling',
        specialInstructions: 'Please trim nails short',
        petMedicalNotes: 'Sensitive skin; hypoallergenic shampoo only',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GroomerMilestoneDialog(
              booking: testBooking,
              milestoneType: MilestoneType.bath,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Bath Completed'), findsWidgets);
      expect(find.text('Copper'), findsOneWidget);
      expect(find.text('• Beagle'), findsOneWidget);
      expect(find.text('Customer Request:'), findsOneWidget);
      expect(find.text('"Please trim nails short"'), findsOneWidget);
      expect(find.text('Medical Alert:'), findsOneWidget);
      expect(find.text('"Sensitive skin; hypoallergenic shampoo only"'), findsOneWidget);
      expect(find.text('Milestone Notes (Optional)'), findsOneWidget);
    });

    testWidgets('Renders Grooming milestone dialog with prior bath notes if present', (tester) async {
      const testBooking = GroomerBooking(
        bookingId: 710,
        status: 'bath_completed',
        bookingDate: '2026-10-16',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Luna',
        breed: 'Husky',
        customerName: 'Chris',
        serviceName: 'De-shed & Grooming',
        milestoneRecord: GroomerMilestoneRecord(
          bathCompleted: true,
          bathNotes: 'Double coat blown out thoroughly.',
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GroomerMilestoneDialog(
              booking: testBooking,
              milestoneType: MilestoneType.grooming,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Grooming Completed'), findsWidgets);
      expect(find.text('Bath Note Recorded:'), findsOneWidget);
      expect(find.text('"Double coat blown out thoroughly."'), findsOneWidget);
    });
  });

  group('Step 7 – AllGroomersSchedulePage Milestone Actions & Badges Tests', () {
    testWidgets('Shows Bath Done button for in-progress appointment owned by groomer', (tester) async {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await ServicesLocator.sessionService.saveGroomerUser({
        'id': 2,
        'name': 'Sarah Jenkins',
        'email': 'sarah@groomer.com',
      });

      final bookings = [
        GroomerBooking(
          bookingId: 711,
          status: 'in_progress',
          bookingDate: todayStr,
          startTime: '09:00 AM',
          endTime: '10:00 AM',
          petName: 'Max',
          breed: 'Golden Retriever',
          customerName: 'David Lee',
          serviceName: 'Bath & Brush',
          groomerId: 2,
          groomerName: 'Sarah Jenkins',
        ),
      ];

      final groomers = [
        const SalonGroomer(
          id: 2,
          groomerCode: 'G002',
          firstName: 'Sarah',
          lastName: 'Jenkins',
          name: 'Sarah Jenkins',
          role: 'Master Groomer',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: bookings,
            initialSalonGroomers: groomers,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Bath Done'), findsOneWidget);
    });

    testWidgets('Shows Grooming Done button when bath is completed', (tester) async {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await ServicesLocator.sessionService.saveGroomerUser({
        'id': 2,
        'name': 'Sarah Jenkins',
        'email': 'sarah@groomer.com',
      });

      final bookings = [
        GroomerBooking(
          bookingId: 712,
          status: 'bath_completed',
          bookingDate: todayStr,
          startTime: '09:00 AM',
          endTime: '10:00 AM',
          petName: 'Charlie',
          breed: 'Poodle',
          customerName: 'Grace',
          serviceName: 'Full Groom',
          groomerId: 2,
          groomerName: 'Sarah Jenkins',
          milestoneRecord: const GroomerMilestoneRecord(
            bathCompleted: true,
            bathNotes: 'Conditioner rinsed thoroughly',
          ),
        ),
      ];

      final groomers = [
        const SalonGroomer(
          id: 2,
          groomerCode: 'G002',
          firstName: 'Sarah',
          lastName: 'Jenkins',
          name: 'Sarah Jenkins',
          role: 'Master Groomer',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: bookings,
            initialSalonGroomers: groomers,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Grooming Done'), findsOneWidget);
      expect(find.text('Milestone: Bath Completed'), findsOneWidget);
      expect(find.text('• Bath Notes: "Conditioner rinsed thoroughly"'), findsOneWidget);
    });
  });
}
