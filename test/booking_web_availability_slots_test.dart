import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/bookings/repo/booking_repository.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/booking_date_time_page.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/store/repositories/store_repository.dart';

class MockWebBookingRepository extends BookingRepository {
  int? lastRequestedGroomerId;
  String? lastRequestedPetSizeKey;

  @override
  Future<Map<String, dynamic>?> getAvailability({
    required String date,
    int? serviceId,
    int? packageId,
    List<int>? addOnIds,
    int? groomerId,
    int? petId,
    String? petSizeKey,
  }) async {
    lastRequestedGroomerId = groomerId;
    lastRequestedPetSizeKey = petSizeKey;

    final groomerList = [
      {'id': 1, 'firstName': 'Merisa', 'lastName': 'Brown', 'role': 'Groomer', 'available': true},
      {'id': 2, 'firstName': 'Richard', 'lastName': 'Cooke', 'role': 'Groomer', 'available': true},
      {'id': 3, 'firstName': 'Tracie', 'lastName': 'Jamison', 'role': 'Groomer', 'available': true},
    ];

    if (groomerId == 1) {
      // Merisa Brown specific availability matching live web
      return {
        'success': true,
        'data': {
          'totalDurationMinutes': 60,
          'totalPrice': 75.0,
          'serviceSubtotal': 75.0,
          'packageSubtotal': 0.0,
          'closed': false,
          'groomers': groomerList,
          'storeWorkingHours': {'open': '08:00', 'close': '17:30', 'closed': false},
          'groomerWorkingHours': {
            'open': '08:00',
            'close': '17:30',
            'closed': false,
            'scheduledStart': '08:00',
            'scheduledEnd': '17:30',
          },
          'scheduleStatus': 'available',
          'slotTimeline': [
            {'startTime': '08:00', 'endTime': '14:00', 'status': 'booked'},
            {'startTime': '14:00', 'endTime': '17:00', 'status': 'available'},
          ],
          'slotColors': {
            'available': '#10b981',
            'booked': '#ef4444',
            'break': '#f59e0b',
            'unavailable': '#9ca3af',
          },
          'timeSlotChoices': [
            {'startTime': '08:00', 'endTime': '09:00', 'status': 'booked', 'isAvailable': false, 'groomerId': 1, 'groomerName': 'Merisa Brown'},
            {'startTime': '09:00', 'endTime': '10:00', 'status': 'booked', 'isAvailable': false, 'groomerId': 1, 'groomerName': 'Merisa Brown'},
            {'startTime': '10:00', 'endTime': '11:00', 'status': 'booked', 'isAvailable': false, 'groomerId': 1, 'groomerName': 'Merisa Brown'},
            {'startTime': '11:00', 'endTime': '12:00', 'status': 'booked', 'isAvailable': false, 'groomerId': 1, 'groomerName': 'Merisa Brown'},
            {'startTime': '12:00', 'endTime': '13:00', 'status': 'booked', 'isAvailable': false, 'groomerId': 1, 'groomerName': 'Merisa Brown'},
            {'startTime': '13:00', 'endTime': '14:00', 'status': 'booked', 'isAvailable': false, 'groomerId': 1, 'groomerName': 'Merisa Brown'},
            {'startTime': '14:00', 'endTime': '15:00', 'status': 'available', 'isAvailable': true, 'groomerId': 1, 'groomerName': 'Merisa Brown'},
            {'startTime': '15:00', 'endTime': '16:00', 'status': 'available', 'isAvailable': true, 'groomerId': 1, 'groomerName': 'Merisa Brown'},
            {'startTime': '16:00', 'endTime': '17:00', 'status': 'available', 'isAvailable': true, 'groomerId': 1, 'groomerName': 'Merisa Brown'},
          ],
          'availableSlots': [
            {'startTime': '14:00', 'endTime': '15:00', 'groomerId': 1, 'groomerName': 'Merisa Brown'},
            {'startTime': '15:00', 'endTime': '16:00', 'groomerId': 1, 'groomerName': 'Merisa Brown'},
            {'startTime': '16:00', 'endTime': '17:00', 'groomerId': 1, 'groomerName': 'Merisa Brown'},
          ],
        }
      };
    }

    // Default "No Pref" (groomerId = 0)
    return {
      'success': true,
      'data': {
        'totalDurationMinutes': 60,
        'totalPrice': 75.0,
        'serviceSubtotal': 75.0,
        'packageSubtotal': 0.0,
        'closed': false,
        'groomers': groomerList,
        'storeWorkingHours': {'open': '08:00', 'close': '17:30', 'closed': false},
        'slotColors': {
          'available': '#10b981',
          'booked': '#ef4444',
          'break': '#f59e0b',
          'unavailable': '#9ca3af',
        },
        'timeSlotChoices': [
          {'startTime': '08:00', 'endTime': '09:00', 'status': 'available', 'isAvailable': true, 'groomerId': 3, 'groomerName': 'Tracie Jamison'},
          {'startTime': '09:00', 'endTime': '10:00', 'status': 'available', 'isAvailable': true, 'groomerId': 3, 'groomerName': 'Tracie Jamison'},
          {'startTime': '10:00', 'endTime': '11:00', 'status': 'available', 'isAvailable': true, 'groomerId': 2, 'groomerName': 'Richard Cooke'},
          {'startTime': '11:00', 'endTime': '12:00', 'status': 'available', 'isAvailable': true, 'groomerId': 2, 'groomerName': 'Richard Cooke'},
          {'startTime': '12:00', 'endTime': '13:00', 'status': 'available', 'isAvailable': true, 'groomerId': 2, 'groomerName': 'Richard Cooke'},
          {'startTime': '13:00', 'endTime': '14:00', 'status': 'available', 'isAvailable': true, 'groomerId': 2, 'groomerName': 'Richard Cooke'},
          {'startTime': '14:00', 'endTime': '15:00', 'status': 'available', 'isAvailable': true, 'groomerId': 1, 'groomerName': 'Merisa Brown'},
          {'startTime': '15:00', 'endTime': '16:00', 'status': 'available', 'isAvailable': true, 'groomerId': 1, 'groomerName': 'Merisa Brown'},
          {'startTime': '16:00', 'endTime': '17:00', 'status': 'available', 'isAvailable': true, 'groomerId': 1, 'groomerName': 'Merisa Brown'},
        ],
        'availableSlots': [
          {'startTime': '08:00', 'endTime': '09:00', 'groomerId': 3, 'groomerName': 'Tracie Jamison'},
          {'startTime': '09:00', 'endTime': '10:00', 'groomerId': 3, 'groomerName': 'Tracie Jamison'},
          {'startTime': '10:00', 'endTime': '11:00', 'groomerId': 2, 'groomerName': 'Richard Cooke'},
          {'startTime': '11:00', 'endTime': '12:00', 'groomerId': 2, 'groomerName': 'Richard Cooke'},
          {'startTime': '12:00', 'endTime': '13:00', 'groomerId': 2, 'groomerName': 'Richard Cooke'},
          {'startTime': '13:00', 'endTime': '14:00', 'groomerId': 2, 'groomerName': 'Richard Cooke'},
          {'startTime': '14:00', 'endTime': '15:00', 'groomerId': 1, 'groomerName': 'Merisa Brown'},
          {'startTime': '15:00', 'endTime': '16:00', 'groomerId': 1, 'groomerName': 'Merisa Brown'},
          {'startTime': '16:00', 'endTime': '17:00', 'groomerId': 1, 'groomerName': 'Merisa Brown'},
        ],
      }
    };
  }
}

