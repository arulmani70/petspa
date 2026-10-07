import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'package:shear_heaven_pet_spa/src/chat/models/chat_message_model.dart';
import 'package:shear_heaven_pet_spa/src/chat/repos/chat_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/customer_socket_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';

class _MockApiRepository extends ApiRepository {
  @override
  Future<Map<String, dynamic>?> get(String path, {Map<String, dynamic>? query}) async {
    if (path == '/api/chat/history') {
      return {
        'success': true,
        'message': 'Chat history retrieved successfully',
        'data': [
          {
            'id': '101',
            'sender': 'assistant',
            'message': 'Hello! How can I help you today?',
            'createdAt': '2026-08-25T10:00:00.000Z',
          },
          {
            'id': '102',
            'sender': 'user',
            'message': 'What are your store hours?',
            'createdAt': '2026-08-25T10:01:00.000Z',
          },
          {
            'id': '103',
            'sender': 'assistant',
            'message': 'We are open Monday to Saturday, 9:00 AM to 6:00 PM.',
            'createdAt': '2026-08-25T10:01:05.000Z',
          }
        ]
      };
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> post(String path, Map<String, dynamic> data) async {
    if (path == '/api/chat/send') {
      final msg = data['message']?.toString() ?? '';
      return {
        'success': true,
        'message': 'Message sent successfully',
        'data': {
          'id': '201',
          'sender': 'user',
          'message': msg,
          'createdAt': '2026-08-25T10:05:00.000Z',
        }
      };
    } else if (path == '/api/chat/assistant') {
      final msg = data['message']?.toString() ?? '';
      return {
        'success': true,
        'message': 'Assistant response generated',
        'data': {
          'id': '202',
          'sender': 'assistant',
          'message': 'Automated reply for: $msg',
          'createdAt': '2026-08-25T10:05:02.000Z',
        }
      };
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatRepository chatRepo;

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    final session = SessionService();
    await session.initialize();
    await session.saveTokens(accessToken: 'mock_access_token', refreshToken: 'mock_refresh_token');

    final apiRepo = _MockApiRepository();
    await apiRepo.initialize();

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<SessionService>(session);
    GetIt.I.registerSingleton<ApiRepository>(apiRepo);

    chatRepo = ChatRepository();
    await chatRepo.initialize();
    GetIt.I.registerSingleton<ChatRepository>(chatRepo);
  });

  group('ChatRepository Tests', () {
    test('getChatHistory fetches and parses message history from GET /api/chat/history', () async {
      final history = await chatRepo.getChatHistory();
      expect(history.length, 3);
      expect(history[0].id, '101');
      expect(history[0].isUser, isFalse);
      expect(history[0].message, 'Hello! How can I help you today?');

      expect(history[1].id, '102');
      expect(history[1].isUser, isTrue);
      expect(history[1].message, 'What are your store hours?');

      expect(history[2].id, '103');
      expect(history[2].isUser, isFalse);
    });

    test('sendMessage sends customer message via POST /api/chat/send', () async {
      final msg = await chatRepo.sendMessage('Hello, I need assistance');
      expect(msg, isNotNull);
      expect(msg!.message, 'Hello, I need assistance');
      expect(msg.isUser, isTrue);
    });

    test('askAssistant sends query to AI assistant via POST /api/chat/assistant', () async {
      final reply = await chatRepo.askAssistant('What are your store hours?');
      expect(reply, isNotNull);
      expect(reply!.message, contains('Automated reply for: What are your store hours?'));
      expect(reply.isUser, isFalse);
    });

    test('sendMessage and askAssistant handle empty string without calling API', () async {
      final msg = await chatRepo.sendMessage('   ');
      expect(msg, isNull);

      final reply = await chatRepo.askAssistant('');
      expect(reply, isNull);
    });

    test('realtimeChatMessageStream emits incoming socket chat messages', () async {
      final socketService = CustomerSocketService();
      GetIt.I.registerSingleton<CustomerSocketService>(socketService);

      ChatMessage? received;
      final sub = chatRepo.realtimeChatMessageStream.listen((msg) => received = msg);

      final testMsg = ChatMessage(
        id: 'realtime_301',
        sender: 'groomer',
        message: 'Your dog Max is ready for pickup!',
        isUser: false,
        createdAt: DateTime.now(),
      );

      socketService.emitChatMessageForTesting(testMsg);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(received, isNotNull);
      expect(received!.id, equals('realtime_301'));
      expect(received!.sender, equals('groomer'));
      expect(received!.message, equals('Your dog Max is ready for pickup!'));

      await sub.cancel();
      socketService.dispose();
    });

    test('joinConversation, leaveConversation, and sendSocketMessage run safely', () {
      final socketService = CustomerSocketService();
      GetIt.I.registerSingleton<CustomerSocketService>(socketService);

      expect(() => chatRepo.joinConversation('room_abc'), returnsNormally);
      expect(() => chatRepo.sendSocketMessage('Hello via socket'), returnsNormally);
      expect(() => chatRepo.leaveConversation('room_abc'), returnsNormally);

      socketService.dispose();
    });
  });
}
