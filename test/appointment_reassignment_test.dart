import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/repo/groomer_home_repository.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/appointment_details_sheet.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/reassign_groomer_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  setUp(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  });

  group('Appointment Reassignment Model & Validation Tests', () {
    test('GroomerBooking correctly serializes and parses isPreferredGroomer and reassignmentHistory', () {
      final json = <String, dynamic>{
        'bookingId': 501,
        'status': 'confirmed',
        'bookingDate': '2026-11-10',
        'startTime': '10:00 AM',
        'endTime': '11:00 AM',
        'petName': 'Max',
        'customerName': 'Sarah Connor',
        'serviceName': 'Deluxe Bath & Grooming',
        'groomerId': 2,
        'groomerName': 'Richard Cooke',
        'groomerCode': 'G002',
        'isPreferredGroomer': true,
        'reassignmentHistory': [
          {
            'fromGroomerId': 1,
            'fromGroomerName': 'Marissa Brown',
            'toGroomerId': 2,
            'toGroomerName': 'Richard Cooke',
            'reassignedAt': '2026-11-09T14:30:00Z',
            'reassignedBy': 'Admin',
          }
        ],
      };

      final booking = GroomerBooking.fromJson(json);

      expect(booking.bookingId, equals(501));
      expect(booking.isPreferredGroomer, isTrue);
      expect(booking.reassignmentHistory.length, equals(1));
      expect(booking.reassignmentHistory.first['fromGroomerName'], equals('Marissa Brown'));
      expect(booking.reassignmentHistory.first['toGroomerName'], equals('Richard Cooke'));

      final outJson = booking.toJson();
      expect(outJson['isPreferredGroomer'], isTrue);
      expect(outJson['reassignmentHistory'], isNotEmpty);

      final copied = booking.copyWith(
        isPreferredGroomer: false,
        reassignmentHistory: [],
      );
      expect(copied.isPreferredGroomer, isFalse);
      expect(copied.reassignmentHistory, isEmpty);
    });

    test('BookingDateUtils canonical groomer resolution maps Marissa and Merisa to ID 1', () {
      expect(BookingDateUtils.resolveCanonicalGroomerId(null, groomerName: 'Marissa Brown'), equals(1));
      expect(BookingDateUtils.resolveCanonicalGroomerId(null, groomerName: 'Merisa Brown'), equals(1));
      expect(BookingDateUtils.resolveCanonicalGroomerId(null, groomerName: 'Richard Cooke'), equals(2));
      expect(BookingDateUtils.resolveCanonicalGroomerId(null, groomerCode: 'G001'), equals(1));
      expect(BookingDateUtils.resolveCanonicalGroomerId(null, groomerCode: 'G002'), equals(2));
    });

    test('BookingDateUtils.doSlotsOverlap accurately detects time slot overlaps', () {
      // Overlapping: 10:00-11:00 and 10:30-11:30
      expect(BookingDateUtils.doSlotsOverlap('10:00 AM', '11:00 AM', '10:30 AM', '11:30 AM'), isTrue);
      // Overlapping: exact same slot
      expect(BookingDateUtils.doSlotsOverlap('10:00 AM', '11:00 AM', '10:00 AM', '11:00 AM'), isTrue);
      // Overlapping: outer contains inner
      expect(BookingDateUtils.doSlotsOverlap('09:30 AM', '11:30 AM', '10:00 AM', '11:00 AM'), isTrue);
      // Non-overlapping: back-to-back (10:00-11:00 and 11:00-12:00)
      expect(BookingDateUtils.doSlotsOverlap('10:00 AM', '11:00 AM', '11:00 AM', '12:00 PM'), isFalse);
      // Non-overlapping: completely separate
      expect(BookingDateUtils.doSlotsOverlap('10:00 AM', '11:00 AM', '01:00 PM', '02:00 PM'), isFalse);
    });
  });

  group('Access Control & Authorization Tests (Admin & Groomer)', () {
    const richardBooking = GroomerBooking(
      bookingId: 201,
      status: 'confirmed',
      bookingDate: '2026-11-10',
      startTime: '10:00 AM',
      endTime: '11:00 AM',
      petName: 'Milo',
      customerName: 'Emma Watson',
      serviceName: 'Full Haircut',
      groomerId: 2,
      groomerName: 'Richard Cooke',
      groomerCode: 'G002',
      isPreferredGroomer: false,
    );

    const preferredBooking = GroomerBooking(
      bookingId: 202,
      status: 'confirmed',
      bookingDate: '2026-11-10',
      startTime: '10:00 AM',
      endTime: '11:00 AM',
      petName: 'Rocky',
      customerName: 'John Wick',
      serviceName: 'Bath & Brush',
      groomerId: 2,
      groomerName: 'Richard Cooke',
      groomerCode: 'G002',
      isPreferredGroomer: true, // Customer requested preferred groomer
    );

    test('Currently assigned groomer (Richard) CAN reassign their own non-preferred booking', () async {
      final session = ServicesLocator.sessionService;
      await session.saveGroomerUser({
        'id': 2,
        'groomerId': 2,
        'groomerCode': 'G002',
        'fullName': 'Richard Cooke',
        'role': 'Senior Groomer',
      });

      expect(session.isAdmin, isFalse);
      expect(session.isCurrentGroomerAssigned(richardBooking), isTrue);
      expect(session.canReassignBooking(richardBooking), isTrue);
      expect(session.getReassignDisabledReason(richardBooking), isNull);
    });

    test('Admin CAN reassign non-preferred booking of any groomer', () async {
      final session = ServicesLocator.sessionService;
      await session.saveGroomerUser({
        'id': 99,
        'fullName': 'Store Manager Admin',
        'role': 'store_admin',
        'isAdmin': true,
      });

      expect(session.isAdmin, isTrue);
      expect(session.canReassignBooking(richardBooking), isTrue);
      expect(session.getReassignDisabledReason(richardBooking), isNull);
    });

    test('Other groomer (Tracie) CANNOT reassign Richard\'s booking (Unauthorized)', () async {
      final session = ServicesLocator.sessionService;
      await session.saveGroomerUser({
        'id': 3,
        'groomerId': 3,
        'groomerCode': 'G003',
        'fullName': 'Tracie Jamison',
        'role': 'Senior Stylist',
      });

      expect(session.isAdmin, isFalse);
      expect(session.isCurrentGroomerAssigned(richardBooking), isFalse);
      expect(session.canReassignBooking(richardBooking), isFalse);
      expect(
        session.getReassignDisabledReason(richardBooking),
        contains('Unauthorized'),
      );
    });

    test('Preferred Groomer selection strictly BLOCKS reassignment for both Groomer and Admin', () async {
      final session = ServicesLocator.sessionService;

      // 1. Groomer (Richard) blocked from reassigning preferred booking
      await session.saveGroomerUser({
        'id': 2,
        'groomerId': 2,
        'groomerCode': 'G002',
        'fullName': 'Richard Cooke',
        'role': 'Senior Groomer',
      });
      expect(session.canReassignBooking(preferredBooking), isFalse);
      expect(
        session.getReassignDisabledReason(preferredBooking),
        contains('Preferred Groomer'),
      );

      // 2. Admin also blocked from reassigning preferred booking (preserves customer preference)
      await session.saveGroomerUser({
        'id': 99,
        'role': 'platform_admin',
        'isAdmin': true,
      });
      expect(session.isAdmin, isTrue);
      expect(session.canReassignBooking(preferredBooking), isFalse);
      expect(
        session.getReassignDisabledReason(preferredBooking),
        contains('Preferred Groomer'),
      );
    });
  });

  group('Groomer Availability Check & Overlap Prevention Tests', () {
    const tracie = SalonGroomer(
      id: 3,
      groomerCode: 'G003',
      firstName: 'Tracie',
      lastName: 'Jamison',
      name: 'Tracie Jamison',
      role: 'Senior Stylist',
      isAvailable: true,
    );

    test('getAvailableGroomersForSlot displays ONLY available groomers and excludes current groomer', () async {
      final repo = ServicesLocator.groomerHomeRepository;

      // Exclude Richard (id 2) for slot 10:00 AM - 11:00 AM on 2026-11-10
      final available = await repo.getAvailableGroomersForSlot(
        date: '2026-11-10',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        excludeGroomerId: 2,
      );

      // Richard should NOT be in the available list
      expect(available.any((g) => g.id == 2), isFalse);
      // Marissa should be in the available list
      expect(available.any((g) => g.id == 1 || g.name.contains('Marissa') || g.name.contains('Merisa')), isTrue);
    });

    test('Overlap check excludes target groomer who already has an appointment during the time slot', () async {
      final repo = ServicesLocator.groomerHomeRepository;

      // Give Tracie (id 3) an active booking on 2026-11-10 at 10:00 AM - 11:00 AM
      GroomerHomeRepository.addLocalBooking(const GroomerBooking(
        bookingId: 888,
        status: 'confirmed',
        bookingDate: '2026-11-10',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Daisy',
        customerName: 'Bob Vance',
        serviceName: 'Nail Trim',
        groomerId: 3,
        groomerName: 'Tracie Jamison',
      ));

      final available = await repo.getAvailableGroomersForSlot(
        date: '2026-11-10',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        excludeGroomerId: 2, // Richard is reassigning
      );

      // Tracie has an overlapping appointment -> must NOT be in available groomers
      expect(available.any((g) => g.id == 3), isFalse);
      // Marissa has no conflicting appointment -> MUST be available
      expect(available.any((g) => g.id == 1), isTrue);
    });

    test('Backend reassignBooking rejects overlapping appointment for target groomer', () async {
      final repo = ServicesLocator.groomerHomeRepository;
      final session = ServicesLocator.sessionService;

      // Log in as Admin
      await session.saveGroomerUser({
        'id': 99,
        'role': 'store_admin',
        'isAdmin': true,
      });

      // Target groomer Tracie (id 3) already has a booking at 10:00 AM
      GroomerHomeRepository.addLocalBooking(const GroomerBooking(
        bookingId: 889,
        status: 'confirmed',
        bookingDate: '2026-11-10',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Daisy',
        customerName: 'Bob Vance',
        serviceName: 'Nail Trim',
        groomerId: 3,
        groomerName: 'Tracie Jamison',
      ));

      const apptToReassign = GroomerBooking(
        bookingId: 777,
        status: 'confirmed',
        bookingDate: '2026-11-10',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Buddy',
        customerName: 'Alice',
        serviceName: 'Full Grooming',
        groomerId: 2,
        groomerName: 'Richard Cooke',
      );

      final result = await repo.reassignBooking(
        booking: apptToReassign,
        targetGroomer: tracie,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('overlapping'));
      expect(result.updatedBooking, isNull);
    });
  });

  group('Full Reassignment Workflow Execution Tests', () {
    const marissa = SalonGroomer(
      id: 1,
      groomerCode: 'G001',
      firstName: 'Merisa',
      lastName: 'Brown',
      name: 'Marissa Brown',
      role: 'Lead Groomer',
      isAvailable: true,
    );

    test('Step-by-step workflow: Richard reassigns his 10:00 AM appointment to Marissa', () async {
      final repo = ServicesLocator.groomerHomeRepository;
      final session = ServicesLocator.sessionService;

      // 1. Richard is logged in
      await session.saveGroomerUser({
        'id': 2,
        'groomerId': 2,
        'groomerCode': 'G002',
        'fullName': 'Richard Cooke',
        'role': 'Senior Groomer',
      });

      // 1. Richard has an appointment at 10:00 AM
      const richardsAppt = GroomerBooking(
        bookingId: 301,
        status: 'confirmed',
        bookingDate: '2026-11-15',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Charlie',
        breed: 'Golden Retriever',
        userId: 45,
        customerName: 'David Miller',
        customerEmail: 'david@example.com',
        customerMobile: '555-0199',
        serviceId: 1,
        serviceName: 'Full Grooming',
        totalPrice: 85.0,
        groomerId: 2,
        groomerName: 'Richard Cooke',
        groomerCode: 'G002',
        isPreferredGroomer: false,
      );

      GroomerHomeRepository.addLocalBooking(richardsAppt);

      // Verify initial state: Richard sees this appointment in his schedule
      var richardsUpcoming = await repo.getUpcomingBookings();
      expect(richardsUpcoming.any((b) => b.bookingId == 301), isTrue);

      // 2. Richard is busy and selects Reassign Groomer
      // 3. System checks other groomers' availability for exact same date and time slot
      final availableGroomers = await repo.getAvailableGroomersForSlot(
        date: richardsAppt.bookingDate,
        startTime: richardsAppt.startTime,
        endTime: richardsAppt.endTime,
        excludeGroomerId: richardsAppt.groomerId,
      );

      // 4. Displays ONLY available groomers (Richard excluded, Marissa present)
      expect(availableGroomers.any((g) => g.id == 2), isFalse);
      final marissaOption = availableGroomers.firstWhere(
        (g) => g.id == 1 || g.name.contains('Marissa') || g.name.contains('Merisa'),
      );
      expect(marissaOption, isNotNull);

      // 5. Richard selects Marissa and confirms reassignment
      final reassignResult = await repo.reassignBooking(
        booking: richardsAppt,
        targetGroomer: marissa,
        reassignedBy: 'Richard Cooke',
      );

      // 6. Verification of update and preservation:
      expect(reassignResult.success, isTrue);
      final updated = reassignResult.updatedBooking!;

      // Preserved attributes:
      expect(updated.bookingId, equals(301));
      expect(updated.bookingDate, equals('2026-11-15'));
      expect(updated.startTime, equals('10:00 AM'));
      expect(updated.endTime, equals('11:00 AM'));
      expect(updated.petName, equals('Charlie'));
      expect(updated.customerName, equals('David Miller'));
      expect(updated.customerMobile, equals('555-0199'));
      expect(updated.serviceName, equals('Full Grooming'));
      expect(updated.totalPrice, equals(85.0));

      // Updated attributes:
      expect(updated.groomerId, equals(1));
      expect(updated.groomerName, equals('Marissa Brown'));

      // Assignment history maintained:
      expect(updated.reassignmentHistory.length, equals(1));
      final history = updated.reassignmentHistory.first;
      expect(history['fromGroomerId'], equals(2));
      expect(history['fromGroomerName'], equals('Richard Cooke'));
      expect(history['toGroomerId'], equals(1));
      expect(history['toGroomerName'], equals('Marissa Brown'));
      expect(history['reassignedBy'], equals('Richard Cooke'));

      // Schedule listing update:
      // Richard's schedule listing no longer includes appointment 301
      richardsUpcoming = await repo.getUpcomingBookings();
      expect(richardsUpcoming.any((b) => b.bookingId == 301), isFalse);

      // Switch session to Marissa: Marissa's schedule now reflects appointment 301!
      await session.saveGroomerUser({
        'id': 1,
        'groomerId': 1,
        'groomerCode': 'G001',
        'fullName': 'Marissa Brown',
        'role': 'Lead Groomer',
      });

      final marissasUpcoming = await repo.getUpcomingBookings();
      expect(marissasUpcoming.any((b) => b.bookingId == 301), isTrue);
    });

    test('Admin independently reassigns an appointment to another groomer', () async {
      final repo = ServicesLocator.groomerHomeRepository;
      final session = ServicesLocator.sessionService;

      // Log in as Store Admin
      await session.saveGroomerUser({
        'id': 99,
        'fullName': 'Head Administrator',
        'role': 'store_admin',
        'isAdmin': true,
      });

      const appt = GroomerBooking(
        bookingId: 401,
        status: 'confirmed',
        bookingDate: '2026-11-20',
        startTime: '02:00 PM',
        endTime: '03:00 PM',
        petName: 'Bella',
        customerName: 'Bruce Wayne',
        serviceName: 'De-shedding Treatment',
        groomerId: 2,
        groomerName: 'Richard Cooke',
        isPreferredGroomer: false,
      );

      final result = await repo.reassignBooking(
        booking: appt,
        targetGroomer: marissa,
        reassignedBy: 'Head Administrator',
      );

      expect(result.success, isTrue);
      expect(result.updatedBooking?.groomerId, equals(1));
      expect(result.updatedBooking?.groomerName, equals('Marissa Brown'));
      expect(result.updatedBooking?.reassignmentHistory.first['reassignedBy'], equals('Head Administrator'));
    });
  });

  group('UI Components Integration Tests', () {
    const normalBooking = GroomerBooking(
      bookingId: 601,
      status: 'confirmed',
      bookingDate: '2026-11-12',
      startTime: '10:00 AM',
      endTime: '11:00 AM',
      petName: 'Luna',
      breed: 'Siberian Husky',
      customerName: 'Robert Langdon',
      customerMobile: '555-1234',
      serviceName: 'Full Grooming',
      totalPrice: 90.0,
      groomerId: 2,
      groomerName: 'Richard Cooke',
      groomerCode: 'G002',
      isPreferredGroomer: false,
    );

    const lockedPreferredBooking = GroomerBooking(
      bookingId: 602,
      status: 'confirmed',
      bookingDate: '2026-11-12',
      startTime: '10:00 AM',
      endTime: '11:00 AM',
      petName: 'Max',
      breed: 'Beagle',
      customerName: 'Robert Langdon',
      customerMobile: '555-1234',
      serviceName: 'Full Grooming',
      totalPrice: 90.0,
      groomerId: 2,
      groomerName: 'Richard Cooke',
      groomerCode: 'G002',
      isPreferredGroomer: true,
    );

    testWidgets('AppointmentDetailsSheet displays Preferred Groomer locked banner and disables service assignment dropdown', (tester) async {
      final session = ServicesLocator.sessionService;
      await session.saveGroomerUser({
        'id': 2,
        'groomerId': 2,
        'groomerCode': 'G002',
        'fullName': 'Richard Cooke',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppointmentDetailsSheet(booking: lockedPreferredBooking),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Banner must be visible
      expect(find.byKey(const Key('preferred_groomer_banner')), findsOneWidget);
      expect(find.text('Preferred Groomer Selection'), findsOneWidget);

      // Service line assignment should be locked
      expect(find.text('Assignment disabled'), findsOneWidget);
      expect(find.text('Customer requested preferred groomer. Reassignment to other groomers is disabled.'), findsOneWidget);

      // Duplicated bottom button must not exist
      expect(find.byKey(const Key('reassign_groomer_button_602')), findsNothing);
    });

    testWidgets('AppointmentDetailsSheet provides Service groomer assignments dropdown without duplicate button', (tester) async {
      final session = ServicesLocator.sessionService;
      await session.saveGroomerUser({
        'id': 2,
        'groomerId': 2,
        'groomerCode': 'G002',
        'fullName': 'Richard Cooke',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppointmentDetailsSheet(booking: normalBooking),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Preferred groomer banner is NOT shown
      expect(find.byKey(const Key('preferred_groomer_banner')), findsNothing);

      // Service groomer assignments card is displayed
      expect(find.text('Service groomer assignments'), findsOneWidget);

      // Duplicated bottom button must NOT exist
      expect(find.byKey(const Key('reassign_groomer_button_601')), findsNothing);
    });

    testWidgets('ReassignGroomerDialog renders available groomers and confirms reassignment', (tester) async {
      final session = ServicesLocator.sessionService;
      await session.saveGroomerUser({
        'id': 2,
        'groomerId': 2,
        'groomerCode': 'G002',
        'fullName': 'Richard Cooke',
      });

      GroomerBooking? resultBooking;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  ReassignGroomerDialog.show(
                    ctx,
                    booking: normalBooking,
                    onReassigned: (updated) {
                      resultBooking = updated;
                    },
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Dialog is open
      expect(find.text('Reassign Groomer'), findsOneWidget);
      expect(find.textContaining('Currently Assigned: Richard Cooke'), findsOneWidget);

      // Verify Marissa Brown is in the available groomers list
      final marissaTile = find.text('Marissa Brown');
      expect(marissaTile, findsOneWidget);

      // Select Marissa Brown
      await tester.tap(marissaTile);
      await tester.pumpAndSettle();

      // Confirm Reassignment button should now be enabled
      final confirmBtnFinder = find.byKey(const Key('confirm_reassignment_button'));
      expect(confirmBtnFinder, findsOneWidget);
      await tester.tap(confirmBtnFinder);
      await tester.pumpAndSettle();

      // Confirmation prompt appears
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);

      // Confirm
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      // Reassignment completed
      expect(resultBooking, isNotNull);
      expect(resultBooking!.groomerId, equals(1));
      expect(resultBooking!.groomerName, equals('Marissa Brown'));
    });
  });
}
