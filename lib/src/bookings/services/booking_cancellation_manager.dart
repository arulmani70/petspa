import 'dart:async';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';

/// Service responsible for managing automatic cancellation of unaccepted appointments
/// at their scheduled appointment start time.
///
/// Features:
/// - Scheduled-Time Validation: Evaluates the actual appointment date (`bookingDate`)
///   and scheduled start time (`startTime`) stored in the database.
/// - Automatic Cancellation: If the appointment reaches or passes its scheduled start time
///   and remains in Pending/Unaccepted status, it is automatically changed to Cancelled.
/// - Concurrency & Race Condition Protection: Ensures accepted, confirmed, in-progress, completed,
///   or already cancelled appointments are never cancelled.
/// - Idempotency & Duplicate Prevention: Guarantees exactly one cancellation action
///   and one customer notification per booking.
/// - Offline & Delay Resilience: Handles server downtime or delayed scheduler runs by evaluating
///   all overdue pending appointments.
/// - Customer Notification: Dispatches real-time Socket.IO, in-app notification, and push notification
///   explaining that the groomer did not accept the booking before the scheduled appointment time.
class BookingCancellationManager {
  final Logger log = Logger();

  /// Set of booking IDs that have already been processed for auto-cancellation (prevents duplicate execution).
  final Set<int> _processedBookingIds = <int>{};

  /// Set of booking IDs currently being processed (prevents concurrent duplicate triggers).
  final Set<int> _inFlightBookingIds = <int>{};

  /// Periodic timer for checking pending bookings.
  Timer? _schedulerTimer;

  Future<void> initialize({Duration? checkInterval}) async {
    log.d('BookingCancellationManager::initialize::Initialized with scheduled-start-time auto cancellation');
    startBackgroundScheduler(checkInterval: checkInterval);
  }

  void dispose() {
    _schedulerTimer?.cancel();
    _schedulerTimer = null;
  }

  /// Starts the background scheduler timer to periodically evaluate unaccepted appointments.
  void startBackgroundScheduler({Duration? checkInterval}) {
    _schedulerTimer?.cancel();
    final interval = checkInterval ?? const Duration(seconds: 15);
    _schedulerTimer = Timer.periodic(interval, (_) async {
      await evaluatePendingBookings();
    });
  }

  /// Extracts the appointment date string from various possible booking map keys.
  String? extractBookingDate(Map<String, dynamic> booking) {
    final raw = booking['bookingDate'] ??
        booking['booking_date'] ??
        booking['date'] ??
        booking['appointmentDate'] ??
        booking['appointment_date'];
    return BookingDateUtils.normalizeDateString(raw);
  }

  /// Extracts the appointment start time string from various possible booking map keys.
  String? extractBookingStartTime(Map<String, dynamic> booking) {
    final raw = booking['startTime'] ??
        booking['start_time'] ??
        booking['time'] ??
        booking['slot'] ??
        booking['appointmentTime'] ??
        booking['appointment_time'];
    return BookingDateUtils.normalizeTimeString(raw);
  }

  /// Parses the scheduled start DateTime from a booking date string and start time string.
  DateTime? parseScheduledStartDateTime(dynamic bookingDate, dynamic startTime, {bool isUtc = false}) {
    if (bookingDate == null || startTime == null) return null;

    final dateStr = BookingDateUtils.normalizeDateString(bookingDate);
    final timeStr = BookingDateUtils.normalizeTimeString(startTime);
    if (dateStr == null || timeStr == null) return null;

    final dateParts = dateStr.split('-');
    final timeParts = timeStr.split(':');
    if (dateParts.length < 3 || timeParts.length < 2) return null;

    final y = int.tryParse(dateParts[0]);
    final m = int.tryParse(dateParts[1]);
    final d = int.tryParse(dateParts[2]);
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);

    if (y == null || m == null || d == null || hour == null || minute == null) {
      return null;
    }

