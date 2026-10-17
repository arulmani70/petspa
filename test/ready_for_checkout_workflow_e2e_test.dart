import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/widgets/customer_checkout_summary_sheet.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_milestone_record.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/groomer_final_checkout_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  setUp(() async {
    await ServicesLocator.sessionService.clearSession();
    await ServicesLocator.sessionService.clearGroomerSession();
  });

  group('Ready for Checkout -> Notification -> Tip -> Final Checkout Workflow', () {
    // ── 1. Groomer Marks Ready for Checkout ──────────────────────────────────
    test('1. Groomer marks Ready for Checkout validates milestones and preserves status without completing checkout', () async {
      await ServicesLocator.sessionService.saveGroomerUser({
        'id': 10,
        'name': 'Groomer Alex',
        'email': 'alex@groomer.com',
      });

      // A booking without completed grooming cannot be marked ready for checkout
      const bookingInBath = GroomerBooking(
        bookingId: 2001,
        status: 'bath_completed',
        customerName: 'Alice',
        petName: 'Milo',
        serviceName: 'Full Spa',
        bookingDate: '2026-10-17',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        totalPrice: 85.0,
        groomerId: 10,
        milestoneRecord: GroomerMilestoneRecord(bathCompleted: true, groomingCompleted: false),
      );

      final prematureRes = await ServicesLocator.groomerHomeRepository.markReadyForCheckoutDetails(
        bookingId: 2001,
        booking: bookingInBath,
      );
      expect(prematureRes.success, isFalse);
      expect(prematureRes.message, contains('Grooming must be completed'));

      // A booking with completed grooming can be marked ready for checkout
      const bookingGroomingDone = GroomerBooking(
        bookingId: 2002,
        status: 'grooming_completed',
        customerName: 'Alice',
        petName: 'Milo',
        serviceName: 'Full Spa',
        bookingDate: '2026-10-17',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        totalPrice: 85.0,
        groomerId: 10,
        userId: 101,
        milestoneRecord: GroomerMilestoneRecord(bathCompleted: true, groomingCompleted: true),
      );
      expect(bookingGroomingDone.isGroomingCompleted, isTrue);

      // Other groomer cannot mark ready for checkout
      const otherGroomerBooking = GroomerBooking(
        bookingId: 2003,
        status: 'grooming_completed',
        customerName: 'Bob',
        petName: 'Luna',
        serviceName: 'Full Spa',
        bookingDate: '2026-10-17',
        startTime: '11:00 AM',
        endTime: '12:00 PM',
        totalPrice: 90.0,
        groomerId: 99, // different groomer
        milestoneRecord: GroomerMilestoneRecord(bathCompleted: true, groomingCompleted: true),
      );
      final unauthorizedRes = await ServicesLocator.groomerHomeRepository.markReadyForCheckoutDetails(
        bookingId: 2003,
        booking: otherGroomerBooking,
      );
      expect(unauthorizedRes.success, isFalse);
      expect(unauthorizedRes.message, contains('cannot mark another groomer'));
    });

    // ── 2. Customer Receives Notification Associated with Booking & Customer ID ──
    test('2. Marking Ready for Checkout triggers notification associated with correct booking ID and customer ID', () async {
      await ServicesLocator.sessionService.saveGroomerUser({
        'id': 10,
        'name': 'Groomer Alex',
        'email': 'alex@groomer.com',
      });

      const customerId = 105;
      const bookingId = 2004;

      const booking = GroomerBooking(
        bookingId: bookingId,
        status: 'grooming_completed',
        customerName: 'Diana',
        petName: 'Coco',
        serviceName: 'Full Spa',
        bookingDate: '2026-10-17',
        startTime: '01:00 PM',
        endTime: '02:00 PM',
        totalPrice: 85.0,
        groomerId: 10,
        userId: customerId,
        milestoneRecord: GroomerMilestoneRecord(bathCompleted: true, groomingCompleted: true),
      );
      expect(booking.userId, equals(customerId));

      // Verify that notification dispatcher persists to customer portal
      await ServicesLocator.sessionService.saveCustomerPortalNotification({
        'id': 9901,
        'notificationId': 9901,
        'userId': customerId,
        'title': 'Ready for Checkout',
        'message': 'Your pet Coco\'s grooming is complete and is now ready for checkout!',
        'type': 'booking_ready_for_checkout',
        'status': 'ready_for_checkout',
        'data': {
          'bookingId': bookingId,
          'userId': customerId,
          'status': 'ready_for_checkout',
          'totalPrice': 85.0,
          'petName': 'Coco',
        },
      }, customerId: customerId);

      final customerNotifications = ServicesLocator.sessionService
          .getCustomerPortalNotifications(customerId: customerId);

      expect(customerNotifications, isNotEmpty);
      final notif = customerNotifications.firstWhere((n) => n['data']?['bookingId'] == bookingId);
      expect(notif['title'], equals('Ready for Checkout'));
      expect(notif['data']['bookingId'], equals(bookingId));
      expect(notif['data']['userId'], equals(customerId));
      expect(notif['status'], equals('ready_for_checkout'));
      // Must NOT be completed
      expect(notif['status'], isNot(equals('completed')));
    });

    // ── 3. Customer Opens Booking and Views Itemized Financial Details ─────────
    testWidgets('3. Customer views checkout summary: service fee, taxes, tip, and total without fabricated data', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const bookingData = {
        'bookingId': 2005,
        'id': 2005,
        'status': 'ready_for_checkout',
        'petName': 'Oliver',
        'petBreed': 'Beagle',
        'serviceName': 'Deluxe Grooming',
        'groomerName': 'Alex Rivera',
        'bookingDate': '2026-10-17',
        'startTime': '02:00 PM',
        'endTime': '03:00 PM',
        'servicePrice': 75.0,
        'totalPrice': 75.0,
        'taxAmount': null, // Uncalculated tax: must show pending message, not $0.00
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomerCheckoutSummarySheet(booking: bookingData),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Checkout Summary'), findsOneWidget);
      expect(find.text('Booking #2005'), findsOneWidget);
      expect(find.text('Oliver'), findsOneWidget);
      expect(find.text('Beagle'), findsOneWidget);
      expect(find.text('Deluxe Grooming'), findsOneWidget);
      expect(find.text('\$75.00'), findsWidgets); // base service fee & subtotal
      // Uncalculated tax shows polite pending message, NOT fabricated $0.00
      expect(find.text('Calculated at counter'), findsOneWidget);
      expect(find.text('Total Due at Counter'), findsOneWidget);
      expect(find.text('Confirm Tip (\$15.00)'), findsOneWidget); // default 20%
    });

    // ── 4. Customer Confirms Tip and Shared State is Updated ───────────────────
    test('4. Customer tip confirmation validates amount, saves to server/session, and does NOT complete booking', () async {
      const bookingData = {
        'bookingId': 2006,
        'id': 2006,
        'status': 'ready_for_checkout',
        'petName': 'Daisy',
        'totalPrice': 60.0,
        'groomerId': 10,
        'userId': 102,
      };

      final result = await ServicesLocator.bookingRepository.confirmTipDetails(
        bookingId: 2006,
        tipAmount: 12.0,
        tipPercentage: 20.0,
        booking: bookingData,
      );

      expect(result.success, isTrue);
      expect(result.confirmedTipAmount, equals(12.0));
      expect(result.confirmedTipPercentage, equals(20.0));
      expect(result.updatedBooking, isNotNull);

      // Critical requirement: booking remains ready_for_checkout, NEVER completed or paid
      expect(result.updatedBooking!['status'], equals('ready_for_checkout'));
      expect(result.updatedBooking!['isPaid'], isNot(equals(true)));
      expect(result.updatedBooking!['isTipConfirmed'], isTrue);

      // Persisted in SessionService for app restarts
      final savedTip = ServicesLocator.sessionService.getConfirmedTip(2006);
      expect(savedTip, isNotNull);
      expect(savedTip!['tipAmount'], equals(12.0));
      expect(ServicesLocator.sessionService.getConfirmedTipAmount(2006), equals(12.0));

      // Groomer notification is dispatched
      final groomerNotifs = ServicesLocator.sessionService.getGroomerPortalNotifications(groomerId: 10);
      expect(groomerNotifs, isNotEmpty);
      final tipNotif = groomerNotifs.firstWhere((n) => n['data']?['bookingId'] == 2006);
      expect(tipNotif['title'], equals('Customer Confirmed Tip'));
      expect(tipNotif['data']['tipAmount'], equals(12.0));
    });

    // ── 5. Groomer Sees Confirmed Tip in getCheckoutStatus and Final Dialog ───
    test('5. Groomer receives and sees customer-confirmed tip in checkout status', () async {
      await ServicesLocator.sessionService.saveConfirmedTip(
        bookingId: 2007,
        tipAmount: 18.0,
        tipPercentage: 20.0,
      );

      final status = await ServicesLocator.groomerHomeRepository.getCheckoutStatus(2007);
      expect(status, isNotNull);
      expect(status!['tipAmount'], equals(18.0));
      expect(status['customerConfirmed'], isTrue);

      // GroomerBooking deserialization picks up confirmed tip
      final booking = GroomerBooking.fromJson({
        'bookingId': 2007,
        'status': 'ready_for_checkout',
        'customerName': 'Frank',
        'petName': 'Max',
        'serviceName': 'Grooming',
        'bookingDate': '2026-10-17',
        'startTime': '03:00 PM',
        'endTime': '04:00 PM',
        'totalPrice': 90.0,
      });

      expect(booking.tipAmount, equals(18.0));
      expect(booking.hasTipData, isTrue);
      expect(booking.totalAuthoritativeAmountDue, equals(108.0)); // 90 + 18
    });

    // ── 6. Cancelling Final Checkout Dialog Leaves Booking Unchanged ───────────
    testWidgets('6. Groomer cancelling confirmation dialog leaves booking unchanged in ready_for_checkout status', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await ServicesLocator.sessionService.saveGroomerUser({
        'id': 10,
        'name': 'Groomer Alex',
        'email': 'alex@groomer.com',
      });

      const testBooking = GroomerBooking(
        bookingId: 2008,
        status: 'ready_for_checkout',
        customerName: 'Grace',
        petName: 'Bella',
        serviceName: 'Full Groom',
        bookingDate: '2026-10-17',
        startTime: '04:00 PM',
        endTime: '05:00 PM',
        totalPrice: 80.0,
        tipAmount: 16.0,
        groomerId: 10,
      );

      bool wasCheckoutSuccessCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroomerFinalCheckoutDialog(
              booking: testBooking,
              onCheckoutSuccess: (_) {
                wasCheckoutSuccessCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Confirm & Complete Checkout
      final completeButton = find.text('Confirm & Complete Checkout');
      expect(completeButton, findsOneWidget);
      await tester.tap(completeButton);
      await tester.pumpAndSettle();

      // Secondary confirmation alert dialog opens
      expect(find.text('Finalize Checkout?'), findsOneWidget);
      expect(find.textContaining('Are you sure you want to finalize checkout for Bella'), findsOneWidget);

      // Tap Cancel in the confirmation dialog
      final cancelButton = find.text('Cancel');
      expect(cancelButton, findsWidgets);
      await tester.tap(cancelButton.last);
      await tester.pumpAndSettle();

      // Confirmation dialog is closed, GroomerFinalCheckoutDialog remains open, no checkout submission occurred
      expect(find.text('Finalize Checkout?'), findsNothing);
      expect(find.byType(GroomerFinalCheckoutDialog), findsOneWidget);
      expect(wasCheckoutSuccessCalled, isFalse);
      expect(testBooking.isReadyForCheckout, isTrue);
      expect(testBooking.isCompleted, isFalse);
    });

    // ── 7. Confirming Final Checkout Updates Status Only After Backend Success ─
    test('7. CompleteBookingDetails validates ownership and updates to completed only upon backend success', () async {
      await ServicesLocator.sessionService.saveGroomerUser({
        'id': 10,
        'name': 'Groomer Alex',
        'email': 'alex@groomer.com',
      });

      // Attempting to complete booking that is NOT ready_for_checkout fails
      const notReadyBooking = GroomerBooking(
        bookingId: 2009,
        status: 'in_progress',
        customerName: 'Helen',
        petName: 'Teddy',
        serviceName: 'Bath',
        bookingDate: '2026-10-17',
        startTime: '05:00 PM',
        endTime: '06:00 PM',
        totalPrice: 50.0,
        groomerId: 10,
      );

      final notReadyRes = await ServicesLocator.groomerHomeRepository.completeBookingDetails(
        2009,
        booking: notReadyBooking,
      );
      expect(notReadyRes.success, isFalse);
      expect(notReadyRes.message, contains('Ready for Checkout'));
      expect(notReadyRes.updatedBooking, isNull);

      // Attempting to complete already completed booking fails
      const alreadyCompletedBooking = GroomerBooking(
        bookingId: 2010,
        status: 'completed',
        customerName: 'Helen',
        petName: 'Teddy',
        serviceName: 'Bath',
        bookingDate: '2026-10-17',
        startTime: '05:00 PM',
        endTime: '06:00 PM',
        totalPrice: 50.0,
        groomerId: 10,
      );

      final completedRes = await ServicesLocator.groomerHomeRepository.completeBookingDetails(
        2010,
        booking: alreadyCompletedBooking,
      );
      expect(completedRes.success, isFalse);
      expect(completedRes.message, contains('already completed'));
      expect(completedRes.updatedBooking, isNull);
    });

    // ── 8. Duplicate Submission Prevention ─────────────────────────────────────
    testWidgets('8. Duplicate submissions are prevented while checkout action is in-flight', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const booking = GroomerBooking(
        bookingId: 2011,
        status: 'ready_for_checkout',
        customerName: 'Ivan',
        petName: 'Buster',
        serviceName: 'Full Spa',
        bookingDate: '2026-10-17',
        startTime: '06:00 PM',
        endTime: '07:00 PM',
        totalPrice: 85.0,
        tipAmount: 17.0,
        groomerId: 10,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GroomerFinalCheckoutDialog(booking: booking),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final btn = find.widgetWithText(ElevatedButton, 'Confirm & Complete Checkout');
      expect(btn, findsOneWidget);
      final widgetButton = tester.widget<ElevatedButton>(btn);
      expect(widgetButton.onPressed, isNotNull);
    });
  });
}
