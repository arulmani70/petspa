import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  late SessionService sessionService;
  late ApiRepository apiRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    
    // Setup GetIt for ServicesLocator
    final getIt = GetIt.instance;
    getIt.allowReassignment = true;

    sessionService = SessionService();
    await sessionService.initialize();
    getIt.registerSingleton<SessionService>(sessionService);

    apiRepository = ApiRepository();
    await apiRepository.initialize();
    getIt.registerSingleton<ApiRepository>(apiRepository);
    
    // We don't want real HTTP calls. We'll use interceptors to catch the request.
    // However, since we just want to verify headers, we can add a RequestInterceptor
    // at the end that prevents the call and throws an error with the headers.
    apiRepository.dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Reject immediately so it doesn't try to resolve google.com or actual baseUrl
        return handler.reject(DioException(
          requestOptions: options,
          error: 'MOCK_INTERCEPT',
        ));
      },
    ));
  });

  group('ApiRepository Interceptor Tests', () {
    test('All three IDs are attached when present', () async {
      await sessionService.saveClientId('client_123');
      await sessionService.saveRegionId('region_456');
      await sessionService.saveStoreId('store_789');

      try {
        await apiRepository.dio.get('/dummy');
      } catch (e) {
        if (e is DioException && e.error == 'MOCK_INTERCEPT') {
          expect(e.requestOptions.headers['x-client-id'], equals('client_123'));
          expect(e.requestOptions.headers['x-region-id'], equals('region_456'));
          expect(e.requestOptions.headers['x-store-id'], equals('store_789'));
        } else {
          fail('Unexpected error: $e');
        }
      }
    });

    test('Missing Client ID does not crash and is not attached', () async {
      await sessionService.saveRegionId('region_456');
      await sessionService.saveStoreId('store_789');

      try {
        await apiRepository.dio.get('/dummy');
      } catch (e) {
        if (e is DioException && e.error == 'MOCK_INTERCEPT') {
          expect(e.requestOptions.headers.containsKey('x-client-id'), isFalse);
          expect(e.requestOptions.headers['x-region-id'], equals('region_456'));
          expect(e.requestOptions.headers['x-store-id'], equals('store_789'));
        }
      }
    });

    test('Missing Region ID does not crash and is not attached', () async {
      await sessionService.saveClientId('client_123');
      await sessionService.saveStoreId('store_789');

      try {
        await apiRepository.dio.get('/dummy');
      } catch (e) {
        if (e is DioException && e.error == 'MOCK_INTERCEPT') {
          expect(e.requestOptions.headers['x-client-id'], equals('client_123'));
          expect(e.requestOptions.headers.containsKey('x-region-id'), isFalse);
          expect(e.requestOptions.headers['x-store-id'], equals('store_789'));
        }
      }
    });

    test('Missing Store ID does not crash and is not attached', () async {
      await sessionService.saveClientId('client_123');
      await sessionService.saveRegionId('region_456');

      try {
        await apiRepository.dio.get('/dummy');
      } catch (e) {
        if (e is DioException && e.error == 'MOCK_INTERCEPT') {
          expect(e.requestOptions.headers['x-client-id'], equals('client_123'));
          expect(e.requestOptions.headers['x-region-id'], equals('region_456'));
          expect(e.requestOptions.headers.containsKey('x-store-id'), isFalse);
        }
      }
    });

    test('Empty session attaches no custom IDs but preserves basic headers', () async {
      // Intentionally not setting any IDs
      try {
        await apiRepository.dio.get('/dummy');
      } catch (e) {
        if (e is DioException && e.error == 'MOCK_INTERCEPT') {
          expect(e.requestOptions.headers.containsKey('x-client-id'), isFalse);
          expect(e.requestOptions.headers.containsKey('x-region-id'), isFalse);
          expect(e.requestOptions.headers.containsKey('x-store-id'), isFalse);
          // Standard headers should still exist
          expect(e.requestOptions.headers['Content-Type'], equals('application/json'));
        }
      }
    });

    test('Existing authentication headers are preserved', () async {
      await sessionService.saveClientId('client_123');
      
      try {
        // Manually attaching an Authorization header to simulate existing auth logic
        await apiRepository.dio.get('/dummy', options: Options(headers: {
          'Authorization': 'Bearer test_token'
        }));
      } catch (e) {
        if (e is DioException && e.error == 'MOCK_INTERCEPT') {
          expect(e.requestOptions.headers['x-client-id'], equals('client_123'));
          // Ensure auth token was preserved
          expect(e.requestOptions.headers['Authorization'], equals('Bearer test_token'));
        }
      }
    });
  });
}
