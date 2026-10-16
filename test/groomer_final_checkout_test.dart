import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_milestone_record.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/all_groomers/all_groomers_schedule_page.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/groomer_final_checkout_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  group('Step 10 – Checkout Eligibility & Status Rules', () {
    test('Only bookings in ready_for_checkout status have canFinalCheckout == true', () {
      const readyBooking = GroomerBooking(
        bookingId: 1001,
        status: 'ready_for_checkout',
        customerName: 'Carol',
        petName: 'Rocky',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-16',
        startTime: '10:00',
        endTime: '11:00',
        totalPrice: 75.0,
      );

      expect(readyBooking.isReadyForCheckout, isTrue);
      expect(readyBooking.isCompleted, isFalse);
      expect(readyBooking.canFinalCheckout, isTrue);
    });

    test('Bookings in other statuses cannot be checked out', () {
      const statuses = [
        'pending',
        'confirmed',
        'checked_in',
        'in_progress',
        'bath_completed',
        'grooming_completed',
        'cancelled',
      ];

      for (final st in statuses) {
        final b = GroomerBooking(
          bookingId: 1002,
          status: st,
          customerName: 'Carol',
          petName: 'Rocky',
          serviceName: 'Full Groom',
          bookingDate: '2026-10-16',
          startTime: '10:00',
          endTime: '11:00',
          totalPrice: 75.0,
        );
        expect(b.canFinalCheckout, isFalse, reason: 'Status $st should not allow final checkout');
      }
    });

    test('Already completed bookings cannot be checked out again', () {
      const completedBooking = GroomerBooking(
        bookingId: 1003,
        status: 'completed',
        customerName: 'Carol',
        petName: 'Rocky',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-16',
        startTime: '10:00',
        endTime: '11:00',
        totalPrice: 75.0,
        isPaid: true,
      );

      expect(completedBooking.isCompleted, isTrue);
      expect(completedBooking.canFinalCheckout, isFalse);
    });
  });

  group('Step 10 – Financial Amount Integrity', () {
    test('Authoritative total equals base price when tip and tax are absent', () {
      const b = GroomerBooking(
        bookingId: 1004,
        status: 'ready_for_checkout',
        customerName: 'Dave',
        petName: 'Daisy',
        serviceName: 'Bath & Brush',
        bookingDate: '2026-10-16',
        startTime: '11:00',
        endTime: '12:00',
        totalPrice: 50.0,
        tipAmount: null,
        taxAmount: null,
      );

      expect(b.totalAuthoritativeAmountDue, equals(50.0));
    });

    test('Authoritative total properly sums base price + confirmed tip + confirmed tax', () {
      const b = GroomerBooking(
        bookingId: 1005,
        status: 'ready_for_checkout',
        customerName: 'Dave',
        petName: 'Daisy',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-16',
        startTime: '11:00',
        endTime: '12:00',
        totalPrice: 80.0,
        tipAmount: 16.0,
        taxAmount: 6.40,
      );

      expect(b.totalAuthoritativeAmountDue, closeTo(102.40, 0.001));
    });

    test('Ignores zero or negative tips/taxes in authoritative total', () {
      const b = GroomerBooking(
        bookingId: 1006,
        status: 'ready_for_checkout',
        customerName: 'Dave',
        petName: 'Daisy',
        serviceName: 'Nail Trim',
        bookingDate: '2026-10-16',
        startTime: '11:00',
        endTime: '12:00',
        totalPrice: 25.0,
        tipAmount: 0.0,
        taxAmount: 0.0,
      );

      expect(b.totalAuthoritativeAmountDue, equals(25.0));
    });
  });

  group('Step 10 – Groomer Ownership & Lifecycle Validation in Repository', () {
    test('Attempting to complete checkout for another groomer\'s appointment fails', () async {
      await ServicesLocator.sessionService.saveGroomerUser({
        'id': 1,
        'name': 'Groomer John',
        'email': 'john@groomer.com',
      });

      const otherGroomerBooking = GroomerBooking(
        bookingId: 1007,
        status: 'ready_for_checkout',
        customerName: 'Eve',
        petName: 'Cooper',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-16',
        startTime: '01:00 PM',
        endTime: '02:00 PM',
        totalPrice: 70.0,
        groomerId: 99, // different groomer
      );

      final res = await ServicesLocator.groomerHomeRepository.completeBookingDetails(
        1007,
        booking: otherGroomerBooking,
      );

      expect(res.success, isFalse);
      expect(res.message, contains('cannot complete checkout for another groomer'));
      expect(res.updatedBooking, isNull);
    });

    test('Attempting to checkout booking that is not in ready_for_checkout fails', () async {
      await ServicesLocator.sessionService.saveGroomerUser({
        'id': 1,
        'name': 'Groomer John',
        'email': 'john@groomer.com',
      });

      const inProgressBooking = GroomerBooking(
        bookingId: 1008,
        status: 'in_progress',
        customerName: 'Eve',
        petName: 'Cooper',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-16',
        startTime: '01:00 PM',
        endTime: '02:00 PM',
        totalPrice: 70.0,
        groomerId: 1,
      );

      final res = await ServicesLocator.groomerHomeRepository.completeBookingDetails(
        1008,
        booking: inProgressBooking,
      );

      expect(res.success, isFalse);
      expect(res.message, contains('Ready for Checkout'));
      expect(res.updatedBooking, isNull);
    });
  });

  group('Step 10 – GroomerFinalCheckoutDialog Widget Tests', () {
    testWidgets('Renders pet details, customer details, and charges breakdown', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const testBooking = GroomerBooking(
        bookingId: 1009,
        status: 'ready_for_checkout',
        customerName: 'Sarah Jenkins',
        customerMobile: '555-0192',
        petName: 'Barnaby',
        breed: 'Golden Retriever',
        serviceName: 'Deluxe Bath & Trim',
        packageName: 'Spa Package',
        addOns: ['Teeth Brushing', 'Nail Dremel'],
        bookingDate: '2026-10-16',
        startTime: '02:00 PM',
        endTime: '03:30 PM',
        totalPrice: 95.0,
        tipAmount: 19.0,
        taxAmount: 7.60,
        groomerId: 1,
        groomerName: 'John Doe',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GroomerFinalCheckoutDialog(booking: testBooking),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Final Checkout'), findsOneWidget);
      expect(find.text('Barnaby'), findsOneWidget);
      expect(find.text('Sarah Jenkins (555-0192)'), findsOneWidget);
      expect(find.text('Authoritative Charges'), findsOneWidget);
      expect(find.text('\$95.00'), findsOneWidget); // base price
      expect(find.text('Teeth Brushing'), findsOneWidget);
      expect(find.text('Nail Dremel'), findsOneWidget);
      expect(find.text('Customer Confirmed'), findsOneWidget);
      expect(find.text('\$19.00'), findsOneWidget); // confirmed tip
      expect(find.text('\$7.60'), findsOneWidget); // confirmed tax
      expect(find.text('\$121.60'), findsOneWidget); // authoritative total: 95 + 19 + 7.60
      expect(find.text('Salon Counter Settlement'), findsOneWidget);
      expect(find.text('Confirm & Complete Checkout'), findsOneWidget);
    });

    testWidgets('Displays "No tip confirmed on server" and "Calculated at counter" when null', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const testBooking = GroomerBooking(
        bookingId: 1010,
        status: 'ready_for_checkout',
        customerName: 'Mark R',
        petName: 'Coco',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-16',
        startTime: '03:00 PM',
        endTime: '04:00 PM',
        totalPrice: 60.0,
        tipAmount: null,
        taxAmount: null,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GroomerFinalCheckoutDialog(booking: testBooking),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No tip confirmed on server'), findsOneWidget);
      expect(find.text('Calculated at counter'), findsOneWidget);
      expect(find.text('\$60.00'), findsNWidgets(2)); // base price and total
    });

    testWidgets('Displays ineligibility banner when booking is not ready_for_checkout', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const testBooking = GroomerBooking(
        bookingId: 1011,
        status: 'grooming_completed',
        customerName: 'Lisa M',
        petName: 'Zoe',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-16',
        startTime: '04:00 PM',
        endTime: '05:00 PM',
        totalPrice: 70.0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GroomerFinalCheckoutDialog(booking: testBooking),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('This appointment is not marked as Ready for Checkout'), findsOneWidget);
      // The Confirm & Complete button should be disabled
      final elevatedButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Confirm & Complete Checkout'),
      );
      expect(elevatedButton.onPressed, isNull);
    });
  });

  group('Step 10 – AllGroomersSchedulePage Integration', () {
    testWidgets('Tapping Complete on ready_for_checkout booking opens GroomerFinalCheckoutDialog', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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
          bookingId: 1012,
          status: 'ready_for_checkout',
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

      expect(find.text('Complete'), findsOneWidget);

      await tester.tap(find.text('Complete'));
      await tester.pumpAndSettle();

      expect(find.byType(GroomerFinalCheckoutDialog), findsOneWidget);
      expect(find.text('Final Checkout'), findsOneWidget);
      expect(find.text('Confirm & Complete Checkout'), findsOneWidget);
    });
  });
}
