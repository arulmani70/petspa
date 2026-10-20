import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class ToastUtil {
  static String? _lastMessage;
  static DateTime? _lastTime;
  static ToastificationType? _lastType;

  @visibleForTesting
  static void resetForTesting() {
    _lastMessage = null;
    _lastTime = null;
    _lastType = null;
  }

  @visibleForTesting
  static String? get lastMessageForTesting => _lastMessage;

  static void showSuccessToast(BuildContext context, String message) {
    _showToast(
      context: context,
      message: message,
      type: ToastificationType.success,
      backgroundColor: Colors.green,
      icon: Icons.check_circle,
    );
  }

  static void showErrorToast(BuildContext context, String message) {
    _showToast(
      context: context,
      message: message,
      type: ToastificationType.error,
      backgroundColor: Colors.red,
      icon: Icons.error,
    );
  }

  static void showWarningToast(BuildContext context, String message) {
    _showToast(
      context: context,
      message: message,
      type: ToastificationType.warning,
      backgroundColor: Colors.orange,
      icon: Icons.crisis_alert_outlined,
    );
  }

  static void showInfoToast(BuildContext context, String message) {
    _showToast(
      context: context,
      message: message,
      type: ToastificationType.info,
      backgroundColor: Colors.blueAccent,
      icon: Icons.info_outline,
    );
  }

  static void info(BuildContext context, String message) {
    showInfoToast(context, message);
  }

  static void _showToast({
    required BuildContext context,
    required String message,
    required ToastificationType type,
    required Color backgroundColor,
    required IconData icon,
  }) {
    final now = DateTime.now();

    // 1. Strict duplicate suppression: identical message within 2500ms
    if (_lastMessage == message &&
        _lastTime != null &&
        now.difference(_lastTime!).inMilliseconds < 2500) {
      return;
    }

    // 2. Prevent double toast: if any success toast was shown in the last 2000ms,
    // suppress follow-up info/notification toasts
    if (type == ToastificationType.info &&
        _lastType == ToastificationType.success &&
        _lastTime != null &&
        now.difference(_lastTime!).inMilliseconds < 2000) {
      return;
    }

    // 3. Debounce rapid-fire toasts within 600ms to guarantee only 1 toast at a time
    if (_lastTime != null && now.difference(_lastTime!).inMilliseconds < 600) {
      return;
    }

    _lastMessage = message;
    _lastTime = now;
    _lastType = type;

    try {
      // Dismiss any existing toast so toasts never stack on screen
      toastification.dismissAll(delayForAnimation: false);

      toastification.show(
        context: context,
        type: type,
        style: ToastificationStyle.flat,
        autoCloseDuration: const Duration(seconds: 4),
        title: Text(
          type == ToastificationType.success
              ? 'Success'
              : type == ToastificationType.warning
                  ? 'Warning'
                  : type == ToastificationType.info
                      ? 'Notification'
                      : 'Error',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        description: Text(
          message,
          style: const TextStyle(color: Colors.black),
        ),
        alignment: Alignment.bottomRight,
        primaryColor: backgroundColor,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        icon: Icon(icon, color: backgroundColor),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 16,
            offset: Offset(0, 16),
            spreadRadius: 0,
          ),
        ],
        showProgressBar: true,
        closeOnClick: false,
        pauseOnHover: true,
        dragToClose: true,
        applyBlurEffect: true,
        callbacks: const ToastificationCallbacks(),
      );
    } catch (_) {
      try {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: backgroundColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (_) {}
    }
  }
}
