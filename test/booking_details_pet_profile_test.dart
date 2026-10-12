import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/booking_details_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/common/constants/constansts.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/pets/bloc/pet_bloc.dart';
import 'package:shear_heaven_pet_spa/src/pets/repo/pet_repository.dart';

class MockPetRepository extends PetRepository {
  List<Map<String, dynamic>> mockPets = [];

  @override
  Future<List<Map<String, dynamic>>> getAllPets({int? userId}) async {
    return mockPets;
  }

  @override
  Future<Map<String, dynamic>?> getPetById(int id) async {
    return mockPets.firstWhere(
      (p) => (p['id'] == id || p[Constants.database.COLUMN_ID] == id),
      orElse: () => <String, dynamic>{},
    );
  }
}

void main() {
  late MockPetRepository mockPetRepo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'token'});
    SharedPreferences.setMockInitialValues({'auth_token': 'token'});
    await ServicesLocator.initialize();
    await ServicesLocator.sessionService.saveSession({'id': 1, 'name': 'Test User'});

    mockPetRepo = MockPetRepository();
    if (GetIt.I.isRegistered<PetRepository>()) {
      GetIt.I.unregister<PetRepository>();
    }
    GetIt.I.registerSingleton<PetRepository>(mockPetRepo);
  });

  tearDownAll(() async {
    if (GetIt.I.isRegistered<PetRepository>()) {
      GetIt.I.unregister<PetRepository>();
    }
    GetIt.I.registerLazySingleton<PetRepository>(() => PetRepository());
  });

  group('BookingDetailsPageMobile Pet Profile & Image Consistency', () {
    testWidgets(
        'Displays matching pet profile details (name, breed, gender, weight, age) using petId from PetBloc',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final petData = {
        Constants.database.COLUMN_ID: 105,
        'id': 105,
        Constants.database.COLUMN_PET_NAME: 'Maximus',
        'name': 'Maximus',
        Constants.database.COLUMN_BREED: 'Golden Retriever',
        'gender': 'Male',
        Constants.database.COLUMN_WEIGHT: '32',
        Constants.database.COLUMN_BIRTH_DATE: '2021-06-15',
        Constants.database.COLUMN_PHOTO_URL: 'https://example.com/maximus.jpg',
      };

      mockPetRepo.mockPets = [petData];
      final petBloc = PetBloc(repository: mockPetRepo);
      petBloc.emit(petBloc.state.copyWith(pets: () => [petData], status: () => PetStatus.loaded));

      // Booking payload that only has petId (like real upcoming bookings endpoint)
      final bookingData = {
        'id': 77,
        'petId': 105,
        'service_name': 'Full Grooming',
        'status': 'confirmed',
        'date_label': 'Aug 10, 2026',
        'time_label': '10:00 AM',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<PetBloc>.value(
            value: petBloc,
            child: Scaffold(
              body: BookingDetailsPageMobile(bookingData: bookingData),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Pet Name
      expect(find.text('Maximus'), findsOneWidget);
      // Not hardcoded "Teddy"
      expect(find.text('Teddy'), findsNothing);

      // Breed & Gender
      expect(find.textContaining('Golden Retriever'), findsOneWidget);
      expect(find.textContaining('Male'), findsOneWidget);
      // Not hardcoded "Shih Tzu"
      expect(find.textContaining('Shih Tzu'), findsNothing);

      // Weight (32kg)
      expect(find.textContaining('32kg'), findsOneWidget);

      // Age (computed from 2021-06-15, e.g. 5yrs in 2026)
      expect(find.textContaining('5yrs'), findsOneWidget);
    });

    testWidgets(
        'Reflects real-time pet updates when PetBloc updates the pet profile',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final initialPet = {
        Constants.database.COLUMN_ID: 202,
        'id': 202,
        Constants.database.COLUMN_PET_NAME: 'Bella',
        Constants.database.COLUMN_BREED: 'Poodle',
        'gender': 'Female',
        Constants.database.COLUMN_WEIGHT: '10',
        Constants.database.COLUMN_BIRTH_DATE: '2023-01-01',
      };

      mockPetRepo.mockPets = [initialPet];
      final petBloc = PetBloc(repository: mockPetRepo);
      petBloc.emit(petBloc.state.copyWith(pets: () => [initialPet], status: () => PetStatus.loaded));

      final bookingData = {
        'id': 88,
        'petId': 202,
        'service_name': 'Bath & Brush',
        'status': 'confirmed',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<PetBloc>.value(
            value: petBloc,
            child: Scaffold(
              body: BookingDetailsPageMobile(bookingData: bookingData),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Bella'), findsOneWidget);
      expect(find.textContaining('10kg'), findsOneWidget);

      // Update pet weight and name in PetBloc
      final updatedPet = {
        Constants.database.COLUMN_ID: 202,
        'id': 202,
        Constants.database.COLUMN_PET_NAME: 'Bella Luna',
        Constants.database.COLUMN_BREED: 'Poodle',
        'gender': 'Female',
        Constants.database.COLUMN_WEIGHT: '14',
        Constants.database.COLUMN_BIRTH_DATE: '2023-01-01',
      };

      petBloc.emit(petBloc.state.copyWith(pets: () => [updatedPet]));
      await tester.pumpAndSettle();

      // UI immediately displays updated name and weight
      expect(find.text('Bella Luna'), findsOneWidget);
      expect(find.textContaining('14kg'), findsOneWidget);
    });

    testWidgets(
        'Gracefully handles null or missing pet image and displays placeholder asset',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final petData = {
        Constants.database.COLUMN_ID: 303,
        'id': 303,
        Constants.database.COLUMN_PET_NAME: 'Charlie',
        Constants.database.COLUMN_BREED: 'Beagle',
        'gender': 'Male',
        Constants.database.COLUMN_WEIGHT: '18kg',
        Constants.database.COLUMN_PHOTO_URL: null,
      };

      mockPetRepo.mockPets = [petData];
      final petBloc = PetBloc(repository: mockPetRepo);
      petBloc.emit(petBloc.state.copyWith(pets: () => [petData], status: () => PetStatus.loaded));

      final bookingData = {
        'id': 99,
        'petId': 303,
        'service_name': 'Full Grooming',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<PetBloc>.value(
            value: petBloc,
            child: Scaffold(
              body: BookingDetailsPageMobile(bookingData: bookingData),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Charlie'), findsOneWidget);
      // Verifies Image.asset placeholder renders without exceptions
      expect(find.byType(Image), findsWidgets);
    });

    testWidgets(
        'Maps relative pet image URL to backend BASE_URL correctly',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final petData = {
        Constants.database.COLUMN_ID: 404,
        'id': 404,
        Constants.database.COLUMN_PET_NAME: 'Rocky',
        Constants.database.COLUMN_BREED: 'Bulldog',
        'gender': 'Male',
        Constants.database.COLUMN_WEIGHT: '20kg',
        Constants.database.COLUMN_PHOTO_URL: '/uploads/pets/rocky.jpg',
      };

      mockPetRepo.mockPets = [petData];
      final petBloc = PetBloc(repository: mockPetRepo);
      petBloc.emit(petBloc.state.copyWith(pets: () => [petData], status: () => PetStatus.loaded));

      final bookingData = {
        'id': 111,
        'petId': 404,
        'service_name': 'Full Grooming',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<PetBloc>.value(
            value: petBloc,
            child: Scaffold(
              body: BookingDetailsPageMobile(bookingData: bookingData),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Rocky'), findsOneWidget);
      final imageWidgetFinder = find.byWidgetPredicate((widget) {
        if (widget is Image && widget.image is NetworkImage) {
          final netImg = widget.image as NetworkImage;
          return netImg.url == '${Constants.app.BASE_URL}/uploads/pets/rocky.jpg';
        }
        return false;
      });
      expect(imageWidgetFinder, findsOneWidget);
    });

    test('GroomerBooking model parses petId from top-level and nested structures and normalizes images', () {
      final jsonWithTopLevelPetId = {
        'bookingId': 501,
        'petId': 12,
        'petName': 'Buddy',
        'petProfilePicture': '/uploads/pets/buddy.jpg',
        'customerName': 'Jane',
        'serviceName': 'Bath',
      };

      final booking1 = GroomerBooking.fromJson(jsonWithTopLevelPetId);
      expect(booking1.petId, 12);
      expect(booking1.petName, 'Buddy');
      expect(booking1.profilePicture, '${Constants.app.BASE_URL}/uploads/pets/buddy.jpg');

      final jsonWithNestedPet = {
        'bookingId': 502,
        'pet': {
          'id': 15,
          'petName': 'Milo',
          'breed': 'Husky',
          'profilePictureUrl': 'https://custom-domain.com/milo.jpg',
        },
        'customerName': 'John',
        'serviceName': 'Grooming',
      };

      final booking2 = GroomerBooking.fromJson(jsonWithNestedPet);
      expect(booking2.petId, 15);
      expect(booking2.petName, 'Milo');
      expect(booking2.breed, 'Husky');
      expect(booking2.profilePicture, 'https://custom-domain.com/milo.jpg');
    });
  });
}