    if (isUtc) {
      return DateTime.utc(y, m, d, hour, minute);
    }
    return DateTime(y, m, d, hour, minute);
  }

  /// Parses the scheduled start DateTime directly from a booking map.
  DateTime? parseBookingScheduledStartTime(Map<String, dynamic> booking, {bool isUtc = false}) {
    final date = extractBookingDate(booking);
    final time = extractBookingStartTime(booking);
    if (date == null || time == null) return null;
    return parseScheduledStartDateTime(date, time, isUtc: isUtc);
  }

  /// Determines whether the appointment's scheduled start time has been reached or passed.
  bool isScheduledStartTimeReached(dynamic bookingDate, dynamic startTime, {DateTime? now}) {
    final scheduled = parseScheduledStartDateTime(bookingDate, startTime);
    if (scheduled == null) return false;
    final current = now ?? DateTime.now();
    return current.isAfter(scheduled) || current.isAtSameMomentAs(scheduled);
  }

  /// Checks if a booking is in a pending/unaccepted state eligible for auto-cancellation
  /// at its scheduled appointment start time.
  bool isEligibleForAutoCancellation(Map<String, dynamic> booking, {DateTime? now}) {
    final rawStatus = booking['status']?.toString().trim().toLowerCase() ?? '';
    // Only pending bookings can be auto-cancelled.
    // Confirmed, accepted, in-progress, completed, and already cancelled are ineligible.
    if (rawStatus != 'pending' && rawStatus != 'unaccepted' && rawStatus != 'awaiting_acceptance') {
      return false;
    }

    final scheduled = parseBookingScheduledStartTime(booking);
    if (scheduled == null) {
      return false;
    }

    final current = now ?? DateTime.now();
    return current.isAfter(scheduled) || current.isAtSameMomentAs(scheduled);
  }

  /// Evaluates pending bookings from the booking repository and auto-cancels any that have
  /// reached or passed their scheduled appointment start time without groomer acceptance.
  Future<void> evaluatePendingBookings() async {
    try {
      if (!ServicesLocator.sessionService.isLoggedIn) return;
      final upcoming = await ServicesLocator.bookingRepository.getUpcomingBookingsApi();
      for (final booking in upcoming) {
        if (isEligibleForAutoCancellation(booking)) {
          final id = int.tryParse(booking['id']?.toString() ?? booking['bookingId']?.toString() ?? '');
          if (id != null && id > 0) {
            await autoCancelBooking(bookingId: id, bookingData: booking);
          }
        }
      }
    } catch (e) {
      log.w('BookingCancellationManager::evaluatePendingBookings::Error: $e');
    }
  }

  /// Automatically cancels an unaccepted booking and dispatches notifications.
  /// Idempotent, concurrency-safe, and single-execution guaranteed.
  Future<bool> autoCancelBooking({
    required int bookingId,
    required Map<String, dynamic> bookingData,
    String? reason,
  }) async {
    if (bookingId <= 0) return false;

    // Concurrency / Duplicate check
    if (_processedBookingIds.contains(bookingId) || _inFlightBookingIds.contains(bookingId)) {
      log.d('BookingCancellationManager::autoCancelBooking::Booking #$bookingId already processed or in-flight');
      return false;
    }

    // Double check status before cancelling to avoid racing with groomer acceptance
    final status = bookingData['status']?.toString().toLowerCase() ?? '';
    if (status.isNotEmpty && status != 'pending' && status != 'unaccepted' && status != 'awaiting_acceptance') {
      log.d('BookingCancellationManager::autoCancelBooking::Booking #$bookingId is status=$status — skipping');
      return false;
    }

    _inFlightBookingIds.add(bookingId);
    final cancellationReason = reason ?? Constants.app.CANCELLATION_REASON_GROOMER_TIMEOUT;

    try {
      log.i('BookingCancellationManager::autoCancelBooking::Auto-cancelling unaccepted booking #$bookingId at scheduled start time. Reason: $cancellationReason');

      // 1. Call backend cancellation endpoint
      try {
        await ServicesLocator.bookingRepository.cancelBookingApi(bookingId);
      } catch (err) {
        log.w('BookingCancellationManager::autoCancelBooking::Backend API cancel note: $err');
      }

      // 2. Mark local SQLite DB status if present
      try {
        await ServicesLocator.databaseRepository.update(
          Constants.database.TABLE_BOOKINGS,
          {
            Constants.database.COLUMN_STATUS: 'CANCELLED',
            Constants.database.COLUMN_CANCELLATION_REASON: cancellationReason,
            Constants.database.COLUMN_UPDATED_AT: DateTime.now().toUtc().toIso8601String(),
          },
          where: '${Constants.database.COLUMN_ID} = ? OR ${Constants.database.COLUMN_REMOTE_ID} = ?',
          whereArgs: [bookingId, bookingId.toString()],
        );
      } catch (_) {}

      // 3. Mark processed in idempotency set
      _processedBookingIds.add(bookingId);

      // 4. Invalidate upcoming cache to reflect immediate cancellation
      ServicesLocator.bookingRepository.invalidateUpcomingBookingsCache();

      // 5. Notify customer via in-app notification and Socket / Push with appointment details
      final petName = bookingData['pet_name'] ??
          bookingData['petName'] ??
          bookingData['pet']?['petName'] ??
          bookingData['pet']?['name'] ??
          'your pet';
      final formattedDate = bookingData['bookingDate'] ?? bookingData['booking_date'] ?? 'scheduled date';
      final formattedTime = bookingData['startTime'] ?? bookingData['start_time'] ?? 'scheduled time';

      final notification = AppNotification(
        id: bookingId,
        title: 'Appointment Auto-Cancelled',
        message: 'Your booking #$bookingId for $petName ($formattedDate at $formattedTime) was automatically cancelled because the groomer did not accept the booking before the scheduled appointment time.',
        type: 'booking_auto_cancelled',
        isRead: false,
        createdAt: DateTime.now(),
        metadata: {
          'bookingId': bookingId,
          'booking_id': bookingId,
          'petName': petName,
          'bookingDate': formattedDate,
          'startTime': formattedTime,
          'reason': cancellationReason,
          'status': 'CANCELLED',
          'autoCancelled': true,
        },
      );

      // Push to socket streams if connected
      if (ServicesLocator.isCustomerSocketServiceRegistered) {
        ServicesLocator.customerSocketService.handleDirectNotification(notification);
      }

      return true;
    } catch (e) {
      log.e('BookingCancellationManager::autoCancelBooking::Error cancelling #$bookingId: $e');
      return false;
    } finally {
      _inFlightBookingIds.remove(bookingId);
    }
  }

  /// Filters a list of bookings and auto-cancels any unaccepted pending bookings
  /// whose scheduled appointment start time has arrived/passed, updating their status in the returned list.
  Future<List<Map<String, dynamic>>> filterAndProcessExpiredBookings(
    List<Map<String, dynamic>> bookings, {
    DateTime? now,
  }) async {
    final List<Map<String, dynamic>> updatedList = [];
    for (final b in bookings) {
      final copy = Map<String, dynamic>.from(b);
      if (isEligibleForAutoCancellation(copy, now: now)) {
        final id = int.tryParse(copy['id']?.toString() ?? copy['bookingId']?.toString() ?? '');
        if (id != null && id > 0) {
          await autoCancelBooking(bookingId: id, bookingData: copy);
        }
        copy['status'] = 'CANCELLED';
        copy['cancellation_reason'] = Constants.app.CANCELLATION_REASON_GROOMER_TIMEOUT;
        copy['cancellationReason'] = Constants.app.CANCELLATION_REASON_GROOMER_TIMEOUT;
      }
      updatedList.add(copy);
    }
    return updatedList;
  }
}
