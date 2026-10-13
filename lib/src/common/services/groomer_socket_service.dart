import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/services/push_notification_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Dedicated Socket.IO service for real-time Groomer notifications.
///
/// Lifecycle:
/// - Connects after successful Groomer authentication.
/// - Passes Bearer token in auth / headers / query.
/// - Listens for backend real-time notification events.
/// - Disconnects on Groomer logout.
class GroomerSocketService {
  final Logger _log = Logger();

  io.Socket? _socket;
  final StreamController<AppNotification> _notificationController =
      StreamController<AppNotification>.broadcast();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  final Set<String> _joinedRooms = <String>{};
  final Map<int, DateTime> _recentNotificationIds = <int, DateTime>{};

  /// Stream of real-time parsed notifications.
  Stream<AppNotification> get onNotification => _notificationController.stream;

  /// Stream of socket connection state changes (true = connected, false = disconnected).
  Stream<bool> get onConnectionStatus => _connectionStatusController.stream;

  /// Current connection status.
  bool get isConnected => _socket?.connected ?? false;

  /// Primary backend event name for real-time notifications.
  /// (Configurable to allow backend updates without breaking changes)
  static const String defaultNotificationEvent = 'notification';

  /// Additional backend event names supported for compatibility.
  static const List<String> supportedEvents = [
    defaultNotificationEvent,
    'new_notification',
    'groomer_notification',
    'admin_notification',
    'staff_notification',
    'booking_notification',
    'new_booking',
    'booking_created',
    'booking_requested',
    'booking_assigned',
    'booking_confirmed',
    'booking_accepted',
    'booking_rejected',
    'booking_cancelled',
    'booking_auto_cancelled',
    'appointment_created',
    'appointment_updated',
    'appointment_cancelled',
    'booking_timeout',
    'appointment_timeout',
    'booking_in_progress',
    'booking_started',
    'booking_completed',
    'appointment_started',
    'appointment_completed',
    'appointment_confirmed',
    'booking_status_updated',
    'booking_updated',
    'booking_status_change',
    'booking_status',
    'booking_update',
    'cancellation_requested',
    'cancellation_approved',
    'cancellation_rejected',
    'customer_updated',
    'customer_created',
    'customer_registered',
    'user_registered',
    'user_updated',
    'pet_updated',
    'pet_created',
  ];

  Future<void> initialize() async {
    _log.d('GroomerSocketService::initialize::Initialized');
    try {
      final token = await ServicesLocator.sessionService.getGroomerAccessToken();
      if (token != null && token.isNotEmpty) {
        _log.d('GroomerSocketService::initialize::Auto-connecting with existing Groomer token');
        await connect(token: token);
      }
    } catch (e) {
      _log.e('GroomerSocketService::initialize::Auto-connect error: $e');
    }
  }

  /// Ensures that the Groomer Socket.IO connection is established.
  Future<void> ensureConnected() async {
    if (isConnected) {
      return;
    }
    try {
      final token = await ServicesLocator.sessionService.getGroomerAccessToken();
      if (token != null && token.isNotEmpty) {
        await connect(token: token);
      }
    } catch (e) {
      _log.e('GroomerSocketService::ensureConnected::Error: $e');
    }
  }

