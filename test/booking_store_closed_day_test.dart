import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/bookings/repo/booking_repository.dart';
import 'package:shear_heaven_pet_spa/src/store/repositories/store_repository.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/booking_date_time_page.dart';

class MockStoreRepository extends StoreRepository {
  @override
  Future<List<Map<String, dynamic>>> getStoreSchedule() async {
    return [
      {"Day": "Sunday", "Open": "No", "Start": "", "last_booking_available": "", "End": ""},
      {"Day": "Monday", "Open": "Yes", "Start": "08:00", "last_booking_available": "04:00", "End": "05:30"},
      {"Day": "Tuesday", "Open": "No", "Start": "08:00", "last_booking_available": "04:00", "End": "05:30"},
      {"Day": "Wednesday", "Open": "Yes", "Start": "08:00", "last_booking_available": "04:00", "End": "05:30"},
      {"Day": "Thursday", "Open": "Yes", "Start": "08:00", "last_booking_available": "04:00", "End": "05:30"},
      {"Day": "Friday", "Open": "Yes", "Start": "08:00", "last_booking_available": "04:00", "End": "05:30"},
      {"Day": "Saturday", "Open": "Yes", "Start": "08:00", "last_booking_available": "04:00", "End": "05:30"}
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getGroomers() async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getHolidays() async {
    return [
      {"HolidayId": "H001", "Name": "Independence Day", "Date": "07/04/2026"}
    ];
  }

  @override
  bool isHoliday(DateTime date) {
    if (date.year == 2026 && date.month == 7 && date.day == 4) return true;
    return false;
  }

  @override
  bool isStoreClosedDay(DateTime date) {
    return date.weekday == DateTime.sunday || date.weekday == DateTime.tuesday;
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
    return {
      'success': true,
      'data': {
        'store': {
          'closed': false,
          'operationalHours': {'startTime': '08:00', 'endTime': '18:00'},
        },
        'groomers': []
      }
    };
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final sessionService = SessionService();
    await sessionService.initialize();
    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<SessionService>(sessionService);
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

  testWidgets('Store closed day calendar interactions and state', (WidgetTester tester) async {
    final draft = ServicesLocator.bookingDraft;
    draft.setService({'name': 'Bath', 'duration': '60 min'});
    draft.addOns.add({'name': 'Nail Trim', 'id': 'nail_trim'});
    draft.setGroomer({'name': 'Test Groomer', 'id': '1'});

    // Set initial date to August 10, 2026 (Monday, which is open)
    final initialDate = DateTime(2026, 8, 10);
    draft.setDate(initialDate);

    await pumpPage(tester);

    // 1. Calendar renders successfully
    expect(find.textContaining('August'), findsOneWidget);

    // August 11, 2026 is Tuesday (Closed)
    final tuesdayFinder = find.descendant(
      of: find.byType(Row),
      matching: find.text('11'),
    ).first;

    // 3. A closed weekday is visually disabled.
    final tuesdayWidget = tester.widget<Text>(tuesdayFinder);
    expect(tuesdayWidget.style!.color, const Color(0xFFAFAFAF));

    // August 12, 2026 is Wednesday (Open)
    final wednesdayFinder = find.descendant(
      of: find.byType(Row),
      matching: find.text('12'),
    ).first;

    // 2. An open weekday remains selectable and visually active
    final wednesdayWidget = tester.widget<Text>(wednesdayFinder);
    expect(wednesdayWidget.style!.color, const Color(0xFF120C0C));

    // 4. Tapping a closed date does NOT update BookingDraft.date.
    await tester.tap(tuesdayFinder);
    await tester.pumpAndSettle();

    expect(draft.date, initialDate); // Still August 10

    // 5. Tapping a closed date does NOT trigger _loadSlots() (implied since date didn't change)
    // 6. Existing selected valid date remains unchanged

    // Now navigate to July to test holiday logic still intact
    final leftArrow = find.byIcon(Icons.chevron_left);
    await tester.tap(leftArrow);
    await tester.pumpAndSettle();

    // 7. Holiday dates remain disabled.
    // July 4 is Saturday (Open), but is a holiday, so it should be disabled.
    final july4Finder = find.descendant(
      of: find.byType(Row),
      matching: find.text('4'),
    ).first;

    final holidayWidget = tester.widget<Text>(july4Finder);
    expect(holidayWidget.style!.color, const Color(0xFFAFAFAF));
    
    await tester.tap(july4Finder);
    await tester.pumpAndSettle();
    expect(draft.date, initialDate); // Still August 10

    // Now tap a valid open day in July (July 6 is Monday, Open, not a holiday)
    final july6Finder = find.descendant(
      of: find.byType(Row),
      matching: find.text('6'),
    ).first;

    await tester.tap(july6Finder);
    await tester.pumpAndSettle();

    // 13. Valid open dates still trigger the existing slot-loading flow and date changes.
    expect(draft.date, DateTime(2026, 7, 6));

    // 10. Existing groomer selection remains intact.
    expect(draft.groomer!['name'], 'Test Groomer');

    // 11. Existing service selection remains intact.
    expect(draft.service!['name'], 'Bath');

    // 12. Existing add-on selection remains intact.
    expect(draft.addOns.length, 1);
  });
}
