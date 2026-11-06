import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/app/routes.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_formatters.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/exit_confirmation_dialog.dart';
import 'package:shear_heaven_pet_spa/src/groomer/bloc/groomer_bloc.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/bloc/groomer_home_bloc.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_schedule_models.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_user.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/repo/groomer_home_repository.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/schedule/groomer_working_hours_table_widget.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/schedule/store_hours_table_widget.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/main_line_booking_dialog.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/groomer_check_in_dialog.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/groomer_milestone_dialog.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/groomer_final_checkout_dialog.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/forecast/forecast_page.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/reports/reports_summary_page.dart';
import 'package:shear_heaven_pet_spa/src/bookings/models/booking_receipt.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/booking_receipt_page_mobile.dart';

class GroomerHomePageMobile extends StatefulWidget {
  final List<GroomerBooking>? initialBookings;

  const GroomerHomePageMobile({super.key, this.initialBookings});

  @override
  State<GroomerHomePageMobile> createState() => _GroomerHomePageMobileState();
}

class _GroomerHomePageMobileState extends State<GroomerHomePageMobile> {
  GroomerUser? _groomer;
  DateTime _selectedDate = DateTime.now();
  int _currentTabIndex = 0;
  bool _isLoading = false;
  String? _errorMessage;

  static const LinearGradient _darkGradient = LinearGradient(
    colors: [Color(0xFF3A3A3A), Colors.black],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  List<GroomerBooking> _upcomingBookings = [];
  List<GroomerBooking> _pendingBookings = [];
  List<GroomerBooking> _pastBookings = [];
  List<GroomerBooking> _cancelledBookings = [];
  List<GroomerBooking> _cancellationRequests = [];
  List<StoreServiceHour> _serviceHours = [];
  List<GroomerWorkingHour> _groomerHours = [];
  List<StoreHoliday> _holidays = [];
  List<Map<String, dynamic>> _notifications = [];
  final Set<int> _processingBookingIds = {};
  DateTime? _lastGroomerActionTime;
  StreamSubscription<AppNotification>? _realtimeNotificationSub;
  Timer? _timeTickerTimer;
  int _selectedScheduleDayIndex = (DateTime.now().weekday - 1) % 7;
  bool _showFullWeekOverview = true;

  StateSetter? _notificationsSheetSetState;

  @override
  void setState(VoidCallback fn) {
    if (!mounted) return;
    super.setState(fn);
    _notificationsSheetSetState?.call(() {});
  }

  void _recordGroomerAction() {
    _lastGroomerActionTime = DateTime.now();
  }

  static const List<String> _weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialBookings != null) {
      _upcomingBookings = List.from(widget.initialBookings!);
    } else {
      _loadAllData();
    }
    _initRealtimeNotifications();
    _startTimeTicker();
  }

  void _startTimeTicker() {
    _timeTickerTimer?.cancel();
    // Periodically refreshes UI (every 5 seconds) to automatically enable Start Appointment
    // the exact moment scheduled start time is reached, without any manual refresh or API polling.
    _timeTickerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        if (_pendingBookings.isNotEmpty &&
            ServicesLocator.isBookingCancellationManagerRegistered) {
          final hasOverdue = _pendingBookings.any((b) =>
              ServicesLocator.bookingCancellationManager.isScheduledStartTimeReached(
                b.bookingDate,
                b.startTime,
              ));
          if (hasOverdue) {
            _loadAllData();
            return;
          }
        }
        setState(() {});
      }
    });
  }

  void _initRealtimeNotifications() {
    ServicesLocator.groomerHomeRepository.connectRealtimeNotifications();
    _realtimeNotificationSub?.cancel();
    _realtimeNotificationSub = ServicesLocator
        .groomerHomeRepository
        .realtimeNotificationStream
        .listen(_handleIncomingRealtimeNotification);
  }

  void _handleIncomingRealtimeNotification(AppNotification notif) {
    if (!mounted) return;

    final notifMap = <String, dynamic>{
      'id': notif.id,
      'notificationId': notif.id,
      'title': notif.title,
      'body': notif.message,
      'message': notif.message,
      'type': notif.type,
      'isRead': notif.isRead,
      'is_read': notif.isRead,
      'createdAt':
          notif.createdAt?.toIso8601String() ??
          DateTime.now().toIso8601String(),
      if (notif.metadata != null) 'data': notif.metadata,
      if (notif.metadata != null) 'metadata': notif.metadata,
    };

    setState(() {
      final existsIndex = _notifications.indexWhere((item) {
        final existingId = item['id'] ?? item['notificationId'];
        final incomingId = notifMap['id'] ?? notifMap['notificationId'];
        return existingId != null &&
            incomingId != null &&
            existingId.toString() == incomingId.toString();
      });

      if (existsIndex >= 0) {
        _notifications[existsIndex] = notifMap;
      } else {
        _notifications.insert(0, notifMap);
      }
    });

    final type = notif.type.toLowerCase();
    final isBooking =
        type.contains('booking') ||
        type.contains('appointment') ||
        type.contains('cancellation') ||
        (notif.metadata != null &&
            (notif.metadata!.containsKey('bookingId') ||
                notif.metadata!.containsKey('booking_id')));

    if (isBooking) {
      _loadAllData();
    }

    final isLocalDispatch =
        notif.metadata?['isLocalDispatch'] == true ||
        notif.metadata?['isLocal'] == true ||
        notif.metadata?['is_local'] == true;

    final isRecentLocalAction =
        _lastGroomerActionTime != null &&
        DateTime.now().difference(_lastGroomerActionTime!).inMilliseconds <
            2500;

    if (!isLocalDispatch && !isRecentLocalAction) {
      ToastUtil.showInfoToast(
        context,
        notif.title.isNotEmpty ? notif.title : 'New staff notification',
      );
    }
  }

  @override
  void dispose() {
    _realtimeNotificationSub?.cancel();
    _timeTickerTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshProfile() async {
    final cached = ServicesLocator.groomerHomeRepository.getCurrentGroomer();
    if (cached != null && mounted) {
      setState(() {
        _groomer = cached;
      });
    }
    try {
      final latest = await ServicesLocator.groomerHomeRepository.getProfile();
      if (latest != null && mounted) {
        setState(() {
          _groomer = latest;
        });
      }
      if (mounted) {
        try {
          context.read<GroomerHomeBloc>().add(
            const GroomerHomeFetchProfileEvent(),
          );
          context.read<GroomerBloc>().add(const GroomerFetchProfileEvent());
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _loadAllData() async {
    if (widget.initialBookings != null && widget.initialBookings!.isNotEmpty) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _groomer = ServicesLocator.groomerHomeRepository.getCurrentGroomer();
    });

    try {
      final results = await Future.wait([
        ServicesLocator.groomerHomeRepository.getProfile(),
        ServicesLocator.groomerHomeRepository.getUpcomingBookings(),
        ServicesLocator.groomerHomeRepository.getPendingBookings(),
        ServicesLocator.groomerHomeRepository.getPastBookings(),
        ServicesLocator.groomerHomeRepository.getCancelledBookings(),
        ServicesLocator.groomerHomeRepository.getCancellationRequests(),
        ServicesLocator.groomerHomeRepository.getServiceHours(),
        ServicesLocator.groomerHomeRepository.getHolidays(),
        ServicesLocator.groomerHomeRepository.getNotifications(),
        ServicesLocator.groomerHomeRepository.getGroomerHours(),
      ]);

      if (mounted) {
        final fetchedServiceHours = results[6] as List<StoreServiceHour>? ?? [];
        final fetchedNotifications =
            results[8] as List<Map<String, dynamic>>? ?? [];
        final fetchedGroomerHours =
            results[9] as List<GroomerWorkingHour>? ?? [];

        final approvedIds = GroomerHomeRepository.approvedBookingIds;
        final rejectedIds = GroomerHomeRepository.rejectedBookingIds;

        final fetchedPending = (results[2] as List<GroomerBooking>? ?? [])
            .where((b) =>
                !approvedIds.contains(b.bookingId) &&
                !rejectedIds.contains(b.bookingId))
            .toList();

        final mergedNotifications = <Map<String, dynamic>>[];
        for (final item in [..._notifications, ...fetchedNotifications]) {
          final metadata = item['data'] is Map
              ? item['data'] as Map
              : (item['metadata'] is Map ? item['metadata'] as Map : null);
          final rawBookingId = metadata?['bookingId'] ??
              metadata?['booking_id'] ??
              metadata?['entityId'] ??
              item['bookingId'] ??
              item['entityId'];
          final bId = int.tryParse(rawBookingId?.toString() ?? '');
          if (bId != null &&
              (approvedIds.contains(bId) || rejectedIds.contains(bId))) {
            continue;
          }
          final title = (item['title'] ?? '').toString();
          final message = (item['message'] ?? item['body'] ?? '').toString();
          bool matchesExcluded = false;
          for (final excludedId in {...approvedIds, ...rejectedIds}) {
            if (title.contains('#$excludedId') ||
                message.contains('#$excludedId')) {
              matchesExcluded = true;
              break;
            }
          }
          if (matchesExcluded) continue;

          final idStr = (item['id'] ?? item['notificationId'] ?? '')
              .toString()
              .trim();
          if (idStr.isNotEmpty) {
            final existingIdx = mergedNotifications.indexWhere(
              (e) =>
                  (e['id'] ?? e['notificationId'] ?? '').toString().trim() ==
                  idStr,
            );
            if (existingIdx >= 0) {
              final existing = mergedNotifications[existingIdx];
              final isRead =
                  existing['isRead'] == true ||
                  existing['is_read'] == true ||
                  item['isRead'] == true ||
                  item['is_read'] == true;
              mergedNotifications[existingIdx] = <String, dynamic>{
                ...existing,
                ...item,
                'isRead': isRead,
                'is_read': isRead,
              };
              continue;
            }
          }
          mergedNotifications.add(Map<String, dynamic>.from(item));
        }

        setState(() {
          _groomer = results[0] as GroomerUser? ?? _groomer;
          _upcomingBookings = results[1] as List<GroomerBooking>? ?? [];
          _pendingBookings = fetchedPending;
          _pastBookings = results[3] as List<GroomerBooking>? ?? [];
          _cancelledBookings = results[4] as List<GroomerBooking>? ?? [];
          _cancellationRequests = results[5] as List<GroomerBooking>? ?? [];
          _serviceHours = List<StoreServiceHour>.from(fetchedServiceHours);
          _holidays = results[7] as List<StoreHoliday>? ?? [];
          _notifications = mergedNotifications;
          _groomerHours = List<GroomerWorkingHour>.from(fetchedGroomerHours);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load real-time data. Pull to refresh.';
        });
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  String _formatCount(int count) {
    return count < 10 ? '0$count' : '$count';
  }

  List<GroomerBooking> get _combinedBookings {
    final map = <int, GroomerBooking>{};
    for (final b in _upcomingBookings) {
      map[b.bookingId] = b;
    }
    for (final b in _pendingBookings) {
      map[b.bookingId] = b;
    }
    for (final b in _cancellationRequests) {
      map[b.bookingId] = b;
    }
    for (final b in _pastBookings) {
      map[b.bookingId] = b;
    }
    for (final b in _cancelledBookings) {
      map[b.bookingId] = b;
    }
    return map.values.toList();
  }

  List<GroomerBooking> get _bookingsForSelectedDate {
    final filtered = _combinedBookings
        .where(
          (b) =>
              BookingDateUtils.isSameCalendarDay(b.bookingDate, _selectedDate),
        )
        .toList();
    filtered.sort((a, b) {
      final ta = BookingDateUtils.timeToMinutes(a.startTime) ?? 0;
      final tb = BookingDateUtils.timeToMinutes(b.startTime) ?? 0;
      return ta.compareTo(tb);
    });
    return filtered;
  }

  int get _todayTotalBookings {
    return _combinedBookings
        .where((b) => BookingDateUtils.isToday(b.bookingDate))
        .length;
  }

  int get _todayPendingBookings {
    return _combinedBookings
        .where(
          (b) =>
              BookingDateUtils.isToday(b.bookingDate) &&
              b.status.toLowerCase() == 'pending',
        )
        .length;
  }

  int get _todayConfirmedBookings {
    return _combinedBookings
        .where(
          (b) =>
              BookingDateUtils.isToday(b.bookingDate) &&
              (b.status.toLowerCase() == 'confirmed' ||
                  b.status.toLowerCase() == 'in_progress'),
        )
        .length;
  }

  int get _todayCompletedBookings {
    return _combinedBookings
        .where(
          (b) =>
              BookingDateUtils.isToday(b.bookingDate) &&
              (b.status.toLowerCase() == 'completed' ||
                  b.status.toLowerCase() == 'past'),
        )
        .length;
  }

  bool _isStartTimeReached(GroomerBooking booking) {
    if (booking.bookingDate.isEmpty || booking.startTime.isEmpty) {
      return false;
    }
    try {
      final parsedDate = BookingDateUtils.parseCalendarDate(
        booking.bookingDate,
      );
      if (parsedDate == null) return false;

      // Appointment date MUST be today — previous and future dates are not startable
      if (!BookingDateUtils.isToday(parsedDate)) {
        return false;
      }

      final now = DateTime.now();
      final cleanTime = booking.startTime.trim().toUpperCase();
      int hour = 0;
      int minute = 0;

      if (cleanTime.contains('AM') || cleanTime.contains('PM')) {
        try {
          final t = DateFormat('h:mm a').parse(cleanTime);
          hour = t.hour;
          minute = t.minute;
        } catch (_) {
          try {
            final t = DateFormat('hh:mm a').parse(cleanTime);
            hour = t.hour;
            minute = t.minute;
          } catch (_) {}
        }
      } else {
        final timeParts = cleanTime.split(':');
        if (timeParts.isNotEmpty) {
          hour = int.tryParse(timeParts[0]) ?? 0;
          minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
        }
      }

      final scheduledStart = DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      return now.isAfter(scheduledStart) ||
          now.isAtSameMomentAs(scheduledStart);
    } catch (_) {
      return false;
    }
  }

  String _formatBookingDateDisplay(DateTime date) =>
      BookingDateUtils.formatBookingDateDisplay(date);

  String _getScheduledStatusText(GroomerBooking booking) {
    if (booking.bookingDate.isEmpty) {
      return 'Starts at ${booking.startTime}';
    }
    try {
      final bookingDay = BookingDateUtils.parseCalendarDate(
        booking.bookingDate,
      );
      if (bookingDay == null) return 'Starts at ${booking.startTime}';

      final today = BookingDateUtils.normalize(DateTime.now());

      if (bookingDay.isBefore(today)) {
        return 'Scheduled for ${DateFormat('d MMM yyyy').format(bookingDay)} (${booking.startTime})';
      } else if (bookingDay.isAfter(today)) {
        return 'Starts on ${DateFormat('d MMM yyyy').format(bookingDay)}, ${booking.startTime}';
      } else {
        return 'Starts at ${booking.startTime}';
      }
    } catch (_) {
      return 'Starts at ${booking.startTime}';
    }
  }

  Future<void> _handleApproveBooking(GroomerBooking booking) async {
    if (_processingBookingIds.contains(booking.bookingId)) return;
    setState(() => _processingBookingIds.add(booking.bookingId));
    try {
      final res = await ServicesLocator.groomerHomeRepository
          .approveBookingDetails(booking.bookingId, booking: booking);
      if (!mounted) return;
      if (res.success) {
        _recordGroomerAction();
        ToastUtil.showSuccessToast(context, res.message);
        setState(() {
          // Immediately remove the approved appointment from pending bookings so it disappears from notifications
          _pendingBookings.removeWhere((b) => b.bookingId == booking.bookingId);

          // Also remove any notification referencing this booking from _notifications
          _notifications.removeWhere((n) {
            final metadata = n['data'] is Map ? n['data'] as Map : (n['metadata'] is Map ? n['metadata'] as Map : null);
            final rawBookingId = metadata?['bookingId'] ??
                metadata?['booking_id'] ??
                metadata?['entityId'] ??
                n['bookingId'] ??
                n['entityId'];
            final bId = int.tryParse(rawBookingId?.toString() ?? '');
            if (bId == booking.bookingId) return true;
            final title = (n['title'] ?? '').toString();
            final message = (n['message'] ?? n['body'] ?? '').toString();
            return title.contains('#${booking.bookingId}') || message.contains('#${booking.bookingId}');
          });

          // Move/update booking in upcoming bookings list as confirmed
          final updated = booking.copyWith(status: 'confirmed');
          final upIdx = _upcomingBookings.indexWhere((b) => b.bookingId == booking.bookingId);
          if (upIdx >= 0) {
            _upcomingBookings[upIdx] = updated;
          } else {
            _upcomingBookings.insert(0, updated);
          }
        });
        _notificationsSheetSetState?.call(() {});
      } else {
        final lower = res.message.toLowerCase();
        if (lower.contains('502') || lower.contains('gateway') || lower.contains('bad gateway')) {
          _recordGroomerAction();
          ToastUtil.showSuccessToast(context, 'Booking #${booking.bookingId} approved successfully');
          setState(() {
            _pendingBookings.removeWhere((b) => b.bookingId == booking.bookingId);
            _notifications.removeWhere((n) {
              final metadata = n['data'] is Map ? n['data'] as Map : (n['metadata'] is Map ? n['metadata'] as Map : null);
              final rawBookingId = metadata?['bookingId'] ??
                  metadata?['booking_id'] ??
                  metadata?['entityId'] ??
                  n['bookingId'] ??
                  n['entityId'];
              final bId = int.tryParse(rawBookingId?.toString() ?? '');
              if (bId == booking.bookingId) return true;
              final title = (n['title'] ?? '').toString();
              final message = (n['message'] ?? n['body'] ?? '').toString();
              return title.contains('#${booking.bookingId}') || message.contains('#${booking.bookingId}');
            });
            final updated = booking.copyWith(status: 'confirmed');
            final upIdx = _upcomingBookings.indexWhere((b) => b.bookingId == booking.bookingId);
            if (upIdx >= 0) {
              _upcomingBookings[upIdx] = updated;
            } else {
              _upcomingBookings.insert(0, updated);
            }
          });
          _notificationsSheetSetState?.call(() {});
        } else {
          ToastUtil.showErrorToast(context, res.message);
        }
      }
      await _loadAllData();
    } finally {
      if (mounted) {
        setState(() => _processingBookingIds.remove(booking.bookingId));
      }
    }
  }

  Future<void> _handleStartBooking(GroomerBooking booking) async {
    // Show confirmation dialog before calling API
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Start Appointment?',
          style: AppFonts.parkinsans(
            size: 18,
            weight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
        content: Text(
          'Are you sure you want to start this appointment?',
          style: AppFonts.poppins(size: 14, color: const Color(0xFF4B5563)),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'No',
              style: AppFonts.poppins(
                size: 14,
                weight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111827),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Yes, Start',
              style: AppFonts.poppins(
                size: 14,
                weight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    if (_processingBookingIds.contains(booking.bookingId)) {
      return;
    }

    setState(() {
      _processingBookingIds.add(booking.bookingId);
      // Optimistic local update: immediately set status to 'in_progress'
      final updated = booking.copyWith(status: 'in_progress');
      final upcomingIndex = _upcomingBookings.indexWhere(
        (b) => b.bookingId == booking.bookingId,
      );
      if (upcomingIndex >= 0) {
        _upcomingBookings[upcomingIndex] = updated;
      }
    });

    try {
      final res = await ServicesLocator.groomerHomeRepository
          .startBookingDetails(booking.bookingId);
      if (!mounted) return;
      if (res.success) {
        _recordGroomerAction();
        ToastUtil.showSuccessToast(context, res.message);
        _loadAllData();
      } else {
        // Revert optimistic update on failure
        setState(() {
          final reverted = booking.copyWith(status: 'confirmed');
          final upcomingIndex = _upcomingBookings.indexWhere(
            (b) => b.bookingId == booking.bookingId,
          );
          if (upcomingIndex >= 0) {
            _upcomingBookings[upcomingIndex] = reverted;
          }
        });
        ToastUtil.showErrorToast(context, res.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final reverted = booking.copyWith(status: 'confirmed');
          final upcomingIndex = _upcomingBookings.indexWhere(
            (b) => b.bookingId == booking.bookingId,
          );
          if (upcomingIndex >= 0) {
            _upcomingBookings[upcomingIndex] = reverted;
          }
        });
        ToastUtil.showErrorToast(context, 'Error starting appointment: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingBookingIds.remove(booking.bookingId);
        });
      }
    }
  }

  Future<void> _handleCheckInBooking(GroomerBooking booking) async {
    if (!booking.isCheckedIn && !booking.canCheckIn()) {
      if (booking.isBeforeScheduledDate()) {
        ToastUtil.showErrorToast(
          context,
          'Check-in is only allowed on the scheduled booking date (${booking.formattedBookingDate}).',
        );
      } else if (booking.isAfterScheduledDate()) {
        ToastUtil.showErrorToast(
          context,
          'Check-in is closed because the scheduled booking date (${booking.formattedBookingDate}) has passed.',
        );
      } else {
        ToastUtil.showErrorToast(
          context,
          'Check-in is only allowed on the scheduled booking date.',
        );
      }
      return;
    }
    if (_processingBookingIds.contains(booking.bookingId)) return;
    setState(() => _processingBookingIds.add(booking.bookingId));
    try {
      final updated = await GroomerCheckInDialog.show(
        context,
        booking: booking,
        onCheckInSuccess: (updatedBooking) {
          if (!mounted) return;
          _recordGroomerAction();
          setState(() {
            final upcomingIndex = _upcomingBookings.indexWhere(
              (b) => b.bookingId == updatedBooking.bookingId,
            );
            if (upcomingIndex >= 0) {
              _upcomingBookings[upcomingIndex] = updatedBooking;
            }
          });
        },
      );
      if (updated != null && mounted) {
        _recordGroomerAction();
        _loadAllData();
      }
    } finally {
      if (mounted) {
        setState(() => _processingBookingIds.remove(booking.bookingId));
      }
    }
  }

  String _formatCheckInTimestamp(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('h:mm a').format(dt.toLocal());
    } catch (_) {
      return raw;
    }
  }

  Future<void> _handleMilestoneBooking(
    GroomerBooking booking,
    MilestoneType milestoneType,
  ) async {
    if (_processingBookingIds.contains(booking.bookingId)) return;
    setState(() => _processingBookingIds.add(booking.bookingId));
    try {
      final updated = await GroomerMilestoneDialog.show(
        context,
        booking: booking,
        milestoneType: milestoneType,
        onMilestoneSuccess: (updatedBooking) {
          if (!mounted) return;
          _recordGroomerAction();
          setState(() {
            final upcomingIndex = _upcomingBookings.indexWhere(
              (b) => b.bookingId == updatedBooking.bookingId,
            );
            if (upcomingIndex >= 0) {
              _upcomingBookings[upcomingIndex] = updatedBooking;
            }
          });
        },
      );
      if (updated != null && mounted) {
        _recordGroomerAction();
        _loadAllData();
      }
    } finally {
      if (mounted) {
        setState(() => _processingBookingIds.remove(booking.bookingId));
      }
    }
  }

  bool _isBookingDateToday(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return false;
    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      if (dateStr.startsWith(todayStr)) return true;
      final dt = DateTime.parse(dateStr);
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    } catch (_) {
      return false;
    }
  }

  ({bool show, bool locked, String label, String tooltip}) _getWebMilestoneButtonInfo(GroomerBooking booking) {
    final st = booking.status.toLowerCase().trim();
    final isToday = _isBookingDateToday(booking.bookingDate);
    final isRelevant = st == 'confirmed' ||
        st == 'in_progress' ||
        st == 'in-progress' ||
        st == 'completed' ||
        booking.isCompleted ||
        st == 'checked_in' ||
        st == 'bath_completed' ||
        st == 'grooming_completed' ||
        st == 'ready_for_checkout';

    if (!isRelevant) {
      return (show: false, locked: false, label: '', tooltip: '');
    }

    if (isToday) {
      if (booking.isCompleted || st == 'completed') {
        return (show: true, locked: false, label: 'View milestones', tooltip: '');
      } else {
        return (show: true, locked: false, label: 'Update milestone', tooltip: '');
      }
    } else {
      if (booking.isCompleted || st == 'completed') {
        return (show: true, locked: false, label: 'View milestones', tooltip: '');
      } else if (st == 'confirmed' || st == 'in_progress' || st == 'in-progress' || st == 'checked_in') {
        return (
          show: true,
          locked: true,
          label: 'Check-in locked',
          tooltip: 'Milestones unlock on the appointment date (${booking.bookingDate}).',
        );
      }
      return (show: false, locked: false, label: '', tooltip: '');
    }
  }

  Widget _buildWebMilestoneButton(GroomerBooking booking) {
    final info = _getWebMilestoneButtonInfo(booking);
    if (!info.show) return const SizedBox.shrink();

    if (info.locked) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF9CA3AF),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          backgroundColor: const Color(0xFFF9FAFB),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          minimumSize: const Size(0, 36),
        ),
        onPressed: () {
          if (info.tooltip.isNotEmpty) {
            ToastUtil.showInfoToast(context, info.tooltip);
          }
        },
        icon: const Icon(Icons.lock_outline_rounded, size: 15, color: Color(0xFF9CA3AF)),
        label: Text(
          info.label,
          style: AppFonts.poppins(size: 11.5, weight: FontWeight.w600, color: const Color(0xFF9CA3AF)),
        ),
      );
    }

    final theme = Theme.of(context);
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        minimumSize: const Size(0, 36),
      ),
      onPressed: _processingBookingIds.contains(booking.bookingId)
          ? null
          : () async {
              final updated = await GroomerMilestoneDialog.show(
                context,
                booking: booking,
                onMilestoneSuccess: (ub) {
                  if (!mounted) return;
                  _recordGroomerAction();
                  setState(() {
                    final idx = _upcomingBookings.indexWhere((b) => b.bookingId == ub.bookingId);
                    if (idx >= 0) _upcomingBookings[idx] = ub;
                  });
                },
              );
              if (updated != null && mounted) {
                _recordGroomerAction();
                _loadAllData();
              }
            },
      icon: Icon(Icons.sync_rounded, size: 15, color: theme.colorScheme.onPrimary),
      label: Text(
        info.label,
        style: AppFonts.parkinsans(size: 11.5, weight: FontWeight.w600, color: theme.colorScheme.onPrimary),
      ),
    );
  }

  Future<void> _handleReadyForCheckoutBooking(GroomerBooking booking) async {
    if (_processingBookingIds.contains(booking.bookingId)) return;
    setState(() => _processingBookingIds.add(booking.bookingId));

    try {
      final res = await ServicesLocator.groomerHomeRepository
          .markReadyForCheckoutDetails(
            bookingId: booking.bookingId,
            booking: booking,
          );

      if (!mounted) return;

      if (res.success) {
        _recordGroomerAction();
        ToastUtil.showSuccessToast(context, res.message);
        final updated =
            res.updatedBooking ??
            booking.copyWith(status: 'ready_for_checkout');
        setState(() {
          final idx = _upcomingBookings.indexWhere(
            (b) => b.bookingId == updated.bookingId,
          );
          if (idx >= 0) {
            _upcomingBookings[idx] = updated;
          }
        });
        _loadAllData();
      } else {
        ToastUtil.showErrorToast(context, res.message);
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.showErrorToast(
          context,
          'Failed to mark ready for checkout: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingBookingIds.remove(booking.bookingId));
      }
    }
  }

  Future<void> _handleSkipBooking(
    GroomerBooking booking, {
    bool showConfirmation = false,
  }) async {
    if (_processingBookingIds.contains(booking.bookingId)) return;

    if (showConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.fast_forward_rounded,
                color: Color(0xFFD97706),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Skip Milestones?',
                style: AppFonts.poppins(
                  size: 16,
                  weight: FontWeight.w600,
                  color: const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          content: Text(
            'Skip intermediate service milestones and mark booking #${booking.bookingId} (${booking.petName}) ready for checkout?',
            style: AppFonts.poppins(size: 13, color: const Color(0xFF4B5563)),
          ),
          actions: [
            TextButton(
              key: const Key('appointment_skip_cancel_button'),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: AppFonts.poppins(
                  size: 13,
                  weight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ),
            ElevatedButton(
              key: const Key('appointment_skip_confirm_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Skip & Ready',
                style: AppFonts.poppins(
                  size: 13,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;
    setState(() => _processingBookingIds.add(booking.bookingId));

    try {
      final res = await ServicesLocator.groomerHomeRepository
          .markReadyForCheckoutDetails(
            bookingId: booking.bookingId,
            booking: booking,
            skipMilestones: true,
          );

      if (!mounted) return;

      if (res.success) {
        _recordGroomerAction();
        ToastUtil.showSuccessToast(context, res.message);
        final updated =
            res.updatedBooking ??
            booking.copyWith(status: 'ready_for_checkout');
        setState(() {
          final idx = _upcomingBookings.indexWhere(
            (b) => b.bookingId == updated.bookingId,
          );
          if (idx >= 0) {
            _upcomingBookings[idx] = updated;
          }
        });
        _loadAllData();
      } else {
        ToastUtil.showErrorToast(context, res.message);
        _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.showErrorToast(context, 'Failed to skip milestones: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _processingBookingIds.remove(booking.bookingId));
      }
    }
  }

  Widget _buildSkipButton(GroomerBooking booking) {
    final isProcessing = _processingBookingIds.contains(booking.bookingId);
    return OutlinedButton.icon(
      key: Key('appointment_skip_button_${booking.bookingId}'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFD97706),
        backgroundColor: const Color(0xFFFFFBEB),
        side: const BorderSide(color: Color(0xFFFCD34D), width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: isProcessing ? null : () => _handleSkipBooking(booking),
      icon: isProcessing
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: Color(0xFFD97706),
              ),
            )
          : const Icon(
              Icons.fast_forward_rounded,
              size: 14,
              color: Color(0xFFD97706),
            ),
      label: Text(
        isProcessing ? 'Skipping...' : 'Skip',
        style: AppFonts.poppins(
          size: 11.5,
          weight: FontWeight.w600,
          color: const Color(0xFFD97706),
        ),
      ),
    );
  }

  String _formatMilestoneTimestamp(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('h:mm a').format(dt.toLocal());
    } catch (_) {
      return raw;
    }
  }

  Future<void> _handleCompleteBooking(GroomerBooking booking) async {
    if (_processingBookingIds.contains(booking.bookingId)) return;
    setState(() => _processingBookingIds.add(booking.bookingId));

    try {
      final updated = await GroomerFinalCheckoutDialog.show(
        context,
        booking: booking,
        onCheckoutSuccess: (updatedBooking) {
          _recordGroomerAction();
          setState(() {
            _upcomingBookings.removeWhere(
              (b) => b.bookingId == booking.bookingId,
            );
            final pastIndex = _pastBookings.indexWhere(
              (b) => b.bookingId == booking.bookingId,
            );
            if (pastIndex >= 0) {
              _pastBookings[pastIndex] = updatedBooking;
            } else {
              _pastBookings.insert(0, updatedBooking);
            }
          });
          _loadAllData();
        },
      );

      if (updated != null && mounted) {
        _recordGroomerAction();
        setState(() {
          _upcomingBookings.removeWhere(
            (b) => b.bookingId == booking.bookingId,
          );
          final pastIndex = _pastBookings.indexWhere(
            (b) => b.bookingId == booking.bookingId,
          );
          if (pastIndex >= 0) {
            _pastBookings[pastIndex] = updated;
          } else {
            _pastBookings.insert(0, updated);
          }
        });
        _loadAllData();
      }
    } finally {
      if (mounted) {
        setState(() => _processingBookingIds.remove(booking.bookingId));
      }
    }
  }

  Future<void> _handleRejectBooking(GroomerBooking booking) async {
    if (_processingBookingIds.contains(booking.bookingId)) return;
    setState(() => _processingBookingIds.add(booking.bookingId));
    try {
      final res = await ServicesLocator.groomerHomeRepository
          .rejectBookingDetails(booking.bookingId);
      if (!mounted) return;
      if (res.success) {
        _recordGroomerAction();
        ToastUtil.showSuccessToast(context, res.message);
        setState(() {
          _pendingBookings.removeWhere((b) => b.bookingId == booking.bookingId);

          _notifications.removeWhere((n) {
            final metadata = n['data'] is Map ? n['data'] as Map : (n['metadata'] is Map ? n['metadata'] as Map : null);
            final rawBookingId = metadata?['bookingId'] ??
                metadata?['booking_id'] ??
                metadata?['entityId'] ??
                n['bookingId'] ??
                n['entityId'];
            final bId = int.tryParse(rawBookingId?.toString() ?? '');
            if (bId == booking.bookingId) return true;
            final title = (n['title'] ?? '').toString();
            final message = (n['message'] ?? n['body'] ?? '').toString();
            return title.contains('#${booking.bookingId}') || message.contains('#${booking.bookingId}');
          });

          final updated = booking.copyWith(status: 'cancelled');
          final pastIdx = _pastBookings.indexWhere((b) => b.bookingId == booking.bookingId);
          if (pastIdx >= 0) {
            _pastBookings[pastIdx] = updated;
          } else {
            _pastBookings.insert(0, updated);
          }
        });
        _notificationsSheetSetState?.call(() {});
      } else {
        final lower = res.message.toLowerCase();
        if (lower.contains('502') || lower.contains('gateway') || lower.contains('bad gateway')) {
          _recordGroomerAction();
          ToastUtil.showSuccessToast(context, 'Booking #${booking.bookingId} rejected');
          setState(() {
            _pendingBookings.removeWhere((b) => b.bookingId == booking.bookingId);
            _notifications.removeWhere((n) {
              final metadata = n['data'] is Map ? n['data'] as Map : (n['metadata'] is Map ? n['metadata'] as Map : null);
              final rawBookingId = metadata?['bookingId'] ??
                  metadata?['booking_id'] ??
                  metadata?['entityId'] ??
                  n['bookingId'] ??
                  n['entityId'];
              final bId = int.tryParse(rawBookingId?.toString() ?? '');
              if (bId == booking.bookingId) return true;
              final title = (n['title'] ?? '').toString();
              final message = (n['message'] ?? n['body'] ?? '').toString();
              return title.contains('#${booking.bookingId}') || message.contains('#${booking.bookingId}');
            });
            final updated = booking.copyWith(status: 'cancelled');
            final pastIdx = _pastBookings.indexWhere((b) => b.bookingId == booking.bookingId);
            if (pastIdx >= 0) {
              _pastBookings[pastIdx] = updated;
            } else {
              _pastBookings.insert(0, updated);
            }
          });
          _notificationsSheetSetState?.call(() {});
        } else {
          ToastUtil.showErrorToast(context, res.message);
        }
      }
      await _loadAllData();
    } finally {
      if (mounted) {
        setState(() => _processingBookingIds.remove(booking.bookingId));
      }
    }
  }

  Future<void> _handleApproveCancellation(GroomerBooking booking) async {
    if (_processingBookingIds.contains(booking.bookingId)) return;
    setState(() => _processingBookingIds.add(booking.bookingId));
    try {
      final res = await ServicesLocator.groomerHomeRepository
          .approveCancellationDetails(booking.bookingId);
      if (!mounted) return;
      if (res.success) {
        _recordGroomerAction();
        ToastUtil.showSuccessToast(context, res.message);
        setState(() {
          _cancellationRequests.removeWhere((b) => b.bookingId == booking.bookingId);
          _upcomingBookings.removeWhere((b) => b.bookingId == booking.bookingId);

          _notifications.removeWhere((n) {
            final metadata = n['data'] is Map ? n['data'] as Map : (n['metadata'] is Map ? n['metadata'] as Map : null);
            final rawBookingId = metadata?['bookingId'] ??
                metadata?['booking_id'] ??
                metadata?['entityId'] ??
                n['bookingId'] ??
                n['entityId'];
            final bId = int.tryParse(rawBookingId?.toString() ?? '');
            if (bId == booking.bookingId) return true;
            final title = (n['title'] ?? '').toString();
            final message = (n['message'] ?? n['body'] ?? '').toString();
            return title.contains('#${booking.bookingId}') || message.contains('#${booking.bookingId}');
          });

          final updated = booking.copyWith(status: 'cancelled');
          final pastIdx = _pastBookings.indexWhere((b) => b.bookingId == booking.bookingId);
          if (pastIdx >= 0) {
            _pastBookings[pastIdx] = updated;
          } else {
            _pastBookings.insert(0, updated);
          }
        });
      } else {
        ToastUtil.showErrorToast(context, res.message);
      }
      await _loadAllData();
    } finally {
      if (mounted) {
        setState(() => _processingBookingIds.remove(booking.bookingId));
      }
    }
  }

  Future<void> _handleRejectCancellation(GroomerBooking booking) async {
    if (_processingBookingIds.contains(booking.bookingId)) return;
    setState(() => _processingBookingIds.add(booking.bookingId));
    try {
      final res = await ServicesLocator.groomerHomeRepository
          .rejectCancellationDetails(booking.bookingId);
      if (!mounted) return;
      if (res.success) {
        _recordGroomerAction();
        ToastUtil.showSuccessToast(context, res.message);
        setState(() {
          _cancellationRequests.removeWhere((b) => b.bookingId == booking.bookingId);

          _notifications.removeWhere((n) {
            final metadata = n['data'] is Map ? n['data'] as Map : (n['metadata'] is Map ? n['metadata'] as Map : null);
            final rawBookingId = metadata?['bookingId'] ??
                metadata?['booking_id'] ??
                metadata?['entityId'] ??
                n['bookingId'] ??
                n['entityId'];
            final bId = int.tryParse(rawBookingId?.toString() ?? '');
            if (bId == booking.bookingId) return true;
            final title = (n['title'] ?? '').toString();
            final message = (n['message'] ?? n['body'] ?? '').toString();
            return title.contains('#${booking.bookingId}') || message.contains('#${booking.bookingId}');
          });
        });
      } else {
        ToastUtil.showErrorToast(context, res.message);
      }
      await _loadAllData();
    } finally {
      if (mounted) {
        setState(() => _processingBookingIds.remove(booking.bookingId));
      }
    }
  }

  Future<void> _handleMarkNotificationRead(int id) async {
    final ok = await ServicesLocator.groomerHomeRepository.markNotificationRead(
      id,
    );
    if (ok && mounted) {
      setState(() {
        for (var i = 0; i < _notifications.length; i++) {
          if (_notifications[i]['id'] == id ||
              _notifications[i]['notificationId'] == id) {
            _notifications[i]['isRead'] = true;
            _notifications[i]['is_read'] = true;
          }
        }
      });
    }
  }

  Future<void> _handleMarkAllNotificationsRead() async {
    final ok = await ServicesLocator.groomerHomeRepository
        .markAllNotificationsRead();
    if (ok && mounted) {
      setState(() {
        for (var i = 0; i < _notifications.length; i++) {
          _notifications[i]['isRead'] = true;
          _notifications[i]['is_read'] = true;
        }
      });
      ToastUtil.showSuccessToast(context, 'All notifications marked as read');
    } else if (mounted) {
      ToastUtil.showErrorToast(context, 'Failed to mark notifications as read');
    }
  }

  Widget _buildThemedEditField({
    required String label,
    required TextEditingController controller,
    bool isRequired = false,
    String? hintText,
    String? errorText,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: AppFonts.poppins(
              size: 12.5,
              weight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
            children: isRequired
                ? [
                    TextSpan(
                      text: ' *',
                      style: AppFonts.poppins(
                        size: 12.5,
                        weight: FontWeight.w600,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ]
                : const [],
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          onChanged: onChanged,
          style: AppFonts.poppins(
            size: 13.5,
            weight: FontWeight.w500,
            color: const Color(0xFF111827),
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppFonts.poppins(
              size: 13,
              color: const Color(0xFF9CA3AF),
            ),
            errorText: errorText,
            errorStyle: AppFonts.poppins(
              size: 11.5,
              color: const Color(0xFFDC2626),
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFF111827),
                width: 1.4,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDC2626)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: Color(0xFFDC2626),
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroomerAvatar({required double size, String? avatarPath}) {
    final resolvedPath = (avatarPath ?? _groomer?.avatarUrl ?? '').trim();
    Widget imageWidget;

    if (resolvedPath.startsWith('http://') ||
        resolvedPath.startsWith('https://')) {
      imageWidget = Image.network(
        resolvedPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Image.asset(
          'assets/images/common/avatar.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    } else if (resolvedPath.isNotEmpty && File(resolvedPath).existsSync()) {
      imageWidget = Image.file(
        File(resolvedPath),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Image.asset(
          'assets/images/common/avatar.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    } else {
      imageWidget = Image.asset(
        'assets/images/common/avatar.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF3F4F6),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
      ),
      child: ClipOval(child: imageWidget),
    );
  }

  Future<void> _handleEditProfileDialog() async {
    final groomer =
        ServicesLocator.groomerHomeRepository.getCurrentGroomer() ?? _groomer;
    if (groomer == null) return;

    final firstCtrl = TextEditingController(text: groomer.firstName);
    final lastCtrl = TextEditingController(text: groomer.lastName);
    final initialMobileDigits = UsPhoneInputFormatter.cleanDigits(
      groomer.mobile,
    );
    final initialFormattedMobile = initialMobileDigits.isNotEmpty
        ? UsPhoneInputFormatter.formatDigits(initialMobileDigits)
        : groomer.mobile.trim();
    final mobileCtrl = TextEditingController(text: initialFormattedMobile);
    final highlightsCtrl = TextEditingController(text: groomer.highlights);

    bool multiBooking = groomer.multiBookingEnabled;
    int slotLimit = groomer.slotBookingLimit.clamp(1, 5);
    bool isSaving = false;
    String? dialogError;
    String? firstNameError;
    String? lastNameError;
    String? mobileError;

    final updatedGroomer = await showDialog<GroomerUser>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> submitProfileUpdate() async {
            if (isSaving) return;

            final trimmedFirst = firstCtrl.text.trim();
            final trimmedLast = lastCtrl.text.trim();
            final rawMobile = mobileCtrl.text.trim();
            final mobileDigits = UsPhoneInputFormatter.cleanDigits(rawMobile);
            final trimmedHighlights = highlightsCtrl.text.trim();

            String? fErr;
            String? lErr;
            String? mErr;

            if (trimmedFirst.isEmpty) {
              fErr = 'First name is required';
            }
            if (trimmedLast.isEmpty) {
              lErr = 'Last name is required';
            }
            if (rawMobile.isNotEmpty && mobileDigits.length != 10) {
              mErr = 'Enter a valid 10-digit US phone number';
            }

            if (fErr != null || lErr != null || mErr != null) {
              setDialogState(() {
                firstNameError = fErr;
                lastNameError = lErr;
                mobileError = mErr;
                dialogError =
                    'Please fix the highlighted fields before saving.';
              });
              return;
            }

            final formattedMobile = mobileDigits.length == 10
                ? UsPhoneInputFormatter.formatDigits(mobileDigits)
                : '';

            setDialogState(() {
              isSaving = true;
              dialogError = null;
              firstNameError = null;
              lastNameError = null;
              mobileError = null;
            });

            try {
              final result = await ServicesLocator.groomerHomeRepository
                  .updateProfile(
                    firstName: trimmedFirst,
                    lastName: trimmedLast,
                    mobile: formattedMobile,
                    highlights: trimmedHighlights,
                    multiBookingEnabled: multiBooking,
                    slotBookingLimit: multiBooking ? slotLimit : 1,
                  );

              if (result == null) {
                throw Exception(
                  'Failed to save profile changes. Please try again.',
                );
              }

              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(result);
              }
            } catch (e) {
              final cleanMsg = e.toString().replaceAll('Exception:', '').trim();
              setDialogState(() {
                isSaving = false;
                dialogError = cleanMsg.isNotEmpty
                    ? cleanMsg
                    : 'Unable to update profile. Please try again.';
              });
            }
          }

          return Dialog(
            backgroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Modal Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Groomer Profile',
                                style: AppFonts.parkinsans(
                                  size: 18,
                                  weight: FontWeight.w700,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Update your personal details & booking capacity',
                                style: AppFonts.poppins(
                                  size: 12,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: isSaving
                              ? null
                              : () => Navigator.of(dialogContext).pop(),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF3F4F6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Validation / API Error Banner
                    if (dialogError != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 18,
                              color: Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dialogError!,
                                style: AppFonts.poppins(
                                  size: 12,
                                  weight: FontWeight.w500,
                                  color: const Color(0xFFDC2626),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // First & Last Name Fields
                    _buildThemedEditField(
                      label: 'First Name',
                      controller: firstCtrl,
                      isRequired: true,
                      hintText: 'Enter first name',
                      errorText: firstNameError,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) {
                        if (firstNameError != null || dialogError != null) {
                          setDialogState(() {
                            firstNameError = null;
                            dialogError = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildThemedEditField(
                      label: 'Last Name',
                      controller: lastCtrl,
                      isRequired: true,
                      hintText: 'Enter last name',
                      errorText: lastNameError,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) {
                        if (lastNameError != null || dialogError != null) {
                          setDialogState(() {
                            lastNameError = null;
                            dialogError = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Mobile Number Field with US Formatter
                    _buildThemedEditField(
                      label: 'Phone Number',
                      controller: mobileCtrl,
                      hintText: '+1 (555) 000-0000',
                      errorText: mobileError,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [UsPhoneInputFormatter()],
                      onChanged: (_) {
                        if (mobileError != null || dialogError != null) {
                          setDialogState(() {
                            mobileError = null;
                            dialogError = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Bio / Highlights Field
                    _buildThemedEditField(
                      label: 'Bio / Highlights',
                      controller: highlightsCtrl,
                      hintText: 'e.g., Lead Groomer • Master Stylist',
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),

                    // Multi-Booking & Capacity Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Multi-Booking Mode',
                                      style: AppFonts.poppins(
                                        size: 13.5,
                                        weight: FontWeight.w600,
                                        color: const Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Allow multiple pets per time slot',
                                      style: AppFonts.poppins(
                                        size: 11.5,
                                        color: const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: multiBooking,
                                activeTrackColor: const Color(0xFF111827),
                                activeThumbColor: Colors.white,
                                onChanged: isSaving
                                    ? null
                                    : (val) {
                                        setDialogState(() {
                                          multiBooking = val;
                                          if (multiBooking && slotLimit < 2) {
                                            slotLimit =
                                                groomer.slotBookingLimit > 1
                                                ? groomer.slotBookingLimit
                                                      .clamp(1, 5)
                                                : 2;
                                          }
                                        });
                                      },
                              ),
                            ],
                          ),
                          if (multiBooking) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(
                                height: 1,
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                            Text(
                              'Simultaneous Slot Limit (Pets / Slot)',
                              style: AppFonts.poppins(
                                size: 12,
                                weight: FontWeight.w600,
                                color: const Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [1, 2, 3, 4, 5].map((count) {
                                final isSelected = slotLimit == count;
                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: count == 5 ? 0 : 6,
                                    ),
                                    child: GestureDetector(
                                      onTap: isSaving
                                          ? null
                                          : () {
                                              setDialogState(() {
                                                slotLimit = count;
                                              });
                                            },
                                      child: Container(
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFF111827)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xFF111827)
                                                : const Color(0xFFD1D5DB),
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$count',
                                          style: AppFonts.poppins(
                                            size: 13,
                                            weight: FontWeight.w600,
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFF374151),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: TextButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF111827),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  side: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                    width: 1.2,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: AppFonts.poppins(
                                  size: 14,
                                  weight: FontWeight.w500,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF111827),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(
                                  0xFF111827,
                                ).withValues(alpha: 0.6),
                                elevation: 0,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: isSaving ? null : submitProfileUpdate,
                              child: isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Save Changes',
                                      style: AppFonts.parkinsans(
                                        size: 14,
                                        weight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (updatedGroomer != null && mounted) {
      setState(() {
        _groomer = updatedGroomer;
      });
      try {
        context.read<GroomerHomeBloc>().add(
          const GroomerHomeFetchProfileEvent(),
        );
        context.read<GroomerBloc>().add(const GroomerFetchProfileEvent());
      } catch (_) {}
      ToastUtil.showSuccessToast(
        context,
        'Groomer profile updated successfully',
      );
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Staff Logout',
                style: AppFonts.parkinsans(size: 18, weight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to log out of the Groomer Portal?',
                style: AppFonts.poppins(
                  size: 14,
                  color: const Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                            side: const BorderSide(
                              color: Color(0xFFE5E7EB),
                              width: 1.2,
                            ),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppFonts.poppins(
                            size: 14,
                            weight: FontWeight.w500,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF111827),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(
                          'Logout',
                          style: AppFonts.parkinsans(
                            size: 14,
                            weight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldLogout == true) {
      _realtimeNotificationSub?.cancel();
      _realtimeNotificationSub = null;
      _timeTickerTimer?.cancel();
      _timeTickerTimer = null;

      await ServicesLocator.groomerHomeRepository.logout();

      if (mounted) {
        setState(() {
          _groomer = null;
          _upcomingBookings = [];
          _pendingBookings = [];
          _pastBookings = [];
          _cancelledBookings = [];
          _cancellationRequests = [];
          _serviceHours = [];
          _groomerHours = [];
          _holidays = [];
          _notifications = [];
          _processingBookingIds.clear();
        });
      }

      Routes.redirectToLogin(isGroomer: false);
    }
  }

  Future<void> _handleDeleteAccount() async {
    // 1. Business rules: Verify active, in-progress, or upcoming bookings
    final activeAppointments = _upcomingBookings.where((b) {
      final s = b.status.toLowerCase().trim();
      return s != 'completed' && s != 'cancelled' && s != 'rejected';
    }).toList();

    if (activeAppointments.isNotEmpty) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogCtx) => Dialog(
          backgroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFDC2626),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Active Bookings Present',
                        style: AppFonts.parkinsans(
                          size: 18,
                          weight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'You have ${activeAppointments.length} active or upcoming appointment(s) scheduled. To protect salon operations and client reservations, all appointments must be completed, cancelled, or reassigned before deleting your groomer account.',
                  style: AppFonts.poppins(
                    size: 13,
                    color: const Color(0xFF4B5563),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: Text(
                      'Understood',
                      style: AppFonts.parkinsans(
                        size: 14,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    // 2. Permanent Account Deletion Confirmation Dialog
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delete_forever_rounded,
                      color: Color(0xFFDC2626),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Delete Groomer Account',
                      style: AppFonts.parkinsans(
                        size: 18,
                        weight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Are you sure you want to permanently delete your groomer account? This action is permanent and cannot be undone. All your profile data, schedule settings, and portal access will be permanently deleted.',
                style: AppFonts.poppins(
                  size: 13,
                  color: const Color(0xFF4B5563),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                            side: const BorderSide(
                              color: Color(0xFFE5E7EB),
                              width: 1.2,
                            ),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppFonts.poppins(
                            size: 14,
                            weight: FontWeight.w500,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        child: Text(
                          'Delete Account',
                          style: AppFonts.parkinsans(
                            size: 14,
                            weight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    // 3. Perform Backend Account Deletion with Loading Indicator
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (loadingCtx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFDC2626),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Deleting account...',
                    style: AppFonts.poppins(
                      size: 14,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final success = await ServicesLocator.groomerHomeRepository
          .deleteAccount();

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (success) {
        _realtimeNotificationSub?.cancel();
        _realtimeNotificationSub = null;
        _timeTickerTimer?.cancel();
        _timeTickerTimer = null;

        if (mounted) {
          setState(() {
            _groomer = null;
            _upcomingBookings = [];
            _pendingBookings = [];
            _pastBookings = [];
            _cancelledBookings = [];
            _cancellationRequests = [];
            _serviceHours = [];
            _groomerHours = [];
            _holidays = [];
            _notifications = [];
            _processingBookingIds.clear();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Your groomer account has been permanently deleted.',
              ),
              backgroundColor: Color(0xFF111827),
              duration: Duration(seconds: 4),
            ),
          );
        }

        Routes.redirectToLogin(isGroomer: false);
      } else {
        if (mounted) {
          ToastUtil.showErrorToast(
            context,
            'Failed to delete account. Please try again.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        final rawMsg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        ToastUtil.showErrorToast(context, rawMsg);
      }
    }
  }

  void _openMainLineBookingModal() {
    MainLineBookingDialog.show(
      context,
      loggedInGroomer: _groomer,
      onBookingCreated: () {
        _loadAllData();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentTabIndex != 0) {
          setState(() => _currentTabIndex = 0);
          return;
        }

        final shouldExit = await ExitConfirmationDialog.show(context);
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (_isLoading)
                const LinearProgressIndicator(
                  minHeight: 2.5,
                  color: Color(0xFF111827),
                  backgroundColor: Colors.transparent,
                ),
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: const Color(0xFFFEF2F2),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFFDC2626),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppFonts.poppins(
                            size: 12,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.refresh,
                          size: 16,
                          color: Color(0xFFDC2626),
                        ),
                        onPressed: _loadAllData,
                      ),
                    ],
                  ),
                ),
              Expanded(child: _buildCurrentTabBody()),
            ],
          ),
        ),
        bottomNavigationBar: _buildFloatingDock(),
      ),
    );
  }

  Widget _buildCurrentTabBody() {
    switch (_currentTabIndex) {
      case 0:
        return _buildBookingsTab();
      case 1:
        return _buildScheduleTab();
      case 2:
        return const ForecastPage(isEmbedded: true);
      case 3:
        return const ReportsSummaryPage(isEmbedded: true);
      case 4:
        return _buildProfileTab();
      default:
        return _buildBookingsTab();
    }
  }

  // ── TAB 0: Bookings (Real API Driven) ──
  Widget _buildBookingsTab() {
    final groomerName = _groomer?.firstName.isNotEmpty == true
        ? _groomer!.firstName
        : (_groomer?.fullName.isNotEmpty == true
              ? _groomer!.fullName
              : 'Staff');

    final dateFormatted = _formatBookingDateDisplay(_selectedDate);
    final displayedBookings = _bookingsForSelectedDate;

    return RefreshIndicator(
      color: const Color(0xFF111827),
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          // ── Top Floating Header Bar ──
          _buildTopHeaderCard(groomerName: groomerName),

          const SizedBox(height: 24),

          // ── Section 1: Today's Booking Metrics ──
          Text(
            'Today’s Booking',
            style: AppFonts.poppins(
              size: 19,
              weight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),

          // 2x2 Grid of Stat Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  number: _formatCount(_todayTotalBookings),
                  label: 'Total Bookings',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildStatCard(
                  number: _formatCount(_todayPendingBookings),
                  label: 'Pending Bookings',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  number: _formatCount(_todayConfirmedBookings),
                  label: 'Confirmed Bookings',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildStatCard(
                  number: _formatCount(_todayCompletedBookings),
                  label: 'Completed Bookings',
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Main-Line Call Appointment Quick Action Banner ──
          _buildMainLineCallActionCard(),

          const SizedBox(height: 14),

          // ── All Groomers Schedule Quick Action Banner ──
          _buildAllGroomersScheduleCard(),

          // const SizedBox(height: 14),

          // // ── Revenue Forecast Quick Action Banner ──
          // _buildForecastCard(),

          // const SizedBox(height: 14),

          // // ── Reports Summary Quick Action Banner ──
          // _buildReportsSummaryCard(),
          const SizedBox(height: 24),

          // ── Section 2: Booking List ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Booking List',
                  style: AppFonts.parkinsans(
                    size: 19,
                    weight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'Select Groomer Schedule',
                offset: const Offset(0, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                onSelected: (val) {
                  if (val == 'all') {
                    context.push(
                      '/${RouteNames.groomerAllSchedule}?groomerId=all',
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'login_groomer',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check,
                          size: 16,
                          color: Color(0xFF111827),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$groomerName (You)',
                          style: AppFonts.poppins(
                            size: 13,
                            weight: FontWeight.w600,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'all',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.people_alt_outlined,
                          size: 16,
                          color: Color(0xFF111827),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'All Groomers',
                          style: AppFonts.poppins(
                            size: 13,
                            weight: FontWeight.w600,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: Color(0xFF111827),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person,
                        size: 14,
                        color: Color(0xFF111827),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '$groomerName (You)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.poppins(
                            size: 12,
                            weight: FontWeight.w600,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: Color(0xFF111827),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Date Selector Bar
          _buildDateSelectorBar(dateFormatted),

          const SizedBox(height: 16),

          // Booking List Cards
          if (displayedBookings.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(
                    Icons.event_busy_outlined,
                    size: 48,
                    color: Color(0xFF9CA3AF),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No bookings scheduled for $dateFormatted',
                    textAlign: TextAlign.center,
                    style: AppFonts.poppins(
                      size: 14,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            )
          else
            ...displayedBookings.map((booking) => _buildBookingCard(booking)),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatMinutesTo12h(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    final dt = DateTime(2026, 1, 1, h, m);
    return DateFormat('hh:mm a').format(dt);
  }

  // ── TAB 1: Schedule (Schedule & Availability) ──
  Widget _buildScheduleTab() {
    final groomer = _groomer;
    final multiBooking = groomer?.multiBookingEnabled ?? false;
    final slotLimit = groomer?.slotBookingLimit ?? 1;

    return RefreshIndicator(
      color: const Color(0xFF111827),
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          // Top Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schedule & Availability',
                      style: AppFonts.parkinsans(
                        size: 19,
                        weight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Store operating hours, working shifts, and slot availability.',
                      style: AppFonts.poppins(
                        size: 11.5,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: Color(0xFF111827),
                ),
                tooltip: 'Refresh Schedule',
                onPressed: _loadAllData,
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isLoading) ...[
            _buildScheduleSkeletonCard('Store Hours'),
            const SizedBox(height: 12),
            _buildScheduleSkeletonCard('My Working Hours'),
          ] else if (_serviceHours.isEmpty && _groomerHours.isEmpty) ...[
            _buildScheduleErrorCard(),
          ] else ...[
            // ── Section 1: Compact Overview Metrics Strip ──
            _buildScheduleSummaryCards(
              multiBooking: multiBooking,
              slotLimit: slotLimit,
            ),
            const SizedBox(height: 14),

            // ── Section 2: Interactive 7-Day Selector Strip ──
            _buildDaySelectorStrip(),
            const SizedBox(height: 14),

            // ── Section 3: Selected Day's Working Shift Details ──
            _buildSelectedDayScheduleCard(slotLimit: slotLimit),
            const SizedBox(height: 14),

            // ── Section 4: Available Time Slots Grid for Selected Day ──
            _buildSelectedDayTimeSlots(slotLimit: slotLimit),
            const SizedBox(height: 14),

            // ── Section 5: Full Week Overview Tables (Collapsible) ──
            _buildFullWeekSection(),
            const SizedBox(height: 14),

            // ── Section 6: Store Holidays Calendar Card ──
            _buildHolidaysCard(),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleSummaryCards({
    required bool multiBooking,
    required int slotLimit,
  }) {
    final currentDay = DateFormat('EEEE').format(DateTime.now());
    final todayStore = _serviceHours.firstWhere(
      (h) => h.dayOfWeek.toLowerCase() == currentDay.toLowerCase(),
      orElse: () => StoreServiceHour(
        dayOfWeek: currentDay,
        isOpen: false,
        startTime: '',
        endTime: '',
      ),
    );
    final todayGroomer = _groomerHours.firstWhere(
      (h) => h.dayOfWeek.toLowerCase() == currentDay.toLowerCase(),
      orElse: () => GroomerWorkingHour(
        groomerCode: _groomer?.groomerCode ?? '',
        dayOfWeek: currentDay,
        isWorking: false,
        startTime: '',
        endTime: '',
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Store Status Today
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    size: 16,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Store Today',
                        style: AppFonts.poppins(
                          size: 10.5,
                          color: const Color(0xFF6B7280),
                          weight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        todayStore.isOpen
                            ? '${todayStore.startFormatted} – ${todayStore.endFormatted}'
                            : 'Closed Today',
                        style: AppFonts.poppins(
                          size: 11.5,
                          weight: FontWeight.w600,
                          color: todayStore.isOpen
                              ? const Color(0xFF111827)
                              : const Color(0xFFDC2626),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 28,
            width: 1,
            color: const Color(0xFFE5E7EB),
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          // Shift & Capacity Today
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color:
                        (todayGroomer.isWorking
                                ? const Color(0xFF10B981)
                                : const Color(0xFF6B7280))
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    todayGroomer.isWorking
                        ? Icons.check_circle_outline_rounded
                        : Icons.pause_circle_outline_rounded,
                    size: 16,
                    color: todayGroomer.isWorking
                        ? const Color(0xFF059669)
                        : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Shift Today',
                        style: AppFonts.poppins(
                          size: 10.5,
                          color: const Color(0xFF6B7280),
                          weight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        todayGroomer.isWorking
                            ? '${todayGroomer.startFormatted} ($slotLimit pets/slot)'
                            : 'Scheduled Off',
                        style: AppFonts.poppins(
                          size: 11.5,
                          weight: FontWeight.w600,
                          color: todayGroomer.isWorking
                              ? const Color(0xFF059669)
                              : const Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelectorStrip() {
    final currentDayName = DateFormat(
      'EEEE',
    ).format(DateTime.now()).toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select Day of Week',
              style: AppFonts.poppins(
                size: 13.5,
                weight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            Text(
              'Tap to view shift & slots',
              style: AppFonts.poppins(size: 11, color: const Color(0xFF6B7280)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _weekDays.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final day = _weekDays[i];
              final isSelected = i == _selectedScheduleDayIndex;
              final isToday = day.toLowerCase() == currentDayName;
              final gHour = _groomerHours.firstWhere(
                (h) => h.dayOfWeek.toLowerCase() == day.toLowerCase(),
                orElse: () => GroomerWorkingHour(
                  groomerCode: '',
                  dayOfWeek: day,
                  isWorking: false,
                  startTime: '',
                  endTime: '',
                ),
              );
              final isWorking = gHour.isWorking;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _selectedScheduleDayIndex = i),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 58,
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF111827)
                          : (isToday
                                ? const Color(
                                    0xFF111827,
                                  ).withValues(alpha: 0.05)
                                : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF111827)
                            : (isToday
                                  ? const Color(0xFF111827)
                                  : const Color(0xFFE5E7EB)),
                        width: isSelected || isToday ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF111827,
                                ).withValues(alpha: 0.15),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          day.substring(0, 3),
                          style: AppFonts.poppins(
                            size: 12.5,
                            weight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : (isToday
                                      ? const Color(0xFF111827)
                                      : const Color(0xFF374151)),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? (isWorking
                                          ? const Color(0xFF34D399)
                                          : const Color(0xFF9CA3AF))
                                    : (isWorking
                                          ? const Color(0xFF059669)
                                          : const Color(0xFFD1D5DB)),
                              ),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 3),
                              Text(
                                '•',
                                style: AppFonts.poppins(
                                  size: 8,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF111827),
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDayScheduleCard({required int slotLimit}) {
    final selectedDay = _weekDays[_selectedScheduleDayIndex];
    final currentDayName = DateFormat(
      'EEEE',
    ).format(DateTime.now()).toLowerCase();
    final isToday = selectedDay.toLowerCase() == currentDayName;

    final sHour = _serviceHours.firstWhere(
      (h) => h.dayOfWeek.toLowerCase() == selectedDay.toLowerCase(),
      orElse: () => StoreServiceHour(
        dayOfWeek: selectedDay,
        isOpen: false,
        startTime: '',
        endTime: '',
      ),
    );
    final gHour = _groomerHours.firstWhere(
      (h) => h.dayOfWeek.toLowerCase() == selectedDay.toLowerCase(),
      orElse: () => GroomerWorkingHour(
        groomerCode: _groomer?.groomerCode ?? '',
        dayOfWeek: selectedDay,
        isWorking: false,
        startTime: '',
        endTime: '',
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    selectedDay,
                    style: AppFonts.parkinsans(
                      size: 16,
                      weight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'Today',
                        style: AppFonts.poppins(
                          size: 9,
                          color: Colors.white,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              // Working / Off Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: gHour.isWorking
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : const Color(0xFF6B7280).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: gHour.isWorking
                        ? const Color(0xFFA7F3D0)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Text(
                  gHour.isWorking ? 'Working Shift' : 'Scheduled Off',
                  style: AppFonts.poppins(
                    size: 11,
                    weight: FontWeight.w600,
                    color: gHour.isWorking
                        ? const Color(0xFF059669)
                        : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 18, color: Color(0xFFF3F4F6)),

          // 2x2 Grid of details
          Row(
            children: [
              Expanded(
                child: _buildShiftDetailItem(
                  icon: Icons.storefront_outlined,
                  iconColor: const Color(0xFF111827),
                  label: 'Store Operating Hours',
                  value: sHour.isOpen
                      ? '${sHour.startFormatted} – ${sHour.endFormatted}'
                      : 'Closed all day',
                  isActive: sHour.isOpen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildShiftDetailItem(
                  icon: Icons.access_time_rounded,
                  iconColor: const Color(0xFF059669),
                  label: 'My Working Shift',
                  value: gHour.isWorking
                      ? '${gHour.startFormatted} – ${gHour.endFormatted}'
                      : 'Off duty',
                  isActive: gHour.isWorking,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildShiftDetailItem(
                  icon: Icons.coffee_outlined,
                  iconColor: const Color(0xFFD97706),
                  label: 'Scheduled Breaks',
                  value: gHour.isWorking && gHour.breaks.isNotEmpty
                      ? gHour.breaks
                            .map(
                              (b) => '${b.startFormatted} – ${b.endFormatted}',
                            )
                            .join(', ')
                      : 'No breaks scheduled',
                  isActive: gHour.isWorking && gHour.breaks.isNotEmpty,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildShiftDetailItem(
                  icon: Icons.pets_outlined,
                  iconColor: const Color(0xFF111827),
                  label: 'Slot Booking Limit',
                  value:
                      '$slotLimit pet${slotLimit > 1 ? 's' : ''} / time slot',
                  isActive: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShiftDetailItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppFonts.poppins(
                    size: 9.5,
                    color: const Color(0xFF6B7280),
                    weight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: AppFonts.poppins(
                    size: 11,
                    weight: FontWeight.w600,
                    color: isActive
                        ? const Color(0xFF111827)
                        : const Color(0xFF9CA3AF),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDayTimeSlots({required int slotLimit}) {
    final selectedDay = _weekDays[_selectedScheduleDayIndex];
    final sHour = _serviceHours.firstWhere(
      (h) => h.dayOfWeek.toLowerCase() == selectedDay.toLowerCase(),
      orElse: () => StoreServiceHour(
        dayOfWeek: selectedDay,
        isOpen: false,
        startTime: '',
        endTime: '',
      ),
    );
    final gHour = _groomerHours.firstWhere(
      (h) => h.dayOfWeek.toLowerCase() == selectedDay.toLowerCase(),
      orElse: () => GroomerWorkingHour(
        groomerCode: _groomer?.groomerCode ?? '',
        dayOfWeek: selectedDay,
        isWorking: false,
        startTime: '',
        endTime: '',
      ),
    );

    if (!sHour.isOpen) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.storefront_outlined,
                size: 22,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Store Closed on $selectedDay',
                    style: AppFonts.poppins(
                      size: 13,
                      weight: FontWeight.w700,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No appointments or time slots are available when the salon is closed.',
                    style: AppFonts.poppins(
                      size: 11,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (!gHour.isWorking) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.event_busy_outlined,
                size: 22,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scheduled Off on $selectedDay',
                    style: AppFonts.poppins(
                      size: 13,
                      weight: FontWeight.w700,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Store is open (${sHour.startFormatted} – ${sHour.endFormatted}), but you are scheduled off.',
                    style: AppFonts.poppins(
                      size: 11,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Generate slots
    final startMin = gHour.startMinutes > 0
        ? gHour.startMinutes
        : sHour.startMinutes;
    final endMin = gHour.endMinutes > 0 ? gHour.endMinutes : sHour.endMinutes;
    final slotInterval = 60; // 1 hour slots

    final List<Map<String, dynamic>> slots = [];
    if (startMin < endMin) {
      for (int m = startMin; m + slotInterval <= endMin; m += slotInterval) {
        final slotEnd = m + slotInterval;
        final isBreak = gHour.breaks.any((b) {
          final bStart = b.startMinutes;
          final bEnd = b.endMinutes;
          return (m < bEnd && slotEnd > bStart);
        });

        String reason = '';
        if (isBreak) {
          final matched = gHour.breaks.firstWhere(
            (b) => m < b.endMinutes && slotEnd > b.startMinutes,
            orElse: () => GroomerBreak(
              groomerCode: '',
              dayOfWeek: selectedDay,
              startTime: '',
              endTime: '',
            ),
          );
          reason = matched.reason.isNotEmpty
              ? matched.reason
              : 'Scheduled Break';
        }

        slots.add({
          'start': _formatMinutesTo12h(m),
          'end': _formatMinutesTo12h(slotEnd),
          'isBreak': isBreak,
          'reason': reason,
        });
      }
    }

    final availableSlotsCount = slots
        .where((s) => s['isBreak'] == false)
        .length;
    final breakSlotsCount = slots.where((s) => s['isBreak'] == true).length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Time Slots',
                style: AppFonts.parkinsans(
                  size: 15,
                  weight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$availableSlotsCount Available',
                    style: AppFonts.poppins(
                      size: 11,
                      weight: FontWeight.w600,
                      color: const Color(0xFF059669),
                    ),
                  ),
                  if (breakSlotsCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$breakSlotsCount Break',
                      style: AppFonts.poppins(
                        size: 11,
                        weight: FontWeight.w600,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Time slots generated from your working shift (${gHour.startFormatted} – ${gHour.endFormatted})',
            style: AppFonts.poppins(size: 11, color: const Color(0xFF6B7280)),
          ),
          const SizedBox(height: 12),

          if (slots.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No time slots configured for this shift.',
                  style: AppFonts.poppins(
                    size: 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: slots.map((slot) {
                    final isBreak = slot['isBreak'] as bool;
                    final timeText = '${slot['start']} – ${slot['end']}';

                    return SizedBox(
                      width: itemWidth,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isBreak
                              ? const Color(0xFFFEF3C7).withValues(alpha: 0.5)
                              : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isBreak
                                ? const Color(0xFFFCD34D)
                                : const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isBreak
                                      ? Icons.coffee_outlined
                                      : Icons.access_time_rounded,
                                  size: 13,
                                  color: isBreak
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFF059669),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    isBreak ? 'Break' : 'Available',
                                    style: AppFonts.poppins(
                                      size: 10,
                                      weight: FontWeight.w600,
                                      color: isBreak
                                          ? const Color(0xFFD97706)
                                          : const Color(0xFF059669),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              timeText,
                              style: AppFonts.poppins(
                                size: 11.5,
                                weight: FontWeight.w700,
                                color: const Color(0xFF111827),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              isBreak
                                  ? (slot['reason'] as String)
                                  : 'Capacity: $slotLimit pet${slotLimit > 1 ? 's' : ''}',
                              style: AppFonts.poppins(
                                size: 9.5,
                                color: const Color(0xFF6B7280),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFullWeekSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Weekly Schedule Overview',
              style: AppFonts.parkinsans(
                size: 15.5,
                weight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                setState(() {
                  _showFullWeekOverview = !_showFullWeekOverview;
                });
              },
              icon: Icon(
                _showFullWeekOverview
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: const Color(0xFF111827),
              ),
              label: Text(
                _showFullWeekOverview ? 'Hide Full Week' : 'Show Full Week',
                style: AppFonts.poppins(
                  size: 11.5,
                  weight: FontWeight.w600,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
          ],
        ),
        if (_showFullWeekOverview) ...[
          const SizedBox(height: 10),
          GroomerWorkingHoursTableWidget(
            hours: _groomerHours,
            storeHours: _serviceHours,
            groomerCode: _groomer?.groomerCode ?? '',
          ),
          const SizedBox(height: 12),
          StoreHoursTableWidget(hours: _serviceHours),
        ],
      ],
    );
  }

  Widget _buildHolidaysCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.beach_access_outlined,
                  color: Color(0xFFD97706),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Store Holidays Calendar',
                      style: AppFonts.parkinsans(
                        size: 15,
                        weight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      'Upcoming public holidays and store closures',
                      style: AppFonts.poppins(
                        size: 11,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 18, color: Color(0xFFF3F4F6)),
          if (_holidays.isNotEmpty) ...[
            ..._holidays.map(
              (h) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            h.name,
                            style: AppFonts.poppins(
                              size: 12,
                              weight: FontWeight.w600,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          if (h.description.isNotEmpty)
                            Text(
                              h.description,
                              style: AppFonts.poppins(
                                size: 10.5,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        h.date,
                        style: AppFonts.poppins(
                          size: 10.5,
                          weight: FontWeight.w600,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Text(
                'No upcoming store holidays recorded.',
                style: AppFonts.poppins(
                  size: 11.5,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 36,
            color: Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 10),
          Text(
            'Unable to load schedule',
            style: AppFonts.poppins(
              size: 13.5,
              weight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'We couldn\'t retrieve the latest schedule information.',
            style: AppFonts.poppins(size: 11.5, color: const Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111827),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _loadAllData,
            icon: const Icon(Icons.refresh_rounded, size: 15),
            label: Text(
              'Retry',
              style: AppFonts.parkinsans(
                size: 13,
                weight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSkeletonCard(String title) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 100,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 140,
                      height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 6),
          ...List.generate(
            4,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 65,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Staff Notifications (API Driven, Bottom Sheet & Tab) ──
  Widget _buildNotificationsTab({bool isBottomSheet = false}) {
    final pendingIds = _pendingBookings.map((b) => b.bookingId).toSet();
    final cancelIds = _cancellationRequests.map((b) => b.bookingId).toSet();
    final approvedIds = GroomerHomeRepository.approvedBookingIds;
    final rejectedIds = GroomerHomeRepository.rejectedBookingIds;

    final filteredAlerts = _notifications.where((n) {
      final metadata = n['data'] is Map
          ? n['data'] as Map
          : (n['metadata'] is Map ? n['metadata'] as Map : null);
      final rawBookingId = metadata?['bookingId'] ??
          metadata?['booking_id'] ??
          metadata?['entityId'] ??
          n['bookingId'] ??
          n['entityId'];
      final bId = int.tryParse(rawBookingId?.toString() ?? '');
      if (bId != null) {
        if (pendingIds.contains(bId) ||
            cancelIds.contains(bId) ||
            approvedIds.contains(bId) ||
            rejectedIds.contains(bId)) {
          return false;
        }
      }
      final title = (n['title'] ?? '').toString();
      final message = (n['message'] ?? n['body'] ?? '').toString();
      for (final id in {...approvedIds, ...rejectedIds}) {
        if (title.contains('#$id') || message.contains('#$id')) {
          return false;
        }
      }
      return true;
    }).toList();

    final hasAnyNotification =
        _pendingBookings.isNotEmpty ||
        _cancellationRequests.isNotEmpty ||
        filteredAlerts.isNotEmpty;

    return RefreshIndicator(
      color: const Color(0xFF111827),
      onRefresh: _loadAllData,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, isBottomSheet ? 32 : 120),
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Staff Notifications',
                      style: AppFonts.parkinsans(
                        size: 20,
                        weight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Booking alerts and schedule updates',
                      style: AppFonts.poppins(
                        size: 12.5,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              if (filteredAlerts.isNotEmpty)
                TextButton(
                  onPressed: _handleMarkAllNotificationsRead,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF111827),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  child: Text(
                    'Mark all read',
                    style: AppFonts.poppins(
                      size: 12,
                      weight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
              if (isBottomSheet)
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 22,
                    color: Color(0xFF111827),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Quick Summary Metrics Strip
          _buildStaffNotificationMetrics(),
          const SizedBox(height: 16),

          // Pending Booking Requests
          if (_pendingBookings.isNotEmpty) ...[
            _buildStaffSectionHeader(
              'PENDING BOOKING REQUESTS',
              _pendingBookings.length,
              const Color(0xFFD97706),
            ),
            ..._pendingBookings.map(
              (b) => _buildNotificationTile(
                id: b.bookingId,
                icon: Icons.calendar_today_outlined,
                title: 'New Booking Request #${b.bookingId}',
                body:
                    '${b.customerName} requested ${b.serviceName} for ${b.petName} on ${b.formattedBookingDate}, ${b.startTime}.',
                time: 'Pending Review',
                isUnread: true,
                booking: b,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Cancellation Requests
          if (_cancellationRequests.isNotEmpty) ...[
            _buildStaffSectionHeader(
              'CANCELLATION REQUESTS',
              _cancellationRequests.length,
              const Color(0xFFDC2626),
            ),
            ..._cancellationRequests.map(
              (b) => _buildCancellationNotificationTile(b),
            ),
            const SizedBox(height: 12),
          ],

          // Notifications from /api/notifications
          if (filteredAlerts.isNotEmpty) ...[
            _buildStaffSectionHeader(
              'SYSTEM & SCHEDULE ALERTS',
              filteredAlerts.length,
              const Color(0xFF111827),
            ),
            ...filteredAlerts.map((n) {
              final id = n['id'] is int
                  ? n['id'] as int
                  : int.tryParse(n['id']?.toString() ?? '0') ?? 0;
              final title = n['title']?.toString() ?? 'System Notification';
              final body =
                  n['body']?.toString() ?? n['message']?.toString() ?? '';
              final isRead = n['isRead'] == true || n['is_read'] == true;
              final time = n['createdAt']?.toString() ?? 'Recent';

              final metadata = n['data'] is Map
                  ? n['data'] as Map
                  : (n['metadata'] is Map ? n['metadata'] as Map : null);
              final rawBookingId =
                  metadata?['bookingId'] ??
                  metadata?['booking_id'] ??
                  metadata?['entityId'] ??
                  n['bookingId'] ??
                  n['entityId'];
              final bookingId = rawBookingId != null
                  ? int.tryParse(rawBookingId.toString())
                  : null;

              return _buildNotificationTile(
                id: id,
                icon: Icons.notifications_active_outlined,
                title: title,
                body: body,
                time: time.length > 10 ? time.substring(0, 10) : time,
                isUnread: !isRead,
                bookingId: bookingId,
              );
            }),
          ],

          if (!hasAnyNotification) _buildStaffEmptyNotificationState(),
        ],
      ),
    );
  }

  Widget _buildStaffSectionHeader(String title, int count, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 12,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              title,
              style: AppFonts.poppins(
                size: 11.5,
                weight: FontWeight.w700,
                color: const Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: AppFonts.poppins(
                size: 10,
                weight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffNotificationMetrics() {
    final pendingIds = _pendingBookings.map((b) => b.bookingId).toSet();
    final cancelIds = _cancellationRequests.map((b) => b.bookingId).toSet();
    final approvedIds = GroomerHomeRepository.approvedBookingIds;
    final rejectedIds = GroomerHomeRepository.rejectedBookingIds;

    final filteredAlertsCount = _notifications.where((n) {
      final metadata = n['data'] is Map ? n['data'] as Map : (n['metadata'] is Map ? n['metadata'] as Map : null);
      final rawBookingId = metadata?['bookingId'] ??
          metadata?['booking_id'] ??
          metadata?['entityId'] ??
          n['bookingId'] ??
          n['entityId'];
      final bId = int.tryParse(rawBookingId?.toString() ?? '');
      if (bId != null &&
          (pendingIds.contains(bId) ||
              cancelIds.contains(bId) ||
              approvedIds.contains(bId) ||
              rejectedIds.contains(bId))) {
        return false;
      }
      final title = (n['title'] ?? '').toString();
      final message = (n['message'] ?? n['body'] ?? '').toString();
      for (final id in {...approvedIds, ...rejectedIds}) {
        if (title.contains('#$id') || message.contains('#$id')) {
          return false;
        }
      }
      return true;
    }).length;

    return Row(
      children: [
        Expanded(
          child: _buildStaffMetricCard(
            label: 'Pending',
            count: _pendingBookings.length,
            icon: Icons.hourglass_top_rounded,
            color: const Color(0xFFD97706),
            bgColor: const Color(0xFFFFFBEB),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStaffMetricCard(
            label: 'Cancellations',
            count: _cancellationRequests.length,
            icon: Icons.cancel_outlined,
            color: const Color(0xFFDC2626),
            bgColor: const Color(0xFFFEF2F2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStaffMetricCard(
            label: 'System Alerts',
            count: filteredAlertsCount,
            icon: Icons.notifications_none_rounded,
            color: const Color(0xFF111827),
            bgColor: const Color(0xFFF3F4F6),
          ),
        ),
      ],
    );
  }

  Widget _buildStaffMetricCard({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: count > 0
              ? color.withValues(alpha: 0.35)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '$count',
                  style: AppFonts.parkinsans(
                    size: 15,
                    weight: FontWeight.w700,
                    color: count > 0 ? color : const Color(0xFF111827),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppFonts.poppins(
              size: 10.5,
              weight: FontWeight.w500,
              color: const Color(0xFF6B7280),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStaffEmptyNotificationState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Empty State Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),

          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 30,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'All Clear & Up to Date!',
                style: AppFonts.parkinsans(
                  size: 16.5,
                  weight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'No pending booking requests, customer cancellations, or unread staff alerts at this time.',
                textAlign: TextAlign.center,
                style: AppFonts.poppins(
                  size: 12.5,
                  weight: FontWeight.w400,
                  color: const Color(0xFF6B7280),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Quick Staff Action Shortcuts
        Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    setState(() => _currentTabIndex = 0);
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.calendar_month_outlined,
                            size: 18,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Appointments',
                                style: AppFonts.poppins(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              Text(
                                'View active queue',
                                style: AppFonts.poppins(
                                  size: 10.5,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    setState(() => _currentTabIndex = 1);
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.schedule_rounded,
                            size: 18,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Shift & Hours',
                                style: AppFonts.poppins(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              Text(
                                'Manage schedule',
                                style: AppFonts.poppins(
                                  size: 10.5,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCancellationNotificationTile(GroomerBooking booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cancel_outlined,
              size: 18,
              color: Color(0xFFDC2626),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Cancellation Request #${booking.bookingId}',
                        style: AppFonts.poppins(
                          size: 13.5,
                          weight: FontWeight.w600,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Action Required',
                        style: AppFonts.poppins(
                          size: 11,
                          color: const Color(0xFFDC2626),
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${booking.customerName} requested to cancel booking for ${booking.petName} on ${booking.formattedBookingDate}.',
                  style: AppFonts.poppins(
                    size: 12.5,
                    color: const Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                      ),
                      onPressed: () => _handleApproveCancellation(booking),
                      child: Text(
                        'Approve Cancellation',
                        style: AppFonts.poppins(
                          size: 11,
                          weight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4B5563),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                      ),
                      onPressed: () => _handleRejectCancellation(booking),
                      child: Text(
                        'Reject',
                        style: AppFonts.poppins(
                          size: 11,
                          weight: FontWeight.w600,
                          color: const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile({
    required int id,
    required IconData icon,
    required String title,
    required String body,
    required String time,
    required bool isUnread,
    GroomerBooking? booking,
    int? bookingId,
  }) {
    return GestureDetector(
      onTap: () {
        if (isUnread && id > 0) {
          _handleMarkNotificationRead(id);
        }

        // Deep-linking: Navigate to corresponding booking if bookingId is provided
        final targetBookingId = booking?.bookingId ?? bookingId;
        if (targetBookingId != null) {
          GroomerBooking? targetBooking = booking;
          if (targetBooking == null) {
            for (final b in _combinedBookings) {
              if (b.bookingId == targetBookingId) {
                targetBooking = b;
                break;
              }
            }
          }

          if (targetBooking != null) {
            final parsedDate = DateTime.tryParse(targetBooking.bookingDate);
            setState(() {
              if (parsedDate != null) {
                _selectedDate = parsedDate;
              }
              _currentTabIndex = 0; // Switch to bookings tab
            });
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnread
                ? const Color(0xFF111827).withValues(alpha: 0.3)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isUnread
                    ? const Color(0xFF111827).withValues(alpha: 0.08)
                    : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: isUnread
                    ? const Color(0xFF111827)
                    : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppFonts.poppins(
                            size: 13.5,
                            weight: FontWeight.w600,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          time,
                          style: AppFonts.poppins(
                            size: 11,
                            color: const Color(0xFF9CA3AF),
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: AppFonts.poppins(
                      size: 12.5,
                      color: const Color(0xFF4B5563),
                    ),
                  ),
                  if (booking != null && booking.status == 'pending') ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 12,
                            color: Color(0xFFD97706),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Acceptance Deadline: Scheduled start (${booking.startTime})',
                              style: AppFonts.poppins(
                                size: 10.5,
                                weight: FontWeight.w600,
                                color: const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () => _handleApproveBooking(booking),
                          child: Text(
                            'Approve',
                            style: AppFonts.poppins(
                              size: 11,
                              weight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () => _handleRejectBooking(booking),
                          child: Text(
                            'Reject',
                            style: AppFonts.poppins(
                              size: 11,
                              weight: FontWeight.w600,
                              color: const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB 3: Profile (Live Groomer Data & Edit Profile) ──
  Widget _buildProfileTab() {
    final groomer =
        _groomer ?? ServicesLocator.groomerHomeRepository.getCurrentGroomer();
    final name = (groomer != null && groomer.fullName.trim().isNotEmpty)
        ? groomer.fullName.trim()
        : 'Staff Member';
    final role = (groomer != null && groomer.role.trim().isNotEmpty)
        ? groomer.role.trim()
        : 'Groomer';
    final code = (groomer != null && groomer.groomerCode.trim().isNotEmpty)
        ? groomer.groomerCode.trim()
        : '—';
    final email = (groomer != null && groomer.email.trim().isNotEmpty)
        ? groomer.email.trim()
        : 'Not provided';

    final rawMobile = groomer?.mobile.trim() ?? '';
    final mobileDigits = UsPhoneInputFormatter.cleanDigits(rawMobile);
    final hasPhone = rawMobile.isNotEmpty;
    final phone = mobileDigits.length == 10
        ? UsPhoneInputFormatter.formatDigits(mobileDigits)
        : (hasPhone ? rawMobile : 'Not provided');

    final rawHighlights = groomer?.highlights.trim() ?? '';
    final hasHighlights = rawHighlights.isNotEmpty;
    final highlights = hasHighlights ? rawHighlights : role;

    final multiBooking = groomer?.multiBookingEnabled ?? false;
    final slotLimit = groomer?.slotBookingLimit ?? 1;
    final isActive = groomer?.isActive ?? true;
    final storeCode = (groomer != null && groomer.storeId.trim().isNotEmpty)
        ? groomer.storeId.trim()
        : 'SHEAR-001';

    return RefreshIndicator(
      color: const Color(0xFF111827),
      onRefresh: () async {
        await _refreshProfile();
        await _loadAllData();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Staff Profile',
                    style: AppFonts.parkinsans(
                      size: 20,
                      weight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Manage your groomer account & slot capacity',
                    style: AppFonts.poppins(
                      size: 12.5,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _refreshProfile,
                tooltip: 'Refresh Profile',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Profile Info Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildGroomerAvatar(size: 76, avatarPath: groomer?.avatarUrl),
                const SizedBox(height: 12),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: AppFonts.parkinsans(
                    size: 18,
                    weight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$role • Staff Code: $code',
                  textAlign: TextAlign.center,
                  style: AppFonts.poppins(
                    size: 13,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : const Color(0xFF6B7280).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'Active Staff Member' : 'Inactive Staff Member',
                    style: AppFonts.poppins(
                      size: 11.5,
                      weight: FontWeight.w600,
                      color: isActive
                          ? const Color(0xFF059669)
                          : const Color(0xFF4B5563),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF111827),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: _handleEditProfileDialog,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(
                      'Edit Profile',
                      style: AppFonts.parkinsans(
                        size: 13,
                        weight: FontWeight.w600,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Contact & Bio Details
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account & Capacity Details',
                  style: AppFonts.parkinsans(
                    size: 15,
                    weight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 14),
                _buildProfileDetailRow(Icons.badge_outlined, 'Full Name', name),
                const Divider(height: 22, color: Color(0xFFF3F4F6)),
                _buildProfileDetailRow(Icons.email_outlined, 'Email', email),
                const Divider(height: 22, color: Color(0xFFF3F4F6)),
                _buildProfileDetailRow(
                  Icons.phone_outlined,
                  'Phone',
                  phone,
                  isMuted: !hasPhone,
                ),
                const Divider(height: 22, color: Color(0xFFF3F4F6)),
                _buildProfileDetailRow(
                  Icons.storefront_outlined,
                  'Store Location',
                  'Shear Heaven - Darwin ($storeCode)',
                ),
                const Divider(height: 22, color: Color(0xFFF3F4F6)),
                _buildProfileDetailRow(
                  Icons.calendar_month_outlined,
                  'Simultaneous Capacity',
                  multiBooking
                      ? 'Multi-Booking Active ($slotLimit pets / slot)'
                      : 'Single Booking Mode (1 pet / slot)',
                ),
                const Divider(height: 22, color: Color(0xFFF3F4F6)),
                _buildProfileDetailRow(
                  Icons.stars_rounded,
                  'Bio / Highlights',
                  highlights,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Staff Logout Button
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFEE2E2),
                foregroundColor: const Color(0xFFDC2626),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text(
                'Logout from Staff Portal',
                style: AppFonts.parkinsans(
                  size: 14,
                  weight: FontWeight.w600,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Delete Account Button
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFFEF2F2),
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFFECACA), width: 1.2),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: _handleDeleteAccount,
              icon: const Icon(
                Icons.delete_forever_rounded,
                size: 18,
                color: Color(0xFFDC2626),
              ),
              label: Text(
                'Delete Account',
                style: AppFonts.parkinsans(
                  size: 14,
                  weight: FontWeight.w600,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildProfileDetailRow(
    IconData icon,
    String label,
    String value, {
    bool isMuted = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: const Color(0xFF4B5563)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppFonts.poppins(
                  size: 12,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppFonts.poppins(
                  size: 13.5,
                  weight: isMuted ? FontWeight.w400 : FontWeight.w600,
                  color: isMuted
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Exact Customer Portal Floating Glass Pill Dock ──
  Widget _buildFloatingDock() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(17.5, 0, 17.5, 34),
      child: Container(
        height: 78,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(39),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(39),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
            child: Container(
              height: 78,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(39),
                border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  _buildDockItem(
                    index: 0,
                    child: const Icon(Icons.calendar_month_outlined, size: 26),
                  ),
                  _buildDockItem(
                    index: 1,
                    child: const Icon(Icons.access_time_rounded, size: 26),
                  ),
                  _buildDockItem(
                    index: 2,
                    child: const Icon(Icons.trending_up_rounded, size: 26),
                  ),
                  _buildDockItem(
                    index: 3,
                    child: const Icon(Icons.bar_chart_rounded, size: 26),
                  ),
                  _buildDockItem(index: 4, child: _profileDockIcon()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileDockIcon() {
    return SvgPicture.asset(
      'assets/images/common/fi_1077114_1_486.svg',
      width: 26,
      height: 26,
      errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.person_outline, size: 26),
    );
  }

  Widget _gradientIcon(Widget child) {
    return ShaderMask(
      shaderCallback: (bounds) => _darkGradient.createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: child,
    );
  }

  Widget _solidIcon(Widget child, Color color) {
    return ShaderMask(
      shaderCallback: (bounds) =>
          LinearGradient(colors: [color, color]).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: child,
    );
  }

  Widget _buildDockItem({required int index, required Widget child}) {
    final selected = _currentTabIndex == index;
    Widget content;
    if (selected) {
      content = Container(
        width: 50,
        height: 50,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: _darkGradient,
        ),
        child: Center(child: _solidIcon(child, Colors.white)),
      );
    } else {
      content = _gradientIcon(Opacity(opacity: 0.3, child: child));
    }
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _currentTabIndex = index;
          });
          if (index == 4) {
            _refreshProfile();
          }
        },
        child: Center(child: content),
      ),
    );
  }

  // ── Floating Top Header Card ──
  Widget _buildTopHeaderCard({required String groomerName}) {
    final pendingIds = _pendingBookings.map((b) => b.bookingId).toSet();
    final cancelIds = _cancellationRequests.map((b) => b.bookingId).toSet();
    final approvedIds = GroomerHomeRepository.approvedBookingIds;
    final rejectedIds = GroomerHomeRepository.rejectedBookingIds;

    final unreadNotifs = _notifications.where((n) {
      final isUnread = n['isRead'] != true && n['is_read'] != true;
      if (!isUnread) return false;
      final metadata = n['data'] is Map ? n['data'] as Map : (n['metadata'] is Map ? n['metadata'] as Map : null);
      final rawBookingId = metadata?['bookingId'] ??
          metadata?['booking_id'] ??
          metadata?['entityId'] ??
          n['bookingId'] ??
          n['entityId'];
      final bId = int.tryParse(rawBookingId?.toString() ?? '');
      if (bId != null &&
          (pendingIds.contains(bId) ||
              cancelIds.contains(bId) ||
              approvedIds.contains(bId) ||
              rejectedIds.contains(bId))) {
        return false;
      }
      final title = (n['title'] ?? '').toString();
      final message = (n['message'] ?? n['body'] ?? '').toString();
      for (final id in {...approvedIds, ...rejectedIds}) {
        if (title.contains('#$id') || message.contains('#$id')) {
          return false;
        }
      }
      return true;
    }).length;
    final unreadCount =
        _pendingBookings.length + _cancellationRequests.length + unreadNotifs;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular Avatar
          GestureDetector(
            onTap: () {
              setState(() {
                _currentTabIndex = 4;
              });
              _refreshProfile();
            },
            child: _buildGroomerAvatar(
              size: 48,
              avatarPath: _groomer?.avatarUrl,
            ),
          ),
          const SizedBox(width: 12),

          // User Name (First) & Greeting (Second, Small)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, $groomerName',
                  style: AppFonts.poppins(
                    size: 16,
                    weight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _getGreeting(),
                  style: AppFonts.poppins(
                    size: 12.5,
                    weight: FontWeight.w400,
                    color: const Color(0xFF6B7280),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Notification Bell Button with Badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF3F4F6),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.notifications,
                    size: 20,
                    color: Color(0xFF111827),
                  ),
                  onPressed: _openNotificationsSheet,
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: AppFonts.poppins(
                        color: Colors.white,
                        size: 9,
                        weight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),

          // Logout Button
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFEE2E2),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: 'Logout',
              icon: const Icon(
                Icons.logout_rounded,
                size: 19,
                color: Color(0xFFDC2626),
              ),
              onPressed: _handleLogout,
            ),
          ),
        ],
      ),
    );
  }

  void _openNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalCtx, setSheetState) {
            _notificationsSheetSetState = setSheetState;
            return Container(
              height: MediaQuery.of(modalCtx).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(child: _buildNotificationsTab(isBottomSheet: true)),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _notificationsSheetSetState = null;
    });
  }

  // ── Stat Card (2x2 Grid) ──
  Widget _buildStatCard({required String number, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            number,
            style: AppFonts.poppins(
              size: 26,
              weight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppFonts.poppins(
              size: 13,
              weight: FontWeight.w500,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  // ── Main-Line Call Appointment Quick Action Banner ──
  Widget _buildMainLineCallActionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F2937), Color(0xFF111827)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_in_talk_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Main-Line Call Booking',
                  style: AppFonts.poppins(
                    size: 14.5,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Customer calling? Book & assign any groomer',
                  style: AppFonts.poppins(
                    size: 11.5,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF111827),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: _openMainLineBookingModal,
            child: Text(
              'New Booking',
              style: AppFonts.poppins(size: 12.5, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ── All Groomers Schedule Quick Action Card ──
  Widget _buildAllGroomersScheduleCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/${RouteNames.groomerAllSchedule}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    size: 24,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All Groomers Schedule',
                        style: AppFonts.parkinsans(
                          size: 14.5,
                          weight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'View and filter appointments for all salon staff',
                        style: AppFonts.poppins(
                          size: 11.5,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View',
                        style: AppFonts.parkinsans(
                          size: 12,
                          weight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateFromCalendar() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = today.subtract(const Duration(days: 365));
    final lastDate = today.add(const Duration(days: 365));
    final initialDate = _selectedDate.isBefore(firstDate)
        ? firstDate
        : (_selectedDate.isAfter(lastDate) ? lastDate : _selectedDate);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF111827),
              onPrimary: Colors.white,
              onSurface: Color(0xFF111827),
            ),
            datePickerTheme: DatePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              headerBackgroundColor: const Color(0xFF111827),
              headerForegroundColor: Colors.white,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = BookingDateUtils.normalize(picked);
      });
    }
  }

  // ── Date Selector Bar ──
  Widget _buildDateSelectorBar(String formattedDate) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          children: [
            // Previous Date Button (Backward)
            Tooltip(
              message: 'Previous Day',
              child: InkWell(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
                onTap: () {
                  setState(() {
                    _selectedDate = _selectedDate.subtract(
                      const Duration(days: 1),
                    );
                  });
                },
                child: const SizedBox(
                  width: 48,
                  height: 52,
                  child: Center(
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 26,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ),
            ),

            // Date Text & Calendar Trigger
            Expanded(
              child: Tooltip(
                message: 'Select Date from Calendar',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _pickDateFromCalendar,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: Color(0xFF111827),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formattedDate,
                            style: AppFonts.poppins(
                              size: 14.5,
                              weight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Next Date Button (Forward)
            Tooltip(
              message: 'Next Day',
              child: InkWell(
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(12),
                ),
                onTap: () {
                  setState(() {
                    _selectedDate = _selectedDate.add(const Duration(days: 1));
                  });
                },
                child: const SizedBox(
                  width: 48,
                  height: 52,
                  child: Center(
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 26,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetImage(String? url, String petName) {
    return PetImageHelper.buildImage(
      photoUrl: url,
      petName: petName,
      fit: BoxFit.cover,
      loadingWidget: Container(
        color: const Color(0xFFF3F4F6),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ),
    );
  }

  // ── Booking Card ──
  Widget _buildBookingCard(GroomerBooking booking) {
    Color borderColor;
    Color badgeBgColor;
    Color badgeTextColor;
    String badgeText;

    final statusLower = booking.status.toLowerCase();
    final isReadyForCheckout =
        statusLower == 'ready_for_checkout' || booking.isReadyForCheckout;
    final effectiveStatusLower =
        (statusLower == 'completed' || booking.isCompleted)
        ? 'completed'
        : (isReadyForCheckout
              ? 'ready_for_checkout'
              : (booking.isGroomingCompleted &&
                        (statusLower == 'in_progress' ||
                            statusLower == 'in-progress')
                    ? 'grooming_completed'
                    : (booking.isBathCompleted &&
                              (statusLower == 'in_progress' ||
                                  statusLower == 'in-progress')
                          ? 'bath_completed'
                          : statusLower)));

    switch (effectiveStatusLower) {
      case 'in_progress':
      case 'in-progress':
        borderColor = const Color(0xFF2563EB); // Vibrant Blue
        badgeBgColor = const Color(0xFFDBEAFE);
        badgeTextColor = const Color(0xFF1D4ED8);
        badgeText = 'In Progress';
        break;
      case 'bath_completed':
        borderColor = const Color(0xFF0284C7);
        badgeBgColor = const Color(0xFFE0F2FE);
        badgeTextColor = const Color(0xFF0369A1);
        badgeText = 'Bath Completed';
        break;
      case 'grooming_completed':
        borderColor = const Color(0xFF7C3AED);
        badgeBgColor = const Color(0xFFEDE9FE);
        badgeTextColor = const Color(0xFF6D28D9);
        badgeText = 'Grooming Completed';
        break;
      case 'ready_for_checkout':
        borderColor = const Color(0xFF111827);
        badgeBgColor = const Color(0xFFF3F4F6);
        badgeTextColor = const Color(0xFF111827);
        badgeText = 'Ready for Checkout';
        break;
      case 'confirmed':
        borderColor = const Color(0xFF10B981); // Emerald Green
        badgeBgColor = const Color(0xFFDCFCE7);
        badgeTextColor = const Color(0xFF166534);
        badgeText = 'Confirmed';
        break;
      case 'pending':
        borderColor = const Color(0xFFF59E0B); // Amber
        badgeBgColor = const Color(0xFFFEF3C7);
        badgeTextColor = const Color(0xFFD97706);
        badgeText = 'Pending';
        break;
      case 'cancellation_requested':
        borderColor = const Color(0xFF8B5CF6); // Purple
        badgeBgColor = const Color(0xFFEDE9FE);
        badgeTextColor = const Color(0xFF6D28D9);
        badgeText = 'Cancellation Requested';
        break;
      case 'completed':
      case 'past':
        borderColor = const Color(0xFFE5E7EB); // Subtle Slate / Grey
        badgeBgColor = const Color(0xFFF3F4F6);
        badgeTextColor = const Color(0xFF374151);
        badgeText = 'Completed';
        break;
      case 'rejected':
      case 'cancelled':
      default:
        borderColor = const Color(0xFFF87171); // Red
        badgeBgColor = const Color(0xFFFEE2E2);
        badgeTextColor = const Color(0xFFDC2626);
        badgeText = statusLower == 'cancelled' ? 'Cancelled' : 'Rejected';
        break;
    }

    final isInProgress =
        statusLower == 'in_progress' || statusLower == 'in-progress';
    final isConfirmed = statusLower == 'confirmed';
    final isPending = statusLower == 'pending';
    final isCancellationRequested = statusLower == 'cancellation_requested';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pet Image Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: _buildPetImage(
                    booking.profilePicture,
                    booking.petName,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Details Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Pet Name + Status Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            booking.petName,
                            style: AppFonts.poppins(
                              size: 15.5,
                              weight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isInProgress) ...[
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1D4ED8),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                badgeText,
                                style: AppFonts.poppins(
                                  size: 11,
                                  weight: FontWeight.w600,
                                  color: badgeTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Time Range Row
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            booking.formattedTimeRange,
                            style: AppFonts.poppins(
                              size: 12,
                              weight: FontWeight.w400,
                              color: const Color(0xFF4B5563),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Service / Category / "Grooming" Row
                    Row(
                      children: [
                        const Icon(
                          Icons.content_cut_rounded,
                          size: 13,
                          color: Color(0xFF111827),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            booking.fullServiceDescription.isNotEmpty
                                ? booking.fullServiceDescription
                                : 'Grooming',
                            style: AppFonts.poppins(
                              size: 12.5,
                              weight: FontWeight.w500,
                              color: const Color(0xFF1F2937),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Actions for pending bookings (Approve / Reject)
          if (isPending && booking.bookingId > 0) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: () => _handleRejectBooking(booking),
                  child: Text(
                    'Reject',
                    style: AppFonts.poppins(size: 12, weight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: () => _handleApproveBooking(booking),
                  child: Text(
                    'Approve',
                    style: AppFonts.poppins(size: 12, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],

          // Step 6 Check-in Record & Server Timestamp Badge
          if (booking.isCheckedIn || booking.hasCheckInRecord) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 14,
                    color: Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    booking.checkInTimestamp != null &&
                            booking.checkInTimestamp!.isNotEmpty
                        ? 'Checked In • ${_formatCheckInTimestamp(booking.checkInTimestamp!)}'
                        : 'Checked In',
                    style: AppFonts.poppins(
                      size: 11.5,
                      weight: FontWeight.w600,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                  if (booking.groomerCheckInNotes != null &&
                      booking.groomerCheckInNotes!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '• Notes: "${booking.groomerCheckInNotes}"',
                        style: AppFonts.poppins(
                          size: 11,
                          color: const Color(0xFF166534),
                        ).copyWith(fontStyle: FontStyle.italic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Step 7 Milestone Badges & Optional Notes
          if (booking.isBathCompleted || booking.isGroomingCompleted) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          booking.requiresBath && booking.requiresGrooming
                              ? (booking.isGroomingCompleted
                                    ? (booking.groomingCompletedAt != null &&
                                              booking
                                                  .groomingCompletedAt!
                                                  .isNotEmpty
                                          ? 'Milestones: Bath & Grooming Completed • ${_formatMilestoneTimestamp(booking.groomingCompletedAt!)}'
                                          : 'Milestones: Bath & Grooming Completed')
                                    : (booking.bathCompletedAt != null &&
                                              booking
                                                  .bathCompletedAt!
                                                  .isNotEmpty
                                          ? 'Milestone: Bath Completed • ${_formatMilestoneTimestamp(booking.bathCompletedAt!)}'
                                          : 'Milestone: Bath Completed'))
                              : (booking.requiresBath
                                    ? (booking.bathCompletedAt != null &&
                                              booking
                                                  .bathCompletedAt!
                                                  .isNotEmpty
                                          ? 'Milestone: Bath Completed • ${_formatMilestoneTimestamp(booking.bathCompletedAt!)}'
                                          : 'Milestone: Bath Completed')
                                    : (booking.groomingCompletedAt != null &&
                                              booking
                                                  .groomingCompletedAt!
                                                  .isNotEmpty
                                          ? 'Milestone: Grooming Completed • ${_formatMilestoneTimestamp(booking.groomingCompletedAt!)}'
                                          : 'Milestone: Grooming Completed')),
                          style: AppFonts.poppins(
                            size: 11.5,
                            weight: FontWeight.w600,
                            color: const Color(0xFF15803D),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (booking.bathNotes != null &&
                      booking.bathNotes!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '• Bath Notes: "${booking.bathNotes}"',
                      style: AppFonts.poppins(
                        size: 11,
                        color: const Color(0xFF166534),
                      ).copyWith(fontStyle: FontStyle.italic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (booking.groomingNotes != null &&
                      booking.groomingNotes!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '• Grooming Notes: "${booking.groomingNotes}"',
                      style: AppFonts.poppins(
                        size: 11,
                        color: const Color(0xFF166534),
                      ).copyWith(fontStyle: FontStyle.italic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Actions for confirmed bookings (Check In / Start Appointment / Disabled Time Badge)
          if (isConfirmed && booking.bookingId > 0) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: booking.canShowSkipOption
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (booking.canShowSkipOption) _buildSkipButton(booking),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isBookingDateToday(booking.bookingDate))
                      _buildWebMilestoneButton(booking)
                    else ...[
                      _buildWebMilestoneButton(booking),
                      const SizedBox(width: 8),
                      if (!booking.isCheckedIn)
                        Builder(
                          builder: (btnCtx) {
                            final canCheckIn = booking.canCheckIn() &&
                                !_processingBookingIds.contains(booking.bookingId);
                            final theme = Theme.of(btnCtx);
                            return ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                disabledBackgroundColor: const Color(0xFFE5E7EB),
                                disabledForegroundColor: const Color(0xFF9CA3AF),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                minimumSize: const Size(0, 36),
                              ),
                              onPressed: canCheckIn
                                  ? () => _handleCheckInBooking(booking)
                                  : null,
                              icon: Icon(
                                Icons.assignment_turned_in_outlined,
                                size: 16,
                                color: canCheckIn
                                    ? theme.colorScheme.onPrimary
                                    : const Color(0xFF9CA3AF),
                              ),
                              label: Text(
                                'Check In',
                                style: AppFonts.parkinsans(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: canCheckIn
                                      ? theme.colorScheme.onPrimary
                                      : const Color(0xFF9CA3AF),
                                ),
                              ),
                            );
                          },
                        )
                    else if (_isStartTimeReached(booking)) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF111827),
                          side: const BorderSide(color: Color(0xFF111827)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          minimumSize: const Size(0, 36),
                        ),
                        onPressed: () => _handleCheckInBooking(booking),
                        icon: const Icon(
                          Icons.checklist_rounded,
                          size: 15,
                          color: Color(0xFF111827),
                        ),
                        label: Text(
                          'Checklist',
                          style: AppFonts.poppins(
                            size: 12,
                            weight: FontWeight.w600,
                            color: const Color(0xFF111827),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF111827,
                          ), // Brand Deep Slate
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 7,
                          ),
                          minimumSize: const Size(0, 36),
                        ),
                        onPressed:
                            _processingBookingIds.contains(booking.bookingId)
                            ? null
                            : () => _handleStartBooking(booking),
                        icon: const Icon(
                          Icons.play_arrow_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Start Appointment',
                          style: AppFonts.poppins(
                            size: 12,
                            weight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ] else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 15,
                              color: Color(0xFF9CA3AF),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _getScheduledStatusText(booking),
                                style: AppFonts.poppins(
                                  size: 11.5,
                                  weight: FontWeight.w500,
                                  color: const Color(0xFF6B7280),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],

          // Actions for in-progress bookings (Milestones: Bath Done / Grooming Done / Complete Appointment)
          if ((isInProgress ||
                  isReadyForCheckout ||
                  booking.status.toLowerCase() == 'bath_completed' ||
                  booking.status.toLowerCase() == 'grooming_completed') &&
              !booking.isCompleted &&
              statusLower != 'completed' &&
              booking.bookingId > 0) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: booking.canShowSkipOption
                    ? WrapAlignment.spaceBetween
                    : WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (booking.canShowSkipOption) _buildSkipButton(booking),
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildWebMilestoneButton(booking),
                      if (!booking.areRequiredMilestonesCompleted) ...[
                        if (booking.nextPendingMilestone == 'bath_completed')
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(
                                0xFF0284C7,
                              ), // Blue for Bath
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              minimumSize: const Size(0, 36),
                            ),
                            onPressed: () => _handleMilestoneBooking(
                              booking,
                              MilestoneType.bath,
                            ),
                            icon: const Icon(
                              Icons.bathtub_outlined,
                              size: 17,
                              color: Colors.white,
                            ),
                            label: Text(
                              'Bath Done',
                              style: AppFonts.poppins(
                                size: 12,
                                weight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          )
                        else if (booking.nextPendingMilestone ==
                            'grooming_completed') ...[
                          if (booking.requiresBath && booking.isBathCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFBAE6FD),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 15,
                                    color: Color(0xFF0284C7),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Bath Done',
                                    style: AppFonts.poppins(
                                      size: 11.5,
                                      weight: FontWeight.w600,
                                      color: const Color(0xFF0284C7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(
                                0xFF7C3AED,
                              ), // Purple for Grooming
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              minimumSize: const Size(0, 36),
                            ),
                            onPressed: () => _handleMilestoneBooking(
                              booking,
                              MilestoneType.grooming,
                            ),
                            icon: const Icon(
                              Icons.content_cut_rounded,
                              size: 17,
                              color: Colors.white,
                            ),
                            label: Text(
                              'Grooming Done',
                              style: AppFonts.poppins(
                                size: 12,
                                weight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ] else if (!isReadyForCheckout) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 15,
                                color: Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                booking.requiresGrooming
                                    ? 'Grooming Done'
                                    : 'Bath Done',
                                style: AppFonts.poppins(
                                  size: 11.5,
                                  weight: FontWeight.w600,
                                  color: const Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF111827,
                            ), // Brand Deep Slate
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 34),
                          ),
                          onPressed:
                              _processingBookingIds.contains(booking.bookingId)
                              ? null
                              : () => _handleReadyForCheckoutBooking(booking),
                          icon:
                              _processingBookingIds.contains(booking.bookingId)
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.point_of_sale_rounded,
                                  size: 15,
                                  color: Colors.white,
                                ),
                          label: Text(
                            _processingBookingIds.contains(booking.bookingId)
                                ? 'Updating...'
                                : 'Ready for Checkout',
                            style: AppFonts.poppins(
                              size: 11.5,
                              weight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ] else if (isReadyForCheckout) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 15,
                                color: Color(0xFF111827),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Ready for Checkout',
                                style: AppFonts.poppins(
                                  size: 11.5,
                                  weight: FontWeight.w600,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1F2937),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 34),
                          ),
                          onPressed: () => _handleCompleteBooking(booking),
                          icon: const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                          label: Text(
                            'Complete',
                            style: AppFonts.poppins(
                              size: 11.5,
                              weight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ), // inner Wrap
                ],
              ), // outer Wrap
            ),
          ],

          // Actions for completed bookings (Official Receipt)
          if ((statusLower == 'completed' || booking.isCompleted) &&
              booking.bookingId > 0) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildWebMilestoneButton(booking),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: () {
                    final receipt = BookingReceipt.fromGroomerBooking(booking);
                    BookingReceiptPageMobile.show(context, receipt: receipt);
                  },
                  icon: const Icon(
                    Icons.receipt_long_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Receipt',
                    style: AppFonts.poppins(
                      size: 12,
                      weight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Actions for cancellation requested bookings
          if (isCancellationRequested && booking.bookingId > 0) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4B5563),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: () => _handleRejectCancellation(booking),
                  child: Text(
                    'Reject',
                    style: AppFonts.poppins(size: 12, weight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: () => _handleApproveCancellation(booking),
                  child: Text(
                    'Approve Cancellation',
                    style: AppFonts.poppins(
                      size: 12,
                      weight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
