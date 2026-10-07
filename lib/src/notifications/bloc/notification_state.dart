part of 'notification_bloc.dart';

enum NotificationStatus { initial, loading, loaded, success, failure }

class NotificationState extends Equatable {
  final NotificationStatus status;
  final String message;
  final List<AppNotification> notifications;
  final int unreadCount;
  final bool isSocketConnected;

  const NotificationState({
    required this.status,
    required this.message,
    required this.notifications,
    required this.unreadCount,
    this.isSocketConnected = false,
  });

  static const NotificationState initial = NotificationState(
    status: NotificationStatus.initial,
    message: '',
    notifications: [],
    unreadCount: 0,
    isSocketConnected: false,
  );

  NotificationState copyWith({
    NotificationStatus Function()? status,
    String Function()? message,
    List<AppNotification> Function()? notifications,
    int Function()? unreadCount,
    bool Function()? isSocketConnected,
  }) {
    return NotificationState(
      status: status != null ? status() : this.status,
      message: message != null ? message() : this.message,
      notifications: notifications != null ? notifications() : this.notifications,
      unreadCount: unreadCount != null ? unreadCount() : this.unreadCount,
      isSocketConnected: isSocketConnected != null ? isSocketConnected() : this.isSocketConnected,
    );
  }

  @override
  List<Object?> get props => [status, message, notifications, unreadCount, isSocketConnected];
}