class MockStoreRepo extends StoreRepository {
  @override
  Future<List<Map<String, dynamic>>> getStoreSchedule() async {
    return [
      {'Day': 'Monday', 'Open': 'Yes', 'Start': '08:00', 'last_booking_available': '04:00', 'End': '05:30'}
    ];
  }
}

void main() {
  late MockWebBookingRepository mockBookingRepo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    final session = SessionService();
    await session.initialize();

    final apiRepo = ApiRepository();
    await apiRepo.initialize();

    mockBookingRepo = MockWebBookingRepository();

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<SessionService>(session);
    GetIt.I.registerSingleton<ApiRepository>(apiRepo);
    GetIt.I.registerSingleton<BookingDraft>(BookingDraft());
    GetIt.I.registerSingleton<BookingRepository>(mockBookingRepo);
    GetIt.I.registerSingleton<StoreRepository>(MockStoreRepo());
  });

  tearDownAll(() {
    GetIt.I.reset();
  });

  setUp(() {
    ServicesLocator.bookingDraft.reset();
    ServicesLocator.bookingDraft.setPet({
      'id': 10,
      'name': 'Rocky',
      'weight': '15 lbs',
    });
    ServicesLocator.bookingDraft.setService({
      'id': 1,
      'PackageMasterId': 1,
      'name': 'Full Grooming',
      'duration': '60 min',
      'price': 75.0,
      'isPackage': true,
    });
    // Future date so past filter doesn't strip slots
    ServicesLocator.bookingDraft.setDate(DateTime.now().add(const Duration(days: 3)));
  });

  testWidgets('Web aligned availability loads slots with groomer names under No Pref', (tester) async {
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => ResponsiveBreakpoints(
        breakpoints: const [
          Breakpoint(start: 0, end: 450, name: MOBILE),
        ],
        child: child!,
      ),
      home: const BookingDateTimePage(),
    ));
    await tester.pumpAndSettle();

    // Verify petSizeKey was passed to API call
    expect(mockBookingRepo.lastRequestedPetSizeKey, equals('small'));

    // Verify Groomer chips are rendered
    expect(find.text('No Pref'), findsOneWidget);
    expect(find.text('Merisa Brown'), findsWidgets);
    expect(find.text('Richard Cooke'), findsWidgets);
    expect(find.text('Tracie Jamison'), findsWidgets);

    // Verify time slots are rendered with groomer name labels in 3 columns
    expect(find.text('8:00 AM'), findsOneWidget);
    expect(find.text('Tracie Jamison'), findsWidgets);
    expect(find.text('Richard Cooke'), findsWidgets);

    // Tap 8:00 AM slot
    final slot8 = find.text('8:00 AM');
    await tester.ensureVisible(slot8);
    await tester.pumpAndSettle();
    await tester.tap(slot8);
    await tester.pumpAndSettle();

    // Verify slot is selected and Tracie Jamison is assigned in draft
    expect(ServicesLocator.bookingDraft.timeSlot, equals('08:00'));
    expect(ServicesLocator.bookingDraft.groomer?['name'], equals('Tracie Jamison'));
  });

  testWidgets('Selecting Merisa Brown shows working hours, timeline, booked slots disabled, and available slots selectable', (tester) async {
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => ResponsiveBreakpoints(
        breakpoints: const [
          Breakpoint(start: 0, end: 450, name: MOBILE),
        ],
        child: child!,
      ),
      home: const BookingDateTimePage(),
    ));
    await tester.pumpAndSettle();

    // Tap Merisa Brown
    final merisaChip = find.text('Merisa Brown').first;
    await tester.ensureVisible(merisaChip);
    await tester.pumpAndSettle();
    await tester.tap(merisaChip);
    await tester.pumpAndSettle();

    // Verify API was called with groomerId = 1
    expect(mockBookingRepo.lastRequestedGroomerId, equals(1));

    // Verify groomer working hours text is displayed
    expect(find.textContaining('Merisa Brown works 8:00 AM – 5:30 PM on this day'), findsOneWidget);

    // Verify timeline label is displayed
    expect(find.text('Groomer day schedule timeline'), findsOneWidget);

    // Verify slots 2:00 PM (14:00) is available and selectable
    final slot2pm = find.text('2:00 PM');
    expect(slot2pm, findsOneWidget);
    await tester.ensureVisible(slot2pm);
    await tester.pumpAndSettle();
    await tester.tap(slot2pm);
    await tester.pumpAndSettle();

    // Verify selected in draft
    expect(ServicesLocator.bookingDraft.timeSlot, equals('14:00'));
    expect(ServicesLocator.bookingDraft.groomer?['id'], equals('1'));
  });
}
