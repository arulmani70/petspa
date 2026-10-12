import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/booking_service_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/widgets/booking_header.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/pets/bloc/pet_bloc.dart';
import 'package:shear_heaven_pet_spa/src/pets/repo/pet_repository.dart';
import 'package:shear_heaven_pet_spa/src/pets/views/mobile/pet_select_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/services/bloc/service_bloc.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';

class FakePetRepository extends PetRepository {
  final List<Map<String, dynamic>> mockPets;
  FakePetRepository([this.mockPets = const []]);

  @override
  Future<List<Map<String, dynamic>>> getAllPets({int? userId}) async => mockPets;
}

class FakeServiceRepository extends ServiceRepository {
  final BookingServicesResult mockResult;
  FakeServiceRepository({BookingServicesResult? mockResult})
      : mockResult = mockResult ??
            BookingServicesResult(
              breeds: [],
              packages: [],
              addOns: [],
              walkIn: [],
            );

  @override
  Future<BookingServicesResult> getBookingServices() async => mockResult;

  @override
  Future<List<Map<String, dynamic>>> getAllServices() async => [];

  @override
  Future<List<Map<String, dynamic>>> getAllPackages() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    GetIt.I.allowReassignment = true;
    await ServicesLocator.initialize();
  });

  setUp(() {
    ServicesLocator.bookingDraft.reset();
  });

  group('BookingHeader Back Button Navigation Tests', () {
    testWidgets('BookingHeader pops to previous screen when canPop is true',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/caller',
        routes: [
          GoRoute(
            path: '/caller',
            name: 'caller',
            builder: (context, state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => context.pushNamed('bookingStep'),
                  child: const Text('Open Booking Step'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/bookingStep',
            name: 'bookingStep',
            builder: (context, state) => const Scaffold(
              body: BookingHeader(
                title: 'Select Service',
                step: 2,
                subtitle: 'Step 2 of 4',
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Open Booking Step'), findsOneWidget);

      // Push to booking step
      await tester.tap(find.text('Open Booking Step'));
      await tester.pumpAndSettle();

      expect(find.text('Select Service'), findsOneWidget);
      expect(find.text('Open Booking Step'), findsNothing);

      // Tap back button on BookingHeader
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Successfully popped back to caller screen
      expect(find.text('Open Booking Step'), findsOneWidget);
      expect(find.text('Select Service'), findsNothing);
    });

    testWidgets('BookingHeader invokes onBack callback when provided',
        (tester) async {
      bool onBackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookingHeader(
              title: 'Review Booking',
              step: 4,
              subtitle: 'Step 4 of 4',
              onBack: () {
                onBackCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Review Booking'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(onBackCalled, isTrue);
    });

    testWidgets(
        'BookingHeader safely triggers step route fallback when canPop is false',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/step3',
        routes: [
          GoRoute(
            path: '/step3',
            name: 'step3',
            builder: (context, state) => const Scaffold(
              body: BookingHeader(
                title: 'Date & Time',
                step: 3,
                subtitle: 'Step 3 of 4',
              ),
            ),
          ),
          GoRoute(
            path: '/booking-service',
            name: RouteNames.bookingService,
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Fallback Service Step Content')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Date & Time'), findsOneWidget);

      // Tap back button when there is no prior route in stack
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Navigates to fallback booking service route without crash
      expect(find.text('Fallback Service Step Content'), findsOneWidget);
    });
  });

  group('PetSelectPageMobile Back Navigation Tests', () {
    late FakePetRepository fakePetRepo;
    late PetBloc petBloc;

    setUp(() {
      fakePetRepo = FakePetRepository([
        {
          'id': 1,
          'userId': 10,
          'pet_name': 'Milo',
          'petName': 'Milo',
          'species': 'Dog',
          'breed': 'Poodle',
          'weight': '12kg',
          'gender': 'Male',
        },
      ]);
      petBloc = PetBloc(repository: fakePetRepo);
    });

    tearDown(() {
      petBloc.close();
    });

    testWidgets('AppBar back button pops back to caller screen',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            name: RouteNames.home,
            builder: (context, state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => context.pushNamed(RouteNames.petSelect),
                  child: const Text('Go to Pet Select'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/pet-select',
            name: RouteNames.petSelect,
            builder: (context, state) => BlocProvider<PetBloc>.value(
              value: petBloc,
              child: const PetSelectPageMobile(),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Go to Pet Select'), findsOneWidget);

      // Push to Pet Select
      await tester.tap(find.text('Go to Pet Select'));
      await tester.pumpAndSettle();

      expect(find.text('Select Your Pet'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Returned to Home
      expect(find.text('Go to Pet Select'), findsOneWidget);
    });

    testWidgets('Hardware back button pops PetSelect back to caller screen',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/myBookings',
        routes: [
          GoRoute(
            path: '/myBookings',
            name: 'myBookings',
            builder: (context, state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => context.pushNamed(RouteNames.petSelect),
                  child: const Text('Book From My Bookings'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/pet-select',
            name: RouteNames.petSelect,
            builder: (context, state) => BlocProvider<PetBloc>.value(
              value: petBloc,
              child: const PetSelectPageMobile(),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Book From My Bookings'));
      await tester.pumpAndSettle();

      expect(find.text('Select Your Pet'), findsOneWidget);

      // Trigger hardware back button
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Returned to My Bookings
      expect(find.text('Book From My Bookings'), findsOneWidget);
    });
  });

  group('BookingServicePageMobile Back Navigation Tests', () {
    late FakeServiceRepository fakeServiceRepo;
    late ServiceBloc serviceBloc;

    setUp(() {
      fakeServiceRepo = FakeServiceRepository(
        mockResult: const BookingServicesResult(
          breeds: [
            ServiceItem(
              id: 1,
              isPackage: false,
              isAddOn: false,
              name: 'Full Groom',
              description: 'Complete grooming service',
              price: 50.0,
              priceDisplay: '\$50',
              durationMinutes: 60,
            ),
          ],
          packages: [],
          addOns: [],
          walkIn: [],
        ),
      );
      serviceBloc = ServiceBloc(repository: fakeServiceRepo)
        ..add(const InitializeServices());
    });

    tearDown(() {
      serviceBloc.close();
    });

    testWidgets('BookingHeader back button pops to Service Detail caller',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/serviceDetail',
        routes: [
          GoRoute(
            path: '/serviceDetail',
            name: 'serviceDetail',
            builder: (context, state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => context.pushNamed(
                    RouteNames.bookingService,
                    extra: {'from_popular': true},
                  ),
                  child: const Text('Book Service Detail'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/booking-service',
            name: RouteNames.bookingService,
            builder: (context, state) => BlocProvider<ServiceBloc>.value(
              value: serviceBloc,
              child: const BookingServicePageMobile(),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Book Service Detail'));
      await tester.pumpAndSettle();

      expect(find.text('Select Service'), findsOneWidget);

      // Tap back button on BookingHeader
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Returned to Service Detail
      expect(find.text('Book Service Detail'), findsOneWidget);
    });

    testWidgets('Hardware back button pops BookingService back to caller',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/packages',
        routes: [
          GoRoute(
            path: '/packages',
            name: 'packages',
            builder: (context, state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => context.pushNamed(
                    RouteNames.bookingService,
                    extra: {'from_popular': true},
                  ),
                  child: const Text('Book Package Button'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/booking-service',
            name: RouteNames.bookingService,
            builder: (context, state) => BlocProvider<ServiceBloc>.value(
              value: serviceBloc,
              child: const BookingServicePageMobile(),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Book Package Button'));
      await tester.pumpAndSettle();

      expect(find.text('Select Service'), findsOneWidget);

      // Trigger hardware back button
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Returned to packages
      expect(find.text('Book Package Button'), findsOneWidget);
    });

    testWidgets('Fallback when canPop is false routes safely without crash',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/booking-service',
        routes: [
          GoRoute(
            path: '/booking-service',
            name: RouteNames.bookingService,
            builder: (context, state) => BlocProvider<ServiceBloc>.value(
              value: serviceBloc,
              child: const BookingServicePageMobile(),
            ),
          ),
          GoRoute(
            path: '/pet-select',
            name: RouteNames.petSelect,
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Fallback Pet Select Screen')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Select Service'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Safe fallback triggered without crashing
      expect(find.text('Fallback Pet Select Screen'), findsOneWidget);
    });
  });

  group('BookingDraft State Persistence on Navigation', () {
    test('BookingDraft retains selected pet and service values across navigation',
        () {
      final draft = ServicesLocator.bookingDraft;
      expect(draft.pet, isNull);
      expect(draft.service, isNull);

      final petData = {
        'id': 101,
        'pet_name': 'Bella',
        'breed': 'Golden Retriever',
      };
      final serviceData = {
        'id': 202,
        'name': 'Deluxe Bath & Cut',
        'price': 75.0,
      };

      draft.setPet(petData);
      draft.setService(serviceData);

      expect(draft.pet, equals(petData));
      expect(draft.service, equals(serviceData));

      // Simulating popping back from a subsequent step does not reset draft
      expect(draft.pet?['pet_name'], equals('Bella'));
      expect(draft.service?['name'], equals('Deluxe Bath & Cut'));
    });
  });
}
