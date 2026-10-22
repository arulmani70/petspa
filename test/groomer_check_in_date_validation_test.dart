import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
import 'package:toastification/toastification.dart';
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

  tearDown(() {
    BookingDateUtils.customNow = null;
    BookingDateUtils.storeTimeZoneOffset = null;
  });

  group('Check-In Date Validation – BookingDateUtils Date & Timezone Tests', () {
    test('isBookingDateToday returns true only for today and false for yesterday/tomorrow', () {
      final now = DateTime(2026, 10, 20, 14, 0);
      BookingDateUtils.customNow = now;

      expect(BookingDateUtils.isBookingDateToday('2026-10-20'), isTrue);
      expect(BookingDateUtils.isBookingDateToday('2026-10-19'), isFalse);
      expect(BookingDateUtils.isBookingDateToday('2026-10-21'), isFalse);
    });

    test('isBeforeBookingDate and isAfterBookingDate detect past and future dates', () {
      final now = DateTime(2026, 10, 20, 14, 0);
      BookingDateUtils.customNow = now;

      // Tomorrow is after now, so now is before booking date
      expect(BookingDateUtils.isBeforeBookingDate('2026-10-21'), isTrue);
      expect(BookingDateUtils.isAfterBookingDate('2026-10-21'), isFalse);

      // Yesterday is before now, so now is after booking date
      expect(BookingDateUtils.isBeforeBookingDate('2026-10-19'), isFalse);
      expect(BookingDateUtils.isAfterBookingDate('2026-10-19'), isTrue);

      // Today
      expect(BookingDateUtils.isBeforeBookingDate('2026-10-20'), isFalse);
      expect(BookingDateUtils.isAfterBookingDate('2026-10-20'), isFalse);
    });

    test('extractTimeZoneOffset parses ISO offsets correctly and ignores pure dates', () {
      expect(BookingDateUtils.extractTimeZoneOffset('2026-10-20'), isNull);
      expect(BookingDateUtils.extractTimeZoneOffset('10/20/2026'), isNull);
      expect(BookingDateUtils.extractTimeZoneOffset('2026-10-20T10:00:00Z'), equals(Duration.zero));
      expect(BookingDateUtils.extractTimeZoneOffset('2026-10-20T10:00:00+05:30'), equals(const Duration(hours: 5, minutes: 30)));
      expect(BookingDateUtils.extractTimeZoneOffset('2026-10-20T10:00:00-05:00'), equals(const Duration(hours: -5)));
      expect(BookingDateUtils.extractTimeZoneOffset('2026-10-20T10:00:00-06:00'), equals(const Duration(hours: -6)));
    });

    test('Handles timezone boundary where device time is next day but store is current day', () {
      final storeOffset = const Duration(hours: -5);
      final refStoreDate = DateTime(2026, 10, 20, 21, 0);

      expect(
        BookingDateUtils.isBookingDateToday(
          '2026-10-20',
          referenceDate: refStoreDate,
          timeZoneOffset: storeOffset,
        ),
        isTrue,
      );

      expect(
        BookingDateUtils.isBookingDateToday(
          '2026-10-21',
          referenceDate: refStoreDate,
          timeZoneOffset: storeOffset,
        ),
        isFalse,
      );
    });
  });

  group('Check-In Date Validation – GroomerBooking.canCheckIn() Tests', () {
    final baseBooking = const GroomerBooking(
      bookingId: 101,
      status: 'confirmed',
      bookingDate: '2026-10-20',
      startTime: '10:00 AM',
      endTime: '11:00 AM',
      petName: 'Max',
      customerName: 'Jane Doe',
      serviceName: 'Full Grooming',
    );

    test('canCheckIn is TRUE for confirmed booking on scheduled booking date', () {
      BookingDateUtils.customNow = DateTime(2026, 10, 20, 10, 0);
      expect(baseBooking.canCheckIn(), isTrue);
      expect(baseBooking.isScheduledForToday(), isTrue);
      expect(baseBooking.isBeforeScheduledDate(), isFalse);
      expect(baseBooking.isAfterScheduledDate(), isFalse);
    });

    test('canCheckIn is FALSE for appointment scheduled yesterday (past booking date)', () {
      BookingDateUtils.customNow = DateTime(2026, 10, 21, 10, 0);
      // Appointment was on Oct 20, today is Oct 21
      expect(baseBooking.canCheckIn(), isFalse);
      expect(baseBooking.isScheduledForToday(), isFalse);
      expect(baseBooking.isBeforeScheduledDate(), isFalse);
      expect(baseBooking.isAfterScheduledDate(), isTrue);
    });

    test('canCheckIn is FALSE for appointment scheduled tomorrow (future booking date)', () {
      BookingDateUtils.customNow = DateTime(2026, 10, 19, 10, 0);
      // Appointment is on Oct 20, today is Oct 19
      expect(baseBooking.canCheckIn(), isFalse);
      expect(baseBooking.isScheduledForToday(), isFalse);
      expect(baseBooking.isBeforeScheduledDate(), isTrue);
      expect(baseBooking.isAfterScheduledDate(), isFalse);
    });

    test('canCheckIn is FALSE even today if status is cancelled, rejected, or pending', () {
      BookingDateUtils.customNow = DateTime(2026, 10, 20, 10, 0);

      expect(baseBooking.copyWith(status: 'cancelled').canCheckIn(), isFalse);
      expect(baseBooking.copyWith(status: 'rejected').canCheckIn(), isFalse);
      expect(baseBooking.copyWith(status: 'pending').canCheckIn(), isFalse);
    });

    test('canCheckIn is FALSE if already checked in or completed', () {
      BookingDateUtils.customNow = DateTime(2026, 10, 20, 10, 0);

      expect(baseBooking.copyWith(status: 'checked_in').canCheckIn(), isFalse);
      expect(baseBooking.copyWith(status: 'in_service').canCheckIn(), isFalse);
      expect(baseBooking.copyWith(status: 'completed').canCheckIn(), isFalse);
    });
  });

  group('Check-In Date Validation – GroomerHomeRepository Gatekeeper Tests', () {
    test('checkInBooking blocks appointments scheduled before today (yesterday)', () async {
      BookingDateUtils.customNow = DateTime(2026, 10, 20, 12, 0);
      final yesterdayBooking = const GroomerBooking(
        bookingId: 881,
        status: 'confirmed',
        bookingDate: '2026-10-19',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Bella',
        customerName: 'Alice',
        serviceName: 'Bath',
      );

      final res = await ServicesLocator.groomerHomeRepository.checkInBooking(
        bookingId: yesterdayBooking.bookingId,
        vaccinationVerified: true,
        healthVerified: true,
        customerRequestAcknowledged: true,
        booking: yesterdayBooking,
      );

      expect(res.success, isFalse);
      expect(res.message, contains('has passed'));
    });

    test('checkInBooking blocks appointments scheduled after today (tomorrow)', () async {
      BookingDateUtils.customNow = DateTime(2026, 10, 20, 12, 0);
      final tomorrowBooking = const GroomerBooking(
        bookingId: 882,
        status: 'confirmed',
        bookingDate: '2026-10-21',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Rocky',
        customerName: 'Bob',
        serviceName: 'Full Grooming',
      );

      final res = await ServicesLocator.groomerHomeRepository.checkInBooking(
        bookingId: tomorrowBooking.bookingId,
        vaccinationVerified: true,
        healthVerified: true,
        customerRequestAcknowledged: true,
        booking: tomorrowBooking,
      );

      expect(res.success, isFalse);
      expect(res.message, contains('scheduled booking date'));
    });

    test('updateServiceMilestone check_in_completed blocks non-today bookings', () async {
      BookingDateUtils.customNow = DateTime(2026, 10, 20, 12, 0);
      final tomorrowBooking = const GroomerBooking(
        bookingId: 883,
        status: 'confirmed',
        bookingDate: '2026-10-21',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Daisy',
        customerName: 'Carol',
        serviceName: 'Bath',
      );

      final res = await ServicesLocator.groomerHomeRepository.updateServiceMilestone(
        bookingId: 883,
        milestone: 'check_in_completed',
        booking: tomorrowBooking,
      );

      expect(res.success, isFalse);
      expect(res.message, contains('scheduled booking date'));
    });
  });

  group('Check-In Date Validation – GroomerCheckInDialog UI Tests', () {
    testWidgets('GroomerCheckInDialog shows warning banner and disables submit for tomorrow appointment', (tester) async {
      BookingDateUtils.customNow = DateTime(2026, 10, 20, 12, 0);
      final tomorrowBooking = const GroomerBooking(
        bookingId: 884,
        status: 'confirmed',
        bookingDate: '2026-10-21',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Milo',
        customerName: 'Claire',
        serviceName: 'Bath & Brush',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroomerCheckInDialog(booking: tomorrowBooking),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Warning banner should be present with scheduled date message
      expect(find.textContaining('Check-in will open on the scheduled booking date'), findsOneWidget);

      // Confirm button is disabled
      final confirmBtnFinder = find.widgetWithText(ElevatedButton, 'Confirm Check-in');
      expect(confirmBtnFinder, findsOneWidget);
      final btn = tester.widget<ElevatedButton>(confirmBtnFinder);
      expect(btn.onPressed, isNull);
    });

    testWidgets('GroomerCheckInDialog shows warning banner and disables submit for yesterday appointment', (tester) async {
      BookingDateUtils.customNow = DateTime(2026, 10, 20, 12, 0);
      final yesterdayBooking = const GroomerBooking(
        bookingId: 885,
        status: 'confirmed',
        bookingDate: '2026-10-19',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Luna',
        customerName: 'David',
        serviceName: 'Bath & Brush',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroomerCheckInDialog(booking: yesterdayBooking),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Warning banner should be present with passed date message
      expect(find.textContaining('Check-in is closed because the scheduled booking date'), findsOneWidget);

      // Confirm button is disabled
      final confirmBtnFinder = find.widgetWithText(ElevatedButton, 'Confirm Check-in');
      expect(confirmBtnFinder, findsOneWidget);
      final btn = tester.widget<ElevatedButton>(confirmBtnFinder);
      expect(btn.onPressed, isNull);
    });

    testWidgets('GroomerCheckInDialog.show() prevents opening dialog when appointment is not today', (tester) async {
      BookingDateUtils.customNow = DateTime(2026, 10, 20, 12, 0);
      final tomorrowBooking = const GroomerBooking(
        bookingId: 886,
        status: 'confirmed',
        bookingDate: '2026-10-21',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Ollie',
        customerName: 'Emma',
        serviceName: 'Bath & Brush',
      );

      late BuildContext testContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              testContext = ctx;
              return const Scaffold(body: Text('Home'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final result = await GroomerCheckInDialog.show(
        testContext,
        booking: tomorrowBooking,
      );

      // Dialog should immediately return null without presenting
      expect(result, isNull);
      await tester.pumpAndSettle();
      expect(find.text('Pet Intake & Check-in'), findsNothing);
    });
  });

  group('Check-In Date Validation – AllGroomersSchedulePage UI Tests', () {
    testWidgets('Check In button is enabled on today schedule, disabled on tomorrow and yesterday schedule', (tester) async {
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

      final todayStr = BookingDateUtils.formatDate(DateTime.now());
      final tomorrowStr = BookingDateUtils.formatDate(DateTime.now().add(const Duration(days: 1)));
      final yesterdayStr = BookingDateUtils.formatDate(DateTime.now().subtract(const Duration(days: 1)));

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

      final todayBooking = GroomerBooking(
        bookingId: 901,
        status: 'confirmed',
        bookingDate: todayStr,
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        petName: 'TodayDog',
        customerName: 'Owner One',
        serviceName: 'Bath & Brush',
        groomerId: 1,
      );

      final tomorrowBooking = GroomerBooking(
        bookingId: 902,
        status: 'confirmed',
        bookingDate: tomorrowStr,
        startTime: '11:00 AM',
        endTime: '12:00 PM',
        petName: 'TomorrowDog',
        customerName: 'Owner Two',
        serviceName: 'Full Grooming',
        groomerId: 1,
      );

      final yesterdayBooking = GroomerBooking(
        bookingId: 903,
        status: 'confirmed',
        bookingDate: yesterdayStr,
        startTime: '01:00 PM',
        endTime: '02:00 PM',
        petName: 'YesterdayDog',
        customerName: 'Owner Three',
        serviceName: 'Nail Trim',
        groomerId: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: [todayBooking, tomorrowBooking, yesterdayBooking],
            initialSalonGroomers: salonGroomers,
            initialGroomerFilterId: '1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. On today's date view: Today's booking Check In button is enabled
      final todayCheckInBtnFinder = find.widgetWithText(ElevatedButton, 'Check In');
      expect(todayCheckInBtnFinder, findsOneWidget);
      final todayBtn = tester.widget<ElevatedButton>(todayCheckInBtnFinder);
      expect(todayBtn.onPressed, isNotNull);

      // 2. Navigate to tomorrow using next day chevron
      final nextDayBtnFinder = find.byIcon(Icons.chevron_right_rounded);
      expect(nextDayBtnFinder, findsOneWidget);
      await tester.tap(nextDayBtnFinder);
      await tester.pumpAndSettle();

      // On tomorrow's date view: TomorrowDog is displayed, Check In button is disabled
      expect(find.text('TomorrowDog'), findsOneWidget);
      final tomorrowCheckInBtnFinder = find.widgetWithText(ElevatedButton, 'Check In');
      expect(tomorrowCheckInBtnFinder, findsOneWidget);
      final tomorrowBtn = tester.widget<ElevatedButton>(tomorrowCheckInBtnFinder);
      expect(tomorrowBtn.onPressed, isNull);

      // 3. Navigate back to today, then yesterday (2 taps on chevron left)
      final prevDayBtnFinder = find.byIcon(Icons.chevron_left_rounded);
      expect(prevDayBtnFinder, findsOneWidget);
      await tester.tap(prevDayBtnFinder);
      await tester.pumpAndSettle();
      await tester.tap(prevDayBtnFinder);
      await tester.pumpAndSettle();

      // On yesterday's date view: YesterdayDog is displayed, Check In button is disabled
      expect(find.text('YesterdayDog'), findsOneWidget);
      final yesterdayCheckInBtnFinder = find.widgetWithText(ElevatedButton, 'Check In');
      expect(yesterdayCheckInBtnFinder, findsOneWidget);
      final yesterdayBtn = tester.widget<ElevatedButton>(yesterdayCheckInBtnFinder);
      expect(yesterdayBtn.onPressed, isNull);
    });

    testWidgets('Checked in appointment displays Checked In badge on schedule page', (tester) async {
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

      final todayStr = BookingDateUtils.formatDate(DateTime.now());

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

      final checkedInBooking = GroomerBooking(
        bookingId: 904,
        status: 'checked_in',
        bookingDate: todayStr,
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Rusty',
        customerName: 'Sam',
        serviceName: 'Full Grooming',
        groomerId: 1,
        checkInRecord: const GroomerCheckInRecord(
          vaccinationVerified: true,
          healthVerified: true,
          customerRequestAcknowledged: true,
          groomerCheckInNotes: 'Checked in fine',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: [checkedInBooking],
            initialSalonGroomers: salonGroomers,
            initialGroomerFilterId: '1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Displays Checked In status badge, not Check In button
      expect(find.text('Check In'), findsNothing);
      expect(find.textContaining('Checked In'), findsWidgets);
    });
  });

  group('Groomer Check-In Error Message Handling (Defect Fix - Route Not Found -> Clear Message)', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = ServicesLocator.apiRepository.dio.httpClientAdapter;
    });

    tearDown(() {
      ServicesLocator.apiRepository.dio.httpClientAdapter = originalAdapter;
      BookingDateUtils.customNow = null;
    });

    test('GroomerBooking.fromJson parses booking_date and appointmentDate appropriately', () {
      BookingDateUtils.customNow = DateTime(2026, 10, 20, 10, 0);
      final jsonSnake = {
        'id': 701,
        'booking_date': '2026-10-21',
        'status': 'confirmed',
        'startTime': '10:00 AM',
        'endTime': '11:00 AM',
        'petName': 'Mochi',
        'customerName': 'Tina',
        'serviceName': 'Bath',
      };
      final b1 = GroomerBooking.fromJson(jsonSnake);
      expect(b1.bookingDate, equals('2026-10-21'));
      expect(b1.formattedBookingDate, equals('21 Oct 2026'));

      final jsonAppt = {
        'id': 702,
        'appointmentDate': '2026-10-22',
        'status': 'confirmed',
        'startTime': '10:00 AM',
        'endTime': '11:00 AM',
        'petName': 'Mochi',
        'customerName': 'Tina',
        'serviceName': 'Bath',
      };
      final b2 = GroomerBooking.fromJson(jsonAppt);
      expect(b2.bookingDate, equals('2026-10-22'));
      expect(b2.formattedBookingDate, equals('22 Oct 2026'));
    });

    test('checkInBooking maps Route Not Found 404 response to user-friendly scheduled booking date message for next-day appointment', () async {
      BookingDateUtils.customNow = DateTime(2026, 10, 20, 10, 0);

      final tomorrowBooking = const GroomerBooking(
        bookingId: 955,
        status: 'confirmed',
        bookingDate: '2026-10-21',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Barnaby',
        customerName: 'George',
        serviceName: 'Full Grooming',
      );

      // Simulate backend returning 404 "Route Not Found"
      ServicesLocator.apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        return MockAdapter.json({
          'success': false,
          'message': 'Route Not Found: POST ${options.path}',
        }, 404);
      });

      final res = await ServicesLocator.groomerHomeRepository.checkInBooking(
        bookingId: tomorrowBooking.bookingId,
        vaccinationVerified: true,
        healthVerified: true,
        customerRequestAcknowledged: true,
        booking: tomorrowBooking,
      );

      expect(res.success, isFalse);
      expect(res.message, isNot(contains('Route Not Found')));
      expect(res.message, contains('Check-in is only allowed on the scheduled booking date (21 Oct 2026)'));
    });

    test('checkInBooking maps Route Not Found 404 response to clear error even if booking argument is null', () async {
      BookingDateUtils.customNow = DateTime(2026, 10, 20, 10, 0);

      // Simulate backend returning 404 "Route Not Found"
      ServicesLocator.apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        return MockAdapter.json({
          'success': false,
          'message': 'Route Not Found',
        }, 404);
      });

      final res = await ServicesLocator.groomerHomeRepository.checkInBooking(
        bookingId: 9999,
        vaccinationVerified: true,
        healthVerified: true,
        customerRequestAcknowledged: true,
        booking: null,
      );

      expect(res.success, isFalse);
      expect(res.message, isNot(contains('Route Not Found')));
      expect(res.message, contains('Check-in is only allowed on the scheduled booking date'));
    });

    test('updateServiceMilestone check_in_completed maps Route Not Found 404 to clear date error message', () async {
      BookingDateUtils.customNow = DateTime(2026, 10, 20, 10, 0);

      final tomorrowBooking = const GroomerBooking(
        bookingId: 956,
        status: 'confirmed',
        bookingDate: '2026-10-21',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Barnaby',
        customerName: 'George',
        serviceName: 'Full Grooming',
      );

      ServicesLocator.apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        return MockAdapter.json({
          'success': false,
          'message': 'Route not found: POST ${options.path}',
        }, 404);
      });

      final res = await ServicesLocator.groomerHomeRepository.updateServiceMilestone(
        bookingId: tomorrowBooking.bookingId,
        milestone: 'check_in_completed',
        booking: tomorrowBooking,
      );

      expect(res.success, isFalse);
      expect(res.message, isNot(contains('Route not found')));
      expect(res.message, contains('Check-in is only allowed on the scheduled booking date (21 Oct 2026)'));
    });

    testWidgets('GroomerCheckInDialog replaces Route Not Found with clear booking date error on failed submission', (tester) async {
      ToastUtil.resetForTesting();
      BookingDateUtils.customNow = DateTime(2026, 10, 20, 10, 0);

      final booking = const GroomerBooking(
        bookingId: 957,
        status: 'confirmed',
        bookingDate: '2026-10-20',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Bella',
        customerName: 'Laura',
        serviceName: 'Full Grooming',
      );

      // Simulate backend returning 404 Route Not Found
      ServicesLocator.apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        return MockAdapter.json({
          'success': false,
          'message': 'Route Not Found',
        }, 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => ToastificationWrapper(child: child!),
          home: Scaffold(
            body: GroomerCheckInDialog(booking: booking),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check the two intake checkboxes (vaccination and health verification)
      final checkBoxes = find.byType(Checkbox);
      expect(checkBoxes, findsAtLeastNWidgets(2));
      await tester.tap(checkBoxes.at(0));
      await tester.pumpAndSettle();
      await tester.tap(checkBoxes.at(1));
      await tester.pumpAndSettle();

      final confirmBtnFinder = find.widgetWithText(ElevatedButton, 'Confirm Check-in');
      await tester.tap(confirmBtnFinder);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Toast must display clear error message, NOT "Route Not Found"
      expect(ToastUtil.lastMessageForTesting, isNotNull);
      expect(ToastUtil.lastMessageForTesting, isNot(contains('Route Not Found')));
      expect(ToastUtil.lastMessageForTesting, contains('Check-in is only allowed on the scheduled booking date'));
    });
  });
}

class MockAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;
  MockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  static ResponseBody json(dynamic data, int statusCode) {
    return ResponseBody.fromString(
      jsonEncode(data),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
