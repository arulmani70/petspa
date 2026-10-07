import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  
  late SessionService sessionService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sessionService = SessionService();
    await sessionService.initialize();
  });

  group('SessionService Config Identifiers', () {
    test('Client ID can be stored and retrieved', () async {
      // By default it should be null
      expect(sessionService.clientId, isNull);

      // Save a valid ID
      await sessionService.saveClientId('client_123');
      expect(sessionService.clientId, equals('client_123'));
    });

    test('Region ID can be stored and retrieved', () async {
      expect(sessionService.regionId, isNull);

      await sessionService.saveRegionId('region_456');
      expect(sessionService.regionId, equals('region_456'));
    });

    test('Store ID can be stored and retrieved', () async {
      expect(sessionService.storeId, isNull);

      await sessionService.saveStoreId('store_789');
      expect(sessionService.storeId, equals('store_789'));
    });

    test('All three can be stored and retrieved together', () async {
      await sessionService.saveClientId('client_1');
      await sessionService.saveRegionId('region_2');
      await sessionService.saveStoreId('store_3');

      expect(sessionService.clientId, equals('client_1'));
      expect(sessionService.regionId, equals('region_2'));
      expect(sessionService.storeId, equals('store_3'));
    });

    test('Missing values are represented as null', () async {
      // SharedPreferences returns null if the key doesn't exist
      expect(sessionService.clientId, isNull);
      expect(sessionService.regionId, isNull);
      expect(sessionService.storeId, isNull);
    });

    test('Values are removed when session is cleared', () async {
      await sessionService.saveClientId('client_1');
      await sessionService.saveRegionId('region_2');
      await sessionService.saveStoreId('store_3');

      expect(sessionService.clientId, isNotNull);
      
      await sessionService.clearSession();

      expect(sessionService.clientId, isNull);
      expect(sessionService.regionId, isNull);
      expect(sessionService.storeId, isNull);
    });
  });
}

