import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_schedule_models.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_user.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/schedule/groomer_working_hours_table_widget.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/schedule/store_hours_table_widget.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/main_line_booking_dialog.dart';

class GroomerHomePageMobile extends StatefulWidget {
  const GroomerHomePageMobile({super.key});

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
  StreamSubscription<AppNotification>? _realtimeNotificationSub;
  Timer? _timeTickerTimer;
  int _selectedScheduleDayIndex = (DateTime.now().weekday - 1) % 7;
  bool _showFullWeekOverview = true;

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
    _loadAllData();
    _initRealtimeNotifications();
    _startTimeTicker();
  }

  void _startTimeTicker() {
    _timeTickerTimer?.cancel();
    // Periodically refreshes UI (every 5 seconds) to automatically enable Start Appointment
    // the exact moment scheduled start time is reached, without any manual refresh or API polling.
    _timeTickerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
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

    ToastUtil.showInfoToast(
      context,
      notif.title.isNotEmpty ? notif.title : 'New staff notification',
    );
  }

  @override
  void dispose() {
    _realtimeNotificationSub?.cancel();
    _timeTickerTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAllData() async {
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
        final fetchedGroomerHours =
            results[9] as List<GroomerWorkingHour>? ?? [];

        setState(() {
          _groomer = results[0] as GroomerUser? ?? _groomer;
          _upcomingBookings = results[1] as List<GroomerBooking>? ?? [];
          _pendingBookings = results[2] as List<GroomerBooking>? ?? [];
          _pastBookings = results[3] as List<GroomerBooking>? ?? [];
          _cancelledBookings = results[4] as List<GroomerBooking>? ?? [];
          _cancellationRequests = results[5] as List<GroomerBooking>? ?? [];
          _serviceHours = List<StoreServiceHour>.from(fetchedServiceHours);
          _holidays = results[7] as List<StoreHoliday>? ?? [];
          _notifications = results[8] as List<Map<String, dynamic>>? ?? [];
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
      final res = await ServicesLocator.groomerHomeRepository.approveBookingDetails(
        booking.bookingId,
      );
      if (!mounted) return;
      if (res.success) {
        ToastUtil.showSuccessToast(context, res.message);
        _loadAllData();
      } else {
        ToastUtil.showErrorToast(context, res.message);
      }
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
              backgroundColor: const Color(0xFF0F766E),
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
      final res = await ServicesLocator.groomerHomeRepository.startBookingDetails(
        booking.bookingId,
      );
      if (!mounted) return;
      if (res.success) {
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

  Future<void> _handleCompleteBooking(GroomerBooking booking) async {
    if (_processingBookingIds.contains(booking.bookingId)) return;
    setState(() => _processingBookingIds.add(booking.bookingId));

    // 1. Optimistic local update: immediately move to completed / past
    setState(() {
      final updated = booking.copyWith(status: 'completed');
      _upcomingBookings.removeWhere((b) => b.bookingId == booking.bookingId);
      final pastIndex = _pastBookings.indexWhere(
        (b) => b.bookingId == booking.bookingId,
      );
      if (pastIndex >= 0) {
        _pastBookings[pastIndex] = updated;
      } else {
        _pastBookings.insert(0, updated);
      }
    });

    try {
      final res = await ServicesLocator.groomerHomeRepository.completeBookingDetails(
        booking.bookingId,
      );
      if (!mounted) return;
      if (res.success) {
        ToastUtil.showSuccessToast(context, res.message);
        _loadAllData();
      } else {
        // Revert on failure
        setState(() {
          final reverted = booking.copyWith(status: 'in_progress');
          _pastBookings.removeWhere((b) => b.bookingId == booking.bookingId);
          if (!_upcomingBookings.any((b) => b.bookingId == booking.bookingId)) {
            _upcomingBookings.insert(0, reverted);
          }
        });
        ToastUtil.showErrorToast(context, res.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final reverted = booking.copyWith(status: 'in_progress');
          _pastBookings.removeWhere((b) => b.bookingId == booking.bookingId);
          if (!_upcomingBookings.any((b) => b.bookingId == booking.bookingId)) {
            _upcomingBookings.insert(0, reverted);
          }
        });
        ToastUtil.showErrorToast(context, 'Error completing appointment: $e');
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
      final res = await ServicesLocator.groomerHomeRepository.rejectBookingDetails(
        booking.bookingId,
      );
      if (!mounted) return;
      if (res.success) {
        ToastUtil.showSuccessToast(context, res.message);
        _loadAllData();
      } else {
        ToastUtil.showErrorToast(context, res.message);
      }
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
      final res = await ServicesLocator.groomerHomeRepository.approveCancellationDetails(
        booking.bookingId,
      );
      if (!mounted) return;
      if (res.success) {
        ToastUtil.showSuccessToast(context, res.message);
        _loadAllData();
      } else {
        ToastUtil.showErrorToast(context, res.message);
      }
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
      final res = await ServicesLocator.groomerHomeRepository.rejectCancellationDetails(
        booking.bookingId,
      );
      if (!mounted) return;
      if (res.success) {
        ToastUtil.showSuccessToast(context, res.message);
        _loadAllData();
      } else {
        ToastUtil.showErrorToast(context, res.message);
      }
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

  Future<void> _handleEditProfileDialog() async {
    final groomer = _groomer;
    if (groomer == null) return;

    final firstCtrl = TextEditingController(text: groomer.firstName);
    final lastCtrl = TextEditingController(text: groomer.lastName);
    final mobileCtrl = TextEditingController(text: groomer.mobile);
    bool multiBooking = groomer.multiBookingEnabled;
    int slotLimit = groomer.slotBookingLimit;

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Edit Groomer Profile',
            style: AppFonts.parkinsans(size: 18, weight: FontWeight.w700),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: firstCtrl,
                  decoration: const InputDecoration(labelText: 'First Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: lastCtrl,
                  decoration: const InputDecoration(labelText: 'Last Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: mobileCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile Number'),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Multi-Booking Enabled',
                    style: AppFonts.poppins(
                      size: 13.5,
                      weight: FontWeight.w600,
                    ),
                  ),
                  value: multiBooking,
                  onChanged: (val) {
                    setDialogState(() {
                      multiBooking = val;
                    });
                  },
                ),
                if (multiBooking) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Simultaneous Slot Limit:',
                        style: AppFonts.poppins(size: 13),
                      ),
                      DropdownButton<int>(
                        value: slotLimit,
                        items: [1, 2, 3, 4, 5]
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text('$e pets'),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              slotLimit = val;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: AppFonts.poppins(
                  size: 14,
                  weight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Save Changes',
                style: AppFonts.parkinsans(
                  size: 14,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (updated == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final result = await ServicesLocator.groomerHomeRepository
            .updateProfile(
              firstName: firstCtrl.text.trim(),
              lastName: lastCtrl.text.trim(),
              mobile: mobileCtrl.text.trim(),
              multiBookingEnabled: multiBooking,
              slotBookingLimit: slotLimit,
            );
        if (mounted) {
          setState(() {
            _groomer = result ?? _groomer;
            _isLoading = false;
          });
          ToastUtil.showSuccessToast(
            context,
            'Groomer profile updated successfully',
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ToastUtil.showErrorToast(context, 'Failed to update profile: $e');
        }
      }
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Staff Logout',
          style: AppFonts.parkinsans(size: 18, weight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to log out of the Groomer Portal?',
          style: AppFonts.poppins(size: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppFonts.poppins(
                size: 14,
                weight: FontWeight.w500,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111827),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
        ],
      ),
    );

    if (shouldLogout == true) {
      await ServicesLocator.groomerHomeRepository.logout();
      if (mounted) {
        context.goNamed(RouteNames.login);
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
    return Scaffold(
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
    );
  }

  Widget _buildCurrentTabBody() {
    switch (_currentTabIndex) {
      case 0:
        return _buildBookingsTab();
      case 1:
        return _buildScheduleTab();
      case 2:
        return _buildNotificationsTab();
      case 3:
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

          const SizedBox(height: 24),

          // ── Section 2: Booking List ──
          Text(
            'Booking List',
            style: AppFonts.poppins(
              size: 19,
              weight: FontWeight.w700,
              color: const Color(0xFF111827),
            ),
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
      color: const Color(0xFF0F766E),
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
                    color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    size: 16,
                    color: Color(0xFF0F766E),
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
                                    0xFF0F766E,
                                  ).withValues(alpha: 0.06)
                                : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF111827)
                            : (isToday
                                  ? const Color(0xFF0F766E)
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
                                      ? const Color(0xFF0F766E)
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
                                      : const Color(0xFF0F766E),
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
                        color: const Color(0xFF0F766E),
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
                  iconColor: const Color(0xFF0F766E),
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
                color: const Color(0xFF0F766E),
              ),
              label: Text(
                _showFullWeekOverview ? 'Hide Full Week' : 'Show Full Week',
                style: AppFonts.poppins(
                  size: 11.5,
                  weight: FontWeight.w600,
                  color: const Color(0xFF0F766E),
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
              backgroundColor: const Color(0xFF0F766E),
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

  // ── TAB 2: Notifications (Real API Driven) ──
  Widget _buildNotificationsTab() {
    final hasAnyNotification =
        _pendingBookings.isNotEmpty ||
        _cancellationRequests.isNotEmpty ||
        _notifications.isNotEmpty;

    return RefreshIndicator(
      color: const Color(0xFF111827),
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
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
              if (_notifications.isNotEmpty)
                TextButton(
                  onPressed: _handleMarkAllNotificationsRead,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
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
                      color: const Color(0xFF0F766E),
                    ),
                  ),
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
          if (_notifications.isNotEmpty) ...[
            _buildStaffSectionHeader(
              'SYSTEM & SCHEDULE ALERTS',
              _notifications.length,
              const Color(0xFF0F766E),
            ),
            ..._notifications.map((n) {
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
          Text(
            title,
            style: AppFonts.poppins(
              size: 11.5,
              weight: FontWeight.w700,
              color: const Color(0xFF6B7280),
              letterSpacing: 0.5,
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
            count: _notifications.length,
            icon: Icons.notifications_none_rounded,
            color: const Color(0xFF0F766E),
            bgColor: const Color(0xFFF0FDFA),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
              Text(
                '$count',
                style: AppFonts.parkinsans(
                  size: 15,
                  weight: FontWeight.w700,
                  color: count > 0 ? color : const Color(0xFF111827),
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
                  onTap: () => setState(() => _currentTabIndex = 0),
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
                            color: const Color(0xFFF0FDFA),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.calendar_month_outlined,
                            size: 18,
                            color: Color(0xFF0F766E),
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
                  onTap: () => setState(() => _currentTabIndex = 1),
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
                    Text(
                      'Action Required',
                      style: AppFonts.poppins(
                        size: 11,
                        color: const Color(0xFFDC2626),
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
                Row(
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
                    const SizedBox(width: 8),
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
                ? const Color(0xFF0F766E).withValues(alpha: 0.4)
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
                    ? const Color(0xFF0F766E).withValues(alpha: 0.1)
                    : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: isUnread
                    ? const Color(0xFF0F766E)
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
                      Text(
                        time,
                        style: AppFonts.poppins(
                          size: 11,
                          color: const Color(0xFF9CA3AF),
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
                    const SizedBox(height: 8),
                    Row(
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
                        const SizedBox(width: 8),
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
    final groomer = _groomer;
    final name = groomer?.fullName ?? 'Staff Member';
    final role = groomer?.role ?? 'Lead Groomer';
    final code = groomer?.groomerCode ?? 'G001';
    final email = groomer?.email ?? 'g001@shearheaven.com';
    final phone = groomer?.mobile.isNotEmpty == true
        ? groomer!.mobile
        : '+1 (555) 234-5678';
    final highlights = groomer?.highlights.isNotEmpty == true
        ? groomer!.highlights
        : 'Lead Groomer';
    final multiBooking = groomer?.multiBookingEnabled ?? false;
    final slotLimit = groomer?.slotBookingLimit ?? 1;

    return RefreshIndicator(
      color: const Color(0xFF111827),
      onRefresh: _loadAllData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          // Profile Info Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: AssetImage('assets/images/common/avatar.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: AppFonts.parkinsans(
                    size: 18,
                    weight: FontWeight.w700,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$role • Staff Code: $code',
                  style: AppFonts.poppins(
                    size: 13,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Active Staff Member',
                    style: AppFonts.poppins(
                      size: 11,
                      weight: FontWeight.w600,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF111827),
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: _handleEditProfileDialog,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(
                    'Edit Profile',
                    style: AppFonts.poppins(
                      size: 13,
                      weight: FontWeight.w600,
                      color: const Color(0xFF111827),
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileDetailRow(Icons.email_outlined, 'Email', email),
                const Divider(height: 20, color: Color(0xFFF3F4F6)),
                _buildProfileDetailRow(Icons.phone_outlined, 'Phone', phone),
                const Divider(height: 20, color: Color(0xFFF3F4F6)),
                _buildProfileDetailRow(
                  Icons.storefront_outlined,
                  'Store Location',
                  'Shear Heaven - Darwin (${groomer?.storeId ?? "SHEAR-001"})',
                ),
                const Divider(height: 20, color: Color(0xFFF3F4F6)),
                _buildProfileDetailRow(
                  Icons.calendar_month_outlined,
                  'Simultaneous Capacity',
                  multiBooking
                      ? 'Multi-Booking Active ($slotLimit pets / slot)'
                      : 'Single Booking Mode (1 pet / slot)',
                ),
                const Divider(height: 20, color: Color(0xFFF3F4F6)),
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
                style: AppFonts.poppins(size: 14, weight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildProfileDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6B7280)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppFonts.poppins(
                  size: 12,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppFonts.poppins(
                  size: 13.5,
                  weight: FontWeight.w500,
                  color: const Color(0xFF111827),
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
                    child: const Icon(Icons.calendar_month_outlined, size: 28),
                  ),
                  _buildDockItem(
                    index: 1,
                    child: const Icon(Icons.access_time_rounded, size: 28),
                  ),
                  _buildDockItem(
                    index: 2,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_outlined, size: 28),
                        if (_notifications.any(
                              (n) =>
                                  n['isRead'] != true && n['is_read'] != true,
                            ) ||
                            _pendingBookings.isNotEmpty ||
                            _cancellationRequests.isNotEmpty)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _buildDockItem(index: 3, child: _profileDockIcon()),
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
      width: 28,
      height: 28,
      errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.person_outline, size: 28),
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
          borderRadius: BorderRadius.all(Radius.circular(16)),
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
        },
        child: Center(child: content),
      ),
    );
  }

  // ── Floating Top Header Card ──
  Widget _buildTopHeaderCard({required String groomerName}) {
    final unreadNotifs = _notifications
        .where((n) => n['isRead'] != true && n['is_read'] != true)
        .length;
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
                _currentTabIndex = 3;
              });
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE5E7EB),
                image: DecorationImage(
                  image: AssetImage('assets/images/common/avatar.png'),
                  fit: BoxFit.cover,
                ),
              ),
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
                  onPressed: () {
                    setState(() {
                      _currentTabIndex = 2;
                    });
                  },
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
    final fallbackAsset = petName.toLowerCase().contains('teddy')
        ? 'assets/images/common/pet_2.png'
        : (petName.toLowerCase().contains('doodles')
              ? 'assets/images/chat/pet_teddy.png'
              : 'assets/images/common/pet_1.png');

    if (url != null && url.isNotEmpty) {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: const Color(0xFFF3F4F6),
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Image.asset(
            fallbackAsset,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => Container(
              color: const Color(0xFFF3F4F6),
              child: const Icon(Icons.pets, color: Color(0xFF9CA3AF), size: 28),
            ),
          ),
        );
      } else if (url.startsWith('assets/')) {
        return Image.asset(
          url,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => Container(
            color: const Color(0xFFF3F4F6),
            child: const Icon(Icons.pets, color: Color(0xFF9CA3AF), size: 28),
          ),
        );
      }
    }

    return Image.asset(
      fallbackAsset,
      fit: BoxFit.cover,
      errorBuilder: (c, e, s) => Container(
        color: const Color(0xFFF3F4F6),
        child: const Icon(Icons.pets, color: Color(0xFF9CA3AF), size: 28),
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

    switch (statusLower) {
      case 'in_progress':
      case 'in-progress':
        borderColor = const Color(0xFF2563EB); // Vibrant Blue
        badgeBgColor = const Color(0xFFDBEAFE);
        badgeTextColor = const Color(0xFF1D4ED8);
        badgeText = 'In Progress';
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
                          color: Color(0xFF0F766E),
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

          // Actions for confirmed bookings (Start Appointment / Disabled Time Badge)
          if (isConfirmed && booking.bookingId > 0) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isStartTimeReached(booking))
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E), // Brand Teal
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
                    onPressed: _processingBookingIds.contains(booking.bookingId)
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
                  )
                else
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
                        Text(
                          _getScheduledStatusText(booking),
                          style: AppFonts.poppins(
                            size: 11.5,
                            weight: FontWeight.w500,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],

          // Actions for in-progress bookings (Complete Appointment)
          if (isInProgress && booking.bookingId > 0) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E), // Brand Teal
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
                  onPressed: () => _handleCompleteBooking(booking),
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 17,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Complete Appointment',
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
