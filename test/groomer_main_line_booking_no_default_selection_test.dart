import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/bloc/groomer_home_bloc.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/customer_summary.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_user.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/repo/groomer_home_repository.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/main_line_booking_dialog.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';

class _FakeBookingRepository extends GroomerHomeRepository {
  final List<CustomerSummary> mockCustomers;
  final List<CustomerPetSummary> mockPets;
  final List<SalonGroomer> mockGroomers;
  final List<ServiceItem> mockServices;
  final List<ServiceItem> mockPackages;
  int availabilityCheckCount = 0;
  int? lastServiceId;
  int? lastPackageId;

  _FakeBookingRepository({
    required this.mockCustomers,
    required this.mockPets,
    required this.mockGroomers,
    required this.mockServices,
    required this.mockPackages,
  });

  @override
  Future<List<CustomerSummary>> searchCustomers({
    String? query,
    int page = 1,
    int limit = 50,
    int offset = 0,
  }) async {
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      return mockCustomers.where((c) =>
        c.name.toLowerCase().contains(q) ||
        (c.phone != null && c.phone!.contains(q)) ||
        (c.email != null && c.email!.toLowerCase().contains(q))
      ).toList();
    }
    return mockCustomers;
  }

  @override
  Future<List<CustomerPetSummary>> getCustomerPets(int userId) async =>
      mockPets.where((p) => p.userId == userId).toList();

  @override
  Future<List<SalonGroomer>> getSalonGroomers() async => mockGroomers;

  @override
  Future<BookingServicesResult> getBookingServices() async => BookingServicesResult(
        breeds: mockServices,
        packages: mockPackages,
        addOns: const [],
        walkIn: const [],
      );

  @override
  Future<Map<String, dynamic>?> getAvailability({
    required String date,
    int? serviceId,
    int? packageId,
    List<int>? addOnIds,
    int? groomerId,
  }) async {
    availabilityCheckCount++;
    lastServiceId = serviceId;
    lastPackageId = packageId;
    return {
      'success': true,
      'data': {
        'availableSlots': [
          {
            'startTime': '10:00:00',
            'endTime': '11:00:00',
            'groomerId': 1,
            'isAvailable': true,
            'remaining': 1,
          }
        ],
        'totalDurationMinutes': 60,
        'totalPrice': serviceId == 1 ? 60.0 : (serviceId == 2 ? 40.0 : 100.0),
      }
    };
  }

  @override
  Future<Map<String, dynamic>?> createBookingForUser({
    required int userId,
    required int petId,
    required int serviceId,
    int? packageId,
    List<int>? addOnIds,
    int? groomerId,
    required String bookingDate,
    required String startTime,
    required String endTime,
    String? clientId,
    String? regionId,
    String? storeId,
  }) async =>
      {
        'success': true,
        'message': 'Booking confirmed',
        'data': {'bookingId': 777}
      };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mockUser = GroomerUser(
    id: 1,
    groomerCode: 'G01',
    firstName: 'Marisa',
    lastName: 'Brown',
    email: 'marisa@example.com',
    role: 'Groomer',
  );

  final mockCustomer = CustomerSummary(id: 10, name: 'Alice Smith', email: 'alice@example.com', phone: '555-1234');
  const mockPet = CustomerPetSummary(id: 101, userId: 10, name: 'Luna', breed: 'Poodle');
  const mockGroomer = SalonGroomer(
    id: 1,
    groomerCode: 'G01',
    firstName: 'Marisa',
    lastName: 'Brown',
    name: 'Marisa Brown',
    isAvailable: true,
  );

  const List<ServiceItem> mockServices = [
    ServiceItem(
      id: 1,
      name: 'Full Body Grooming',
      description: 'Full body haircut',
      price: 60.0,
      priceDisplay: '\$60',
      durationMinutes: 60,
      isPackage: false,
      isAddOn: false,
    ),
    ServiceItem(
      id: 2,
      name: 'Bath & Brush',
      description: 'Bath and brushing',
      price: 40.0,
      priceDisplay: '\$40',
      durationMinutes: 30,
      isPackage: false,
      isAddOn: false,
    ),
  ];

  const List<ServiceItem> mockPackages = [
    ServiceItem(
      id: 101,
      name: 'Gold Spa Package',
      description: 'Full spa treatment',
      price: 100.0,
      priceDisplay: '\$100',
      durationMinutes: 90,
      isPackage: true,
      isAddOn: false,
    ),
    ServiceItem(
      id: 102,
      name: 'Puppy First Trim',
      description: 'Introductory puppy trim',
      price: 70.0,
      priceDisplay: '\$70',
      durationMinutes: 45,
      isPackage: true,
      isAddOn: false,
    ),
  ];

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  group('MainLineBookingDialog Section 4: No Default Selection & Dynamic Selection', () {
    late _FakeBookingRepository repo;
    late GroomerHomeBloc bloc;

    setUp(() {
      repo = _FakeBookingRepository(
        mockCustomers: [mockCustomer],
        mockPets: [mockPet],
        mockGroomers: [mockGroomer],
        mockServices: mockServices,
        mockPackages: mockPackages,
      );
      bloc = GroomerHomeBloc(repository: repo);
      bloc.emit(bloc.state.copyWith(
        searchedCustomers: () => [mockCustomer],
        customerPets: () => [mockPet],
        salonGroomers: () => [mockGroomer],
        bookingServices: () => mockServices,
        bookingPackages: () => mockPackages,
      ));
    });

    tearDown(() {
      bloc.close();
    });

    testWidgets('1. Neither service nor package is selected by default upon opening', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainLineBookingDialog(
              loggedInGroomer: mockUser,
              bloc: bloc,
              onBookingCreated: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger shows placeholder "Select a service"
      expect(find.text('Select a service'), findsOneWidget);

      // Summary section row shows "Not selected"
      expect(find.text('Not selected'), findsWidgets);

      // Confirm button is disabled because service/package is not selected
      final btnFinder = find.byType(ElevatedButton).last;
      final btn = tester.widget<ElevatedButton>(btnFinder);
      expect(btn.onPressed, isNull);
    });

    testWidgets('2. Switching between Services and Packages tabs does not auto-select any item', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainLineBookingDialog(
              loggedInGroomer: mockUser,
              bloc: bloc,
              onBookingCreated: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap to open the dropdown
      await tester.tap(find.text('Select a service'));
      await tester.pumpAndSettle();

      // Both tabs are visible
      expect(find.text('Services (2)'), findsOneWidget);
      expect(find.text('Packages (2)'), findsOneWidget);

      // Switch to Packages tab
      await tester.tap(find.text('Packages (2)'));
      await tester.pumpAndSettle();

      // Check packages are displayed, both with unchecked radio buttons
      expect(find.text('Gold Spa Package'), findsOneWidget);
      expect(find.text('Puppy First Trim'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsNWidgets(2));

      // Switch back to Services tab
      await tester.tap(find.text('Services (2)'));
      await tester.pumpAndSettle();

      // Check services are displayed, both with unchecked radio buttons
      expect(find.text('Full Body Grooming'), findsOneWidget);
      expect(find.text('Bath & Brush'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsNWidgets(2));
    });

    testWidgets('3. User can manually pick any service and triggers availability', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainLineBookingDialog(
              loggedInGroomer: mockUser,
              bloc: bloc,
              onBookingCreated: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dropdown
      await tester.tap(find.text('Select a service'));
      await tester.pumpAndSettle();

      // Tap the second service: "Bath & Brush"
      await tester.tap(find.text('Bath & Brush'));
      await tester.pumpAndSettle();

      // Dropdown closes and trigger header displays "Bath & Brush (30 min)"
      expect(find.text('Bath & Brush (30 min)'), findsOneWidget);
      expect(find.text('\$40'), findsWidgets);

      // Availability check was called with serviceId = 2
      expect(repo.lastServiceId, equals(2));
      expect(repo.lastPackageId, isNull);
    });

    testWidgets('4. User can switch to Packages and manually pick any package', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainLineBookingDialog(
              loggedInGroomer: mockUser,
              bloc: bloc,
              onBookingCreated: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dropdown
      await tester.tap(find.text('Select a service'));
      await tester.pumpAndSettle();

      // Switch to Packages tab
      await tester.tap(find.text('Packages (2)'));
      await tester.pumpAndSettle();

      // Tap "Gold Spa Package"
      await tester.tap(find.text('Gold Spa Package'));
      await tester.pumpAndSettle();

      // Dropdown closes and header displays "Gold Spa Package (90 min)"
      expect(find.text('Gold Spa Package (90 min)'), findsOneWidget);
      expect(find.text('\$100'), findsWidgets);

      // Availability check was called with packageId = 101
      expect(repo.lastPackageId, equals(101));
    });

    testWidgets('5. Dynamic services arrival via BLoC does not auto-select anything', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Start with empty services in bloc, but repo has services
      final dynamicBloc = GroomerHomeBloc(repository: repo);
      dynamicBloc.emit(dynamicBloc.state.copyWith(
        searchedCustomers: () => [mockCustomer],
        customerPets: () => [mockPet],
        salonGroomers: () => [mockGroomer],
        bookingServices: () => [],
        bookingPackages: () => [],
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainLineBookingDialog(
              loggedInGroomer: mockUser,
              bloc: dynamicBloc,
              onBookingCreated: () {},
            ),
          ),
        ),
      );
      // Let initState's GroomerHomeGetBookingServicesEvent fetch and emit mockServices
      await tester.pumpAndSettle();

      // Ensure mockServices actually arrived into the bloc
      expect(dynamicBloc.state.bookingServices.isNotEmpty, isTrue);

      // Header must still show placeholder "Select a service" (NO auto-selection)
      expect(find.text('Select a service'), findsOneWidget);
      expect(find.text('Not selected'), findsWidgets);

      dynamicBloc.close();
    });
  });

  group('MainLineBookingDialog Section 1: Calling Customer No Default Selection & Dynamic Picking', () {
    late _FakeBookingRepository repo;
    late GroomerHomeBloc bloc;

    final customer1 = CustomerSummary(id: 10, name: 'Alice Smith', email: 'alice@example.com', phone: '555-1234');
    final customer2 = CustomerSummary(id: 20, name: 'Bob Jones', email: 'bob@example.com', phone: '555-5678');
    const pet1 = CustomerPetSummary(id: 101, userId: 10, name: 'Luna', breed: 'Poodle');
    const pet2 = CustomerPetSummary(id: 201, userId: 20, name: 'Charlie', breed: 'Golden Retriever');

    setUp(() {
      repo = _FakeBookingRepository(
        mockCustomers: [customer1, customer2],
        mockPets: [pet1, pet2],
        mockGroomers: [mockGroomer],
        mockServices: mockServices,
        mockPackages: mockPackages,
      );
      bloc = GroomerHomeBloc(repository: repo);
      bloc.emit(bloc.state.copyWith(
        searchedCustomers: () => [customer1, customer2],
        customerPets: () => [pet1, pet2],
        salonGroomers: () => [mockGroomer],
        bookingServices: () => mockServices,
        bookingPackages: () => mockPackages,
      ));
    });

    tearDown(() {
      bloc.close();
    });

    testWidgets('1. No customer is selected by default upon opening', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainLineBookingDialog(
              loggedInGroomer: mockUser,
              bloc: bloc,
              onBookingCreated: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Dropdown hint shows "Select calling customer"
      expect(find.text('Select calling customer'), findsOneWidget);

      // Section 2 shows "Please select a registered customer above to view pets."
      expect(find.text('Please select a registered customer above to view pets.'), findsOneWidget);

      // Booking Summary section shows "Not selected"
      expect(find.text('Not selected'), findsWidgets);

      // Confirm button is disabled
      final btnFinder = find.byType(ElevatedButton).last;
      final btn = tester.widget<ElevatedButton>(btnFinder);
      expect(btn.onPressed, isNull);
    });

    testWidgets('2. Searching customers auto-selects the searched customer', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainLineBookingDialog(
              loggedInGroomer: mockUser,
              bloc: bloc,
              onBookingCreated: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially no customer is selected
      expect(find.text('Select calling customer'), findsOneWidget);

      // Type in search bar to trigger customer search
      await tester.enterText(find.byType(TextField).first, 'Bob');
      await tester.pump(const Duration(milliseconds: 400)); // debounce timer
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      // Searched customer Bob Jones is automatically selected
      expect(find.text('Bob Jones (555-5678)'), findsOneWidget);
      expect(find.text('Bob Jones'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
    });

    testWidgets('3. User can manually pick any customer from the dropdown', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainLineBookingDialog(
              loggedInGroomer: mockUser,
              bloc: bloc,
              onBookingCreated: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the customer dropdown
      await tester.tap(find.text('Select calling customer'));
      await tester.pumpAndSettle();

      // Tap Bob Jones in dropdown menu
      await tester.tap(find.text('Bob Jones (555-5678)').last);
      await tester.pumpAndSettle();

      // Selected customer is displayed in dropdown and summary
      expect(find.text('Bob Jones (555-5678)'), findsOneWidget);
      expect(find.text('Bob Jones'), findsOneWidget);
    });
  });
}
