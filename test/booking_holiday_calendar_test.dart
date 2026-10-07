import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/bookings/repo/booking_repository.dart';
import 'package:shear_heaven_pet_spa/src/store/repo/store_repository.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/booking_date_time_page.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  Future<List<Map<String, dynamic>>> getHolidays() async {
    final holidayDate = DateTime.now().add(const Duration(days: 2));
    final mStr = holidayDate.month.toString().padLeft(2, '0');
    final dStr = holidayDate.day.toString().padLeft(2, '0');
    return [
      {
        "HolidayId": "H001",
        "Name": "Store Holiday",
        "Date": "$mStr/$dStr/${holidayDate.year}",
      }
    ];
  }

  @override
  bool isHoliday(DateTime date) {
    final holidayDate = DateTime.now().add(const Duration(days: 2));
    return date.year == holidayDate.year &&
        date.month == holidayDate.month &&
        date.day == holidayDate.day;
  }

  @override
  bool isStoreClosedDay(DateTime date) {
    return false;
  }
}

class MockBookingRepository extends BookingRepository {
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
        'availableSlots': [],
      }
    };
  }

  @override
  Future<Map<String, dynamic>?> getGroomerAvailability({
    required String date,
    int? groomerId,
    List<int>? groomerIds,
    int? durationMinutes,
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
            'workingHours': {'isWorking': true, 'startTime': '08:00', 'endTime': '17:00'},
            'availableWindows': [
              {'startTime': '08:00', 'endTime': '17:00'}
            ],
            'bookedSlots': [],
            'multiBookingEnabled': true,
            'slotBookingLimit': 3,
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

    await ServicesLocator.initialize();

    if (serviceLocator.isRegistered<StoreRepository>()) {
      serviceLocator.unregister<StoreRepository>();
    }
    serviceLocator.registerSingleton<StoreRepository>(MockStoreRepository());

    if (serviceLocator.isRegistered<BookingRepository>()) {
      serviceLocator.unregister<BookingRepository>();
    }
    serviceLocator.registerSingleton<BookingRepository>(MockBookingRepository());
  });

  tearDownAll(() {
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

  testWidgets('Holiday calendar interactions and state', (WidgetTester tester) async {
    final draft = ServicesLocator.bookingDraft;
    draft.setService({'name': 'Bath', 'duration': '60 min', 'id': 1});
    draft.addOns.add({'name': 'Nail Trim', 'id': 'nail_trim'});
    draft.setGroomer({'name': 'Test Groomer', 'id': '1'});

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final holidayDate = today.add(const Duration(days: 2));
    final normalDate = today.add(const Duration(days: 1));

    draft.setDate(today);

    await pumpPage(tester);

    // 2. A known holiday is visually disabled.
    final holidayFinder = find.descendant(
      of: find.byType(Row),
      matching: find.text(holidayDate.day.toString()),
    ).last;

    final holidayWidget = tester.widget<Text>(holidayFinder);
    expect(holidayWidget.style!.color, const Color(0xFFAFAFAF));

    // 3. A non-holiday date remains selectable.
    final normalDateFinder = find.descendant(
      of: find.byType(Row),
      matching: find.text(normalDate.day.toString()),
    ).last;

    final normalDateWidget = tester.widget<Text>(normalDateFinder);
    expect(normalDateWidget.style!.color, const Color(0xFF120C0C));

    // 4. Tapping a holiday does NOT update BookingDraft.date.
    await tester.tap(holidayFinder);
    await tester.pumpAndSettle();

    expect(draft.date, today);

    // 6. Tapping a valid date updates BookingDraft.date.
    await tester.tap(normalDateFinder);
    await tester.pumpAndSettle();

    expect(draft.date?.day, normalDate.day);
    expect(draft.service!['name'], 'Bath');
    expect(draft.addOns.length, 1);
  });
}
