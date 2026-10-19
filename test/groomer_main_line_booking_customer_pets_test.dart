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

class FakeCustomerPetsRepository extends GroomerHomeRepository {
  final List<CustomerSummary> mockCustomers;
  final Map<int, List<CustomerPetSummary>> mockCustomerPets;
  final List<SalonGroomer> mockGroomers;
  final List<ServiceItem> mockServices;
  int getCustomerPetsCallCount = 0;

  FakeCustomerPetsRepository({
    required this.mockCustomers,
    required this.mockCustomerPets,
    required this.mockGroomers,
    required this.mockServices,
  });

  @override
  Future<List<CustomerSummary>> searchCustomers({
    String? query,
    int page = 1,
    int limit = 50,
    int offset = 0,
  }) async {
    return mockCustomers;
  }

  @override
  Future<List<CustomerPetSummary>> getCustomerPets(int userId) async {
    getCustomerPetsCallCount++;
    return mockCustomerPets[userId] ?? [];
  }

  @override
  Future<List<SalonGroomer>> getSalonGroomers() async => mockGroomers;

  @override
  Future<BookingServicesResult> getBookingServices() async => BookingServicesResult(
        breeds: mockServices,
        packages: const [],
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
    return {
      'isAvailable': true,
      'slots': [
        {'startTime': '09:00:00', 'endTime': '10:00:00', 'isAvailable': true}
      ],
      'totalPrice': 50.0,
      'durationMinutes': 60,
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  const mockGroomerUser = GroomerUser(
    id: 1,
    groomerCode: 'G01',
    firstName: 'Staff',
    lastName: 'Groomer',
    email: 'staff@example.com',
    mobile: '555-0100',
    isActive: true,
  );

  const mockGroomer = SalonGroomer(
    id: 1,
    groomerCode: 'G01',
    firstName: 'Staff',
    lastName: 'Groomer',
    name: 'Staff Groomer',
    isAvailable: true,
  );

  const mockServices = [
    ServiceItem(
      id: 1,
      name: 'Full Body Grooming',
      price: 75.0,
      priceDisplay: '\$75.00',
      durationMinutes: 60,
      description: 'Bath, haircut & styling',
      isPackage: false,
      isAddOn: false,
    ),
  ];

  const pet1 = CustomerPetSummary(
    id: 101,
    userId: 1,
    name: 'Bella',
    breed: 'Golden Retriever',
  );
  const pet2 = CustomerPetSummary(
    id: 102,
    userId: 1,
    name: 'Max',
    breed: 'Poodle',
  );

  final customerWithPets = CustomerSummary(
    id: 1,
    name: 'Alice Johnson',
    email: 'alice@example.com',
    phone: '555-1111',
    pets: const [pet1, pet2],
  );

  final customerWithoutPets = CustomerSummary(
    id: 2,
    name: 'Bob Smith',
    email: 'bob@example.com',
    phone: '555-2222',
    pets: const [],
  );

  group('MainLineBookingDialog - Customer Relevant Pets & Empty State Tests', () {
    testWidgets('1. Displays relevant pets when selected customer has pets',
        (WidgetTester tester) async {
      final repo = FakeCustomerPetsRepository(
        mockCustomers: [customerWithPets],
        mockCustomerPets: {1: [pet1, pet2]},
        mockGroomers: [mockGroomer],
        mockServices: mockServices,
      );
      final bloc = GroomerHomeBloc(repository: repo);
      bloc.emit(bloc.state.copyWith(
        searchedCustomers: () => [customerWithPets],
        customerPets: () => [pet1, pet2],
        salonGroomers: () => [mockGroomer],
        bookingServices: () => mockServices,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainLineBookingDialog(
              loggedInGroomer: mockGroomerUser,
              bloc: bloc,
              onBookingCreated: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify customer relevant pets Bella and Max are displayed
      expect(find.text('Bella'), findsOneWidget);
      expect(find.text('(Golden Retriever)'), findsOneWidget);
      expect(find.text('Max'), findsOneWidget);
      expect(find.text('(Poodle)'), findsOneWidget);

      bloc.close();
    });

    testWidgets('2. Displays "This customer has no pets registered." when customer has no pets',
        (WidgetTester tester) async {
      final repo = FakeCustomerPetsRepository(
        mockCustomers: [customerWithoutPets],
        mockCustomerPets: {2: []},
        mockGroomers: [mockGroomer],
        mockServices: mockServices,
      );
      final bloc = GroomerHomeBloc(repository: repo);
      bloc.emit(bloc.state.copyWith(
        searchedCustomers: () => [customerWithoutPets],
        customerPets: () => [],
        isLoadingCustomerPets: () => false,
        salonGroomers: () => [mockGroomer],
        bookingServices: () => mockServices,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainLineBookingDialog(
              loggedInGroomer: mockGroomerUser,
              bloc: bloc,
              onBookingCreated: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify proper message is displayed instead of "Unable to load pets. Please try again."
      expect(find.text('This customer has no pets registered.'), findsOneWidget);
      expect(find.text('Unable to load pets. Please try again.'), findsNothing);

      bloc.close();
    });

    test('3. GroomerHomeBloc retains initialPets if API returns empty', () async {
      final repo = FakeCustomerPetsRepository(
        mockCustomers: [customerWithPets],
        mockCustomerPets: {1: []}, // API returns empty, but customer had initial pets
        mockGroomers: [mockGroomer],
        mockServices: mockServices,
      );
      final bloc = GroomerHomeBloc(repository: repo);

      bloc.add(GroomerHomeGetCustomerPetsEvent(
        customerWithPets.id,
        initialPets: customerWithPets.pets,
      ));

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Bloc falls back to initialPets
      expect(bloc.state.customerPets, isNotEmpty);
      expect(bloc.state.customerPets.first.name, equals('Bella'));
      expect(bloc.state.petError, isNull);

      bloc.close();
    });

    test('4. GroomerHomeBloc cleanly emits empty customerPets with no error for petless customer', () async {
      final repo = FakeCustomerPetsRepository(
        mockCustomers: [customerWithoutPets],
        mockCustomerPets: {2: []},
        mockGroomers: [mockGroomer],
        mockServices: mockServices,
      );
      final bloc = GroomerHomeBloc(repository: repo);

      bloc.add(GroomerHomeGetCustomerPetsEvent(
        customerWithoutPets.id,
        initialPets: customerWithoutPets.pets,
      ));

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(bloc.state.customerPets, isEmpty);
      expect(bloc.state.isLoadingCustomerPets, isFalse);
      expect(bloc.state.petError, isNull);

      bloc.close();
    });
  });
}
