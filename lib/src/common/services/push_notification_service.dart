import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/firebase_options.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/common/services/notification_navigation_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';

/// Dedicated Android Notification Channel for Shear Heaven Pet Spa.
const AndroidNotificationChannel
highImportanceChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'Shear Heaven Notifications',
  description:
      'High importance notifications for appointments, bookings, and updates.',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
);

/// Top-level background message handler for FCM.
///
/// This handler MUST be a top-level function annotated with `@pragma('vm:entry-point')`.
/// It executes in a separate background isolate when a push arrives while the app is
/// in the background or completely closed / terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (_) {
        await Firebase.initializeApp();
      }
    }
  } catch (e) {
    debugPrint('[FCM Background] Firebase initialization error: $e');
  }

  debugPrint('[FCM Background] Received messageId: ${message.messageId}');
  debugPrint(
    '[FCM Background] Notification: title=${message.notification?.title}, body=${message.notification?.body}',
  );
  debugPrint('[FCM Background] Data: ${message.data}');

  final title =
      message.notification?.title ??
      message.data['title']?.toString() ??
      message.data['notification_title']?.toString() ??
      message.data['header']?.toString() ??
      'Shear Heaven Pet Spa';
  final body =
      message.notification?.body ??
      message.data['body']?.toString() ??
      message.data['message']?.toString() ??
      message.data['notification_body']?.toString() ??
      message.data['text']?.toString() ??
      'You have a new update';

  final rawId = message.data['id'] ??
      message.data['notificationId'] ??
      message.data['bookingId'] ??
      message.data['booking_id'];
  final resolvedId = (rawId != null ? int.tryParse(rawId.toString()) : null) ??
      (message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch).abs();

  // Persist background notification so when the app opens/resumes, the in-app
  // notification list and unread count reflect it across Customer, Groomer, and Admin portals.
  try {
    final prefs = await SharedPreferences.getInstance();
    const bgKey = 'PENDING_BG_FCM_NOTIFS';
    final existingRaw = prefs.getString(bgKey);
    final List<Map<String, dynamic>> list = [];
    if (existingRaw != null && existingRaw.isNotEmpty) {
      final decoded = jsonDecode(existingRaw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) list.add(Map<String, dynamic>.from(item));
        }
      }
    }
    final notifPayload = <String, dynamic>{
      'id': resolvedId,
      'title': title,
      'message': body,
      'body': body,
      'type': message.data['type']?.toString() ?? 'general',
      'isRead': false,
      'createdAt': DateTime.now().toIso8601String(),
      'data': Map<String, dynamic>.from(message.data),
      if (message.data['userId'] != null) 'userId': message.data['userId'],
      if (message.data['groomerId'] != null) 'groomerId': message.data['groomerId'],
      if (message.data['role'] != null) 'role': message.data['role'],
    };
    final exists = list.any((e) => e['id']?.toString() == resolvedId.toString());
    if (!exists) {
      list.insert(0, notifPayload);
      await prefs.setString(bgKey, jsonEncode(list));
    }
  } catch (e) {
    debugPrint('[FCM Background] Failed to persist background notification: $e');
  }

  // When the message is data-only (no notification payload), Android OS does not
  // display a system notification automatically. We initialize and display it using flutter_local_notifications.
  if (message.notification == null && message.data.isNotEmpty) {
    try {
      final FlutterLocalNotificationsPlugin localNotifications =
          FlutterLocalNotificationsPlugin();
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );
      await localNotifications.initialize(settings: initSettings);

      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidPlugin?.createNotificationChannel(highImportanceChannel);
      }

      final androidNotificationDetails = AndroidNotificationDetails(
        highImportanceChannel.id,
        highImportanceChannel.name,
        channelDescription: highImportanceChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await localNotifications.show(
        id: resolvedId,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      debugPrint('[FCM Background] Local notification display error: $e');
    }
  }
}

