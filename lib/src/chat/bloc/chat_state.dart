part of 'chat_bloc.dart';

enum ChatStatus { initial, loading, loaded, sending, success, failure }

class ChatState extends Equatable {
  final ChatStatus status;
  final String message;
  final List<ChatMessage> messages;
  final bool isTyping;

  const ChatState({
    required this.status,
    required this.message,
    required this.messages,
    this.isTyping = false,
  });

  static const ChatState initial = ChatState(
    status: ChatStatus.initial,
    message: '',
    messages: [],
    isTyping: false,
  );

  ChatState copyWith({
    ChatStatus Function()? status,
    String Function()? message,
    List<ChatMessage> Function()? messages,
    bool Function()? isTyping,
  }) {
    return ChatState(
      status: status != null ? status() : this.status,
      message: message != null ? message() : this.message,
      messages: messages != null ? messages() : this.messages,
      isTyping: isTyping != null ? isTyping() : this.isTyping,
    );
  }

  @override
  List<Object?> get props => [status, message, messages, isTyping];
}
