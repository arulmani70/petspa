import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/common/services/push_notification_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';

class NotificationRepository {
  final Logger _log = Logger();

  /// ValueNotifier tracking the current unread notification count across the app.
  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  StreamSubscription<AppNotification>? _socketNotificationSub;
  final List<AppNotification> _realtimeNotifications = <AppNotification>[];
  final Set<int> _seenUnreadIds = <int>{};

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
      final existingIdx = _realtimeNotifications.indexWhere((n) => n.id == notif.id);
      if (existingIdx >= 0) {
        _realtimeNotifications[existingIdx] = notif;
      } else {
        _realtimeNotifications.insert(0, notif);
      }
      if (!notif.isRead && _seenUnreadIds.add(notif.id)) {
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
      if (ServicesLocator.isPushNotificationServiceRegistered) {
        await ServicesLocator.pushNotificationService.ingestPendingBackgroundNotifications();
      }

      _log.d('NotificationRepository::getNotifications::Fetching notifications from /api/notifications');
      final response = await ServicesLocator.apiRepository.get('/api/notifications');

      final List<AppNotification> apiNotifications = [];

      if (response != null && response['success'] != false) {
        final dynamic data = response['data'] ?? response['notifications'];
        List<dynamic>? rawList;
        if (data is List) {
          rawList = data;
        } else if (data is Map) {
          if (data['notifications'] is List) {
            rawList = data['notifications'] as List;
          } else if (data['items'] is List) {
            rawList = data['items'] as List;
          } else if (data['rows'] is List) {
            rawList = data['rows'] as List;
          } else if (data['data'] is List) {
            rawList = data['data'] as List;
          }
        }
        if (rawList != null) {
          for (final item in rawList) {
            if (item is Map) {
              apiNotifications.add(
                AppNotification.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          }
        }
      } else {
        _log.w('NotificationRepository::getNotifications::API returned unsuccessful response');
      }

      // Merge real-time in-memory notifications and persisted portal notifications (when logged in)
      final List<AppNotification> persistedNotifications = [];
      if (ServicesLocator.isRegistered<SessionService>() &&
          ServicesLocator.sessionService.isLoggedIn) {
        final savedMaps = ServicesLocator.sessionService.getCustomerPortalNotifications();
        for (final map in savedMaps) {
          persistedNotifications.add(AppNotification.fromJson(map));
        }
      }

      final merged = _mergeNotifications(
        apiList: apiNotifications,
        realtimeList: _realtimeNotifications,
        persistedList: persistedNotifications,
      );

      _seenUnreadIds
        ..clear()
        ..addAll(merged.where((n) => !n.isRead).map((n) => n.id));
      final unread = merged.where((n) => !n.isRead).length;
      unreadCountNotifier.value = unread;

      _log.d('NotificationRepository::getNotifications::Retrieved ${merged.length} notifications ($unread unread)');
      return merged;
    } catch (error) {
      _log.e('NotificationRepository::getNotifications::Error fetching notifications: $error');
      return List<AppNotification>.from(_realtimeNotifications);
    }
  }

  List<AppNotification> _mergeNotifications({
    required List<AppNotification> apiList,
    required List<AppNotification> realtimeList,
    required List<AppNotification> persistedList,
  }) {
    final Map<int, AppNotification> byId = <int, AppNotification>{};
    final List<AppNotification> ordered = <AppNotification>[];

    void upsert(AppNotification item, {bool preferExistingRead = true}) {
      if (byId.containsKey(item.id)) {
        final existing = byId[item.id]!;
        final resolvedRead = preferExistingRead
            ? (existing.isRead || item.isRead)
            : item.isRead;
        final updated = existing.copyWith(isRead: resolvedRead);
        byId[item.id] = updated;
        final idx = ordered.indexWhere((e) => e.id == item.id);
        if (idx >= 0) ordered[idx] = updated;
        return;
      }

      // Avoid duplicating local synthetic notification when API already returned the same bookingId + type
      final itemBookingId = item.metadata?['bookingId'] ?? item.metadata?['booking_id'];
      if (itemBookingId != null) {
        final duplicateIdx = ordered.indexWhere((existing) {
          final existingBookingId =
              existing.metadata?['bookingId'] ?? existing.metadata?['booking_id'];
          return existingBookingId != null &&
              existingBookingId.toString() == itemBookingId.toString() &&
              existing.type.toLowerCase() == item.type.toLowerCase() &&
              existing.title.toLowerCase() == item.title.toLowerCase();
        });
        if (duplicateIdx >= 0) {
          return;
        }
      }

      byId[item.id] = item;
      ordered.add(item);
    }

    for (final n in realtimeList) {
      upsert(n);
    }
    for (final n in apiList) {
      upsert(n);
    }
    for (final n in persistedList) {
      upsert(n);
    }

    ordered.sort((a, b) {
      if (a.createdAt != null && b.createdAt != null) {
        return b.createdAt!.compareTo(a.createdAt!);
      }
      return 0;
    });

    return ordered;
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
      bool updatedLocal = false;
      final rtIdx = _realtimeNotifications.indexWhere((n) => n.id == id);
      if (rtIdx >= 0) {
        _realtimeNotifications[rtIdx] = _realtimeNotifications[rtIdx].copyWith(isRead: true);
        updatedLocal = true;
      }
      _seenUnreadIds.remove(id);
      if (ServicesLocator.isRegistered<SessionService>() &&
          ServicesLocator.sessionService.isLoggedIn) {
        await ServicesLocator.sessionService.markPortalNotificationRead(
          id,
          isGroomer: false,
        );
      }

      final success = await ServicesLocator.apiRepository.put('/api/notifications/$id/read', {});

      if (success || updatedLocal) {
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
      for (int i = 0; i < _realtimeNotifications.length; i++) {
        _realtimeNotifications[i] = _realtimeNotifications[i].copyWith(isRead: true);
      }
      _seenUnreadIds.clear();
      if (ServicesLocator.isRegistered<SessionService>() &&
          ServicesLocator.sessionService.isLoggedIn) {
        await ServicesLocator.sessionService.markAllPortalNotificationsRead(
          isGroomer: false,
        );
      }

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
      _realtimeNotifications.removeWhere((n) => n.id == id);
      _seenUnreadIds.remove(id);
      if (ServicesLocator.isRegistered<SessionService>() &&
          ServicesLocator.sessionService.isLoggedIn) {
        await ServicesLocator.sessionService.deletePortalNotification(
          id,
          isGroomer: false,
        );
      }

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

