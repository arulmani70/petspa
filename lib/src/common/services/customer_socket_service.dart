import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/chat/models/chat_message_model.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Dedicated Socket.IO service for real-time Customer notifications and Customer Chat.
///
/// Lifecycle:
/// - Connects after successful Customer authentication (login / verifyOtp) or auto-connects on app start.
/// - Passes Bearer token in auth / headers / query.
/// - Listens for backend real-time notification events (booking confirmations, status changes, etc.).
/// - Listens for backend real-time chat events (customer-groomer / assistant messages).
/// - Manages room / conversation joining and leaving.
/// - Disconnects and cleans listeners on Customer logout.
class CustomerSocketService {
  final Logger _log = Logger();

  io.Socket? _socket;
  final StreamController<AppNotification> _notificationController =
      StreamController<AppNotification>.broadcast();
  final StreamController<ChatMessage> _chatMessageController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  final Set<String> _joinedRooms = <String>{};

  /// Stream of real-time parsed notifications.
  Stream<AppNotification> get onNotification => _notificationController.stream;

  /// Stream of real-time parsed customer chat messages.
  Stream<ChatMessage> get onChatMessage => _chatMessageController.stream;

  /// Stream of socket connection state changes (true = connected, false = disconnected).
  Stream<bool> get onConnectionStatus => _connectionStatusController.stream;

  /// Current connection status.
  bool get isConnected => _socket?.connected ?? false;

  /// Current socket ID.
  String? get socketId => _socket?.id;

  /// Currently active conversation rooms.
  Set<String> get activeRooms => Set.unmodifiable(_joinedRooms);

  /// Primary backend event name for real-time notifications.
  static const String defaultNotificationEvent = 'notification';

  /// Primary backend event name for real-time chat messages.
  static const String defaultChatEvent = 'chat_message';

  /// Notification backend events.
  static const List<String> supportedNotificationEvents = [
    defaultNotificationEvent,
    'new_notification',
    'customer_notification',
    'booking_notification',
    'booking_confirmed',
    'booking_accepted',
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
    'offer_notification',
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

  /// Real-time chat backend events.
  static const List<String> supportedChatEvents = [
    defaultChatEvent,
    'chatMessage',
    'chat_message_received',
    'chatMessageReceived',
    'new_message',
    'newMessage',
    'message',
    'msg',
    'receive_message',
    'receiveMessage',
    'message_received',
    'messageReceived',
    'chat',
    'assistant_reply',
    'assistantReply',
    'assistant_message',
    'assistantMessage',
    'agent_message',
    'agentMessage',
    'groomer_message',
    'groomerMessage',
    'support_message',
    'supportMessage',
    'new_chat_message',
    'newChatMessage',
    'incoming_message',
    'incomingMessage',
    'response',
    'reply',
    'chat:message',
    'chat:receive',
    'message:new',
    'message:receive',
  ];

  /// Combined supported backend events.
  static const List<String> supportedEvents = [
    ...supportedNotificationEvents,
    ...supportedChatEvents,
  ];

  Future<void> initialize() async {
    _log.d('CustomerSocketService::initialize::Initialized');
    try {
      final token = await ServicesLocator.sessionService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        _log.d('CustomerSocketService::initialize::Auto-connecting with existing session token');
        await connect(token: token);
      }
    } catch (e) {
      _log.e('CustomerSocketService::initialize::Auto-connect error: $e');
    }
  }

