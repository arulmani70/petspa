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
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';

class MockStoreRepository extends StoreRepository {
  List<Map<String, dynamic>> mockGroomers = [];

  @override
  Future<List<Map<String, dynamic>>> getStoreSchedule() async {
    return [
      {"Day": "Monday", "Start": "08:00:00", "End": "10:00:00", "Open": "Yes"}
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
    final storeRepo = ServicesLocator.storeRepository as MockStoreRepository;
    final groomersList = storeRepo.mockGroomers.map((g) => {
      'id': g['GroomerId'] ?? 'G001',
      'firstName': g['FirstName'] ?? 'Merisa',
      'lastName': g['LastName'] ?? 'Brown',
      'role': g['Role'] ?? 'Lead Groomer',
      'profilePicture': g['image'] ?? g['ProfilePicture'] ?? g['profilePicture'],
      'available': true,
      'availableSlots': [
        {'startTime': '08:00', 'endTime': '09:00', 'isAvailable': true}
      ],
    }).toList();

    return {
      'success': true,
      'data': {
        'store': {
          'closed': false,
          'operationalHours': {'startTime': '08:00', 'endTime': '18:00'},
        },
        'groomers': groomersList,
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

  tearDownAll(() {
    GetIt.I.reset();
  });

  setUp(() {
    ServicesLocator.bookingDraft.reset();
    ServicesLocator.bookingDraft.setService({'duration': '60 min', 'price': 50});
    ServicesLocator.bookingDraft.setDate(DateTime(2026, 8, 10)); // Monday
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

  testWidgets('Groomer Display handles missing image gracefully', (WidgetTester tester) async {
    final storeRepo = ServicesLocator.storeRepository as MockStoreRepository;
    storeRepo.mockGroomers = [
      {
        "GroomerId": "G001",
        "FirstName": "Merisa",
        "LastName": "Brown",
        "Role": "Lead Groomer"
      } // No image
    ];

    await pumpPage(tester);

    // Verify "ANY" option is present
    expect(find.text('ANY'), findsOneWidget);
    expect(find.text('No Pref'), findsOneWidget);

    // Verify Merisa is present
    expect(find.text('Merisa Brown'), findsOneWidget);
    expect(find.text('M'), findsOneWidget); // Initial

    // Verify selecting groomer updates draft
    final groomerFinder = find.text('Merisa Brown');
    await tester.ensureVisible(groomerFinder);
    await tester.tap(groomerFinder);
    await tester.pumpAndSettle();

    expect(ServicesLocator.bookingDraft.groomer, isNotNull);
    expect(ServicesLocator.bookingDraft.groomer!['id'], 'G001');
    expect(ServicesLocator.bookingDraft.groomer!['name'], 'Merisa Brown');
  });

  testWidgets('Groomer Display renders image when available', (WidgetTester tester) async {
    final storeRepo = ServicesLocator.storeRepository as MockStoreRepository;
    storeRepo.mockGroomers = [
      {
        "GroomerId": "G002",
        "FirstName": "Richard",
        "LastName": "Cooke",
        "Role": "Senior Groomer",
        "image": "assets/images/group2.png" // Assume this local asset exists
      }
    ];

    await pumpPage(tester);

    expect(find.text('Richard Cooke'), findsOneWidget);
    expect(find.text('R'), findsOneWidget); // Initial
  });
}
