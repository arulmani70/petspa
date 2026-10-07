import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/chat/models/chat_message_model.dart';
import 'package:shear_heaven_pet_spa/src/common/services/customer_socket_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CustomerSocketService socketService;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  setUp(() {
    socketService = CustomerSocketService();
  });

  tearDown(() {
    socketService.dispose();
  });

  group('CustomerSocketService Core Tests', () {
    test('initial state is disconnected', () {
      expect(socketService.isConnected, isFalse);
      expect(socketService.activeRooms, isEmpty);
    });

    test('emits AppNotification when receiving valid map payload', () async {
      AppNotification? receivedNotification;
      final subscription = socketService.onNotification.listen((n) {
        receivedNotification = n;
      });

      socketService.handleRawEventForTesting('notification', {
        'id': 1001,
        'title': 'Booking Confirmed #1001',
        'message': 'Your appointment for Bella has been confirmed.',
        'type': 'booking_confirmed',
        'isRead': false,
        'metadata': {
          'bookingId': 1001,
          'petName': 'Bella',
        },
      });

      await Future.delayed(const Duration(milliseconds: 50));
      expect(receivedNotification, isNotNull);
      expect(receivedNotification!.id, equals(1001));
      expect(receivedNotification!.title, equals('Booking Confirmed #1001'));
      expect(receivedNotification!.type, equals('booking_confirmed'));
      expect(receivedNotification!.isRead, isFalse);
      expect(receivedNotification!.metadata?['bookingId'], equals(1001));

      await subscription.cancel();
    });

    test('correctly parses JSON string payload for notification', () async {
      AppNotification? receivedNotification;
      final subscription = socketService.onNotification.listen((n) {
        receivedNotification = n;
      });

      socketService.handleRawEventForTesting(
        'notification',
        '{"id": 1002, "title": "50% Off Grooming!", "message": "Use promo PAWSOME50", "type": "offer"}',
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(receivedNotification, isNotNull);
      expect(receivedNotification!.id, equals(1002));
      expect(receivedNotification!.title, equals('50% Off Grooming!'));
      expect(receivedNotification!.type, equals('offer'));

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
          'id': 2001,
          'title': 'Wrapped Customer Data Title',
          'message': 'Your groomer is on the way',
          'type': 'booking',
        },
      });

      // Wrapped in 'notification'
      socketService.handleRawEventForTesting('customer_notification', {
        'notification': {
          'id': 2002,
          'title': 'Wrapped Customer Notification Title',
          'message': 'Grooming service completed',
          'type': 'completed',
        },
      });

      await Future.delayed(const Duration(milliseconds: 50));
      expect(received.length, equals(2));
      expect(received[0].id, equals(2001));
      expect(received[0].title, equals('Wrapped Customer Data Title'));
      expect(received[1].id, equals(2002));
      expect(received[1].title, equals('Wrapped Customer Notification Title'));

      await subscription.cancel();
    });

    test('assigns fallback id and infers type from event name when missing', () async {
      AppNotification? receivedNotification;
      final subscription = socketService.onNotification.listen((n) {
        receivedNotification = n;
      });

      socketService.handleRawEventForTesting('booking_notification', {
        'title': 'Booking Status Update',
        'message': 'Your grooming session is now in progress',
      });

      await Future.delayed(const Duration(milliseconds: 50));
      expect(receivedNotification, isNotNull);
      expect(receivedNotification!.id, isPositive);
      expect(receivedNotification!.type, equals('booking'));

      await subscription.cancel();
    });

    test('disconnect resets connection state and rooms cleanly', () {
      socketService.joinConversation('room_123');
      expect(socketService.activeRooms.contains('room_123'), isTrue);

      socketService.disconnect();
      expect(socketService.isConnected, isFalse);
      expect(socketService.activeRooms, isEmpty);
    });
  });

  group('CustomerSocketService Chat Tests', () {
    test('emits ChatMessage on onChatMessage stream when receiving Map payload', () async {
      ChatMessage? receivedMessage;
      final subscription = socketService.onChatMessage.listen((m) {
        receivedMessage = m;
      });

      socketService.handleRawChatEventForTesting('chat_message', {
        'id': 'msg_101',
        'sender': 'assistant',
        'message': 'Hello, how can I help you today?',
        'createdAt': '2026-08-27T10:00:00.000Z',
      });

      await Future.delayed(const Duration(milliseconds: 50));
      expect(receivedMessage, isNotNull);
      expect(receivedMessage!.id, equals('msg_101'));
      expect(receivedMessage!.sender, equals('assistant'));
      expect(receivedMessage!.message, equals('Hello, how can I help you today?'));
      expect(receivedMessage!.isUser, isFalse);

      await subscription.cancel();
    });

    test('correctly parses JSON string chat message payload', () async {
      ChatMessage? receivedMessage;
      final subscription = socketService.onChatMessage.listen((m) {
        receivedMessage = m;
      });

      socketService.handleRawChatEventForTesting(
        'new_message',
        '{"id": "msg_102", "sender": "support", "message": "Your groomer has arrived!", "createdAt": "2026-08-27T10:05:00.000Z"}',
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(receivedMessage, isNotNull);
      expect(receivedMessage!.id, equals('msg_102'));
      expect(receivedMessage!.sender, equals('support'));
      expect(receivedMessage!.message, equals('Your groomer has arrived!'));
      expect(receivedMessage!.isUser, isFalse);

      await subscription.cancel();
    });

    test('correctly parses chat envelopes (chat, message, data)', () async {
      final received = <ChatMessage>[];
      final subscription = socketService.onChatMessage.listen((m) {
        received.add(m);
      });

      // Wrapped in 'chat'
      socketService.handleRawChatEventForTesting('chat_message', {
        'chat': {
          'id': 'msg_201',
          'sender': 'assistant',
          'message': 'Wrapped in chat envelope',
        },
      });

      // Wrapped in 'data'
      socketService.handleRawChatEventForTesting('message', {
        'data': {
          'id': 'msg_202',
          'sender': 'user',
          'message': 'Wrapped in data envelope',
        },
      });

      await Future.delayed(const Duration(milliseconds: 50));
      expect(received.length, equals(2));
      expect(received[0].id, equals('msg_201'));
      expect(received[0].message, equals('Wrapped in chat envelope'));
      expect(received[1].id, equals('msg_202'));
      expect(received[1].message, equals('Wrapped in data envelope'));
      expect(received[1].isUser, isTrue);

      await subscription.cancel();
    });

    test('room management tracks joined rooms and avoids duplicates', () {
      socketService.joinConversation('conv_456');
      expect(socketService.activeRooms.contains('conv_456'), isTrue);
      expect(socketService.activeRooms.length, equals(1));

      // Duplicate join
      socketService.joinConversation('conv_456');
      expect(socketService.activeRooms.length, equals(1));

      // Leave conversation
      socketService.leaveConversation('conv_456');
      expect(socketService.activeRooms.contains('conv_456'), isFalse);
    });

    test('emitChatMessageForTesting directly delivers message', () async {
      ChatMessage? received;
      final subscription = socketService.onChatMessage.listen((m) => received = m);

      final msg = ChatMessage(
        id: 'test_999',
        sender: 'assistant',
        message: 'Direct test message',
        isUser: false,
        createdAt: DateTime.now(),
      );

      socketService.emitChatMessageForTesting(msg);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(received, isNotNull);
      expect(received!.id, equals('test_999'));
      expect(received!.message, equals('Direct test message'));

      await subscription.cancel();
    });
  });
}
