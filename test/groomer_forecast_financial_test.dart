import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/forecast_financial_summary.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/forecast/forecast_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  group('ForecastFinancialSummary Business Rules & Aggregations', () {
    test('Calculates forecast from eligible unpaid appointments only', () {
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
          totalPrice: 120.0,
          tipAmount: 0.0,
          taxAmount: 0.0,
          isPaid: false,
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
          totalPrice: 80.0,
          isPaid: false,
        ),
      ];

      final summary = ForecastFinancialSummary.fromBookings(bookings);
      expect(summary.forecastServiceAmount, 200.0);
      expect(summary.forecastAppointmentsCount, 2);
      expect(summary.completedSales, 0.0);
      expect(summary.completedAppointmentsCount, 0);
      expect(summary.formattedForecastServiceAmount, '\$200.00');
    });

    test('Excludes cancelled appointments and pending appointments by default', () {
      final bookings = [
        const GroomerBooking(
          bookingId: 1,
          status: 'confirmed',
          bookingDate: '2026-10-16',
          startTime: '09:00',
          endTime: '10:00',
          petName: 'Max',
          customerName: 'Alice',
          serviceName: 'Grooming',
          totalPrice: 100.0,
        ),
        const GroomerBooking(
          bookingId: 2,
          status: 'cancelled',
          bookingDate: '2026-10-16',
          startTime: '10:00',
          endTime: '11:00',
          petName: 'Rocky',
          customerName: 'Charlie',
          serviceName: 'Bath',
          totalPrice: 150.0,
        ),
        const GroomerBooking(
          bookingId: 3,
          status: 'pending',
          bookingDate: '2026-10-16',
          startTime: '11:00',
          endTime: '12:00',
          petName: 'Milo',
          customerName: 'Diana',
          serviceName: 'Spa',
          totalPrice: 75.0,
        ),
      ];

      final summary = ForecastFinancialSummary.fromBookings(bookings);
      // Only the confirmed appointment ($100) should be included in forecast
      expect(summary.forecastServiceAmount, 100.0);
      expect(summary.forecastAppointmentsCount, 1);
      expect(summary.cancelledAppointmentsCount, 1);
      expect(summary.pendingAppointmentsCount, 1);
      expect(summary.totalAppointmentsCount, 3);
    });

    test('Forecast amount includes pure service charges only, strictly excluding tax and tips', () {
      final bookings = [
        const GroomerBooking(
          bookingId: 1,
          status: 'confirmed',
          bookingDate: '2026-10-16',
          startTime: '09:00',
          endTime: '10:00',
          petName: 'Max',
          customerName: 'Alice',
          serviceName: 'Grooming',
          totalPrice: 110.0,
          tipAmount: 20.0,
          taxAmount: 8.80,
          isPaid: false,
        ),
      ];

      final summary = ForecastFinancialSummary.fromBookings(bookings);
      expect(summary.forecastServiceAmount, 110.0);
      expect(summary.tipsCollected, 0.0);
      expect(summary.taxCollected, 0.0);
      expect(summary.totalCollected, 0.0);
    });

    test('Completed sales, tax, tips, and total collected are calculated separately and accurately', () {
      final bookings = [
        const GroomerBooking(
          bookingId: 1,
          status: 'completed',
          bookingDate: '2026-10-16',
          startTime: '09:00',
          endTime: '10:00',
          petName: 'Max',
          customerName: 'Alice',
          serviceName: 'Full Grooming',
          totalPrice: 150.0,
          tipAmount: 25.0,
          taxAmount: 12.0,
          isPaid: true,
        ),
        const GroomerBooking(
          bookingId: 2,
          status: 'checkout_completed',
          bookingDate: '2026-10-16',
          startTime: '10:30',
          endTime: '11:30',
          petName: 'Bella',
          customerName: 'Bob',
          serviceName: 'Bath & Brush',
          totalPrice: 90.0,
          tipAmount: 15.0,
          taxAmount: 7.20,
          isPaid: true,
        ),
      ];

      final summary = ForecastFinancialSummary.fromBookings(bookings);
      expect(summary.forecastServiceAmount, 0.0);
      expect(summary.forecastAppointmentsCount, 0);
      expect(summary.completedSales, 240.0); // 150 + 90
      expect(summary.tipsCollected, 40.0);   // 25 + 15
      expect(summary.taxCollected, 19.20);   // 12 + 7.20
      expect(summary.totalCollected, 299.20); // 240 + 19.20 + 40
      expect(summary.completedAppointmentsCount, 2);

      expect(summary.formattedCompletedSales, '\$240.00');
      expect(summary.formattedTipsCollected, '\$40.00');
      expect(summary.formattedTotalCollected, '\$299.20');
    });

    test('Paid appointments are never counted in the forecast again (prevents double-counting)', () {
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
          totalPrice: 120.0,
          isPaid: false,
        ),
        const GroomerBooking(
          bookingId: 2,
          status: 'checkout_completed',
          bookingDate: '2026-10-16',
          startTime: '10:30',
          endTime: '11:30',
          petName: 'Bella',
          customerName: 'Bob',
          serviceName: 'Bath & Brush',
          totalPrice: 80.0,
          tipAmount: 15.0,
          isPaid: true,
        ),
      ];

      final summary = ForecastFinancialSummary.fromBookings(bookings);
      // Max is in forecast ($120), Bella is in completed sales ($80)
      expect(summary.forecastServiceAmount, 120.0);
      expect(summary.completedSales, 80.0);
      expect(summary.tipsCollected, 15.0);
      expect(summary.totalVolume, 200.0);
      expect(summary.activeAppointmentsCount, 2);
    });

    test('Do not infer payment completion from generic completed appointment status', () {
      final bookings = [
        const GroomerBooking(
          bookingId: 1,
          status: 'completed', // Grooming service finished, but customer has not checked out / paid yet
          bookingDate: '2026-10-16',
          startTime: '09:00',
          endTime: '10:00',
          petName: 'Max',
          customerName: 'Alice',
          serviceName: 'Full Grooming',
          totalPrice: 150.0,
          isPaid: false,
          paymentStatus: 'unpaid',
        ),
      ];

      final summary = ForecastFinancialSummary.fromBookings(bookings);
      // Because payment/checkout has not occurred, it must remain in forecast, NOT sales!
      expect(summary.forecastServiceAmount, 150.0);
      expect(summary.forecastAppointmentsCount, 1);
      expect(summary.completedSales, 0.0);
      expect(summary.completedAppointmentsCount, 0);
    });

    test('Formats currency using configured currency symbol without hardcoding to USD', () {
      final euroSummary = const ForecastFinancialSummary(
        forecastServiceAmount: 250.0,
        completedSales: 150.0,
        tipsCollected: 20.0,
        taxCollected: 12.0,
        totalCollected: 182.0,
        currencySymbol: '€',
      );

      expect(euroSummary.formattedForecastServiceAmount, '€250.00');
      expect(euroSummary.formattedCompletedSales, '€150.00');
      expect(euroSummary.formattedTipsCollected, '€20.00');
      expect(euroSummary.formattedTotalCollected, '€182.00');
    });

    test('Calculates financial summary across dates for multi-day quarterly date range', () {
      final bookings = [
        const GroomerBooking(
          bookingId: 1,
          status: 'confirmed',
          bookingDate: '2026-10-01',
          startTime: '09:00',
          endTime: '10:00',
          petName: 'Max',
          customerName: 'Alice',
          serviceName: 'Full Grooming',
          totalPrice: 120.0,
        ),
        const GroomerBooking(
          bookingId: 2,
          status: 'confirmed',
          bookingDate: '2026-11-15',
          startTime: '10:00',
          endTime: '11:00',
          petName: 'Bella',
          customerName: 'Bob',
          serviceName: 'Bath',
          totalPrice: 80.0,
        ),
        const GroomerBooking(
          bookingId: 3,
          status: 'checkout_completed',
          bookingDate: '2026-12-31',
          startTime: '11:00',
          endTime: '12:00',
          petName: 'Charlie',
          customerName: 'Clara',
          serviceName: 'Nails',
          totalPrice: 40.0,
          isPaid: true,
        ),
      ];

      final summary = ForecastFinancialSummary.fromBookings(bookings);
      expect(summary.forecastServiceAmount, 200.0);
      expect(summary.completedSales, 40.0);
      expect(summary.totalAppointmentsCount, 3);
    });

    test('Supports JSON serialization and deserialization', () {
      final original = const ForecastFinancialSummary(
        forecastServiceAmount: 350.0,
        completedSales: 200.0,
        tipsCollected: 30.0,
        taxCollected: 16.0,
        totalCollected: 246.0,
        forecastAppointmentsCount: 3,
        completedAppointmentsCount: 2,
        cancelledAppointmentsCount: 1,
        pendingAppointmentsCount: 1,
        totalAppointmentsCount: 7,
      );

      final json = original.toJson();
      final fromJson = ForecastFinancialSummary.fromJson(json);

      expect(fromJson.forecastServiceAmount, original.forecastServiceAmount);
      expect(fromJson.completedSales, original.completedSales);
      expect(fromJson.totalCollected, original.totalCollected);
      expect(fromJson.forecastAppointmentsCount, original.forecastAppointmentsCount);
      expect(fromJson.completedAppointmentsCount, original.completedAppointmentsCount);
    });

    test('Marks financial metrics as Unavailable/Incomplete when backend omits payment and tip fields', () {
      // Simulating real availability endpoint response records where tipAmount, taxAmount, isPaid, and paymentStatus are omitted
      final rawAvailabilityBookings = [
        const GroomerBooking(
          bookingId: 201,
          status: 'confirmed',
          bookingDate: '2026-10-16',
          startTime: '09:00',
          endTime: '10:00',
          petName: 'Max',
          customerName: 'Alice',
          serviceName: 'Full Grooming',
          totalPrice: 120.0,
          // tipAmount, taxAmount, isPaid, paymentStatus omitted (null)
        ),
        const GroomerBooking(
          bookingId: 202,
          status: 'completed',
          bookingDate: '2026-10-16',
          startTime: '10:00',
          endTime: '11:00',
          petName: 'Bella',
          customerName: 'Bob',
          serviceName: 'Bath',
          totalPrice: 80.0,
          // tipAmount, taxAmount, isPaid, paymentStatus omitted (null)
        ),
      ];

      final summary = ForecastFinancialSummary.fromBookings(rawAvailabilityBookings);

      // Forecast amount sums active services ($120 + $80 = $200), but is marked as incomplete
      expect(summary.forecastServiceAmount, 200.0);
      expect(summary.isForecastDataComplete, isFalse);

      // Completed Sales, Tips, and Total Collected must NOT be displayed as verified $0.00
      expect(summary.isCompletedSalesAvailable, isFalse);
      expect(summary.completedSales, isNull);
      expect(summary.formattedCompletedSales, 'Unavailable');

      expect(summary.isTipsAvailable, isFalse);
      expect(summary.tipsCollected, isNull);
      expect(summary.formattedTipsCollected, 'Unavailable');

      expect(summary.isTotalCollectedAvailable, isFalse);
      expect(summary.totalCollected, isNull);
      expect(summary.formattedTotalCollected, 'Unavailable');
    });

    test('Does not treat appointment status alone as payment proof without backend payment confirmation', () {
      final unverifiedStatusBookings = [
        const GroomerBooking(
          bookingId: 301,
          status: 'checkout_completed',
          bookingDate: '2026-10-16',
          startTime: '09:00',
          endTime: '10:00',
          petName: 'Rocky',
          customerName: 'Dan',
          serviceName: 'Full Grooming',
          totalPrice: 100.0,
          // isPaid and paymentStatus omitted (null)
        ),
        const GroomerBooking(
          bookingId: 302,
          status: 'completed',
          bookingDate: '2026-10-16',
          startTime: '10:00',
          endTime: '11:00',
          petName: 'Luna',
          customerName: 'Eva',
          serviceName: 'Bath',
          totalPrice: 70.0,
          // isPaid and paymentStatus omitted (null)
        ),
      ];

      final summary = ForecastFinancialSummary.fromBookings(unverifiedStatusBookings);

      // Neither status: 'checkout_completed' nor 'completed' alone is treated as proof of payment
      expect(summary.completedAppointmentsCount, 0);
      expect(summary.isCompletedSalesAvailable, isFalse);
      expect(summary.completedSales, isNull);
      expect(summary.formattedCompletedSales, 'Unavailable');
      expect(summary.forecastAppointmentsCount, 2);
      expect(summary.forecastServiceAmount, 170.0);
    });
  });

  group('ForecastPage Financial UI Integration (Step 3)', () {
    final List<SalonGroomer> sampleGroomers = [
      const SalonGroomer(
        id: 1,
        groomerCode: 'G001',
        firstName: 'Merisa',
        lastName: 'Brown',
        name: 'Merisa Brown',
      ),
      const SalonGroomer(
        id: 2,
        groomerCode: 'G002',
        firstName: 'Richard',
        lastName: 'Cooke',
        name: 'Richard Cooke',
      ),
      const SalonGroomer(
        id: 3,
        groomerCode: 'G003',
        firstName: 'Emma',
        lastName: 'Watson',
        name: 'Emma Watson',
      ),
    ];

    final List<GroomerBooking> sampleBookings = [
      const GroomerBooking(
        bookingId: 101,
        status: 'confirmed',
        bookingDate: '2026-10-16',
        startTime: '09:00',
        endTime: '10:00',
        petName: 'Max',
        customerName: 'Alice Smith',
        customerMobile: '+1 (555) 019-2831',
        serviceName: 'Full Grooming',
        totalPrice: 150.0,
        tipAmount: 0.0,
        taxAmount: 0.0,
        isPaid: false,
        groomerId: 1,
        groomerName: 'Merisa Brown',
      ),
      const GroomerBooking(
        bookingId: 102,
        status: 'checkout_completed',
        bookingDate: '2026-10-16',
        startTime: '10:30',
        endTime: '11:30',
        petName: 'Bella',
        customerName: 'Bob Jones',
        customerMobile: '555-019-4422',
        serviceName: 'Bath & Brush',
        totalPrice: 100.0,
        tipAmount: 20.0,
        taxAmount: 8.0,
        isPaid: true,
        groomerId: 2,
        groomerName: 'Richard Cooke',
      ),
      const GroomerBooking(
        bookingId: 103,
        status: 'confirmed',
        bookingDate: '2026-10-16',
        startTime: '12:00',
        endTime: '13:00',
        petName: 'Charlie',
        customerName: 'Clara Oswald',
        customerMobile: '5550199988',
        serviceName: 'Nail Trim',
        totalPrice: 50.0,
        tipAmount: 0.0,
        taxAmount: 0.0,
        isPaid: false,
        groomerId: 3,
        groomerName: 'Emma Watson',
      ),
    ];

    Widget buildTestWidget({
      List<GroomerBooking>? bookings,
      List<SalonGroomer>? groomers,
      Set<String>? initialGroomerFilterIds,
    }) {
      return MaterialApp(
        home: ForecastPage(
          initialBookings: bookings ?? sampleBookings,
          initialSalonGroomers: groomers ?? sampleGroomers,
          initialGroomerFilterIds: initialGroomerFilterIds,
          initialDate: DateTime(2026, 10, 16),
        ),
      );
    }

    testWidgets('Renders real API-driven financial metrics on all 4 summary cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Overall:
      // Forecast Service Amount = 150 (Max) + 50 (Charlie) = $200.00
      expect(find.text('\$200.00'), findsWidgets);
      expect(find.text('2 unpaid appts'), findsOneWidget);

      // Completed Sales = 100 (Bella) = $100.00
      expect(find.text('\$100.00'), findsWidgets);
      expect(find.text('1 paid checkout'), findsOneWidget);

      // Tips Collected = 20 = $20.00
      expect(find.text('\$20.00'), findsOneWidget);

      // Total Collected = 100 + 8 (tax) + 20 (tip) = $128.00
      expect(find.text('\$128.00'), findsOneWidget);
    });

    testWidgets('Displays per-groomer financial breakdown with real Appts, Forecast, and Sales', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check breakdown header
      expect(find.text('Groomer Financial Breakdown'), findsOneWidget);

      // Merisa Brown: Appt 1, Forecast $150.00, Sales $0.00
      expect(find.text('Merisa Brown'), findsWidgets);
      expect(find.text('\$150.00'), findsWidgets);

      // Richard Cooke: Appt 1, Forecast $0.00, Sales $100.00
      expect(find.text('Richard Cooke'), findsWidgets);
      expect(find.text('\$0.00'), findsWidgets);
    });

    testWidgets('Financial cards update dynamically when filtering by individual groomer', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1600));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Select 'Richard' filter chip
      final richardChip = find.text('Richard');
      expect(richardChip, findsOneWidget);
      await tester.tap(richardChip);
      await tester.pumpAndSettle();

      // For Richard: 0 unpaid forecast appts ($0.00), 1 completed sale ($100.00), tips ($20.00), total ($128.00)
      expect(find.text('0 unpaid appts'), findsOneWidget);
      expect(find.text('1 paid checkout'), findsOneWidget);
      expect(find.text('\$100.00'), findsWidgets);
      expect(find.text('\$20.00'), findsOneWidget);
      expect(find.text('\$128.00'), findsOneWidget);
    });

    testWidgets('Financial cards update dynamically when search query is entered', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1600));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      // Search for "Charlie" (Emma's appointment: $50.00 unpaid)
      await tester.enterText(searchField, 'Charlie');
      await tester.pumpAndSettle();

      // Summary should reflect only Charlie: Forecast = $50.00, Sales = $0.00, Tips = $0.00, Total = $0.00
      expect(find.text('\$50.00'), findsWidgets);
      expect(find.text('1 unpaid appt'), findsOneWidget);
      expect(find.text('0 paid checkouts'), findsOneWidget);
      expect(find.text('\$0.00'), findsWidgets);
    });

    testWidgets('Displays Unavailable and informative warning subcaptions when availability data omits payment/tips', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      // Bookings representing actual backend availability response (no payment/tip fields)
      final rawBookings = [
        const GroomerBooking(
          bookingId: 401,
          status: 'confirmed',
          bookingDate: '2026-10-16',
          startTime: '09:00',
          endTime: '10:00',
          petName: 'Max',
          customerName: 'Alice',
          serviceName: 'Full Grooming',
          totalPrice: 150.0,
          groomerId: 1,
          groomerName: 'Merisa Brown',
        ),
        const GroomerBooking(
          bookingId: 402,
          status: 'completed',
          bookingDate: '2026-10-16',
          startTime: '10:30',
          endTime: '11:30',
          petName: 'Bella',
          customerName: 'Bob',
          serviceName: 'Bath',
          totalPrice: 100.0,
          groomerId: 2,
          groomerName: 'Richard Cooke',
        ),
      ];

      await tester.pumpWidget(buildTestWidget(bookings: rawBookings));
      await tester.pumpAndSettle();

      // Forecast amount is shown ($250.00), with warning subcaption
      expect(find.text('\$250.00'), findsWidgets);
      expect(find.text('Payment status omitted by API'), findsOneWidget);

      // Completed Sales, Tips, and Total Collected in summary cards + 2 groomer breakdown cards display 'Unavailable'
      expect(find.text('Unavailable'), findsNWidgets(5));
      expect(find.text('Payment data unavailable'), findsOneWidget);
      expect(find.text('Omitted by availability API'), findsOneWidget);
      expect(find.text('Awaiting checkout endpoint'), findsOneWidget);

      // Groomer breakdown banner and cards
      expect(find.text('Availability API omits checkout payment status & tips.'), findsOneWidget);
      expect(find.text('\$150.00*'), findsOneWidget);
      expect(find.text('\$100.00*'), findsOneWidget);
    });
  });
}
