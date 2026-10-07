import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'package:shear_heaven_pet_spa/src/chat/bloc/chat_bloc.dart';
import 'package:shear_heaven_pet_spa/src/chat/models/chat_message_model.dart';
import 'package:shear_heaven_pet_spa/src/chat/repo/chat_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/customer_socket_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';

class _MockApiRepository extends ApiRepository {
  @override
  Future<Map<String, dynamic>?> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/api/chat/history') {
      return {
        'success': true,
        'message': 'History',
        'data': [
          {
            'id': 'hist_1',
            'sender': 'assistant',
            'message': 'Welcome to Shear Heaven!',
            'createdAt': '2026-08-27T09:00:00.000Z',
          }
        ]
      };
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> post(String path, Map<String, dynamic> data) async {
    if (path == '/api/chat/send') {
      return {
        'success': true,
        'message': 'Sent',
        'data': {
          'id': 'sent_101',
          'sender': 'user',
          'message': data['message'] ?? '',
          'createdAt': '2026-08-27T09:01:00.000Z',
        }
      };
    } else if (path == '/api/chat/assistant') {
      return {
        'success': true,
        'message': 'Assistant reply',
        'data': {
          'id': 'reply_102',
          'sender': 'assistant',
          'message': 'Reply for: ${data['message']}',
          'createdAt': '2026-08-27T09:01:02.000Z',
        }
      };
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionService sessionService;
  late CustomerSocketService socketService;
  late ChatRepository chatRepository;
  late ChatBloc chatBloc;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    sessionService = SessionService();
    await sessionService.initialize();
    await sessionService.saveTokens(accessToken: 'test_jwt_token_123', refreshToken: 'test_refresh_123');
    await sessionService.saveSession({
      'id': 42,
      'name': 'Customer Test',
      'email': 'customer@test.com',
    });

    final api = _MockApiRepository();
    await api.initialize();

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<SessionService>(sessionService);
    GetIt.I.registerSingleton<ApiRepository>(api);

    socketService = CustomerSocketService();
    GetIt.I.registerSingleton<CustomerSocketService>(socketService);

    chatRepository = ChatRepository();
    await chatRepository.initialize();
    GetIt.I.registerSingleton<ChatRepository>(chatRepository);

    chatBloc = ChatBloc(repository: chatRepository);
  });

  tearDown(() {
    chatBloc.close();
    socketService.dispose();
  });