  /// Connects to Socket.IO using the authenticated Groomer session token.
  ///
  /// Safe against duplicate connections and duplicate event listener registration.
  Future<void> connect({
    String? token,
    String? serverUrl,
    List<String>? customEvents,
  }) async {
    final authToken =
        token ?? await ServicesLocator.sessionService.getGroomerAccessToken();

    if (authToken == null || authToken.isEmpty) {
      _log.w('GroomerSocketService::connect::No valid Groomer token found. Skipping connection.');
      return;
    }

    if (_socket != null && _socket!.connected) {
      _log.d('GroomerSocketService::connect::Socket already connected.');
      return;
    }

    // Clean up any lingering socket before creating a new one
    _cleanSocket();

    final url = serverUrl ?? Constants.app.BASE_URL;
    final maskedToken = authToken.length > 8
        ? '${authToken.substring(0, 4)}...${authToken.substring(authToken.length - 4)}'
        : '***';
    _log.d('GroomerSocketService::connect::Socket connecting to $url (token: $maskedToken)');

    try {
      final rawToken = authToken.startsWith('Bearer ')
          ? authToken.substring(7)
          : authToken;
      final bearerToken = authToken.startsWith('Bearer ')
          ? authToken
          : 'Bearer $authToken';

      final options = io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(15)
          .setReconnectionDelay(1500)
          .setReconnectionDelayMax(10000)
          .setAuth({
            'token': rawToken,
            'accessToken': rawToken,
            'authorization': bearerToken,
            'Authorization': bearerToken,
          })
          .setExtraHeaders({
            'Authorization': bearerToken,
            'authorization': bearerToken,
            'token': rawToken,
          })
          .setQuery({
            'token': rawToken,
            'accessToken': rawToken,
            'authorization': bearerToken,
          })
          .build();

      _socket = io.io(url, options);

      _socket!.onConnect((_) {
        _log.i('GroomerSocketService::onConnect::Socket connected successfully to $url (Socket ID: ${_socket?.id})');
        _connectionStatusController.add(true);
        _autoJoinGroomerRooms();
        for (final roomId in _joinedRooms) {
          _emitJoinRoom(roomId);
        }
      });

      _socket!.onDisconnect((reason) {
        _log.w('GroomerSocketService::onDisconnect::Socket disconnected: $reason');
        _connectionStatusController.add(false);
      });

      _socket!.onConnectError((err) {
        _log.e('GroomerSocketService::onConnectError::Socket connection error: $err');
      });

      _socket!.onError((err) {
        _log.e('GroomerSocketService::onError::Socket error: $err');
      });

      _socket!.onReconnectAttempt((attempt) {
        _log.d('GroomerSocketService::onReconnectAttempt::Socket reconnecting attempt #$attempt');
      });

      _socket!.onReconnect((attempt) {
        _log.i('GroomerSocketService::onReconnect::Socket connected (reconnected attempt #$attempt)');
        _connectionStatusController.add(true);
        _autoJoinGroomerRooms();
        for (final roomId in _joinedRooms) {
          _emitJoinRoom(roomId);
        }
      });

      _socket!.onReconnectError((err) {
        _log.e('GroomerSocketService::onReconnectError::Socket reconnection error: $err');
      });

      final eventsToListen = customEvents ?? supportedEvents;
      for (final eventName in eventsToListen) {
        _socket!.on(eventName, (data) {
          _log.d('GroomerSocketService::Socket event received "$eventName": $data');
          _handleRawEventData(eventName, data);
        });
      }

      _socket!.onAny((eventName, data) {
        const reserved = {
          'connect',
          'disconnect',
          'connect_error',
          'connect_timeout',
          'error',
          'reconnect',
          'reconnect_attempt',
          'reconnecting',
          'reconnect_error',
          'reconnect_failed',
          'ping',
          'pong',
        };
        final lower = eventName.toString().toLowerCase();
        final isChatOnly = lower.contains('chat') ||
            lower == 'message' ||
            lower == 'new_message' ||
            lower == 'send_message';
        if (!reserved.contains(eventName) &&
            !eventsToListen.contains(eventName) &&
            !isChatOnly) {
          _log.i('GroomerSocketService::Received onAny event "$eventName": $data');
          _handleRawEventData(eventName.toString(), data);
        }
      });

      _socket!.connect();
    } catch (e) {
      _log.e('GroomerSocketService::connect::Error establishing socket: $e');
    }
  }

  /// Joins groomer, staff, store, and admin rooms for the current authenticated groomer/admin.
  void joinGroomerRooms([Map<String, dynamic>? groomerProfile]) {
    try {
      if (!ServicesLocator.isRegistered<SessionService>()) return;
      final session = ServicesLocator.sessionService;
      final data = groomerProfile ?? session.getGroomerData();
      final uid = (data?['id'] ?? data?['groomerId'] ?? data?['userId'] ?? session.currentUserId)?.toString().trim();
      final groomerCode = (data?['groomerCode'] ?? data?['code'])?.toString().trim();
      final storeId = (data?['storeId'] ?? data?['store_id'] ?? (data?['store'] is Map ? data!['store']['id'] : null))?.toString().trim();
      final role = (data?['role'] ?? session.userRole ?? 'groomer').toString().toLowerCase().trim();
      final isAdmin = role == 'admin' || data?['isAdmin'] == true;

      if (uid != null && uid.isNotEmpty) {
        _joinRoom('groomer_$uid');
        _joinRoom('user_$uid');
        _joinRoom('staff_$uid');
        _joinRoom(uid);
      }
      if (groomerCode != null && groomerCode.isNotEmpty) {
        _joinRoom('groomer_$groomerCode');
      }
      if (storeId != null && storeId.isNotEmpty) {
        _joinRoom('store_$storeId');
      }
      _joinRoom('groomers');
      _joinRoom('staff');
      if (isAdmin) {
        _joinRoom('admin');
        _joinRoom('admins');
      }
    } catch (e) {
      _log.e('GroomerSocketService::joinGroomerRooms::Error: $e');
    }
  }

