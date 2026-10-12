import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_cancellation_manager.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookingCancellationManager manager;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  setUp(() {
    manager = BookingCancellationManager();
  });

  tearDown(() {
    manager.dispose();
  });

  group('Scheduled-Time Validation & Expiry Evaluation Tests', () {
    test('parses scheduled start DateTime accurately from bookingDate and startTime (12-hour AM/PM and 24-hour formats)', () {
      final dt1 = manager.parseScheduledStartDateTime('2026-10-15', '11:00 AM');
      expect(dt1, equals(DateTime(2026, 10, 15, 11, 0)));

      final dt2 = manager.parseScheduledStartDateTime('2026-10-15', '02:30 PM');
      expect(dt2, equals(DateTime(2026, 10, 15, 14, 30)));

      final dt3 = manager.parseScheduledStartDateTime('2026-10-15', '09:15');
      expect(dt3, equals(DateTime(2026, 10, 15, 9, 15)));

      final dtUtc = manager.parseScheduledStartDateTime('2026-10-15', '11:00 AM', isUtc: true);
      expect(dtUtc, equals(DateTime.utc(2026, 10, 15, 11, 0)));
    });

    test('11:00 AM appointment that remains pending is NOT expired before 11:00 AM', () {
      final bookingDate = '2026-10-15';
      final startTime = '11:00 AM';

      // Check at 9:00 AM on appointment date
      final checkAt9am = DateTime(2026, 10, 15, 9, 0);
      expect(manager.isScheduledStartTimeReached(bookingDate, startTime, now: checkAt9am), isFalse);

      // Check at 10:59 AM on appointment date
      final checkAt1059am = DateTime(2026, 10, 15, 10, 59);
      expect(manager.isScheduledStartTimeReached(bookingDate, startTime, now: checkAt1059am), isFalse);
    });

    test('11:00 AM appointment that remains pending IS expired at exactly 11:00 AM', () {
      final bookingDate = '2026-10-15';
      final startTime = '11:00 AM';

      // Check at exactly 11:00 AM on appointment date
      final checkAt11am = DateTime(2026, 10, 15, 11, 0);
      expect(manager.isScheduledStartTimeReached(bookingDate, startTime, now: checkAt11am), isTrue);

      // Check at 11:05 AM on appointment date
      final checkAt1105am = DateTime(2026, 10, 15, 11, 5);
      expect(manager.isScheduledStartTimeReached(bookingDate, startTime, now: checkAt1105am), isTrue);
    });

    test('future appointments for tomorrow or next week are NOT expired today', () {
      final tomorrowBookingDate = '2026-10-16';
      final startTime = '11:00 AM';

      // Current time is today (Oct 15) at 3:00 PM
      final todayAfternoon = DateTime(2026, 10, 15, 15, 0);
      expect(manager.isScheduledStartTimeReached(tomorrowBookingDate, startTime, now: todayAfternoon), isFalse);
    });

    test('delayed scheduler run / server downtime: handles overdue pending appointments', () {
      final pastBookingDate = '2026-10-14';
      final startTime = '11:00 AM';

      // Current time is Oct 15 (delayed processing)
      final nextDay = DateTime(2026, 10, 15, 9, 0);
      expect(manager.isScheduledStartTimeReached(pastBookingDate, startTime, now: nextDay), isTrue);
    });
  });

  group('Eligibility for Automatic Cancellation Tests', () {
    test('pending unaccepted booking reaching scheduled start time is eligible for auto-cancellation', () {
      final booking = {
        'id': 101,
        'status': 'pending',
        'bookingDate': '2026-10-15',
        'startTime': '11:00 AM',
        'pet_name': 'Max',
      };
      final now11am = DateTime(2026, 10, 15, 11, 0);

      expect(manager.isEligibleForAutoCancellation(booking, now: now11am), isTrue);
    });

    test('pending booking before scheduled start time is NOT eligible for auto-cancellation', () {
      final booking = {
        'id': 102,
        'status': 'pending',
        'bookingDate': '2026-10-15',
        'startTime': '11:00 AM',
        'pet_name': 'Daisy',
      };
      final now1030am = DateTime(2026, 10, 15, 10, 30);

      expect(manager.isEligibleForAutoCancellation(booking, now: now1030am), isFalse);
    });

    test('accepted / confirmed booking before or at 11:00 AM is NEVER eligible for auto-cancellation', () {
      final booking = {
        'id': 103,
        'status': 'confirmed',
        'bookingDate': '2026-10-15',
        'startTime': '11:00 AM',
        'pet_name': 'Rocky',
      };
      final now11am = DateTime(2026, 10, 15, 11, 0);
      final now1130am = DateTime(2026, 10, 15, 11, 30);

      expect(manager.isEligibleForAutoCancellation(booking, now: now11am), isFalse);
      expect(manager.isEligibleForAutoCancellation(booking, now: now1130am), isFalse);
    });

    test('in_progress or completed booking is NEVER auto-cancelled', () {
      final inProgressBooking = {
        'id': 104,
        'status': 'in_progress',
        'bookingDate': '2026-10-15',
        'startTime': '11:00 AM',
      };
      final completedBooking = {
        'id': 105,
        'status': 'completed',
        'bookingDate': '2026-10-15',
        'startTime': '11:00 AM',
      };
      final now1130am = DateTime(2026, 10, 15, 11, 30);

      expect(manager.isEligibleForAutoCancellation(inProgressBooking, now: now1130am), isFalse);
      expect(manager.isEligibleForAutoCancellation(completedBooking, now: now1130am), isFalse);
    });

    test('already cancelled booking is NEVER eligible for duplicate auto-cancellation', () {
      final cancelledBooking = {
        'id': 106,
        'status': 'cancelled',
        'bookingDate': '2026-10-15',
        'startTime': '11:00 AM',
      };
      final now1130am = DateTime(2026, 10, 15, 11, 30);

      expect(manager.isEligibleForAutoCancellation(cancelledBooking, now: now1130am), isFalse);
    });
  });

  group('Auto-Cancellation Execution, Notification, & Idempotency Tests', () {
    test('autoCancelBooking sets correct cancellation reason and executes cleanly', () async {
      final bookingData = {
        'id': 201,
        'status': 'pending',
        'bookingDate': '2026-10-15',
        'startTime': '11:00 AM',
        'pet_name': 'Milo',
      };

      final result = await manager.autoCancelBooking(
        bookingId: 201,
        bookingData: bookingData,
      );

      expect(result, isTrue);
    });

    test('idempotency: prevents duplicate cancellations for the same booking ID', () async {
      final bookingData = {
        'id': 202,
        'status': 'pending',
        'bookingDate': '2026-10-15',
        'startTime': '11:00 AM',
        'pet_name': 'Luna',
      };

      final first = await manager.autoCancelBooking(
        bookingId: 202,
        bookingData: bookingData,
      );
      expect(first, isTrue);

      final second = await manager.autoCancelBooking(
        bookingId: 202,
        bookingData: bookingData,
      );
      expect(second, isFalse);
    });

    test('dispatches customer notification explaining cancellation at scheduled appointment time', () async {
      AppNotification? receivedNotification;
      final sub = ServicesLocator.customerSocketService.onNotification.listen((n) {
        receivedNotification = n;
      });

      final bookingData = {
        'id': 203,
        'status': 'pending',
        'bookingDate': '2026-10-15',
        'startTime': '11:00 AM',
        'pet_name': 'Bella',
      };

      await manager.autoCancelBooking(
        bookingId: 203,
        bookingData: bookingData,
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(receivedNotification, isNotNull);
      expect(receivedNotification!.id, equals(203));
      expect(receivedNotification!.type, equals('booking_auto_cancelled'));
      expect(receivedNotification!.message, contains('Bella'));
      expect(receivedNotification!.message, contains('2026-10-15'));
      expect(receivedNotification!.message, contains('11:00 AM'));
      expect(receivedNotification!.message, contains('before the scheduled appointment time'));
      expect(receivedNotification!.metadata?['autoCancelled'], isTrue);
      expect(receivedNotification!.metadata?['reason'], equals(Constants.app.CANCELLATION_REASON_GROOMER_TIMEOUT));

      await sub.cancel();
    });

    test('filterAndProcessExpiredBookings processes overdue pending items and preserves valid/future items', () async {
      final checkTime = DateTime(2026, 10, 15, 11, 0);
      final rawList = [
        {
          'id': 301,
          'status': 'pending',
          'pet_name': 'Coco',
          'bookingDate': '2026-10-15',
          'startTime': '10:30 AM', // 10:30 AM -> past scheduled time -> auto-cancelled
        },
        {
          'id': 302,
          'status': 'pending',
          'pet_name': 'Rocky',
          'bookingDate': '2026-10-15',
          'startTime': '02:00 PM', // 2:00 PM -> future start time today -> preserved pending
        },
        {
          'id': 303,
          'status': 'pending',
          'pet_name': 'Sammy',
          'bookingDate': '2026-10-16',
          'startTime': '11:00 AM', // Tomorrow -> future date -> preserved pending
        },
        {
          'id': 304,
          'status': 'confirmed',
          'pet_name': 'Charlie',
          'bookingDate': '2026-10-15',
          'startTime': '10:00 AM', // Confirmed -> preserved confirmed
        },
      ];

      final processed = await manager.filterAndProcessExpiredBookings(rawList, now: checkTime);

      expect(processed.length, equals(4));

      // Overdue unaccepted booking #301
      expect(processed[0]['id'], equals(301));
      expect(processed[0]['status'], equals('CANCELLED'));
      expect(processed[0]['cancellationReason'], equals(Constants.app.CANCELLATION_REASON_GROOMER_TIMEOUT));

      // Future booking today #302
      expect(processed[1]['id'], equals(302));
      expect(processed[1]['status'], equals('pending'));

      // Tomorrow's booking #303
      expect(processed[2]['id'], equals(303));
      expect(processed[2]['status'], equals('pending'));

      // Confirmed booking #304
      expect(processed[3]['id'], equals(304));
      expect(processed[3]['status'], equals('confirmed'));
    });
  });

  group('Groomer Acceptance Blocked Past Scheduled Start Time Tests', () {
    test('Groomer cannot approve an unaccepted booking once its scheduled start time has passed', () async {
      // Create a booking overdue past scheduled start time
      const overdueBooking = GroomerBooking(
        bookingId: 501,
        status: 'pending',
        bookingDate: '2026-10-10', // In past
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        petName: 'Rex',
        customerName: 'Alice',
        serviceName: 'Full Grooming',
      );

      // Verify that scheduled start time is reached
      final isOverdue = manager.isScheduledStartTimeReached(
        overdueBooking.bookingDate,
        overdueBooking.startTime,
      );
      expect(isOverdue, isTrue);

      // Verify approval prevention logic
      final result = await ServicesLocator.groomerHomeRepository.approveBookingDetails(
        501,
        booking: overdueBooking,
      );
      expect(result.success, isFalse);
      expect(result.message, contains('scheduled appointment start time has passed'));
    });
  });

  group('GroomerBooking Model Serialization Tests', () {
    test('GroomerBooking correctly serializes and deserializes cancellationReason', () {
      final json = {
        'bookingId': 401,
        'status': 'cancelled',
        'bookingDate': '2026-10-15',
        'startTime': '11:00 AM',
        'endTime': '12:00 PM',
        'petName': 'Oliver',
        'customerName': 'Sarah Connor',
        'serviceName': 'Full Grooming',
        'cancellationReason': Constants.app.CANCELLATION_REASON_GROOMER_TIMEOUT,
      };

      final booking = GroomerBooking.fromJson(json);

      expect(booking.bookingId, equals(401));
      expect(booking.status, equals('cancelled'));
      expect(booking.cancellationReason, equals(Constants.app.CANCELLATION_REASON_GROOMER_TIMEOUT));

      final serialized = booking.toJson();
      expect(serialized['cancellationReason'], equals(Constants.app.CANCELLATION_REASON_GROOMER_TIMEOUT));
    });
  });
}
