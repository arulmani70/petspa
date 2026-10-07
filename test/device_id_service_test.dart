import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shear_heaven_pet_spa/src/common/services/device_id_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Persistent Device ID Service Verification', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
    });

    test('Scenario 1: First app launch generates and persists a valid UUID v4', () async {
      final storage = const FlutterSecureStorage();
      final service = DeviceIdService(secureStorage: storage);

      // Verify no ID exists before
      final before = await storage.read(key: DeviceIdService.storageKey);
      expect(before, isNull);

      // First call generates ID
      final deviceId = await service.getDeviceId();
      expect(deviceId, isNotEmpty);
      
      // Verify format is standard UUID v4 (8-4-4-4-12 hex format)
      final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$', caseSensitive: false);
      expect(uuidRegex.hasMatch(deviceId), isTrue);

      // Verify it was stored in secure storage
      final stored = await storage.read(key: DeviceIdService.storageKey);
      expect(stored, equals(deviceId));
    });

    test('Scenario 2: App reopened reuses the existing UUID without regenerating', () async {
      const existingUuid = '550e8400-e29b-41d4-a716-446655440000';
      FlutterSecureStorage.setMockInitialValues({
        DeviceIdService.storageKey: existingUuid,
      });

      final storage = const FlutterSecureStorage();
      final service = DeviceIdService(secureStorage: storage);

      await service.initialize();
      final deviceId = await service.getDeviceId();

      // Must be identical to existing
      expect(deviceId, equals(existingUuid));
      expect(service.currentDeviceId, equals(existingUuid));
    });

    test('Scenario 3: Repeated calls across lifecycle return exact same UUID', () async {
      final storage = const FlutterSecureStorage();
      final service = DeviceIdService(secureStorage: storage);

      final id1 = await service.getDeviceId();
      final id2 = await service.getDeviceId();
      final id3 = service.currentDeviceId;

      expect(id1, equals(id2));
      expect(id2, equals(id3));
    });

    test('Scenario 4: Logout preserves the device_id in secure storage', () async {
      final storage = const FlutterSecureStorage();
      final deviceService = DeviceIdService(secureStorage: storage);
      final sessionService = SessionService();
      await sessionService.initialize();

      // 1. Generate device ID
      final deviceId = await deviceService.getDeviceId();
      expect(deviceId, isNotEmpty);

      // 2. User logs in (tokens stored)
      await sessionService.saveTokens(accessToken: 'access_123', refreshToken: 'refresh_123');
      await sessionService.saveSession({'id': 'user_1', 'name': 'John Doe'});

      expect(await sessionService.getAccessToken(), equals('access_123'));
      expect(sessionService.isLoggedIn, isTrue);

      // 3. User logs out
      await sessionService.clearSession();

      // 4. Verify tokens are cleared
      expect(await sessionService.getAccessToken(), isNull);
      expect(sessionService.isLoggedIn, isFalse);

      // 5. CRITICAL: Verify device_id is STILL intact in secure storage
      final storedDeviceId = await storage.read(key: DeviceIdService.storageKey);
      expect(storedDeviceId, equals(deviceId));

      // 6. Next login reuses exact same deviceId
      final nextService = DeviceIdService(secureStorage: storage);
      final reloadedId = await nextService.getDeviceId();
      expect(reloadedId, equals(deviceId));
    });

    test('Scenario 5: Multi-device independence (Device A vs Device B)', () async {
      // Simulate Device A
      FlutterSecureStorage.setMockInitialValues({});
      final storageA = const FlutterSecureStorage();
      final serviceA = DeviceIdService(secureStorage: storageA);
      final deviceAId = await serviceA.getDeviceId();

      // Simulate Device B
      FlutterSecureStorage.setMockInitialValues({});
      final storageB = const FlutterSecureStorage();
      final serviceB = DeviceIdService(secureStorage: storageB);
      final deviceBId = await serviceB.getDeviceId();

      // Devices must have distinct UUIDs
      expect(deviceAId, isNot(equals(deviceBId)));
    });
  });
}
