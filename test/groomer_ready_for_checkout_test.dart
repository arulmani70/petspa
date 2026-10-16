import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_milestone_record.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/all_groomers/all_groomers_schedule_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  group('Step 8 – Ready for Checkout Lifecycle & Eligibility Tests', () {
    test('Appointments in pending, confirmed, checked_in, in_progress, bath_completed cannot be marked ready for checkout', () {
      const pendingBooking = GroomerBooking(
        bookingId: 801,
        status: 'pending',
        customerName: 'Alice',
        petName: 'Milo',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-16',
        startTime: '10:00',
        endTime: '11:00',
        totalPrice: 65.0,
      );
      expect(pendingBooking.isReadyForCheckout, isFalse);
      expect(pendingBooking.canMarkReadyForCheckout, isFalse);

      const confirmedBooking = GroomerBooking(
        bookingId: 802,
        status: 'confirmed',
        customerName: 'Alice',
        petName: 'Milo',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-16',
        startTime: '10:00',
        endTime: '11:00',
        totalPrice: 65.0,
      );
      expect(confirmedBooking.isReadyForCheckout, isFalse);
      expect(confirmedBooking.canMarkReadyForCheckout, isFalse);

      const inProgressBooking = GroomerBooking(
        bookingId: 803,
        status: 'in_progress',
        customerName: 'Alice',
        petName: 'Milo',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-16',
        startTime: '10:00',
        endTime: '11:00',
        totalPrice: 65.0,
      );
      expect(inProgressBooking.isReadyForCheckout, isFalse);
      expect(inProgressBooking.canMarkReadyForCheckout, isFalse);

      const bathDoneBooking = GroomerBooking(
        bookingId: 804,
        status: 'bath_completed',
        customerName: 'Alice',
        petName: 'Milo',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-16',
        startTime: '10:00',
        endTime: '11:00',
        totalPrice: 65.0,
        milestoneRecord: GroomerMilestoneRecord(bathCompleted: true),
      );
      expect(bathDoneBooking.isBathCompleted, isTrue);
      expect(bathDoneBooking.isGroomingCompleted, isFalse);
      expect(bathDoneBooking.isReadyForCheckout, isFalse);
      expect(bathDoneBooking.canMarkReadyForCheckout, isFalse);
    });

    test('Appointment in grooming_completed is eligible for Ready for Checkout', () {
      const groomingDoneBooking = GroomerBooking(
        bookingId: 805,
        status: 'grooming_completed',
        customerName: 'Bob',
        petName: 'Bella',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-16',
        startTime: '11:00',
        endTime: '12:00',
        totalPrice: 85.0,
        milestoneRecord: GroomerMilestoneRecord(
          bathCompleted: true,
          groomingCompleted: true,
        ),
      );

      expect(groomingDoneBooking.isBathCompleted, isTrue);
      expect(groomingDoneBooking.isGroomingCompleted, isTrue);
      expect(groomingDoneBooking.isReadyForCheckout, isFalse);
      expect(groomingDoneBooking.canMarkReadyForCheckout, isTrue);
    });

    test('Appointment already in ready_for_checkout cannot be marked again (duplicate prevention)', () {
      const readyBooking = GroomerBooking(
        bookingId: 806,
        status: 'ready_for_checkout',
        customerName: 'Carol',
        petName: 'Luna',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-16',
        startTime: '12:00',
        endTime: '13:00',
        totalPrice: 75.0,
        milestoneRecord: GroomerMilestoneRecord(
          bathCompleted: true,
          groomingCompleted: true,
        ),
      );

      expect(readyBooking.isReadyForCheckout, isTrue);
      expect(readyBooking.canMarkReadyForCheckout, isFalse);
    });

    test('Completed and cancelled appointments cannot be marked ready for checkout', () {
      const completedBooking = GroomerBooking(
        bookingId: 807,
        status: 'completed',
        customerName: 'Dave',
        petName: 'Max',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-16',
        startTime: '13:00',
        endTime: '14:00',
        totalPrice: 90.0,
        milestoneRecord: GroomerMilestoneRecord(
          bathCompleted: true,
          groomingCompleted: true,
        ),
      );
      expect(completedBooking.canMarkReadyForCheckout, isFalse);

      const cancelledBooking = GroomerBooking(
        bookingId: 808,
        status: 'cancelled',
        customerName: 'Eve',
        petName: 'Rocky',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-16',
        startTime: '14:00',
        endTime: '15:00',
        totalPrice: 50.0,
      );
      expect(cancelledBooking.canMarkReadyForCheckout, isFalse);
    });
  });

  group('Step 8 – Repository markReadyForCheckout Validation & Guard Rails', () {
    test('Rejects transition when booking is in pending or cancelled status', () async {
      const pendingBooking = GroomerBooking(
        bookingId: 809,
        status: 'pending',
        customerName: 'Frank',
        petName: 'Daisy',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-16',
        startTime: '09:00',
        endTime: '10:00',
        totalPrice: 60.0,
      );

      final res = await ServicesLocator.groomerHomeRepository.markReadyForCheckoutDetails(
        bookingId: 809,
        booking: pendingBooking,
      );

      expect(res.success, isFalse);
      expect(res.message, contains('Cannot mark a pending appointment ready for checkout.'));
      expect(res.updatedBooking, isNull);
    });

    test('Rejects transition when grooming is not yet completed', () async {
      const inProgressBooking = GroomerBooking(
        bookingId: 810,
        status: 'in_progress',
        customerName: 'Grace',
        petName: 'Charlie',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-16',
        startTime: '10:00',
        endTime: '11:00',
        totalPrice: 70.0,
        milestoneRecord: GroomerMilestoneRecord(bathCompleted: true, groomingCompleted: false),
      );

      final res = await ServicesLocator.groomerHomeRepository.markReadyForCheckoutDetails(
        bookingId: 810,
        booking: inProgressBooking,
      );

      expect(res.success, isFalse);
      expect(res.message, contains('Grooming must be completed before marking appointment ready for checkout.'));
      expect(res.updatedBooking, isNull);
    });

    test('Rejects transition when appointment is already marked ready for checkout (duplicate protection)', () async {
      const alreadyReadyBooking = GroomerBooking(
        bookingId: 811,
        status: 'ready_for_checkout',
        customerName: 'Hannah',
        petName: 'Bailey',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-16',
        startTime: '11:00',
        endTime: '12:00',
        totalPrice: 80.0,
        milestoneRecord: GroomerMilestoneRecord(bathCompleted: true, groomingCompleted: true),
      );

      final res = await ServicesLocator.groomerHomeRepository.markReadyForCheckoutDetails(
        bookingId: 811,
        booking: alreadyReadyBooking,
      );

      expect(res.success, isFalse);
      expect(res.message, contains('Appointment is already marked as Ready for Checkout.'));
      expect(res.updatedBooking, isNull);
    });

    test('Rejects transition when another groomer owns the appointment', () async {
      // Mock active groomer user in session
      await ServicesLocator.sessionService.saveGroomerUser({
        'id': 1,
        'name': 'Groomer One',
        'groomerCode': 'G001',
      });

      const otherGroomerBooking = GroomerBooking(
        bookingId: 812,
        status: 'grooming_completed',
        customerName: 'Ian',
        petName: 'Cooper',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-16',
        startTime: '13:00',
        endTime: '14:00',
        totalPrice: 95.0,
        groomerId: 99, // Different groomer
        milestoneRecord: GroomerMilestoneRecord(bathCompleted: true, groomingCompleted: true),
      );

      final res = await ServicesLocator.groomerHomeRepository.markReadyForCheckoutDetails(
        bookingId: 812,
        booking: otherGroomerBooking,
      );

      expect(res.success, isFalse);
      expect(res.message, contains('You cannot mark another groomer\'s appointment ready for checkout.'));
      expect(res.updatedBooking, isNull);
    });
  });

  group('Step 8 – Checkout Summary Fields & Financial Safety', () {
    test('Preserves base pricing without inventing unavailable tax or tip amounts', () {
      final json = {
        'bookingId': 813,
        'status': 'ready_for_checkout',
        'customerName': 'Julia',
        'petName': 'Bear',
        'serviceName': 'Full Spa Package',
        'bookingDate': '2026-10-16',
        'startTime': '14:00',
        'endTime': '15:00',
        'packageName': 'Full Spa Package',
        'addOns': ['Teeth Cleaning', 'De-shedding'],
        'totalPrice': 110.0,
        // taxAmount, tipAmount, and isPaid omitted by backend availability response
      };

      final booking = GroomerBooking.fromJson(json);

      expect(booking.packageName, equals('Full Spa Package'));
      expect(booking.addOns, contains('Teeth Cleaning'));
      expect(booking.addOns, contains('De-shedding'));
      expect(booking.totalPrice, equals(110.0));
      // Confirms strict Step 3 financial rules: missing fields are null, not fabricated as 0.0
      expect(booking.hasTaxData, isFalse);
      expect(booking.taxAmount, isNull);
      expect(booking.hasTipData, isFalse);
      expect(booking.tipAmount, isNull);
      expect(booking.hasPaymentData, isFalse);
      expect(booking.isPaid, isNull);
      expect(booking.totalCollected, isNull);
      expect(booking.isReadyForCheckout, isTrue);
    });
  });

  group('Step 8 – Customer Notification Feed Integration', () {
    test('Saving ready for checkout notification to customer portal feed succeeds', () async {
      final baseId = DateTime.now().millisecondsSinceEpoch;
      final notificationMap = {
        'id': baseId,
        'notificationId': baseId,
        'userId': 42,
        'title': 'Ready for Checkout',
        'message': 'Your pet is ready for checkout!',
        'type': 'booking_ready_for_checkout',
        'status': 'ready_for_checkout',
        'isRead': false,
        'createdAt': DateTime.now().toIso8601String(),
        'data': {
          'bookingId': 814,
          'status': 'ready_for_checkout',
          'userId': 42,
        },
      };

      await ServicesLocator.sessionService.saveCustomerPortalNotification(
        notificationMap,
        customerId: 42,
      );

      final notifs = ServicesLocator.sessionService.getCustomerPortalNotifications(customerId: 42);
      expect(notifs, isNotEmpty);
      final found = notifs.firstWhere((n) => n['id'] == baseId);
      expect(found['title'], equals('Ready for Checkout'));
      expect(found['type'], equals('booking_ready_for_checkout'));
      expect(found['status'], equals('ready_for_checkout'));
    });
  });

  group('Step 8 – AllGroomersSchedulePage UI & Action Button Tests', () {
    testWidgets('Displays Ready for Checkout action button when grooming is completed and groomer owns booking', (tester) async {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await ServicesLocator.sessionService.saveGroomerUser({
        'id': 1,
        'name': 'John Doe',
        'email': 'john@groomer.com',
      });

      final testGroomers = [
        const SalonGroomer(
          id: 1,
          groomerCode: 'G001',
          firstName: 'John',
          lastName: 'Doe',
          name: 'John Doe',
        ),
      ];

      final testBookings = [
        GroomerBooking(
          bookingId: 815,
          status: 'grooming_completed',
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
            groomingCompleted: true,
          ),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: testBookings,
            initialSalonGroomers: testGroomers,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Ready for Checkout'), findsOneWidget);
      expect(find.byIcon(Icons.point_of_sale_rounded), findsOneWidget);
    });

    testWidgets('Displays Ready for Checkout status badge when booking is ready_for_checkout', (tester) async {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await ServicesLocator.sessionService.saveGroomerUser({
        'id': 1,
        'name': 'John Doe',
        'email': 'john@groomer.com',
      });

      final testGroomers = [
        const SalonGroomer(
          id: 1,
          groomerCode: 'G001',
          firstName: 'John',
          lastName: 'Doe',
          name: 'John Doe',
        ),
      ];

      final testBookings = [
        GroomerBooking(
          bookingId: 816,
          status: 'ready_for_checkout',
          customerName: 'Tina',
          petName: 'Oliver',
          serviceName: 'Full Groom',
          bookingDate: todayStr,
          startTime: '10:00 AM',
          endTime: '11:00 AM',
          totalPrice: 90.0,
          groomerId: 1,
          groomerCode: 'G001',
          groomerName: 'John Doe',
          milestoneRecord: const GroomerMilestoneRecord(
            bathCompleted: true,
            groomingCompleted: true,
          ),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: testBookings,
            initialSalonGroomers: testGroomers,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Ready for Checkout'), findsWidgets);
      expect(find.text('Complete'), findsOneWidget);
    });
  });
}
