import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/bookings/repo/booking_repository.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/my_bookings_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';

class MockBookingRepository extends BookingRepository {
  List<Map<String, dynamic>> upcomingMock = [];
  List<Map<String, dynamic>> pastMock = [];
  List<Map<String, dynamic>> cancelledMock = [];

  @override
  Future<List<Map<String, dynamic>>> getUpcomingBookingsApi({bool forceRefresh = false}) async {
    return upcomingMock;
  }

  @override
  Future<List<Map<String, dynamic>>> getPastBookingsApi({bool forceRefresh = false}) async {
    return pastMock;
  }

  @override
  Future<List<Map<String, dynamic>>> getCancelledBookingsApi({bool forceRefresh = false}) async {
    return cancelledMock;
  }
}

void main() {
  late MockBookingRepository mockRepo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();

    mockRepo = MockBookingRepository();

    if (GetIt.I.isRegistered<BookingRepository>()) {
      GetIt.I.unregister<BookingRepository>();
    }
    GetIt.I.registerSingleton<BookingRepository>(mockRepo);
  });

  tearDownAll(() async {
    if (GetIt.I.isRegistered<BookingRepository>()) {
      GetIt.I.unregister<BookingRepository>();
    }
    GetIt.I.registerLazySingleton<BookingRepository>(() => BookingRepository());
  });

  group('MyBookingsPage upcoming appointments & current date empty view', () {
    testWidgets('Empty view for upcoming tab shows today date pill and message',
        (tester) async {
      mockRepo.upcomingMock = [];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MyBookingsPageMobile(),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final expectedDateBadge = 'Today: ${DateFormat('EEE, MMM d, yyyy').format(now)}';
      final expectedSubtitle =
          'No appointments scheduled for today (${DateFormat('MMM d, yyyy').format(now)}) or upcoming dates.\nBook an appointment for your pet!';

      expect(find.text(expectedDateBadge), findsOneWidget);
      expect(find.text(expectedSubtitle), findsOneWidget);
      expect(find.text('No Upcoming Appointments'), findsOneWidget);
      expect(find.text('Book Appointment'), findsOneWidget);
    });

    testWidgets('Preserves today appointment and sorts upcoming bookings soonest first',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final tomorrowStr =
          DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)));
      final nextWeekStr =
          DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 7)));

      mockRepo.upcomingMock = [
        {
          'bookingId': 101,
          'bookingDate': nextWeekStr,
          'startTime': '02:00 PM',
          'endTime': '03:00 PM',
          'petName': 'Charlie',
          'serviceName': 'Full Grooming',
          'status': 'CONFIRMED',
        },
        {
          'bookingId': 102,
          'bookingDate': todayStr,
          'startTime': '09:00 AM',
          'endTime': '10:00 AM',
          'petName': 'Buddy',
          'serviceName': 'Bath & Brush',
          'status': 'CONFIRMED',
        },
        {
          'bookingId': 103,
          'bookingDate': tomorrowStr,
          'startTime': '11:00 AM',
          'endTime': '12:00 PM',
          'petName': 'Max',
          'serviceName': 'Nail Trim',
          'status': 'PENDING',
        },
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MyBookingsPageMobile(),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Ensure all 3 appointments (including today's 9:00 AM) are displayed
      expect(find.text('Buddy'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
      expect(find.text('3 upcoming appointments'), findsOneWidget);

      // Verify Buddy (Today) is first in the list, then Max (Tomorrow), then Charlie (Next week)
      final buddyPos = tester.getTopLeft(find.text('Buddy')).dy;
      final maxPos = tester.getTopLeft(find.text('Max')).dy;
      final charliePos = tester.getTopLeft(find.text('Charlie')).dy;

      expect(buddyPos < maxPos, isTrue, reason: "Today's booking should appear before tomorrow's");
      expect(maxPos < charliePos, isTrue, reason: "Tomorrow's booking should appear before next week's");
    });
  });
}