  void _autoJoinGroomerRooms() {
    joinGroomerRooms();
  }

  void _joinRoom(String roomId) {
    final clean = roomId.trim();
    if (clean.isEmpty) return;
    _joinedRooms.add(clean);
    if (_socket != null && _socket!.connected) {
      _emitJoinRoom(clean);
    }
  }

  void _emitJoinRoom(String roomId) {
    String? uid;
    String role = 'groomer';
    if (ServicesLocator.isRegistered<SessionService>()) {
      final session = ServicesLocator.sessionService;
      final data = session.getGroomerData();
      uid = (data?['id'] ?? data?['groomerId'] ?? session.currentUserId)?.toString();
      role = (data?['role'] ?? session.userRole ?? 'groomer').toString();
    }
    final payload = <String, dynamic>{
      'roomId': roomId,
      'conversationId': roomId,
      if (uid != null && uid.isNotEmpty) 'groomerId': uid,
      if (uid != null && uid.isNotEmpty) 'userId': uid,
      'userType': role,
      'role': role,
    };
    _socket?.emit('join_room', payload);
    _socket?.emit('join_groomer', payload);
    _socket?.emit('joinGroomer', payload);
    _socket?.emit('join', roomId);
    if (uid != null && uid.isNotEmpty) {
      _socket?.emit('join_user', {'userId': uid, 'groomerId': uid, 'userType': role});
      _socket?.emit('joinUser', {'userId': uid, 'groomerId': uid, 'userType': role});
    }
  }

