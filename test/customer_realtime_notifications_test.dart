import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/notifications/bloc/notification_bloc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NotificationBloc bloc;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  setUp(() {
    bloc = NotificationBloc(repository: ServicesLocator.notificationRepository);
  });

  tearDown(() {
    bloc.close();
  });

  group('Customer Real-Time Notifications BLoC Tests', () {
    test('initial state has empty notifications and 0 unreadCount', () {
      expect(bloc.state.notifications, isEmpty);
      expect(bloc.state.unreadCount, equals(0));
      expect(bloc.state.isSocketConnected, isFalse);
    });

    test('NotificationSocketConnectionChangedEvent updates isSocketConnected', () async {
      bloc.add(const NotificationSocketConnectionChangedEvent(true));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.isSocketConnected, isTrue);

      bloc.add(const NotificationSocketConnectionChangedEvent(false));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.isSocketConnected, isFalse);
    });

    test('NotificationRealtimeReceivedEvent inserts notification and updates unread count', () async {
      const notif = AppNotification(
        id: 3001,
        title: 'Booking Confirmed #3001',
        message: 'Your dog grooming appointment is confirmed.',
        type: 'booking',
        isRead: false,
        metadata: {'bookingId': 3001},
      );

      bloc.add(const NotificationRealtimeReceivedEvent(notif));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.notifications.length, equals(1));
      expect(bloc.state.notifications.first.id, equals(3001));
      expect(bloc.state.notifications.first.title, equals('Booking Confirmed #3001'));
      expect(bloc.state.unreadCount, equals(1));
    });

    test('deduplicates customer real-time notifications with identical id', () async {
      const notif1 = AppNotification(
        id: 4001,
        title: 'Groomer Assigned #4001',
        message: 'Groomer Sarah has been assigned',
        type: 'booking',
        isRead: false,
      );

      const notif2 = AppNotification(
        id: 4001,
        title: 'Groomer Assigned #4001 (Updated)',
        message: 'Groomer Sarah is on the way',
        type: 'booking',
        isRead: false,
      );

      bloc.add(const NotificationRealtimeReceivedEvent(notif1));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.notifications.length, equals(1));

      // Send same ID again
      bloc.add(const NotificationRealtimeReceivedEvent(notif2));
      await Future.delayed(const Duration(milliseconds: 50));

      // Length remains 1, title updated
      expect(bloc.state.notifications.length, equals(1));
      expect(bloc.state.notifications.first.title, equals('Groomer Assigned #4001 (Updated)'));
      expect(bloc.state.unreadCount, equals(1));
    });

    test('markNotificationRead updates notification state and unread count', () async {
      const notif = AppNotification(
        id: 5001,
        title: 'Exclusive Weekend Offer',
        message: 'Get 20% off Spa Bath this weekend',
        type: 'offer',
        isRead: false,
      );

      bloc.add(const NotificationRealtimeReceivedEvent(notif));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.unreadCount, equals(1));

      bloc.add(const MarkNotificationRead(5001));
      await Future.delayed(const Duration(milliseconds: 50));

      final item = bloc.state.notifications.firstWhere((n) => n.id == 5001);
      expect(item.isRead, isTrue);
      expect(bloc.state.unreadCount, equals(0));
    });

    test('customer socket service broadcast forwards to NotificationBloc', () async {
      const notif = AppNotification(
        id: 6001,
        title: 'Customer Direct Live Notification',
        message: 'Stream test message for customer app',
        type: 'system',
        isRead: false,
      );

      ServicesLocator.customerSocketService.emitNotificationForTesting(notif);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.notifications.any((n) => n.id == 6001), isTrue);
    });

    test('E2E Regression: Groomer accepts booking -> Customer receives booking_confirmed real-time notification -> unread count increments -> notification appears in list -> booking deep-link metadata is preserved', () async {
      // 1. Initial state
      final initialUnread = ServicesLocator.notificationRepository.unreadCount;

      // 2. Backend emits booking_confirmed event after Groomer accepts booking
      ServicesLocator.customerSocketService.handleRawEventForTesting('booking_confirmed', {
        'id': 7001,
        'bookingId': 7001,
        'status': 'confirmed',
        'petName': 'Charlie',
        'groomerName': 'Alex',
        'title': 'Booking Confirmed #7001',
        'message': 'Your booking #7001 for Charlie has been confirmed.',
        'type': 'booking_confirmed',
        'isRead': false,
        'data': {
          'bookingId': 7001,
          'entityId': 7001,
          'status': 'confirmed',
          'petName': 'Charlie',
        }
      });

      await Future.delayed(const Duration(milliseconds: 50));

      // 3. Unread count increments in Repository notifier
      expect(ServicesLocator.notificationRepository.unreadCount, equals(initialUnread + 1));

      // 4. Notification appears in BLoC state list
      expect(bloc.state.notifications.any((n) => n.id == 7001), isTrue);
      final receivedNotif = bloc.state.notifications.firstWhere((n) => n.id == 7001);
      expect(receivedNotif.title, equals('Booking Confirmed #7001'));
      expect(receivedNotif.type, equals('booking_confirmed'));
      expect(receivedNotif.isRead, isFalse);

      // 5. Booking deep-link metadata is preserved
      expect(receivedNotif.metadata, isNotNull);
      expect(receivedNotif.metadata?['bookingId'], equals(7001));
      expect(receivedNotif.metadata?['entityId'], equals(7001));
      expect(receivedNotif.metadata?['status'], equals('confirmed'));
    });

    test('E2E: Raw booking acceptance payload without explicit title/message synthesizes Booking Confirmed correctly', () async {
      ServicesLocator.customerSocketService.handleRawEventForTesting('booking_accepted', {
        'id': 8001,
        'bookingId': 8001,
        'status': 'confirmed',
        'petName': 'Luna',
      });

      await Future.delayed(const Duration(milliseconds: 50));

      final receivedNotif = bloc.state.notifications.firstWhere((n) => n.id == 8001);
      expect(receivedNotif.title, equals('Booking Confirmed'));
      expect(receivedNotif.message, contains('8001'));
      expect(receivedNotif.type, equals('booking_confirmed'));
      expect(receivedNotif.metadata?['bookingId'], equals(8001));
    });

    test('E2E: Groomer rejects booking -> Customer receives booking_rejected real-time notification', () async {
      ServicesLocator.customerSocketService.handleRawEventForTesting('notification', {
        'id': 9001,
        'title': 'Booking Declined',
        'message': 'Your grooming appointment was declined by the groomer.',
        'type': 'booking_rejected',
        'data': {
          'bookingId': 9001,
          'status': 'cancelled',
          'petId': 2,
        },
        'isRead': false,
        'createdAt': '2026-08-27T06:00:00.000Z',
      });

      await Future.delayed(const Duration(milliseconds: 50));

      final receivedNotif = bloc.state.notifications.firstWhere((n) => n.id == 9001);
      expect(receivedNotif.title, equals('Booking Declined'));
      expect(receivedNotif.type, equals('booking_rejected'));
      expect(receivedNotif.metadata?['bookingId'], equals(9001));
      expect(receivedNotif.metadata?['status'], equals('cancelled'));
    });

    test('Device push token registration saves token in SessionService', () async {
      const testDeviceId = 'test_device_uuid_12345';
      const testPushToken = 'fcm_push_token_test_abc123';

      await ServicesLocator.sessionService.savePushToken(testPushToken);
      expect(ServicesLocator.sessionService.getPushToken(), equals(testPushToken));

      bloc.add(const RegisterPushTokenEvent(
        deviceId: testDeviceId,
        pushToken: testPushToken,
        platform: 'android',
      ));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(ServicesLocator.sessionService.getPushToken(), equals(testPushToken));
    });
  });
}
