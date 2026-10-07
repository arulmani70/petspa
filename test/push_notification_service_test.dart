import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/device_id_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/push_notification_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/notifications/repo/notification_repository.dart';

class _MockApiRepository extends ApiRepository {
  String? lastPostPath;
  dynamic lastPostData;
  Map<String, dynamic>? mockPostResponse;

  @override
  Future<Map<String, dynamic>?> post(String path, dynamic data, {Map<String, dynamic>? query}) async {
    lastPostPath = path;
    lastPostData = data;
    return mockPostResponse ?? {'success': true, 'message': 'Device token registered successfully'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockApiRepository mockApi;
  late SessionService sessionService;
  late DeviceIdService deviceIdService;
  late NotificationRepository notificationRepo;
  late PushNotificationService pushNotificationService;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({
      'device_id': '550e8400-e29b-41d4-a716-446655440000',
    });
    SharedPreferences.setMockInitialValues({});

    mockApi = _MockApiRepository();
    sessionService = SessionService();
    await sessionService.initialize();
    await sessionService.saveSession({'id': 101, 'name': 'Test Customer'});

    deviceIdService = DeviceIdService();
    await deviceIdService.initialize();

    notificationRepo = NotificationRepository();

    pushNotificationService = PushNotificationService();

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<ApiRepository>(mockApi);
    GetIt.I.registerSingleton<SessionService>(sessionService);
    GetIt.I.registerSingleton<DeviceIdService>(deviceIdService);
    GetIt.I.registerSingleton<NotificationRepository>(notificationRepo);
    GetIt.I.registerSingleton<PushNotificationService>(pushNotificationService);
  });

  group('PushNotificationService Firebase Project & Masking', () {
    test('firebaseProjectId is configured for shpr-3b7ce', () {
      expect(PushNotificationService.firebaseProjectId, equals('shpr-3b7ce'));
    });

    test('maskToken masks real FCM token in logs', () {
      expect(PushNotificationService.maskToken(''), equals('<empty>'));
      expect(PushNotificationService.maskToken(null), equals('<empty>'));
      expect(PushNotificationService.maskToken('12345'), equals('***'));
      expect(
        PushNotificationService.maskToken('fK8l29xM_very_long_firebase_token_string_9988'),
        equals('fK8l29...9988'),
      );
    });

    test('maskDeviceId masks Device ID in logs', () {
      expect(PushNotificationService.maskDeviceId(''), equals('<empty>'));
      expect(PushNotificationService.maskDeviceId(null), equals('<empty>'));
      expect(PushNotificationService.maskDeviceId('12345'), equals('***'));
      expect(
        PushNotificationService.maskDeviceId('550e8400-e29b-41d4-a716-446655440000'),
        equals('550e84...0000'),
      );
    });

    test('currentPlatform dynamically returns android/ios/os', () {
      final platform = PushNotificationService.currentPlatform;
      expect(platform, isNotEmpty);
      expect(platform, anyOf(equals('android'), equals('ios'), equals('windows'), equals('macos'), equals('linux'), equals('web')));
    });
  });

  group('PushNotificationService Runtime Token Registration', () {
    test('registerDeviceToken sends real persistent device ID, runtime token and platform', () async {
      const realRuntimeToken = 'dK9x_real_firebase_runtime_fcm_token_1234567890';
      pushNotificationService.setCurrentTokenForTesting(realRuntimeToken);

      final success = await pushNotificationService.registerDeviceToken();

      expect(success, isTrue);
      expect(mockApi.lastPostPath, equals('/api/notifications/device-token'));

      final payload = mockApi.lastPostData as Map<String, dynamic>;
      expect(payload['deviceId'], equals('550e8400-e29b-41d4-a716-446655440000'));
      expect(payload['pushToken'], equals(realRuntimeToken));
      expect(payload['platform'], equals(PushNotificationService.currentPlatform));

      // Check that token was persisted in session
      expect(sessionService.getPushToken(), equals(realRuntimeToken));
    });

    test('registerDeviceToken defers registration if user is not authenticated', () async {
      await sessionService.clearSession();
      const realRuntimeToken = 'dK9x_real_firebase_runtime_fcm_token_1234567890';
      pushNotificationService.setCurrentTokenForTesting(realRuntimeToken);

      final success = await pushNotificationService.registerDeviceToken();

      expect(success, isFalse);
      expect(mockApi.lastPostPath, isNull);
      // Token is cached for future login
      expect(sessionService.getPushToken(), equals(realRuntimeToken));
    });

    test('registerDeviceToken rejects registration when token is missing', () async {
      pushNotificationService.setCurrentTokenForTesting(null);
      await sessionService.clearPushToken();

      final success = await pushNotificationService.registerDeviceToken();

      expect(success, isFalse);
      expect(mockApi.lastPostPath, isNull);
    });

    test('Token refresh updates backend with new token and current device ID', () async {
      const initialToken = 'initial_fcm_token_11111111111111111111';
      const refreshedToken = 'refreshed_fcm_token_22222222222222222222';

      pushNotificationService.setCurrentTokenForTesting(initialToken);
      await pushNotificationService.registerDeviceToken();
      expect(sessionService.getPushToken(), equals(initialToken));

      // Simulate token refresh
      pushNotificationService.setCurrentTokenForTesting(refreshedToken);
      final refreshSuccess = await pushNotificationService.registerDeviceToken(token: refreshedToken);

      expect(refreshSuccess, isTrue);
      final payload = mockApi.lastPostData as Map<String, dynamic>;
      expect(payload['deviceId'], equals('550e8400-e29b-41d4-a716-446655440000'));
      expect(payload['pushToken'], equals(refreshedToken));
      expect(sessionService.getPushToken(), equals(refreshedToken));
    });

    test('Failed API response (400) logs error and returns false', () async {
      mockApi.mockPostResponse = {
        'success': false,
        'statusCode': 400,
        'message': 'Invalid token payload',
      };

      const token = 'valid_token_test_abc123456789';
      pushNotificationService.setCurrentTokenForTesting(token);

      final success = await pushNotificationService.registerDeviceToken();
      expect(success, isFalse);
    });
  });
}
