import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/chat/models/chat_message_model.dart';
import 'package:shear_heaven_pet_spa/src/chat/repo/chat_repository.dart';

part 'chat_event.dart';
part 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({required ChatRepository repository})
      : _repository = repository,
        super(ChatState.initial) {
    on<InitializeChat>(_onInitializeChat);
    on<FetchChatHistory>(_onFetchChatHistory);
    on<SendMessageEvent>(_onSendMessage);
    on<ChatRealtimeMessageReceived>(_onRealtimeMessageReceived);
    on<JoinConversationEvent>(_onJoinConversation);
    on<LeaveConversationEvent>(_onLeaveConversation);
    on<ClearChatEvent>(_onClearChat);

    _initSocketSubscription();
  }

  final ChatRepository _repository;
  final _log = Logger();
  StreamSubscription<ChatMessage>? _realtimeSub;

  void _initSocketSubscription() {
    _realtimeSub?.cancel();
    _realtimeSub = _repository.realtimeChatMessageStream.listen(
      (message) {
        _log.d('ChatBloc::Received realtime message #${message.id}: ${message.message}');
        add(ChatRealtimeMessageReceived(message));
      },
      onError: (err) {
        _log.e('ChatBloc::Realtime message stream error: $err');
      },
    );
  }

  void _onJoinConversation(
    JoinConversationEvent event,
    Emitter<ChatState> emit,
  ) {
    _log.d('ChatBloc::_onJoinConversation::Joining ${event.conversationId}');
    _repository.joinConversation(event.conversationId);
  }

  void _onLeaveConversation(
    LeaveConversationEvent event,
    Emitter<ChatState> emit,
  ) {
    _log.d('ChatBloc::_onLeaveConversation::Leaving ${event.conversationId}');
    _repository.leaveConversation(event.conversationId);
  }

  Future<void> _onInitializeChat(
    InitializeChat event,
    Emitter<ChatState> emit,
  ) async {
    _log.d('ChatBloc::_onInitializeChat::Initializing chat');
    try {
      emit(state.copyWith(status: () => ChatStatus.loading));

      // Ensure WebSocket connection is active and customer rooms are joined
      await _repository.ensureConnected();
      _repository.joinUserRooms();

      final history = await _repository.getChatHistory();
      emit(state.copyWith(
        status: () => ChatStatus.loaded,
        message: () => 'Chat history loaded',
        messages: () => history,
      ));
    } catch (e) {
      _log.e('ChatBloc::_onInitializeChat::Error: $e');
      emit(state.copyWith(
        status: () => ChatStatus.failure,
        message: () => e.toString(),
      ));
    }
  }

  Future<void> _onFetchChatHistory(
    FetchChatHistory event,
    Emitter<ChatState> emit,
  ) async {
    _log.d('ChatBloc::_onFetchChatHistory::Fetching chat history');
    try {
      emit(state.copyWith(status: () => ChatStatus.loading));

      // Ensure WebSocket connection is active and customer rooms are joined
      await _repository.ensureConnected();
      _repository.joinUserRooms();

      final history = await _repository.getChatHistory();
      emit(state.copyWith(
        status: () => ChatStatus.loaded,
        message: () => 'Chat history fetched',
        messages: () => history,
      ));
    } catch (e) {
      _log.e('ChatBloc::_onFetchChatHistory::Error: $e');
      emit(state.copyWith(
        status: () => ChatStatus.failure,
        message: () => e.toString(),
      ));
    }
  }

  Future<void> _onSendMessage(
    SendMessageEvent event,
    Emitter<ChatState> emit,
  ) async {
    final text = event.message.trim();
    if (text.isEmpty) return;

    _log.d('ChatBloc::_onSendMessage::Sending message: $text');

    // Ensure socket connected before sending
    await _repository.ensureConnected();

    final userMsg = ChatMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      sender: 'user',
      message: text,
      isUser: true,
      createdAt: DateTime.now(),
    );

    final updatedList = List<ChatMessage>.from(state.messages)..add(userMsg);

    emit(state.copyWith(
      status: () => ChatStatus.sending,
      messages: () => updatedList,
      isTyping: () => true,
    ));

    // Emit over Socket.IO for real-time delivery
    _repository.sendSocketMessage(text);

    try {
      ChatMessage? reply;
      if (event.useAssistant) {
        reply = await _repository.askAssistant(text);
      } else {
        reply = await _repository.sendMessage(text);
      }

      if (reply != null) {
        final currentMessages = List<ChatMessage>.from(state.messages);
        final existingIndex = currentMessages.indexWhere((m) => m.id == reply!.id);

        if (existingIndex >= 0) {
          currentMessages[existingIndex] = reply;
        } else {
          // Check if socket already delivered this exact reply content recently
          final duplicateRecentIndex = currentMessages.indexWhere(
            (m) =>
                m.sender == reply!.sender &&
                m.message.trim() == reply.message.trim() &&
                (m.createdAt != null &&
                    reply.createdAt != null &&
                    (m.createdAt!.difference(reply.createdAt!).inSeconds.abs() < 15)),
          );

          if (duplicateRecentIndex >= 0) {
            _log.d('ChatBloc::_onSendMessage::Updating matching recent reply message');
            currentMessages[duplicateRecentIndex] = reply;
          } else {
            currentMessages.add(reply);
          }
        }

        emit(state.copyWith(
          status: () => ChatStatus.success,
          message: () => 'Message sent',
          messages: () => currentMessages,
          isTyping: () => false,
        ));
      } else {
        emit(state.copyWith(
          status: () => ChatStatus.loaded,
          isTyping: () => false,
        ));
      }
    } catch (e) {
      _log.e('ChatBloc::_onSendMessage::Error: $e');
      emit(state.copyWith(
        status: () => ChatStatus.failure,
        message: () => e.toString(),
        isTyping: () => false,
      ));
    }
  }

  void _onRealtimeMessageReceived(
    ChatRealtimeMessageReceived event,
    Emitter<ChatState> emit,
  ) {
    final incoming = event.message;
    final currentList = List<ChatMessage>.from(state.messages);

    _log.i('ChatBloc::_onRealtimeMessageReceived::Processing realtime message id=${incoming.id}, sender=${incoming.sender}, text="${incoming.message}"');

    // 1. Exact ID deduplication
    final existingIndex = currentList.indexWhere((m) => m.id == incoming.id);
    if (existingIndex >= 0) {
      _log.d('ChatBloc::_onRealtimeMessageReceived::Updating existing message #${incoming.id}');
      currentList[existingIndex] = incoming;
      emit(state.copyWith(
        messages: () => currentList,
        isTyping: () => incoming.isUser ? state.isTyping : false,
      ));
      return;
    }

    // 2. Optimistic user message matching (replace local temporary message)
    if (incoming.isUser) {
      final optimisticIndex = currentList.indexWhere(
        (m) => m.id.startsWith('local_') && m.message.trim() == incoming.message.trim(),
      );
      if (optimisticIndex >= 0) {
        _log.d('ChatBloc::_onRealtimeMessageReceived::Replaced optimistic message with server message #${incoming.id}');
        currentList[optimisticIndex] = incoming;
        emit(state.copyWith(messages: () => currentList));
        return;
      }
    }

    // 3. Deduplicate recent assistant/server reply if REST API already added it with a different/local ID
    if (!incoming.isUser) {
      final duplicateRecentIndex = currentList.indexWhere(
        (m) =>
            m.sender == incoming.sender &&
            m.message.trim() == incoming.message.trim() &&
            (m.createdAt != null &&
                incoming.createdAt != null &&
                (m.createdAt!.difference(incoming.createdAt!).inSeconds.abs() < 15)),
      );
      if (duplicateRecentIndex >= 0) {
        _log.d('ChatBloc::_onRealtimeMessageReceived::Deduplicated matching recent server response with server id #${incoming.id}');
        currentList[duplicateRecentIndex] = incoming;
        emit(state.copyWith(
          messages: () => currentList,
          isTyping: () => false,
        ));
        return;
      }
    }

    // 4. New incoming message from recipient / assistant / groomer / support
    _log.i('ChatBloc::_onRealtimeMessageReceived::Appending new message #${incoming.id}');
    currentList.add(incoming);
    emit(state.copyWith(
      messages: () => currentList,
      isTyping: () => incoming.isUser ? state.isTyping : false,
      status: () => ChatStatus.loaded,
    ));
  }

  void _onClearChat(
    ClearChatEvent event,
    Emitter<ChatState> emit,
  ) {
    _log.d('ChatBloc::_onClearChat::Clearing chat');
    emit(ChatState.initial);
  }

  @override
  Future<void> close() {
    _realtimeSub?.cancel();
    return super.close();
  }
}