  group('Customer Chat Realtime & Deduplication Tests', () {
    test('ChatBloc appends new realtime incoming messages to state.messages', () async {
      expect(chatBloc.state.messages, isEmpty);

      final msg = ChatMessage(
        id: 'msg_501',
        sender: 'groomer',
        message: 'Your dog is ready for pickup!',
        isUser: false,
        createdAt: DateTime.now(),
      );

      socketService.emitChatMessageForTesting(msg);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(chatBloc.state.messages.length, equals(1));
      expect(chatBloc.state.messages.first.id, equals('msg_501'));
      expect(chatBloc.state.messages.first.message, equals('Your dog is ready for pickup!'));
    });

    test('ChatBloc deduplicates messages with the same id', () async {
      final msg = ChatMessage(
        id: 'dup_msg_1',
        sender: 'assistant',
        message: 'Same message received twice',
        isUser: false,
        createdAt: DateTime.now(),
      );

      socketService.emitChatMessageForTesting(msg);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(chatBloc.state.messages.length, equals(1));
      expect(chatBloc.state.messages.first.id, equals('dup_msg_1'));

      // Send same message again
      socketService.emitChatMessageForTesting(msg);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(chatBloc.state.messages.length, equals(1));
      expect(chatBloc.state.messages.first.id, equals('dup_msg_1'));
    });

    test('ChatBloc replaces optimistic user message when server message arrives', () async {
      // Manually add optimistic local message to simulate sending in-flight
      final localMsg = ChatMessage(
        id: 'local_12345',
        sender: 'user',
        message: 'Hello Groomer',
        isUser: true,
        createdAt: DateTime.now(),
      );

      // Simulate incoming server confirmation with actual ID
      final serverMsg = ChatMessage(
        id: 'srv_777',
        sender: 'user',
        message: 'Hello Groomer',
        isUser: true,
        createdAt: DateTime.now(),
      );

      // Add local message first via state emission
      chatBloc.emit(chatBloc.state.copyWith(
        messages: () => [localMsg],
        isTyping: () => true,
      ));

      expect(chatBloc.state.messages.length, equals(1));
      expect(chatBloc.state.messages.first.id, equals('local_12345'));

      // Now server message arrives over socket
      socketService.emitChatMessageForTesting(serverMsg);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(chatBloc.state.messages.length, equals(1));
      expect(chatBloc.state.messages.first.id, equals('srv_777'));
      expect(chatBloc.state.messages.first.message, equals('Hello Groomer'));
    });

    test('ChatBloc deduplicates REST API response and duplicate WebSocket reply', () async {
      final restReply = ChatMessage(
        id: 'reply_102',
        sender: 'assistant',
        message: 'Reply for: What are your store hours?',
        isUser: false,
        createdAt: DateTime.now(),
      );

      chatBloc.emit(chatBloc.state.copyWith(
        messages: () => [restReply],
        isTyping: () => true,
      ));

      expect(chatBloc.state.messages.length, equals(1));

      // Duplicate socket event with same content arrives within 15 seconds
      final wsReply = ChatMessage(
        id: 'srv_reply_999',
        sender: 'assistant',
        message: 'Reply for: What are your store hours?',
        isUser: false,
        createdAt: DateTime.now(),
      );

      socketService.emitChatMessageForTesting(wsReply);
      await Future.delayed(const Duration(milliseconds: 50));

      // Should update without creating a second bubble
      expect(chatBloc.state.messages.length, equals(1));
      expect(chatBloc.state.messages.first.id, equals('srv_reply_999'));
      expect(chatBloc.state.isTyping, isFalse);
    });

    test('ChatBloc handles join and leave conversation events', () async {
      chatBloc.add(const JoinConversationEvent('room_groomer_123'));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(socketService.activeRooms.contains('room_groomer_123'), isTrue);

      chatBloc.add(const LeaveConversationEvent('room_groomer_123'));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(socketService.activeRooms.contains('room_groomer_123'), isFalse);
    });

    test('ChatBloc clears typing indicator on incoming assistant response', () async {
      // Simulate isTyping active
      chatBloc.emit(chatBloc.state.copyWith(
        isTyping: () => true,
      ));
      expect(chatBloc.state.isTyping, isTrue);

      final reply = ChatMessage(
        id: 'reply_801',
        sender: 'assistant',
        message: 'Here to help!',
        isUser: false,
        createdAt: DateTime.now(),
      );

      socketService.emitChatMessageForTesting(reply);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(chatBloc.state.isTyping, isFalse);
      expect(chatBloc.state.messages.any((m) => m.id == 'reply_801'), isTrue);
    });

    test('InitializeChat loads history, ensures connection, and joins user rooms', () async {
      chatBloc.add(const InitializeChat());
      await Future.delayed(const Duration(milliseconds: 100));

      expect(chatBloc.state.status, equals(ChatStatus.loaded));
      expect(chatBloc.state.messages.length, equals(1));
      expect(chatBloc.state.messages.first.message, equals('Welcome to Shear Heaven!'));

      // Verify user rooms joined
      expect(socketService.activeRooms.contains('user_42'), isTrue);
      expect(socketService.activeRooms.contains('customer_42'), isTrue);
      expect(socketService.activeRooms.contains('42'), isTrue);
      expect(socketService.activeRooms.contains('customer_chat'), isTrue);
    });

    test('CustomerSocketService handles receiveMessage, receive_message, and nested payloads', () async {
      final received = <ChatMessage>[];
      final sub = socketService.onChatMessage.listen((m) => received.add(m));

      // 1. camelCase receiveMessage
      socketService.handleRawChatEventForTesting('receiveMessage', {
        'id': 'evt_1',
        'sender': 'groomer',
        'message': 'Grooming started',
      });

      // 2. snake_case receive_message
      socketService.handleRawChatEventForTesting('receive_message', {
        'id': 'evt_2',
        'sender': 'groomer',
        'message': 'Grooming halfway done',
      });

      // 3. Nested data.message envelope
      socketService.handleRawChatEventForTesting('newMessage', {
        'data': {
          'id': 'evt_3',
          'sender': 'assistant',
          'message': {
            'text': 'Your dog is ready for pickup!',
          },
        },
      });

      // 4. Nested payload.content envelope
      socketService.handleRawChatEventForTesting('chatMessage', {
        'payload': {
          'id': 'evt_4',
          'sender': 'support',
          'content': 'Support agent connected',
        },
      });

      // 5. Raw JSON string payload
      socketService.handleRawChatEventForTesting(
        'chat_message',
        '{"id": "evt_5", "sender": "groomer", "message": "Thanks for visiting!"}',
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(received.length, equals(5));
      expect(received[0].message, equals('Grooming started'));
      expect(received[1].message, equals('Grooming halfway done'));
      expect(received[2].message, equals('Your dog is ready for pickup!'));
      expect(received[3].message, equals('Support agent connected'));
      expect(received[4].message, equals('Thanks for visiting!'));

      await sub.cancel();
    });

    test('CustomerSocketService ignores empty chat payloads', () async {
      final received = <ChatMessage>[];
      final sub = socketService.onChatMessage.listen((m) => received.add(m));

      socketService.handleRawChatEventForTesting('receiveMessage', {
        'id': 'empty_1',
        'sender': 'assistant',
        'message': '   ',
      });

      await Future.delayed(const Duration(milliseconds: 50));
      expect(received, isEmpty);

      await sub.cancel();
    });
  });
}
