import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/booking_date_time_page.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/bookings/repo/booking_repository.dart';
import 'package:shear_heaven_pet_spa/src/store/repositories/store_repository.dart';
import 'package:get_it/get_it.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';

class MockBookingRepository extends BookingRepository {
  @override
  Future<List<String>> getBookedSlotsForDate(String date) async {
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
    return {
      'success': true,
      'data': {
        'store': {
          'closed': false,
          'operationalHours': {'startTime': '08:00', 'endTime': '18:00'},
        },
        'groomers': [
          {
            'id': 'G001',
            'firstName': 'Merisa',
            'lastName': 'Brown',
            'role': 'Lead Groomer',
            'available': true,
            'availableSlots': [
              {'startTime': '08:00', 'endTime': '09:00', 'isAvailable': true}
            ],
          }
        ]
      }
    };
  }
}

class MockStoreRepository extends StoreRepository {
  @override
  Future<List<Map<String, dynamic>>> getGroomers() async {
    return [
      {
        'GroomerId': 'G001',
        'FirstName': 'Merisa',
        'LastName': 'Brown',
        'Role': 'Lead Groomer',
      }
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getStoreSchedule() async {
    return [
      {'Day': 'Monday', 'Open': 'Yes', 'Start': '08:00', 'last_booking_available': '04:00', 'End': '05:30'}
    ];
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

    GetIt.instance.registerSingleton<SessionService>(session);
    GetIt.instance.registerSingleton<ApiRepository>(apiRepo);
    GetIt.instance.registerSingleton<BookingDraft>(BookingDraft());
    GetIt.instance.registerSingleton<BookingRepository>(MockBookingRepository());
    GetIt.instance.registerSingleton<StoreRepository>(MockStoreRepository());
  });

  tearDownAll(() {
    GetIt.instance.reset();
  });

  setUp(() {
    ServicesLocator.bookingDraft.reset();
    ServicesLocator.bookingDraft.setService({'duration': '60 min', 'price': 50});
  });

  testWidgets('BookingDateTimePage loads dynamic groomers from StoreRepository', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => ResponsiveBreakpoints(
        breakpoints: const [
          Breakpoint(start: 0, end: 450, name: MOBILE),
          Breakpoint(start: 451, end: 800, name: TABLET),
          Breakpoint(start: 801, end: 1920, name: DESKTOP),
        ],
        child: child!,
      ),
      home: BookingDateTimePage(),
    ));
    await tester.pumpAndSettle();

    // Verify "ANY" / "No Preference" groomer is prepended and rendered
    expect(find.text('No Pref'), findsOneWidget);
    expect(find.text('ANY'), findsOneWidget); // The initial text avatar

    // Verify the mock groomer "Merisa Brown" is rendered
    expect(find.text('Merisa Brown'), findsOneWidget);
    expect(find.text('M'), findsOneWidget); // The initial text avatar

    // Tap "Merisa Brown" groomer avatar
    final merisaFinder = find.text('Merisa Brown');
    await tester.ensureVisible(merisaFinder);
    await tester.pumpAndSettle();
    await tester.tap(merisaFinder);
    await tester.pumpAndSettle();

    // Verify selected groomer is updated in the draft
    expect(ServicesLocator.bookingDraft.groomer, isNotNull);
    expect(ServicesLocator.bookingDraft.groomer?['id'], equals('G001'));
    expect(ServicesLocator.bookingDraft.groomer?['name'], equals('Merisa Brown'));
  });
}
