import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/bookings/repo/booking_repository.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/booking_review_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/offers/bloc/offer_bloc.dart';
import 'package:shear_heaven_pet_spa/src/offers/repo/offer_repository.dart';
import 'package:shear_heaven_pet_spa/src/pets/repo/pet_repository.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';
import 'package:shear_heaven_pet_spa/src/store/repositories/store_repository.dart';

class _CapturingApiRepository extends ApiRepository {
  final List<Map<String, dynamic>> postCalls = [];

  int mockDurationMinutes = 60;

  @override
  Future<Map<String, dynamic>?> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/api/offers') {
      return {'success': true, 'data': []};
    } else if (path == '/api/holidays') {
      return {'success': true, 'data': {'HolidayList': []}};
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> post(String path, Map<String, dynamic> data) async {
    postCalls.add({'path': path, 'data': Map<String, dynamic>.from(data)});

    if (path == '/api/availability') {
      return {
        'success': true,
        'message': 'Availability retrieved successfully',
        'data': {
          'totalDurationMinutes': mockDurationMinutes,
          'totalPrice': 80.0,
          'availableSlots': [
            {
              'startTime': '10:00',
              'endTime': '11:00',
              'groomerId': 1,
              'groomerName': 'Alex',
              'bookingCount': 0,
              'maxBookings': 2,
              'isAvailable': true,
            }
          ]
        }
      };
    }

    if (path == '/api/bookings') {
      return {
        'success': true,
        'message': 'Booking created successfully',
        'data': {
          'id': 999,
          'bookingId': 999,
          'status': 'pending',
        }
      };
    }

    return {'success': true};
  }
}

class _DummyPetRepository extends PetRepository {
  @override
  Future<List<Map<String, dynamic>>> getAllPets({int? userId}) async => [];
}

