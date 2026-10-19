import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/mobile/groomer_home_page_mobile.dart';
import 'package:toastification/toastification.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  setUp(() {
    ToastUtil.resetForTesting();
  });

  group('Groomer Portal Single Toast & Duplicate Suppression Tests', () {
    testWidgets('ToastUtil suppresses duplicate identical toast within debounce window', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => ToastificationWrapper(child: child!),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  ToastUtil.showSuccessToast(ctx, 'Booking checked in successfully');
                  // Immediate identical duplicate call
                  ToastUtil.showSuccessToast(ctx, 'Booking checked in successfully');
                },
                child: const Text('Trigger Duplicate'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Trigger Duplicate'));
      await tester.pump(const Duration(milliseconds: 400));

      final manager = toastification.managers[Alignment.bottomRight];
      expect(manager, isNotNull);
      // Exactly ONE toast should be registered, duplicate was suppressed
      expect(manager!.notifications.length, equals(1));

      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('ToastUtil suppresses follow-up info notification toast after success toast', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => ToastificationWrapper(child: child!),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  // Success toast from direct groomer action
                  ToastUtil.showSuccessToast(ctx, 'Milestone updated successfully');
                  // Simulated secondary notification broadcast
                  ToastUtil.showInfoToast(ctx, 'Booking Milestone Updated');
                },
                child: const Text('Trigger Action And Notification'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Trigger Action And Notification'));
      await tester.pump(const Duration(milliseconds: 400));

      final manager = toastification.managers[Alignment.bottomRight];
      expect(manager, isNotNull);
      // Only the success toast is registered; secondary info toast was suppressed
      expect(manager!.notifications.length, equals(1));

      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('ToastUtil debounces rapid consecutive toasts within 600ms', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => ToastificationWrapper(child: child!),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  ToastUtil.showSuccessToast(ctx, 'First message');
                  ToastUtil.showErrorToast(ctx, 'Second message in rapid succession');
                },
                child: const Text('Trigger Rapid'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Trigger Rapid'));
      await tester.pump(const Duration(milliseconds: 400));

      final manager = toastification.managers[Alignment.bottomRight];
      expect(manager, isNotNull);
      // Rapid secondary toast was debounced, maintaining only 1 active toast
      expect(manager!.notifications.length, equals(1));

      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('Local dispatch notifications in groomer socket stream do not trigger second toast', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final bookings = [
        GroomerBooking(
          bookingId: 991,
          status: 'in_progress',
          bookingDate: dateStr,
          startTime: '10:00 AM',
          endTime: '11:00 AM',
          petName: 'Bella',
          customerName: 'Carol',
          serviceName: 'Full Grooming',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => ToastificationWrapper(child: child!),
          home: GroomerHomePageMobile(
            initialBookings: bookings,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Emit local dispatch notification into socket stream
      final localNotif = AppNotification(
        id: 99991,
        title: 'Booking Status Updated',
        message: 'Bella is now ready for checkout',
        type: 'booking_status_updated',
        isRead: false,
        createdAt: DateTime.now(),
        metadata: {
          'bookingId': 991,
          'isLocalDispatch': true,
        },
      );

      ServicesLocator.groomerSocketService.handleDirectNotification(localNotif);
      await tester.pump();

      // The local notification is recorded in state/list, but info toast is suppressed
      expect(find.text('Booking Status Updated'), findsNothing);

      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });
}
