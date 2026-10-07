import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/common/services/push_notification_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';

class NotificationRepository {
  final Logger _log = Logger();

  /// ValueNotifier tracking the current unread notification count across the app.
  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  StreamSubscription<AppNotification>? _socketNotificationSub;

  int get unreadCount => unreadCountNotifier.value;

  Future<void> initialize() async {
    _log.d('NotificationRepository::initialize::Initialized');
    _initSocketListener();
  }

  void _initSocketListener() {
    if (!ServicesLocator.isCustomerSocketServiceRegistered) return;
    _socketNotificationSub?.cancel();
    _socketNotificationSub =
        ServicesLocator.customerSocketService.onNotification.listen((notif) {
      if (!notif.isRead) {
        unreadCountNotifier.value += 1;
        _log.d('NotificationRepository::Socket notification received #${notif.id} — unread incremented to ${unreadCountNotifier.value}');
      }
    });
  }

  // ── Real-Time Socket.IO Integration ──

  /// Connects to Socket.IO real-time notification service for the customer.
  Future<void> connectRealtimeNotifications({
    String? token,
    String? serverUrl,
  }) async {
    if (!ServicesLocator.isCustomerSocketServiceRegistered) return;
    await ServicesLocator.customerSocketService.connect(
      token: token,
      serverUrl: serverUrl,
    );
  }

  /// Disconnects from Socket.IO real-time notification service.
  void disconnectRealtimeNotifications() {
    if (!ServicesLocator.isCustomerSocketServiceRegistered) return;
    ServicesLocator.customerSocketService.disconnect();
  }

  /// Stream of incoming real-time notifications.
  Stream<AppNotification> get realtimeNotificationStream {
    if (!ServicesLocator.isCustomerSocketServiceRegistered) {
      return const Stream.empty();
    }
    return ServicesLocator.customerSocketService.onNotification;
  }

  /// Stream of Socket.IO connection status (true = connected, false = disconnected).
  Stream<bool> get realtimeConnectionStatusStream {
    if (!ServicesLocator.isCustomerSocketServiceRegistered) {
      return const Stream.empty();
    }
    return ServicesLocator.customerSocketService.onConnectionStatus;
  }

  /// Whether Socket.IO is currently connected.
  bool get isRealtimeConnected {
    if (!ServicesLocator.isCustomerSocketServiceRegistered) return false;
    return ServicesLocator.customerSocketService.isConnected;
  }

