import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/booking_date_time_page.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/bookings/repo/booking_repository.dart';
import 'package:shear_heaven_pet_spa/src/store/repositories/store_repository.dart';
import 'package:get_it/get_it.dart';

class MockStoreRepository extends StoreRepository {
  @override
  Future<List<Map<String, dynamic>>> getStoreSchedule() async {
    return [
      {"Day": "Monday", "Start": "08:00", "End": "18:00", "Open": "Yes"},
      {"Day": "Tuesday", "Start": "08:00", "End": "18:00", "Open": "Yes"},
      {"Day": "Wednesday", "Start": "08:00", "End": "18:00", "Open": "Yes"},
      {"Day": "Thursday", "Start": "08:00", "End": "18:00", "Open": "Yes"},
      {"Day": "Friday", "Start": "08:00", "End": "18:00", "Open": "Yes"},
      {"Day": "Saturday", "Start": "08:00", "End": "18:00", "Open": "Yes"},
      {"Day": "Sunday", "Start": "08:00", "End": "18:00", "Open": "Yes"}
    ];
  }
}

class MockBookingRepository extends BookingRepository {
  @override
  Future<List<Map<String, dynamic>>> getBookingsForDate(String date) async => [];

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
            'id': 1,
            'name': 'Test Groomer',
            'available': true,
            'availableWindows': [
              {'startTime': '08:00', 'endTime': '18:00'}
            ],
            'bookedSlots': [
              {'startTime': '10:00', 'endTime': '11:00', 'groomerId': 1}
            ]
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

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<SessionService>(session);
    GetIt.I.registerSingleton<ApiRepository>(apiRepo);
    GetIt.I.registerSingleton<BookingDraft>(BookingDraft());
    GetIt.I.registerSingleton<StoreRepository>(MockStoreRepository());
    GetIt.I.registerSingleton<BookingRepository>(MockBookingRepository());
  });

  tearDownAll(() {
    GetIt.instance.reset();
  });

  setUp(() {
    ServicesLocator.bookingDraft.reset();
    ServicesLocator.bookingDraft.setService({'id': '1', 'name': 'Bath', 'duration': '60 min'});
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    ServicesLocator.bookingDraft.setDate(tomorrow);
  });

  testWidgets('Time Slot Picker renders available, selected, and unavailable states', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => ResponsiveBreakpoints(
        breakpoints: const [
          Breakpoint(start: 0, end: 450, name: MOBILE),
          Breakpoint(start: 451, end: 800, name: TABLET),
          Breakpoint(start: 801, end: 1920, name: DESKTOP),
        ],
        child: child!,
      ),
      home: const BookingDateTimePage(),
    ));
    await tester.pumpAndSettle();

    // 1. Verify available slot rendering (e.g., 9:00 AM)
    final slot900Finder = find.text('9:00 AM');
    expect(slot900Finder, findsOneWidget);

    // 2. Verify disabled slot rendering (10:00 AM is mocked as booked)
    final slot1000Finder = find.text('10:00 AM');
    expect(slot1000Finder, findsOneWidget);
    
    final slot1000Text = tester.widget<Text>(slot1000Finder);
    expect(slot1000Text.style?.decoration, equals(TextDecoration.lineThrough)); // Disabled visual

    // 3. Verify disabled slot cannot be selected
    await tester.ensureVisible(slot1000Finder);
    await tester.pumpAndSettle();
    await tester.tap(slot1000Finder);
    await tester.pump();
    expect(ServicesLocator.bookingDraft.timeSlot, isNull); // Selection remains null because 10:00 is blocked

    // 4. Test selecting an available slot (9:00 AM)
    await tester.ensureVisible(slot900Finder);
    await tester.pumpAndSettle();
    await tester.tap(slot900Finder);
    await tester.pumpAndSettle();

    // Verify draft updated (stored as 24h key)
    expect(ServicesLocator.bookingDraft.timeSlot, equals('09:00'));

    final selectedText = tester.widget<Text>(find.text('9:00 AM'));
    expect(selectedText.style?.color, equals(Colors.white)); // Selected text color
  });
}
