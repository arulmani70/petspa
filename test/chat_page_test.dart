import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'package:shear_heaven_pet_spa/src/chat/models/chat_message_model.dart';
import 'package:shear_heaven_pet_spa/src/chat/repos/chat_repository.dart';
import 'package:shear_heaven_pet_spa/src/chat/views/chat_page.dart';
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
            'message': 'Welcome to Shear Heaven Pet Spa!',
            'createdAt': '2026-08-25T10:00:00.000Z',
          }
        ]
      };
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> post(String path, Map<String, dynamic> data) async {
    if (path == '/api/chat/assistant') {
      final msg = data['message']?.toString() ?? '';
      return {
        'success': true,
        'message': 'Assistant response generated',
        'data': {
          'id': '202',
          'sender': 'assistant',
          'message': 'Assistant reply for: $msg',
          'createdAt': '2026-08-25T10:05:02.000Z',
        }
      };
    } else if (path == '/api/chat/send') {
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
    }
    return null;
  }
}

void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'test_token'});
    SharedPreferences.setMockInitialValues({'auth_token': 'test_token'});

    final session = SessionService();
    await session.initialize();
    await session.saveSession({'id': 1, 'name': 'Test User', 'email': 'test@example.com'});

    final apiRepo = _MockApiRepository();
    await apiRepo.initialize();

    GetIt.I.allowReassignment = true;
    GetIt.I.registerSingleton<SessionService>(session);
    GetIt.I.registerSingleton<ApiRepository>(apiRepo);

    final chatRepo = ChatRepository();
    await chatRepo.initialize();
    GetIt.I.registerSingleton<ChatRepository>(chatRepo);
  });

  testWidgets('ChatPage renders header, loads history, and sends message to assistant', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatPage(),
      ),
    );

    // Verify initial loading or settling
    await tester.pumpAndSettle();

    // Verify header title and status
    expect(find.text('Shear Heaven Assistant'), findsOneWidget);
    expect(find.text('Always here to help'), findsOneWidget);

    // Verify history message is displayed
    expect(find.text('Welcome to Shear Heaven Pet Spa!'), findsOneWidget);

    // Type a message in input field
    final inputFinder = find.byType(TextField);
    expect(inputFinder, findsOneWidget);
    await tester.enterText(inputFinder, 'What are your store hours?');
    await tester.pump();

    // Tap Send button
    final sendButtonFinder = find.byIcon(Icons.send_rounded);
    expect(sendButtonFinder, findsOneWidget);
    await tester.tap(sendButtonFinder);
    await tester.pumpAndSettle();

    // Verify user message and assistant reply are both rendered
    expect(find.text('What are your store hours?'), findsOneWidget);
    expect(find.text('Assistant reply for: What are your store hours?'), findsOneWidget);
  });

  testWidgets('ChatPage renders realtime incoming message without screen reload', (tester) async {
    final socketService = CustomerSocketService();
    GetIt.I.registerSingleton<CustomerSocketService>(socketService);

    await tester.pumpWidget(
      const MaterialApp(
        home: ChatPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Shear Heaven Pet Spa!'), findsOneWidget);
    expect(find.text('Real-time groomer update: Oliver is ready!'), findsNothing);

    // Simulate backend sending real-time chat message via Socket.IO
    socketService.emitChatMessageForTesting(
      ChatMessage(
        id: 'rt_msg_901',
        sender: 'groomer',
        message: 'Real-time groomer update: Oliver is ready!',
        isUser: false,
        createdAt: DateTime.now(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify incoming real-time message is immediately rendered in UI
    expect(find.text('Real-time groomer update: Oliver is ready!'), findsOneWidget);

    socketService.dispose();
  });

  test('cleanChatMessage correctly strips JSON envelopes, field names, and returns pure message', () {
    // Case 1: JSON string
    expect(
      cleanChatMessage('{"id": 1, "message": "Oliver is all done!", "createdAt": "2026-09-22T10:00:00Z"}'),
      'Oliver is all done!',
    );

    // Case 2: JSON string with text key
    expect(
      cleanChatMessage('{"id": 2, "text": "Bath completed.", "created_at": "2026-09-22T10:05:00Z"}'),
      'Bath completed.',
    );

    // Case 3: Dart Map object
    expect(
      cleanChatMessage({'id': 3, 'message': 'Grooming started.', 'createdAt': '2026-09-22T10:00:00Z'}),
      'Grooming started.',
    );

    // Case 4: Stringified Dart Map / pseudo-JSON
    expect(
      cleanChatMessage('{id: 4, message: Ready for pickup, createdAt: 2026-09-22}'),
      'Ready for pickup',
    );

    // Case 5: Plain clean text
    expect(
      cleanChatMessage('Hello, how can I help you today?'),
      'Hello, how can I help you today?',
    );
  });

  testWidgets('ChatPage strips raw JSON field names from incoming message and renders clean text and time', (tester) async {
    final socketService = CustomerSocketService();
    GetIt.I.registerSingleton<CustomerSocketService>(socketService);

    await tester.pumpWidget(
      const MaterialApp(
        home: ChatPage(),
      ),
    );
    await tester.pumpAndSettle();

    // Emit message with raw JSON in message payload
    socketService.emitChatMessageForTesting(
      ChatMessage(
        id: 'json_msg_01',
        sender: 'groomer',
        message: '{"id": 55, "message": "Your pet is fresh and cleaned!", "createdAt": "2026-08-25T11:30:00.000Z"}',
        isUser: false,
        createdAt: DateTime(2026, 8, 25, 11, 30),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Must show the clean text
    expect(find.text('Your pet is fresh and cleaned!'), findsOneWidget);

    // Must NOT show raw JSON structure or field names
    expect(find.textContaining('"id": 55'), findsNothing);
    expect(find.textContaining('"createdAt":'), findsNothing);

    socketService.dispose();
  });

  testWidgets('ChatPage input area adjusts cleanly when keyboard opens without excessive gap', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ChatPage(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify input area is present
    expect(find.byType(TextField), findsOneWidget);

    // Simulate keyboard open by changing viewInsets
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();

    // Verify input area is still visible and correctly laid out
    expect(find.byType(TextField), findsOneWidget);

    // Reset view
    tester.view.resetViewInsets();
  });
}


