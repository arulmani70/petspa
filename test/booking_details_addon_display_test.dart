import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/booking_confirmed_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/booking_details_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/pets/bloc/pet_bloc.dart';
import 'package:shear_heaven_pet_spa/src/pets/repo/pet_repository.dart';

class _MockPetRepoForAddons extends PetRepository {
  @override
  Future<List<Map<String, dynamic>>> getAllPets({int? userId}) async => [];

  @override
  Future<Map<String, dynamic>?> getPetById(int id) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BookingDraft draft;
  late _MockPetRepoForAddons mockPetRepo;

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'test_token'});
    SharedPreferences.setMockInitialValues({'auth_token': 'test_token'});
    await ServicesLocator.initialize();

    mockPetRepo = _MockPetRepoForAddons();
    if (GetIt.I.isRegistered<PetRepository>()) {
      GetIt.I.unregister<PetRepository>();
    }
    GetIt.I.registerSingleton<PetRepository>(mockPetRepo);
  });

  setUp(() {
    draft = ServicesLocator.bookingDraft;
    draft.reset();
  });

  Widget buildTestWidget(Widget child) {
    return MaterialApp(
      home: BlocProvider<PetBloc>(
        create: (context) => PetBloc(repository: mockPetRepo),
        child: child,
      ),
    );
  }

  group('Customer Booking Details View Page - Add-on Display Tests', () {
    testWidgets(
      'When customer completes booking WITHOUT add-ons, view page does NOT show default add-ons',
      (tester) async {
        tester.view.physicalSize = const Size(400, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final bookingWithoutAddOns = <String, dynamic>{
          'booking_id': 'BKG-101',
          'status': 'confirmed',
          'service_name': 'Full Grooming',
          'pet_name': 'Charlie',
          'pet_breed': 'Labrador',
          'date_label': 'Nov 12, 2026',
          'time_label': '10:00 AM',
          'addOns': <Map<String, dynamic>>[],
          'addons': <Map<String, dynamic>>[],
          'has_addons': false,
          'addons_count': 0,
        };

        await tester.pumpWidget(
          buildTestWidget(
            BookingDetailsPageMobile(bookingData: bookingWithoutAddOns),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Should display service name "Full Grooming" without "+ Add On Services"
        expect(find.text('Full Grooming'), findsOneWidget);
        expect(find.text('Full Grooming + Add On Services'), findsNothing);

        // 2. Should NOT show "Add On Services" section header
        expect(find.text('Add On Services'), findsNothing);

        // 3. Should NOT show any default/mock add-ons
        expect(find.text('Nail Grinding'), findsNothing);
        expect(find.text('Teeth Brushing'), findsNothing);
        expect(find.text('Blueberry Facial'), findsNothing);
      },
    );

    testWidgets(
      'When customer completes booking WITH selected add-ons, view page shows ONLY selected add-ons',
      (tester) async {
        tester.view.physicalSize = const Size(400, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final bookingWithSelectedAddOns = <String, dynamic>{
          'booking_id': 'BKG-102',
          'status': 'confirmed',
          'service_name': 'Bath & Brush',
          'pet_name': 'Bella',
          'pet_breed': 'Golden Retriever',
          'date_label': 'Nov 14, 2026',
          'time_label': '02:00 PM',
          'addOns': [
            {'name': 'Flea Bath', 'price': 15.0},
          ],
          'has_addons': true,
          'addons_count': 1,
        };

        await tester.pumpWidget(
          buildTestWidget(
            BookingDetailsPageMobile(bookingData: bookingWithSelectedAddOns),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Should display service name with "+ Add On Services"
        expect(find.text('Bath & Brush + Add On Services'), findsOneWidget);

        // 2. Should show "Add On Services" section header
        expect(find.text('Add On Services'), findsOneWidget);

        // 3. Should show ONLY the selected add-on
        expect(find.text('Flea Bath'), findsOneWidget);

        // 4. Should NOT show unselected default add-ons
        expect(find.text('Nail Grinding'), findsNothing);
        expect(find.text('Teeth Brushing'), findsNothing);
        expect(find.text('Blueberry Facial'), findsNothing);
      },
    );

    testWidgets(
      'BookingConfirmedPageMobile does not show "+ Add On Services" when no add-ons are in draft.lastBooking',
      (tester) async {
        tester.view.physicalSize = const Size(400, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        draft.lastBooking = {
          'booking_id': 'BKG-103',
          'status': 'confirmed',
          'service_name': 'Full Grooming',
          'pet_name': 'Rocky',
          'pet_breed': 'Beagle',
          'date_label': 'Nov 15, 2026',
          'time_label': '11:00 AM',
          'addOns': <Map<String, dynamic>>[],
          'addons': <Map<String, dynamic>>[],
          'has_addons': false,
          'addons_count': 0,
        };

        await tester.pumpWidget(
          buildTestWidget(const BookingConfirmedPageMobile()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Full Grooming'), findsOneWidget);
        expect(find.text('Full Grooming + Add On Services'), findsNothing);
        expect(find.text('View'), findsOneWidget);
      },
    );
  });
}