  /// Parses raw Socket.IO incoming event data into an [AppNotification] and emits it.
  void _handleRawEventData(String eventName, dynamic rawData) {
    try {
      Map<String, dynamic> payload;

      if (rawData is Map<String, dynamic>) {
        payload = Map<String, dynamic>.from(rawData);
      } else if (rawData is Map) {
        payload = Map<String, dynamic>.from(rawData);
      } else if (rawData is String) {
        final decoded = jsonDecode(rawData);
        if (decoded is Map) {
          payload = Map<String, dynamic>.from(decoded);
        } else {
          payload = {'message': decoded.toString()};
        }
      } else {
        payload = {'message': rawData?.toString() ?? ''};
      }

      // Safely unwrap 'notification' or 'data' envelopes without losing top-level fields or nested metadata
      if (payload.containsKey('notification') && payload['notification'] is Map) {
        final innerNotification = Map<String, dynamic>.from(payload['notification'] as Map);
        payload.forEach((k, v) {
          if (!innerNotification.containsKey(k) && k != 'notification') {
            innerNotification[k] = v;
          }
        });
        payload = innerNotification;
      } else if (payload.containsKey('data') && payload['data'] is Map) {
        final innerData = Map<String, dynamic>.from(payload['data'] as Map);
        final topHasTitleOrMessage =
            (payload['title'] != null && payload['title'].toString().trim().isNotEmpty) ||
            (payload['message'] != null && payload['message'].toString().trim().isNotEmpty);
        if (!topHasTitleOrMessage) {
          payload.forEach((k, v) {
            if (!innerData.containsKey(k) && k != 'data') {
              innerData[k] = v;
            }
          });
          payload = innerData;
        } else {
          // Top level already has title/message; copy useful metadata keys from data if missing at top level
          innerData.forEach((k, v) {
            if (!payload.containsKey(k)) {
              payload[k] = v;
            }
          });
        }
      }

      // Recipient validation: ignore customer-only notifications or notifications intended for another groomer (unless admin)
      final targetRole = (payload['targetRole'] ?? payload['recipientRole'] ?? payload['role'] ?? '')
          .toString()
          .toLowerCase();
      if (targetRole == 'customer') {
        _log.d('GroomerSocketService::_handleRawEventData::Ignoring customer-only notification.');
        return;
      }

      if (ServicesLocator.isRegistered<SessionService>()) {
        final session = ServicesLocator.sessionService;
        if (session.isGroomerLoggedIn) {
          final groomerData = session.getGroomerData();
          final roleLower = (groomerData?['role'] ?? session.userRole ?? 'groomer')
              .toString()
              .toLowerCase();
          final isAdmin = roleLower == 'admin' || groomerData?['isAdmin'] == true;

          if (!isAdmin) {
            final currentGroomerId = (groomerData?['id'] ??
                    groomerData?['groomerId'] ??
                    session.currentUserId)
                ?.toString()
                .trim();
            final currentGroomerCode =
                (groomerData?['groomerCode'] ?? groomerData?['code'])
                    ?.toString()
                    .trim();
            final targetGroomerId = (payload['groomerId'] ??
                    payload['groomer_id'] ??
                    (payload['groomer'] is Map ? payload['groomer']['id'] : null))
                ?.toString()
                .trim();

            if (targetGroomerId != null &&
                targetGroomerId.isNotEmpty &&
                currentGroomerId != null &&
                currentGroomerId.isNotEmpty &&
                targetGroomerId != currentGroomerId &&
                (currentGroomerCode == null || targetGroomerId != currentGroomerCode)) {
              _log.d('GroomerSocketService::_handleRawEventData::Ignoring notification for different groomer ($targetGroomerId != $currentGroomerId).');
              return;
            }
          }
        }
      }

      // If id is missing, assign a unique timestamp-based fallback id
      if (!payload.containsKey('id') && !payload.containsKey('notificationId')) {
        payload['id'] = DateTime.now().millisecondsSinceEpoch;
      }

      final eventLower = eventName.toLowerCase();
      final typeLower = payload['type']?.toString().toLowerCase() ?? '';
      final statusLower = payload['status']?.toString().toLowerCase() ?? '';

      // Default type based on event name if not set
      if (!payload.containsKey('type') || payload['type'] == null || payload['type'].toString().trim().isEmpty) {
        if (eventLower.contains('cancellation')) {
          payload['type'] = 'cancellation_requested';
        } else if (eventLower.contains('new_booking') || eventLower.contains('booking_created') || eventLower.contains('booking_requested')) {
          payload['type'] = 'new_booking';
        } else if (eventLower.contains('booking') || eventLower.contains('appointment')) {
          payload['type'] = 'booking';
        } else if (eventLower.contains('admin')) {
          payload['type'] = 'admin';
        } else {
          payload['type'] = 'general';
        }
      }

      // Synthesize title if missing
      final existingTitle = payload['title'] ?? payload['subject'] ?? payload['heading'];
      if (existingTitle == null || existingTitle.toString().trim().isEmpty) {
        if (eventLower.contains('new_booking') ||
            eventLower.contains('booking_created') ||
            eventLower.contains('booking_requested') ||
            typeLower.contains('new_booking')) {
          payload['title'] = 'New Booking Request';
        } else if (eventLower.contains('cancellation_requested') || typeLower == 'cancellation_requested') {
          payload['title'] = 'Cancellation Requested';
        } else if (eventLower.contains('cancel') || typeLower.contains('cancel') || statusLower == 'cancelled') {
          payload['title'] = 'Booking Cancelled';
        } else if (eventLower.contains('confirm') || eventLower.contains('accept') || statusLower == 'confirmed') {
          payload['title'] = 'Booking Confirmed';
        } else if (eventLower.contains('reject') || statusLower == 'rejected') {
          payload['title'] = 'Booking Rejected';
        } else if (eventLower.contains('start') || eventLower.contains('progress') || statusLower == 'in_progress') {
          payload['title'] = 'Appointment In Progress';
        } else if (eventLower.contains('complet') || statusLower == 'completed') {
          payload['title'] = 'Appointment Completed';
        } else {
          payload['title'] = 'Groomer Notification';
        }
      }

      // Synthesize message if missing
      final existingBody = payload['message'] ?? payload['body'] ?? payload['description'] ?? payload['text'];
      if (existingBody == null || existingBody.toString().trim().isEmpty) {
        final bookingId = payload['bookingId'] ??
            payload['booking_id'] ??
            payload['appointmentId'] ??
            payload['entityId'];
        final petName = payload['petName'] ??
            payload['pet_name'] ??
            (payload['pet'] is Map ? payload['pet']['name'] : null);
        final customerName = payload['customerName'] ??
            payload['customer_name'] ??
            (payload['customer'] is Map ? payload['customer']['name'] : null);

        if (eventLower.contains('new_booking') ||
            eventLower.contains('booking_created') ||
            eventLower.contains('booking_requested')) {
          final who = petName != null
              ? 'for $petName'
              : (customerName != null ? 'from $customerName' : '');
          payload['message'] = bookingId != null
              ? 'New booking request #$bookingId ${who.isNotEmpty ? "$who " : ""}is awaiting review.'
              : 'A new booking request ${who.isNotEmpty ? "$who " : ""}has been received.';
        } else if (eventLower.contains('cancel') || statusLower == 'cancelled') {
          payload['message'] = bookingId != null
              ? 'Booking #$bookingId has been cancelled.'
              : 'A booking has been cancelled.';
        } else {
          payload['message'] = bookingId != null
              ? 'Booking #$bookingId has been updated.'
              : 'You have a new booking update.';
        }
      }

      final notification = AppNotification.fromJson(payload);
      if (_isDuplicateNotification(notification.id)) {
        _log.d('GroomerSocketService::_handleRawEventData::Suppressed duplicate notification #${notification.id}');
        return;
      }

      if (ServicesLocator.isRegistered<SessionService>()) {
        final session = ServicesLocator.sessionService;
        if (session.isGroomerLoggedIn) {
          unawaited(session.saveGroomerPortalNotification(notification.toJson()));
        }
      }

      if (ServicesLocator.isRegistered<PushNotificationService>()) {
        unawaited(
          ServicesLocator.pushNotificationService.showLocalNotification(
            id: notification.id,
            title: notification.title,
            body: notification.message,
            payload: jsonEncode(notification.toJson()),
          ),
        );
      }

      _log.i('GroomerSocketService::_handleRawEventData::Socket notification parsed #${notification.id}: "${notification.title}"');
      _notificationController.add(notification);
    } catch (e) {
      _log.e('GroomerSocketService::_handleRawEventData::Error parsing event payload: $e');
    }
  }

