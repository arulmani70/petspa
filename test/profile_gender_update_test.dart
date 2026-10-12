import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:shear_heaven_pet_spa/src/account/bloc/profile_bloc.dart';
import 'package:shear_heaven_pet_spa/src/account/views/mobile/profile_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/auth/repo/auth_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/device_id_service.dart';

class _MockApiRepository extends ApiRepository {
  Map<String, dynamic>? profileData = {
    'name': 'Alex Smith',
    'email': 'alex@example.com',
    'mobile': '1234567890',
    'gender': 'male',
    'emailVerified': true,
  };

  Map<String, dynamic>? lastPutPayload;
  bool shouldFailUpdate = false;

  @override
  Future<Map<String, dynamic>?> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/api/auth/profile') {
      return {
        'success': true,
        'message': 'Profile fetched successfully',
        'data': profileData,
      };
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> putData(String path, Map<String, dynamic> data) async {
    if (path == '/api/auth/profile') {
      if (shouldFailUpdate) {
        return {
          'success': false,
          'message': 'Server error: unable to update profile',
        };
      }
      lastPutPayload = Map<String, dynamic>.from(data);
      profileData = {
        ...?profileData,
        ...data,
      };
      return {
        'success': true,
        'message': 'Profile updated successfully',
        'data': profileData,
      };
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> putMultipartData(String path, FormData formData) async {
    if (path == '/api/auth/profile') {
      if (shouldFailUpdate) {
        return {
          'success': false,
          'message': 'Server error: unable to update profile',
        };
      }
      final map = <String, dynamic>{};
      for (final field in formData.fields) {
        map[field.key] = field.value;
      }
      lastPutPayload = Map<String, dynamic>.from(map);
      profileData = {
        ...?profileData,
        ...map,
      };
      return {
        'success': true,
        'message': 'Profile updated successfully',
        'data': profileData,
      };
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockApiRepository mockApi;
  late SessionService sessionService;
  late AuthRepository authRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'user_data': '{"id":1,"name":"Alex Smith","email":"alex@example.com","mobile":"1234567890","gender":"male"}',
      'user_session': '1',
    });
    FlutterSecureStorage.setMockInitialValues({});

    sessionService = SessionService();
    await sessionService.initialize();
    await sessionService.saveSession({
      'id': 1,
      'name': 'Alex Smith',
      'email': 'alex@example.com',
      'mobile': '1234567890',
      'gender': 'male',
    });

    mockApi = _MockApiRepository();
    await mockApi.initialize();

    final deviceIdService = DeviceIdService();
    await deviceIdService.initialize();

    authRepository = AuthRepository();
    await authRepository.initialize();

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<SessionService>(sessionService);
    GetIt.I.registerSingleton<DeviceIdService>(deviceIdService);
    GetIt.I.registerSingleton<ApiRepository>(mockApi);
    GetIt.I.registerSingleton<AuthRepository>(authRepository);
  });

  group('Profile Gender Update Tests', () {
    test('AuthRepository includes gender in PUT payload and persists to session', () async {
      final updated = await authRepository.updateProfilePut(
        name: 'Alex Smith',
        mobile: '1234567890',
        gender: 'Female',
      );

      // Verify payload sent to backend API
      expect(mockApi.lastPutPayload?['gender'], equals('female'));

      // Verify returned data contains updated gender
      expect(updated['gender'], equals('female'));

      // Verify local session cache is updated
      final sessionUser = sessionService.getSessionUser();
      expect(sessionUser?['gender'], equals('female'));
    });

    test('AuthRepository getProfile preserves gender in merged session data', () async {
      // Set session user with female gender
      await sessionService.saveSession({
        'id': 1,
        'name': 'Alex Smith',
        'gender': 'female',
      });

      // Backend returns profile without explicit gender
      mockApi.profileData = {
        'id': 1,
        'name': 'Alex Smith',
        'email': 'alex@example.com',
      };

      final profile = await authRepository.getProfile();
      expect(profile['gender'], equals('female'));
    });

    test('ProfileBloc SaveProfileEvent correctly passes gender and updates state', () async {
      final bloc = ProfileBloc(repository: authRepository);
      bloc.add(const SaveProfileEvent(
        name: 'Alex Smith',
        mobile: '1234567890',
        gender: 'Female',
      ));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ProfileState>().having((s) => s.status, 'status', ProfileStatus.saving),
          isA<ProfileState>()
              .having((s) => s.status, 'status', ProfileStatus.success)
              .having((s) => s.profileData['gender'], 'gender', equals('female')),
        ]),
      );

      expect(mockApi.lastPutPayload?['gender'], equals('female'));
    });

    testWidgets('ProfilePageMobile changes gender from Male to Female, saves, and updates UI', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfilePageMobile(),
        ),
      );

      await tester.pumpAndSettle();

      // Find gender options
      final maleFinder = find.widgetWithText(Container, 'Male');
      final femaleFinder = find.widgetWithText(Container, 'Female');
      expect(maleFinder, findsOneWidget);
      expect(femaleFinder, findsOneWidget);

      // Tap Female option to change selection
      await tester.tap(femaleFinder);
      await tester.pumpAndSettle();

      // Tap Save Changes button
      final saveBtnFinder = find.text('Save Changes');
      expect(saveBtnFinder, findsOneWidget);
      await tester.ensureVisible(saveBtnFinder);
      await tester.tap(saveBtnFinder);
      await tester.pumpAndSettle();

      // Verify API was called with gender: 'female'
      expect(mockApi.lastPutPayload?['gender'], equals('female'));

      // Verify success message banner appears
      expect(find.text('Profile updated successfully.'), findsOneWidget);

      // Verify session was persisted with female gender
      final sessionUser = sessionService.getSessionUser();
      expect(sessionUser?['gender'], equals('female'));
    });

    testWidgets('ProfilePageMobile handles API error without showing success banner', (tester) async {
      mockApi.shouldFailUpdate = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: ProfilePageMobile(),
        ),
      );

      await tester.pumpAndSettle();

      final femaleFinder = find.widgetWithText(Container, 'Female');
      await tester.tap(femaleFinder);
      await tester.pumpAndSettle();

      final saveBtnFinder = find.text('Save Changes');
      await tester.ensureVisible(saveBtnFinder);
      await tester.tap(saveBtnFinder);
      await tester.pumpAndSettle();

      // Error message should be displayed, not success
      expect(find.text('Profile updated successfully.'), findsNothing);
      expect(find.textContaining('unable to update profile'), findsOneWidget);
    });
  });
}