class _DummyServiceRepository extends ServiceRepository {
  @override
  Future<BookingServicesResult> getBookingServices() async => BookingServicesResult(
        breeds: [],
        packages: [],
        addOns: [],
        walkIn: [],
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookingDraft draft;
  late OfferRepository offerRepo;
  late _CapturingApiRepository apiRepo;
  late BookingRepository bookingRepo;

  final testDate = DateTime.now().add(const Duration(days: 2));
  final testDateStr = DateFormat('yyyy-MM-dd').format(testDate);

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    final session = SessionService();
    await session.initialize();
    await session.saveClientId('SHEAR-001');
    await session.saveRegionId('DWG-001');
    await session.saveStoreId('SHEAR-001');
    await session.saveSession({'id': 1, 'email': 'cupretrahuddo-2377@yopmail.com'});

    apiRepo = _CapturingApiRepository();
    await apiRepo.initialize();

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<SessionService>(session);
    GetIt.I.registerSingleton<ApiRepository>(apiRepo);

    offerRepo = OfferRepository();
    await offerRepo.initialize();
    GetIt.I.registerSingleton<OfferRepository>(offerRepo);

    draft = BookingDraft();
    GetIt.I.registerSingleton<BookingDraft>(draft);

    GetIt.I.registerSingleton<StoreRepository>(StoreRepository());

    bookingRepo = BookingRepository();
    GetIt.I.registerSingleton<BookingRepository>(bookingRepo);

    GetIt.I.registerSingleton<PetRepository>(_DummyPetRepository());
    GetIt.I.registerSingleton<ServiceRepository>(_DummyServiceRepository());
  });

  tearDown(() {
    draft.reset();
  });

  group('Package vs Service Payload & Duration Tests', () {
    test('BookingRepository.getAvailability sends packageId and omits serviceId for packages', () async {
      await bookingRepo.getAvailability(
        date: testDateStr,
        packageId: 1,
        petId: 2,
      );

      expect(apiRepo.postCalls, isNotEmpty);
      final availCall = apiRepo.postCalls.firstWhere((c) => c['path'] == '/api/availability');
      final data = availCall['data'] as Map<String, dynamic>;

      expect(data['packageId'], equals(1));
      expect(data.containsKey('serviceId'), isFalse);
      expect(data['petId'], equals(2));
      expect(data['date'], equals(testDateStr));
    });

    test('BookingRepository.getAvailability sends serviceId and omits packageId for services', () async {
      await bookingRepo.getAvailability(
        date: testDateStr,
        serviceId: 5,
        petId: 2,
      );

      final availCall = apiRepo.postCalls.lastWhere((c) => c['path'] == '/api/availability');
      final data = availCall['data'] as Map<String, dynamic>;

      expect(data['serviceId'], equals(5));
      expect(data.containsKey('packageId'), isFalse);
      expect(data['petId'], equals(2));
      expect(data['date'], equals(testDateStr));
    });

    test('BookingDraft.extractServiceIds isolates packageId from serviceId', () {
      draft.setService({'id': 1, 'package_name': 'Special Package', 'name': 'Special Package', 'isPackage': true});
      final ids = draft.extractServiceIds();
      expect(ids['packageId'], equals(1));
      expect(ids['serviceId'], isNull);

      draft.setService({'id': 3, 'service_name': 'Full Grooming', 'name': 'Full Grooming', 'isPackage': false});
      final ids2 = draft.extractServiceIds();
      expect(ids2['serviceId'], equals(3));
      expect(ids2['packageId'], isNull);
    });

    testWidgets('Special Package calculates endTime dynamically from package duration (60m) and sends packageId: 1', (tester) async {
      apiRepo.mockDurationMinutes = 60; // Package duration: 60 min

      draft.setPet({'id': 2, 'pet_name': 'Buddy', 'breed': 'Poodle', 'weight': 'Small'});
      draft.setService({'id': 1, 'package_name': 'Special Package', 'name': 'Special Package', 'isPackage': true, 'price': 80.0});
      draft.setDate(testDate);
      draft.setSelectedSlot({
        'startTime': '10:00',
        'endTime': '11:00', // 60 min
        'groomerId': 1,
        'groomerName': 'Alex',
      });
      draft.apiTotalPrice = 80.0;
      draft.apiDurationMinutes = 60;

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<OfferBloc>(
            create: (_) => OfferBloc(repository: offerRepo),
            child: const BookingReviewPageMobile(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Confirm Booking
      final confirmBtn = find.text('Confirm Booking');
      expect(confirmBtn, findsOneWidget);
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Check the POST /api/bookings call
      final bookingCall = apiRepo.postCalls.firstWhere(
        (c) => c['path'] == '/api/bookings',
        orElse: () => throw StateError('No /api/bookings call made'),
      );
      final bookingPayload = bookingCall['data'] as Map<String, dynamic>;

      expect(bookingPayload['packageId'], equals(1));
      expect(bookingPayload.containsKey('serviceId'), isFalse);
      expect(bookingPayload['startTime'], equals('10:00'));
      expect(bookingPayload['endTime'], equals('11:00'));
      expect(bookingPayload['petId'], equals(2));
    });

    testWidgets('Custom duration recalculates endTime (e.g. 75m => 10:00 to 11:15)', (tester) async {
      apiRepo.mockDurationMinutes = 75; // 75 minutes

      draft.setPet({'id': 2, 'pet_name': 'Buddy', 'breed': 'Poodle', 'weight': 'Small'});
      draft.setService({'id': 1, 'service_name': 'Full Grooming', 'name': 'Full Grooming', 'isPackage': false, 'price': 95.0});
      draft.setDate(testDate);
      draft.setSelectedSlot({
        'startTime': '10:00',
        'endTime': '10:30', // stale draft endTime that should be corrected
        'groomerId': 1,
        'groomerName': 'Alex',
      });
      draft.apiTotalPrice = 95.0;

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<OfferBloc>(
            create: (_) => OfferBloc(repository: offerRepo),
            child: const BookingReviewPageMobile(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final confirmBtn = find.text('Confirm Booking');
      expect(confirmBtn, findsOneWidget);
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      final bookingCall = apiRepo.postCalls.firstWhere(
        (c) => c['path'] == '/api/bookings',
        orElse: () => throw StateError('No /api/bookings call made'),
      );
      final bookingPayload = bookingCall['data'] as Map<String, dynamic>;

      expect(bookingPayload['serviceId'], equals(1));
      expect(bookingPayload.containsKey('packageId'), isFalse);
      expect(bookingPayload['startTime'], equals('10:00'));
      // Must be recalculated to 11:15 based on the 75 minutes
      expect(bookingPayload['endTime'], equals('11:15'));
      expect(bookingPayload['petId'], equals(2));
    });
  });
}
