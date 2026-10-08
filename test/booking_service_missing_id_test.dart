import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/booking_service_page.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';
import 'package:go_router/go_router.dart';

class MockServiceRepository extends ServiceRepository {
  bool shouldThrowDioError = false;
  int dioErrorStatusCode = 400;
  bool isCalled = false;

  @override
  Future<BookingServicesResult> getBookingServices() async {
    final session = ServicesLocator.sessionService;
    if (session.clientId == null || session.regionId == null || session.storeId == null) {
      throw Exception('missing_identifiers: Store information is unavailable.');
    }
    isCalled = true;
    if (shouldThrowDioError) {
      throw DioException(
        requestOptions: RequestOptions(path: '/'),
        response: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: dioErrorStatusCode,
        ),
      );
    }
    return BookingServicesResult(
      breeds  : [
        ServiceItem(
          id: 1, isPackage: false, isAddOn: false,
          name: 'Poodle — Grooming', description: 'Grooming for Poodle',
          price: 50, priceDisplay: r'$50', durationMinutes: 60,
        ),
      ],
      packages: [
        ServiceItem(
          id: 2, isPackage: true, isAddOn: false,
          name: 'Bath', description: 'Bath package',
          price: 30, priceDisplay: r'$30', durationMinutes: 30,
        ),
      ],
      addOns  : [
        ServiceItem(
          id: 3, isPackage: false, isAddOn: true,
          name: 'Nail Trim', description: 'Nail trimming add-on',
          price: 10, priceDisplay: r'$10', durationMinutes: 10,
        ),
      ],
      walkIn  : [],
    );
  }
}

void main() {
  late SessionService sessionService;
  late MockServiceRepository mockServiceRepo;
  late BookingDraft draft;
  late ApiRepository apiRepo;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    GetIt.instance.allowReassignment = true;

    sessionService = SessionService();
    await sessionService.initialize();
    GetIt.instance.registerSingleton<SessionService>(sessionService);

    apiRepo = ApiRepository();
    await apiRepo.initialize();
    GetIt.instance.registerSingleton<ApiRepository>(apiRepo);

    mockServiceRepo = MockServiceRepository();
    GetIt.instance.registerSingleton<ServiceRepository>(mockServiceRepo);

    draft = BookingDraft();
    draft.setPet({'id': 1, 'name': 'Buddy'});
    GetIt.instance.registerSingleton<BookingDraft>(draft);
  });

  Widget buildTestApp() {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const BookingServicePage(),
        ),
      ],
    );
    return MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => ResponsiveBreakpoints(
        breakpoints: const [
          Breakpoint(start: 0, end: 450, name: MOBILE),
          Breakpoint(start: 451, end: 800, name: TABLET),
          Breakpoint(start: 801, end: 1920, name: DESKTOP),
        ],
        child: child!,
      ),
    );
  }

  group('BookingServicePage Missing IDs & Retry Tests', () {
    testWidgets('1. Client ID missing shows friendly error, no crash', (tester) async {
      await sessionService.saveRegionId('region_1');
      await sessionService.saveStoreId('store_1');

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Unable to load services'), findsOneWidget);
      expect(find.text('Store information is unavailable.\nPlease try again.'), findsOneWidget);
      expect(mockServiceRepo.isCalled, isFalse);
    });

    testWidgets('2. Region ID missing shows friendly error, no crash', (tester) async {
      await sessionService.saveClientId('client_1');
      await sessionService.saveStoreId('store_1');

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Unable to load services'), findsOneWidget);
      expect(find.text('Store information is unavailable.\nPlease try again.'), findsOneWidget);
      expect(mockServiceRepo.isCalled, isFalse);
    });

    testWidgets('3. Store ID missing shows friendly error, no crash', (tester) async {
      await sessionService.saveClientId('client_1');
      await sessionService.saveRegionId('region_1');

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Unable to load services'), findsOneWidget);
      expect(find.text('Store information is unavailable.\nPlease try again.'), findsOneWidget);
      expect(mockServiceRepo.isCalled, isFalse);
    });

    testWidgets('4. All three IDs missing shows friendly error, no crash', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Unable to load services'), findsOneWidget);
      expect(find.text('Store information is unavailable.\nPlease try again.'), findsOneWidget);
      expect(mockServiceRepo.isCalled, isFalse);
    });

    testWidgets('5. Valid IDs -> normal API flow continues', (tester) async {
      await sessionService.saveClientId('client_1');
      await sessionService.saveRegionId('region_1');
      await sessionService.saveStoreId('store_1');

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Unable to load services'), findsNothing);
      expect(mockServiceRepo.isCalled, isTrue);
      expect(find.text('Poodle — Grooming'), findsOneWidget);
    });

    testWidgets('6. Invalid API response (400) -> friendly error state', (tester) async {
      await sessionService.saveClientId('client_1');
      await sessionService.saveRegionId('region_1');
      await sessionService.saveStoreId('store_1');

      mockServiceRepo.shouldThrowDioError = true;
      mockServiceRepo.dioErrorStatusCode = 400;

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Unable to load services'), findsOneWidget);
      expect(mockServiceRepo.isCalled, isTrue);
    });

    testWidgets('Invalid API response (500) -> generic error state', (tester) async {
      await sessionService.saveClientId('client_1');
      await sessionService.saveRegionId('region_1');
      await sessionService.saveStoreId('store_1');

      mockServiceRepo.shouldThrowDioError = true;
      mockServiceRepo.dioErrorStatusCode = 500;

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Unable to load services'), findsOneWidget);
      expect(mockServiceRepo.isCalled, isTrue);
    });

    testWidgets('7. Retry after IDs become available -> API request succeeds', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Unable to load services'), findsOneWidget);
      expect(mockServiceRepo.isCalled, isFalse);

      await sessionService.saveClientId('client_1');
      await sessionService.saveRegionId('region_1');
      await sessionService.saveStoreId('store_1');

      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.text('Unable to load services'), findsNothing);
      expect(mockServiceRepo.isCalled, isTrue);
      expect(find.text('Poodle — Grooming'), findsOneWidget);
    });

    testWidgets('8. Retry while IDs remain missing -> error state remains', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Unable to load services'), findsOneWidget);
      expect(mockServiceRepo.isCalled, isFalse);

      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.text('Unable to load services'), findsOneWidget);
      expect(mockServiceRepo.isCalled, isFalse);
    });
  });
}
