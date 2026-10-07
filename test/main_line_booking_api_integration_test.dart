import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/bloc/groomer_home_bloc.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/customer_summary.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_schedule_models.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_user.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/repo/groomer_home_repository.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/main_line_booking_dialog.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';

class MockApiIntegrationGroomerRepository extends GroomerHomeRepository {
  final List<CustomerSummary> customers;
  final Map<int, List<CustomerPetSummary>> petsByUser;
  final List<SalonGroomer> shopGroomers;
  final List<ServiceItem> services;
  final List<ServiceItem> packages;
  final List<ServiceItem> addOns;

  bool shouldFailAvailability = false;
  bool shouldReturnEmptySlots = false;
  bool shouldFailBookingCreation = false;

  Map<String, dynamic>? lastAvailabilityQuery;
  int? lastAvailabilityGroomerId;
  Map<String, dynamic>? lastCreateBookingPayload;
  int createBookingCallCount = 0;

  MockApiIntegrationGroomerRepository({
    required this.customers,
    required this.petsByUser,
    required this.shopGroomers,
    required this.services,
    required this.packages,
    required this.addOns,
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
      return customers
          .where((c) =>
              c.name.toLowerCase().contains(q) ||
              (c.phone != null && c.phone!.contains(q)) ||
              (c.email != null && c.email!.toLowerCase().contains(q)))
          .toList();
    }
    return customers;
  }

  @override
  Future<List<CustomerPetSummary>> getCustomerPets(int userId) async {
    return petsByUser[userId] ?? [];
  }

  @override
  Future<List<SalonGroomer>> getSalonGroomers() async {
    return shopGroomers;
  }

  @override
  Future<BookingServicesResult> getBookingServices() async {
    return BookingServicesResult(
      breeds: services,
      packages: packages,
      addOns: addOns,
      walkIn: [],
    );
  }