/// Push Notification Service for REAL-TIME FCM token registration and lifecycle handling.
///
/// Firebase Project ID: shpr-3b7ce
///
/// Handles:
/// - Initial FCM token registration with real Firebase tokens
/// - FCM token refresh (via [FirebaseMessaging.instance.onTokenRefresh])
/// - Background/Terminated message handling (via [firebaseMessagingBackgroundHandler])
/// - Local heads-up notifications across all states
/// - App reinstall / token change
/// - User login & logout
/// - Persistent Device ID from [DeviceIdService]
/// - Dynamic platform detection (android / ios)
class PushNotificationService {
  final Logger _log = Logger();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _currentToken;
  bool _isFirebaseInitialized = false;
  bool _isLocalNotificationsInitialized = false;

  /// Deduplication cache to avoid showing duplicate banners within a short window.
  final Map<String, DateTime> _recentDisplayedKeys = {};

  /// Dedicated Firebase Project ID for Shear Heaven Pet Spa
  static const String firebaseProjectId = 'shpr-3b7ce';

  bool get isFirebaseInitialized => _isFirebaseInitialized;

  /// Masks the FCM token for safe logging in production logs.
  /// Example: "eK9abc...3xPq"
  static String maskToken(String? token) {
    if (token == null || token.trim().isEmpty) return '<empty>';
    final trimmed = token.trim();
    if (trimmed.length <= 10) return '***';
    return '${trimmed.substring(0, 6)}...${trimmed.substring(trimmed.length - 4)}';
  }

  /// Masks the Device ID for safe logging in production logs.
  /// Example: "550e84...0000"
  static String maskDeviceId(String? deviceId) {
    if (deviceId == null || deviceId.trim().isEmpty) return '<empty>';
    final trimmed = deviceId.trim();
    if (trimmed.length <= 10) return '***';
    return '${trimmed.substring(0, 6)}...${trimmed.substring(trimmed.length - 4)}';
  }

