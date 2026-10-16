import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_report_summary.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/reports/reports_summary_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  group('GroomerReportSummary Model Business Logic & Separation', () {
    test('Calculates appointment counts and completion rate accurately', () {
      final bookings = [
        const GroomerBooking(
          bookingId: 1,
          status: 'confirmed',
          bookingDate: '2026-10-16',
          startTime: '09:00',
          endTime: '10:00',
          petName: 'Max',
          customerName: 'Alice',
          serviceName: 'Full Grooming',
          totalPrice: 100.0,
        ),
        const GroomerBooking(
          bookingId: 2,
          status: 'in_progress',
          bookingDate: '2026-10-16',
          startTime: '10:00',
          endTime: '11:00',
          petName: 'Bella',
          customerName: 'Bob',
          serviceName: 'Bath',
          totalPrice: 60.0,
        ),
        const GroomerBooking(
          bookingId: 3,
          status: 'ready_for_checkout',
          bookingDate: '2026-10-16',
          startTime: '11:00',
          endTime: '12:00',
          petName: 'Charlie',
          customerName: 'Carol',
          serviceName: 'Nail Trim',
          totalPrice: 30.0,
        ),
        const GroomerBooking(
          bookingId: 4,
          status: 'completed',
          bookingDate: '2026-10-16',
          startTime: '12:00',
          endTime: '13:00',
          petName: 'Daisy',
          customerName: 'Dan',
          serviceName: 'Full Grooming',
          totalPrice: 120.0,
          isPaid: true,
          tipAmount: 20.0,
          taxAmount: 9.90,
        ),
        const GroomerBooking(
          bookingId: 5,
          status: 'pending',
          bookingDate: '2026-10-16',
          startTime: '13:00',
          endTime: '14:00',
          petName: 'Rocky',
          customerName: 'Eve',
          serviceName: 'Bath',
          totalPrice: 50.0,
        ),
        const GroomerBooking(
          bookingId: 6,
          status: 'cancelled',
          bookingDate: '2026-10-16',
          startTime: '14:00',
          endTime: '15:00',
          petName: 'Milo',
          customerName: 'Frank',
          serviceName: 'Spa',
          totalPrice: 85.0,
        ),
      ];

      final summary = GroomerReportSummary.fromBookings(bookings);

      expect(summary.totalAppointments, 6);
      expect(summary.confirmedAppointments, 1);
      expect(summary.inProgressAppointments, 1);
      expect(summary.readyForCheckoutAppointments, 1);
      expect(summary.completedAppointments, 1);
      expect(summary.pendingAppointments, 1);
      expect(summary.cancelledAppointments, 1);

      // Completion rate: 1 completed / 6 total = 16.66% -> 17%
      expect(summary.completionRatePercentage, '17%');
    });

    test('Strict Revenue Separation: Completed but unpaid appointment NEVER qualifies as actual collected revenue', () {
      final bookings = [
        // Completed booking, but NOT paid yet
        const GroomerBooking(
          bookingId: 101,
          status: 'completed',
          bookingDate: '2026-10-16',
          startTime: '09:00',
          endTime: '10:00',
          petName: 'Buster',
          customerName: 'Grace',
          serviceName: 'Bath & Brush',
          totalPrice: 90.0,
          isPaid: false,
          paymentStatus: 'unpaid',
        ),
        // Confirmed active booking
        const GroomerBooking(
          bookingId: 102,
          status: 'confirmed',
          bookingDate: '2026-10-16',
          startTime: '10:00',
          endTime: '11:00',
          petName: 'Luna',
          customerName: 'Henry',
          serviceName: 'Full Groom',
          totalPrice: 110.0,
          isPaid: false,
        ),
      ];

      final summary = GroomerReportSummary.fromBookings(bookings);

      // Both contribute to forecast (90 + 110 = 200)
      expect(summary.forecastRevenue, 200.0);
      expect(summary.formattedForecastRevenue, '\$200.00');

      // Actual revenue must be $0.00 (since there is payment data indicator b.paymentStatus, but 0 paid)
      expect(summary.actualRevenue, 0.0);
      expect(summary.formattedActualRevenue, '\$0.00');
    });

    test('Collected Revenue includes verified paid checkouts with tip and tax totals', () {
      final bookings = [
        // Paid checkout
        const GroomerBooking(
          bookingId: 201,
          status: 'completed',
          bookingDate: '2026-10-16',
          startTime: '09:00',
          endTime: '10:00',
          petName: 'Cooper',
          customerName: 'Iris',
          serviceName: 'Full Grooming',
          totalPrice: 100.0,
          isPaid: true,
          tipAmount: 15.0,
          taxAmount: 8.25,
        ),
        // Unpaid active booking
        const GroomerBooking(
          bookingId: 202,
          status: 'in_progress',
          bookingDate: '2026-10-16',
          startTime: '10:00',
          endTime: '11:00',
          petName: 'Ruby',
          customerName: 'Jack',
          serviceName: 'Bath',
          totalPrice: 70.0,
          isPaid: false,
        ),
      ];

      final summary = GroomerReportSummary.fromBookings(bookings);

      expect(summary.forecastRevenue, 70.0);
      expect(summary.actualRevenue, 100.0);
      expect(summary.actualTips, 15.0);
      expect(summary.actualTaxes, 8.25);
      expect(summary.actualTotalCollected, 123.25);

      expect(summary.formattedActualRevenue, '\$100.00');
      expect(summary.formattedActualTips, '\$15.00');
      expect(summary.formattedActualTaxes, '\$8.25');
      expect(summary.formattedActualTotalCollected, '\$123.25');
    });

    test('Discloses Unavailable when backend omits payment and tip fields rather than fabricating \$0.00', () {
      // Raw booking without any payment/tip fields
      final bookings = [
        const GroomerBooking(
          bookingId: 301,
          status: 'confirmed',
          bookingDate: '2026-10-16',
          startTime: '09:00',
          endTime: '10:00',
          petName: 'Coco',
          customerName: 'Karen',
          serviceName: 'Basic Groom',
          totalPrice: 75.0,
        ),
      ];

      final summary = GroomerReportSummary.fromBookings(bookings);

      expect(summary.forecastRevenue, 75.0);
      expect(summary.isActualRevenueAvailable, false);
      expect(summary.formattedActualRevenue, 'Unavailable');
      expect(summary.isTipsAvailable, false);
      expect(summary.formattedActualTips, 'Unavailable');
    });

    test('Cancelled bookings are excluded from forecast and actual revenue', () {
      final bookings = [
        const GroomerBooking(
          bookingId: 401,
          status: 'cancelled',
          bookingDate: '2026-10-16',
          startTime: '09:00',
          endTime: '10:00',
          petName: 'Leo',
          customerName: 'Liam',
          serviceName: 'Full Groom',
          totalPrice: 200.0,
        ),
        const GroomerBooking(
          bookingId: 402,
          status: 'rejected',
          bookingDate: '2026-10-16',
          startTime: '10:00',
          endTime: '11:00',
          petName: 'Mia',
          customerName: 'Noah',
          serviceName: 'Bath',
          totalPrice: 150.0,
        ),
      ];

      final summary = GroomerReportSummary.fromBookings(bookings);

      expect(summary.totalAppointments, 2);
      expect(summary.cancelledAppointments, 2);
      expect(summary.forecastRevenue, 0.0);
    });
  });

  group('ReportDatePreset Date Range Resolution', () {
    final fixedWednesday = DateTime(2026, 10, 14); // 2026-10-14 is Wednesday

    test('Today preset resolves to single reference day', () {
      final range = ReportDatePreset.today.resolveRange(fixedWednesday);
      expect(range.start, DateTime(2026, 10, 14));
      expect(range.end, DateTime(2026, 10, 14));
    });

    test('This Week preset resolves Monday to Sunday', () {
      final range = ReportDatePreset.thisWeek.resolveRange(fixedWednesday);
      expect(range.start, DateTime(2026, 10, 12)); // Monday
      expect(range.end, DateTime(2026, 10, 18)); // Sunday
    });

    test('This Month preset resolves 1st to last day of the month', () {
      final range = ReportDatePreset.thisMonth.resolveRange(fixedWednesday);
      expect(range.start, DateTime(2026, 10, 1));
      expect(range.end, DateTime(2026, 10, 31));
    });
  });

  group('ReportsSummaryPage UI Rendering & Filtering', () {
    final List<SalonGroomer> testGroomers = [
      const SalonGroomer(
        id: 1,
        groomerCode: 'groomer_1',
        firstName: 'Sarah',
        lastName: 'Connor',
        name: 'Sarah Connor',
        role: 'Senior Stylist',
      ),
      const SalonGroomer(
        id: 2,
        groomerCode: 'groomer_2',
        firstName: 'John',
        lastName: 'Wick',
        name: 'John Wick',
        role: 'Master Groomer',
      ),
    ];

    final List<GroomerBooking> testBookings = [
      const GroomerBooking(
        bookingId: 501,
        groomerId: 1,
        groomerCode: 'groomer_1',
        groomerName: 'Sarah Connor',
        status: 'confirmed',
        bookingDate: '2026-10-14',
        startTime: '09:00',
        endTime: '10:00',
        petName: 'Zeus',
        customerName: 'Oliver',
        customerMobile: '555-0101',
        serviceName: 'Executive Groom',
        totalPrice: 150.0,
        isPaid: false,
      ),
      const GroomerBooking(
        bookingId: 502,
        groomerId: 2,
        groomerCode: 'groomer_2',
        groomerName: 'John Wick',
        status: 'completed',
        bookingDate: '2026-10-14',
        startTime: '10:00',
        endTime: '11:00',
        petName: 'Shadow',
        customerName: 'Penny',
        customerMobile: '555-0102',
        serviceName: 'Bath & De-shed',
        totalPrice: 95.0,
        isPaid: true,
        tipAmount: 20.0,
        taxAmount: 7.84,
      ),
      const GroomerBooking(
        bookingId: 503,
        groomerId: 1,
        groomerCode: 'groomer_1',
        groomerName: 'Sarah Connor',
        status: 'cancelled',
        bookingDate: '2026-10-14',
        startTime: '11:00',
        endTime: '12:00',
        petName: 'Ginger',
        customerName: 'Quinn',
        customerMobile: '555-0103',
        serviceName: 'Full Spa',
        totalPrice: 120.0,
      ),
    ];

    testWidgets('Renders presets, metrics, and filters correctly for All Groomers', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 2400));

      await tester.pumpWidget(
        MaterialApp(
          home: ReportsSummaryPage(
            initialBookings: testBookings,
            initialSalonGroomers: testGroomers,
            initialPreset: ReportDatePreset.today,
            initialCustomRange: DateTimeRange(
              start: DateTime(2026, 10, 14),
              end: DateTime(2026, 10, 14),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Reports Summary'), findsWidgets);

      // Verify Date Presets
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);

      // Verify Groomer Chips
      expect(find.text('All Groomers'), findsOneWidget);
      expect(find.text('Sarah Connor'), findsWidgets);
      expect(find.text('John Wick'), findsWidgets);

      // Verify Revenue Metrics
      expect(find.text('Forecast Revenue'), findsOneWidget);
      expect(find.text('\$150.00'), findsWidgets); // Sarah's confirmed booking

      expect(find.text('Actual Collected'), findsOneWidget);
      expect(find.text('\$95.00'), findsWidgets); // John's completed paid booking

      expect(find.text('Confirmed Tips'), findsOneWidget);
      expect(find.text('\$20.00'), findsWidgets);

      // Verify Appointment Cards in Itemized List
      expect(find.textContaining('Zeus'), findsOneWidget);
      expect(find.textContaining('Shadow'), findsOneWidget);
      expect(find.textContaining('Ginger'), findsOneWidget);

      // Verify Paid/Unpaid badges
      expect(find.text('PAID'), findsOneWidget);
      expect(find.text('UNPAID'), findsNWidgets(2));
    });

    testWidgets('Filtering by single groomer isolates data strictly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 2400));

      await tester.pumpWidget(
        MaterialApp(
          home: ReportsSummaryPage(
            initialBookings: testBookings,
            initialSalonGroomers: testGroomers,
            initialPreset: ReportDatePreset.today,
            initialGroomerFilterId: '1',
            initialCustomRange: DateTimeRange(
              start: DateTime(2026, 10, 14),
              end: DateTime(2026, 10, 14),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only Sarah Connor's bookings should be displayed
      expect(find.textContaining('Zeus'), findsOneWidget);
      expect(find.textContaining('Ginger'), findsOneWidget);
      // John Wick's booking Shadow must NOT be visible
      expect(find.textContaining('Shadow'), findsNothing);

      // Forecast revenue for Sarah is $150.00, collected sales is $0.00
      expect(find.text('\$150.00'), findsWidgets);
      expect(find.text('\$0.00'), findsWidgets);
    });

    testWidgets('Search input filters itemized list by pet, customer, and service name', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 2400));

      await tester.pumpWidget(
        MaterialApp(
          home: ReportsSummaryPage(
            initialBookings: testBookings,
            initialSalonGroomers: testGroomers,
            initialPreset: ReportDatePreset.today,
            initialCustomRange: DateTimeRange(
              start: DateTime(2026, 10, 14),
              end: DateTime(2026, 10, 14),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      // Search for 'Zeus'
      await tester.enterText(searchField, 'Zeus');
      await tester.pumpAndSettle();

      expect(find.text('Zeus (Dog)'), findsOneWidget);
      expect(find.textContaining('Shadow'), findsNothing);
      expect(find.textContaining('Ginger'), findsNothing);

      // Clear search
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      expect(find.text('Zeus (Dog)'), findsOneWidget);
      expect(find.text('Shadow (Dog)'), findsOneWidget);
      expect(find.text('Ginger (Dog)'), findsOneWidget);
    });

    testWidgets('Secondary status chip filters appointment list by status', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 2400));

      await tester.pumpWidget(
        MaterialApp(
          home: ReportsSummaryPage(
            initialBookings: testBookings,
            initialSalonGroomers: testGroomers,
            initialPreset: ReportDatePreset.today,
            initialCustomRange: DateTimeRange(
              start: DateTime(2026, 10, 14),
              end: DateTime(2026, 10, 14),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Completed' status chip
      final completedChip = find.widgetWithText(ChoiceChip, 'Completed');
      expect(completedChip, findsOneWidget);
      await tester.tap(completedChip);
      await tester.pumpAndSettle();

      // Only Shadow (completed) should appear
      expect(find.textContaining('Shadow'), findsOneWidget);
      expect(find.textContaining('Zeus'), findsNothing);
      expect(find.text('Ginger'), findsNothing);
    });
  });
}
