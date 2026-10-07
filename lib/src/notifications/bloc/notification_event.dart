part of 'notification_bloc.dart';

sealed class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

class InitializeNotifications extends NotificationEvent {
  const InitializeNotifications();
}

class FetchNotifications extends NotificationEvent {
  const FetchNotifications();
}

class MarkNotificationRead extends NotificationEvent {
  final int notificationId;

  const MarkNotificationRead(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

class MarkAllNotificationsRead extends NotificationEvent {
  const MarkAllNotificationsRead();
}

class DeleteNotificationEvent extends NotificationEvent {
  final int notificationId;

  const DeleteNotificationEvent(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

class RegisterPushTokenEvent extends NotificationEvent {
  final String deviceId;
  final String pushToken;
  final String? platform;

  const RegisterPushTokenEvent({
    required this.deviceId,
    required this.pushToken,
    this.platform,
  });

  @override
  List<Object?> get props => [deviceId, pushToken, platform];
}

class NotificationConnectSocketEvent extends NotificationEvent {
  final String? token;
  final String? serverUrl;

  const NotificationConnectSocketEvent({this.token, this.serverUrl});

  @override
  List<Object?> get props => [token, serverUrl];
}

class NotificationSocketConnectionChangedEvent extends NotificationEvent {
  final bool isConnected;

  const NotificationSocketConnectionChangedEvent(this.isConnected);

  @override
  List<Object?> get props => [isConnected];
}

class NotificationRealtimeReceivedEvent extends NotificationEvent {
  final AppNotification notification;

  const NotificationRealtimeReceivedEvent(this.notification);

  @override
  List<Object?> get props => [notification];
}
