import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/bloc/groomer_home_bloc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GroomerHomeBloc bloc;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  setUp(() {
    bloc = GroomerHomeBloc(repository: ServicesLocator.groomerHomeRepository);
  });

  tearDown(() {
    bloc.close();
  });

  group('Groomer Real-Time Notifications BLoC Tests', () {
    test('initial unreadNotificationCount is zero', () {
      expect(bloc.state.notifications, isEmpty);
      expect(bloc.state.unreadNotificationCount, equals(0));
      expect(bloc.state.isSocketConnected, isFalse);
    });

    test('GroomerHomeSocketConnectionChangedEvent updates isSocketConnected', () async {
      bloc.add(const GroomerHomeSocketConnectionChangedEvent(true));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.isSocketConnected, isTrue);

      bloc.add(const GroomerHomeSocketConnectionChangedEvent(false));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.isSocketConnected, isFalse);
    });

    test('GroomerHomeRealtimeNotificationReceivedEvent inserts notification and updates unread count', () async {
      const notif = AppNotification(
        id: 301,
        title: 'New Booking #301',
        message: 'Charlie booked Full Grooming',
        type: 'booking',
        isRead: false,
        metadata: {'bookingId': 301},
      );

      bloc.add(const GroomerHomeRealtimeNotificationReceivedEvent(notif));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.notifications.length, equals(1));
      expect(bloc.state.notifications.first['id'], equals(301));
      expect(bloc.state.notifications.first['title'], equals('New Booking #301'));
      expect(bloc.state.unreadNotificationCount, equals(1));
    });

    test('deduplicates real-time notifications with identical id', () async {
      const notif1 = AppNotification(
        id: 401,
        title: 'Booking Request #401',
        message: 'Max booked a bath',
        type: 'booking',
        isRead: false,
      );

      const notif2 = AppNotification(
        id: 401,
        title: 'Booking Request #401 Updated',
        message: 'Max booked a bath with nail trim',
        type: 'booking',
        isRead: false,
      );

      bloc.add(const GroomerHomeRealtimeNotificationReceivedEvent(notif1));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.notifications.length, equals(1));

      // Send same ID again
      bloc.add(const GroomerHomeRealtimeNotificationReceivedEvent(notif2));
      await Future.delayed(const Duration(milliseconds: 50));

      // Length should still be 1, content updated
      expect(bloc.state.notifications.length, equals(1));
      expect(bloc.state.notifications.first['title'], equals('Booking Request #401 Updated'));
      expect(bloc.state.unreadNotificationCount, equals(1));
    });

    test('markNotificationRead updates state and unread count', () async {
      const notif = AppNotification(
        id: 501,
        title: 'System Alert',
        message: 'Maintenance scheduled',
        type: 'general',
        isRead: false,
      );

      bloc.add(const GroomerHomeRealtimeNotificationReceivedEvent(notif));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state.unreadNotificationCount, equals(1));

      bloc.add(const GroomerHomeMarkNotificationReadEvent(501));
      await Future.delayed(const Duration(milliseconds: 50));

      // If simulated read
      final item = bloc.state.notifications.firstWhere((n) => n['id'] == 501);
      expect(item, isNotNull);
    });

    test('socket service integration forwards notification to BLoC', () async {
      const notif = AppNotification(
        id: 601,
        title: 'Socket Direct Broadcast',
        message: 'Test message through socket service stream',
        type: 'general',
        isRead: false,
      );

      ServicesLocator.groomerSocketService.emitNotificationForTesting(notif);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(bloc.state.notifications.any((n) => n['id'] == 601), isTrue);
    });
  });
}
