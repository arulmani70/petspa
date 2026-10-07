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

class FakeGroomerHomeRepository extends GroomerHomeRepository {
  final List<CustomerSummary> mockCustomers;
  final List<CustomerPetSummary> mockPets;
  final List<SalonGroomer> mockGroomers;
  final List<ServiceItem> mockServices;
  final List<ServiceItem> mockAddOns;

  Map<String, dynamic>? lastCreatedBookingParams;
  List<int>? lastAvailabilityAddOnIds;

  FakeGroomerHomeRepository({
    required this.mockCustomers,
    required this.mockPets,
    required this.mockGroomers,
    required this.mockServices,
    required this.mockAddOns,
  });

  @override
  Future<List<CustomerSummary>> searchCustomers({String? query = '', int page = 1, int limit = 20, int offset = 0}) {
    return Future.value(mockCustomers);
  }

  @override
  Future<List<CustomerPetSummary>> getCustomerPets(int userId) {
    return Future.value(mockPets);
  }

  @override
  Future<List<SalonGroomer>> getSalonGroomers() {
    return Future.value(mockGroomers);
  }

  @override
  Future<BookingServicesResult> getBookingServices() {
    return Future.value(BookingServicesResult(
      breeds: mockServices,
      packages: [],
      addOns: mockAddOns,
      walkIn: [],
    ));
  }

