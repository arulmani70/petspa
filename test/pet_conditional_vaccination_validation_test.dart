import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/pets/bloc/pet_bloc.dart';
import 'package:shear_heaven_pet_spa/src/pets/repo/pet_repository.dart';
import 'package:shear_heaven_pet_spa/src/pets/views/mobile/create_pet_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/store/repo/store_repository.dart';

class MockApiRepository extends ApiRepository {
  FormData? lastPostMultipartFormData;
  String? lastPostMultipartPath;
  FormData? lastPutMultipartFormData;
  String? lastPutMultipartPath;

  bool shouldFailCreate = false;
  String? customErrorMessage;

  @override
  Future<Map<String, dynamic>?> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/api/pet-weights') {
      return {
        'success': true,
        'data': [
          {'name': 'Small'},
          {'name': 'Medium'},
          {'name': 'Large'},
          {'name': 'Extra Large'},
        ],
      };
    }
    if (path == '/api/pets') {
      return {
        'success': true,
        'data': {'pets': []},
      };
    }
    return {'success': true, 'data': {}};
  }

  @override
  Future<Map<String, dynamic>?> postMultipart(String path, FormData data) async {
    lastPostMultipartPath = path;
    lastPostMultipartFormData = data;
    if (shouldFailCreate) {
      return {
        'success': false,
        'message': customErrorMessage ?? 'Server rejected pet creation',
      };
    }
    return {
      'success': true,
      'data': {'id': 99},
    };
  }

  @override
  Future<bool> putMultipart(String path, FormData data) async {
    lastPutMultipartPath = path;
    lastPutMultipartFormData = data;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockApiRepository mockApi;
  late PetRepository petRepo;
  late StoreRepository storeRepo;
  late SessionService sessionService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'user_data': '{"id":1,"name":"Test User","email":"test@example.com"}',
      'user_session': '1',
    });

    mockApi = MockApiRepository();
    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<ApiRepository>(mockApi);

    sessionService = SessionService();
    GetIt.I.registerSingleton<SessionService>(sessionService);

    storeRepo = StoreRepository();
    GetIt.I.registerSingleton<StoreRepository>(storeRepo);

    petRepo = PetRepository();
    GetIt.I.registerSingleton<PetRepository>(petRepo);
  });

  group('PetRepository Vaccination Payload Contract', () {
    test('createPet with vaccinated=Yes sends allVaccinatedCurrent=true and lastVaccinatedDate', () async {
      final petData = <String, dynamic>{
        Constants.database.COLUMN_PET_NAME: 'Max',
        Constants.database.COLUMN_BREED: 'Poodle',
        Constants.database.COLUMN_WEIGHT: 'Medium',
        'age': '2 Years',
        'gender': 'male',
        Constants.database.COLUMN_NOTES: 'None',
        Constants.database.COLUMN_PHOTO_URL: 'assets/images/common/pet_1.png',
        'allVaccinatedCurrent': 'true',
        'lastVaccinatedDate': '2025-05-10',
        'behaviorNotes': 'Friendly',
      };

      await petRepo.createPet(petData);

      expect(mockApi.lastPostMultipartPath, equals('/api/pets'));
      expect(mockApi.lastPostMultipartFormData, isNotNull);

      final fields = Map.fromEntries(mockApi.lastPostMultipartFormData!.fields);
      expect(fields['allVaccinatedCurrent'], equals('true'));
      expect(fields['lastVaccinatedDate'], equals('2025-05-10'));
    });

    test('createPet with vaccinated=No sends allVaccinatedCurrent=false and omits lastVaccinatedDate', () async {
      final petData = <String, dynamic>{
        Constants.database.COLUMN_PET_NAME: 'Charlie',
        Constants.database.COLUMN_BREED: 'Beagle',
        Constants.database.COLUMN_WEIGHT: 'Small',
        'age': '1 Year',
        'gender': 'female',
        Constants.database.COLUMN_NOTES: 'None',
        Constants.database.COLUMN_PHOTO_URL: 'assets/images/common/pet_1.png',
        'allVaccinatedCurrent': 'false',
        'lastVaccinatedDate': null,
        'behaviorNotes': 'Playful',
      };

      await petRepo.createPet(petData);

      expect(mockApi.lastPostMultipartPath, equals('/api/pets'));
      expect(mockApi.lastPostMultipartFormData, isNotNull);

      final fields = Map.fromEntries(mockApi.lastPostMultipartFormData!.fields);
      expect(fields['allVaccinatedCurrent'], equals('false'));
      expect(fields.containsKey('lastVaccinatedDate'), isFalse);
    });

    test('updatePet with vaccinated=No sends allVaccinatedCurrent=false and omits lastVaccinatedDate', () async {
      final petData = <String, dynamic>{
        Constants.database.COLUMN_PET_NAME: 'Bella',
        Constants.database.COLUMN_BREED: 'Bulldog',
        Constants.database.COLUMN_WEIGHT: 'Medium',
        'age': '3 Years',
        'gender': 'female',
        Constants.database.COLUMN_NOTES: 'None',
        Constants.database.COLUMN_PHOTO_URL: 'assets/images/common/pet_1.png',
        'allVaccinatedCurrent': 'false',
        'lastVaccinatedDate': null,
        'behaviorNotes': 'Calm',
      };

      await petRepo.updatePet(42, petData);

      expect(mockApi.lastPutMultipartPath, equals('/api/pets/42'));
      expect(mockApi.lastPutMultipartFormData, isNotNull);

      final fields = Map.fromEntries(mockApi.lastPutMultipartFormData!.fields);
      expect(fields['allVaccinatedCurrent'], equals('false'));
      expect(fields.containsKey('lastVaccinatedDate'), isFalse);
    });

    test('createPet surfaces custom error message on API failure', () async {
      mockApi.shouldFailCreate = true;
      mockApi.customErrorMessage = 'Vaccination date is invalid';

      final petData = <String, dynamic>{
        Constants.database.COLUMN_PET_NAME: 'Rocky',
        Constants.database.COLUMN_PHOTO_URL: 'assets/images/common/pet_1.png',
        'allVaccinatedCurrent': 'true',
        'lastVaccinatedDate': '2025-01-01',
      };

      expect(
        () => petRepo.createPet(petData),
        throwsA(predicate((e) => e.toString().contains('Vaccination date is invalid'))),
      );
    });
  });

  group('CreatePetPageMobile UI Conditional Vaccination Validation', () {
    testWidgets('Vaccinated = Yes requires vaccination date, shows red border and inline error on submit', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final petBloc = PetBloc(repository: petRepo);

      // Open in Edit mode with existing pet data but no vaccination date and vaccinated = Yes
      final petData = <String, dynamic>{
        Constants.database.COLUMN_ID: 10,
        Constants.database.COLUMN_PET_NAME: 'Buddy',
        Constants.database.COLUMN_BREED: 'Golden Retriever',
        Constants.database.COLUMN_WEIGHT: 'Large',
        'age': '2 Years',
        'gender': 'male',
        Constants.database.COLUMN_PHOTO_URL: 'assets/images/common/pet_1.png',
        'allVaccinatedCurrent': 'true',
        'lastVaccinatedDate': null,
      };

      final router = GoRouter(
        initialLocation: '/create-pet',
        routes: [
          GoRoute(
            path: '/create-pet',
            builder: (context, state) => BlocProvider<PetBloc>.value(
              value: petBloc,
              child: const CreatePetPageMobile(),
            ),
          ),
        ],
        initialExtra: {'pet': petData},
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Verify "Last Vaccinated Date" title is shown (mandatory)
      expect(find.text('Last Vaccinated Date'), findsOneWidget);
      expect(find.text('Last Vaccinated Date (Optional)'), findsNothing);

      // Verify no error is displayed initially
      expect(find.text('Please select last vaccination date'), findsNothing);

      // Tap Save & Continue
      final saveBtn = find.text('Save & Continue');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Error message should appear
      expect(find.text('Please select last vaccination date'), findsOneWidget);

      // Verify red border on the date field container
      final dateFinder = find.ancestor(
        of: find.text('eg: 03-08-2025'),
        matching: find.byType(Container),
      ).first;
      final container = tester.widget<Container>(dateFinder);
      final decoration = container.decoration as BoxDecoration;
      expect((decoration.border as Border).top.color, equals(Colors.red));
      expect((decoration.border as Border).top.width, equals(1.5));
    });

    testWidgets('Vaccinated = No makes vaccination date optional and allows submission without date', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final petData = <String, dynamic>{
        Constants.database.COLUMN_ID: 11,
        Constants.database.COLUMN_PET_NAME: 'Milo',
        Constants.database.COLUMN_BREED: 'Poodle',
        Constants.database.COLUMN_WEIGHT: 'Small',
        'age': '1 Year',
        'gender': 'female',
        Constants.database.COLUMN_PHOTO_URL: 'assets/images/common/pet_1.png',
        'allVaccinatedCurrent': 'false',
        'lastVaccinatedDate': null,
      };

      final router = GoRouter(
        initialLocation: '/create-pet',
        routes: [
          GoRoute(
            path: '/create-pet',
            builder: (context, state) => BlocProvider<PetBloc>.value(
              value: PetBloc(repository: petRepo),
              child: const CreatePetPageMobile(),
            ),
          ),
          GoRoute(
            path: '/my-pets',
            name: RouteNames.myPets,
            builder: (context, state) => const Scaffold(body: Text('My Pets Screen')),
          ),
        ],
        initialExtra: {'pet': petData},
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Verify "Last Vaccinated Date (Optional)" label
      expect(find.text('Last Vaccinated Date (Optional)'), findsOneWidget);
      expect(find.text('Last Vaccinated Date'), findsNothing);

      // Tap Save & Continue
      final saveBtn = find.text('Save & Continue');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Validation error should NOT appear
      expect(find.text('Please select last vaccination date'), findsNothing);

      // Verify PUT API was invoked with allVaccinatedCurrent = false and no lastVaccinatedDate
      expect(mockApi.lastPutMultipartFormData, isNotNull);
      final fields = Map.fromEntries(mockApi.lastPutMultipartFormData!.fields);
      expect(fields['allVaccinatedCurrent'], equals('false'));
      expect(fields.containsKey('lastVaccinatedDate'), isFalse);
    });

    testWidgets('Switching from Yes with date to No clears date and clears validation error', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final petData = <String, dynamic>{
        Constants.database.COLUMN_ID: 12,
        Constants.database.COLUMN_PET_NAME: 'Luna',
        Constants.database.COLUMN_BREED: 'Shih Tzu',
        Constants.database.COLUMN_WEIGHT: 'Small',
        'age': '2 Years',
        'gender': 'female',
        Constants.database.COLUMN_PHOTO_URL: 'assets/images/common/pet_1.png',
        'allVaccinatedCurrent': 'true',
        'lastVaccinatedDate': '2025-06-15',
      };

      final router = GoRouter(
        initialLocation: '/create-pet',
        routes: [
          GoRoute(
            path: '/create-pet',
            builder: (context, state) => BlocProvider<PetBloc>.value(
              value: PetBloc(repository: petRepo),
              child: const CreatePetPageMobile(),
            ),
          ),
          GoRoute(
            path: '/my-pets',
            name: RouteNames.myPets,
            builder: (context, state) => const Scaffold(body: Text('My Pets Screen')),
          ),
        ],
        initialExtra: {'pet': petData},
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Date should initially be formatted and displayed
      expect(find.text('15-06-2025'), findsOneWidget);
      expect(find.text('Last Vaccinated Date'), findsOneWidget);

      // Switch to "No"
      final noText = find.text('No');
      await tester.ensureVisible(noText);
      await tester.tap(noText);
      await tester.pumpAndSettle();

      // Label should update to (Optional)
      expect(find.text('Last Vaccinated Date (Optional)'), findsOneWidget);
      // Date value should be cleared and hint restored
      expect(find.text('15-06-2025'), findsNothing);
      expect(find.text('eg: 03-08-2025'), findsOneWidget);

      // Tap Save & Continue
      final saveBtn = find.text('Save & Continue');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Validation error should NOT be triggered
      expect(find.text('Please select last vaccination date'), findsNothing);

      // Put multipart payload sends allVaccinatedCurrent = false and no lastVaccinatedDate
      expect(mockApi.lastPutMultipartFormData, isNotNull);
      final fields = Map.fromEntries(mockApi.lastPutMultipartFormData!.fields);
      expect(fields['allVaccinatedCurrent'], equals('false'));
      expect(fields.containsKey('lastVaccinatedDate'), isFalse);
    });

    testWidgets('Switching from Yes with error to No immediately dismisses error border and message', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final petData = <String, dynamic>{
        Constants.database.COLUMN_ID: 13,
        Constants.database.COLUMN_PET_NAME: 'Cooper',
        Constants.database.COLUMN_BREED: 'Labrador',
        Constants.database.COLUMN_WEIGHT: 'Large',
        'age': '4 Years',
        'gender': 'male',
        Constants.database.COLUMN_PHOTO_URL: 'assets/images/common/pet_1.png',
        'allVaccinatedCurrent': 'true',
        'lastVaccinatedDate': null,
      };

      final router = GoRouter(
        initialLocation: '/create-pet',
        routes: [
          GoRoute(
            path: '/create-pet',
            builder: (context, state) => BlocProvider<PetBloc>.value(
              value: PetBloc(repository: petRepo),
              child: const CreatePetPageMobile(),
            ),
          ),
        ],
        initialExtra: {'pet': petData},
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Tap Save & Continue to trigger error
      final saveBtn = find.text('Save & Continue');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Error message is visible
      expect(find.text('Please select last vaccination date'), findsOneWidget);

      // Now tap "No"
      final noText = find.text('No');
      await tester.ensureVisible(noText);
      await tester.tap(noText);
      await tester.pumpAndSettle();

      // Error message should disappear immediately
      expect(find.text('Please select last vaccination date'), findsNothing);

      // Date container border should no longer be red
      final dateFinder = find.ancestor(
        of: find.text('eg: 03-08-2025'),
        matching: find.byType(Container),
      ).first;
      final container = tester.widget<Container>(dateFinder);
      final decoration = container.decoration as BoxDecoration;
      expect((decoration.border as Border).top.color, isNot(equals(Colors.red)));
    });
  });
}
