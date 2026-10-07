import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/auth/repo/auth_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/device_id_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';

class MockApiRepository extends ApiRepository {
  Map<String, dynamic>? lastPostPayload;
  String? lastPostPath;
  Map<String, dynamic>? mockResponse;

  @override
  Future<Map<String, dynamic>?> post(String path, dynamic data, {Map<String, dynamic>? query}) async {
    lastPostPath = path;
    lastPostPayload = data is Map<String, dynamic> ? data : null;
    return mockResponse;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockApiRepository mockApi;
  late DeviceIdService deviceIdService;
  late SessionService sessionService;
  late AuthRepository authRepository;

  const testDeviceId = '550e8400-e29b-41d4-a716-446655440000';

  setUp(() async {
    await GetIt.instance.reset();
    FlutterSecureStorage.setMockInitialValues({
      DeviceIdService.storageKey: testDeviceId,
    });
    SharedPreferences.setMockInitialValues({});

    mockApi = MockApiRepository();
    deviceIdService = DeviceIdService(secureStorage: const FlutterSecureStorage());
    sessionService = SessionService();
    await sessionService.initialize();

    GetIt.instance.registerSingleton<ApiRepository>(mockApi);
    GetIt.instance.registerSingleton<DeviceIdService>(deviceIdService);
    GetIt.instance.registerSingleton<SessionService>(sessionService);

    authRepository = AuthRepository();
    GetIt.instance.registerSingleton<AuthRepository>(authRepository);

    await deviceIdService.initialize();
  });

  group('Auth Multi-Device Integration Tests', () {
    test('Register payload includes the persistent deviceId', () async {
      mockApi.mockResponse = {
        'success': true,
        'message': 'OTP sent to email',
      };

      await authRepository.register(
        name: 'John Doe',
        email: 'john@example.com',
        phone: '9876543210',
        password: 'Password@123',
      );

      expect(mockApi.lastPostPath, equals('/api/auth/signup'));
      expect(mockApi.lastPostPayload, isNotNull);
      expect(mockApi.lastPostPayload?['deviceId'], equals(testDeviceId));
      expect(mockApi.lastPostPayload?['email'], equals('john@example.com'));
    });

    test('Login payload includes the persistent deviceId', () async {
      mockApi.mockResponse = {
        'success': true,
        'data': {
          'accessToken': 'access_token_123',
          'refreshToken': 'refresh_token_123',
          'user': {'id': 1, 'name': 'John Doe', 'email': 'john@example.com'},
        }
      };

      final user = await authRepository.login(
        email: 'john@example.com',
        password: 'Password@123',
      );

      expect(mockApi.lastPostPath, equals('/api/auth/login'));
      expect(mockApi.lastPostPayload, isNotNull);
      expect(mockApi.lastPostPayload?['deviceId'], equals(testDeviceId));
      expect(mockApi.lastPostPayload?['email'], equals('john@example.com'));
      expect((user['user'] ?? user)['id'], equals(1));
    });

    test('Send OTP payload includes the persistent deviceId', () async {
      mockApi.mockResponse = {
        'success': true,
        'message': 'OTP sent successfully',
      };

      await authRepository.sendOtp('john@example.com');

      expect(mockApi.lastPostPath, equals('/api/auth/send-otp'));
      expect(mockApi.lastPostPayload?['deviceId'], equals(testDeviceId));
    });

    test('Validate Device payload includes the persistent deviceId and userType', () async {
      mockApi.mockResponse = {
        'success': true,
        'data': {'deviceToken': 'dev_token_123'},
      };

      final res = await authRepository.validateDevice(userType: 'guest');

      expect(mockApi.lastPostPath, equals('/api/auth/validate-device'));
      expect(mockApi.lastPostPayload?['deviceId'], equals(testDeviceId));
      expect(mockApi.lastPostPayload?['userType'], equals('guest'));
      expect(res?['success'], isTrue);
    });

    test('Login error handling when maximum 5 devices limit is reached', () async {
      mockApi.mockResponse = {
        'success': false,
        'code': 'DEVICE_LIMIT_REACHED',
        'message': 'Maximum devices limit reached for this account',
      };

      expect(
        () async => await authRepository.login(
          email: 'john@example.com',
          password: 'Password@123',
        ),
        throwsA(predicate((e) =>
            e.toString().contains('5 devices') ||
            e.toString().contains('Maximum registered device limit'))),
      );
    });
  });
}