  bool _isDuplicateNotification(int id) {
    if (id <= 0) return false;
    final now = DateTime.now();
    _recentNotificationIds.removeWhere((_, ts) => now.difference(ts).inSeconds > 5);
    final prev = _recentNotificationIds[id];
    if (prev != null && now.difference(prev).inSeconds <= 3) {
      return true;
    }
    _recentNotificationIds[id] = now;
    return false;
  }

  /// Disconnects the socket and resets connection state.
  void disconnect() {
    _log.d('GroomerSocketService::disconnect::Disconnecting socket');
    _cleanSocket();
    _joinedRooms.clear();
    _recentNotificationIds.clear();
    _connectionStatusController.add(false);
  }

  void _cleanSocket() {
    if (_socket != null) {
      _socket!.offAny();
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
  }

  /// Disposes streams on application shutdown.
  void dispose() {
    disconnect();
    _notificationController.close();
    _connectionStatusController.close();
  }

  /// Dispatches a notification directly into the groomer notification stream.
  void handleDirectNotification(AppNotification notification) {
    if (_isDuplicateNotification(notification.id)) {
      return;
    }
    if (ServicesLocator.isRegistered<SessionService>()) {
      final session = ServicesLocator.sessionService;
      if (session.isGroomerLoggedIn) {
        unawaited(session.saveGroomerPortalNotification(notification.toJson()));
      }
    }
    if (!_notificationController.isClosed) {
      _notificationController.add(notification);
    }
  }

  /// Helper for testing to inject mock event payloads directly into the stream.
  @visibleForTesting
  void emitNotificationForTesting(AppNotification notification) {
    _notificationController.add(notification);
  }

  /// Helper for testing to inject raw events directly.
  @visibleForTesting
  void handleRawEventForTesting(String event, dynamic data) {
    _handleRawEventData(event, data);
  }
}
