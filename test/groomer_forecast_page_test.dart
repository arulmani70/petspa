import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/forecast/forecast_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      groomerId: 1,
      groomerName: 'Merisa Brown',
    ),
    const GroomerBooking(
      bookingId: 102,
      status: 'completed',
      bookingDate: '2026-10-16',
      startTime: '10:30',
      endTime: '11:30',
      petName: 'Bella',
      customerName: 'Bob Jones',
      customerMobile: '555-019-4422',
      serviceName: 'Bath & Brush',
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
      groomerId: 3,
      groomerName: 'Emma Watson',
    ),
  ];

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  Widget buildTestWidget({
    List<GroomerBooking>? bookings,
    List<SalonGroomer>? groomers,
    Set<String>? initialGroomerFilterIds,
    String? initialGroomerFilterId,
    bool initialIsPaginationTruncated = false,
  }) {
    return MaterialApp(
      home: ForecastPage(
        initialBookings: bookings ?? sampleBookings,
        initialSalonGroomers: groomers ?? sampleGroomers,
        initialGroomerFilterIds: initialGroomerFilterIds,
        initialGroomerFilterId: initialGroomerFilterId,
        initialDate: DateTime(2026, 10, 16),
        initialIsPaginationTruncated: initialIsPaginationTruncated,
      ),
    );
  }

  group('ForecastPage UI Clone & Neutral Placeholder Tests (Step 1)', () {
    testWidgets('Renders Forecast header, title, and all 4 neutral financial cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check Header & Screen Title
      expect(find.text('Forecast'), findsOneWidget);
      expect(find.text('Appointment revenue projections & financial breakdown'), findsOneWidget);

      // Verify all 4 financial cards exist with real API-driven currency values
      expect(find.text('Forecast Service Amount'), findsOneWidget);
      expect(find.text('Completed Sales'), findsOneWidget);
      expect(find.text('Tips Collected'), findsOneWidget);
      expect(find.text('Total Collected'), findsOneWidget);

      // Verify real calculated currency formatting across cards and breakdown
      expect(find.text(r'$0.00'), findsWidgets);
    });

    testWidgets('Renders per-groomer financial breakdown section', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check breakdown section title
      expect(find.text('Groomer Financial Breakdown'), findsOneWidget);

      // Verify visible groomer names appear in the breakdown area
      expect(find.text('Merisa Brown'), findsWidgets);
      expect(find.text('Richard Cooke'), findsWidgets);
    });

    testWidgets('Supports multi-groomer selection filters', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1600));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap single groomer 'Merisa' filter chip
      final merisaFilterChip = find.text('Merisa');
      expect(merisaFilterChip, findsOneWidget);
      await tester.tap(merisaFilterChip);
      await tester.pumpAndSettle();

      // Only Merisa's booking (Alice Smith / Max) should be shown
      expect(find.textContaining('Alice Smith'), findsOneWidget);
      expect(find.textContaining('Bob Jones'), findsNothing);
      expect(find.textContaining('Clara Oswald'), findsNothing);

      // Now tap 'Richard' to multi-select both Merisa and Richard
      final richardFilterChip = find.text('Richard');
      expect(richardFilterChip, findsOneWidget);
      await tester.tap(richardFilterChip);
      await tester.pumpAndSettle();

      // Both Alice and Bob should be shown, Clara should still be hidden
      expect(find.textContaining('Alice Smith'), findsOneWidget);
      expect(find.textContaining('Bob Jones'), findsOneWidget);
      expect(find.textContaining('Clara Oswald'), findsNothing);

      // Tap 'All Groomers' chip to reset multi-selection back to All
      final allGroomersChip = find.text('All Groomers');
      expect(allGroomersChip, findsOneWidget);
      await tester.tap(allGroomersChip);
      await tester.pumpAndSettle();

      // All 3 bookings should be displayed again
      expect(find.textContaining('Alice Smith'), findsOneWidget);
      expect(find.textContaining('Bob Jones'), findsOneWidget);
      expect(find.textContaining('Clara Oswald'), findsOneWidget);
    });

    testWidgets('Search filters bookings by pet name, customer name, and phone', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1600));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      // Search by Pet Name "Max"
      await tester.enterText(searchField, 'Max');
      await tester.pumpAndSettle();
      expect(find.textContaining('Alice Smith'), findsOneWidget);
      expect(find.textContaining('Bob Jones'), findsNothing);

      // Search by Customer Phone (normalized with digits)
      await tester.enterText(searchField, '5550194422');
      await tester.pumpAndSettle();
      expect(find.textContaining('Bob Jones'), findsOneWidget);
      expect(find.textContaining('Alice Smith'), findsNothing);

      // Clear search
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();
      expect(find.textContaining('Alice Smith'), findsOneWidget);
      expect(find.textContaining('Bob Jones'), findsOneWidget);
      expect(find.textContaining('Clara Oswald'), findsOneWidget);
    });

    testWidgets('Displays timeline selector with single date and date range options', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open date options modal
      final dateModalTrigger = find.byIcon(Icons.arrow_drop_down_rounded);
      expect(dateModalTrigger, findsOneWidget);
      await tester.tap(dateModalTrigger);
      await tester.pumpAndSettle();

      expect(find.text('Single Date Picker'), findsOneWidget);
      expect(find.text('Date Range Picker'), findsOneWidget);
    });
  });

  group('ForecastPage Step 4 Listing, Filters, Pagination & Service Notes Tests', () {
    final List<GroomerBooking> step4Bookings = [
      const GroomerBooking(
        bookingId: 201,
        status: 'confirmed',
        bookingDate: '2026-10-16',
        startTime: '09:00',
        endTime: '10:00',
        petName: 'Max',
        customerName: 'Alice Smith',
        customerMobile: '+1 (555) 019-2831',
        serviceName: 'Full Grooming',
        totalPrice: 85.0,
        isPaid: false,
        paymentStatus: 'unpaid',
        groomerId: 1,
        groomerName: 'Merisa Brown',
        specialInstructions: 'Please be extra gentle with ears',
      ),
      const GroomerBooking(
        bookingId: 202,
        status: 'completed',
        bookingDate: '2026-10-16',
        startTime: '10:30',
        endTime: '11:30',
        petName: 'Bella',
        customerName: 'Bob Jones',
        customerMobile: '555-019-4422',
        serviceName: 'Bath & Brush',
        totalPrice: 50.0,
        isPaid: true,
        paymentStatus: 'paid',
        groomerId: 2,
        groomerName: 'Richard Cooke',
        specialInstructions: 'Sensitive shampoo requested',
      ),
      const GroomerBooking(
        bookingId: 203,
        status: 'in_progress',
        bookingDate: '2026-10-16',
        startTime: '12:00',
        endTime: '13:00',
        petName: 'Charlie',
        customerName: 'Clara Oswald',
        customerMobile: '5550199988',
        serviceName: 'Nail Trim',
        totalPrice: 25.0,
        groomerId: 3,
        groomerName: 'Emma Watson',
      ),
    ];

    testWidgets('Secondary status filter narrows displayed appointments and shows correct count badges', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));

      await tester.pumpWidget(buildTestWidget(bookings: step4Bookings));
      await tester.pumpAndSettle();

      // Tap 'Confirmed' status filter chip in the status bar
      final confirmedChip = find.text('Confirmed');
      expect(confirmedChip, findsWidgets);
      await tester.tap(confirmedChip.first);
      await tester.pumpAndSettle();

      // Alice Smith (Confirmed) should be visible, Bob Jones (Completed) and Clara (In Progress) should be hidden
      expect(find.textContaining('Alice Smith'), findsOneWidget);
      expect(find.textContaining('Bob Jones'), findsNothing);
      expect(find.textContaining('Clara Oswald'), findsNothing);

      // Tap 'Completed' status chip
      final completedChip = find.text('Completed');
      expect(completedChip, findsWidgets);
      await tester.tap(completedChip.first);
      await tester.pumpAndSettle();

      // Only Bob Jones should be visible
      expect(find.textContaining('Bob Jones'), findsOneWidget);
      expect(find.textContaining('Alice Smith'), findsNothing);
      expect(find.textContaining('Clara Oswald'), findsNothing);

      // Tap 'Pending' status chip which has 0 bookings
      final pendingChip = find.text('Pending');
      expect(pendingChip, findsOneWidget);
      await tester.tap(pendingChip);
      await tester.pumpAndSettle();

      // Should display dedicated status empty state
      expect(find.text('No Pending Appointments'), findsOneWidget);
      expect(find.text('Show All Statuses (3)'), findsOneWidget);

      // Tap "Show All Statuses" button
      await tester.tap(find.text('Show All Statuses (3)'));
      await tester.pumpAndSettle();

      // All 3 bookings should be restored
      expect(find.textContaining('Alice Smith'), findsOneWidget);
      expect(find.textContaining('Bob Jones'), findsOneWidget);
      expect(find.textContaining('Clara Oswald'), findsOneWidget);
    });

    testWidgets('Renders Service Request Notes and allows searching by notes and service name', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1600));

      await tester.pumpWidget(buildTestWidget(bookings: step4Bookings));
      await tester.pumpAndSettle();

      // Check that customer notes from Step 2 are rendered on the card
      expect(find.text('Customer Instructions:'), findsNWidgets(2));
      expect(find.text('Please be extra gentle with ears'), findsOneWidget);
      expect(find.text('Sensitive shampoo requested'), findsOneWidget);

      final searchField = find.byType(TextField);

      // Search by note content "extra gentle"
      await tester.enterText(searchField, 'extra gentle');
      await tester.pumpAndSettle();
      expect(find.textContaining('Alice Smith'), findsOneWidget);
      expect(find.textContaining('Bob Jones'), findsNothing);

      // Search by service name "Bath & Brush"
      await tester.enterText(searchField, 'Bath & Brush');
      await tester.pumpAndSettle();
      expect(find.textContaining('Bob Jones'), findsOneWidget);
      expect(find.textContaining('Alice Smith'), findsNothing);

      // Clear search
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();
      expect(find.textContaining('Alice Smith'), findsOneWidget);
      expect(find.textContaining('Bob Jones'), findsOneWidget);
    });

    testWidgets('Renders service fee and verified payment badge correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1600));

      await tester.pumpWidget(buildTestWidget(bookings: step4Bookings));
      await tester.pumpAndSettle();

      // Prices rendered
      expect(find.text(r'$85.00'), findsWidgets);
      expect(find.text(r'$50.00'), findsWidgets);
      expect(find.text(r'$25.00'), findsWidgets);

      // Payment badges:
      // Alice Smith has isPaid: false -> Unpaid badge
      expect(find.text('Unpaid'), findsWidgets);

      // Bob Jones has isPaid: true -> Paid badge
      expect(find.text('Paid'), findsOneWidget);
    });

    testWidgets('Supports incremental pagination with Show More and Show All buttons when exceeding 25 records', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1600));

      // Generate 30 dummy bookings
      final lotsOfBookings = List.generate(
        30,
        (i) => GroomerBooking(
          bookingId: 300 + i,
          status: 'confirmed',
          bookingDate: '2026-10-16',
          startTime: '09:00',
          endTime: '10:00',
          petName: 'Pet #$i',
          customerName: 'Customer #$i',
          serviceName: 'Grooming',
          totalPrice: 40.0,
          groomerId: 1,
          groomerName: 'Merisa Brown',
        ),
      );

      await tester.pumpWidget(buildTestWidget(bookings: lotsOfBookings));
      await tester.pumpAndSettle();

      // Initial visible items should be capped at 25 (item #25 should not exist in tree)
      expect(find.textContaining('Customer #0'), findsOneWidget);
      expect(find.textContaining('Customer #25'), findsNothing);

      // Scroll to Show More button
      final mainScrollable = find.byType(Scrollable).first;
      final showMoreFinder = find.text('Show More (5 remaining)');
      await tester.scrollUntilVisible(showMoreFinder, 300, scrollable: mainScrollable);
      expect(showMoreFinder, findsOneWidget);
      expect(find.text('Show All (30)'), findsOneWidget);

      // Tap 'Show More'
      await tester.tap(showMoreFinder);
      await tester.pumpAndSettle();

      // Now all 30 should be available, scroll down to the last item
      final lastCustomerFinder = find.textContaining('Customer #29');
      await tester.scrollUntilVisible(lastCustomerFinder, 300, scrollable: mainScrollable);
      expect(lastCustomerFinder, findsOneWidget);
      expect(find.text('Show More (5 remaining)'), findsNothing);
    });

    testWidgets('Displays warning notice banner only when truncation actually occurs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      // 1. Normal state: truncation has NOT occurred -> banner is absent
      await tester.pumpWidget(buildTestWidget(
        bookings: step4Bookings,
        initialIsPaginationTruncated: false,
      ));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Large dataset safety ceiling reached (5,000 appointments per groomer/date)'),
        findsNothing,
      );

      // 2. Truncated state: truncation HAS occurred -> banner is displayed
      await tester.pumpWidget(buildTestWidget(
        bookings: step4Bookings,
        initialIsPaginationTruncated: true,
      ));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Large dataset safety ceiling reached (5,000 appointments per groomer/date)'),
        findsOneWidget,
      );
    });

    testWidgets('Changing status filters affects only the visible appointment list and does not alter financial summary or breakdown', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));

      await tester.pumpWidget(buildTestWidget(bookings: step4Bookings));
      await tester.pumpAndSettle();

      // Top financial summary shows $85.00 forecast and $50.00 completed sales
      expect(find.text(r'$85.00'), findsWidgets);
      expect(find.text(r'$50.00'), findsWidgets);

      // Breakdown section shows Merisa Brown and Richard Cooke
      expect(find.text('Groomer Financial Breakdown'), findsOneWidget);

      // Now filter visible list to 'Completed' only
      final completedChip = find.text('Completed');
      await tester.tap(completedChip.first);
      await tester.pumpAndSettle();

      // Visible appointment list contains only Bob Jones (Bella)
      expect(find.textContaining('Bob Jones'), findsOneWidget);
      expect(find.textContaining('Alice Smith'), findsNothing);
      expect(find.textContaining('Clara Oswald'), findsNothing);

      // Financial summary cards still reflect all matching appointments for the date ($85.00 and $50.00)
      expect(find.text(r'$85.00'), findsWidgets);
      expect(find.text(r'$50.00'), findsWidgets);

      // Now filter visible list to 'Pending' (0 appointments)
      final pendingChip = find.text('Pending');
      await tester.tap(pendingChip);
      await tester.pumpAndSettle();

      // Visible list displays status empty state
      expect(find.text('No Pending Appointments'), findsOneWidget);

      // Financial summary cards STILL preserve authoritative date totals ($85.00 and $50.00)
      expect(find.text(r'$85.00'), findsWidgets);
      expect(find.text(r'$50.00'), findsWidgets);
    });

    testWidgets('Deduplication is applied before calculating appointment counts and financial aggregates', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));

      // Create a list with an intentional duplicate booking (#201 repeated twice)
      final bookingsWithDuplicate = [
        ...step4Bookings,
        step4Bookings.first, // Duplicate of bookingId 201 ($85.00)
      ];

      expect(bookingsWithDuplicate.length, equals(4));

      await tester.pumpWidget(buildTestWidget(bookings: bookingsWithDuplicate));
      await tester.pumpAndSettle();

      // Header shows 3 appointments, NOT 4 (deduplication applied)
      expect(find.text('Forecast Appointments (3)'), findsOneWidget);

      // Forecast Service Amount is $85.00, NOT $170.00 (no double counting)
      expect(find.text(r'$85.00'), findsWidgets);
      expect(find.text(r'$170.00'), findsNothing);
    });
  });
}
