import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/app/routes.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';

/// Centralized Notification Navigation Service.
///
/// Handles routing for all notification tap events across:
/// 1. Foreground local notification taps (via flutter_local_notifications)
/// 2. Background FCM notification taps (via FirebaseMessaging.onMessageOpenedApp)
/// 3. App launch from terminated state via notification (via getInitialMessage & getNotificationAppLaunchDetails)
/// 4. In-app Notification Center taps (via NotificationsPageMobile)
/// 5. In-app Socket / Push banner interactions
///
/// Implements duplicate navigation throttling to prevent duplicate transitions
/// when rapid or multiple notification event listeners fire for the same notification.
class NotificationNavigationService {
  static final Logger _log = Logger();

  /// Sliding cache of recently navigated notification events for deduplication.
  static final Map<String, DateTime> _recentNavigationEvents = <String, DateTime>{};

  /// Clears navigation throttling history (useful for unit/widget testing).
  @visibleForTesting
  static void resetDeduplicationCache() {
    _recentNavigationEvents.clear();
  }

  /// Entrypoint for String payloads (such as JSON from flutter_local_notifications).
  static Future<bool> handlePayloadString(String? rawString, {BuildContext? context}) async {
    if (rawString == null || rawString.trim().isEmpty) {
      _log.w('NotificationNavigationService::handlePayloadString::Payload is empty');
      return false;
    }
    try {
      final decoded = jsonDecode(rawString);
      if (decoded is Map<String, dynamic>) {
        return handlePayloadMap(decoded, context: context);
      } else if (decoded is Map) {
        return handlePayloadMap(Map<String, dynamic>.from(decoded), context: context);
      }
    } catch (e) {
      _log.e('NotificationNavigationService::handlePayloadString::JSON decode error: $e');
    }
    return false;
  }

  /// Entrypoint for [AppNotification] instances from Notification list / Socket.
  static Future<bool> handleAppNotification(AppNotification notification, {BuildContext? context}) async {
    final metadata = notification.metadata ?? <String, dynamic>{};
    final payload = <String, dynamic>{
      ...metadata,
      'type': notification.type,
      'id': notification.id,
      'title': notification.title,
      'message': notification.message,
    };
    return handlePayloadMap(payload, context: context);
  }