  @override
  Future<Map<String, dynamic>?> getAvailability({
    required String date,
    int? serviceId,
    int? packageId,
    List<int>? addOnIds,
    int? groomerId,
  }) {
    lastAvailabilityAddOnIds = addOnIds;
    double addOnPrice = 0.0;
    int addOnDuration = 0;
    if (addOnIds != null) {
      for (final id in addOnIds) {
        final match = mockAddOns.where((a) => a.id == id).firstOrNull;
        if (match != null) {
          addOnPrice += match.price;
          addOnDuration += match.durationMinutes;
        }
      }
    }

    return Future.value({
      'success': true,
      'data': {
        'availableSlots': [
          {'startTime': '23:00:00', 'endTime': '23:30:00', 'isAvailable': true, 'remaining': 1}
        ],
        'bookedSlots': <Map<String, dynamic>>[],
        'totalDurationMinutes': 60 + addOnDuration,
        'totalPrice': 75.0 + addOnPrice,
      },
    });
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
  }) {
    lastCreatedBookingParams = {
      'userId': userId,
      'petId': petId,
      'serviceId': serviceId,
      'packageId': packageId,
      'addOnIds': addOnIds,
      'groomerId': groomerId,
      'bookingDate': bookingDate,
      'startTime': startTime,
      'endTime': endTime,
    };
    return Future.value({'success': true, 'data': {'id': 999}});
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

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  group('Optional Add-ons Enhancement Tests in MainLineBookingDialog', () {
    late FakeGroomerHomeRepository fakeRepo;
    late GroomerHomeBloc bloc;

    const mockAddOns = [
      ServiceItem(
        id: 101,
        name: 'De-shedding Treatment',
        price: 25.0,
        priceDisplay: '\$25.00',
        durationMinutes: 20,
        description: 'Undercoat removal brush out',
        isPackage: false,
        isAddOn: true,
      ),
      ServiceItem(
        id: 102,
        name: 'Teeth Brushing',
        price: 15.0,
        priceDisplay: '\$15.00',
        durationMinutes: 10,
        description: 'Fresh breath enzyme gel',
        isPackage: false,
        isAddOn: true,
      ),
      ServiceItem(
        id: 103,
        name: 'Flea & Tick Rinse',
        price: 20.0,
        priceDisplay: '\$20.00',
        durationMinutes: 0,
        description: 'Medicinal anti-parasite wash',
        isPackage: false,
        isAddOn: true,
      ),
    ];

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

    final mockCustomer = CustomerSummary(
      id: 50,
      name: 'Jane Doe',
      email: 'jane@example.com',
      phone: '555-0199',
    );

    const mockPet = CustomerPetSummary(
      id: 10,
      userId: 50,
      name: 'Milo',
      breed: 'Golden Retriever',
    );

    const mockGroomer = SalonGroomer(
      id: 5,
      groomerCode: 'G05',
      name: 'Sarah Groomer',
      firstName: 'Sarah',
      lastName: 'Groomer',
      isAvailable: true,
    );

    const mockGroomerUser = GroomerUser(
      id: 1,
      groomerCode: 'G01',
      firstName: 'Staff',
      lastName: 'Groomer',
      email: 'staff@example.com',
      mobile: '555-0100',
      isActive: true,
    );

    setUp(() {
      fakeRepo = FakeGroomerHomeRepository(
        mockCustomers: [mockCustomer],
        mockPets: [mockPet],
        mockGroomers: [mockGroomer],
        mockServices: mockServices,
        mockAddOns: mockAddOns,
      );
      bloc = GroomerHomeBloc(repository: fakeRepo);
      bloc.emit(bloc.state.copyWith(
        searchedCustomers: () => [mockCustomer],
        customerPets: () => [mockPet],
        salonGroomers: () => [mockGroomer],
        bookingServices: () => mockServices,
        bookingAddOns: () => mockAddOns,
        isSlotAvailable: () => true,
        availableTimeSlots: () => [
          <String, dynamic>{'startTime': '23:00:00', 'endTime': '23:30:00', 'isAvailable': true, 'remaining': 1}
        ],
        slotTotalPrice: () => 75.0,
        slotDurationMinutes: () => 60,
      ));
    });

    tearDown(() {
      bloc.close();
    });

    Future<void> pumpDialog(WidgetTester tester) async {
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
    }

    testWidgets('1. Empty add-ons response renders cleanly without crash',
        (WidgetTester tester) async {
      final emptyRepo = FakeGroomerHomeRepository(
        mockCustomers: [mockCustomer],
        mockPets: [mockPet],
        mockGroomers: [mockGroomer],
        mockServices: mockServices,
        mockAddOns: [],
      );
      final emptyBloc = GroomerHomeBloc(repository: emptyRepo);
      emptyBloc.emit(emptyBloc.state.copyWith(
        searchedCustomers: () => [mockCustomer],
        customerPets: () => [mockPet],
        salonGroomers: () => [mockGroomer],
        bookingServices: () => mockServices,
        bookingAddOns: () => [],
        isSlotAvailable: () => true,
        availableTimeSlots: () => [
          <String, dynamic>{'startTime': '23:00:00', 'endTime': '23:30:00', 'isAvailable': true, 'remaining': 1}
        ],
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainLineBookingDialog(
              loggedInGroomer: mockGroomerUser,
              bloc: emptyBloc,
              onBookingCreated: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure dialog renders without throwing exception
      expect(tester.takeException(), isNull);
      expect(find.text('Full Body Grooming (\$75)'), findsOneWidget);
      expect(find.text('None (Optional • \$0)'), findsOneWidget);

      emptyBloc.close();
    });

    testWidgets('2. Handles null/missing optional fields safely',
        (WidgetTester tester) async {
      const edgeAddOns = [
        ServiceItem(
          id: 201,
          name: '',
          price: 0.0,
          priceDisplay: '',
          durationMinutes: 0,
          description: '',
          isPackage: false,
          isAddOn: true,
        ),
      ];

      final edgeRepo = FakeGroomerHomeRepository(
        mockCustomers: [mockCustomer],
        mockPets: [mockPet],
        mockGroomers: [mockGroomer],
        mockServices: mockServices,
        mockAddOns: edgeAddOns,
      );
      final edgeBloc = GroomerHomeBloc(repository: edgeRepo);
      edgeBloc.emit(edgeBloc.state.copyWith(
        searchedCustomers: () => [mockCustomer],
        customerPets: () => [mockPet],
        salonGroomers: () => [mockGroomer],
        bookingServices: () => mockServices,
        bookingAddOns: () => edgeAddOns,
        isSlotAvailable: () => true,
        availableTimeSlots: () => [
          <String, dynamic>{'startTime': '23:00:00', 'endTime': '23:30:00', 'isAvailable': true, 'remaining': 1}
        ],
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainLineBookingDialog(
              loggedInGroomer: mockGroomerUser,
              bloc: edgeBloc,
              onBookingCreated: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Fallback name 'Add-on' and price 'Free'
      expect(find.text('Add-on'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);

      edgeBloc.close();
    });

    testWidgets('3. Multiple add-ons selection and dynamic calculation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpDialog(tester);

      // Select De-shedding Treatment ($25)
      await tester.tap(find.text('De-shedding Treatment'));
      await tester.pumpAndSettle();

      // Select Teeth Brushing ($15)
      await tester.tap(find.text('Teeth Brushing'));
      await tester.pumpAndSettle();

      // Total is $75 + $25 + $15 = $115
      expect(find.text('2 selected • +\$40'), findsOneWidget);
      expect(find.text('\$115'), findsWidgets);
      expect(find.text('Confirm Appointment • \$115'), findsOneWidget);
      expect(find.text('De-shedding Treatment, Teeth Brushing (+\$40)'), findsOneWidget);
    });

    testWidgets('4. Clear All resets selection and totals back to base price',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpDialog(tester);

      // Select De-shedding Treatment ($25)
      await tester.tap(find.text('De-shedding Treatment'));
      await tester.pumpAndSettle();

      expect(find.text('Clear all'), findsOneWidget);

      // Tap Clear all
      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();

      expect(find.text('Clear all'), findsNothing);
      expect(find.text('None (Optional • \$0)'), findsOneWidget);
      expect(find.text('\$75'), findsWidgets);
      expect(find.text('Confirm Appointment • \$75'), findsOneWidget);
    });

    testWidgets('5. Zero add-ons booking allows booking to proceed normally',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpDialog(tester);

      // Select Any Groomer
      await tester.tap(find.text('Any Groomer'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Select time slot
      await tester.ensureVisible(find.text('11:00 PM').first);
      await tester.tap(find.text('11:00 PM').first);
      await tester.pumpAndSettle();

      final confirmBtn = find.widgetWithText(ElevatedButton, 'Confirm Appointment • \$75');
      expect(confirmBtn, findsOneWidget);

      final button = tester.widget<ElevatedButton>(confirmBtn);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('6a. Responsive layout on 360px viewport without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpDialog(tester);

      await tester.ensureVisible(find.text('De-shedding Treatment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('De-shedding Treatment'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Teeth Brushing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Teeth Brushing'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Clear all'), findsOneWidget);
    });

    testWidgets('6b. Responsive layout on 375px viewport without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(375, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpDialog(tester);

      await tester.ensureVisible(find.text('De-shedding Treatment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('De-shedding Treatment'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Teeth Brushing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Teeth Brushing'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Clear all'), findsOneWidget);
    });

    testWidgets('6c. Responsive layout on 390px viewport without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpDialog(tester);

      await tester.ensureVisible(find.text('De-shedding Treatment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('De-shedding Treatment'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Teeth Brushing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Teeth Brushing'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Clear all'), findsOneWidget);
    });

    test('7. Correct booking payload with selected add-on IDs', () async {
      bloc.add(const GroomerHomeCreateBookingForUserEvent(
        userId: 50,
        petId: 10,
        serviceId: 1,
        packageId: null,
        addOnIds: [101, 102],
        groomerId: 0,
        bookingDate: '2026-09-25',
        startTime: '23:00:00',
        endTime: '23:30:00',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify repository received selected add-on IDs in payload
      expect(fakeRepo.lastCreatedBookingParams, isNotNull);
      expect(fakeRepo.lastCreatedBookingParams!['userId'], equals(50));
      expect(fakeRepo.lastCreatedBookingParams!['petId'], equals(10));
      expect(fakeRepo.lastCreatedBookingParams!['addOnIds'], equals([101, 102]));
      expect(fakeRepo.lastCreatedBookingParams!['bookingDate'], equals('2026-09-25'));
    });
  });
}
