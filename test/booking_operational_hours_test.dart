import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/bookings/repo/booking_repository.dart';
import 'package:shear_heaven_pet_spa/src/store/repositories/store_repository.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/booking_date_time_page.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';

class MockStoreRepository extends StoreRepository {
  @override
  Future<List<Map<String, dynamic>>> getStoreSchedule() async {
    return [
      {"Day": "Monday", "Open": "Yes", "Start": "08:00", "last_booking_available": "04:00", "End": "05:30"},
      {"Day": "Tuesday", "Open": "Yes", "Start": "08:00", "last_booking_available": "", "End": "12:00"}, // Missing last booking, short day
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
    return false;
  }
}

class MockBookingRepository extends BookingRepository {
  @override
  Future<List<Map<String, dynamic>>> getBookingsForDate(String date) async {
    return [
      // Block out 9:30 AM to 10:30 AM
      {
        'start_time': DateTime(2026, 8, 10, 9, 30).toIso8601String(),
        'end_time': DateTime(2026, 8, 10, 10, 30).toIso8601String(),
      }
    ];
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
          'operationalHours': {'startTime': '08:00', 'endTime': '17:30'},
        },
        'groomers': [
          {
            'id': 'G001',
            'firstName': 'Merisa',
            'lastName': 'Brown',
            'available': true,
            'workingHours': {'startTime': '08:00', 'endTime': '17:30'},
            'availableSlots': [
              {'startTime': '08:00', 'endTime': '09:00', 'isAvailable': true},
              {'startTime': '08:30', 'endTime': '09:30', 'isAvailable': true},
              {'startTime': '09:00', 'endTime': '10:00', 'isAvailable': true},
              {'startTime': '09:30', 'endTime': '10:30', 'isAvailable': false},
              {'startTime': '10:00', 'endTime': '11:00', 'isAvailable': true},
              {'startTime': '10:30', 'endTime': '11:30', 'isAvailable': true},
              {'startTime': '11:00', 'endTime': '12:00', 'isAvailable': true},
              {'startTime': '11:30', 'endTime': '12:30', 'isAvailable': true},
              {'startTime': '12:00', 'endTime': '13:00', 'isAvailable': true},
              {'startTime': '12:30', 'endTime': '13:30', 'isAvailable': true},
              {'startTime': '13:00', 'endTime': '14:00', 'isAvailable': true},
              {'startTime': '13:30', 'endTime': '14:30', 'isAvailable': true},
              {'startTime': '14:00', 'endTime': '15:00', 'isAvailable': true},
              {'startTime': '14:30', 'endTime': '15:30', 'isAvailable': true},
              {'startTime': '15:00', 'endTime': '16:00', 'isAvailable': true},
              {'startTime': '15:30', 'endTime': '16:30', 'isAvailable': true},
              {'startTime': '16:00', 'endTime': '17:00', 'isAvailable': true},
              {'startTime': '16:30', 'endTime': '17:30', 'isAvailable': true},
            ],
            'bookedSlots': [
              {'startTime': '09:30', 'endTime': '10:30', 'groomerId': 'G001'}
            ],
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

  setUp(() {
    BookingDateUtils.disableDateRangeValidationForTesting = true;
  });

  tearDown(() {
    BookingDateUtils.disableDateRangeValidationForTesting = false;
  });

  tearDownAll(() {
    BookingDateUtils.disableDateRangeValidationForTesting = false;
    GetIt.I.reset();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => ResponsiveBreakpoints(
        breakpoints: const [
          Breakpoint(start: 0, end: 450, name: MOBILE),
          Breakpoint(start: 451, end: 800, name: TABLET),
          Breakpoint(start: 801, end: 1920, name: DESKTOP),
        ],
        child: child!,
      ),
      home: BookingDateTimePage(key: UniqueKey()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Operational hours and last booking cutoff', (WidgetTester tester) async {
    final draft = ServicesLocator.bookingDraft;
    // 90 minute duration
    draft.setService({'name': 'Bath', 'duration': '90 min'});
    
    // Set to Monday August 10, 2026
    draft.setDate(DateTime(2026, 8, 10));

    await pumpPage(tester);

    // Monday schedule: Start 8:00 AM, End 5:30 PM (17:30), Last booking 4:00 PM (16:00)
    
    // 1. Slots before opening time are not generated/available.
    expect(find.text('7:30 AM'), findsNothing);
    expect(find.text('8:00 AM'), findsOneWidget); // Generated because it starts at 8:00

    // Check if 8:00 AM is available (not lineThrough).
    final slot800Finder = find.descendant(
      of: find.byType(Container),
      matching: find.text('8:00 AM'),
    ).first;
    var widget800 = tester.widget<Text>(slot800Finder);
    expect(widget800.style!.decoration, isNull);

    // 10. Existing booking overlap logic still works.
    // Booking from 9:30 to 10:30.
    // 9:00 AM slot + 60 min = 10:00 AM (overlaps 9:30-10:30)
    final slot900Finder = find.descendant(
      of: find.byType(Container),
      matching: find.text('9:00 AM'),
    ).first;
    var widget900 = tester.widget<Text>(slot900Finder);
    expect(widget900.style!.decoration, TextDecoration.lineThrough); // Unavailable due to overlap

    // 6. A slot at 4:00 PM (16:00)
    final slot400Finder = find.descendant(
      of: find.byType(Container),
      matching: find.text('4:00 PM'),
    ).first;
    var widget400 = tester.widget<Text>(slot400Finder);
    expect(widget400.style!.decoration, isNull); // Available

    // 3. Slots after operational closing time are not generated
    expect(find.text('5:00 PM'), findsNothing);
  });
}
