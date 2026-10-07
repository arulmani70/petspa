import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/chat/models/chat_message_model.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';

class ChatRepository {
  final Logger _log = Logger();

  Future<void> initialize() async {
    _log.d('ChatRepository::initialize::Initialized');
  }

  /// Ensures that the Customer Socket.IO connection is active.
  Future<void> ensureConnected() async {
    if (ServicesLocator.isCustomerSocketServiceRegistered) {
      await ServicesLocator.customerSocketService.ensureConnected();
    }
  }

  /// Automatically joins customer's personal chat rooms.
  void joinUserRooms([String? userId]) {
    if (ServicesLocator.isCustomerSocketServiceRegistered) {
      ServicesLocator.customerSocketService.joinUserRooms(userId);
    }
  }

  /// Real-time stream of incoming customer chat messages from Socket.IO.
  Stream<ChatMessage> get realtimeChatMessageStream {
    if (!ServicesLocator.isCustomerSocketServiceRegistered) {
      return const Stream.empty();
    }
    return ServicesLocator.customerSocketService.onChatMessage;
  }

  /// Real-time socket connection state stream.
  Stream<bool> get realtimeConnectionStatusStream {
    if (!ServicesLocator.isCustomerSocketServiceRegistered) {
      return const Stream.empty();
    }
    return ServicesLocator.customerSocketService.onConnectionStatus;
  }

  /// Joins a specific chat room / conversation.
  void joinConversation(String conversationId) {
    if (ServicesLocator.isCustomerSocketServiceRegistered) {
      ServicesLocator.customerSocketService.joinConversation(conversationId);
    }
  }

  /// Leaves a specific chat room / conversation.
  void leaveConversation(String conversationId) {
    if (ServicesLocator.isCustomerSocketServiceRegistered) {
      ServicesLocator.customerSocketService.leaveConversation(conversationId);
    }
  }

  /// Emits a message over Socket.IO in real time.
  void sendSocketMessage(String message, {String? conversationId, Map<String, dynamic>? extraData}) {
    if (ServicesLocator.isCustomerSocketServiceRegistered) {
      ServicesLocator.customerSocketService.sendMessage(
        message: message,
        conversationId: conversationId,
        extraData: extraData,
      );
    }
  }

  /// Fetches conversation history from GET /api/chat/history
  Future<List<ChatMessage>> getChatHistory() async {
    try {
      _log.d('ChatRepository::getChatHistory::Fetching chat history');
      final response = await ServicesLocator.apiRepository.get('/api/chat/history');

      if (response != null && response['success'] == true && response['data'] != null) {
        final data = response['data'];
        List<dynamic> list = [];
        if (data is List) {
          list = data;
        } else if (data is Map<String, dynamic>) {
          if (data['messages'] is List) {
            list = data['messages'] as List;
          } else if (data['history'] is List) {
            list = data['history'] as List;
          } else if (data['chats'] is List) {
            list = data['chats'] as List;
          }
        }

        final messages = list
            .whereType<Map>()
            .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
            .toList();

        _log.d('ChatRepository::getChatHistory::Fetched ${messages.length} messages');
        return messages;
      }

      _log.w('ChatRepository::getChatHistory::Empty or unsuccessful response');
      return [];
    } catch (e) {
      _log.e('ChatRepository::getChatHistory::Error fetching chat history: $e');
      return [];
    }
  }

  /// Sends a customer message via POST /api/chat/send
  Future<ChatMessage?> sendMessage(String message) async {
    try {
      final trimmed = message.trim();
      if (trimmed.isEmpty) return null;

      _log.d('ChatRepository::sendMessage::Sending message: $trimmed');
      final response = await ServicesLocator.apiRepository.post(
        '/api/chat/send',
        {'message': trimmed},
      );

      if (response != null && response['success'] == true) {
        final data = response['data'];
        if (data is Map<String, dynamic>) {
          return ChatMessage.fromJson(data);
        } else if (data is Map) {
          return ChatMessage.fromJson(Map<String, dynamic>.from(data));
        } else if (data is String && data.isNotEmpty) {
          final clean = cleanChatMessage(data);
          return ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: 'assistant',
            message: clean,
            isUser: false,
            createdAt: DateTime.now(),
          );
        }
        return ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: 'user',
          message: trimmed,
          isUser: true,
          createdAt: DateTime.now(),
        );
      }

      _log.w('ChatRepository::sendMessage::Unsuccessful response: $response');
      return null;
    } catch (e) {
      _log.e('ChatRepository::sendMessage::Error sending message: $e');
      return null;
    }
  }

  /// Sends a question/message to the AI Assistant via POST /api/chat/assistant
  Future<ChatMessage?> askAssistant(String message) async {
    try {
      final trimmed = message.trim();
      if (trimmed.isEmpty) return null;

      _log.d('ChatRepository::askAssistant::Querying assistant: $trimmed');
      final response = await ServicesLocator.apiRepository.post(
        '/api/chat/assistant',
        {'message': trimmed},
      );

      if (response != null && response['success'] == true) {
        final data = response['data'];
        if (data is Map<String, dynamic>) {
          return ChatMessage.fromJson(data);
        } else if (data is Map) {
          return ChatMessage.fromJson(Map<String, dynamic>.from(data));
        } else if (data is String && data.isNotEmpty) {
          final clean = cleanChatMessage(data);
          return ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: 'assistant',
            message: clean,
            isUser: false,
            createdAt: DateTime.now(),
          );
        }
        return ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: 'assistant',
          message: 'How can I assist you with Shear Heaven services today?',
          isUser: false,
          createdAt: DateTime.now(),
        );
      }

      _log.w('ChatRepository::askAssistant::Unsuccessful response: $response');
      return null;
    } catch (e) {
      _log.e('ChatRepository::askAssistant::Error querying assistant: $e');
      return null;
    }
  }
}