  /// Ensures that the Customer Socket.IO connection is established.
  /// If already connected, avoids duplicate connection attempts.
  Future<void> ensureConnected() async {
    if (isConnected) {
      _log.d('CustomerSocketService::ensureConnected::Socket already connected (Socket ID: ${_socket?.id}).');
      return;
    }
    try {
      final token = await ServicesLocator.sessionService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        _log.i('CustomerSocketService::ensureConnected::Connecting socket with saved token.');
        await connect(token: token);
      } else {
        _log.w('CustomerSocketService::ensureConnected::No access token available in session.');
      }
    } catch (e) {
      _log.e('CustomerSocketService::ensureConnected::Error establishing connection: $e');
    }
  }

  /// Connects to Socket.IO using the authenticated Customer session token.
  ///
  /// Safe against duplicate connections and duplicate event listener registration.
  Future<void> connect({
    String? token,
    String? serverUrl,
    List<String>? customEvents,
  }) async {
    final authToken =
        token ?? await ServicesLocator.sessionService.getAccessToken();

    if (authToken == null || authToken.isEmpty) {
      _log.w('CustomerSocketService::connect::No valid Customer token found. Skipping connection.');
      return;
    }

    if (_socket != null && _socket!.connected) {
      _log.d('CustomerSocketService::connect::Socket already connected (Socket ID: ${_socket?.id}).');
      return;
    }

    // Clean up any lingering socket before creating a new one
    _cleanSocket();

    final url = serverUrl ?? Constants.app.BASE_URL;
    final maskedToken = _maskToken(authToken);
    _log.i('Customer Chat Socket connecting to $url (token: $maskedToken)');

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
        _log.i('Customer Chat Socket connected: ${_socket?.id} (URL: $url)');
        _connectionStatusController.add(true);

        // Auto-join customer user rooms & re-join previously joined rooms
        _autoJoinCustomerRooms();
        for (final roomId in _joinedRooms) {
          _emitJoinRoom(roomId);
        }
      });

      _socket!.onDisconnect((reason) {
        _log.w('Customer Chat Socket disconnected: $reason');
        _connectionStatusController.add(false);
      });

      _socket!.onConnectError((err) {
        _log.e('Customer Chat Socket connection error: $err');
      });

      _socket!.on('connect_timeout', (data) {
        _log.w('CustomerSocketService::onConnectTimeout::Socket connection timed out: $data');
      });

      _socket!.onError((err) {
        _log.e('CustomerSocketService::onError::Socket general error: $err');
      });

      _socket!.onReconnect((attempt) {
        _log.i('Customer Chat Socket reconnected (attempt #$attempt)');
        _connectionStatusController.add(true);

        // Re-join active conversation and user rooms on reconnect
        _autoJoinCustomerRooms();
        for (final roomId in _joinedRooms) {
          _emitJoinRoom(roomId);
        }
      });

      _socket!.onReconnectAttempt((attempt) {
        _log.d('CustomerSocketService::onReconnectAttempt::Socket attempting reconnection #$attempt');
      });

      _socket!.onReconnectError((err) {
        _log.e('CustomerSocketService::onReconnectError::Socket reconnection error: $err');
      });

      _socket!.onReconnectFailed((_) {
        _log.e('CustomerSocketService::onReconnectFailed::Socket reconnection failed after maximum attempts');
      });

      _socket!.onPing((_) {
        _log.d('CustomerSocketService::onPing::Ping heartbeat sent');
      });

      _socket!.onPong((_) {
        _log.d('CustomerSocketService::onPong::Pong heartbeat received');
      });

      final eventsToListen = customEvents ?? supportedEvents;
      for (final eventName in eventsToListen) {
        _socket!.on(eventName, (data) {
          _routeIncomingEvent(eventName, data);
        });
      }

      // Catch-all listener to ensure no custom/backend event is missed
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
          'pong'
        };
        if (!reserved.contains(eventName) && !eventsToListen.contains(eventName)) {
          _log.i('CustomerSocketService::Received onAny event "$eventName": $data');
          _routeIncomingEvent(eventName, data);
        }
      });

      // Explicitly initiate socket connection now that all listeners are ready
      _socket!.connect();
    } catch (e) {
      _log.e('CustomerSocketService::connect::Error establishing socket: $e');
    }
  }

  // ── Conversation / Room Management ───────────────────────────────────────────

  /// Joins customer's personal user and chat rooms.
  void joinUserRooms([String? userId]) {
    try {
      final uid = userId ?? ServicesLocator.sessionService.currentUserId;
      if (uid != null && uid.trim().isNotEmpty) {
        final cleanUid = uid.trim();
        joinConversation('user_$cleanUid');
        joinConversation('customer_$cleanUid');
        joinConversation(cleanUid);
        joinConversation('customer_chat');
        joinConversation('chat_$cleanUid');
      }
    } catch (e) {
      _log.e('CustomerSocketService::joinUserRooms::Error: $e');
    }
  }

  void _autoJoinCustomerRooms() {
    try {
      final uid = ServicesLocator.sessionService.currentUserId;
      if (uid != null && uid.isNotEmpty) {
        joinUserRooms(uid);
      }
    } catch (e) {
      _log.e('CustomerSocketService::_autoJoinCustomerRooms::Error: $e');
    }
  }

  /// Joins a specific chat room / conversation.
  /// Prevents duplicate joins.
  void joinConversation(String conversationId) {
    final roomId = conversationId.trim();
    if (roomId.isEmpty) return;

    if (_joinedRooms.contains(roomId)) {
      _log.d('CustomerSocketService::joinConversation::Already joined room: $roomId');
      return;
    }

    _joinedRooms.add(roomId);
    if (_socket != null && _socket!.connected) {
      _emitJoinRoom(roomId);
    }
  }

  /// Leaves a specific chat room / conversation.
  void leaveConversation(String conversationId) {
    final roomId = conversationId.trim();
    if (roomId.isEmpty) return;

    _joinedRooms.remove(roomId);
    if (_socket != null && _socket!.connected) {
      _emitLeaveRoom(roomId);
    }
  }

  void _emitJoinRoom(String roomId) {
    _log.i('CustomerSocketService::_emitJoinRoom::Joining room: $roomId');
    final uid = ServicesLocator.sessionService.currentUserId;
    final payload = {
      'conversationId': roomId,
      'roomId': roomId,
      if (uid != null && uid.isNotEmpty) 'userId': uid,
      'userType': 'customer',
      'role': 'customer',
    };
    _socket?.emit('join_chat', payload);
    _socket?.emit('join_room', payload);
    _socket?.emit('join_conversation', payload);
    _socket?.emit('join', roomId);
    if (uid != null && uid.isNotEmpty) {
      _socket?.emit('join_user', {'userId': uid, 'userType': 'customer'});
      _socket?.emit('joinUser', {'userId': uid, 'userType': 'customer'});
    }
  }

  void _emitLeaveRoom(String roomId) {
    _log.i('CustomerSocketService::_emitLeaveRoom::Leaving room: $roomId');
    final uid = ServicesLocator.sessionService.currentUserId;
    final payload = {
      'conversationId': roomId,
      'roomId': roomId,
      if (uid != null && uid.isNotEmpty) 'userId': uid,
    };
    _socket?.emit('leave_chat', payload);
    _socket?.emit('leave_room', payload);
    _socket?.emit('leave_conversation', payload);
    _socket?.emit('leave', roomId);
  }

  // ── Realtime Message Emission ───────────────────────────────────────────────

  /// Emits a chat message via Socket.IO.
  void sendMessage({
    required String message,
    String? conversationId,
    Map<String, dynamic>? extraData,
  }) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    if (_socket != null && _socket!.connected) {
      final payload = <String, dynamic>{
        'message': trimmed,
        if (conversationId != null && conversationId.isNotEmpty) 'conversationId': conversationId,
        if (extraData != null) ...extraData,
      };

      _log.i('CustomerSocketService::sendMessage::Emitting message: $trimmed');
      _socket!.emit('send_message', payload);
      _socket!.emit('chat_message', payload);
      _socket!.emit('message', payload);
    } else {
      _log.w('CustomerSocketService::sendMessage::Socket not connected. Realtime emission skipped.');
    }
  }

  // ── Incoming Event Routing & Parsing ────────────────────────────────────────

  void _routeIncomingEvent(String eventName, dynamic rawData) {
    final eventLower = eventName.toLowerCase();
    if (_isNotificationEvent(eventLower, rawData)) {
      _handleRawNotificationEventData(eventName, rawData);
    } else if (_isChatEvent(eventLower, rawData)) {
      _handleRawChatEventData(eventName, rawData);
    } else {
      _handleRawNotificationEventData(eventName, rawData);
    }
  }

  bool _isNotificationEvent(String eventLower, dynamic rawData) {
    if (supportedNotificationEvents.map((e) => e.toLowerCase()).contains(eventLower)) {
      return true;
    }
    if (eventLower.contains('notif') ||
        eventLower.contains('booking_status') ||
        eventLower.contains('cancellation') ||
        eventLower.contains('offer')) {
      return true;
    }
    if (rawData is Map) {
      final map = rawData;
      if (map.containsKey('notification') ||
          map.containsKey('title') ||
          map.containsKey('heading') ||
          map.containsKey('subject')) {
        return true;
      }
      if (map.containsKey('data') && map['data'] is Map) {
        final inner = map['data'] as Map;
        if (inner.containsKey('notification') ||
            inner.containsKey('title') ||
            inner.containsKey('heading') ||
            inner.containsKey('subject')) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isChatEvent(String eventLower, dynamic rawData) {
    if (_isNotificationEvent(eventLower, rawData)) {
      return false;
    }
    if (supportedChatEvents.map((e) => e.toLowerCase()).contains(eventLower)) {
      return true;
    }
    if (eventLower.contains('chat') ||
        eventLower.contains('msg') ||
        eventLower.contains('message') ||
        eventLower.contains('reply') ||
        eventLower.contains('assistant') ||
        eventLower.contains('agent') ||
        eventLower.contains('groomer')) {
      return true;
    }
    if (rawData is Map) {
      final map = rawData;
      final hasExplicitChatEnvelope = map.containsKey('chat') ||
          (map.containsKey('data') && map['data'] is Map && (map['data'] as Map).containsKey('message')) ||
          (map.containsKey('payload') && map['payload'] is Map);

      final hasChatKeys = hasExplicitChatEnvelope ||
          map.containsKey('sender') ||
          map.containsKey('role') ||
          map.containsKey('from') ||
          map.containsKey('senderType') ||
          map.containsKey('sender_type') ||
          map.containsKey('isUser') ||
          map.containsKey('is_user');

      if (hasChatKeys) {
        return true;
      }
    }
    return false;
  }

  /// Parses raw Socket.IO incoming chat message event data into a [ChatMessage] and emits it.
  void _handleRawChatEventData(String eventName, dynamic rawData) {
    try {
      _log.i('CustomerSocketService::Chat event received "$eventName": $rawData');
      Map<String, dynamic> payload = {};

      if (rawData is Map<String, dynamic>) {
        payload = Map<String, dynamic>.from(rawData);
      } else if (rawData is Map) {
        payload = Map<String, dynamic>.from(rawData);
      } else if (rawData is String) {
        try {
          final decoded = jsonDecode(rawData);
          if (decoded is Map) {
            payload = Map<String, dynamic>.from(decoded);
          } else {
            payload = {'message': decoded.toString()};
          }
        } catch (_) {
          payload = {'message': rawData};
        }
      } else if (rawData != null) {
        payload = {'message': rawData.toString()};
      }

      // Recursive / multi-level unwrapping of common wrapper envelopes:
      // data, chat, payload, result, body, message (if Map)
      bool unwrapped = true;
      int unwrapDepth = 0;
      while (unwrapped && unwrapDepth < 5) {
        unwrapped = false;
        unwrapDepth++;

        for (final wrapperKey in ['data', 'chat', 'payload', 'result']) {
          if (payload.containsKey(wrapperKey) && payload[wrapperKey] is Map) {
            final inner = Map<String, dynamic>.from(payload[wrapperKey] as Map);
            payload.forEach((k, v) {
              if (k != wrapperKey && !inner.containsKey(k)) {
                inner[k] = v;
              }
            });
            payload = inner;
            unwrapped = true;
            break;
          }
        }

        if (payload.containsKey('message') && payload['message'] is Map) {
          final inner = Map<String, dynamic>.from(payload['message'] as Map);
          payload.forEach((k, v) {
            if (k != 'message' && !inner.containsKey(k)) {
              inner[k] = v;
            }
          });
          payload = inner;
          unwrapped = true;
        }
      }

      final text = (payload['message'] ??
              payload['text'] ??
              payload['content'] ??
              payload['body'] ??
              payload['reply'] ??
              payload['response'] ??
              payload['msg'] ??
              '')
          .toString()
          .trim();

      if (text.isEmpty) {
        _log.w('CustomerSocketService::_handleRawChatEventData::Ignored empty chat payload from event "$eventName"');
        return;
      }

      final chatMessage = ChatMessage.fromJson(payload);
      _log.i('CustomerSocketService::Chat message parsed: id=${chatMessage.id}, sender=${chatMessage.sender}, text="${chatMessage.message}"');
      _chatMessageController.add(chatMessage);
    } catch (e, st) {
      _log.e('CustomerSocketService::_handleRawChatEventData::Error parsing chat payload: $e\n$st');
    }
  }

  /// Parses raw Socket.IO incoming notification event data into an [AppNotification] and emits it.
  void _handleRawNotificationEventData(String eventName, dynamic rawData) {
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

      // If wrapped in a 'notification' object, unwrap it
      if (payload.containsKey('notification') && payload['notification'] is Map) {
        final innerNotification = Map<String, dynamic>.from(payload['notification'] as Map);
        payload.forEach((k, v) {
          if (!innerNotification.containsKey(k) && k != 'notification') innerNotification[k] = v;
        });
        payload = innerNotification;
      } else if (!payload.containsKey('title') &&
          !payload.containsKey('message') &&
          payload.containsKey('data') &&
          payload['data'] is Map) {
        // If top-level has no notification content but 'data' holds it, unwrap 'data'
        final innerData = Map<String, dynamic>.from(payload['data'] as Map);
        payload.forEach((k, v) {
          if (!innerData.containsKey(k) && k != 'data') innerData[k] = v;
        });
        payload = innerData;
      }

      // If id is missing, assign a unique timestamp-based fallback id
      if (!payload.containsKey('id') && !payload.containsKey('notificationId')) {
        payload['id'] = DateTime.now().millisecondsSinceEpoch;
      }

      final title = payload['title'] ?? payload['subject'] ?? payload['heading'];
      final eventLower = eventName.toLowerCase();
      final typeLower = payload['type']?.toString().toLowerCase() ?? '';
      final statusLower = payload['status']?.toString().toLowerCase() ?? '';

      // Synthesize meaningful title if missing
      if (title == null || title.toString().trim().isEmpty) {
        if (eventLower.contains('confirm') || typeLower.contains('confirm') || statusLower == 'confirmed') {
          payload['title'] = 'Booking Confirmed';
        } else if (eventLower.contains('accept') || typeLower.contains('accept')) {
          payload['title'] = 'Booking Accepted';
        } else if (eventLower.contains('cancel') || typeLower.contains('cancel')) {
          payload['title'] = 'Booking Cancelled';
        } else if (eventLower.contains('reject') || typeLower.contains('reject')) {
          payload['title'] = 'Booking Request Declined';
        } else if (eventLower.contains('offer') || typeLower.contains('offer')) {
          payload['title'] = 'Special Offer';
        } else {
          payload['title'] = 'Booking Update';
        }
      }

      // Synthesize meaningful message if missing
      final body = payload['message'] ?? payload['body'] ?? payload['description'] ?? payload['text'];
      if (body == null || body.toString().trim().isEmpty) {
        final bookingId = payload['bookingId'] ?? payload['booking_id'] ?? payload['entityId'];
        if (eventLower.contains('confirm') || typeLower.contains('confirm') || statusLower == 'confirmed') {
          payload['message'] = bookingId != null
              ? 'Your booking #$bookingId has been confirmed by the groomer.'
              : 'Your booking has been confirmed by the groomer.';
        } else {
          payload['message'] = bookingId != null
              ? 'Your booking #$bookingId has been updated.'
              : 'You have a new update for your appointment.';
        }
      }

      // Default type based on event name if not set
      if (!payload.containsKey('type') || payload['type'] == null) {
        if (eventLower.contains('confirm') || statusLower == 'confirmed') {
          payload['type'] = 'booking_confirmed';
        } else if (eventLower.contains('booking')) {
          payload['type'] = 'booking';
        } else if (eventLower.contains('offer') || eventLower.contains('promo')) {
          payload['type'] = 'offer';
        } else if (eventLower.contains('cancellation')) {
          payload['type'] = 'cancellation';
        } else {
          payload['type'] = 'general';
        }
      }

      final notification = AppNotification.fromJson(payload);
      _notificationController.add(notification);
    } catch (e) {
      _log.e('CustomerSocketService::_handleRawNotificationEventData::Error parsing event payload: $e');
    }
  }

  /// Disconnects the socket and resets connection state.
  void disconnect() {
    _log.d('CustomerSocketService::disconnect::Disconnecting socket');
    _cleanSocket();
    _joinedRooms.clear();
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
    _chatMessageController.close();
    _connectionStatusController.close();
  }

  /// Masks sensitive access token for secure debug logging.
  String _maskToken(String token) {
    if (token.length <= 8) return '****';
    return '${token.substring(0, 4)}...${token.substring(token.length - 4)}';
  }

  /// Helper for testing to inject mock notification payloads directly into the stream.
  @visibleForTesting
  void emitNotificationForTesting(AppNotification notification) {
    _notificationController.add(notification);
  }

  /// Helper for testing to inject mock chat message payloads directly into the stream.
  @visibleForTesting
  void emitChatMessageForTesting(ChatMessage message) {
    _chatMessageController.add(message);
  }

  /// Helper for testing to inject raw notification events directly.
  @visibleForTesting
  void handleRawEventForTesting(String event, dynamic data) {
    _routeIncomingEvent(event, data);
  }

  /// Helper for testing to inject raw chat events directly.
  @visibleForTesting
  void handleRawChatEventForTesting(String event, dynamic data) {
    _handleRawChatEventData(event, data);
  }
}
