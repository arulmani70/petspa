import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/bookings/repo/booking_repository.dart';
import 'package:shear_heaven_pet_spa/src/store/repositories/store_repository.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/booking_date_time_page.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';

class MockStoreRepository extends StoreRepository {
  List<Map<String, dynamic>> mockGroomers = [];

  @override
  Future<List<Map<String, dynamic>>> getStoreSchedule() async {
    return [
      {"Day": "Monday", "Start": "08:00", "End": "10:00", "Open": "Yes"},
      {"Day": "Tuesday", "Start": "08:00", "End": "10:00", "Open": "Yes"},
      {"Day": "Wednesday", "Start": "08:00", "End": "10:00", "Open": "Yes"},
      {"Day": "Thursday", "Start": "08:00", "End": "10:00", "Open": "Yes"},
      {"Day": "Friday", "Start": "08:00", "End": "10:00", "Open": "Yes"},
      {"Day": "Saturday", "Start": "08:00", "End": "10:00", "Open": "Yes"},
      {"Day": "Sunday", "Start": "08:00", "End": "10:00", "Open": "Yes"}
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getGroomers() async {
    return mockGroomers;
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
        'groomers': [
          {
            'id': 1,
            'name': 'Test Groomer',
            'available': true,
            'availableWindows': [
              {'startTime': '08:00', 'endTime': '12:00'}
            ],
            'bookedSlots': []
          }
        ]
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

  testWidgets('Calendar UI interactions and state', (WidgetTester tester) async {
    final draft = ServicesLocator.bookingDraft;
    draft.setService({'name': 'Bath', 'duration': '60 min'});
    draft.addOns.add({'name': 'Nail Trim', 'id': 'nail_trim'});
    draft.addOns.add({'name': 'Teeth Brushing', 'id': 'teeth_brush'});
    
    // Set initial date to today (start of allowed window)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    draft.setDate(today);

    await pumpPage(tester);

    // 1. Calendar renders successfully and today is displayed
    expect(find.textContaining(DateFormat('MMMM').format(today)), findsOneWidget); // visible month
    expect(find.text('${today.day}'), findsWidgets);

    // 2. Select tomorrow (today + 1) which is within allowed 14-day window
    final tomorrow = today.add(const Duration(days: 1));
    if (tomorrow.month == today.month) {
      final tomorrowFinder = find.byWidgetPredicate((widget) {
        if (widget is Text && widget.data == '${tomorrow.day}') {
          final color = widget.style?.color;
          return color == const Color(0xFF120C0C) || color == Colors.white;
        }
        return false;
      });
      
      expect(tomorrowFinder, findsOneWidget);
      await tester.tap(tomorrowFinder);
      await tester.pumpAndSettle();

      // 3. Selected date updates correctly in the booking state
      expect(draft.date, tomorrow);
    }

    // 4. Existing service and add-ons selection remains intact after changing date
    expect(draft.service, isNotNull);
    expect(draft.service!['name'], 'Bath');
    expect(draft.addOns.length, 2);
    expect(draft.addOns[0]['name'], 'Nail Trim');

    // 5. Existing time-slot state updates gracefully
    expect(find.text('8:00 AM'), findsOneWidget);
  });
}