  /// Master routing handler for normalized map payloads.
  static Future<bool> handlePayloadMap(Map<String, dynamic>? data, {BuildContext? context}) async {
    if (data == null || data.isEmpty) {
      _log.w('NotificationNavigationService::handlePayloadMap::Payload map is empty');
      return false;
    }

    final type = (data['type'] ??
            data['event'] ??
            data['status'] ??
            data['notification_type'] ??
            '')
        .toString()
        .toLowerCase();

    final rawBookingId = data['bookingId'] ??
        data['booking_id'] ??
        data['entityId'] ??
        data['entity_id'] ??
        (data['data'] is Map ? (data['data']['bookingId'] ?? data['data']['booking_id']) : null);

    final bookingId = rawBookingId is int
        ? rawBookingId
        : (rawBookingId != null ? int.tryParse(rawBookingId.toString()) : null);

    final notifId = data['id'] ?? data['notificationId'] ?? data['notification_id'];

    // ── Deduplication check ──────────────────────────────────────────────────
    final now = DateTime.now();
    _recentNavigationEvents.removeWhere(
      (_, timestamp) => now.difference(timestamp).inSeconds > 10,
    );

    final dedupKey = '${bookingId ?? 'no_bkid'}|$type|${notifId ?? ''}';
    if (_recentNavigationEvents.containsKey(dedupKey)) {
      final lastTime = _recentNavigationEvents[dedupKey]!;
      if (now.difference(lastTime).inMilliseconds < 2500) {
        _log.d('NotificationNavigationService::handlePayloadMap::Throttling duplicate navigation ($dedupKey)');
        return false;
      }
    }
    _recentNavigationEvents[dedupKey] = now;

    _log.i('NotificationNavigationService::handlePayloadMap::Navigating for type="$type", bookingId=$bookingId');

    // ── Ready for Checkout Navigation ────────────────────────────────────────
    final isReadyForCheckout = type.contains('ready_for_checkout') ||
        type.contains('customer_checkout') ||
        (type.contains('checkout') && !type.contains('groomer_checkout'));

    if (isReadyForCheckout) {
      if (bookingId != null && bookingId > 0) {
        return navigateToRoute(
          RouteNames.customerCheckoutSummary,
          queryParams: {'bookingId': bookingId.toString()},
          extra: data,
          context: context,
        );
      } else {
        // Missing booking ID fallback: Navigate to checkout summary with error query param so user gets clear recovery UI
        return navigateToRoute(
          RouteNames.customerCheckoutSummary,
          queryParams: {'error': 'missing_booking_id'},
          extra: data,
          context: context,
        );
      }
    }

    // ── Groomer Portal Notification Routing ──────────────────────────────────
    final isGroomerLoggedIn = ServicesLocator.isRegistered<SessionService>() &&
        ServicesLocator.sessionService.isGroomerLoggedIn;
    final isGroomerTarget = data['role']?.toString().toLowerCase() == 'groomer' ||
        type.contains('groomer') ||
        type.contains('booking_tip_confirmed') ||
        type.contains('tip_confirmed');

    if (isGroomerTarget || isGroomerLoggedIn) {
      if (type.contains('tip') || type.contains('checkout')) {
        return navigateToRoute(
          RouteNames.groomerHome,
          context: context,
        );
      }
      return navigateToRoute(
        RouteNames.groomerAllSchedule,
        context: context,
      );
    }

    // ── Customer Standard Booking Notification Routing ───────────────────────
    if (bookingId != null ||
        type.contains('booking') ||
        type.contains('appointment') ||
        type.contains('milestone') ||
        type.contains('groom')) {
      return navigateToRoute(
        RouteNames.myBookings,
        context: context,
      );
    }

    // ── Offer / Promotion Routing ────────────────────────────────────────────
    if (type.contains('offer') || type.contains('promo') || type.contains('discount')) {
      return navigateToRoute(
        RouteNames.offers,
        context: context,
      );
    }

    // ── Default fallback ─────────────────────────────────────────────────────
    return navigateToRoute(
      RouteNames.home,
      context: context,
    );
  }

  /// Dispatches navigation using either the provided [BuildContext], or the global [Routes.globalRouter].
  /// Supports retries if the router delegate is not yet initialized (e.g. during cold launch).
  static Future<bool> navigateToRoute(
    String routeName, {
    Map<String, String>? queryParams,
    Object? extra,
    BuildContext? context,
  }) async {
    // 1. Try navigation with provided BuildContext if mounted
    if (context != null && context.mounted) {
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        try {
          router.goNamed(
            routeName,
            queryParameters: queryParams ?? const {},
            extra: extra,
          );
          return true;
        } catch (e) {
          _log.w('NotificationNavigationService::navigateToRoute::Context go failed ($e), falling back to globalRouter');
        }
      }
    }

    // 2. Fall back to global router
    try {
      Routes.globalRouter.goNamed(
        routeName,
        queryParameters: queryParams ?? const {},
        extra: extra,
      );
      return true;
    } catch (e) {
      _log.w('NotificationNavigationService::navigateToRoute::Immediate globalRouter go failed: $e. Scheduling post frame retry.');
      
      // 3. Retry on next frame (handles app startup from terminated state)
      try {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            Routes.globalRouter.goNamed(
              routeName,
              queryParameters: queryParams ?? const {},
              extra: extra,
            );
          } catch (err) {
            _log.e('NotificationNavigationService::navigateToRoute::PostFrameCallback retry failed: $err');
          }
        });
        return true;
      } catch (err) {
        _log.e('NotificationNavigationService::navigateToRoute::Unable to schedule post frame navigation: $err');
        return false;
      }
    }
  }
}
