import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/notifications/repo/notification_repository.dart';

part 'notification_event.dart';
part 'notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  NotificationBloc({required NotificationRepository repository})
      : _repository = repository,
        super(NotificationState.initial) {
    on<InitializeNotifications>(_onInitializeNotifications);
    on<FetchNotifications>(_onFetchNotifications);
    on<MarkNotificationRead>(_onMarkNotificationRead);
    on<MarkAllNotificationsRead>(_onMarkAllNotificationsRead);
    on<DeleteNotificationEvent>(_onDeleteNotification);
    on<RegisterPushTokenEvent>(_onRegisterPushToken);
    on<NotificationConnectSocketEvent>(_onConnectSocket);
    on<NotificationSocketConnectionChangedEvent>(_onSocketConnectionChanged);
    on<NotificationRealtimeReceivedEvent>(_onRealtimeReceived);

    _initSocketSubscriptions();
  }

  final NotificationRepository _repository;
  final _log = Logger();

  StreamSubscription<AppNotification>? _realtimeSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  void _initSocketSubscriptions() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = _repository.realtimeNotificationStream.listen(
      (notification) {
        add(NotificationRealtimeReceivedEvent(notification));
      },
      onError: (err) {
        _log.e('NotificationBloc::realtimeNotificationStream error: $err');
      },
    );

    _connectionSubscription?.cancel();
    _connectionSubscription = _repository.realtimeConnectionStatusStream.listen(
      (isConnected) {
        add(NotificationSocketConnectionChangedEvent(isConnected));
      },
      onError: (err) {
        _log.e('NotificationBloc::realtimeConnectionStatusStream error: $err');
      },
    );
  }

  Future<void> _onConnectSocket(
    NotificationConnectSocketEvent event,
    Emitter<NotificationState> emit,
  ) async {
    _log.d('NotificationBloc::_onConnectSocket::Connecting customer socket');
    await _repository.connectRealtimeNotifications(
      token: event.token,
      serverUrl: event.serverUrl,
    );
  }

  void _onSocketConnectionChanged(
    NotificationSocketConnectionChangedEvent event,
    Emitter<NotificationState> emit,
  ) {
    emit(state.copyWith(isSocketConnected: () => event.isConnected));
  }

  void _onRealtimeReceived(
    NotificationRealtimeReceivedEvent event,
    Emitter<NotificationState> emit,
  ) {
    final newNotif = event.notification;
    _log.d('NotificationBloc::_onRealtimeReceived::Received #${newNotif.id} - ${newNotif.title}');

    final existingList = List<AppNotification>.from(state.notifications);
    final existsIndex = existingList.indexWhere((item) => item.id == newNotif.id);

    if (existsIndex >= 0) {
      _log.d('NotificationBloc::_onRealtimeReceived::Updating existing notification #${newNotif.id}');
      existingList[existsIndex] = newNotif;
    } else {
      _log.d('NotificationBloc::_onRealtimeReceived::Prepending new notification #${newNotif.id}');
      existingList.insert(0, newNotif);
    }

    final unread = existingList.where((n) => !n.isRead).length;

    emit(state.copyWith(
      notifications: () => existingList,
      unreadCount: () => unread,
      message: () => newNotif.title.isNotEmpty ? newNotif.title : 'New notification received',
    ));
  }

  Future<void> _onInitializeNotifications(
    InitializeNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    _log.d('NotificationBloc::_onInitializeNotifications::Initializing notifications');
    try {
      emit(state.copyWith(status: () => NotificationStatus.loading));
      final notifications = await _repository.getNotifications();
      final unread = notifications.where((n) => !n.isRead).length;
      emit(state.copyWith(
        status: () => NotificationStatus.loaded,
        message: () => 'Notifications initialized',
        notifications: () => notifications,
        unreadCount: () => unread,
      ));
    } catch (e) {
      _log.e('NotificationBloc::_onInitializeNotifications::Error: $e');
      emit(state.copyWith(
        status: () => NotificationStatus.failure,
        message: () => e.toString(),
      ));
    }
  }

  Future<void> _onFetchNotifications(
    FetchNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    _log.d('NotificationBloc::_onFetchNotifications::Fetching notifications');
    try {
      emit(state.copyWith(status: () => NotificationStatus.loading));
      final notifications = await _repository.getNotifications();
      final unread = notifications.where((n) => !n.isRead).length;
      emit(state.copyWith(
        status: () => NotificationStatus.loaded,
        message: () => 'Notifications fetched',
        notifications: () => notifications,
        unreadCount: () => unread,
      ));
    } catch (e) {
      _log.e('NotificationBloc::_onFetchNotifications::Error: $e');
      emit(state.copyWith(
        status: () => NotificationStatus.failure,
        message: () => e.toString(),
      ));
    }
  }

  Future<void> _onMarkNotificationRead(
    MarkNotificationRead event,
    Emitter<NotificationState> emit,
  ) async {
    _log.d('NotificationBloc::_onMarkNotificationRead::Marking ${event.notificationId} as read');
    try {
      await _repository.markAsRead(event.notificationId);
      final updated = state.notifications.map((n) {
        if (n.id == event.notificationId) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();
      final unread = updated.where((n) => !n.isRead).length;
      emit(state.copyWith(
        status: () => NotificationStatus.success,
        message: () => 'Notification marked as read',
        notifications: () => updated,
        unreadCount: () => unread,
      ));
    } catch (e) {
      _log.e('NotificationBloc::_onMarkNotificationRead::Error: $e');
      emit(state.copyWith(
        status: () => NotificationStatus.failure,
        message: () => e.toString(),
      ));
    }
  }

  Future<void> _onMarkAllNotificationsRead(
    MarkAllNotificationsRead event,
    Emitter<NotificationState> emit,
  ) async {
    _log.d('NotificationBloc::_onMarkAllNotificationsRead::Marking all notifications as read');
    try {
      await _repository.markAllAsRead();
      final updated = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
      emit(state.copyWith(
        status: () => NotificationStatus.success,
        message: () => 'All notifications marked as read',
        notifications: () => updated,
        unreadCount: () => 0,
      ));
    } catch (e) {
      _log.e('NotificationBloc::_onMarkAllNotificationsRead::Error: $e');
      emit(state.copyWith(
        status: () => NotificationStatus.failure,
        message: () => e.toString(),
      ));
    }
  }

  Future<void> _onDeleteNotification(
    DeleteNotificationEvent event,
    Emitter<NotificationState> emit,
  ) async {
    _log.d('NotificationBloc::_onDeleteNotification::Deleting ${event.notificationId}');
    try {
      await _repository.deleteNotification(event.notificationId);
      final updated = state.notifications.where((n) => n.id != event.notificationId).toList();
      final unread = updated.where((n) => !n.isRead).length;
      emit(state.copyWith(
        status: () => NotificationStatus.success,
        message: () => 'Notification deleted',
        notifications: () => updated,
        unreadCount: () => unread,
      ));
    } catch (e) {
      _log.e('NotificationBloc::_onDeleteNotification::Error: $e');
      emit(state.copyWith(
        status: () => NotificationStatus.failure,
        message: () => e.toString(),
      ));
    }
  }

  Future<void> _onRegisterPushToken(
    RegisterPushTokenEvent event,
    Emitter<NotificationState> emit,
  ) async {
    _log.d('NotificationBloc::_onRegisterPushToken::Registering token');
    try {
      await _repository.registerDeviceToken(
        deviceId: event.deviceId,
        pushToken: event.pushToken,
        platform: event.platform,
      );
    } catch (e) {
      _log.e('NotificationBloc::_onRegisterPushToken::Error: $e');
    }
  }

  @override
  Future<void> close() async {
    await _realtimeSubscription?.cancel();
    await _connectionSubscription?.cancel();
    return super.close();
  }
}

