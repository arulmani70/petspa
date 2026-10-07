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

class MockBookingRepository extends BookingRepository {
  List<Map<String, dynamic>> mockBookings = [];
  late MockStoreRepository storeRepo;

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
    final d = ServicesLocator.bookingDraft.service?['duration']?.toString() ?? '60 min';
    final dur = int.tryParse(d.split(' ').first) ?? 60;
    return {
      'success': true,
      'data': {
        'totalDurationMinutes': dur,
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
    final sched = storeRepo.mockSchedule.isNotEmpty
        ? storeRepo.mockSchedule.first
        : {'Day': 'Monday', 'Open': 'Yes', 'Start': '08:00', 'End': '10:00'};
    final isOpen = sched['Open']?.toString().toLowerCase() == 'yes';
    final start = sched['Start']?.toString() ?? '08:00';
    final end = sched['End']?.toString() ?? '10:00';

    if (!isOpen || start == end) {
      return {
        'success': true,
        'data': {
          'store': {
            'closed': !isOpen,
            'operationalHours': {'startTime': start, 'endTime': end},
          },
          'groomers': []
        }
      };
    }

    final booked = mockBookings.map((b) {
      final s = b['start_time']?.toString().split(' ').last.substring(0, 5) ?? '09:00';
      final e = b['end_time']?.toString().split(' ').last.substring(0, 5) ?? '10:00';
      return {
        'startTime': s,
        'endTime': e,
        'groomerId': 1,
      };
    }).toList();

    return {
      'success': true,
      'data': {
        'store': {
          'closed': false,
          'operationalHours': {'startTime': start, 'endTime': end},
        },
        'groomers': [
          {
            'id': 1,
            'name': 'Merisa Brown',
            'available': true,
            'availableWindows': [
              {'startTime': start, 'endTime': end}
            ],
            'bookedSlots': booked,
          }
        ]
      }
    };
  }
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
    bookingRepo.storeRepo = storeRepo;

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
  }

  testWidgets('1. Service fits exactly within schedule (e.g. 1 hour from 8 to 9)', (WidgetTester tester) async {
    storeRepo.mockSchedule = [
      {'Day': 'Monday', 'Open': 'Yes', 'Start': '08:00', 'End': '09:00'}
    ];
    ServicesLocator.bookingDraft.setService({'duration': '60 min'});
    await pumpPage(tester);

    final slotFinder = find.text('8:00 AM');
    expect(slotFinder, findsOneWidget);
    await tester.ensureVisible(slotFinder);
    await tester.tap(slotFinder);
    await tester.pumpAndSettle();
    expect(ServicesLocator.bookingDraft.timeSlot, equals('08:00'));
  });

  testWidgets('2. Service exceeds schedule end (e.g. 2 hours from 8 to 9)', (WidgetTester tester) async {
    storeRepo.mockSchedule = [
      {'Day': 'Monday', 'Open': 'Yes', 'Start': '08:00', 'End': '09:00'}
    ];
    ServicesLocator.bookingDraft.setService({'duration': '120 min'});
    await pumpPage(tester);

    expect(find.text('8:00 AM'), findsNothing);
  });

  testWidgets('3. Service overlaps an existing booking', (WidgetTester tester) async {
    storeRepo.mockSchedule = [
      {'Day': 'Monday', 'Open': 'Yes', 'Start': '08:00', 'End': '10:00'}
    ];
    final today = ServicesLocator.bookingDraft.date!;
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    bookingRepo.mockBookings = [
      {'start_time': '$dateKey 09:00:00', 'end_time': '$dateKey 10:00:00'}
    ];
    ServicesLocator.bookingDraft.setService({'duration': '60 min'});
    await pumpPage(tester);

    final slot800 = find.text('8:00 AM');
    expect(slot800, findsOneWidget);
    await tester.ensureVisible(slot800);
    await tester.tap(slot800);
    await tester.pumpAndSettle();
    expect(ServicesLocator.bookingDraft.timeSlot, equals('08:00'));

    final slot900 = find.text('9:00 AM');
    expect(slot900, findsOneWidget);
    await tester.ensureVisible(slot900);
    await tester.tap(slot900);
    await tester.pumpAndSettle();
    expect(ServicesLocator.bookingDraft.timeSlot, equals('08:00')); // unchanged, blocked
  });

