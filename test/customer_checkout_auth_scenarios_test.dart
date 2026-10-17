import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/app/routes.dart';
import 'package:shear_heaven_pet_spa/src/bookings/repo/booking_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/customer_socket_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/groomer_socket_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/notification_navigation_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';

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
  late BookingRepository bookingRepository;
  late CustomerSocketService customerSocketService;
  late GroomerSocketService groomerSocketService;

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

    bookingRepository = BookingRepository();
    await bookingRepository.initialize();
    getIt.registerSingleton<BookingRepository>(bookingRepository);
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  group('Scenario 1: Valid Customer Login -> Confirm Tip -> Remains in Checkout Flow', () {
    test('Customer Bearer token is attached, tip confirmed, booking remains ready_for_checkout', () async {
      await sessionService.saveSession({'id': 101, 'name': 'Alice Smith'});
      await sessionService.saveTokens(
        accessToken: 'valid_customer_access_token_123',
        refreshToken: 'valid_customer_refresh_token_123',
      );

      String? sentAuthHeader;
      Map<String, dynamic>? sentBody;

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        if (options.path.contains('/confirm-tip')) {
          sentAuthHeader = options.headers['Authorization'];
          sentBody = options.data is Map ? options.data as Map<String, dynamic> : jsonDecode(options.data.toString());
          return MockAdapter.json({
            'success': true,
            'message': 'Tip confirmed successfully',
            'data': {'bookingId': 8, 'tipAmount': 15.0},
          }, 200);
        }
        return MockAdapter.json({'message': 'Not found'}, 404);
      });

      final result = await bookingRepository.confirmTipDetails(
        bookingId: 8,
        tipAmount: 15.0,
        tipPercentage: 15.0,
        booking: {
          'id': 8,
          'bookingId': 8,
          'status': 'ready_for_checkout',
          'customerId': 101,
        },
      );

      expect(result.success, isTrue);
      expect(result.confirmedTipAmount, equals(15.0));
      expect(sentAuthHeader, equals('Bearer valid_customer_access_token_123'));
      expect(sentBody?['tipAmount'], equals(15.0));

      // Booking status MUST remain ready_for_checkout, NEVER completed
      expect(result.updatedBooking?['status'], equals('ready_for_checkout'));
      expect(result.updatedBooking?['isPaid'], isNot(equals(true)));

      // SessionService records confirmed tip
      final savedTip = sessionService.getConfirmedTip(8);
      expect(savedTip?['tipAmount'], equals(15.0));
    });
  });

  group('Scenario 2: Notification Tap -> Checkout Confirmation Page', () {
    testWidgets('Ready for checkout notification opens confirmation page for booking #8', (tester) async {
      await sessionService.saveSession({'id': 101, 'name': 'Alice Smith'});
      await sessionService.saveTokens(
        accessToken: 'customer_jwt_token',
        refreshToken: 'customer_refresh_token',
      );

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        if (options.path.contains('/api/bookings/8/checkout-summary')) {
          return MockAdapter.json({
            'success': true,
            'data': {
              'bookingId': 8,
              'id': 8,
              'petName': 'Max',
              'serviceName': 'Deluxe Bath',
              'totalPrice': 60.0,
              'status': 'ready_for_checkout',
            },
          }, 200);
        }
        return MockAdapter.json({'message': 'Not found'}, 404);
      });

      await tester.pumpWidget(MaterialApp.router(routerConfig: Routes.globalRouter));
      await tester.pumpAndSettle();

      final payloadJson = jsonEncode({
        'id': 8801,
        'bookingId': 8,
        'type': 'booking_ready_for_checkout',
        'title': 'Ready for Checkout',
        'message': 'Max is all done and ready for pickup!',
      });

      final handled = await NotificationNavigationService.handlePayloadString(payloadJson);
      expect(handled, isTrue);
      await tester.pumpAndSettle();

      final router = Routes.globalRouter;
      expect(router.routerDelegate.currentConfiguration.uri.toString(), contains(RouteNames.customerCheckoutSummary));
      expect(router.routerDelegate.currentConfiguration.uri.queryParameters['bookingId'], equals('8'));

      // Verify the page renders checkout confirmation
      expect(find.text('Checkout Confirmation'), findsOneWidget);
    });
  });

  group('Scenario 3: Valid Customer Session After App Restart', () {
    test('Tokens reload into memory after app restart via SharedPreferences fallback', () async {
      // 1. Initial run: customer logs in and saves tokens
      await sessionService.saveSession({'id': 101, 'name': 'Alice'});
      await sessionService.saveTokens(
        accessToken: 'persisted_customer_access_token',
        refreshToken: 'persisted_customer_refresh_token',
      );

      // Verify tokens present
      expect(await sessionService.getAccessToken(), equals('persisted_customer_access_token'));

      // 2. Simulate App Restart: new SessionService instance with fresh in-memory state
      final restartedSessionService = SessionService();
      await restartedSessionService.initialize();

      // In-memory cache is initially empty on a fresh instance, but recovers from storage
      expect(await restartedSessionService.getAccessToken(), equals('persisted_customer_access_token'));
      expect(await restartedSessionService.getRefreshToken(), equals('persisted_customer_refresh_token'));
      expect(restartedSessionService.isLoggedIn, isTrue);
    });
  });

  group('Scenario 4: Expired or Invalid Customer Token', () {
    test('Expired access token is refreshed automatically and confirm-tip retried', () async {
      await sessionService.saveSession({'id': 101, 'name': 'Alice'});
      await sessionService.saveTokens(
        accessToken: 'expired_access_token',
        refreshToken: 'valid_refresh_token',
      );

      int tipCallCount = 0;
      int refreshCallCount = 0;

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        if (options.path.contains('/confirm-tip')) {
          tipCallCount++;
          if (tipCallCount == 1) {
            expect(options.headers['Authorization'], equals('Bearer expired_access_token'));
            return MockAdapter.json({'success': false, 'message': 'Token expired'}, 401);
          } else {
            expect(options.headers['Authorization'], equals('Bearer newly_refreshed_access_token'));
            return MockAdapter.json({
              'success': true,
              'message': 'Tip confirmed with fresh token',
              'data': {'bookingId': 8, 'tipAmount': 10.0},
            }, 200);
          }
        } else if (options.path.contains('/api/auth/refresh-token')) {
          refreshCallCount++;
          return MockAdapter.json({
            'success': true,
            'data': {
              'accessToken': 'newly_refreshed_access_token',
              'refreshToken': 'newly_refreshed_refresh_token',
            },
          }, 200);
        }
        return MockAdapter.json({'message': 'Not found'}, 404);
      });

      final result = await bookingRepository.confirmTipDetails(
        bookingId: 8,
        tipAmount: 10.0,
      );

      expect(result.success, isTrue);
      expect(tipCallCount, equals(2));
      expect(refreshCallCount, equals(1));
      expect(await sessionService.getAccessToken(), equals('newly_refreshed_access_token'));
    });

    test('Genuine 401 (refresh failure / expired session) returns success: false and does NOT fake success', () async {
      await sessionService.saveSession({'id': 101, 'name': 'Alice'});
      await sessionService.saveTokens(
        accessToken: 'expired_access_token',
        refreshToken: 'invalid_refresh_token',
      );

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        if (options.path.contains('/confirm-tip') || options.path.contains('/tip')) {
          return MockAdapter.json({'statusCode': 401, 'message': 'Unauthorized'}, 401);
        } else if (options.path.contains('/api/auth/refresh-token')) {
          return MockAdapter.json({'success': false, 'message': 'Refresh token expired'}, 401);
        }
        return MockAdapter.json({'message': 'Not found'}, 404);
      });

      final result = await bookingRepository.confirmTipDetails(
        bookingId: 8,
        tipAmount: 10.0,
      );

      // Must return success: false and session expired message
      expect(result.success, isFalse);
      expect(result.message, contains('session has expired'));
      expect(result.isPendingBackend, isFalse);
    });
  });

  group('Scenario 5: Tip API returns 400, 401, 403, 404, or 500', () {
    test('400 validation error returns success: false with validation message', () async {
      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        return MockAdapter.json({
          'statusCode': 400,
          'message': 'Invalid tip amount: exceeds maximum limit',
        }, 400);
      });

      final result = await bookingRepository.confirmTipDetails(
        bookingId: 8,
        tipAmount: 500.0,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('Invalid tip amount'));
    });

    test('403 Forbidden returns success: false and does NOT redirect to login', () async {
      await sessionService.saveSession({'id': 101, 'name': 'Alice'});
      await sessionService.saveTokens(accessToken: 'valid_token', refreshToken: 'valid_refresh');

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        return MockAdapter.json({
          'statusCode': 403,
          'message': 'You do not have permission to modify this booking',
        }, 403);
      });

      final result = await bookingRepository.confirmTipDetails(
        bookingId: 8,
        tipAmount: 10.0,
      );

      expect(result.success, isFalse);
      expect(result.message, contains('permission'));
      // Customer session must remain intact
      expect(sessionService.isLoggedIn, isTrue);
    });

    test('404 Not Found endpoint records tip locally with isPendingBackend: true', () async {
      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        return MockAdapter.json({'statusCode': 404, 'message': 'Endpoint not found'}, 404);
      });

      final result = await bookingRepository.confirmTipDetails(
        bookingId: 8,
        tipAmount: 12.0,
      );

      expect(result.success, isTrue);
      expect(result.isPendingBackend, isTrue);
      expect(result.confirmedTipAmount, equals(12.0));
    });

    test('500 Server Error records tip locally with isPendingBackend: true without crashing', () async {
      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        return MockAdapter.json({'statusCode': 500, 'message': 'Internal Server Error'}, 500);
      });

      final result = await bookingRepository.confirmTipDetails(
        bookingId: 8,
        tipAmount: 8.0,
      );

      expect(result.success, isTrue);
      expect(result.isPendingBackend, isTrue);
      expect(result.confirmedTipAmount, equals(8.0));
    });
  });

  group('Scenario 6: Network Failure, Preservation, and Retry', () {
    test('Network timeout does not wipe customer session and preserves entered tip', () async {
      await sessionService.saveSession({'id': 101, 'name': 'Alice'});
      await sessionService.saveTokens(accessToken: 'valid_token', refreshToken: 'valid_refresh');

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
          error: 'Connection timed out',
        );
      });

      final result = await bookingRepository.confirmTipDetails(
        bookingId: 8,
        tipAmount: 10.0,
      );

      // Tip recorded locally in fallback mode
      expect(result.success, isTrue);
      expect(result.isPendingBackend, isTrue);

      // Customer session must NOT be cleared on network error
      expect(sessionService.isLoggedIn, isTrue);
      expect(await sessionService.getAccessToken(), equals('valid_token'));
    });
  });

  group('Scenario 7: Session Isolation (Groomer vs Customer)', () {
    test('Customer tip confirmation NEVER sends Groomer token even if Groomer is logged in', () async {
      // Setup both customer and groomer sessions simultaneously
      await sessionService.saveSession({'id': 101, 'name': 'Alice Customer'});
      await sessionService.saveTokens(
        accessToken: 'customer_token_aaa',
        refreshToken: 'customer_refresh_aaa',
      );

      await sessionService.saveGroomerSession(
        accessToken: 'groomer_token_bbb',
        refreshToken: 'groomer_refresh_bbb',
        groomerData: {'id': 50, 'fullName': 'Bob Groomer'},
      );

      expect(sessionService.isLoggedIn, isTrue);
      expect(sessionService.isGroomerLoggedIn, isTrue);

      String? attachedToken;

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        if (options.path.contains('/confirm-tip')) {
          attachedToken = options.headers['Authorization'];
          return MockAdapter.json({'success': true, 'message': 'Success'}, 200);
        }
        return MockAdapter.json({'message': 'Not found'}, 404);
      });

      await bookingRepository.confirmTipDetails(
        bookingId: 8,
        tipAmount: 15.0,
      );

      // The Authorization header MUST be the customer token, NEVER the groomer token!
      expect(attachedToken, equals('Bearer customer_token_aaa'));
      expect(attachedToken, isNot(contains('groomer_token_bbb')));
    });

    test('Guest tip confirmation NEVER sends Groomer token even if Groomer is logged in on same device', () async {
      // Clear customer session, but keep groomer logged in
      await sessionService.clearSession();
      await sessionService.saveGroomerSession(
        accessToken: 'groomer_token_bbb',
        refreshToken: 'groomer_refresh_bbb',
        groomerData: {'id': 50, 'fullName': 'Bob Groomer'},
      );

      expect(sessionService.isLoggedIn, isFalse);
      expect(sessionService.isGroomerLoggedIn, isTrue);

      String? attachedToken;

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        if (options.path.contains('/confirm-tip') || options.path.contains('/tip')) {
          attachedToken = options.headers['Authorization'];
          return MockAdapter.json({'success': true, 'message': 'Success'}, 200);
        }
        return MockAdapter.json({'message': 'Not found'}, 404);
      });

      await bookingRepository.confirmTipDetails(
        bookingId: 8,
        tipAmount: 5.0,
      );

      // Must NEVER leak groomer token on customer endpoint!
      expect(attachedToken, isNull);
    });
  });

  group('Scenario 8: In-Flight Deduplication', () {
    test('Concurrent confirmTipDetails calls for the same booking ID send only ONE API request', () async {
      int apiCallCount = 0;

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        if (options.path.contains('/confirm-tip')) {
          apiCallCount++;
          await Future.delayed(const Duration(milliseconds: 50));
          return MockAdapter.json({'success': true, 'message': 'Confirmed'}, 200);
        }
        return MockAdapter.json({'message': 'Not found'}, 404);
      });

      final future1 = bookingRepository.confirmTipDetails(bookingId: 8, tipAmount: 10.0);
      final future2 = bookingRepository.confirmTipDetails(bookingId: 8, tipAmount: 10.0);
      final future3 = bookingRepository.confirmTipDetails(bookingId: 8, tipAmount: 10.0);

      final results = await Future.wait([future1, future2, future3]);

      expect(apiCallCount, equals(1));
      expect(results[0].success, isTrue);
      expect(results[1].success, isTrue);
      expect(results[2].success, isTrue);
    });
  });

  group('Scenario 9: Final Checkout Remains a Separate Groomer Action', () {
    test('Customer tip confirmation records tip preference without changing status to completed', () async {
      const initialBooking = {
        'id': 8,
        'bookingId': 8,
        'status': 'ready_for_checkout',
        'isPaid': false,
      };

      apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
        return MockAdapter.json({'success': true}, 200);
      });

      final result = await bookingRepository.confirmTipDetails(
        bookingId: 8,
        tipAmount: 20.0,
        booking: initialBooking,
      );

      expect(result.success, isTrue);
      expect(result.updatedBooking?['status'], equals('ready_for_checkout'));
      expect(result.updatedBooking?['status'], isNot(equals('completed')));
      expect(result.updatedBooking?['status'], isNot(equals('checkout_completed')));
      expect(result.updatedBooking?['isPaid'], isNot(equals(true)));
    });
  });
}