  /// Determines the dynamic runtime platform: 'android' or 'ios'.
  static String get currentPlatform {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      return Platform.operatingSystem.toLowerCase();
    } catch (_) {
      return 'android';
    }
  }

  /// Initializes Firebase, requests notification permissions, sets up background & foreground
  /// message handlers, creates notification channels, and registers the initial FCM token.
  Future<void> initialize() async {
    // Always initialize local notifications even if Firebase is unavailable in test/desktop environments
    await _initializeLocalNotifications();
    await ingestPendingBackgroundNotifications();

    try {
      _log.d(
        'PushNotificationService::initialize::Initializing Firebase for project $firebaseProjectId...',
      );
      if (Firebase.apps.isEmpty) {
        FirebaseOptions? options;
        try {
          options = DefaultFirebaseOptions.currentPlatform;
        } catch (_) {
          // Fallback if platform options not supported (e.g. desktop)
        }
        if (options != null) {
          await Firebase.initializeApp(options: options).timeout(
            const Duration(milliseconds: 1500),
            onTimeout: () => throw Exception('Firebase init timeout'),
          );
        } else {
          await Firebase.initializeApp().timeout(
            const Duration(milliseconds: 1500),
            onTimeout: () => throw Exception('Firebase init timeout'),
          );
        }
      }
      _isFirebaseInitialized = true;
      _log.d(
        'PushNotificationService::initialize::Firebase initialized successfully',
      );

      // Register background handler for terminated & background message handling
      try {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
      } catch (e) {
        _log.d(
          'PushNotificationService::initialize::onBackgroundMessage registration skipped/unsupported: $e',
        );
      }

      // Configure foreground notification presentation options
      try {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: true,
              badge: true,
              sound: true,
            );
      } catch (e) {
        _log.d(
          'PushNotificationService::initialize::setForegroundNotificationPresentationOptions skipped: $e',
        );
      }

      // Setup foreground message listener
      _setupForegroundMessageListener();

      // Setup notification tap handlers (background and terminated)
      _setupNotificationOpenedListeners();

      // Request notification permissions on supported platforms
      await _requestPermissions();

      // Set up token refresh listener
      _setupTokenRefreshListener();

      // Retrieve and register initial token
      await fetchAndRegisterToken();
    } catch (e) {
      _log.w(
        'PushNotificationService::initialize::Firebase initialization skipped or failed: $e',
      );
    }
  }

  Future<void> _initializeLocalNotifications() async {
    if (_isLocalNotificationsInitialized) return;
    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          _log.d(
            'PushNotificationService::onNotificationTapped::Payload: ${response.payload}',
          );
          if (response.payload != null && response.payload!.isNotEmpty) {
            NotificationNavigationService.handlePayloadString(response.payload);
          }
        },
      );

      // Check if application was launched by tapping a local notification
      try {
        final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
        if (launchDetails != null &&
            launchDetails.didNotificationLaunchApp &&
            launchDetails.notificationResponse?.payload != null &&
            launchDetails.notificationResponse!.payload!.isNotEmpty) {
          _log.i(
            'PushNotificationService::App launched from local notification payload: ${launchDetails.notificationResponse!.payload}',
          );
          NotificationNavigationService.handlePayloadString(
            launchDetails.notificationResponse!.payload,
          );
        }
      } catch (e) {
        _log.d('PushNotificationService::getNotificationAppLaunchDetails check skipped: $e');
      }

      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidPlugin?.createNotificationChannel(highImportanceChannel);
      }
      _isLocalNotificationsInitialized = true;
      _log.d(
        'PushNotificationService::_initializeLocalNotifications::Channel ${highImportanceChannel.id} initialized',
      );
    } catch (e) {
      _log.d(
        'PushNotificationService::_initializeLocalNotifications::Skipped: $e',
      );
    }
  }

  /// Ingests any notifications received in the background isolate while the app was backgrounded/terminated.
  Future<void> ingestPendingBackgroundNotifications() async {
    try {
      final session = ServicesLocator.sessionService;
      final pending = await session.consumePendingBackgroundFcmNotifications();
      for (final raw in pending) {
        await handleRemotePayload(
          raw,
          title: raw['title']?.toString(),
          body: raw['message']?.toString() ?? raw['body']?.toString(),
          id: raw['id'],
          showBanner: false,
        );
      }
    } catch (e) {
      _log.d(
        'PushNotificationService::ingestPendingBackgroundNotifications::Skipped: $e',
      );
    }
  }

  void _setupForegroundMessageListener() {
    try {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        _log.i(
          '[FCM Foreground] Received: ${message.notification?.title ?? message.data['title']}',
        );
        await handleIncomingRemoteMessage(message, showBanner: true);
      });
    } catch (e) {
      _log.d(
        'PushNotificationService::_setupForegroundMessageListener::Skipped: $e',
      );
    }
  }

  void _setupNotificationOpenedListeners() {
    try {
      // When app is in background and user taps on notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
        _log.i(
          '[FCM Click] App opened from background notification: ${message.data}',
        );
        await handleIncomingRemoteMessage(message, showBanner: false);
        await NotificationNavigationService.handlePayloadMap(message.data);
      });

      // When app is terminated and user taps on notification to launch app
      FirebaseMessaging.instance.getInitialMessage().then((
        RemoteMessage? message,
      ) async {
        if (message != null) {
          _log.i(
            '[FCM Click] App launched from terminated notification: ${message.data}',
          );
          await handleIncomingRemoteMessage(message, showBanner: false);
          await NotificationNavigationService.handlePayloadMap(message.data);
        }
      });
    } catch (e) {
      _log.d(
        'PushNotificationService::_setupNotificationOpenedListeners::Skipped: $e',
      );
    }
  }

  /// Processes an incoming [RemoteMessage] from FCM (foreground, background tap, or initial launch),
  /// displays a local heads-up notification if [showBanner] is true, and routes the notification
  /// to the appropriate in-app portal stream and persistent store.
  Future<AppNotification?> handleIncomingRemoteMessage(
    RemoteMessage message, {
    bool showBanner = true,
  }) async {
    final title =
        message.notification?.title ??
        message.data['title']?.toString() ??
        message.data['notification_title']?.toString() ??
        message.data['header']?.toString() ??
        '';
    final body =
        message.notification?.body ??
        message.data['body']?.toString() ??
        message.data['message']?.toString() ??
        message.data['notification_body']?.toString() ??
        '';
    final rawId = message.data['id'] ??
        message.data['notificationId'] ??
        message.data['bookingId'] ??
        message.data['booking_id'] ??
        message.messageId?.hashCode;

    return handleRemotePayload(
      Map<String, dynamic>.from(message.data),
      title: title,
      body: body,
      id: rawId,
      showBanner: showBanner,
    );
  }

  /// Parses a notification payload map, deduplicates banner display, persists for the target recipient,
  /// and forwards to the active portal's real-time stream (Customer, Groomer, or Admin).
  Future<AppNotification?> handleRemotePayload(
    Map<String, dynamic> rawData, {
    String? title,
    String? body,
    dynamic id,
    bool showBanner = true,
  }) async {
    try {
      final data = Map<String, dynamic>.from(rawData);
      final resolvedTitle = (title != null && title.trim().isNotEmpty)
          ? title.trim()
          : (data['title']?.toString() ??
              data['notification_title']?.toString() ??
              'Shear Heaven Pet Spa');
      final resolvedBody = (body != null && body.trim().isNotEmpty)
          ? body.trim()
          : (data['body']?.toString() ??
              data['message']?.toString() ??
              data['notification_body']?.toString() ??
              '');

      final rawId = id ??
          data['id'] ??
          data['notificationId'] ??
          data['bookingId'] ??
          data['booking_id'];
      final resolvedId = (rawId is int
              ? rawId
              : (rawId != null ? int.tryParse(rawId.toString()) : null)) ??
          DateTime.now().millisecondsSinceEpoch;

      final type = (data['type'] ?? data['event'] ?? 'general').toString();
      final notifJson = <String, dynamic>{
        ...data,
        'id': resolvedId,
        'notificationId': resolvedId,
        'title': resolvedTitle,
        'message': resolvedBody,
        'body': resolvedBody,
        'type': type,
        'isRead': data['isRead'] == true || data['is_read'] == true,
        'createdAt':
            data['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
        'data': data['data'] is Map
            ? Map<String, dynamic>.from(data['data'] as Map)
            : Map<String, dynamic>.from(data),
      };

      final notification = AppNotification.fromJson(notifJson);

      if (showBanner && (resolvedTitle.isNotEmpty || resolvedBody.isNotEmpty)) {
        await showLocalNotification(
          id: resolvedId,
          title: resolvedTitle,
          body: resolvedBody,
          payload: jsonEncode(data),
        );
      }

      // Route to appropriate portal(s) based on recipient metadata and active session
      final session = ServicesLocator.sessionService;
      final roleTarget = (data['role'] ??
              data['recipientRole'] ??
              data['targetRole'] ??
              data['portal'] ??
              '')
          .toString()
          .toLowerCase();
      final targetGroomerId = int.tryParse(
        (data['groomerId'] ??
                data['groomer_id'] ??
                (data['data'] is Map ? data['data']['groomerId'] : null) ??
                '')
            .toString(),
      );
      final targetUserId = int.tryParse(
        (data['userId'] ??
                data['user_id'] ??
                data['customerId'] ??
                data['customer_id'] ??
                (data['data'] is Map ? data['data']['userId'] : null) ??
                '')
            .toString(),
      );

      final isExplicitGroomerOrAdmin = roleTarget.contains('groomer') ||
          roleTarget.contains('admin') ||
          roleTarget.contains('staff') ||
          type.toLowerCase().contains('groomer_notification') ||
          type.toLowerCase().contains('new_booking') ||
          type.toLowerCase().contains('cancellation_requested');

      final isExplicitCustomer = roleTarget.contains('customer') ||
          type.toLowerCase().contains('customer_notification');

      if (isExplicitGroomerOrAdmin ||
          (!isExplicitCustomer && session.isGroomerLoggedIn)) {
        await session.saveGroomerPortalNotification(
          notifJson,
          groomerId: targetGroomerId,
        );
        if (ServicesLocator.isGroomerSocketServiceRegistered) {
          ServicesLocator.groomerSocketService
              .handleDirectNotification(notification);
        }
      }

      if (isExplicitCustomer ||
          (!isExplicitGroomerOrAdmin && session.isLoggedIn)) {
        await session.saveCustomerPortalNotification(
          notifJson,
          customerId: targetUserId,
        );
        if (ServicesLocator.isCustomerSocketServiceRegistered) {
          ServicesLocator.customerSocketService
              .handleDirectNotification(notification);
        }
      }

      return notification;
    } catch (e) {
      _log.w('PushNotificationService::handleRemotePayload::Error: $e');
      return null;
    }
  }

  /// Displays a local heads-up notification with built-in deduplication so the same
  /// notification is never shown twice within a 5-second window.
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final now = DateTime.now();
    _recentDisplayedKeys.removeWhere(
      (_, timestamp) => now.difference(timestamp).inSeconds > 5,
    );
    final dedupKey = '$id|${title.trim()}|${body.trim()}';
    final contentKey = '${title.trim()}|${body.trim()}';
    if (_recentDisplayedKeys.containsKey(dedupKey) ||
        (title.trim().isNotEmpty &&
            body.trim().isNotEmpty &&
            _recentDisplayedKeys.containsKey(contentKey))) {
      _log.d(
        'PushNotificationService::showLocalNotification::Skipping duplicate local notification ($dedupKey)',
      );
      return;
    }
    _recentDisplayedKeys[dedupKey] = now;
    if (title.trim().isNotEmpty && body.trim().isNotEmpty) {
      _recentDisplayedKeys[contentKey] = now;
    }

    try {
      await _initializeLocalNotifications();
      final androidDetails = AndroidNotificationDetails(
        highImportanceChannel.id,
        highImportanceChannel.name,
        channelDescription: highImportanceChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      _log.w('PushNotificationService::showLocalNotification::Error: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidPlugin?.requestNotificationsPermission();
      } else if (!kIsWeb && Platform.isIOS) {
        final iosPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        await iosPlugin?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      _log.d(
        'PushNotificationService::_requestPermissions::Local permission request skipped: $e',
      );
    }

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      _log.d(
        'PushNotificationService::_requestPermissions::Status: ${settings.authorizationStatus}',
      );
    } catch (e) {
      _log.d(
        'PushNotificationService::_requestPermissions::Permission request ignored: $e',
      );
    }
  }

  void _setupTokenRefreshListener() {
    try {
      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen(
            (newToken) async {
              _log.i('[FCM] Token refreshed: ${maskToken(newToken)}');
              _currentToken = newToken;
              await registerDeviceToken(token: newToken);
            },
            onError: (error) {
              _log.e('[FCM] Error on token refresh stream: $error');
            },
          );
      _log.d(
        'PushNotificationService::_setupTokenRefreshListener::Listening for token refreshes',
      );
    } catch (e) {
      _log.d(
        'PushNotificationService::_setupTokenRefreshListener::Failed to attach listener: $e',
      );
    }
  }

  /// Fetches real FCM token from Firebase at runtime and registers it with backend.
  Future<String?> fetchAndRegisterToken({bool? isGroomer}) async {
    try {
      final messaging = FirebaseMessaging.instance;

      // On iOS devices, APNs token must be ready before requesting FCM token
      if (!kIsWeb && Platform.isIOS) {
        String? apnsToken = await messaging.getAPNSToken();
        if (apnsToken == null) {
          _log.d('[FCM] Waiting for iOS APNs token...');
          for (int i = 0; i < 10; i++) {
            await Future.delayed(const Duration(milliseconds: 500));
            apnsToken = await messaging.getAPNSToken();
            if (apnsToken != null) break;
          }
        }
        if (apnsToken != null) {
          _log.d('[FCM] iOS APNs token received: ${maskToken(apnsToken)}');
        } else {
          _log.w(
            '[FCM] iOS APNs token not yet available (may take a moment on simulator/fresh install)',
          );
        }
      }

      String? token;
      for (int i = 0; i < 3 && (token == null || token.trim().isEmpty); i++) {
        token = await messaging.getToken();
        if (token == null || token.trim().isEmpty) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      if (token != null && token.trim().isNotEmpty) {
        _currentToken = token.trim();
        _log.i('[FCM] Firebase Project: $firebaseProjectId');
        _log.i('[FCM] Full FCM Token: $_currentToken');
        await registerDeviceToken(token: _currentToken, isGroomer: isGroomer);
        return _currentToken;
      } else {
        _log.w('[FCM] Firebase getToken() returned null or empty token');
      }
    } catch (e) {
      _log.w('[FCM] Error getting FCM token: $e');
    }
    return null;
  }

  /// Registers the device token with the backend API: POST /api/notifications/device-token
  ///
  /// Strictly requires:
  /// - Real persistent Device ID from [DeviceIdService]
  /// - Real FCM token from Firebase runtime
  /// - Dynamic platform ('android' or 'ios')
  /// - Authenticated session
  Future<bool> registerDeviceToken({String? token, bool? isGroomer}) async {
    try {
      // 1. Obtain persistent Device ID (never generated anew)
      final deviceId = await ServicesLocator.deviceIdService.getDeviceId();
      if (deviceId.isEmpty) {
        _log.w('[FCM] Device ID is unavailable. Skipping registration.');
        return false;
      }

      // 2. Obtain real FCM token
      final tokenToRegister =
          token ??
          _currentToken ??
          ServicesLocator.sessionService.getPushToken();
      if (tokenToRegister == null || tokenToRegister.trim().isEmpty) {
        _log.w('[FCM] Push token is unavailable. Skipping registration.');
        return false;
      }

      // Cache token locally
      await ServicesLocator.sessionService.savePushToken(tokenToRegister);

      // 3. Verify user authentication session
      final session = ServicesLocator.sessionService;
      final isAuth = session.isLoggedIn || session.isGroomerLoggedIn;
      if (!isAuth) {
        _log.d(
          '[FCM] Authenticated session is not yet available. Token saved; deferring backend registration.',
        );
        return false;
      }

      // For groomer sessions, the /api/notifications/device-token endpoint is strictly customer-scoped
      final isGroomerOnlySession =
          isGroomer == true || (!session.isLoggedIn && session.isGroomerLoggedIn);
      if (isGroomerOnlySession) {
        _log.d(
          '[FCM] Device token cached locally for groomer session (backend notification endpoint is customer-scoped)',
        );
        return true;
      }

      // 4. Dynamic platform
      final platform = currentPlatform;

      // 5. Explicit Logging
      _log.i('[FCM] Firebase Project: $firebaseProjectId');
      _log.i('[FCM] Full Device ID: $deviceId');
      _log.i('[FCM] Full FCM Token: $tokenToRegister');
      _log.i('[FCM] Platform: $platform');
      debugPrint(
        '==================== [FCM FULL TOKEN START] ====================',
      );
      debugPrint(tokenToRegister);
      debugPrint(
        '==================== [FCM FULL TOKEN END] ====================',
      );
      debugPrint('==================== [DEVICE ID START] ====================');
      debugPrint(deviceId);
      debugPrint('==================== [DEVICE ID END] ====================');
      _log.i('[FCM] Registering device token...');

      // 6. API call via existing network architecture
      final api = ServicesLocator.apiRepository;
      api.setNotificationAuthRole(isGroomer);
      late final Map<String, dynamic>? response;
      try {
        response = await api.post('/api/notifications/device-token', {
          'deviceId': deviceId,
          'pushToken': tokenToRegister,
          'platform': platform,
        });
      } finally {
        api.setNotificationAuthRole(null);
      }

      final success = response != null && response['success'] == true;
      if (success) {
        _log.i('[FCM] Device token registration successful');
        return true;
      } else {
        final statusCode = response?['statusCode'] ?? response?['code'] ?? 400;
        final message = response?['message'] ?? 'Unknown error';
        final isGroomerOnlySession =
            isGroomer == true || (!session.isLoggedIn && session.isGroomerLoggedIn);
        if (isGroomerOnlySession &&
            message.toString().toLowerCase().contains('user not found')) {
          _log.d(
            '[FCM] Device token cached locally for groomer session (endpoint customer-scoped)',
          );
          return false;
        }
        _log.e(
          '[FCM] Device token registration failed: Status $statusCode - $message',
        );
        return false;
      }
    } catch (e) {
      _log.e('[FCM] Device token registration failed with error: $e');
      return false;
    }
  }

  /// Sets current runtime token manually (e.g. for testing).
  void setCurrentTokenForTesting(String? token) {
    _currentToken = token;
  }

  /// Returns the current runtime FCM token if available.
  Future<String?> getToken() async {
    if (_currentToken != null && _currentToken!.isNotEmpty) {
      return _currentToken;
    }
    return fetchAndRegisterToken();
  }

  /// Cancels subscriptions on dispose.
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }
}
