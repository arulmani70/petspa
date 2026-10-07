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

class _BottomSheetTestRepo extends GroomerHomeRepository {
  final List<CustomerSummary> customers;
  final List<CustomerPetSummary> pets;
  final List<SalonGroomer> groomers;
  final List<ServiceItem> services;
  final List<ServiceItem> addOns;

  _BottomSheetTestRepo({
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
            {'startTime': '23:00:00', 'endTime': '23:45:00', 'groomerId': 1, 'isAvailable': true, 'remaining': 1}
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
  const mockAddOn = ServiceItem(
    id: 2,
    name: 'Nail Polish',
    description: 'Pet safe nail color',
    price: 15.0,
    priceDisplay: '\$15',
    durationMinutes: 10,
    isPackage: false,
    isAddOn: true,
  );

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  group('MainLineBookingDialog Bottom Sheet Presentation Tests', () {
    late _BottomSheetTestRepo repo;
    late GroomerHomeBloc bloc;

    setUp(() {
      repo = _BottomSheetTestRepo(
        customers: [mockCustomer],
        pets: [mockPet],
        groomers: [mockGroomer],
        services: [mockService],
        addOns: [mockAddOn],
      );
      bloc = GroomerHomeBloc(repository: repo);
      bloc.emit(bloc.state.copyWith(
        searchedCustomers: () => [mockCustomer],
        customerPets: () => [mockPet],
        salonGroomers: () => [mockGroomer],
        bookingServices: () => [mockService],
        bookingAddOns: () => [mockAddOn],
        isSlotAvailable: () => true,
        availableTimeSlots: () => [
          {'startTime': '23:00:00', 'endTime': '23:45:00', 'groomerId': 1, 'isAvailable': true, 'remaining': 1}
        ],
        slotTotalPrice: () => 60.0,
        slotDurationMinutes: () => 45,
      ));
    });

    tearDown(() {
      bloc.close();
    });

    testWidgets('1. Opens from bottom via MainLineBookingDialog.show with slide animation', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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
                child: const Text('Open Booking Sheet'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Main-Line Call Booking'), findsNothing);

      await tester.tap(find.text('Open Booking Sheet'));
      // Step halfway through opening animation
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Main-Line Call Booking'), findsOneWidget);

      // Complete opening animation
      await tester.pumpAndSettle();
      expect(find.text('Main-Line Call Booking'), findsOneWidget);
      expect(find.text('Alice Smith'), findsOneWidget);
      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('(Poodle)'), findsOneWidget);
      expect(find.text('Confirm Appointment • \$60'), findsOneWidget);
    });

    testWidgets('2. Close button smoothly dismisses the bottom sheet', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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
                child: const Text('Open Booking Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Booking Sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Main-Line Call Booking'), findsOneWidget);

      // Tap Close icon button
      final closeIcon = find.byTooltip('Close');
      expect(closeIcon, findsOneWidget);
      await tester.tap(closeIcon);
      await tester.pumpAndSettle();

      expect(find.text('Main-Line Call Booking'), findsNothing);
    });

    testWidgets('3. Cancel button dismisses the bottom sheet', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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
                child: const Text('Open Booking Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Booking Sheet'));
      await tester.pumpAndSettle();

      final cancelButton = find.widgetWithText(TextButton, 'Cancel');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(find.text('Main-Line Call Booking'), findsNothing);
    });

    testWidgets('4. Responsive layout on 360px width without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

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

      expect(tester.takeException(), isNull);
      expect(find.text('Main-Line Call Booking'), findsOneWidget);
      expect(find.text('Confirm Appointment • \$60'), findsOneWidget);
    });

    testWidgets('5. Responsive layout on 375px width with keyboard open without overflow', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetViewInsets();
      });

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

      expect(tester.takeException(), isNull);
      expect(find.text('Main-Line Call Booking'), findsOneWidget);
      expect(find.text('Confirm Appointment • \$60'), findsOneWidget);
    });

    testWidgets('6. Successful booking confirms and closes the sheet automatically', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool bookingCreatedCalled = false;

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
                    onBookingCreated: () {
                      bookingCreatedCalled = true;
                    },
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

      final confirmButton = find.widgetWithText(ElevatedButton, 'Confirm Appointment • \$60');
      expect(confirmButton, findsOneWidget);
      await tester.tap(confirmButton);
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(bookingCreatedCalled, isTrue);
      expect(find.text('Main-Line Call Booking'), findsNothing);
    });
  });
}
