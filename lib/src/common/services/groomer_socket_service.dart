import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
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
    'booking_notification',
    'booking_confirmed',
    'booking_in_progress',
    'booking_started',
    'booking_completed',
    'appointment_started',
    'appointment_completed',
    'appointment_confirmed',
    'booking_status_updated',
    'booking_updated',
    'booking_status_change',
    'cancellation_requested',
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
      final options = io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(10000)
          .setAuth({'token': authToken})
          .setExtraHeaders({'Authorization': 'Bearer $authToken'})
          .setQuery({'token': authToken})
          .build();

      _socket = io.io(url, options);

      _socket!.onConnect((_) {
        _log.i('GroomerSocketService::onConnect::Socket connected successfully to $url (Socket ID: ${_socket?.id})');
        _connectionStatusController.add(true);
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
    } catch (e) {
      _log.e('GroomerSocketService::connect::Error establishing socket: $e');
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

      // If wrapped in a 'data' or 'notification' object, extract root
      if (payload.containsKey('data') && payload['data'] is Map) {
        final innerData = Map<String, dynamic>.from(payload['data'] as Map);
        // Copy top level fields if missing in inner data
        payload.forEach((k, v) {
          if (!innerData.containsKey(k)) innerData[k] = v;
        });
        payload = innerData;
      } else if (payload.containsKey('notification') && payload['notification'] is Map) {
        final innerNotification = Map<String, dynamic>.from(payload['notification'] as Map);
        payload.forEach((k, v) {
          if (!innerNotification.containsKey(k)) innerNotification[k] = v;
        });
        payload = innerNotification;
      }

      // If id is missing, assign a unique timestamp-based fallback id
      if (!payload.containsKey('id') && !payload.containsKey('notificationId')) {
        payload['id'] = DateTime.now().millisecondsSinceEpoch;
      }

      // Default type based on event name if not set
      if (!payload.containsKey('type') || payload['type'] == null) {
        if (eventName.contains('booking')) {
          payload['type'] = 'booking';
        } else if (eventName.contains('cancellation')) {
          payload['type'] = 'cancellation_requested';
        } else {
          payload['type'] = 'general';
        }
      }

      final notification = AppNotification.fromJson(payload);
      _log.i('GroomerSocketService::_handleRawEventData::Socket notification parsed #${notification.id}: "${notification.title}"');
      _notificationController.add(notification);
    } catch (e) {
      _log.e('GroomerSocketService::_handleRawEventData::Error parsing event payload: $e');
    }
  }

  /// Disconnects the socket and resets connection state.
  void disconnect() {
    _log.d('GroomerSocketService::disconnect::Disconnecting socket');
    _cleanSocket();
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
