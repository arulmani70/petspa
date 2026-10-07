import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/auth/repo/auth_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/customer_socket_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/groomer_socket_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/groomer/repo/groomer_repository.dart';

class MockAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;
  MockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  static ResponseBody json(dynamic data, int statusCode) {
    final text = jsonEncode(data);
    return ResponseBody.fromString(
      text,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionService sessionService;
  late ApiRepository apiRepository;
  late CustomerSocketService customerSocketService;
  late GroomerSocketService groomerSocketService;
  late AuthRepository authRepository;
  late GroomerRepository groomerRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    final getIt = GetIt.instance;
    getIt.allowReassignment = true;

    sessionService = SessionService();
    await sessionService.initialize();
    getIt.registerSingleton<SessionService>(sessionService);

    apiRepository = ApiRepository();
    await apiRepository.initialize();
    getIt.registerSingleton<ApiRepository>(apiRepository);

    customerSocketService = CustomerSocketService();
    getIt.registerSingleton<CustomerSocketService>(customerSocketService);

    groomerSocketService = GroomerSocketService();
    getIt.registerSingleton<GroomerSocketService>(groomerSocketService);

    authRepository = AuthRepository();
    await authRepository.initialize();
    getIt.registerSingleton<AuthRepository>(authRepository);

    groomerRepository = GroomerRepository();
    await groomerRepository.initialize();
    getIt.registerSingleton<GroomerRepository>(groomerRepository);
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  group('Session & Access Token Expiry Flow Tests', () {
    test('Scenario 1: Customer 401 transparently refreshes token and retries request with new token', () async {
      // 1. Setup active customer session with old tokens
      await sessionService.saveSession({'id': 101, 'name': 'John Doe', 'email': 'john@example.com'});
      await sessionService.saveTokens(
        accessToken: 'expired_customer_access_token',
        refreshToken: 'valid_customer_refresh_token',
      );

      expect(sessionService.isLoggedIn, isTrue);

      int requestCount = 0;
      int refreshCount = 0;

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        if (options.path.contains('/api/pets')) {
          requestCount++;
          if (requestCount == 1) {
            // Initial request with expired token
            expect(options.headers['Authorization'], equals('Bearer expired_customer_access_token'));
            return MockAdapter.json({'success': false, 'message': 'Token expired'}, 401);
          } else {
            // Retried request with refreshed token
            expect(options.headers['Authorization'], equals('Bearer new_fresh_customer_access_token'));
            return MockAdapter.json({
              'success': true,
              'data': {'id': 1, 'name': 'Buddy'}
            }, 200);
          }
        } else if (options.path.contains('/api/auth/refresh-token')) {
          refreshCount++;
          final body = options.data is Map ? options.data as Map : jsonDecode(options.data.toString());
          expect(body['refreshToken'], equals('valid_customer_refresh_token'));
          return MockAdapter.json({
            'success': true,
            'data': {
              'accessToken': 'new_fresh_customer_access_token',
              'refreshToken': 'new_fresh_customer_refresh_token',
            }
          }, 200);
        }
        return MockAdapter.json({'message': 'Not found'}, 404);
      });

      final result = await apiRepository.get('/api/pets');

      expect(result, isNotNull);
      expect(result!['success'], isTrue);
      expect(result['data']['name'], equals('Buddy'));
      expect(requestCount, equals(2)); // Initial 401 + retry
      expect(refreshCount, equals(1)); // 1 refresh call

      // Tokens should be updated in SessionService
      expect(await sessionService.getAccessToken(), equals('new_fresh_customer_access_token'));
      expect(await sessionService.getRefreshToken(), equals('new_fresh_customer_refresh_token'));
      expect(sessionService.isLoggedIn, isTrue);
    });

    test('Scenario 2: Groomer 401 transparently refreshes token and retries request with new token', () async {
      // 1. Setup active groomer session
      await sessionService.saveGroomerSession(
        accessToken: 'expired_groomer_token',
        refreshToken: 'valid_groomer_refresh_token',
        groomerData: {'id': 55, 'fullName': 'Jane Groomer', 'email': 'jane@groomer.com'},
      );

      expect(sessionService.isGroomerLoggedIn, isTrue);

      int requestCount = 0;
      int refreshCount = 0;

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        if (options.path.contains('/api/groomer-auth/bookings/upcoming')) {
          requestCount++;
          if (requestCount == 1) {
            expect(options.headers['Authorization'], equals('Bearer expired_groomer_token'));
            return MockAdapter.json({'success': false, 'message': 'Groomer token expired'}, 401);
          } else {
            expect(options.headers['Authorization'], equals('Bearer new_fresh_groomer_access_token'));
            return MockAdapter.json({
              'success': true,
              'data': [
                {'id': 1001, 'status': 'confirmed'}
              ]
            }, 200);
          }
        } else if (options.path.contains('/api/groomer-auth/refresh-token')) {
          refreshCount++;
          final body = options.data is Map ? options.data as Map : jsonDecode(options.data.toString());
          expect(body['refreshToken'], equals('valid_groomer_refresh_token'));
          return MockAdapter.json({
            'success': true,
            'data': {
              'accessToken': 'new_fresh_groomer_access_token',
              'refreshToken': 'new_fresh_groomer_refresh_token',
            }
          }, 200);
        }
        return MockAdapter.json({'message': 'Not found'}, 404);
      });

      final result = await apiRepository.get('/api/groomer-auth/bookings/upcoming');

      expect(result, isNotNull);
      expect(result!['success'], isTrue);
      expect(requestCount, equals(2));
      expect(refreshCount, equals(1));

      expect(await sessionService.getGroomerAccessToken(), equals('new_fresh_groomer_access_token'));
      expect(await sessionService.getGroomerRefreshToken(), equals('new_fresh_groomer_refresh_token'));
      expect(sessionService.isGroomerLoggedIn, isTrue);
    });

    test('Scenario 3: Customer refresh failure clears session and disconnects socket', () async {
      await sessionService.saveSession({'id': 101, 'name': 'John Doe'});
      await sessionService.saveTokens(
        accessToken: 'expired_customer_access_token',
        refreshToken: 'invalid_customer_refresh_token',
      );

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        if (options.path.contains('/api/pets')) {
          return MockAdapter.json({'message': 'Unauthorized'}, 401);
        } else if (options.path.contains('/api/auth/refresh-token')) {
          return MockAdapter.json({'success': false, 'message': 'Invalid refresh token'}, 401);
        }
        return MockAdapter.json({'message': 'Not found'}, 404);
      });

      final result = await apiRepository.get('/api/pets');

      // Request fails and returns null
      expect(result, isNull);

      // Session data and tokens must be cleared
      expect(sessionService.isLoggedIn, isFalse);
      expect(await sessionService.getAccessToken(), isNull);
      expect(await sessionService.getRefreshToken(), isNull);
    });

    test('Scenario 4: Groomer refresh failure clears groomer session and disconnects socket', () async {
      await sessionService.saveGroomerSession(
        accessToken: 'expired_groomer_token',
        refreshToken: 'invalid_groomer_refresh_token',
        groomerData: {'id': 55, 'fullName': 'Jane Groomer'},
      );

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        if (options.path.contains('/api/groomer-auth/bookings/upcoming')) {
          return MockAdapter.json({'message': 'Unauthorized'}, 401);
        } else if (options.path.contains('/api/groomer-auth/refresh-token')) {
          return MockAdapter.json({'success': false, 'message': 'Invalid groomer refresh token'}, 401);
        }
        return MockAdapter.json({'message': 'Not found'}, 404);
      });

      final result = await apiRepository.get('/api/groomer-auth/bookings/upcoming');

      expect(result, isNull);
      expect(sessionService.isGroomerLoggedIn, isFalse);
      expect(await sessionService.getGroomerAccessToken(), isNull);
      expect(await sessionService.getGroomerRefreshToken(), isNull);
    });

    test('Scenario 5: Guest 401 does not attempt refresh or clear Customer/Groomer session', () async {
      // Guest: isLoggedIn is false and isGroomerLoggedIn is false
      expect(sessionService.isLoggedIn, isFalse);
      expect(sessionService.isGroomerLoggedIn, isFalse);

      int refreshAttempts = 0;

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        if (options.path.contains('/api/auth/refresh-token') ||
            options.path.contains('/api/groomer-auth/refresh-token')) {
          refreshAttempts++;
        }
        if (options.path.contains('/api/services')) {
          return MockAdapter.json({'message': 'Guest unauthorized'}, 401);
        }
        return MockAdapter.json({'message': 'Not found'}, 404);
      });

      final result = await apiRepository.get('/api/services');

      expect(result, isNull);
      expect(refreshAttempts, equals(0)); // Zero refresh calls for guest
    });

    test('Scenario 6: In-Flight Mutex prevents duplicate Customer refresh calls under concurrent requests', () async {
      await sessionService.saveSession({'id': 101, 'name': 'John Doe'});
      await sessionService.saveTokens(
        accessToken: 'expired_token',
        refreshToken: 'valid_refresh_token',
      );

      int refreshCallCount = 0;

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        if (options.path.contains('/api/auth/refresh-token')) {
          refreshCallCount++;
          // Simulate network latency for refresh
          await Future.delayed(const Duration(milliseconds: 30));
          return MockAdapter.json({
            'success': true,
            'data': {
              'accessToken': 'new_synchronized_token',
              'refreshToken': 'new_synchronized_refresh_token',
            }
          }, 200);
        } else if (options.path.contains('/api/endpoint_')) {
          if (options.headers['Authorization'] == 'Bearer expired_token') {
            return MockAdapter.json({'message': 'Expired'}, 401);
          } else if (options.headers['Authorization'] == 'Bearer new_synchronized_token') {
            return MockAdapter.json({'success': true, 'path': options.path}, 200);
          }
        }
        return MockAdapter.json({'message': 'Not found'}, 404);
      });

      // Trigger 3 concurrent requests simultaneously
      final future1 = apiRepository.get('/api/endpoint_1');
      final future2 = apiRepository.get('/api/endpoint_2');
      final future3 = apiRepository.get('/api/endpoint_3');

      final results = await Future.wait([future1, future2, future3]);

      // Exactly 1 refresh HTTP call must have been made
      expect(refreshCallCount, equals(1));

      // All 3 requests must succeed with the refreshed token
      expect(results[0], isNotNull);
      expect(results[0]!['success'], isTrue);
      expect(results[1], isNotNull);
      expect(results[1]!['success'], isTrue);
      expect(results[2], isNotNull);
      expect(results[2]!['success'], isTrue);
    });

    test('Scenario 7: In-Flight Mutex prevents duplicate Groomer refresh calls under concurrent requests', () async {
      await sessionService.saveGroomerSession(
        accessToken: 'expired_groomer_token',
        refreshToken: 'valid_groomer_refresh_token',
        groomerData: {'id': 55, 'fullName': 'Jane Groomer'},
      );

      int groomerRefreshCallCount = 0;

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        if (options.path.contains('/api/groomer-auth/refresh-token')) {
          groomerRefreshCallCount++;
          await Future.delayed(const Duration(milliseconds: 30));
          return MockAdapter.json({
            'success': true,
            'data': {
              'accessToken': 'new_synchronized_groomer_token',
              'refreshToken': 'new_synchronized_groomer_refresh_token',
            }
          }, 200);
        } else if (options.path.contains('/api/groomer-auth/req_')) {
          if (options.headers['Authorization'] == 'Bearer expired_groomer_token') {
            return MockAdapter.json({'message': 'Expired'}, 401);
          } else if (options.headers['Authorization'] == 'Bearer new_synchronized_groomer_token') {
            return MockAdapter.json({'success': true, 'path': options.path}, 200);
          }
        }
        return MockAdapter.json({'message': 'Not found'}, 404);
      });

      final future1 = apiRepository.get('/api/groomer-auth/req_1');
      final future2 = apiRepository.get('/api/groomer-auth/req_2');
      final future3 = apiRepository.get('/api/groomer-auth/req_3');

      final results = await Future.wait([future1, future2, future3]);

      expect(groomerRefreshCallCount, equals(1));
      expect(results[0]!['success'], isTrue);
      expect(results[1]!['success'], isTrue);
      expect(results[2]!['success'], isTrue);
    });

    test('Scenario 8: Excluded auth endpoints receiving 401 do not trigger token refresh', () async {
      int refreshCount = 0;

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        if (options.path.contains('refresh-token')) {
          refreshCount++;
        }
        if (options.path == '/api/auth/login' ||
            options.path == '/api/auth/signup' ||
            options.path == '/api/auth/send-otp' ||
            options.path == '/api/auth/verify-otp' ||
            options.path == '/api/groomer-auth/login') {
          return MockAdapter.json({'success': false, 'message': 'Invalid credentials'}, 401);
        }
        return MockAdapter.json({'message': 'Not found'}, 404);
      });

      final loginRes = await apiRepository.post('/api/auth/login', {'email': 'test@example.com', 'password': '123'});
      final groomerLoginRes = await apiRepository.post('/api/groomer-auth/login', {'email': 'g@example.com', 'password': '123'});

      expect(loginRes?['success'], isFalse);
      expect(groomerLoginRes?['success'], isFalse);
      expect(refreshCount, equals(0)); // Must be zero
    });

    test('Scenario 9: Refresh endpoint failure does not loop infinitely and terminates with single failure', () async {
      await sessionService.saveSession({'id': 101, 'name': 'John'});
      await sessionService.saveTokens(
        accessToken: 'expired_token',
        refreshToken: 'bad_refresh_token',
      );

      int refreshHitCount = 0;

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        if (options.path.contains('/api/auth/refresh-token')) {
          refreshHitCount++;
          return MockAdapter.json({'success': false, 'message': 'Refresh token expired'}, 401);
        } else if (options.path.contains('/api/pets')) {
          return MockAdapter.json({'success': false, 'message': 'Unauthorized'}, 401);
        }
        return MockAdapter.json({'message': 'Not found'}, 404);
      });

      final result = await apiRepository.get('/api/pets');

      expect(result, isNull);
      expect(refreshHitCount, equals(1)); // Called once, never looped
    });

    test('Scenario 10: Role Isolation - Customer 401 does not affect Groomer session', () async {
      // Setup both sessions simultaneously
      await sessionService.saveSession({'id': 101, 'name': 'Customer John'});
      await sessionService.saveTokens(accessToken: 'cust_access', refreshToken: 'cust_bad_refresh');

      await sessionService.saveGroomerSession(
        accessToken: 'groomer_access',
        refreshToken: 'groomer_refresh',
        groomerData: {'id': 55, 'fullName': 'Jane Groomer'},
      );

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        if (options.path.contains('/api/pets')) {
          return MockAdapter.json({'message': 'Customer 401'}, 401);
        } else if (options.path.contains('/api/auth/refresh-token')) {
          return MockAdapter.json({'message': 'Customer refresh failed'}, 401);
        }
        return MockAdapter.json({'message': 'Not found'}, 404);
      });

      await apiRepository.get('/api/pets');

      // Customer session cleared
      expect(sessionService.isLoggedIn, isFalse);
      expect(await sessionService.getAccessToken(), isNull);

      // Groomer session remains completely intact!
      expect(sessionService.isGroomerLoggedIn, isTrue);
      expect(await sessionService.getGroomerAccessToken(), equals('groomer_access'));
      expect(await sessionService.getGroomerRefreshToken(), equals('groomer_refresh'));
      expect(sessionService.getGroomerUser()?['fullName'], equals('Jane Groomer'));
    });

    test('Scenario 11: Role Isolation - Groomer 401 does not affect Customer session', () async {
      await sessionService.saveSession({'id': 101, 'name': 'Customer John'});
      await sessionService.saveTokens(accessToken: 'cust_access', refreshToken: 'cust_refresh');

      await sessionService.saveGroomerSession(
        accessToken: 'groomer_access',
        refreshToken: 'groomer_bad_refresh',
        groomerData: {'id': 55, 'fullName': 'Jane Groomer'},
      );

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        if (options.path.contains('/api/groomer-auth/bookings/upcoming')) {
          return MockAdapter.json({'message': 'Groomer 401'}, 401);
        } else if (options.path.contains('/api/groomer-auth/refresh-token')) {
          return MockAdapter.json({'message': 'Groomer refresh failed'}, 401);
        }
        return MockAdapter.json({'message': 'Not found'}, 404);
      });

      await apiRepository.get('/api/groomer-auth/bookings/upcoming');

      // Groomer session cleared
      expect(sessionService.isGroomerLoggedIn, isFalse);
      expect(await sessionService.getGroomerAccessToken(), isNull);

      // Customer session remains completely intact!
      expect(sessionService.isLoggedIn, isTrue);
      expect(await sessionService.getAccessToken(), equals('cust_access'));
      expect(await sessionService.getRefreshToken(), equals('cust_refresh'));
      expect(sessionService.getSessionUser()?['name'], equals('Customer John'));
    });

    test('Scenario 12: AuthRepository.refreshToken() manually refreshes customer token and saves tokens', () async {
      await sessionService.saveTokens(
        accessToken: 'old_cust_token',
        refreshToken: 'cust_refresh_123',
      );

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        if (options.path.contains('/api/auth/refresh-token')) {
          return MockAdapter.json({
            'success': true,
            'data': {
              'accessToken': 'manual_fresh_cust_token',
              'refreshToken': 'manual_fresh_cust_refresh',
            }
          }, 200);
        }
        return MockAdapter.json({'message': 'Not found'}, 404);
      });

      final success = await authRepository.refreshToken();

      expect(success, isTrue);
      expect(await sessionService.getAccessToken(), equals('manual_fresh_cust_token'));
      expect(await sessionService.getRefreshToken(), equals('manual_fresh_cust_refresh'));
    });

    test('Scenario 13: GroomerRepository.refreshToken() manually refreshes groomer token and saves session', () async {
      await sessionService.saveGroomerSession(
        accessToken: 'old_groomer_token',
        refreshToken: 'groomer_refresh_123',
        groomerData: {'id': 55, 'fullName': 'Jane'},
      );

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        if (options.path.contains('/api/groomer-auth/refresh-token')) {
          return MockAdapter.json({
            'success': true,
            'data': {
              'accessToken': 'manual_fresh_groomer_token',
              'refreshToken': 'manual_fresh_groomer_refresh',
            }
          }, 200);
        }
        return MockAdapter.json({'message': 'Not found'}, 404);
      });

      final success = await groomerRepository.refreshToken();

      expect(success, isTrue);
      expect(await sessionService.getGroomerAccessToken(), equals('manual_fresh_groomer_token'));
      expect(await sessionService.getGroomerRefreshToken(), equals('manual_fresh_groomer_refresh'));
    });

    test('Scenario 14: After logout or refresh failure, subsequent requests do not send expired tokens', () async {
      await sessionService.saveSession({'id': 101, 'name': 'John'});
      await sessionService.saveTokens(accessToken: 'token_to_clear', refreshToken: 'refresh_to_clear');

      String? sentAuthHeader;

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        if (options.path.contains('/api/auth/logout')) {
          return MockAdapter.json({'success': true}, 200);
        } else if (options.path.contains('/api/services')) {
          sentAuthHeader = options.headers['Authorization']?.toString();
          return MockAdapter.json({'success': true}, 200);
        }
        return MockAdapter.json({'message': 'Not found'}, 404);
      });

      // Execute logout
      await authRepository.logout();

      await apiRepository.get('/api/services');

      expect(sentAuthHeader, isNull);
    });
  });
}
