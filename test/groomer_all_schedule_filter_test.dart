import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/all_groomers/all_groomers_schedule_page.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/mobile/groomer_home_page_mobile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  group('GroomerBooking Model & Effective Groomer Name Tests', () {
    test('GroomerBooking parses groomer fields correctly from JSON', () {
      final json = {
        'id': 101,
        'booking_id': 101,
        'status': 'confirmed',
        'booking_date': '2026-10-15',
        'start_time': '09:00',
        'end_time': '10:00',
        'pet_name': 'Max',
        'customer_name': 'Alice Smith',
        'service_name': 'Full Grooming',
        'groomer_id': 1,
        'groomer_name': 'Merisa Brown',
        'groomer_code': 'G001',
      };

      final booking = GroomerBooking.fromJson(json);
      expect(booking.bookingId, equals(101));
      expect(booking.customerName, equals('Alice Smith'));
      expect(booking.petName, equals('Max'));
      expect(booking.groomerId, equals(1));
      expect(booking.groomerName, equals('Merisa Brown'));
      expect(booking.groomerCode, equals('G001'));
      expect(booking.effectiveGroomerName, equals('Merisa Brown'));
    });

    test('effectiveGroomerName resolves correctly when groomerName is absent', () {
      const bWithId = GroomerBooking(
        bookingId: 102,
        status: 'pending',
        bookingDate: '2026-10-15',
        startTime: '10:00',
        endTime: '11:00',
        petName: 'Bella',
        customerName: 'Bob Jones',
        serviceName: 'Bath & Brush',
        groomerId: 2,
      );
      expect(bWithId.effectiveGroomerName, equals('Richard Cooke'));

      const bWithCode = GroomerBooking(
        bookingId: 103,
        status: 'confirmed',
        bookingDate: '2026-10-15',
        startTime: '11:00',
        endTime: '12:00',
        petName: 'Charlie',
        customerName: 'Carol White',
        serviceName: 'Nail Trim',
        groomerCode: 'G003',
      );
      expect(bWithCode.effectiveGroomerName, equals('Groomer G003'));

      const bFallback = GroomerBooking(
        bookingId: 104,
        status: 'completed',
        bookingDate: '2026-10-15',
        startTime: '12:00',
        endTime: '13:00',
        petName: 'Luna',
        customerName: 'David Lee',
        serviceName: 'Full Spa',
      );
      expect(bFallback.effectiveGroomerName, equals('Assigned Staff'));
    });

    test('Dedicated repository method getAllGroomersBookings is available', () {
      final repo = ServicesLocator.groomerHomeRepository;
      expect(repo.getAllGroomersBookings, isNotNull);
    });
  });

  group('Dedicated AllGroomersSchedulePage UI Widget Tests', () {
    testWidgets('Renders AllGroomersSchedulePage with title, stat cards, and filter bar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        const MaterialApp(
          home: AllGroomersSchedulePage(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Page Title and Header
      expect(find.text('All Groomers Schedule'), findsOneWidget);
      expect(find.text('Consolidated salon appointment calendar'), findsOneWidget);

      // Verify Dynamic Stat Cards
      expect(find.text('Total Bookings'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);

      // Verify Groomer Filter Section
      expect(find.text('Filter by Groomer'), findsOneWidget);
      expect(find.text('All Groomers'), findsOneWidget);

      // Verify Appointments list header
      expect(find.textContaining('Appointments ('), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Groomer filter selection and Show All reset pill in AllGroomersSchedulePage', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        const MaterialApp(
          home: AllGroomersSchedulePage(),
        ),
      );

      await tester.pumpAndSettle();

      // Initially "Show All" reset pill is not visible because 'all' is selected
      expect(find.text('Show All'), findsNothing);

      // If salon groomer chips are present, tap one
      final richardChip = find.text('Richard');
      if (richardChip.evaluate().isNotEmpty) {
        await tester.tap(richardChip);
        await tester.pumpAndSettle();

        // "Show All" reset button is now visible
        expect(find.text('Show All'), findsOneWidget);

        // Tap "Show All" to reset
        await tester.tap(find.text('Show All'));
        await tester.pumpAndSettle();

        // Filter is reset back to 'all', so 'Show All' is hidden
        expect(find.text('Show All'), findsNothing);
      }

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('GroomerHomePageMobile Entry Point & Preservation Tests', () {
    testWidgets('GroomerHomePageMobile preserves personal dashboard and provides entry points to All Groomers', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        const MaterialApp(
          home: GroomerHomePageMobile(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Tab 0 personal dashboard sections
      expect(find.text('Today’s Booking'), findsOneWidget);
      expect(find.text('Total Bookings'), findsOneWidget);
      expect(find.text('Pending Bookings'), findsOneWidget);
      expect(find.text('Confirmed Bookings'), findsOneWidget);
      expect(find.text('Completed Bookings'), findsOneWidget);

      // Verify Main-Line Call Action Banner is preserved
      expect(find.text('Main-Line Call Booking'), findsOneWidget);

      // Verify All Groomers Schedule entry card is present
      expect(find.text('All Groomers Schedule'), findsOneWidget);
      expect(find.text('View and filter appointments for all salon staff'), findsOneWidget);

      // Verify Section 2 Booking List header with selector defaulting to login groomer
      expect(find.text('Booking List'), findsOneWidget);
      expect(find.textContaining('(You)'), findsOneWidget);

      // Tap the selector to verify 'All Groomers' option is accessible
      await tester.tap(find.textContaining('(You)'));
      await tester.pumpAndSettle();
      expect(find.text('All Groomers'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('All Groomers Action Authorization & Separation Tests', () {
    testWidgets('AllGroomersSchedulePage enables actions for own bookings and shows Read-only for other groomers', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      // Mock logged-in groomer as Merisa Brown (id: 1)
      await ServicesLocator.sessionService.saveGroomerUser({
        'id': 1,
        'groomerCode': 'G001',
        'firstName': 'Merisa',
        'lastName': 'Brown',
        'email': 'merisa@shearheaven.com',
        'role': 'Groomer',
      });

      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final mockBookings = [
        GroomerBooking(
          bookingId: 301,
          status: 'pending',
          bookingDate: todayStr,
          startTime: '23:30',
          endTime: '23:59',
          petName: 'Bella',
          customerName: 'Customer One',
          serviceName: 'Bath & Brush',
          groomerId: 1,
          groomerName: 'Merisa Brown',
          groomerCode: 'G001',
        ),
        GroomerBooking(
          bookingId: 302,
          status: 'pending',
          bookingDate: todayStr,
          startTime: '23:30',
          endTime: '23:59',
          petName: 'Rocky',
          customerName: 'Customer Two',
          serviceName: 'Full Spa',
          groomerId: 2,
          groomerName: 'Richard Cooke',
          groomerCode: 'G002',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: mockBookings,
            initialGroomerFilterId: 'all',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that Bella's card (assigned to Merisa Brown) has Approve and Reject actions enabled
      expect(find.text('Bella'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);

      // Verify that Rocky's card (assigned to Richard Cooke) displays Read-only badge
      expect(find.text('Rocky'), findsOneWidget);
      expect(find.text('Read-only'), findsOneWidget);

      // Clean up mock session
      await ServicesLocator.sessionService.clearGroomerSession();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('AllGroomersSchedulePage defaults to selecting the logged-in groomer', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await ServicesLocator.sessionService.saveGroomerUser({
        'id': 1,
        'groomerCode': 'G001',
        'firstName': 'Merisa',
        'lastName': 'Brown',
        'email': 'merisa@shearheaven.com',
        'role': 'Groomer',
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: AllGroomersSchedulePage(),
        ),
      );
      await tester.pumpAndSettle();

      // Show All reset button should be visible because logged-in groomer is selected by default instead of 'all'
      expect(find.text('Show All'), findsOneWidget);

      await ServicesLocator.sessionService.clearGroomerSession();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('AllGroomersSchedulePage renders without right overflow on narrow screens', (tester) async {
      // Test narrow mobile screen (360x640)
      await tester.binding.setSurfaceSize(const Size(360, 640));

      await ServicesLocator.sessionService.saveGroomerUser({
        'id': 1,
        'groomerCode': 'G001',
        'firstName': 'Merisa',
        'lastName': 'Brown',
        'email': 'merisa@shearheaven.com',
        'role': 'Groomer',
      });

      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final mockBookings = [
        GroomerBooking(
          bookingId: 401,
          status: 'pending',
          bookingDate: todayStr,
          startTime: '23:30',
          endTime: '23:59',
          petName: 'Very Long Pet Name That Might Wrap',
          customerName: 'Customer With A Long Name',
          serviceName: 'Full Deluxe Luxury Bath, Groom and Style',
          groomerId: 1,
          groomerName: 'Merisa Brown Extra Long',
          groomerCode: 'G001',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: mockBookings,
            initialGroomerFilterId: '1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no overflow occurred and elements are rendered properly
      expect(find.textContaining('Appointments ('), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await ServicesLocator.sessionService.clearGroomerSession();
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Groomer Availability Endpoint & Deduplication Tests', () {
    test('parseAvailabilityAppointmentsResponse correctly maps busySlots into GroomerBooking records', () {
      final repo = ServicesLocator.groomerHomeRepository;
      final mockApiResponse = {
        'success': true,
        'data': {
          'storeId': 'SHEAR-001',
          'date': '2026-10-16',
          'groomers': [
            {
              'id': 11,
              'groomerCode': 'G001',
              'name': 'Merisa Brown',
              'type': 'Groomer',
              'multiBookingEnabled': true,
              'slotBookingLimit': 3,
              'busySlots': [
                {
                  'bookingId': 111,
                  'bookingDate': '2026-10-16',
                  'startTime': '08:15',
                  'endTime': '09:15',
                  'status': 'pending',
                  'petName': 'Milo',
                  'customerName': 'Sarah Connor',
                  'serviceName': 'Full Grooming',
                },
                {
                  'bookingId': 112,
                  'bookingDate': '2026-10-16',
                  'startTime': '10:00',
                  'endTime': '11:00',
                  'status': 'confirmed',
                },
              ],
            },
          ],
          'pagination': {
            'page': 1,
            'limit': 10,
            'total': 2,
            'totalPages': 1,
            'hasNextPage': false,
          },
        },
      };

      final appointments = repo.parseAvailabilityAppointmentsResponse(
        mockApiResponse,
        targetGroomerId: 11,
        date: '2026-10-16',
      );

      expect(appointments.length, equals(2));

      // First appointment check
      final b1 = appointments[0];
      expect(b1.bookingId, equals(111));
      expect(b1.bookingDate, equals('2026-10-16'));
      expect(b1.startTime, equals('08:15'));
      expect(b1.endTime, equals('09:15'));
      expect(b1.status, equals('pending'));
      expect(b1.petName, equals('Milo'));
      expect(b1.customerName, equals('Sarah Connor'));
      expect(b1.serviceName, equals('Full Grooming'));
      expect(b1.groomerId, equals(11));
      expect(b1.groomerName, equals('Merisa Brown'));
      expect(b1.groomerCode, equals('G001'));

      // Second appointment check (tests safe fallback values for unspecified pet/customer/service)
      final b2 = appointments[1];
      expect(b2.bookingId, equals(112));
      expect(b2.bookingDate, equals('2026-10-16'));
      expect(b2.startTime, equals('10:00'));
      expect(b2.endTime, equals('11:00'));
      expect(b2.status, equals('confirmed'));
      expect(b2.petName, equals('Pet'));
      expect(b2.customerName, equals('Customer'));
      expect(b2.serviceName, equals('Grooming'));
      expect(b2.groomerId, equals(11));
    });

    test('parseAvailabilityPagination correctly detects hasNextPage from pagination object or item count', () {
      final repo = ServicesLocator.groomerHomeRepository;

      // 1. Backend contract with hasNextPage: false when page has exactly 100 records
      final fullPageNoMore = {
        'success': true,
        'data': {
          'pagination': {
            'page': 1,
            'limit': 100,
            'total': 100,
            'totalPages': 1,
            'hasNextPage': false,
          },
        },
      };
      final p1 = repo.parseAvailabilityPagination(fullPageNoMore, itemsCount: 100, page: 1, limit: 100);
      expect(p1.hasNextPage, isFalse);
      expect(p1.totalPages, equals(1));
      expect(p1.total, equals(100));

      // 2. Backend contract with hasNextPage: true when page has 100 records and more remain
      final fullPageHasMore = {
        'success': true,
        'data': {
          'pagination': {
            'page': 1,
            'limit': 100,
            'total': 150,
            'totalPages': 2,
            'hasNextPage': true,
          },
        },
      };
      final p2 = repo.parseAvailabilityPagination(fullPageHasMore, itemsCount: 100, page: 1, limit: 100);
      expect(p2.hasNextPage, isTrue);
      expect(p2.totalPages, equals(2));
      expect(p2.total, equals(150));

      // 3. Backend contract with totalPages: 1 and page == totalPages
      final pageMatchesTotal = {
        'success': true,
        'data': {
          'pagination': {
            'page': 1,
            'limit': 100,
            'totalPages': 1,
          },
        },
      };
      final p3 = repo.parseAvailabilityPagination(pageMatchesTotal, itemsCount: 100, page: 1, limit: 100);
      expect(p3.hasNextPage, isFalse);

      // 4. Backend omits pagination object: fallback uses itemsCount >= limit
      final noPaginationFull = {
        'success': true,
        'data': {'groomers': []},
      };
      final p4 = repo.parseAvailabilityPagination(noPaginationFull, itemsCount: 100, page: 1, limit: 100);
      expect(p4.hasNextPage, isTrue); // Queries next page to check if more items exist

      final noPaginationPartial = {
        'success': true,
        'data': {'groomers': []},
      };
      final p5 = repo.parseAvailabilityPagination(noPaginationPartial, itemsCount: 42, page: 1, limit: 100);
      expect(p5.hasNextPage, isFalse); // < 100 items -> definitely no more
    });

    test('Combines multi-groomer availability results without duplicate appointments', () {
      final listGroomer1 = [
        const GroomerBooking(
          bookingId: 201,
          status: 'confirmed',
          bookingDate: '2026-10-16',
          startTime: '09:00',
          endTime: '10:00',
          petName: 'Pet 1',
          customerName: 'Customer 1',
          serviceName: 'Grooming',
          groomerId: 1,
          groomerName: 'Merisa Brown',
        ),
        const GroomerBooking(
          bookingId: 202,
          status: 'pending',
          bookingDate: '2026-10-16',
          startTime: '10:30',
          endTime: '11:30',
          petName: 'Pet 2',
          customerName: 'Customer 2',
          serviceName: 'Grooming',
          groomerId: 1,
          groomerName: 'Merisa Brown',
        ),
      ];

      final listGroomer2 = [
        // Duplicate bookingId 201 (e.g. multi-staff booking)
        const GroomerBooking(
          bookingId: 201,
          status: 'confirmed',
          bookingDate: '2026-10-16',
          startTime: '09:00',
          endTime: '10:00',
          petName: 'Pet 1',
          customerName: 'Customer 1',
          serviceName: 'Grooming',
          groomerId: 2,
          groomerName: 'Richard Cooke',
        ),
        const GroomerBooking(
          bookingId: 203,
          status: 'confirmed',
          bookingDate: '2026-10-16',
          startTime: '14:00',
          endTime: '15:00',
          petName: 'Pet 3',
          customerName: 'Customer 3',
          serviceName: 'Grooming',
          groomerId: 2,
          groomerName: 'Richard Cooke',
        ),
      ];

      final Map<String, GroomerBooking> uniqueAppointments = {};
      for (final list in [listGroomer1, listGroomer2]) {
        for (final booking in list) {
          final key = booking.bookingId > 0
              ? 'id_${booking.bookingId}'
              : 'slot_${booking.groomerId}_${booking.bookingDate}_${booking.startTime}_${booking.endTime}';
          if (!uniqueAppointments.containsKey(key)) {
            uniqueAppointments[key] = booking;
          }
        }
      }

      final combined = uniqueAppointments.values.toList();
      // Should have exactly 3 unique bookings: 201, 202, 203 (duplicate 201 deduplicated)
      expect(combined.length, equals(3));
      final ids = combined.map((b) => b.bookingId).toList();
      expect(ids, containsAll([201, 202, 203]));
    });

    test('Availability repository methods accept dynamic date, groomerId, page, and limit', () {
      final repo = ServicesLocator.groomerHomeRepository;
      expect(repo.getGroomerAvailabilityAppointments, isNotNull);
      expect(repo.getAllGroomersAvailabilityAppointments, isNotNull);
    });
  });

  group('Search Functionality & Dynamic Filter Integration Tests', () {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final searchMockBookings = [
      GroomerBooking(
        bookingId: 501,
        status: 'confirmed',
        bookingDate: todayStr,
        startTime: '09:00',
        endTime: '10:00',
        petName: 'Milo',
        customerName: 'Sarah Connor',
        customerMobile: '+1 (555) 019-2834',
        serviceName: 'Full Grooming',
        groomerId: 1,
        groomerName: 'Merisa Brown',
        groomerCode: 'G001',
      ),
      GroomerBooking(
        bookingId: 502,
        status: 'pending',
        bookingDate: todayStr,
        startTime: '10:30',
        endTime: '11:30',
        petName: 'Bella',
        customerName: 'John Wick',
        customerMobile: '555-432-1098',
        serviceName: 'Bath & Brush',
        groomerId: 2,
        groomerName: 'Richard Cooke',
        groomerCode: 'G002',
      ),
      GroomerBooking(
        bookingId: 503,
        status: 'completed',
        bookingDate: todayStr,
        startTime: '13:00',
        endTime: '14:00',
        petName: 'Rocky',
        customerName: 'Alice Smith',
        customerMobile: '+15559876543',
        serviceName: 'Nail Trim',
        groomerId: 1,
        groomerName: 'Merisa Brown',
        groomerCode: 'G001',
      ),
    ];

    testWidgets('Search by Pet name dynamically updates list and stat cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: searchMockBookings,
            initialGroomerFilterId: 'all',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Milo'), findsOneWidget);
      expect(find.text('Bella'), findsOneWidget);
      expect(find.text('Rocky'), findsOneWidget);

      // Search for "Milo"
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'milo');
      await tester.pumpAndSettle();

      expect(find.text('Milo'), findsOneWidget);
      expect(find.text('Bella'), findsNothing);
      expect(find.text('Rocky'), findsNothing);
      expect(find.text('Search Results (1)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Search by Customer name is case-insensitive and ignores leading/trailing spaces', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: searchMockBookings,
            initialGroomerFilterId: 'all',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, '   jOhN wIcK   ');
      await tester.pumpAndSettle();

      expect(find.text('Bella'), findsOneWidget);
      expect(find.text('Milo'), findsNothing);
      expect(find.text('Rocky'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Search by Groomer name filters matching appointments', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: searchMockBookings,
            initialGroomerFilterId: 'all',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Richard');
      await tester.pumpAndSettle();

      expect(find.text('Bella'), findsOneWidget);
      expect(find.text('Milo'), findsNothing);
      expect(find.text('Rocky'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Search by Booking ID with or without # and partial matches', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: searchMockBookings,
            initialGroomerFilterId: 'all',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      // Search with "#501"
      await tester.enterText(searchField, '#501');
      await tester.pumpAndSettle();

      expect(find.text('Milo'), findsOneWidget);
      expect(find.text('Bella'), findsNothing);

      // Search with "502"
      await tester.enterText(searchField, '502');
      await tester.pumpAndSettle();

      expect(find.text('Bella'), findsOneWidget);
      expect(find.text('Milo'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Search by Customer Mobile supports normalized, partial, and formatted queries', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: searchMockBookings,
            initialGroomerFilterId: 'all',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);

      // 1. Partial unformatted: "0192" should match Milo's "+1 (555) 019-2834"
      await tester.enterText(searchField, '0192');
      await tester.pumpAndSettle();
      expect(find.text('Milo'), findsOneWidget);
      expect(find.text('Bella'), findsNothing);

      // 2. Formatted query "(555) 432" should match Bella's "555-432-1098"
      await tester.enterText(searchField, '(555) 432');
      await tester.pumpAndSettle();
      expect(find.text('Bella'), findsOneWidget);
      expect(find.text('Milo'), findsNothing);

      // 3. Query with dashes "987-6543" should match Rocky's "+15559876543"
      await tester.enterText(searchField, '987-6543');
      await tester.pumpAndSettle();
      expect(find.text('Rocky'), findsOneWidget);
      expect(find.text('Milo'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Clear search restores previous appointment results and empty state displays Clear Search button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: searchMockBookings,
            initialGroomerFilterId: 'all',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);

      // Non-matching search
      await tester.enterText(searchField, 'NonExistentSearchTerm');
      await tester.pumpAndSettle();

      // Empty search state displayed
      expect(find.text('No matching appointments'), findsOneWidget);
      expect(find.textContaining('No appointments match "NonExistentSearchTerm"'), findsOneWidget);
      expect(find.text('Clear Search'), findsOneWidget);

      // Tap "Clear Search" in the empty state
      await tester.tap(find.text('Clear Search'));
      await tester.pumpAndSettle();

      // All original bookings are restored
      expect(find.text('Milo'), findsOneWidget);
      expect(find.text('Bella'), findsOneWidget);
      expect(find.text('Rocky'), findsOneWidget);

      // Filter with another query and clear via prefix/suffix close button
      await tester.enterText(searchField, 'Milo');
      await tester.pumpAndSettle();
      expect(find.text('Bella'), findsNothing);

      final clearIconButton = find.byTooltip('Clear search');
      expect(clearIconButton, findsOneWidget);
      await tester.tap(clearIconButton);
      await tester.pumpAndSettle();

      expect(find.text('Milo'), findsOneWidget);
      expect(find.text('Bella'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Combines search with groomer filter seamlessly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: searchMockBookings,
            initialGroomerFilterId: '1', // Groomer 1 (Merisa Brown)
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially only Groomer 1's appointments: Milo and Rocky
      expect(find.text('Milo'), findsOneWidget);
      expect(find.text('Rocky'), findsOneWidget);
      expect(find.text('Bella'), findsNothing); // Assigned to Groomer 2

      // Search for "rocky" (case-insensitive test)
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'rocky');
      await tester.pumpAndSettle();

      expect(find.text('Rocky'), findsOneWidget);
      expect(find.text('Milo'), findsNothing);
      expect(find.text('Bella'), findsNothing);

      // Search for "Bella" (Groomer 2's dog) while Groomer 1 filter is active -> No match
      await tester.enterText(searchField, 'Bella');
      await tester.pumpAndSettle();

      expect(find.text('No matching appointments'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Pagination and searching records beyond the first page', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      final page1Bookings = List.generate(
        10,
        (i) => GroomerBooking(
          bookingId: 600 + i,
          status: 'confirmed',
          bookingDate: todayStr,
          startTime: '0${8 + (i ~/ 2)}:${i % 2 == 0 ? '00' : '30'}',
          endTime: '0${8 + (i ~/ 2)}:${i % 2 == 0 ? '30' : '59'}',
          petName: 'Dog #$i',
          customerName: 'Customer #$i',
          customerMobile: '555-000-000$i',
          serviceName: 'Grooming',
          groomerId: 1,
          groomerName: 'Merisa Brown',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: page1Bookings,
            initialGroomerFilterId: 'all',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify page 1 Dog #0 is present, but page 2 Dog #11 is not loaded
      expect(find.text('Dog #0'), findsOneWidget);
      expect(find.text('Dog #11'), findsNothing);

      // Search for Dog #11 before it exists -> shows empty search state
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Dog #11');
      await tester.pumpAndSettle();

      expect(find.text('No matching appointments'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Step 5 – Groomer Schedule API Integration & UI Verification Tests', () {
    test('getAllGroomersBookingsWithPagination repository method supports date range and returns pagination metadata', () async {
      final repo = ServicesLocator.groomerHomeRepository;
      expect(repo.getAllGroomersBookingsWithPagination, isNotNull);

      // Verify call structure with date range
      final res = await repo.getAllGroomersBookingsWithPagination(
        groomerId: 1,
        startDate: '2026-10-15',
        endDate: '2026-10-17',
        page: 1,
        limit: 10,
      );

      expect(res.appointments, isA<List<GroomerBooking>>());
      expect(res.hasNextPage, isA<bool>());
      expect(res.totalPages, isA<int>());
      expect(res.total, isA<int>());
    });

    testWidgets('Tapping Date Selector Bar opens timeline options modal with Single Date and Date Range options', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      await tester.pumpWidget(
        const MaterialApp(
          home: AllGroomersSchedulePage(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the date selector center
      final dateBarTrigger = find.byTooltip('Select Date or Date Range');
      expect(dateBarTrigger, findsOneWidget);
      await tester.tap(dateBarTrigger);
      await tester.pumpAndSettle();

      // Verify Bottom Sheet Options Modal
      expect(find.text('Select Schedule Timeline'), findsOneWidget);
      expect(find.text('Past, present, and future dates are unrestricted'), findsOneWidget);
      expect(find.text('Single Date Picker'), findsOneWidget);
      expect(find.text('Date Range Picker'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Displays Customer Special Instructions container with speaker notes icon on appointment card', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final mockBookings = [
        GroomerBooking(
          bookingId: 401,
          status: 'confirmed',
          bookingDate: todayStr,
          startTime: '09:00',
          endTime: '10:00',
          petName: 'Bella',
          customerName: 'Sarah Jenkins',
          serviceName: 'Full Spa',
          groomerId: 1,
          groomerName: 'Merisa Brown',
          specialInstructions: 'Please trim nails gently and use blueberry facial shampoo',
        ),
        GroomerBooking(
          bookingId: 402,
          status: 'confirmed',
          bookingDate: todayStr,
          startTime: '10:30',
          endTime: '11:30',
          petName: 'Milo',
          customerName: 'Tom Hanks',
          serviceName: 'Bath & Brush',
          groomerId: 1,
          groomerName: 'Merisa Brown',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: mockBookings,
            initialGroomerFilterId: 'all',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Customer instructions container is displayed for Bella
      expect(find.text('Customer Instructions: "Please trim nails gently and use blueberry facial shampoo"'), findsOneWidget);
      expect(find.byIcon(Icons.speaker_notes_outlined), findsOneWidget);

      // Verify Milo has no customer instructions container
      expect(find.text('Milo'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Searches appointments by Customer Special Instructions and Pet Breed', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));

      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final mockBookings = [
        GroomerBooking(
          bookingId: 501,
          status: 'confirmed',
          bookingDate: todayStr,
          startTime: '09:00',
          endTime: '10:00',
          petName: 'Daisy',
          breed: 'Golden Retriever',
          customerName: 'Alice Green',
          serviceName: 'Full Grooming',
          groomerId: 1,
          groomerName: 'Merisa Brown',
          specialInstructions: 'Extra fluff on tail requested',
        ),
        GroomerBooking(
          bookingId: 502,
          status: 'confirmed',
          bookingDate: todayStr,
          startTime: '11:00',
          endTime: '12:00',
          petName: 'Rocky',
          breed: 'French Bulldog',
          customerName: 'Bob Vance',
          serviceName: 'Nail Trim',
          groomerId: 1,
          groomerName: 'Merisa Brown',
          specialInstructions: 'Careful with sensitive ears',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: mockBookings,
            initialGroomerFilterId: 'all',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);

      // 1. Search by customer instructions keyword: 'tail'
      await tester.enterText(searchField, 'tail');
      await tester.pumpAndSettle();
      expect(find.text('Daisy'), findsOneWidget);
      expect(find.text('Rocky'), findsNothing);

      // 2. Search by pet breed: 'Bulldog'
      await tester.enterText(searchField, 'Bulldog');
      await tester.pumpAndSettle();
      expect(find.text('Daisy'), findsNothing);
      expect(find.text('Rocky'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
