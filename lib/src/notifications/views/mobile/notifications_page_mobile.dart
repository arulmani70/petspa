import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/app/route_names.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
import 'package:shear_heaven_pet_spa/src/notifications/bloc/notification_bloc.dart';

class NotificationsPageMobile extends StatefulWidget {
  const NotificationsPageMobile({super.key});

  @override
  State<NotificationsPageMobile> createState() => _NotificationsPageMobileState();
}

class _NotificationsPageMobileState extends State<NotificationsPageMobile> {
  @override
  void initState() {
    super.initState();
    if (ServicesLocator.sessionService.isLoggedIn) {
      context.read<NotificationBloc>().add(const FetchNotifications());
      context.read<NotificationBloc>().add(const NotificationConnectSocketEvent());
    }
  }

  Future<void> _handleRefresh() async {
    context.read<NotificationBloc>().add(const FetchNotifications());
  }

  void _onNotificationTap(AppNotification notification) {
    if (!notification.isRead) {
      context.read<NotificationBloc>().add(MarkNotificationRead(notification.id));
    }

    final metadata = notification.metadata;
    final rawBookingId = metadata?['bookingId'] ??
        metadata?['booking_id'] ??
        metadata?['entityId'];
    final type = notification.type.toLowerCase();

    if (rawBookingId != null ||
        type.contains('booking') ||
        type.contains('appointment') ||
        type.contains('confirm') ||
        type.contains('groom')) {
      context.pushNamed(RouteNames.myBookings);
    } else if (type.contains('offer') || type.contains('promo') || type.contains('discount')) {
      context.pushNamed(RouteNames.offers);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ServicesLocator.sessionService.isLoggedIn) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black, size: 22),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.goNamed(RouteNames.home);
              }
            },
          ),
          title: Text(
            'Notifications',
            style: AppFonts.parkinsans(
              size: 20,
              weight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          centerTitle: false,
        ),
        body: _buildGuestState(),
      );
    }

    return BlocConsumer<NotificationBloc, NotificationState>(
      listener: (context, state) {
        if (state.status == NotificationStatus.failure && state.message.isNotEmpty) {
          ToastUtil.showErrorToast(context, state.message);
        }
      },
      builder: (context, state) {
        final rawNotifications = state.notifications;
        final notifications = rawNotifications.isNotEmpty
            ? rawNotifications
            : _getMockNotifications();

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black, size: 22),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.goNamed(RouteNames.home);
                }
              },
            ),
            title: Text(
              'Notifications',
              style: AppFonts.parkinsans(
                size: 20,
                weight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            centerTitle: false,
          ),
          body: RefreshIndicator(
            onRefresh: _handleRefresh,
            color: Colors.black,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 130.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildGroupedNotificationList(notifications),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildGroupedNotificationList(List<AppNotification> notifications) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayNotifs = <AppNotification>[];
    final earlierNotifs = <AppNotification>[];

    for (final n in notifications) {
      if (n.createdAt == null) {
        earlierNotifs.add(n);
        continue;
      }
      final local = n.createdAt!.toLocal();
      final dateOnly = DateTime(local.year, local.month, local.day);

      if (dateOnly == today) {
        todayNotifs.add(n);
      } else {
        earlierNotifs.add(n);
      }
    }

    final widgets = <Widget>[];

    if (todayNotifs.isNotEmpty) {
      widgets.add(_buildSectionHeader('TODAY'));
      for (int i = 0; i < todayNotifs.length; i++) {
        widgets.add(_buildNotificationItem(todayNotifs[i]));
        if (i < todayNotifs.length - 1 || earlierNotifs.isNotEmpty) {
          widgets.add(const Divider(height: 24, thickness: 1, color: Color(0xFFEEEEEE)));
        }
      }
    }

    if (earlierNotifs.isNotEmpty) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(_buildSectionHeader('EARLIER'));
      for (int i = 0; i < earlierNotifs.length; i++) {
        widgets.add(_buildNotificationItem(earlierNotifs[i]));
        if (i < earlierNotifs.length - 1) {
          widgets.add(const Divider(height: 24, thickness: 1, color: Color(0xFFEEEEEE)));
        }
      }
    }

    widgets.add(const SizedBox(height: 32));
    return widgets;
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        title,
        style: AppFonts.poppins(
          size: 13,
          weight: FontWeight.w600,
          color: const Color(0xFF1E1E1E),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildNotificationItem(AppNotification n) {
    final isRead = n.isRead;
    final iconData = _iconForType(n.type, n.title);
    final timeStr = _formatNotificationTime(n.createdAt);

    return InkWell(
      onTap: () => _onNotificationTap(n),
      splashColor: Colors.transparent,
      highlightColor: const Color(0xFFF9F9F9),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Circular Avatar with hash/ash background and black icon
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFF2F2F2), // hash/ash color matching brand theme
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  iconData,
                  size: 22,
                  color: Colors.black, // black color for all icons
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Content column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: AppFonts.parkinsans(
                            size: 16,
                            weight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      if (!isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD32F2F), // unread red indicator dot
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    n.message,
                    style: AppFonts.poppins(
                      size: 13,
                      weight: FontWeight.w400,
                      color: const Color(0xFF4A4A4A),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    timeStr,
                    style: AppFonts.poppins(
                      size: 12,
                      weight: FontWeight.w400,
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type, String title) {
    final t = '${type.toLowerCase()} ${title.toLowerCase()}';
    if (t.contains('offer') || t.contains('promo') || t.contains('discount') || t.contains('weekend')) {
      return Icons.calendar_month_outlined;
    }
    if (t.contains('groom') || t.contains('complete') || t.contains('ready') || t.contains('spa')) {
      return Icons.calendar_month_outlined;
    }
    if (t.contains('reminder') || t.contains('time') || t.contains('clock')) {
      return Icons.calendar_month_outlined;
    }
    if (t.contains('confirm') || t.contains('booked') || t.contains('appointment') || t.contains('booking')) {
      return Icons.calendar_month_outlined;
    }
    return Icons.calendar_month_outlined;
  }

  String _formatNotificationTime(DateTime? dateTime) {
    if (dateTime == null) return '2 hours ago';
    final now = DateTime.now();
    final localDt = dateTime.toLocal();
    final diff = now.difference(localDt);

    if (diff.inSeconds < 60 && diff.inSeconds >= 0) {
      return 'Just now';
    } else if (diff.inMinutes < 60 && diff.inMinutes >= 1) {
      return '${diff.inMinutes} mins ago';
    } else if (diff.inHours < 24 && diff.inHours >= 1) {
      return '${diff.inHours} hours ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return DateFormat('d MMM yyyy').format(localDt);
    }
  }

  List<AppNotification> _getMockNotifications() {
    final now = DateTime.now();
    return [
      AppNotification(
        id: 1,
        title: 'Appointment Booked',
        message: "Teddy's Full Grooming is tomorrow at 10:30 AM. See you soon!",
        createdAt: now.subtract(const Duration(hours: 2)),
        isRead: false,
        type: 'booking',
      ),
      AppNotification(
        id: 2,
        title: 'Booking Confirmed',
        message: "Teddy's Full Grooming is tomorrow at 10:30 AM. See you soon!",
        createdAt: now.subtract(const Duration(hours: 2)),
        isRead: true,
        type: 'confirm',
      ),
      AppNotification(
        id: 3,
        title: 'Weekend Offer',
        message: "Teddy's Full Grooming is tomorrow at 10:30 AM. See you soon!",
        createdAt: now.subtract(const Duration(days: 2)),
        isRead: true,
        type: 'offer',
      ),
      AppNotification(
        id: 4,
        title: 'Grooming Complete',
        message: "Teddy's Full Grooming is tomorrow at 10:30 AM. See you soon!",
        createdAt: now.subtract(const Duration(days: 2)),
        isRead: true,
        type: 'complete',
      ),
      AppNotification(
        id: 5,
        title: 'Appointment Reminder',
        message: "Teddy's Full Grooming is tomorrow at 10:30 AM. See you soon!",
        createdAt: now.subtract(const Duration(days: 2)),
        isRead: true,
        type: 'reminder',
      ),
    ];
  }

  Widget _buildGuestState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_outlined,
                size: 46,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sign In to View Notifications',
              style: AppFonts.parkinsans(
                size: 20,
                weight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to get instant updates about your appointments, special offers, and spa announcements.',
              style: AppFonts.poppins(
                size: 14,
                color: const Color(0xFF6B7280),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(60),
                  ),
                ),
                onPressed: () => context.pushNamed(RouteNames.login),
                child: Text(
                  'Sign In / Register',
                  style: AppFonts.parkinsans(
                    size: 16,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
