import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/account/models/app_notification.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/groomer_milestone_dialog.dart';

class _MockApiRepository extends ApiRepository {
  String? lastPutPath;
  dynamic lastPutData;
  String? lastPostPath;
  dynamic lastPostData;
  bool shouldFail = false;
  int putCallCount = 0;
  int postCallCount = 0;

  void reset() {
    lastPutPath = null;
    lastPutData = null;
    lastPostPath = null;
    lastPostData = null;
    shouldFail = false;
    putCallCount = 0;
    postCallCount = 0;
  }

    @override
  Future<Map<String, dynamic>?> get(String path, {Map<String, dynamic>? query}) async {
    return {'success': true, 'data': []};
  }

  @override
  Future<Map<String, dynamic>?> putData(String path, Map<String, dynamic> data) async {
    lastPutPath = path;
    lastPutData = data;
    putCallCount++;

    if (shouldFail) {
      return {
        'success': false,
        'message': 'Failed to update progress on backend',
        'statusCode': 500,
      };
    }

    final taskKey = data['taskKey']?.toString() ?? 'svc-1-bath';
    final percent = data['percent'] is int ? data['percent'] as int : int.tryParse(data['percent'].toString()) ?? 0;
    final notes = data['notes']?.toString();

    return {
      'success': true,
      'message': percent >= 100 ? 'Milestone completed' : 'Progress updated to $percent%',
      'data': {
        'serviceProgress': [
          {
            'taskKey': taskKey,
            'skipAllowed': true,
            'durationMinutes': 30,
            'percent': percent,
            'status': percent >= 100 ? 'completed' : 'in_progress',
            'notes': notes,
          }
        ]
      }
    };
  }

  @override
  Future<Map<String, dynamic>?> post(String path, dynamic data, {Map<String, dynamic>? query}) async {
    lastPostPath = path;
    lastPostData = data;
    postCallCount++;

    if (shouldFail) {
      return {
        'success': false,
        'message': 'Failed to skip task on backend',
        'statusCode': 500,
      };
    }

    final taskKey = (data is Map) ? data['taskKey']?.toString() ?? 'svc-1-bath' : 'svc-1-bath';
    final reason = (data is Map) ? data['reason']?.toString() : null;

    return {
      'success': true,
      'message': 'Task skipped successfully',
      'data': {
        'serviceProgress': [
          {
            'taskKey': taskKey,
            'skipAllowed': true,
            'durationMinutes': 30,
            'percent': 0,
            'status': 'skipped',
            'reason': reason,
          }
        ]
      }
    };
  }
}

