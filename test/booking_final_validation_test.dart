import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/bookings/repo/booking_repository.dart';
import 'package:shear_heaven_pet_spa/src/store/repositories/store_repository.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/booking_date_time_page.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';

class MockStoreRepository extends StoreRepository {
  @override
  Future<List<Map<String, dynamic>>> getStoreSchedule() async {
    return [
      {"Day": "Monday", "Open": "Yes", "Start": "08:00", "last_booking_available": "04:00", "End": "05:30"},
      {"Day": "Tuesday", "Open": "No", "Start": "08:00", "last_booking_available": "04:00", "End": "05:30"},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getGroomers() async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getHolidays() async {
    return [];
  }

  @override
  bool isHoliday(DateTime date) {
    if (date.year == 2026 && date.month == 8 && date.day == 12) return true; // Wednesday
    return false;
  }
}

class MockBookingRepository extends BookingRepository {
  @override
  Future<List<Map<String, dynamic>>> getBookingsForDate(String date) async {
    return [];
  }

  @override
  Future<Map<String, dynamic>?> getAvailability({
    required String date,
    int? serviceId,
    int? packageId,
    List<int>? addOnIds,
    int? groomerId,
  }) async {
    return {
      'success': true,
      'data': {
        'totalDurationMinutes': 60,
        'totalPrice': 50.0,
      }
    };
  }

  @override
  Future<Map<String, dynamic>?> getGroomerAvailability({
    required String date,
    required int durationMinutes,
    int? groomerId,
    List<int>? groomerIds,
  }) async {
    final isClosed = date == '2026-08-11';
    final isHoliday = date == '2026-08-12';
    return {
      'success': true,
      'data': {
        'store': {
          'closed': isClosed || isHoliday,
          'holiday': isHoliday ? 'Test Holiday' : null,
          'operationalHours': {'startTime': '08:00', 'endTime': '18:00'},
        },
        'groomers': isClosed || isHoliday
            ? []
            : [
                {
                  'id': 'G001',
                  'firstName': 'Merisa',
                  'lastName': 'Brown',
                  'available': true,
                  'workingHours': {'startTime': '08:00', 'endTime': '18:00'},
                  'availableSlots': [
                    {'startTime': '08:00', 'endTime': '09:00', 'isAvailable': true},
                  ],
                  'bookedSlots': [],
                }
              ]
      }
    };
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    final session = SessionService();
    await session.initialize();

    final apiRepo = ApiRepository();
    await apiRepo.initialize();

    GetIt.I.registerSingleton<SessionService>(session);
    GetIt.I.registerSingleton<ApiRepository>(apiRepo);
    GetIt.I.registerSingleton<BookingDraft>(BookingDraft());
    GetIt.I.registerSingleton<StoreRepository>(MockStoreRepository());
    GetIt.I.registerSingleton<BookingRepository>(MockBookingRepository());
  });

  Future<GoRouter> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => ScaffoldMessenger(child: BookingDateTimePage(key: UniqueKey())),
        ),
        GoRoute(
          path: '/booking-review',
          name: RouteNames.bookingReview,
          builder: (context, state) => const Scaffold(body: Text('Review Page')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => ResponsiveBreakpoints(
        breakpoints: const [
          Breakpoint(start: 0, end: 450, name: MOBILE),
          Breakpoint(start: 451, end: 800, name: TABLET),
          Breakpoint(start: 801, end: 1920, name: DESKTOP),
        ],
        child: child!,
      ),
    ));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('Final validation logic prevents invalid bookings', (WidgetTester tester) async {
    final draft = ServicesLocator.bookingDraft;
    draft.setService({'name': 'Bath', 'duration': '60 min'});
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    draft.setDate(tomorrow);
    draft.clearSelectedSlot();

    await pumpPage(tester);

    // 1 & 2: Continue with no time selected -> Button disabled / navigation blocked
    final continueFinder = find.text('Continue');
    expect(continueFinder, findsOneWidget);
    
    // Tap Continue
    await tester.tap(continueFinder);
    await tester.pumpAndSettle();

    expect(find.text('Review Page'), findsNothing);

    // Try an invalid slot
    draft.setTimeSlot('99:99');
    await tester.pumpAndSettle();
    await tester.tap(continueFinder);
    await tester.pumpAndSettle();
    expect(find.text('Review Page'), findsNothing);

    // Now select valid 8:00 AM slot
    final slot800Finder = find.text('8:00 AM');
    expect(slot800Finder, findsOneWidget);
    await tester.tap(slot800Finder);
    await tester.pumpAndSettle();

    expect(draft.timeSlot, '08:00');
    expect(draft.endTime, '09:00');

    // Tap Continue
    await tester.tap(continueFinder);
    await tester.pumpAndSettle();

    // 3. Continue with valid date + valid slot -> allowed.
    expect(find.text('Review Page'), findsOneWidget);
  });
}
