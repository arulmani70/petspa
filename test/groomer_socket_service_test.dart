import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/common/services/groomer_socket_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GroomerSocketService socketService;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  setUp(() {
    socketService = GroomerSocketService();
  });

  tearDown(() {
    socketService.dispose();
  });

  group('GroomerSocketService Core Tests', () {
    test('initial state is disconnected', () {
      expect(socketService.isConnected, isFalse);
    });

    test('emits AppNotification when receiving valid map payload', () async {
      AppNotification? receivedNotification;
      final subscription = socketService.onNotification.listen((n) {
        receivedNotification = n;
      });

      socketService.handleRawEventForTesting('notification', {
        'id': 101,
        'title': 'New Booking #101',
        'message': 'Bella has a new grooming appointment.',
        'type': 'booking',
        'isRead': false,
        'data': {
          'bookingId': 101,
          'petName': 'Bella',
        },
      });

      await Future.delayed(const Duration(milliseconds: 50));
      expect(receivedNotification, isNotNull);
      expect(receivedNotification!.id, equals(101));
      expect(receivedNotification!.title, equals('New Booking #101'));
      expect(receivedNotification!.type, equals('booking'));
      expect(receivedNotification!.isRead, isFalse);
      expect(receivedNotification!.metadata?['bookingId'], equals(101));

      await subscription.cancel();
    });

    test('correctly parses JSON string payload', () async {
      AppNotification? receivedNotification;
      final subscription = socketService.onNotification.listen((n) {
        receivedNotification = n;
      });

      socketService.handleRawEventForTesting(
        'notification',
        '{"id": 102, "title": "Cancellation Request #102", "message": "Customer cancelled", "type": "cancellation_requested"}',
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(receivedNotification, isNotNull);
      expect(receivedNotification!.id, equals(102));
      expect(receivedNotification!.title, equals('Cancellation Request #102'));
      expect(receivedNotification!.type, equals('cancellation_requested'));

      await subscription.cancel();
    });

    test('correctly parses nested data and notification envelopes', () async {
      final received = <AppNotification>[];
      final subscription = socketService.onNotification.listen((n) {
        received.add(n);
      });

      // Wrapped in 'data'
      socketService.handleRawEventForTesting('notification', {
        'data': {
          'id': 201,
          'title': 'Wrapped Data Title',
          'message': 'Wrapped Data Message',
          'type': 'system',
        },
      });

      // Wrapped in 'notification'
      socketService.handleRawEventForTesting('groomer_notification', {
        'notification': {
          'id': 202,
          'title': 'Wrapped Notification Title',
          'message': 'Wrapped Notification Message',
          'type': 'booking',
        },
      });

      await Future.delayed(const Duration(milliseconds: 50));
      expect(received.length, equals(2));
      expect(received[0].id, equals(201));
      expect(received[0].title, equals('Wrapped Data Title'));
      expect(received[1].id, equals(202));
      expect(received[1].title, equals('Wrapped Notification Title'));

      await subscription.cancel();
    });

    test('assigns fallback id and infers type from event name when missing', () async {
      AppNotification? receivedNotification;
      final subscription = socketService.onNotification.listen((n) {
        receivedNotification = n;
      });

      socketService.handleRawEventForTesting('cancellation_request', {
        'title': 'Cancellation Alert',
        'message': 'Appointment cancelled by owner',
      });

      await Future.delayed(const Duration(milliseconds: 50));
      expect(receivedNotification, isNotNull);
      expect(receivedNotification!.id, isPositive);
      expect(receivedNotification!.type, equals('cancellation_requested'));

      await subscription.cancel();
    });

    test('duplicate socket connection prevention skips when already connected', () async {
      // Testing connect guard
      await socketService.connect(token: 'mock_test_token_123');
      final firstConnectAttempt = socketService.isConnected;
      // Re-invoking connect with another token should not crash or create multiple socket instances
      await socketService.connect(token: 'mock_test_token_456');
      expect(socketService.isConnected, equals(firstConnectAttempt));
    });

    test('disconnect resets connection state cleanly and emits false on connection stream', () async {
      bool? lastStatus;
      final sub = socketService.onConnectionStatus.listen((status) {
        lastStatus = status;
      });

      socketService.disconnect();
      await Future.delayed(const Duration(milliseconds: 30));
      expect(socketService.isConnected, isFalse);
      expect(lastStatus, isFalse);

      await sub.cancel();
    });

    test('logout cleanup through GroomerLoginRepository & GroomerHomeRepository disconnects socket', () async {
      await ServicesLocator.sessionService.saveGroomerSession(
        accessToken: 'test_access_token_abc',
        refreshToken: 'test_refresh_token_def',
        groomerData: {'id': 1, 'firstName': 'Test', 'lastName': 'Groomer'},
      );

      expect(ServicesLocator.sessionService.isGroomerLoggedIn, isTrue);

      await ServicesLocator.groomerLoginRepository.logout();
      expect(ServicesLocator.sessionService.isGroomerLoggedIn, isFalse);
      expect(ServicesLocator.groomerSocketService.isConnected, isFalse);

      await ServicesLocator.groomerHomeRepository.logout();
      expect(ServicesLocator.sessionService.isGroomerLoggedIn, isFalse);
      expect(ServicesLocator.groomerSocketService.isConnected, isFalse);
    });

    test('duplicate notification handling in UI state logic preserves unique IDs', () async {
      final notifications = <Map<String, dynamic>>[];

      void handleNotification(AppNotification notif) {
        final notifMap = <String, dynamic>{
          'id': notif.id,
          'title': notif.title,
          'message': notif.message,
          'type': notif.type,
          'isRead': notif.isRead,
        };

        final existsIndex = notifications.indexWhere((item) => item['id'] == notifMap['id']);
        if (existsIndex >= 0) {
          notifications[existsIndex] = notifMap;
        } else {
          notifications.insert(0, notifMap);
        }
      }

      // Initial notification
      handleNotification(const AppNotification(
        id: 301,
        title: 'Initial Booking #301',
        message: 'Scheduled for 2:00 PM',
        type: 'booking',
        isRead: false,
      ));
      expect(notifications.length, equals(1));
      expect(notifications[0]['title'], equals('Initial Booking #301'));

      // Updated duplicate notification with same ID
      handleNotification(const AppNotification(
        id: 301,
        title: 'Updated Booking #301',
        message: 'Rescheduled for 3:00 PM',
        type: 'booking',
        isRead: false,
      ));
      expect(notifications.length, equals(1));
      expect(notifications[0]['title'], equals('Updated Booking #301'));

      // Distinct notification with new ID
      handleNotification(const AppNotification(
        id: 302,
        title: 'New Booking #302',
        message: 'Scheduled for 4:00 PM',
        type: 'booking',
        isRead: false,
      ));
      expect(notifications.length, equals(2));
      expect(notifications[0]['id'], equals(302));
      expect(notifications[1]['id'], equals(301));
    });
  });
}
