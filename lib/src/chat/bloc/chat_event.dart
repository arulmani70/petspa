part of 'chat_bloc.dart';

sealed class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class InitializeChat extends ChatEvent {
  const InitializeChat();
}

class FetchChatHistory extends ChatEvent {
  const FetchChatHistory();
}

class SendMessageEvent extends ChatEvent {
  final String message;
  final bool useAssistant;

  const SendMessageEvent(this.message, {this.useAssistant = true});

  @override
  List<Object?> get props => [message, useAssistant];
}

class ClearChatEvent extends ChatEvent {
  const ClearChatEvent();
}

class ChatRealtimeMessageReceived extends ChatEvent {
  final ChatMessage message;
  const ChatRealtimeMessageReceived(this.message);

  @override
  List<Object?> get props => [message];
}

class JoinConversationEvent extends ChatEvent {
  final String conversationId;
  const JoinConversationEvent(this.conversationId);

  @override
  List<Object?> get props => [conversationId];
}

class LeaveConversationEvent extends ChatEvent {
  final String conversationId;
  const LeaveConversationEvent(this.conversationId);

  @override
  List<Object?> get props => [conversationId];
}
