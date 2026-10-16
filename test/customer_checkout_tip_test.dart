import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/bookings/bloc/booking_bloc.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/booking_details_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/widgets/customer_checkout_summary_sheet.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  group('Step 9 – Customer Checkout & Tip Confirmation: Repository & Safeguards', () {
    test('confirmTipDetails rejects invalid booking ID (<= 0)', () async {
      final repo = ServicesLocator.bookingRepository;
      final result = await repo.confirmTipDetails(
        bookingId: 0,
        tipAmount: 15.0,
      );
      expect(result.success, isFalse);
      expect(result.message, contains('Invalid booking ID'));
      expect(result.confirmedTipAmount, isNull);
    });

    test('confirmTipDetails rejects negative tip amount', () async {
      final repo = ServicesLocator.bookingRepository;
      final result = await repo.confirmTipDetails(
        bookingId: 901,
        tipAmount: -5.0,
      );
      expect(result.success, isFalse);
      expect(result.message, contains('cannot be negative'));
      expect(result.confirmedTipAmount, isNull);
    });

    test('CRITICAL SAFEGUARD: confirmTipDetails never marks booking completed and preserves ready_for_checkout status', () async {
      final repo = ServicesLocator.bookingRepository;
      const initialBooking = {
        'id': 902,
        'bookingId': 902,
        'status': 'ready_for_checkout',
        'isPaid': false,
        'totalPrice': 100.0,
      };

      final result = await repo.confirmTipDetails(
        bookingId: 902,
        tipAmount: 20.0,
        tipPercentage: 20.0,
        booking: initialBooking,
      );

      expect(result.success, isTrue);
      expect(result.confirmedTipAmount, equals(20.0));
      expect(result.confirmedTipPercentage, equals(20.0));

      final updated = result.updatedBooking;
      expect(updated, isNotNull);
      // Status MUST remain ready_for_checkout, NEVER completed
      expect(updated!['status'], equals('ready_for_checkout'));
      expect(updated['status'], isNot(equals('completed')));
      // Payment MUST NOT be marked as true
      expect(updated['isPaid'], isNot(equals(true)));
      expect(updated['isTipConfirmed'], isTrue);
    });

    test('confirmTipDetails handles unverified backend gracefully without crashing', () async {
      final repo = ServicesLocator.bookingRepository;
      final result = await repo.confirmTipDetails(
        bookingId: 999999, // Unverified ID
        tipAmount: 10.0,
        booking: {'status': 'ready_for_checkout'},
      );

      expect(result.success, isTrue);
      expect(result.confirmedTipAmount, equals(10.0));
      // Documents pending backend status
      expect(result.isPendingBackend, isTrue);
      expect(result.message, contains('pending endpoint deployment'));
    });
  });

  group('Step 9 – Customer Checkout & Tip Confirmation: BookingBloc Integration', () {
    test('BookingBloc handles ConfirmTipEvent and updates confirmedTips state', () async {
      final repo = ServicesLocator.bookingRepository;
      final bloc = BookingBloc(repository: repo);

      const bookingData = {
        'id': 905,
        'bookingId': 905,
        'status': 'ready_for_checkout',
      };

      bloc.add(const ConfirmTipEvent(
        bookingId: 905,
        tipAmount: 18.0,
        tipPercentage: 18.0,
        booking: bookingData,
      ));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<BookingState>((s) => s.confirmingTipBookingIds.contains(905)),
          predicate<BookingState>((s) =>
              !s.confirmingTipBookingIds.contains(905) &&
              s.status == BookingStatus.success &&
              s.confirmedTips[905] == 18.0),
        ]),
      );

      await bloc.close();
    });
  });

  group('Step 9 – Customer Checkout Summary Sheet: UI Rendering & Financial Breakdown', () {
    testWidgets('Renders pet details, booking info, itemized charges, and default 20% tip', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const mockBooking = {
        'id': 910,
        'bookingId': 910,
        'petName': 'Charlie',
        'petBreed': 'Golden Retriever',
        'groomerName': 'Sarah Jenkins',
        'bookingDate': '2026-10-25',
        'startTime': '10:00 AM',
        'endTime': '11:30 AM',
        'serviceName': 'Full Grooming Spa',
        'totalPrice': 100.0,
        'addons': [
          {'name': 'Nail Grinding', 'price': 15.0},
          {'name': 'Teeth Brushing', 'price': 10.0},
        ],
        'status': 'ready_for_checkout',
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomerCheckoutSummarySheet(booking: mockBooking),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & booking ID
      expect(find.text('Checkout Summary'), findsOneWidget);
      expect(find.text('Booking #910'), findsOneWidget);

      // Verify Pet Details
      expect(find.text('Charlie'), findsOneWidget);
      expect(find.text('Golden Retriever'), findsOneWidget);
      expect(find.text('Sarah Jenkins'), findsOneWidget);

      // Verify Service & Add-ons
      expect(find.text('Full Grooming Spa'), findsOneWidget);
      expect(find.text('+ Nail Grinding'), findsOneWidget);
      expect(find.text('+ Teeth Brushing'), findsOneWidget);

      // Verify Subtotal
      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text('\$100.00'), findsWidgets);

      // Verify Default Tip (20% of $100 = $20.00)
      expect(find.text('Total Due at Counter'), findsOneWidget);
      expect(find.text('\$120.00'), findsOneWidget); // 100 + 20 = 120
      expect(find.text('Includes \$20.00 tip'), findsOneWidget);
    });

    testWidgets('Financial Rule: Missing optional fields (taxes, discounts, deposits) are NOT fabricated with fake numbers', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const mockBookingMissingFields = {
        'id': 911,
        'bookingId': 911,
        'petName': 'Bella',
        'serviceName': 'Bath & Brush',
        'totalPrice': 60.0,
        'taxAmount': null,
        'discountAmount': null,
        'depositAmount': null,
        'status': 'ready_for_checkout',
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomerCheckoutSummarySheet(booking: mockBookingMissingFields),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Taxes should be marked as "Calculated at counter", not $0.00
      expect(find.text('Calculated at counter'), findsOneWidget);
      expect(find.text('Estimated Sales Tax'), findsOneWidget);

      // Discount and Deposit rows should NOT exist
      expect(find.text('Discount / Promo'), findsNothing);
      expect(find.text('Deposit Pre-paid'), findsNothing);
    });

    testWidgets('Displays verified discounts and deposits when provided by backend', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const mockBookingWithFinancials = {
        'id': 912,
        'bookingId': 912,
        'petName': 'Max',
        'serviceName': 'Full Grooming',
        'totalPrice': 100.0,
        'discountAmount': 10.0,
        'depositAmount': 25.0,
        'taxAmount': 5.0,
        'status': 'ready_for_checkout',
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomerCheckoutSummarySheet(booking: mockBookingWithFinancials),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Discount row displayed with minus sign
      expect(find.text('Discount / Promo'), findsOneWidget);
      expect(find.text('-\$10.00'), findsOneWidget);

      // Deposit row displayed
      expect(find.text('Deposit Pre-paid'), findsOneWidget);
      expect(find.text('-\$25.00'), findsOneWidget);

      // Tax row displayed
      expect(find.text('Taxes'), findsOneWidget);
      expect(find.text('+\$5.00'), findsOneWidget);

      // Subtotal = 100 - 10 (discount) + 5 (tax) - 25 (deposit) + 20 (20% tip) = 90
      expect(find.text('\$90.00'), findsOneWidget);
    });
  });

  group('Step 9 – Interactive Tip Selection & Real-Time Calculation', () {
    testWidgets('Selecting 15%, 25%, and No Tip recalculates total in real-time', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const mockBooking = {
        'id': 913,
        'bookingId': 913,
        'totalPrice': 100.0,
        'status': 'ready_for_checkout',
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomerCheckoutSummarySheet(booking: mockBooking),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially 20%: Total = $120.00
      expect(find.text('\$120.00'), findsOneWidget);

      // Select 15%
      await tester.tap(find.text('15%'));
      await tester.pumpAndSettle();
      expect(find.text('Includes \$15.00 tip'), findsOneWidget);
      expect(find.text('\$115.00'), findsOneWidget);

      // Select 25%
      await tester.tap(find.text('25%'));
      await tester.pumpAndSettle();
      expect(find.text('Includes \$25.00 tip'), findsOneWidget);
      expect(find.text('\$125.00'), findsOneWidget);

      // Select No Tip
      await tester.tap(find.text('No Tip'));
      await tester.pumpAndSettle();
      expect(find.text('No tip added'), findsOneWidget);
      expect(find.text('\$100.00'), findsWidgets);
      expect(find.text('Confirm No Tip'), findsOneWidget);
    });

    testWidgets('Custom tip option expands input, updates total, and validates input', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const mockBooking = {
        'id': 914,
        'bookingId': 914,
        'totalPrice': 80.0,
        'status': 'ready_for_checkout',
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomerCheckoutSummarySheet(booking: mockBooking),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Custom
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      // Custom input field should appear
      expect(find.byType(TextField), findsOneWidget);

      final confirmBtn = find.text('Confirm No Tip');
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();
      expect(find.text('Please enter a tip amount.'), findsOneWidget);

      // Enter valid custom amount "16.00"
      await tester.enterText(find.byType(TextField), '16.00');
      await tester.pumpAndSettle();

      // Total Due = 80 + 16 = $96.00
      expect(find.text('\$96.00'), findsOneWidget);
      expect(find.text('Includes \$16.00 tip'), findsOneWidget);
      expect(find.text('Confirm Tip (\$16.00)'), findsOneWidget);
    });
  });

  group('Step 9 – Tip Confirmation Workflow & Payment Safeguard Guarantees', () {
    testWidgets('Confirm Tip updates button state to confirmed and allows changing tip', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      Map<String, dynamic>? confirmedBooking;
      const mockBooking = {
        'id': 915,
        'bookingId': 915,
        'totalPrice': 50.0,
        'status': 'ready_for_checkout',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerCheckoutSummarySheet(
              booking: mockBooking,
              onTipConfirmed: (b) => confirmedBooking = b,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default 20% on $50 = $10.00
      final confirmBtn = find.text('Confirm Tip (\$10.00)');
      expect(confirmBtn, findsOneWidget);

      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify confirmed UI elements
      expect(find.text('Tip Confirmed: \$10.00'), findsOneWidget);
      final changeTipBtn = find.text('Change Tip');
      expect(changeTipBtn, findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // Verify callback was invoked and status was NOT altered to completed
      expect(confirmedBooking, isNotNull);
      expect(confirmedBooking!['status'], equals('ready_for_checkout'));
      expect(confirmedBooking!['tipAmount'], equals(10.0));

      // Test "Change Tip" allows re-selecting tip before final checkout
      await tester.ensureVisible(changeTipBtn);
      await tester.tap(changeTipBtn);
      await tester.pumpAndSettle();

      expect(find.text('Confirm Tip (\$10.00)'), findsOneWidget);
    });

    testWidgets('Displays clear payment safeguard notice confirming no immediate charge is made', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const mockBooking = {
        'id': 916,
        'bookingId': 916,
        'totalPrice': 70.0,
        'status': 'ready_for_checkout',
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomerCheckoutSummarySheet(booking: mockBooking),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Safeguard notice must be clearly displayed to customer
      expect(
        find.textContaining('No payment is processed now'),
        findsOneWidget,
      );
      expect(
        find.textContaining('settle your bill at the spa counter'),
        findsOneWidget,
      );
    });
  });

  group('Step 9 – Customer Booking Details Page Integration', () {
    testWidgets('Displays Ready for Checkout pill and Review Checkout Summary & Tip banner when status is ready_for_checkout', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const mockBookingData = {
        'id': 917,
        'bookingId': 917,
        'petName': 'Rocky',
        'breed': 'Labrador',
        'date_label': 'Oct 20, 2026',
        'time_label': '10:00 AM',
        'status': 'ready_for_checkout',
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: BookingDetailsPageMobile(bookingData: mockBookingData),
        ),
      );
      await tester.pumpAndSettle();

      // Verify status label
      expect(find.text('Ready for Checkout'), findsWidgets);

      // Verify banner action button
      expect(find.text('Review Checkout Summary & Tip'), findsOneWidget);
    });
  });
}
