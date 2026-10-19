import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/forecast/forecast_page.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/mobile/groomer_home_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/reports/reports_summary_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  group('Groomer Bottom Navigation & Notification Sheet Tests', () {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final bookings = [
      GroomerBooking(
        bookingId: 901,
        status: 'confirmed',
        bookingDate: dateStr,
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        petName: 'Milo',
        customerName: 'Alice',
        serviceName: 'Full Grooming',
      ),
    ];

    testWidgets('Bottom dock renders 5 items and removes notifications icon from dock', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: GroomerHomePageMobile(
            initialBookings: bookings,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify bottom dock icons exist (size: 26)
      expect(find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.calendar_month_outlined && w.size == 26), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.access_time_rounded && w.size == 26), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.trending_up_rounded && w.size == 26), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.bar_chart_rounded && w.size == 26), findsOneWidget);

      // Verify notifications_outlined is NOT in the bottom dock
      expect(find.byIcon(Icons.notifications_outlined), findsNothing);

      // Verify top header has the notification bell button
      expect(find.byIcon(Icons.notifications), findsOneWidget);
    });

    testWidgets('Tapping Revenue Forecast dock item opens ForecastPage embedded', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: GroomerHomePageMobile(
            initialBookings: bookings,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Revenue Forecast dock item (size: 26)
      final forecastDockItem = find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.trending_up_rounded && w.size == 26);
      expect(forecastDockItem, findsOneWidget);
      await tester.tap(forecastDockItem);
      await tester.pumpAndSettle();

      // Verify ForecastPage is displayed
      expect(find.byType(ForecastPage), findsOneWidget);
      expect(find.text('Forecast'), findsOneWidget);
    });

    testWidgets('Tapping Reports Summary dock item opens ReportsSummaryPage embedded', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: GroomerHomePageMobile(
            initialBookings: bookings,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Reports Summary dock item (size: 26)
      final reportsDockItem = find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.bar_chart_rounded && w.size == 26);
      expect(reportsDockItem, findsOneWidget);
      await tester.tap(reportsDockItem);
      await tester.pumpAndSettle();

      // Verify ReportsSummaryPage is displayed
      expect(find.byType(ReportsSummaryPage), findsOneWidget);
      expect(find.text('Reports Summary'), findsOneWidget);
    });

    testWidgets('Tapping notification bell in header opens Staff Notifications sheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: GroomerHomePageMobile(
            initialBookings: bookings,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap notification bell in top header card
      final notifBell = find.byIcon(Icons.notifications);
      expect(notifBell, findsOneWidget);
      await tester.tap(notifBell);
      await tester.pumpAndSettle();

      // Verify modal bottom sheet opened with Staff Notifications
      expect(find.text('Staff Notifications'), findsOneWidget);
      expect(find.text('Booking alerts and schedule updates'), findsOneWidget);
    });
  });
}
