import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/shared_calendar.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/bloc/groomer_home_bloc.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/customer_summary.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_schedule_models.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_user.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/repo/groomer_home_repository.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/main_line_booking_dialog.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';

class _TestGroomerHomeRepo extends GroomerHomeRepository {
  final List<CustomerSummary> customers;
  final List<CustomerPetSummary> pets;
  final List<SalonGroomer> groomers;
  final List<ServiceItem> services;
  final List<ServiceItem> addOns;

  _TestGroomerHomeRepo({
    required this.customers,
    required this.pets,
    required this.groomers,
    required this.services,
    required this.addOns,
  });

  @override
  Future<List<CustomerSummary>> searchCustomers({String? query = '', int page = 1, int limit = 20, int offset = 0}) =>
      Future.value(customers);

  @override
  Future<List<CustomerPetSummary>> getCustomerPets(int userId) => Future.value(pets);

  @override
  Future<List<SalonGroomer>> getSalonGroomers() => Future.value(groomers);

  @override
  Future<BookingServicesResult> getBookingServices() => Future.value(BookingServicesResult(
        breeds: services,
        packages: [],
        addOns: addOns,
        walkIn: [],
      ));

  @override
  Future<Map<String, dynamic>?> getAvailability({
    required String date,
    int? serviceId,
    int? packageId,
    List<int>? addOnIds,
    int? groomerId,
  }) =>
      Future.value({
        'success': true,
        'data': {
          'availableSlots': [
            {'startTime': '10:00:00', 'endTime': '10:45:00', 'groomerId': 1, 'isAvailable': true, 'remaining': 1},
            {'startTime': '11:00:00', 'endTime': '11:45:00', 'groomerId': 1, 'isAvailable': true, 'remaining': 1},
            {'startTime': '12:00:00', 'endTime': '12:45:00', 'groomerId': 1, 'isAvailable': false, 'remaining': 0},
          ],
          'totalDurationMinutes': 45,
          'totalPrice': 60.0,
        }
      });

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
  }) =>
      Future.value({
        'success': true,
        'message': 'Booking created',
        'data': {'bookingId': 999, 'status': 'confirmed', 'totalPrice': 60.0}
      });

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

  const mockUser = GroomerUser(
    id: 1,
    groomerCode: 'G001',
    firstName: 'Marisa',
    lastName: 'Brown',
    email: 'marisa@shearheaven.com',
    role: 'Groomer',
  );

  const mockCustomer = CustomerSummary(id: 1, name: 'Alice Smith', email: 'alice@example.com', phone: '5551234');
  const mockPet = CustomerPetSummary(id: 10, userId: 1, name: 'Luna', breed: 'Poodle');
  const mockGroomer = SalonGroomer(id: 1, groomerCode: 'G001', name: 'Marisa Brown', firstName: 'Marisa', lastName: 'Brown', isAvailable: true);
  const mockService = ServiceItem(
    id: 12,
    name: 'Full Grooming',
    description: 'Full body haircut and bath',
    price: 60.0,
    priceDisplay: '\$60',
    durationMinutes: 45,
    isPackage: false,
    isAddOn: false,
  );

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  group('Groomer Portal Booking Time Slot and Date UI Match Tests', () {
    late _TestGroomerHomeRepo repo;
    late GroomerHomeBloc bloc;

    setUp(() {
      repo = _TestGroomerHomeRepo(
        customers: [mockCustomer],
        pets: [mockPet],
        groomers: [mockGroomer],
        services: [mockService],
        addOns: [],
      );
      bloc = GroomerHomeBloc(repository: repo);
    });

    tearDown(() {
      bloc.close();
    });

    testWidgets('1. Section 5 renders SharedCalendar matching Customer Portal date selection', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bloc.emit(bloc.state.copyWith(
        searchedCustomers: () => [mockCustomer],
        customerPets: () => [mockPet],
        salonGroomers: () => [mockGroomer],
        bookingServices: () => [mockService],
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  MainLineBookingDialog.show(
                    context,
                    loggedInGroomer: mockUser,
                    bloc: bloc,
                    onBookingCreated: () {},
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('5. Appointment Date'), findsOneWidget);
      expect(find.byType(SharedCalendar), findsOneWidget);
    });

    testWidgets('2. Section 6 renders 2-column GridView, exact legend and slot items matching Customer Portal', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bloc.emit(bloc.state.copyWith(
        searchedCustomers: () => [mockCustomer],
        customerPets: () => [mockPet],
        salonGroomers: () => [mockGroomer],
        bookingServices: () => [mockService],
        isSlotAvailable: () => true,
        availableTimeSlots: () => [
          {'startTime': '10:00:00', 'endTime': '10:45:00', 'groomerId': 1, 'isAvailable': true, 'remaining': 1},
          {'startTime': '11:00:00', 'endTime': '11:45:00', 'groomerId': 1, 'isAvailable': true, 'remaining': 1},
          {'startTime': '12:00:00', 'endTime': '12:45:00', 'groomerId': 1, 'isAvailable': false, 'remaining': 0},
        ],
        slotTotalPrice: () => 60.0,
        slotDurationMinutes: () => 45,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  MainLineBookingDialog.show(
                    context,
                    loggedInGroomer: mockUser,
                    bloc: bloc,
                    onBookingCreated: () {},
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify legend
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Selected'), findsOneWidget);
      expect(find.text('Already Booked'), findsOneWidget);

      // Verify GridView matching Customer Portal (crossAxisCount: 2, mainAxisExtent: 52 for isAny)
      final gridFinder = find.byType(GridView);
      expect(gridFinder, findsOneWidget);
      final grid = tester.widget<GridView>(gridFinder);
      final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);
      expect(delegate.mainAxisExtent, 52);
      expect(delegate.crossAxisSpacing, 10);
      expect(delegate.mainAxisSpacing, 10);

      // Verify slot format with start and end time texts and clock icon
      expect(find.text('10:00 AM'), findsWidgets);
      expect(find.text(' – 10:45 AM'), findsOneWidget);
      expect(find.text('11:00 AM'), findsWidgets);
      expect(find.text(' – 11:45 AM'), findsOneWidget);
      expect(find.byIcon(Icons.access_time_rounded), findsWidgets);

      // Verify duration subtitle
      expect(find.text('Service duration: 45 min  ·  Est. \$60'), findsOneWidget);
    });

    testWidgets('3. Empty slots state matches Customer Portal with Icons.event_busy_rounded', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bloc.emit(bloc.state.copyWith(
        searchedCustomers: () => [mockCustomer],
        customerPets: () => [mockPet],
        salonGroomers: () => [mockGroomer],
        bookingServices: () => [mockService],
        isSlotAvailable: () => true,
        availableTimeSlots: () => [],
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  MainLineBookingDialog.show(
                    context,
                    loggedInGroomer: mockUser,
                    bloc: bloc,
                    onBookingCreated: () {},
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('No Available Slots'), findsOneWidget);
      expect(find.byIcon(Icons.event_busy_rounded), findsOneWidget);
    });

    testWidgets('4. Loading slots state matches Customer Portal', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bloc.emit(bloc.state.copyWith(
        searchedCustomers: () => [mockCustomer],
        customerPets: () => [mockPet],
        salonGroomers: () => [mockGroomer],
        bookingServices: () => [mockService],
        isCheckingAvailability: () => true,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  MainLineBookingDialog.show(
                    context,
                    loggedInGroomer: mockUser,
                    bloc: bloc,
                    onBookingCreated: () {},
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Loading available slots…'), findsOneWidget);

      // Clean up dialog
      bloc.emit(bloc.state.copyWith(isCheckingAvailability: () => false));
      final closeBtn = find.byTooltip('Close');
      if (closeBtn.evaluate().isNotEmpty) {
        await tester.tap(closeBtn);
      }
      await tester.pumpAndSettle();
    });

    testWidgets('5. Groomer subtitle displayed for Any Groomer and slot tap selection works', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bloc.emit(bloc.state.copyWith(
        searchedCustomers: () => [mockCustomer],
        customerPets: () => [mockPet],
        salonGroomers: () => [mockGroomer],
        bookingServices: () => [mockService],
        isSlotAvailable: () => true,
        availableTimeSlots: () => [
          {
            'startTime': '09:00:00',
            'endTime': '10:00:00',
            'groomerId': 1,
            'groomerName': 'Marisa Brown',
            'isAvailable': true,
            'remaining': 1,
          },
          {
            'startTime': '11:00:00',
            'endTime': '12:00:00',
            'groomerId': 1,
            'groomerName': 'Marisa Brown',
            'isAvailable': true,
            'remaining': 1,
          },
        ],
        slotTotalPrice: () => 60.0,
        slotDurationMinutes: () => 60,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  MainLineBookingDialog.show(
                    context,
                    loggedInGroomer: mockUser,
                    bloc: bloc,
                    onBookingCreated: () {},
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // In Any Groomer context, groomer subtitle should be visible
      expect(find.text('Marisa Brown'), findsWidgets);
      expect(find.text('· '), findsWidgets);

      // Verify slot button border radius 14
      final containers = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
      final slotDecorations = containers
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.borderRadius == BorderRadius.circular(14))
          .toList();
      expect(slotDecorations.isNotEmpty, isTrue);

      // Tap 11:00 AM slot
      final slotFinder = find.text('11:00 AM');
      expect(slotFinder, findsOneWidget);
      await tester.ensureVisible(slotFinder);
      await tester.tap(slotFinder);
      await tester.pumpAndSettle();

      // Scroll to summary if needed and verify schedule display
      final summaryFinder = find.textContaining('11:00 AM – 12:00 PM');
      await tester.ensureVisible(summaryFinder);
      expect(summaryFinder, findsOneWidget);
    });
  });
}
