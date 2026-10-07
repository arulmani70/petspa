import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/account/repos/notification_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';

class MockApiRepository extends ApiRepository {
  String? lastPutPath;
  Map<String, dynamic>? lastPutData;
  bool mockPutResult = true;
  bool shouldThrowPutError = false;

  String? lastGetPath;
  Map<String, dynamic>? mockGetResponse;

  String? lastDeletePath;
  Map<String, dynamic>? mockDeleteResponse;

  String? lastPostPath;
  Map<String, dynamic>? lastPostData;
  Map<String, dynamic>? mockPostResponse;

  @override
  Future<bool> put(String path, Map<String, dynamic> data) async {
    lastPutPath = path;
    lastPutData = data;
    if (shouldThrowPutError) {
      throw Exception('Network error');
    }
    return mockPutResult;
  }

  @override
  Future<Map<String, dynamic>?> get(String path, {Map<String, dynamic>? query}) async {
    lastGetPath = path;
    return mockGetResponse;
  }

  @override
  Future<bool> delete(String path) async {
    lastDeletePath = path;
    return true;
  }

  @override
  Future<Map<String, dynamic>?> post(String path, Map<String, dynamic> data) async {
    lastPostPath = path;
    lastPostData = data;
    return mockPostResponse ?? {'success': true, 'message': 'Success'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockApiRepository mockApi;
  late NotificationRepository repo;

  setUp(() async {
    await GetIt.instance.reset();
    SharedPreferences.setMockInitialValues({});
    final session = SessionService();
    await session.initialize();
    GetIt.instance.registerSingleton<SessionService>(session);

    mockApi = MockApiRepository();
    GetIt.instance.registerSingleton<ApiRepository>(mockApi);
    repo = NotificationRepository();
    await repo.initialize();
  });

  group('AppNotification Model Tests', () {
    test('parses complete notification JSON successfully', () {
      final json = {
        'id': 101,
        'userId': 2,
        'title': 'Appointment Booked',
        'message': "Teddy's Full Grooming is tomorrow at 10:30 AM.",
        'type': 'appointment',
        'isRead': false,
        'createdAt': '2026-08-22T10:30:00.000Z',
        'data': {'bookingId': 36},
      };

      final notification = AppNotification.fromJson(json);

      expect(notification.id, 101);
      expect(notification.userId, 2);
      expect(notification.title, 'Appointment Booked');
      expect(notification.message, "Teddy's Full Grooming is tomorrow at 10:30 AM.");
      expect(notification.type, 'appointment');
      expect(notification.isRead, false);
      expect(notification.createdAt, isNotNull);
      expect(notification.createdAt!.year, 2026);
      expect(notification.metadata?['bookingId'], 36);
    });

    test('parses notification with alternative keys and fallback defaults', () {
      final json = {
        'id': '202',
        'subject': 'Special Offer',
        'body': 'Get 20% off on your next grooming session!',
        'read': 'true',
        'created_at': '2026-08-21T15:00:00.000Z',
      };

      final notification = AppNotification.fromJson(json);

      expect(notification.id, 202);
      expect(notification.title, 'Special Offer');
      expect(notification.message, 'Get 20% off on your next grooming session!');
      expect(notification.type, 'general');
      expect(notification.isRead, true);
      expect(notification.createdAt, isNotNull);
    });

    test('handles empty or null fields gracefully without crashing', () {
      final json = <String, dynamic>{};

      final notification = AppNotification.fromJson(json);

      expect(notification.id, 0);
      expect(notification.userId, isNull);
      expect(notification.title, '');
      expect(notification.message, '');
      expect(notification.type, 'general');
      expect(notification.isRead, false);
      expect(notification.createdAt, isNull);
      expect(notification.metadata, isNull);
    });

    test('copyWith updates fields while preserving others', () {
      const notification = AppNotification(
        id: 1,
        title: 'Initial Title',
        message: 'Initial Message',
        isRead: false,
      );

      final updated = notification.copyWith(isRead: true);

      expect(updated.id, 1);
      expect(updated.title, 'Initial Title');
      expect(updated.message, 'Initial Message');
      expect(updated.isRead, true);
    });

    test('serializes to JSON correctly', () {
      final notification = AppNotification(
        id: 5,
        userId: 2,
        title: 'Booking Confirmed',
        message: 'Your booking has been confirmed.',
        type: 'confirmed',
        isRead: true,
        createdAt: DateTime.parse('2026-08-22T12:00:00.000Z'),
        metadata: {'bookingId': 12},
      );

      final json = notification.toJson();

      expect(json['id'], 5);
      expect(json['userId'], 2);
      expect(json['title'], 'Booking Confirmed');
      expect(json['message'], 'Your booking has been confirmed.');
      expect(json['type'], 'confirmed');
      expect(json['isRead'], true);
      expect(json['createdAt'], '2026-08-22T12:00:00.000Z');
      expect(json['data']?['bookingId'], 12);
    });
  });

  group('NotificationRepository Tests', () {
    test('initializes cleanly', () async {
      await expectLater(repo.initialize(), completes);
    });

    test('getNotifications returns list and updates unreadCountNotifier', () async {
      mockApi.mockGetResponse = {
        'success': true,
        'message': 'Notifications retrieved successfully',
        'data': [
          {
            'id': 1,
            'title': 'Test 1',
            'message': 'Message 1',
            'isRead': false,
          },
          {
            'id': 2,
            'title': 'Test 2',
            'message': 'Message 2',
            'isRead': false,
          },
          {
            'id': 3,
            'title': 'Test 3',
            'message': 'Message 3',
            'isRead': true,
          }
        ]
      };

      final result = await repo.getNotifications();

      expect(mockApi.lastGetPath, '/api/notifications');
      expect(result.length, 3);
      expect(repo.unreadCount, 2);
      expect(repo.unreadCountNotifier.value, 2);
    });

    test('markAsRead calls PUT /api/notifications/:id/read and decrements unreadCount', () async {
      repo.unreadCountNotifier.value = 2;
      mockApi.mockPutResult = true;

      final result = await repo.markAsRead(42);

      expect(mockApi.lastPutPath, '/api/notifications/42/read');
      expect(result, isTrue);
      expect(repo.unreadCountNotifier.value, 1);
    });

    test('markAllAsRead calls PUT /api/notifications/read-all and resets unreadCount to 0', () async {
      repo.unreadCountNotifier.value = 5;
      mockApi.mockPutResult = true;

      final result = await repo.markAllAsRead();

      expect(mockApi.lastPutPath, '/api/notifications/read-all');
      expect(result, isTrue);
      expect(repo.unreadCountNotifier.value, 0);
    });

    test('deleteNotification calls DELETE /api/notifications/:id', () async {
      final result = await repo.deleteNotification(101);

      expect(mockApi.lastDeletePath, '/api/notifications/101');
      expect(result, isTrue);
    });

    test('registerDeviceToken calls POST /api/notifications/device-token', () async {
      const testDeviceId = '550e8400-e29b-41d4-a716-446655440000';
      const testPushToken = 'fK8l29xM_mock_test_token_9988_real_shape';

      final result = await repo.registerDeviceToken(
        deviceId: testDeviceId,
        pushToken: testPushToken,
        platform: 'android',
      );

      expect(mockApi.lastPostPath, '/api/notifications/device-token');
      expect(mockApi.lastPostData?['deviceId'], testDeviceId);
      expect(mockApi.lastPostData?['pushToken'], testPushToken);
      expect(result, isTrue);
    });
  });
}
