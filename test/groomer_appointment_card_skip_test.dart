import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_milestone_record.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/all_groomers/all_groomers_schedule_page.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/mobile/groomer_home_page_mobile.dart';

class _MockApiRepository extends ApiRepository {
  String? lastPostPath;
  dynamic lastPostData;
  int postCallCount = 0;

  void reset() {
    lastPostPath = null;
    lastPostData = null;
    postCallCount = 0;
  }

  @override
  Future<Map<String, dynamic>?> post(String path, dynamic data, {Map<String, dynamic>? query}) async {
    lastPostPath = path;
    lastPostData = data;
    postCallCount++;
    final milestone = (data is Map) ? (data['milestone'] ?? data['milestoneKey']) : null;
    return {
      'success': true,
      'message': milestone == 'ready_for_checkout'
          ? 'Appointment marked as Ready for Checkout.'
          : 'Milestone updated successfully.',
      'data': {
        'status': milestone ?? 'ready_for_checkout',
        'milestone': milestone,
      },
    };
  }
}

late _MockApiRepository _mockApi;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();

    if (GetIt.I.isRegistered<ApiRepository>()) {
      GetIt.I.unregister<ApiRepository>();
    }
    _mockApi = _MockApiRepository();
    GetIt.I.registerSingleton<ApiRepository>(_mockApi);
  });

  setUp(() {
    _mockApi.reset();
  });

  group('Skip Option – Eligibility & Model Tests', () {
    test('Skip option is HIDDEN before check-in is completed', () {
      const confirmedUncheckedIn = GroomerBooking(
        bookingId: 901,
        status: 'confirmed',
        customerName: 'Alice',
        petName: 'Milo',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-17',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        totalPrice: 65.0,
      );

      expect(confirmedUncheckedIn.isCheckedIn, isFalse);
      expect(confirmedUncheckedIn.canShowSkipOption, isFalse);
    });

    test('Skip option is VISIBLE immediately after check-in is completed', () {
      const checkedInBooking = GroomerBooking(
        bookingId: 902,
        status: 'checked_in',
        customerName: 'Alice',
        petName: 'Milo',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-17',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        totalPrice: 65.0,
      );

      expect(checkedInBooking.isCheckedIn, isTrue);
      expect(checkedInBooking.areRequiredMilestonesCompleted, isFalse);
      expect(checkedInBooking.canShowSkipOption, isTrue);
    });

    test('Skip option is VISIBLE during in-progress when intermediate milestones are pending', () {
      const inProgressBooking = GroomerBooking(
        bookingId: 903,
        status: 'in_progress',
        customerName: 'Bob',
        petName: 'Bella',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-17',
        startTime: '11:00 AM',
        endTime: '12:00 PM',
        totalPrice: 75.0,
        milestoneRecord: GroomerMilestoneRecord(
          bathCompleted: true,
          groomingCompleted: false,
        ),
      );

      expect(inProgressBooking.isCheckedIn, isTrue);
      expect(inProgressBooking.isBathCompleted, isTrue);
      expect(inProgressBooking.isGroomingCompleted, isFalse);
      expect(inProgressBooking.areRequiredMilestonesCompleted, isFalse);
      expect(inProgressBooking.canShowSkipOption, isTrue);
    });

    test('Skip option is HIDDEN when all required milestones are already completed', () {
      const milestonesDoneBooking = GroomerBooking(
        bookingId: 904,
        status: 'grooming_completed',
        customerName: 'Carol',
        petName: 'Charlie',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-17',
        startTime: '01:00 PM',
        endTime: '02:00 PM',
        totalPrice: 85.0,
        milestoneRecord: GroomerMilestoneRecord(
          bathCompleted: true,
          groomingCompleted: true,
        ),
      );

      expect(milestonesDoneBooking.isCheckedIn, isTrue);
      expect(milestonesDoneBooking.areRequiredMilestonesCompleted, isTrue);
      expect(milestonesDoneBooking.canShowSkipOption, isFalse);
    });

    test('Skip option is HIDDEN once appointment reaches ready_for_checkout', () {
      const readyBooking = GroomerBooking(
        bookingId: 905,
        status: 'ready_for_checkout',
        customerName: 'David',
        petName: 'Daisy',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-17',
        startTime: '02:00 PM',
        endTime: '03:00 PM',
        totalPrice: 90.0,
        milestoneRecord: GroomerMilestoneRecord(
          readyForCheckoutCompleted: true,
        ),
      );

      expect(readyBooking.isReadyForCheckout, isTrue);
      expect(readyBooking.canShowSkipOption, isFalse);
    });

    test('Skip option is HIDDEN once appointment is completed', () {
      const completedBooking = GroomerBooking(
        bookingId: 906,
        status: 'completed',
        customerName: 'Eve',
        petName: 'Rusty',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-17',
        startTime: '03:00 PM',
        endTime: '04:00 PM',
        totalPrice: 95.0,
      );

      expect(completedBooking.isCompleted, isTrue);
      expect(completedBooking.canShowSkipOption, isFalse);
    });

    test('Skip option is HIDDEN for pending or cancelled appointments', () {
      const pendingBooking = GroomerBooking(
        bookingId: 907,
        status: 'pending',
        customerName: 'Frank',
        petName: 'Max',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-17',
        startTime: '04:00 PM',
        endTime: '05:00 PM',
        totalPrice: 60.0,
      );
      expect(pendingBooking.canShowSkipOption, isFalse);

      const cancelledBooking = GroomerBooking(
        bookingId: 908,
        status: 'cancelled',
        customerName: 'Grace',
        petName: 'Luna',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-17',
        startTime: '05:00 PM',
        endTime: '06:00 PM',
        totalPrice: 60.0,
      );
      expect(cancelledBooking.canShowSkipOption, isFalse);
    });
  });

  group('Skip Option – Repository Guard & Skip Action Tests', () {
    test('markReadyForCheckoutDetails REJECTS transition before check-in is complete', () async {
      const unCheckedInBooking = GroomerBooking(
        bookingId: 910,
        status: 'confirmed',
        customerName: 'Hank',
        petName: 'Rocky',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-17',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        totalPrice: 70.0,
      );

      final res = await ServicesLocator.groomerHomeRepository.markReadyForCheckoutDetails(
        bookingId: 910,
        booking: unCheckedInBooking,
        skipMilestones: true,
      );

      expect(res.success, isFalse);
      expect(res.message, contains('Check-in must be completed before marking appointment ready for checkout.'));
      expect(_mockApi.postCallCount, equals(0));
    });

    test('markReadyForCheckoutDetails allows skipping milestones and sends skipMilestones: true in payload', () async {
      const checkedInBooking = GroomerBooking(
        bookingId: 911,
        status: 'checked_in',
        customerName: 'Ivy',
        petName: 'Coco',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-17',
        startTime: '11:00 AM',
        endTime: '12:00 PM',
        totalPrice: 80.0,
      );

      final res = await ServicesLocator.groomerHomeRepository.markReadyForCheckoutDetails(
        bookingId: 911,
        booking: checkedInBooking,
        skipMilestones: true,
      );

      expect(res.success, isTrue);
      expect(res.updatedBooking, isNotNull);
      expect(res.updatedBooking!.status, equals('ready_for_checkout'));
      expect(res.updatedBooking!.isReadyForCheckout, isTrue);

      expect(_mockApi.postCallCount, greaterThan(0));
      expect(_mockApi.lastPostPath, contains('/bookings/911/milestone'));
      expect(_mockApi.lastPostData, isA<Map<String, dynamic>>());
      final payload = _mockApi.lastPostData as Map<String, dynamic>;
      expect(payload['skipMilestones'], isTrue);
      expect(payload['milestoneKey'], equals('ready_for_checkout'));
    });
  });

  group('Skip Option – AllGroomersSchedulePage UI Tests', () {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final testGroomers = [
      const SalonGroomer(
        id: 1,
        groomerCode: 'G001',
        firstName: 'John',
        lastName: 'Doe',
        name: 'John Doe',
      ),
      const SalonGroomer(
        id: 99,
        groomerCode: 'G099',
        firstName: 'Other',
        lastName: 'Groomer',
        name: 'Other Groomer',
      ),
    ];

    setUp(() async {
      await ServicesLocator.sessionService.saveGroomerUser({
        'id': 1,
        'name': 'John Doe',
        'email': 'john@groomer.com',
        'groomerCode': 'G001',
      });
    });

    testWidgets('Does NOT display Skip button on confirmed card before check-in', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bookings = [
        GroomerBooking(
          bookingId: 921,
          status: 'confirmed',
          customerName: 'Sam',
          petName: 'Rusty',
          serviceName: 'Full Groom',
          bookingDate: todayStr,
          startTime: '09:00 AM',
          endTime: '10:00 AM',
          totalPrice: 80.0,
          groomerId: 1,
          groomerCode: 'G001',
          groomerName: 'John Doe',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: bookings,
            initialSalonGroomers: testGroomers,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('appointment_skip_button_921')), findsNothing);
      expect(find.text('Check In'), findsOneWidget);
    });

    testWidgets('Displays Skip button on the left side of the card after check-in', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bookings = [
        GroomerBooking(
          bookingId: 922,
          status: 'checked_in',
          customerName: 'Sam',
          petName: 'Rusty',
          serviceName: 'Full Groom',
          bookingDate: todayStr,
          startTime: '09:00 AM',
          endTime: '10:00 AM',
          totalPrice: 80.0,
          groomerId: 1,
          groomerCode: 'G001',
          groomerName: 'John Doe',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: bookings,
            initialSalonGroomers: testGroomers,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final skipFinder = find.byKey(const Key('appointment_skip_button_922'));
      expect(skipFinder, findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.byIcon(Icons.fast_forward_rounded), findsOneWidget);

      final badgeFinder = find.text('Groomer: John Doe');
      expect(badgeFinder, findsOneWidget);
    });

    testWidgets('Displays Skip button during in-progress service on AllGroomersSchedulePage', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bookings = [
        GroomerBooking(
          bookingId: 923,
          status: 'in_progress',
          customerName: 'Sam',
          petName: 'Rusty',
          serviceName: 'Full Groom',
          bookingDate: todayStr,
          startTime: '09:00 AM',
          endTime: '10:00 AM',
          totalPrice: 80.0,
          groomerId: 1,
          groomerCode: 'G001',
          groomerName: 'John Doe',
          milestoneRecord: const GroomerMilestoneRecord(
            bathCompleted: true,
            groomingCompleted: false,
          ),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: bookings,
            initialSalonGroomers: testGroomers,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('appointment_skip_button_923')), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Grooming Done'), findsOneWidget);
    });

    testWidgets('Does NOT display Skip button on another groomer\'s appointment card (read-only)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bookings = [
        GroomerBooking(
          bookingId: 924,
          status: 'in_progress',
          customerName: 'Sam',
          petName: 'Rusty',
          serviceName: 'Full Groom',
          bookingDate: todayStr,
          startTime: '09:00 AM',
          endTime: '10:00 AM',
          totalPrice: 80.0,
          groomerId: 99, // Another groomer
          groomerCode: 'G099',
          groomerName: 'Other Groomer',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: bookings,
            initialSalonGroomers: testGroomers,
            initialGroomerFilterId: 'all',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('appointment_skip_button_924')), findsNothing);
      expect(find.text('Read-only'), findsOneWidget);
    });

    testWidgets('Tapping Skip on AllGroomersSchedulePage executes skip & marks ready for checkout', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bookings = [
        GroomerBooking(
          bookingId: 925,
          status: 'in_progress',
          customerName: 'Sam',
          petName: 'Rusty',
          serviceName: 'Full Groom',
          bookingDate: todayStr,
          startTime: '09:00 AM',
          endTime: '10:00 AM',
          totalPrice: 80.0,
          groomerId: 1,
          groomerCode: 'G001',
          groomerName: 'John Doe',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: bookings,
            initialSalonGroomers: testGroomers,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final skipBtn = find.byKey(const Key('appointment_skip_button_925'));
      expect(skipBtn, findsOneWidget);

      await tester.tap(skipBtn);
      await tester.pumpAndSettle();

      // Card should now be updated to ready_for_checkout
      expect(find.text('Ready for Checkout'), findsWidgets);
      // Skip button disappears once in ready_for_checkout
      expect(find.byKey(const Key('appointment_skip_button_925')), findsNothing);
    });
  });

  group('Skip Option – GroomerHomePageMobile UI Tests', () {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    setUp(() async {
      await ServicesLocator.sessionService.saveGroomerUser({
        'id': 1,
        'name': 'John Doe',
        'email': 'john@groomer.com',
        'groomerCode': 'G001',
      });
    });

    testWidgets('GroomerHomePageMobile renders Skip button on left side of in-progress card', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bookings = [
        GroomerBooking(
          bookingId: 931,
          status: 'in_progress',
          customerName: 'Leo',
          petName: 'Simba',
          serviceName: 'Full Groom',
          bookingDate: todayStr,
          startTime: '10:00 AM',
          endTime: '11:00 AM',
          totalPrice: 75.0,
          groomerId: 1,
          groomerCode: 'G001',
          groomerName: 'John Doe',
          milestoneRecord: const GroomerMilestoneRecord(
            bathCompleted: false,
          ),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: GroomerHomePageMobile(
            initialBookings: bookings,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final skipFinder = find.byKey(const Key('appointment_skip_button_931'));
      expect(skipFinder, findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Bath Done'), findsOneWidget);

      // Verify skip button is to the left of the milestone button
      final skipTopLeft = tester.getTopLeft(skipFinder);
      final bathBtn = find.text('Bath Done');
      final bathTopLeft = tester.getTopLeft(bathBtn);
      expect(skipTopLeft.dx, lessThan(bathTopLeft.dx));
    });

    testWidgets('GroomerHomePageMobile hides Skip button once booking is ready_for_checkout', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bookings = [
        GroomerBooking(
          bookingId: 932,
          status: 'ready_for_checkout',
          customerName: 'Maya',
          petName: 'Chloe',
          serviceName: 'Full Groom',
          bookingDate: todayStr,
          startTime: '11:00 AM',
          endTime: '12:00 PM',
          totalPrice: 85.0,
          groomerId: 1,
          groomerCode: 'G001',
          groomerName: 'John Doe',
          milestoneRecord: const GroomerMilestoneRecord(
            readyForCheckoutCompleted: true,
          ),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: GroomerHomePageMobile(
            initialBookings: bookings,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('appointment_skip_button_932')), findsNothing);
      expect(find.text('Ready for Checkout'), findsWidgets);
    });

    testWidgets('Tapping Skip on GroomerHomePageMobile marks booking ready for checkout', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final bookings = [
        GroomerBooking(
          bookingId: 933,
          status: 'in_progress',
          customerName: 'Nina',
          petName: 'Jasper',
          serviceName: 'Full Groom',
          bookingDate: todayStr,
          startTime: '01:00 PM',
          endTime: '02:00 PM',
          totalPrice: 80.0,
          groomerId: 1,
          groomerCode: 'G001',
          groomerName: 'John Doe',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: GroomerHomePageMobile(
            initialBookings: bookings,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final skipBtn = find.byKey(const Key('appointment_skip_button_933'));
      expect(skipBtn, findsOneWidget);

      await tester.tap(skipBtn);
      await tester.pumpAndSettle();

      // Booking moves to ready for checkout
      expect(find.text('Ready for Checkout'), findsWidgets);
      expect(find.byKey(const Key('appointment_skip_button_933')), findsNothing);
    });
  });
}
