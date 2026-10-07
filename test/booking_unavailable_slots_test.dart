import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/booking_date_time_page.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/bookings/repo/booking_repository.dart';
import 'package:shear_heaven_pet_spa/src/store/repositories/store_repository.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:get_it/get_it.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';

class MockBookingRepository extends BookingRepository {
  List<Map<String, dynamic>> mockBookings = [];

  @override
  Future<List<Map<String, dynamic>>> getBookingsForDate(String date) async {
    return mockBookings;
  }

  @override
  Future<Map<String, dynamic>?> getAvailability({
    required String date,
    int? serviceId,
    int? packageId,
    List<int>? addOnIds,
    int? groomerId,
  }) async {
    final durationMin = ServicesLocator.bookingDraft.service?['duration'] == '30 min' ? 30 : 60;
    return {
      'success': true,
      'data': {
        'totalDurationMinutes': durationMin,
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
    final hasBookings = mockBookings.isNotEmpty;
    return {
      'success': true,
      'data': {
        'store': {
          'closed': false,
          'operationalHours': {'startTime': '08:00', 'endTime': '10:00'},
        },
        'groomers': [
          {
            'id': 'G001',
            'firstName': 'Merisa',
            'lastName': 'Brown',
            'available': true,
            'workingHours': {'startTime': '08:00', 'endTime': '10:00'},
            'availableSlots': [
              {'startTime': '08:00', 'endTime': durationMinutes == 30 ? '08:30' : '09:00', 'isAvailable': true},
              {'startTime': '08:30', 'endTime': durationMinutes == 30 ? '09:00' : '09:30', 'isAvailable': !hasBookings},
              {'startTime': '09:00', 'endTime': durationMinutes == 30 ? '09:30' : '10:00', 'isAvailable': !hasBookings},
              {'startTime': '09:30', 'endTime': '10:00', 'isAvailable': durationMinutes == 30},
            ],
            'bookedSlots': hasBookings
                ? [{'startTime': '09:00', 'endTime': '10:00', 'groomerId': 'G001'}]
                : [],
          }
        ]
      }
    };
  }
}

class MockStoreRepository extends StoreRepository {
  List<Map<String, dynamic>> mockSchedule = [];

  @override
  Future<List<Map<String, dynamic>>> getGroomers() async {
    return [
      {'GroomerId': 'G001', 'FirstName': 'Merisa', 'LastName': 'Brown'}
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getStoreSchedule() async {
    return mockSchedule;
  }

  @override
  Future<List<Map<String, dynamic>>> getHolidays() async {
    return [];
  }

  @override
  bool isHoliday(DateTime date) => false;

  @override
  bool isStoreClosedDay(DateTime date) => false;
}

void main() {
  late MockBookingRepository bookingRepo;
  late MockStoreRepository storeRepo;
  late SessionService sessionService;
  late ApiRepository apiRepo;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    await GetIt.instance.reset();
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    sessionService = SessionService();
    await sessionService.initialize();

    apiRepo = ApiRepository();
    await apiRepo.initialize();

    bookingRepo = MockBookingRepository();
    storeRepo = MockStoreRepository();

    GetIt.instance.registerSingleton<SessionService>(sessionService);
    GetIt.instance.registerSingleton<ApiRepository>(apiRepo);
    GetIt.instance.registerSingleton<BookingDraft>(BookingDraft());
    GetIt.instance.registerSingleton<BookingRepository>(bookingRepo);
    GetIt.instance.registerSingleton<StoreRepository>(storeRepo);

    ServicesLocator.bookingDraft.reset();
    final validDate = BookingDateUtils.minAllowedDate.add(const Duration(days: 2));
    ServicesLocator.bookingDraft.setDate(validDate);
  });

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

  testWidgets('Unavailable slots are visually disabled and unselectable', (WidgetTester tester) async {
    storeRepo.mockSchedule = [
      {'Day': 'Monday', 'Open': 'Yes', 'Start': '08:00', 'End': '10:00'}
    ];
    // 8:00 to 10:00. Generated slots: 8:00, 8:30, 9:00, 9:30
    // Service duration 60 mins -> 9:30 is overflow -> disabled.
    // Booking overlap 9:00 to 10:00 -> 8:30 and 9:00 disabled.
    
    final today = ServicesLocator.bookingDraft.date!;
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    bookingRepo.mockBookings = [
      {'start_time': '$dateKey 09:00:00', 'end_time': '$dateKey 10:00:00'}
    ];
    
    ServicesLocator.bookingDraft.setService({'duration': '60 min'});
    await pumpPage(tester);

    // Find slots
    final slot800 = find.text('8:00 AM'); // Available
    final slot900 = find.text('9:00 AM'); // Disabled (overlap)

    expect(slot800, findsOneWidget);
    expect(slot900, findsOneWidget);

    // 1. Available slot is enabled and tappable.
    // Check decoration of 8:00 AM (should not be lineThrough)
    Text text800 = tester.widget<Text>(slot800);
    expect(text800.style?.decoration, isNull);

    // 2. Unavailable slot is visually disabled.
    // Check decoration of 9:00 AM
    Text text900 = tester.widget<Text>(slot900);
    expect(text900.style?.decoration, equals(TextDecoration.lineThrough));

    // 3. Tapping an unavailable slot does not change selected time
    await tester.tap(slot900);
    await tester.pump();
    expect(ServicesLocator.bookingDraft.timeSlot, isNull);

    // 4. Selected slot remains visually distinct
    await tester.tap(slot800);
    await tester.pump();
    expect(ServicesLocator.bookingDraft.timeSlot, equals('08:00'));

    // 5. Changing date/service updates disabled states
    // Change duration to 30 mins -> 9:30 AM should now be available
    bookingRepo.mockBookings = [];
    ServicesLocator.bookingDraft.setService({'duration': '30 min'});
    await pumpPage(tester);
    
    // Find slots again since the page was rebuilt from scratch
    final newSlot930 = find.text('9:30 AM');
    expect(newSlot930, findsOneWidget);

    Text text930Updated = tester.widget<Text>(newSlot930);
    expect(text930Updated.style?.decoration, isNull); // No longer disabled
  });
}
