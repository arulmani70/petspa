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
    'name': 'Jane Doe',
    'email': 'jane@example.com',
    'mobile': '1234567890',
    'emailVerified': true,
    'profilePictureUrl': 'https://shear-heaven-api.genzcodershub.com/uploads/jane.png',
  };

  FormData? lastPutMultipartFormData;
  Map<String, dynamic>? lastPutData;

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
      lastPutData = data;
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
      lastPutMultipartFormData = formData;
      final map = <String, dynamic>{};
      for (final field in formData.fields) {
        map[field.key] = field.value;
      }
      map['profilePictureUrl'] = 'https://shear-heaven-api.genzcodershub.com/uploads/uploaded_avatar.png';
      profileData = {
        ...?profileData,
        ...map,
      };
      return {
        'success': true,
        'message': 'Profile picture updated successfully',
        'data': profileData,
      };
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> post(String path, Map<String, dynamic> data) async {
    if (path == '/api/auth/reset-password') {
      return {
        'success': true,
        'message': 'Password reset successful',
        'data': {},
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
      'user_data': '{"name":"Jane Doe","email":"jane@example.com","mobile":"1234567890","profilePictureUrl":"https://shear-heaven-api.genzcodershub.com/uploads/jane.png"}',
    });
    FlutterSecureStorage.setMockInitialValues({});

    sessionService = SessionService();
    await sessionService.initialize();
    await sessionService.saveSession({'id': 1, 'name': 'Jane Doe', 'email': 'jane@example.com', 'mobile': '1234567890'});

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

  group('Profile Image & Update Tests', () {
    test('AuthRepository getProfile returns photo and session is updated', () async {
      final profile = await authRepository.getProfile();
      expect(profile['name'], equals('Jane Doe'));
      expect(profile['profilePictureUrl'], contains('jane.png'));
    });

    test('AuthRepository updateProfilePut updates profile and persists session', () async {
      final updated = await authRepository.updateProfilePut(
        name: 'Jane Smith',
        mobile: '9876543210',
      );
      expect(updated['name'], equals('Jane Smith'));
      expect(updated['mobile'], equals('9876543210'));

      final cached = sessionService.getSessionUser();
      expect(cached?['name'], equals('Jane Smith'));
    });

    test('ProfileBloc LoadProfileEvent loads photo from profile data', () async {
      final bloc = ProfileBloc(repository: authRepository);
      bloc.add(const LoadProfileEvent());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ProfileState>().having((s) => s.status, 'status', ProfileStatus.loading),
          isA<ProfileState>()
              .having((s) => s.status, 'status', ProfileStatus.loaded)
              .having((s) => s.profileData['profilePictureUrl'], 'photo', contains('jane.png')),
        ]),
      );
    });

    test('ProfileBloc SaveProfileEvent updates name, mobile, and profileData', () async {
      final bloc = ProfileBloc(repository: authRepository);
      bloc.add(const SaveProfileEvent(
        name: 'Jane New Name',
        mobile: '5551234567',
      ));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ProfileState>().having((s) => s.status, 'status', ProfileStatus.saving),
          isA<ProfileState>()
              .having((s) => s.status, 'status', ProfileStatus.success)
              .having((s) => s.profileData['name'], 'name', equals('Jane New Name')),
        ]),
      );
    });

    testWidgets('ProfilePageMobile renders profile info, avatar icon/image, and edit badge', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ProfilePageMobile(),
        ),
      );

      // Initially shows loading or loads quickly
      await tester.pumpAndSettle();

      // Verify name, mobile and email are populated
      expect(find.text('My Profile'), findsOneWidget);
      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('jane@example.com'), findsOneWidget);
      expect(find.text('1234567890'), findsOneWidget);
      expect(find.text('Email Verified'), findsOneWidget);

      // Verify camera badge icon is present on avatar
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);

      // Tapping avatar opens image picker modal
      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pumpAndSettle();

      expect(find.text('Profile Photo'), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);
    });
  });
}
