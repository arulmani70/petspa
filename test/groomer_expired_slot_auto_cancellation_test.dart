import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_cancellation_manager.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
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
    BookingDateUtils.customNow = null;
    manager.dispose();
  });

  group('Expired Slot & Auto-Cancellation Tests', () {
    test('GroomerBooking.fromJson parses snake_case start_time and slot accurately without falling back to 09:00 AM', () {
      final json1 = {
        'id': 801,
        'status': 'pending',
        'booking_date': '2026-10-22',
        'start_time': '02:30 PM',
        'end_time': '03:30 PM',
      };
      final b1 = GroomerBooking.fromJson(json1);
      expect(b1.startTime, equals('02:30 PM'));
      expect(b1.endTime, equals('03:30 PM'));

      final json2 = {
        'id': 802,
        'status': 'pending',
        'date': '2026-10-22',
        'slot': '11:15 AM',
      };
      final b2 = GroomerBooking.fromJson(json2);
      expect(b2.startTime, equals('11:15 AM'));
    });

    test('GroomerBooking.isExpiredPending returns true only for pending bookings whose scheduled start time has passed', () {
      BookingDateUtils.customNow = DateTime(2026, 10, 22, 12, 0); // 12:00 PM today

      // Overdue pending (10:00 AM)
      final overduePending = GroomerBooking.fromJson({
        'id': 803,
        'status': 'pending',
        'booking_date': '2026-10-22',
        'start_time': '10:00 AM',
      });
      expect(overduePending.isExpiredPending, isTrue);

      // Future pending today (02:00 PM)
      final futurePending = GroomerBooking.fromJson({
        'id': 804,
        'status': 'pending',
        'booking_date': '2026-10-22',
        'start_time': '02:00 PM',
      });
      expect(futurePending.isExpiredPending, isFalse);

      // Overdue confirmed (10:00 AM) -> confirmed cannot be expired pending
      final overdueConfirmed = GroomerBooking.fromJson({
        'id': 805,
        'status': 'confirmed',
        'booking_date': '2026-10-22',
        'start_time': '10:00 AM',
      });
      expect(overdueConfirmed.isExpiredPending, isFalse);

      // Already cancelled booking -> cannot be expired pending
      final cancelledBooking = GroomerBooking.fromJson({
        'id': 806,
        'status': 'cancelled',
        'booking_date': '2026-10-22',
        'start_time': '10:00 AM',
      });
      expect(cancelledBooking.isExpiredPending, isFalse);
    });

    test('BookingCancellationManager autoCancelBooking triggers notifications to customer and groomer streams', () async {
      BookingDateUtils.customNow = DateTime(2026, 10, 22, 12, 0);

      AppNotification? receivedCustomerNotif;
      AppNotification? receivedGroomerNotif;

      final customerSub = ServicesLocator.customerSocketService.onNotification.listen((n) {
        if (n.id == 810) receivedCustomerNotif = n;
      });

      final groomerSub = ServicesLocator.groomerSocketService.onNotification.listen((n) {
        if (n.id == 810) receivedGroomerNotif = n;
      });

      final bookingData = {
        'id': 810,
        'status': 'pending',
        'bookingDate': '2026-10-22',
        'startTime': '10:00 AM',
        'pet_name': 'Milo',
      };

      final success = await manager.autoCancelBooking(
        bookingId: 810,
        bookingData: bookingData,
      );

      expect(success, isTrue);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(receivedCustomerNotif, isNotNull);
      expect(receivedCustomerNotif!.type, equals('booking_auto_cancelled'));
      expect(receivedCustomerNotif!.message, contains('Milo'));
      expect(receivedCustomerNotif!.message, contains('before the scheduled appointment time'));

      expect(receivedGroomerNotif, isNotNull);
      expect(receivedGroomerNotif!.title, equals('Appointment Expired'));
      expect(receivedGroomerNotif!.message, contains('was automatically cancelled because it was not accepted'));

      await customerSub.cancel();
      await groomerSub.cancel();
    });

    test('evaluatePendingBookings evaluates and auto-cancels unaccepted appointments for groomer sessions', () async {
      BookingDateUtils.customNow = DateTime(2026, 10, 22, 14, 0); // 2:00 PM today

      // Mock Groomer logged in
      await ServicesLocator.sessionService.saveGroomerSession(
        groomerData: {'id': 1, 'firstName': 'Alex', 'lastName': 'Smith', 'email': 'alex@example.com'},
        accessToken: 'dummy_groomer_token',
        refreshToken: 'dummy_refresh_token',
      );

      expect(ServicesLocator.sessionService.isGroomerLoggedIn, isTrue);

      // evaluatePendingBookings runs without throwing and executes groomer pending evaluation
      await expectLater(manager.evaluatePendingBookings(), completes);
    });

    test('approveBookingDetails auto-cancels overdue booking and blocks approval with clear explanation', () async {
      BookingDateUtils.customNow = DateTime(2026, 10, 22, 15, 0); // 3:00 PM

      final overdueBooking = GroomerBooking.fromJson({
        'id': 820,
        'status': 'pending',
        'booking_date': '2026-10-22',
        'start_time': '10:00 AM',
        'pet_name': 'Bella',
      });

      final result = await ServicesLocator.groomerHomeRepository.approveBookingDetails(
        820,
        booking: overdueBooking,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('scheduled appointment start time has passed without groomer acceptance'));
    });
  });
}
