import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/notifications/bloc/notification_bloc.dart';
import 'package:shear_heaven_pet_spa/src/notifications/repo/notification_repository.dart';
import 'package:shear_heaven_pet_spa/src/notifications/views/mobile/notifications_page_mobile.dart';

class _FakeNotificationRepository extends NotificationRepository {
  List<AppNotification> notificationsToReturn = [];

  @override
  Future<List<AppNotification>> getNotifications() async {
    return notificationsToReturn;
  }

  @override
  Future<bool> markAsRead(int notificationId) async => true;

  @override
  Future<bool> markAllAsRead() async => true;

  @override
  Future<void> connectRealtimeNotifications({String? token, String? serverUrl}) async {}

  @override
  void disconnectRealtimeNotifications() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeNotificationRepository fakeRepo;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() {
    fakeRepo = _FakeNotificationRepository();
  });

  group('NotificationsPageMobile UI Tests', () {
    testWidgets('Renders empty state on standard mobile size (390x844)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      fakeRepo.notificationsToReturn = [];

      final notifBloc = NotificationBloc(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NotificationBloc>.value(
            value: notifBloc,
            child: const NotificationsPageMobile(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Hero Status Banner
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('All caught up!'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);

      // Verify Category Filter Chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Unread'), findsOneWidget);
      expect(find.text('Bookings'), findsOneWidget);
      expect(find.text('Offers'), findsOneWidget);

      // Verify Empty State Card & Content
      expect(find.text('No Notifications Yet'), findsOneWidget);
      expect(find.text('Book Service'), findsOneWidget);
      expect(find.text('Spa Offers'), findsOneWidget);

      // Verify What to Expect Highlights
      expect(find.text('WHAT NOTIFICATIONS TO EXPECT'), findsOneWidget);
      expect(find.text('Live Grooming Status'), findsOneWidget);
      expect(find.text('Appointment Reminders'), findsOneWidget);
      expect(find.text('Exclusive Member Perks'), findsOneWidget);
      expect(find.text('Push notifications are enabled on this device'), findsOneWidget);
    });

    testWidgets('Renders empty state on ultra narrow screen (320x640) without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      fakeRepo.notificationsToReturn = [];

      final notifBloc = NotificationBloc(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NotificationBloc>.value(
            value: notifBloc,
            child: const NotificationsPageMobile(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('No Notifications Yet'), findsOneWidget);
      expect(find.text('WHAT NOTIFICATIONS TO EXPECT'), findsOneWidget);
    });

    testWidgets('Renders notifications list with category tags, relative dates, and filter chip filtering', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final now = DateTime.now();
      final notifications = [
        AppNotification(
          id: 101,
          title: 'Booking Confirmed #101',
          message: 'Your dog grooming session with Bella is confirmed.',
          type: 'booking',
          isRead: false,
          createdAt: now.subtract(const Duration(minutes: 5)),
          metadata: const {'bookingId': 101},
        ),
        AppNotification(
          id: 102,
          title: 'Special Weekend 20% Off',
          message: 'Enjoy 20% discount on Deluxe Pet Spa this weekend!',
          type: 'offer',
          isRead: true,
          createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        ),
      ];

      fakeRepo.notificationsToReturn = notifications;
      final notifBloc = NotificationBloc(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<NotificationBloc>.value(
            value: notifBloc,
            child: const NotificationsPageMobile(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify unread count badge in header
      expect(find.text('1 new'), findsOneWidget);
      expect(find.text('Mark all read'), findsOneWidget);

      // Verify rendered notification cards
      expect(find.text('Booking Confirmed #101'), findsOneWidget);
      expect(find.text('Special Weekend 20% Off'), findsOneWidget);
      expect(find.text('View Booking'), findsOneWidget);
      expect(find.text('View Offer'), findsOneWidget);

      // Test Category Filtering: tap 'Offers' filter
      await tester.tap(find.text('Offers'));
      await tester.pumpAndSettle();

      expect(find.text('Special Weekend 20% Off'), findsOneWidget);
      expect(find.text('Booking Confirmed #101'), findsNothing);

      // Test Category Filtering: tap 'Bookings' filter
      await tester.tap(find.text('Bookings'));
      await tester.pumpAndSettle();

      expect(find.text('Booking Confirmed #101'), findsOneWidget);
      expect(find.text('Special Weekend 20% Off'), findsNothing);
    });
  });
}
