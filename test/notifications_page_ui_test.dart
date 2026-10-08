import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
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
    final sessionService = SessionService();
    await sessionService.initialize();
    if (!serviceLocator.isRegistered<SessionService>()) {
      serviceLocator.registerSingleton<SessionService>(sessionService);
    }
    await sessionService.saveSession({'id': 1, 'name': 'Alexander'});
    await sessionService.saveTokens(accessToken: 'mock_token', refreshToken: 'mock_refresh');
  });

  setUp(() {
    fakeRepo = _FakeNotificationRepository();
    if (!serviceLocator.isRegistered<NotificationRepository>()) {
      serviceLocator.registerSingleton<NotificationRepository>(fakeRepo);
    }
  });

  group('NotificationsPageMobile UI Tests', () {
    testWidgets('Renders notifications list and Mark as read all button', (tester) async {
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

      // Verify AppBar Title and Mark as read all button
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Mark as read all'), findsOneWidget);

      // Verify grouped headers & notification cards
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('EARLIER'), findsOneWidget);
      expect(find.text('Booking Confirmed #101'), findsOneWidget);
      expect(find.text('Special Weekend 20% Off'), findsOneWidget);

      // Tap 'Mark as read all'
      await tester.tap(find.text('Mark as read all'));
      await tester.pumpAndSettle();

      // Verify bloc state or UI updated
      expect(notifBloc.state.unreadCount, 0);
    });
  });
}