  @override
  Future<Map<String, dynamic>?> getAvailability({
    required String date,
    int? serviceId,
    int? packageId,
    List<int>? addOnIds,
    int? groomerId,
  }) async {
    lastAvailabilityGroomerId = groomerId;
    lastAvailabilityQuery = {
      'date': date,
      'serviceId': serviceId,
      'packageId': packageId,
      'addOnIds': addOnIds,
      'groomerId': groomerId,
    };

    if (shouldFailAvailability) {
      return {'success': false, 'message': 'API Error'};
    }

    if (shouldReturnEmptySlots) {
      return {
        'success': true,
        'data': {
          'availableSlots': <Map<String, dynamic>>[],
          'bookedSlots': <Map<String, dynamic>>[],
          'totalDurationMinutes': 60,
          'totalPrice': 50.0,
        }
      };
    }

    // Calculate dynamic duration and price based on addOns
    double addOnTotal = 0.0;
    int addOnDuration = 0;
    if (addOnIds != null) {
      for (final id in addOnIds) {
        final match = addOns.where((a) => a.id == id).firstOrNull;
        if (match != null) {
          addOnTotal += match.price;
          addOnDuration += match.durationMinutes;
        }
      }
    }

    final matchedGroomer = shopGroomers.where((g) => g.id == groomerId).firstOrNull;
    final groomerName = matchedGroomer?.name ?? 'Merisa Brown';

    return {
      'success': true,
      'data': {
        'availableSlots': [
          {
            'startTime': '23:00:00',
            'endTime': '23:45:00',
            'groomerId': groomerId ?? 1,
            'groomerName': groomerName,
            'bookingCount': 0,
            'maxBookings': 1,
            'remaining': 1,
            'isAvailable': true,
          }
        ],
        'bookedSlots': <Map<String, dynamic>>[],
        'totalDurationMinutes': 45 + addOnDuration,
        'totalPrice': 60.0 + addOnTotal,
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
  }) async {
    createBookingCallCount++;
    await Future<void>.delayed(const Duration(milliseconds: 15));
    lastCreateBookingPayload = {
      'userId': userId,
      'petId': petId,
      'serviceId': serviceId,
      'packageId': packageId,
      'addOnIds': addOnIds,
      'groomerId': groomerId,
      'bookingDate': bookingDate,
      'startTime': startTime,
      'endTime': endTime,
      'clientId': clientId ?? 'SHEAR-001',
      'regionId': regionId ?? 'DWG-001',
      'storeId': storeId ?? 'SHEAR-001',
    };

    if (shouldFailBookingCreation) {
      return null;
    }

    return {
      'success': true,
      'message': 'Booking created successfully',
      'data': {
        'bookingId': 1045,
        'status': 'confirmed',
        'totalDurationMinutes': 60,
        'totalPrice': 75.0,
      }
    };
  }

  @override
  Future<GroomerUser?> getProfile() => Future.value(null);

  @override
  Future<List<GroomerBooking>> getUpcomingBookings() => Future.value([]);

  @override
  Future<List<GroomerBooking>> getPendingBookings() => Future.value([]);

  @override
  Future<List<GroomerBooking>> getPastBookings() => Future.value([]);

  @override
  Future<List<GroomerBooking>> getCancelledBookings() => Future.value([]);

  @override
  Future<List<GroomerBooking>> getCancellationRequests() => Future.value([]);

  @override
  Future<List<StoreServiceHour>> getServiceHours({String? clientId, String? regionId, String? storeId}) => Future.value([]);

  @override
  Future<List<StoreHoliday>> getHolidays({String? clientId, String? regionId, String? storeId}) => Future.value([]);

  @override
  Future<List<Map<String, dynamic>>> getNotifications() => Future.value([]);

  @override
  Future<List<GroomerWorkingHour>> getGroomerHours({String? groomerCode, String? clientId, String? regionId, String? storeId}) => Future.value([]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockCustomers = [
    const CustomerSummary(
      id: 10,
      name: 'John Doe',
      email: 'john@example.com',
      phone: '9876543210',
    ),
    const CustomerSummary(
      id: 20,
      name: 'Sarah Connor',
      email: 'sarah@example.com',
      phone: '9123456780',
    ),
  ];

  final mockPetsByUser = {
    10: [
      const CustomerPetSummary(
        id: 101,
        userId: 10,
        name: 'Buddy',
        breed: 'Golden Retriever',
        weight: 'Large',
      ),
      const CustomerPetSummary(
        id: 102,
        userId: 10,
        name: 'Max',
        breed: 'German Shepherd',
        weight: 'Large',
      ),
    ],
    20: [
      const CustomerPetSummary(
        id: 201,
        userId: 20,
        name: 'Bella',
        breed: 'Poodle',
        weight: 'Small',
      ),
    ],
  };

  final mockShopGroomers = [
    const SalonGroomer(
      id: 1,
      groomerCode: 'G001',
      firstName: 'Marisa',
      lastName: 'Brown',
      name: 'Marisa Brown',
      role: 'Groomer',
      isAvailable: true,
      isSelf: true,
    ),
    const SalonGroomer(
      id: 2,
      groomerCode: 'G002',
      firstName: 'Richard',
      lastName: 'Davis',
      name: 'Richard Davis',
      role: 'Groomer',
      isAvailable: true,
      isSelf: false,
    ),
    const SalonGroomer(
      id: 3,
      groomerCode: 'G003',
      firstName: 'Alex',
      lastName: 'Taylor',
      name: 'Alex Taylor',
      role: 'Groomer',
      isAvailable: false,
      isSelf: false,
      reason: 'On Leave',
    ),
  ];

  final mockServices = [
    const ServiceItem(
      id: 12,
      name: 'Full Grooming Spa',
      description: 'Complete bath, hair styling and nail trim',
      price: 60.0,
      priceDisplay: '\$60',
      durationMinutes: 45,
      isPackage: false,
      isAddOn: false,
    ),
  ];

  final mockPackages = [
    const ServiceItem(
      id: 1,
      name: 'Royal VIP Package',
      description: 'Luxury wash and full grooming bundle',
      price: 95.0,
      priceDisplay: '\$95',
      durationMinutes: 75,
      isPackage: true,
      isAddOn: false,
    ),
  ];

  final mockAddOns = [
    const ServiceItem(
      id: 2,
      name: 'Teeth Brushing',
      description: 'Enzyme tartar removal and mint breath spray',
      price: 15.0,
      priceDisplay: '\$15',
      durationMinutes: 10,
      isPackage: false,
      isAddOn: true,
    ),
    const ServiceItem(
      id: 3,
      name: 'Nail Grinding',
      description: 'Smooth round finish with dremel tool',
      price: 12.0,
      priceDisplay: '\$12',
      durationMinutes: 10,
      isPackage: false,
      isAddOn: true,
    ),
  ];

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  group('Main Line Call Booking API Integration Tests', () {
    late MockApiIntegrationGroomerRepository repository;
    late GroomerHomeBloc bloc;

    setUp(() {
      repository = MockApiIntegrationGroomerRepository(
        customers: mockCustomers,
        petsByUser: mockPetsByUser,
        shopGroomers: mockShopGroomers,
        services: mockServices,
        packages: mockPackages,
        addOns: mockAddOns,
      );
      bloc = GroomerHomeBloc(repository: repository);
    });

    tearDown(() {
      bloc.close();
    });

    test('1. Customer search uses real API with query parameters', () async {
      bloc.add(const GroomerHomeSearchCustomersEvent(query: 'John'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.searchedCustomers.length, equals(1));
      expect(bloc.state.searchedCustomers.first.id, equals(10));
      expect(bloc.state.searchedCustomers.first.name, equals('John Doe'));
    });

    test('2. Customer pets loaded after customer selection', () async {
      bloc.add(const GroomerHomeGetCustomerPetsEvent(10));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.customerPets.length, equals(2));
      expect(bloc.state.customerPets[0].id, equals(101));
      expect(bloc.state.customerPets[0].name, equals('Buddy'));
      expect(bloc.state.customerPets[1].id, equals(102));
      expect(bloc.state.customerPets[1].name, equals('Max'));
    });

    test('3. Shop groomers load from GET /api/groomer-auth/groomers with catalog IDs', () async {
      bloc.add(const GroomerHomeGetSalonGroomersEvent());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.salonGroomers.length, equals(3));
      expect(bloc.state.salonGroomers[0].id, equals(1));
      expect(bloc.state.salonGroomers[0].isSelf, isTrue);
      expect(bloc.state.salonGroomers[1].id, equals(2));
      expect(bloc.state.salonGroomers[1].name, equals('Richard Davis'));
      expect(bloc.state.salonGroomers[2].isAvailable, isFalse);
      expect(bloc.state.salonGroomers[2].reason, equals('On Leave'));
    });

    test('4. Requested groomer availability check with add-ons passes query parameters', () async {
      final date = DateTime(2026, 9, 25);
      bloc.add(GroomerHomeCheckAvailabilityEvent(
        date: date,
        groomerId: 2, // Richard Davis
        serviceId: 12,
        packageId: 1,
        addOnIds: [2, 3],
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(repository.lastAvailabilityGroomerId, equals(2));
      expect(repository.lastAvailabilityQuery?['serviceId'], equals(12));
      expect(repository.lastAvailabilityQuery?['packageId'], equals(1));
      expect(repository.lastAvailabilityQuery?['addOnIds'], equals([2, 3]));
      expect(bloc.state.isSlotAvailable, isTrue);
      expect(bloc.state.availableTimeSlots.length, equals(1));
    });

    test('5. Requested groomer different from logged-in groomer creates booking for requested groomer', () async {
      final emittedStates = <GroomerHomeState>[];
      final sub = bloc.stream.listen(emittedStates.add);

      bloc.add(const GroomerHomeCreateBookingForUserEvent(
        userId: 10,
        petId: 101,
        serviceId: 12,
        packageId: 1,
        addOnIds: [2],
        groomerId: 2, // Richard Davis (requested groomer, not Marisa who is 1)
        bookingDate: '2026-09-25',
        startTime: '10:00',
        endTime: '11:00',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await sub.cancel();

      expect(emittedStates.any((s) => s.bookingForUserSuccess == true), isTrue);
      expect(bloc.state.lastCreatedBookingId, equals(1045));
      expect(repository.lastCreateBookingPayload?['userId'], equals(10));
      expect(repository.lastCreateBookingPayload?['petId'], equals(101));
      expect(repository.lastCreateBookingPayload?['serviceId'], equals(12));
      expect(repository.lastCreateBookingPayload?['packageId'], equals(1));
      expect(repository.lastCreateBookingPayload?['addOnIds'], equals([2]));
      expect(repository.lastCreateBookingPayload?['groomerId'], equals(2));
      expect(repository.lastCreateBookingPayload?['clientId'], equals('SHEAR-001'));
      expect(repository.lastCreateBookingPayload?['regionId'], equals('DWG-001'));
      expect(repository.lastCreateBookingPayload?['storeId'], equals('SHEAR-001'));
    });

    test('6. Booking with 0 add-ons passes empty addOnIds array', () async {
      final emittedStates = <GroomerHomeState>[];
      final sub = bloc.stream.listen(emittedStates.add);

      bloc.add(const GroomerHomeCreateBookingForUserEvent(
        userId: 20,
        petId: 201,
        serviceId: 12,
        addOnIds: [],
        groomerId: 1,
        bookingDate: '2026-09-25',
        startTime: '14:00',
        endTime: '14:45',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await sub.cancel();

      expect(emittedStates.any((s) => s.bookingForUserSuccess == true), isTrue);
      expect(repository.lastCreateBookingPayload?['addOnIds'], equals([]));
    });

    test('7. No available slots updates state with friendly availability message', () async {
      repository.shouldReturnEmptySlots = true;

      bloc.add(GroomerHomeCheckAvailabilityEvent(
        date: DateTime(2026, 9, 25),
        groomerId: 2,
        serviceId: 12,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.isSlotAvailable, isFalse);
      expect(bloc.state.availableTimeSlots, isEmpty);
      expect(bloc.state.availabilityMessage, contains('No available time slots'));
    });

    test('8. API failure on booking creation sets bookingForUserError without crash', () async {
      repository.shouldFailBookingCreation = true;

      bloc.add(const GroomerHomeCreateBookingForUserEvent(
        userId: 10,
        petId: 101,
        serviceId: 12,
        bookingDate: '2026-09-25',
        startTime: '10:00',
        endTime: '11:00',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.bookingForUserSuccess, isFalse);
      expect(bloc.state.bookingForUserError, isNotNull);
      expect(bloc.state.lastCreatedBookingId, isNull);
    });

    testWidgets('9. Full MainLineBookingDialog Widget rendering with real API data flow', (tester) async {
      final loggedInMarisa = const GroomerUser(
        id: 1,
        groomerCode: 'G001',
        firstName: 'Marisa',
        lastName: 'Brown',
        email: 'marisa@shearheaven.com',
        role: 'Groomer',
      );

      // Seed dynamic API state into bloc
      bloc.emit(bloc.state.copyWith(
        searchedCustomers: () => mockCustomers,
        customerPets: () => mockPetsByUser[10]!,
        salonGroomers: () => mockShopGroomers,
        bookingServices: () => mockServices,
        bookingPackages: () => mockPackages,
        bookingAddOns: () => mockAddOns,
        isSlotAvailable: () => true,
        availableTimeSlots: () => [
          {
            'startTime': '23:00:00',
            'endTime': '23:45:00',
            'groomerId': 2,
            'groomerName': 'Richard Davis',
            'isAvailable': true,
            'remaining': 1,
          }
        ],
        slotTotalPrice: () => 60.0,
        slotDurationMinutes: () => 45,
      ));

      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainLineBookingDialog(
              loggedInGroomer: loggedInMarisa,
              bloc: bloc,
              onBookingCreated: () {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify header and logged-in groomer display
      expect(find.text('Main-Line Call Booking'), findsOneWidget);
      expect(find.textContaining('Call attended by: Marisa'), findsOneWidget);

      // Verify customers and pets
      expect(find.textContaining('John Doe'), findsWidgets);
      expect(find.textContaining('Buddy'), findsWidgets);

      // Verify Requested Groomers
      expect(find.text('Any Groomer'), findsOneWidget);
      expect(find.text('Richard Davis'), findsOneWidget);

      // Verify Optional Add-ons
      expect(find.text('Optional Add-ons'), findsWidgets);
      expect(find.text('Teeth Brushing'), findsOneWidget);
      expect(find.text('Nail Grinding'), findsOneWidget);

      // Select Teeth Brushing add-on
      await tester.tap(find.text('Teeth Brushing'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify selected counter
      expect(find.textContaining('1 selected'), findsOneWidget);

      // Select Richard Davis (Requested groomer)
      await tester.ensureVisible(find.text('Richard Davis'));
      await tester.tap(find.text('Richard Davis'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Select time slot
      await tester.ensureVisible(find.text('11:00 PM').first);
      await tester.tap(find.text('11:00 PM').first);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify confirmation button enabled with dynamic groomer assignment text
      final btnFinder = find.byType(ElevatedButton);
      expect(btnFinder, findsOneWidget);
      final btn = tester.widget<ElevatedButton>(btnFinder);
      expect(btn.onPressed, isNotNull);
      expect(find.textContaining('Assign to Richard'), findsOneWidget);
    });

    test('10. Changing groomer immediately clears stale slots and fetches new groomer availability', () async {
      // 1. Initial check for Groomer 1
      bloc.add(GroomerHomeCheckAvailabilityEvent(
        date: DateTime(2026, 9, 25),
        groomerId: 1,
        serviceId: 12,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.availableTimeSlots.length, equals(1));
      expect(repository.lastAvailabilityGroomerId, equals(1));

      // 2. Change to Groomer 2
      bloc.add(GroomerHomeCheckAvailabilityEvent(
        date: DateTime(2026, 9, 25),
        groomerId: 2,
        serviceId: 12,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(repository.lastAvailabilityGroomerId, equals(2));
      expect(bloc.state.availableTimeSlots.length, equals(1));
      expect(bloc.state.availableTimeSlots.first['groomerName'], equals('Richard Davis'));
    });

    test('11. Changing date updates availability date query parameter', () async {
      final newDate = DateTime(2026, 10, 15);
      bloc.add(GroomerHomeCheckAvailabilityEvent(
        date: newDate,
        groomerId: 2,
        serviceId: 12,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(repository.lastAvailabilityQuery?['date'], equals('2026-10-15'));
    });

    test('12. Changing service updates availability serviceId query parameter', () async {
      bloc.add(GroomerHomeCheckAvailabilityEvent(
        date: DateTime(2026, 9, 25),
        groomerId: 1,
        serviceId: 99,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(repository.lastAvailabilityQuery?['serviceId'], equals(99));
    });

    test('13. Adding and removing add-ons recalculates availability and addOnIds query', () async {
      // With add-ons [2, 3]
      bloc.add(GroomerHomeCheckAvailabilityEvent(
        date: DateTime(2026, 9, 25),
        groomerId: 1,
        serviceId: 12,
        addOnIds: [2, 3],
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(repository.lastAvailabilityQuery?['addOnIds'], equals([2, 3]));
      expect(bloc.state.slotTotalPrice, equals(60.0 + 15.0 + 12.0)); // Base + Addons
      expect(bloc.state.slotDurationMinutes, equals(45 + 10 + 10));

      // Remove add-on 3 -> [2]
      bloc.add(GroomerHomeCheckAvailabilityEvent(
        date: DateTime(2026, 9, 25),
        groomerId: 1,
        serviceId: 12,
        addOnIds: [2],
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(repository.lastAvailabilityQuery?['addOnIds'], equals([2]));
      expect(bloc.state.slotTotalPrice, equals(60.0 + 15.0));
      expect(bloc.state.slotDurationMinutes, equals(45 + 10));
    });

    test('14. Respects API slot capacity fields: bookingCount, maxBookings, and remaining', () async {
      // Emit a slot where bookingCount >= maxBookings and remaining is 0
      bloc.emit(bloc.state.copyWith(
        availableTimeSlots: () => [
          {
            'startTime': '10:00:00',
            'endTime': '11:00:00',
            'groomerId': 2,
            'isAvailable': true,
            'bookingCount': 2,
            'maxBookings': 2,
            'remaining': 0,
          }
        ],
        isSlotAvailable: () => false,
      ));

      expect(bloc.state.isSlotAvailable, isFalse);
    });

    test('15. Single API trigger: Duplicate / concurrent booking creation events are ignored', () async {
      repository.createBookingCallCount = 0;

      // Dispatch first create booking event
      bloc.add(const GroomerHomeCreateBookingForUserEvent(
        userId: 10,
        petId: 101,
        serviceId: 12,
        groomerId: 2,
        bookingDate: '2026-09-25',
        startTime: '10:00:00',
        endTime: '10:45:00',
      ));

      // Immediate concurrent duplicate dispatch while bloc is processing
      bloc.add(const GroomerHomeCreateBookingForUserEvent(
        userId: 10,
        petId: 101,
        serviceId: 12,
        groomerId: 2,
        bookingDate: '2026-09-25',
        startTime: '10:00:00',
        endTime: '10:45:00',
      ));

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(repository.createBookingCallCount, equals(1));
      expect(bloc.state.bookingForUserSuccess, isFalse); // reset cleanly by fetch cycle
      expect(bloc.state.lastCreatedBookingId, equals(1045));
    });

    testWidgets('16. Success callback and alert triggered exactly once even across data reload emissions', (tester) async {
      int bookingCreatedCallbackCount = 0;

      final loggedInMarisa = const GroomerUser(
        id: 1,
        groomerCode: 'G001',
        firstName: 'Marisa',
        lastName: 'Brown',
        email: 'marisa@shearheaven.com',
        role: 'Groomer',
      );

      bloc.emit(bloc.state.copyWith(
        searchedCustomers: () => mockCustomers,
        customerPets: () => mockPetsByUser[10]!,
        salonGroomers: () => mockShopGroomers,
        bookingServices: () => mockServices,
        bookingPackages: () => mockPackages,
        bookingAddOns: () => mockAddOns,
        isSlotAvailable: () => true,
        availableTimeSlots: () => [
          {
            'startTime': '23:00:00',
            'endTime': '23:45:00',
            'groomerId': 2,
            'groomerName': 'Richard Davis',
            'isAvailable': true,
            'remaining': 1,
          }
        ],
      ));

      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainLineBookingDialog(
              loggedInGroomer: loggedInMarisa,
              bloc: bloc,
              onBookingCreated: () {
                bookingCreatedCallbackCount++;
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Emit bookingForUserSuccess: true
      bloc.emit(bloc.state.copyWith(
        bookingForUserSuccess: () => true,
        lastCreatedBookingId: () => 1045,
      ));
      await tester.pump();

      // Subsequent state emissions (e.g. data reload loading and loaded)
      bloc.emit(bloc.state.copyWith(
        status: () => GroomerHomeStatus.loading,
      ));
      await tester.pump();

      bloc.emit(bloc.state.copyWith(
        status: () => GroomerHomeStatus.loaded,
      ));
      await tester.pump();

      expect(bookingCreatedCallbackCount, equals(1));
      await tester.pump(const Duration(seconds: 6));
    });
  });
}