late _MockApiRepository _mockApi;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();

    if (GetIt.I.isRegistered<ApiRepository>()) {
      GetIt.I.unregister<ApiRepository>();
    }
    _mockApi = _MockApiRepository();
    GetIt.I.registerSingleton<ApiRepository>(_mockApi);
  });

  setUp(() {
    _mockApi.reset();
  });

  group('Scenario 1 & 2: Incremental Service Progress Updates & Notifications', () {
    test('1. Update Bath progress to 30% and verify backend response & customer notification', () async {
      const initialBooking = GroomerBooking(
        bookingId: 101,
        status: 'checked_in',
        bookingDate: '2026-10-22',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Rocky',
        customerName: 'Alice',
        userId: 55,
        serviceName: 'Full Groom',
        totalDurationMinutes: 60,
      );

      final receivedCustomerNotifs = <AppNotification>[];
      final sub = ServicesLocator.customerSocketService.onNotification.listen((notif) {
        receivedCustomerNotifs.add(notif);
      });

      final res = await ServicesLocator.groomerHomeRepository.updateServiceProgress(
        101,
        taskKey: 'svc-1-bath',
        percent: 30,
        notes: 'Bath 30% done',
        booking: initialBooking,
      );

      await Future.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(res.success, isTrue);
      expect(_mockApi.putCallCount, equals(1));
      expect(_mockApi.lastPutPath, equals('/api/common/bookings/101/service-progress'));
      expect(_mockApi.lastPutData['taskKey'], equals('svc-1-bath'));
      expect(_mockApi.lastPutData['percent'], equals(30));

      final updatedBooking = res.updatedBooking;
      expect(updatedBooking, isNotNull);
      expect(updatedBooking!.getProgressPercentForTask('svc-1-bath'), equals(30));
      expect(updatedBooking.isMilestoneDone('bath_completed'), isFalse); // Not completed yet

      // Verify customer notification was triggered
      expect(receivedCustomerNotifs.isNotEmpty, isTrue);
      final notif = receivedCustomerNotifs.first;
      expect(notif.title, contains('Bath Progress'));
      expect(notif.message, contains('30%'));
    });

    test('2. Update Bath progress to 50% and verify progress refreshes & another notification delivered', () async {
      const initialBooking = GroomerBooking(
        bookingId: 102,
        status: 'checked_in',
        bookingDate: '2026-10-22',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Rocky',
        customerName: 'Alice',
        userId: 55,
        serviceName: 'Full Groom',
        serviceProgress: [
          ServiceProgressItem(
            taskKey: 'svc-1-bath',
            percent: 30,
            status: 'in_progress',
            durationMinutes: 30,
          ),
        ],
      );

      final receivedCustomerNotifs = <AppNotification>[];
      final sub = ServicesLocator.customerSocketService.onNotification.listen((notif) {
        receivedCustomerNotifs.add(notif);
      });

      final res = await ServicesLocator.groomerHomeRepository.updateServiceProgress(
        102,
        taskKey: 'svc-1-bath',
        percent: 50,
        notes: 'Halfway through bath',
        booking: initialBooking,
      );

      await Future.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(res.success, isTrue);
      expect(_mockApi.putCallCount, equals(1));
      expect(_mockApi.lastPutData['percent'], equals(50));

      final updated = res.updatedBooking;
      expect(updated, isNotNull);
      expect(updated!.getProgressPercentForTask('svc-1-bath'), equals(50));

      expect(receivedCustomerNotifs.isNotEmpty, isTrue);
      final notif = receivedCustomerNotifs.first;
      expect(notif.title, contains('Bath Progress'));
      expect(notif.message, contains('50%'));
    });
  });

  group('Scenario 3: 100% Progress / Milestone Completion', () {
    test('3. Complete a milestone (100%) and verify status transition & completion notification', () async {
      const initialBooking = GroomerBooking(
        bookingId: 103,
        status: 'checked_in',
        bookingDate: '2026-10-22',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Bella',
        customerName: 'Bob',
        userId: 56,
        serviceName: 'Bath & Brush',
      );

      final receivedCustomerNotifs = <AppNotification>[];
      final sub = ServicesLocator.customerSocketService.onNotification.listen((notif) {
        receivedCustomerNotifs.add(notif);
      });

      final res = await ServicesLocator.groomerHomeRepository.updateServiceProgress(
        103,
        taskKey: 'svc-1-bath',
        percent: 100,
        notes: 'Bath all done',
        booking: initialBooking,
      );

      await Future.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(res.success, isTrue);
      expect(_mockApi.lastPutData['percent'], equals(100));

      final updated = res.updatedBooking;
      expect(updated, isNotNull);
      expect(updated!.getProgressPercentForTask('svc-1-bath'), equals(100));
      expect(updated.isBathCompleted, isTrue);

      expect(receivedCustomerNotifs.isNotEmpty, isTrue);
      final notif = receivedCustomerNotifs.first;
      expect(notif.title, contains('Completed'));
    });
  });

  group('Scenario 4 & 5: Skip Option & Preserving Duration in Consumed Time', () {
    test('4. Skip an eligible milestone immediately and verify next allowed action', () async {
      const checkedInBooking = GroomerBooking(
        bookingId: 104,
        status: 'checked_in',
        bookingDate: '2026-10-22',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Milo',
        customerName: 'Charlie',
        userId: 57,
        serviceName: 'Full Groom',
        totalDurationMinutes: 60,
        serviceProgress: [
          ServiceProgressItem(
            taskKey: 'svc-1-bath',
            durationMinutes: 30,
            skipAllowed: true,
          ),
          ServiceProgressItem(
            taskKey: 'svc-2-grooming',
            durationMinutes: 30,
            skipAllowed: true,
          ),
        ],
      );

      final receivedCustomerNotifs = <AppNotification>[];
      final sub = ServicesLocator.customerSocketService.onNotification.listen((notif) {
        receivedCustomerNotifs.add(notif);
      });

      final res = await ServicesLocator.groomerHomeRepository.skipServiceProgressTask(
        104,
        taskKey: 'svc-1-bath',
        reason: 'Customer requested quick dry groom',
        booking: checkedInBooking,
      );

      await Future.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(res.success, isTrue);
      expect(_mockApi.postCallCount, equals(1));
      expect(_mockApi.lastPostPath, equals('/api/common/bookings/104/service-progress/skip'));
      expect(_mockApi.lastPostData['taskKey'], equals('svc-1-bath'));

      final updated = res.updatedBooking;
      expect(updated, isNotNull);
      expect(updated!.isTaskSkipped('svc-1-bath'), isTrue);

      // Notification sent
      expect(receivedCustomerNotifs.isNotEmpty, isTrue);
      final notif = receivedCustomerNotifs.first;
      expect(notif.title, contains('Skipped'));
      expect(notif.message, contains('skipped'));
    });

    test('5. Confirm skipped milestone duration is preserved in consumed-time calculations', () {
      const bookingWithSkippedTask = GroomerBooking(
        bookingId: 105,
        status: 'checked_in',
        bookingDate: '2026-10-22',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Milo',
        customerName: 'Charlie',
        serviceName: 'Full Groom',
        totalDurationMinutes: 60,
        serviceProgress: [
          ServiceProgressItem(
            taskKey: 'svc-1-bath',
            durationMinutes: 25,
            status: 'skipped',
            skipAllowed: true,
          ),
          ServiceProgressItem(
            taskKey: 'svc-2-grooming',
            durationMinutes: 35,
            percent: 50,
            status: 'in_progress',
            skipAllowed: true,
          ),
        ],
      );

      // Consumed time MUST include the 25 minutes from the skipped bath milestone!
      expect(bookingWithSkippedTask.consumedDurationMinutes, equals(60));
    });
  });

  group('Scenario 6: Non-skippable Milestone Enforcement', () {
    test('6. Attempt to skip check_in_completed is rejected', () {
      const booking = GroomerBooking(
        bookingId: 106,
        status: 'confirmed',
        bookingDate: '2026-10-22',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Daisy',
        customerName: 'David',
        serviceName: 'Full Groom',
      );

      // Before check-in, skip option is prohibited
      expect(booking.isCheckedIn, isFalse);
      expect(booking.canShowSkipOption, isFalse);
    });
  });

  group('Scenario 7 & 8: API Failure & Duplicate Notification Prevention', () {
    test('7. Simulate API failure and verify NO false success notification is sent', () async {
      _mockApi.shouldFail = true;

      const booking = GroomerBooking(
        bookingId: 107,
        status: 'checked_in',
        bookingDate: '2026-10-22',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Daisy',
        customerName: 'David',
        userId: 58,
        serviceName: 'Full Groom',
      );

      final receivedCustomerNotifs = <AppNotification>[];
      final sub = ServicesLocator.customerSocketService.onNotification.listen((notif) {
        receivedCustomerNotifs.add(notif);
      });

      final res = await ServicesLocator.groomerHomeRepository.updateServiceProgress(
        107,
        taskKey: 'svc-1-bath',
        percent: 30,
        booking: booking,
      );

      await Future.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(res.success, isFalse);
      expect(receivedCustomerNotifs.isEmpty, isTrue); // NO notification sent on failure!
    });

    test('8. Verify repeated requests do not create unintended duplicate notifications', () async {
      const notifJson = {
        'id': 999111,
        'title': 'Bath Progress Updated',
        'message': 'Bath progress updated to 30%.',
        'type': 'booking_progress',
        'userId': 12,
      };

      final notif = AppNotification.fromJson(notifJson);
      final emitted = <AppNotification>[];
      final sub = ServicesLocator.customerSocketService.onNotification.listen((n) {
        emitted.add(n);
      });

      ServicesLocator.customerSocketService.handleDirectNotification(notif);
      ServicesLocator.customerSocketService.handleDirectNotification(notif); // Duplicate

      await Future.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(emitted.length, equals(1)); // Duplicate was successfully suppressed!
    });
  });

  group('Scenario 9: Correct Customer Delivery', () {
    test('9. Verify notifications target the correct customer and booking', () async {
      const booking = GroomerBooking(
        bookingId: 109,
        status: 'checked_in',
        bookingDate: '2026-10-22',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Max',
        customerName: 'Eve',
        userId: 99,
        serviceName: 'Full Groom',
      );

      final receivedCustomerNotifs = <AppNotification>[];
      final sub = ServicesLocator.customerSocketService.onNotification.listen((notif) {
        receivedCustomerNotifs.add(notif);
      });

      final res = await ServicesLocator.groomerHomeRepository.updateServiceProgress(
        109,
        taskKey: 'svc-1-bath',
        percent: 75,
        booking: booking,
      );

      await Future.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(res.success, isTrue);
      expect(receivedCustomerNotifs.isNotEmpty, isTrue);
      final notif = receivedCustomerNotifs.first;
      expect(notif.userId, equals(99));
      expect(notif.metadata?['bookingId'], equals(109));
    });
  });

  group('Scenario 10: UI Dialog Integration Test', () {
    testWidgets('10. Milestone dialog displays progress selector and skip button', (tester) async {
      const booking = GroomerBooking(
        bookingId: 110,
        status: 'checked_in',
        bookingDate: '2026-10-22',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Leo',
        customerName: 'Frank',
        userId: 77,
        serviceName: 'Full Groom',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  GroomerMilestoneDialog.show(
                    ctx,
                    booking: booking,
                    initialMilestoneKey: 'bath_completed',
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify Service Progress section and percentage options are visible
      expect(find.text('Service Progress'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      // Verify Skip button is present for eligible milestone
      expect(find.textContaining('Skip'), findsWidgets);
    });
  });
}
