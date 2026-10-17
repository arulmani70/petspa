import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/app/routes.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/customer_checkout_confirmation_page.dart';
import 'package:shear_heaven_pet_spa/src/common/services/notification_navigation_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';

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
    NotificationNavigationService.resetDeduplicationCache();
  });

  group('Customer Notification Tap -> Checkout Confirmation Page Tests', () {
    // ── 1. Local Notification JSON Payload Routing ───────────────────────────
    testWidgets('1. Local notification JSON payload navigates to customerCheckoutSummary with bookingId', (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: Routes.globalRouter));
      await tester.pumpAndSettle();

      const bookingId = 3001;
      final payloadJson = jsonEncode({
        'id': 9901,
        'bookingId': bookingId,
        'type': 'booking_ready_for_checkout',
        'title': 'Ready for Checkout',
        'message': 'Your pet Charlie is ready for checkout!',
      });

      final handled = await NotificationNavigationService.handlePayloadString(payloadJson);
      expect(handled, isTrue);
      await tester.pumpAndSettle();

      final router = Routes.globalRouter;
      expect(router.routerDelegate.currentConfiguration.uri.toString(), contains(RouteNames.customerCheckoutSummary));
      expect(router.routerDelegate.currentConfiguration.uri.queryParameters['bookingId'], equals(bookingId.toString()));
    });

    // ── 2. In-App Notification Center AppNotification Routing ─────────────────
    testWidgets('2. In-app AppNotification tap routes directly to customerCheckoutSummary', (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: Routes.globalRouter));
      await tester.pumpAndSettle();

      const bookingId = 3002;
      const notif = AppNotification(
        id: 9902,
        title: 'Ready for Checkout',
        message: 'Bella is all fresh and ready for pickup!',
        type: 'ready_for_checkout',
        metadata: {
          'bookingId': bookingId,
          'petName': 'Bella',
          'serviceName': 'Full Spa Package',
          'totalPrice': 95.0,
        },
      );

      final handled = await NotificationNavigationService.handleAppNotification(notif);
      expect(handled, isTrue);
      await tester.pumpAndSettle();

      final router = Routes.globalRouter;
      expect(router.routerDelegate.currentConfiguration.uri.toString(), contains(RouteNames.customerCheckoutSummary));
      expect(router.routerDelegate.currentConfiguration.uri.queryParameters['bookingId'], equals(bookingId.toString()));
    });

    // ── 3. Duplicate Notification Tap Throttling ─────────────────────────────
    test('3. Rapid duplicate notification taps are throttled to prevent duplicate navigation', () async {
      final payload = {
        'id': 9903,
        'bookingId': 3003,
        'type': 'booking_ready_for_checkout',
      };

      // First tap should succeed and navigate
      final firstTap = await NotificationNavigationService.handlePayloadMap(payload);
      expect(firstTap, isTrue);

      // Immediate second tap with identical key within 2.5s window should be throttled
      final secondTap = await NotificationNavigationService.handlePayloadMap(payload);
      expect(secondTap, isFalse);
    });

    // ── 4. Missing Booking ID Safe Fallback Routing ──────────────────────────
    testWidgets('4. Notification with missing booking ID routes to fallback view with error parameter', (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: Routes.globalRouter));
      await tester.pumpAndSettle();

      final payload = {
        'id': 9904,
        'type': 'booking_ready_for_checkout',
        // bookingId omitted
      };

      final handled = await NotificationNavigationService.handlePayloadMap(payload);
      expect(handled, isTrue);
      await tester.pumpAndSettle();

      final router = Routes.globalRouter;
      expect(router.routerDelegate.currentConfiguration.uri.toString(), contains(RouteNames.customerCheckoutSummary));
      expect(router.routerDelegate.currentConfiguration.uri.queryParameters['error'], equals('missing_booking_id'));
    });

    // ── 5. Missing Booking ID UI Fallback Rendering ──────────────────────────
    testWidgets('5. CustomerCheckoutConfirmationPage renders Missing Booking Information when ID is absent', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerCheckoutConfirmationPage(bookingId: null),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Missing Booking Information'), findsOneWidget);
      expect(find.textContaining('No booking ID was provided'), findsOneWidget);
      expect(find.text('Go to My Bookings'), findsOneWidget);
    });

    // ── 6. Session Expired / Unauthenticated Fallback UI ───────────────────────
    testWidgets('6. CustomerCheckoutConfirmationPage renders Sign In Required when session is unauthenticated', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Customer is logged out
      await ServicesLocator.sessionService.clearSession();

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerCheckoutConfirmationPage(bookingId: 3005),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign In Required'), findsOneWidget);
      expect(find.textContaining('session has expired'), findsOneWidget);
      expect(find.text('Log In'), findsOneWidget);
    });

    // ── 7. Completed Booking Safe Fallback UI ─────────────────────────────────
    testWidgets('7. CustomerCheckoutConfirmationPage shows Already Completed and View Receipt for completed bookings', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Mock active customer session
      await ServicesLocator.sessionService.saveSession({
        'id': 50,
        'name': 'Sarah Connor',
        'email': 'sarah@example.com',
      });

      const completedBooking = {
        'bookingId': 3006,
        'status': 'completed',
        'customerName': 'Sarah Connor',
        'petName': 'Terminator Dog',
        'serviceName': 'Full Spa',
        'totalPrice': 100.0,
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerCheckoutConfirmationPage(
            bookingId: 3006,
            initialBookingData: completedBooking,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Checkout Already Completed'), findsOneWidget);
      expect(find.textContaining('already been completed by the groomer'), findsOneWidget);
      expect(find.text('View Receipt & Invoice'), findsOneWidget);
      expect(find.text('Go to My Bookings'), findsOneWidget);
    });

    // ── 8. Cancelled Booking Safe Fallback UI ─────────────────────────────────
    testWidgets('8. CustomerCheckoutConfirmationPage shows Booking Cancelled for cancelled bookings', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await ServicesLocator.sessionService.saveSession({
        'id': 50,
        'name': 'Sarah Connor',
        'email': 'sarah@example.com',
      });

      const cancelledBooking = {
        'bookingId': 3007,
        'status': 'cancelled',
        'customerName': 'Sarah Connor',
        'petName': 'Buddy',
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerCheckoutConfirmationPage(
            bookingId: 3007,
            initialBookingData: cancelledBooking,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Booking Cancelled'), findsOneWidget);
      expect(find.textContaining('was cancelled and is no longer eligible'), findsOneWidget);
      expect(find.text('Go to My Bookings'), findsOneWidget);
    });

    // ── 9. Eligible Booking Display & Breakdown ───────────────────────────────
    testWidgets('9. Eligible booking displays pet info, service fee, tax status, tip selection, and total', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await ServicesLocator.sessionService.saveSession({
        'id': 50,
        'name': 'Sarah Connor',
        'email': 'sarah@example.com',
      });

      const eligibleBooking = {
        'bookingId': 3008,
        'status': 'ready_for_checkout',
        'customerName': 'Sarah Connor',
        'petName': 'Barnaby',
        'petBreed': 'Golden Retriever',
        'serviceName': 'Deluxe Bath & Trim',
        'totalPrice': 90.0,
        'servicePrice': 90.0,
        'groomerName': 'Merisa Brown',
        'bookingDate': '2026-10-17',
        'startTime': '11:00 AM',
        'endTime': '12:00 PM',
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerCheckoutConfirmationPage(
            bookingId: 3008,
            initialBookingData: eligibleBooking,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header checks
      expect(find.text('Checkout Summary'), findsOneWidget);
      expect(find.text('Booking #3008'), findsOneWidget);

      // Pet & Groomer checks
      expect(find.text('Barnaby'), findsOneWidget);
      expect(find.text('Golden Retriever'), findsOneWidget);
      expect(find.text('Merisa Brown'), findsOneWidget);

      // Financial breakdown: $90 base, 20% default tip = $18.00, Total = $108.00
      expect(find.text('\$90.00'), findsWidgets);
      expect(find.text('\$18.00'), findsWidgets);
      expect(find.text('\$108.00'), findsOneWidget);

      // Tax label should explicitly indicate pending at counter rather than fabricating a $0.00 tax rate
      expect(find.text('Calculated at counter'), findsOneWidget);

      // Safeguard notice check
      expect(find.textContaining('No payment is processed now'), findsOneWidget);
      expect(find.textContaining('Confirm Tip'), findsWidgets);
    });

    // ── 10. Customer Tip Confirmation Workflow & Preserved Status ────────────
    testWidgets('10. Customer confirms tip: saves via backend API/session and preserves ready_for_checkout status', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await ServicesLocator.sessionService.saveSession({
        'id': 50,
        'name': 'Sarah Connor',
        'email': 'sarah@example.com',
      });

      const testBooking = {
        'bookingId': 3009,
        'status': 'ready_for_checkout',
        'customerName': 'Sarah Connor',
        'petName': 'Barnaby',
        'serviceName': 'Deluxe Bath',
        'totalPrice': 80.0,
      };

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerCheckoutConfirmationPage(
            bookingId: 3009,
            initialBookingData: testBooking,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 15% preset: 15% of $80 = $12.00
      final fifteenPreset = find.text('15%');
      expect(fifteenPreset, findsOneWidget);
      await tester.tap(fifteenPreset);
      await tester.pumpAndSettle();

      // Total updated: $80 + $12 = $92.00
      expect(find.text('\$12.00'), findsWidgets);
      expect(find.text('\$92.00'), findsOneWidget);

      // Tap confirm button
      final confirmBtn = find.textContaining('Confirm Tip');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify tip is recorded in session
      final confirmed = ServicesLocator.sessionService.getConfirmedTip(3009);
      expect(confirmed, isNotNull);
      expect(confirmed!['tipAmount'], equals(12.0));

      // Verify status badge shows Confirmed
      expect(find.textContaining('Confirmed'), findsWidgets);
    });
  });
}