  /// GET /api/notifications
  ///
  /// Fetches the authenticated user's notifications and updates unread count.
  /// Requires Bearer accessToken (handled automatically by ApiRepository).
  Future<List<AppNotification>> getNotifications() async {
    try {
      _log.d('NotificationRepository::getNotifications::Fetching notifications from /api/notifications');
      final response = await ServicesLocator.apiRepository.get('/api/notifications');

      if (response == null || response['success'] == false) {
        _log.w('NotificationRepository::getNotifications::API returned unsuccessful response');
        return [];
      }

      final dynamic data = response['data'];
      final List<AppNotification> notifications = [];

      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            notifications.add(AppNotification.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      } else if (data is Map<String, dynamic> && data['notifications'] is List) {
        for (final item in data['notifications']) {
          if (item is Map) {
            notifications.add(AppNotification.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }

      final unread = notifications.where((n) => !n.isRead).length;
      unreadCountNotifier.value = unread;

      _log.d('NotificationRepository::getNotifications::Retrieved ${notifications.length} notifications ($unread unread)');
      return notifications;
    } catch (error) {
      _log.e('NotificationRepository::getNotifications::Error fetching notifications: $error');
      return [];
    }
  }

  /// Refreshes the unread count by calling getNotifications
  Future<int> refreshUnreadCount() async {
    try {
      final list = await getNotifications();
      return list.where((n) => !n.isRead).length;
    } catch (error) {
      _log.e('NotificationRepository::refreshUnreadCount::Error: $error');
      return unreadCountNotifier.value;
    }
  }

  /// PUT /api/notifications/:id/read
  ///
  /// Marks a specific notification as read.
  /// Requires Bearer accessToken (handled automatically by ApiRepository).
  Future<bool> markAsRead(int id) async {
    try {
      _log.d('NotificationRepository::markAsRead::Marking notification $id as read');
      final success = await ServicesLocator.apiRepository.put('/api/notifications/$id/read', {});

      if (success) {
        _log.d('NotificationRepository::markAsRead::Successfully marked notification $id as read');
        if (unreadCountNotifier.value > 0) {
          unreadCountNotifier.value -= 1;
        }
        return true;
      }

      _log.w('NotificationRepository::markAsRead::Failed to mark notification $id as read');
      return false;
    } catch (error) {
      _log.e('NotificationRepository::markAsRead::Error marking notification $id as read: $error');
      return false;
    }
  }

  /// PUT /api/notifications/read-all
  ///
  /// Marks all notifications as read.
  /// Requires Bearer accessToken (handled automatically by ApiRepository).
  Future<bool> markAllAsRead() async {
    try {
      _log.d('NotificationRepository::markAllAsRead::Marking all notifications as read');
      final success = await ServicesLocator.apiRepository.put('/api/notifications/read-all', {});

      if (success) {
        _log.d('NotificationRepository::markAllAsRead::Successfully marked all as read');
        unreadCountNotifier.value = 0;
        return true;
      }

      _log.w('NotificationRepository::markAllAsRead::Failed to mark all as read');
      return false;
    } catch (error) {
      _log.e('NotificationRepository::markAllAsRead::Error: $error');
      return false;
    }
  }

  /// DELETE /api/notifications/:id
  ///
  /// Deletes a specific notification.
  Future<bool> deleteNotification(int id) async {
    try {
      _log.d('NotificationRepository::deleteNotification::Deleting notification $id');
      final success = await ServicesLocator.apiRepository.delete('/api/notifications/$id');

      if (success) {
        _log.d('NotificationRepository::deleteNotification::Successfully deleted notification $id');
        return true;
      }

      _log.w('NotificationRepository::deleteNotification::Failed to delete notification $id');
      return false;
    } catch (error) {
      _log.e('NotificationRepository::deleteNotification::Error: $error');
      return false;
    }
  }

  /// POST /api/notifications/device-token
  ///
  /// Registers device push token for push notifications.
  Future<bool> registerDeviceToken({
    required String deviceId,
    required String pushToken,
    String? platform,
  }) async {
    final resolvedPlatform = platform ?? PushNotificationService.currentPlatform;
    try {
      _log.i('[FCM] Firebase Project: ${PushNotificationService.firebaseProjectId}');
      _log.i('[FCM] Device ID: ${PushNotificationService.maskDeviceId(deviceId)}');
      _log.i('[FCM] FCM Token: ${PushNotificationService.maskToken(pushToken)}');
      _log.i('[FCM] Platform: $resolvedPlatform');
      _log.i('[FCM] Registering device token...');

      final response = await ServicesLocator.apiRepository.post(
        '/api/notifications/device-token',
        {
          'deviceId': deviceId,
          'pushToken': pushToken,
          'platform': resolvedPlatform,
        },
      );

      final success = response != null && response['success'] == true;
      if (success) {
        _log.i('[FCM] Device token registration successful');
        await ServicesLocator.sessionService.savePushToken(pushToken);
      } else {
        final statusCode = response?['statusCode'] ?? response?['code'] ?? 400;
        final message = response?['message'] ?? 'Unknown error';
        _log.e('[FCM] Device token registration failed: Status $statusCode - $message');
      }
      return success;
    } catch (error) {
      _log.e('[FCM] Device token registration failed with error: $error');
      return false;
    }
  }

  void dispose() {
    _socketNotificationSub?.cancel();
  }
}