  testWidgets('4. Candidate starts exactly when an existing booking ends', (WidgetTester tester) async {
    storeRepo.mockSchedule = [
      {'Day': 'Monday', 'Open': 'Yes', 'Start': '08:00', 'End': '10:00'}
    ];
    final today = ServicesLocator.bookingDraft.date!;
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    bookingRepo.mockBookings = [
      {'start_time': '$dateKey 08:00:00', 'end_time': '$dateKey 09:00:00'}
    ];
    ServicesLocator.bookingDraft.setService({'duration': '60 min'});
    await pumpPage(tester);

    final slot900 = find.text('9:00 AM');
    expect(slot900, findsOneWidget);
    await tester.ensureVisible(slot900);
    await tester.tap(slot900);
    await tester.pumpAndSettle();
    expect(ServicesLocator.bookingDraft.timeSlot, equals('09:00')); 
  });

  testWidgets('5. Existing booking starts exactly when candidate ends', (WidgetTester tester) async {
    storeRepo.mockSchedule = [
      {'Day': 'Monday', 'Open': 'Yes', 'Start': '08:00', 'End': '10:00'}
    ];
    final today = ServicesLocator.bookingDraft.date!;
    final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    bookingRepo.mockBookings = [
      {'start_time': '$dateKey 09:00:00', 'end_time': '$dateKey 10:00:00'}
    ];
    ServicesLocator.bookingDraft.setService({'duration': '60 min'});
    await pumpPage(tester);

    final slot800 = find.text('8:00 AM');
    expect(slot800, findsOneWidget);
    await tester.ensureVisible(slot800);
    await tester.tap(slot800);
    await tester.pumpAndSettle();
    expect(ServicesLocator.bookingDraft.timeSlot, equals('08:00')); 
  });

  testWidgets('6. Long-duration service', (WidgetTester tester) async {
    storeRepo.mockSchedule = [
      {'Day': 'Monday', 'Open': 'Yes', 'Start': '08:00', 'End': '10:00'}
    ];
    ServicesLocator.bookingDraft.setService({'duration': '120 min'});
    await pumpPage(tester);

    final slot800 = find.text('8:00 AM');
    expect(slot800, findsOneWidget);
    await tester.ensureVisible(slot800);
    await tester.tap(slot800);
    await tester.pumpAndSettle();
    expect(ServicesLocator.bookingDraft.timeSlot, equals('08:00')); 
  });

  testWidgets('7. Short-duration service', (WidgetTester tester) async {
    storeRepo.mockSchedule = [
      {'Day': 'Monday', 'Open': 'Yes', 'Start': '08:00', 'End': '09:00'} 
    ];
    ServicesLocator.bookingDraft.setService({'duration': '30 min'});
    await pumpPage(tester);

    final slot830 = find.text('8:30 AM');
    expect(slot830, findsOneWidget);
    await tester.ensureVisible(slot830);
    await tester.tap(slot830);
    await tester.pumpAndSettle();
    expect(ServicesLocator.bookingDraft.timeSlot, equals('08:30'));
  });

  testWidgets('8. No slots available', (WidgetTester tester) async {
    storeRepo.mockSchedule = [
      {'Day': 'Monday', 'Open': 'Yes', 'Start': '08:00', 'End': '08:00'} 
    ];
    ServicesLocator.bookingDraft.setService({'duration': '60 min'}); 
    await pumpPage(tester);

    expect(find.text('8:00 AM'), findsNothing);
  });

  testWidgets('9. Closed day', (WidgetTester tester) async {
    storeRepo.mockSchedule = [
      {'Day': 'Monday', 'Open': 'No', 'Start': '08:00', 'End': '17:00'} 
    ];
    ServicesLocator.bookingDraft.setService({'duration': '60 min'}); 
    await pumpPage(tester);

    expect(find.text('8:00 AM'), findsNothing);
  });
}
