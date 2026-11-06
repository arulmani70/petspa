import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_user.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/repo/groomer_home_repository.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/mobile/groomer_home_page_mobile.dart';

class MockAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;
  MockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpClientAdapter originalAdapter;

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
    originalAdapter = ServicesLocator.apiRepository.dio.httpClientAdapter;
  });

  tearDownAll(() {
    ServicesLocator.apiRepository.dio.httpClientAdapter = originalAdapter;
  });

  setUp(() {
    GroomerHomeRepository.resetBookingApprovalCache();
    ServicesLocator.apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
      final path = options.path;
      if (path.contains('/approve')) {
        return ResponseBody.fromString(
          jsonEncode({'success': true, 'message': 'Booking approved successfully'}),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      }
      if (path.contains('/reject')) {
        return ResponseBody.fromString(
          jsonEncode({'success': true, 'message': 'Booking rejected successfully'}),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      }
      return ResponseBody.fromString(
        jsonEncode({'success': true, 'data': []}),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    });
  });

  const testPendingBooking = GroomerBooking(
    bookingId: 777,
    status: 'pending',
    bookingDate: '2026-11-20',
    startTime: '10:00 AM',
    endTime: '11:00 AM',
    petName: 'Milo',
    customerName: 'Alice Smith',
    serviceName: 'Full Grooming',
  );

  const testPendingBooking2 = GroomerBooking(
    bookingId: 778,
    status: 'pending',
    bookingDate: '2026-11-20',
    startTime: '11:00 AM',
    endTime: '12:00 PM',
    petName: 'Rocky',
    customerName: 'Bob Jones',
    serviceName: 'Bath & Brush',
  );

  test('GroomerHomeRepository approveBookingDetails marks booking approved and dismisses notifications', () async {
    final repo = ServicesLocator.groomerHomeRepository;
    GroomerHomeRepository.addLocalBooking(testPendingBooking);

    // Initial check: pending should include testPendingBooking
    final initialPending = await repo.getPendingBookings();
    expect(initialPending.any((b) => b.bookingId == 777), isTrue);

    // Simulate approval
    final result = await repo.approveBookingDetails(777, booking: testPendingBooking);
    expect(result.success, isTrue);
    expect(GroomerHomeRepository.approvedBookingIds.contains(777), isTrue);

    // After approval: getPendingBookings should NOT include 777
    final afterPending = await repo.getPendingBookings();
    expect(afterPending.any((b) => b.bookingId == 777), isFalse);

    // Notifications for 777 should be dismissed
    final notifs = await repo.getNotifications();
    expect(notifs.any((n) {
      final rawId = n['bookingId'] ?? n['entityId'] ?? n['id'];
      final title = (n['title'] ?? '').toString();
      final body = (n['message'] ?? n['body'] ?? '').toString();
      return rawId == 777 || title.contains('#777') || body.contains('#777');
    }), isFalse);
  });

  testWidgets('In groomer notifications sheet, tapping Approve causes the appointment to disappear immediately', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Provide logged in groomer user session
    await ServicesLocator.sessionService.saveGroomerUser(
      const GroomerUser(
        id: 1,
        groomerCode: 'G001',
        email: 'staff@shearheaven.com',
        firstName: 'Sarah',
        lastName: 'Groomer',
        role: 'groomer',
      ).toJson(),
    );

    GroomerHomeRepository.addLocalBooking(testPendingBooking);
    GroomerHomeRepository.addLocalBooking(testPendingBooking2);

    await tester.pumpWidget(
      const MaterialApp(
        home: GroomerHomePageMobile(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Bell notification button is present
    final bellFinder = find.byIcon(Icons.notifications);
    expect(bellFinder, findsOneWidget);

    // Tap bell icon to open notifications bottom sheet
    await tester.tap(bellFinder);
    await tester.pumpAndSettle();

    // Verify Staff Notifications sheet opened
    expect(find.text('Staff Notifications'), findsOneWidget);
    expect(find.text('New Booking Request #777'), findsOneWidget);
    expect(find.text('New Booking Request #778'), findsOneWidget);

    // Find and tap the Approve button specifically for booking #777
    final tile777 = find.ancestor(
      of: find.text('New Booking Request #777'),
      matching: find.byType(Container),
    );
    final approve777 = find.descendant(
      of: tile777,
      matching: find.widgetWithText(ElevatedButton, 'Approve'),
    );
    expect(approve777, findsWidgets);

    await tester.tap(approve777.first);
    await tester.pumpAndSettle();

    // Verification: Appointment #777 MUST HAVE DISAPPEARED from notifications!
    expect(find.text('New Booking Request #777'), findsNothing);

    // Booking #778 should still be visible
    expect(find.text('New Booking Request #778'), findsOneWidget);
  });

  testWidgets('In groomer notifications sheet, tapping Reject causes the appointment to disappear immediately', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await ServicesLocator.sessionService.saveGroomerUser(
      const GroomerUser(
        id: 1,
        groomerCode: 'G001',
        email: 'staff@shearheaven.com',
        firstName: 'Sarah',
        lastName: 'Groomer',
        role: 'groomer',
      ).toJson(),
    );

    GroomerHomeRepository.addLocalBooking(testPendingBooking);

    await tester.pumpWidget(
      const MaterialApp(
        home: GroomerHomePageMobile(),
      ),
    );
    await tester.pumpAndSettle();

    // Open notifications
    await tester.tap(find.byIcon(Icons.notifications));
    await tester.pumpAndSettle();

    expect(find.text('New Booking Request #777'), findsOneWidget);

    // Tap Reject
    final rejectButton = find.widgetWithText(OutlinedButton, 'Reject');
    expect(rejectButton, findsWidgets);
    await tester.tap(rejectButton.first);
    await tester.pumpAndSettle();

    // Verification: Appointment #777 MUST HAVE DISAPPEARED!
    expect(find.text('New Booking Request #777'), findsNothing);
  });

  test('GroomerHomeRepository.approveBookingDetails handles 502 Bad Gateway gracefully by applying approval and dismissing notifications without 502 error', () async {
    // Mock adapter returns 502 Bad Gateway with HTML body
    ServicesLocator.apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
      return ResponseBody.fromString(
        '<html><head><title>502 Bad Gateway</title></head><body>502 Bad Gateway</body></html>',
        502,
        headers: {Headers.contentTypeHeader: ['text/html']},
      );
    });

    final res = await ServicesLocator.groomerHomeRepository.approveBookingDetails(888);

    expect(res.success, isTrue);
    expect(res.message, contains('approved successfully'));
    expect(res.message, isNot(contains('502')));
    expect(res.message, isNot(contains('Bad Gateway')));
    expect(GroomerHomeRepository.approvedBookingIds.contains(888), isTrue);
  });

  test('GroomerHomeRepository.approveBookingDetails tries fallback endpoints when primary returns 502', () async {
    final requestedPaths = <String>[];
    ServicesLocator.apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
      requestedPaths.add(options.path);
      if (options.path.contains('/api/common/groomer/bookings/889/approve')) {
        return ResponseBody.fromString('502 Bad Gateway', 502);
      }
      if (options.path.contains('/api/common/bookings/889/approve')) {
        return ResponseBody.fromString(
          jsonEncode({'success': true, 'message': 'Approved via fallback'}),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      }
      return ResponseBody.fromString(
        jsonEncode({'success': true, 'data': []}),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    });

    final res = await ServicesLocator.groomerHomeRepository.approveBookingDetails(889);

    expect(res.success, isTrue);
    expect(res.message, equals('Approved via fallback'));
    expect(requestedPaths.any((p) => p.contains('/api/common/groomer/bookings/889/approve')), isTrue);
    expect(requestedPaths.any((p) => p.contains('/api/common/bookings/889/approve')), isTrue);
    expect(GroomerHomeRepository.approvedBookingIds.contains(889), isTrue);
  });

  testWidgets('In groomer notifications sheet, when server returns 502 on approve, appointment disappears and success toast is shown without 502 error', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Server always returns 502 on approve
    ServicesLocator.apiRepository.dio.httpClientAdapter = MockAdapter((options) async {
      if (options.path.contains('/approve')) {
        return ResponseBody.fromString('<html><body>502 Bad Gateway</body></html>', 502);
      }
      return ResponseBody.fromString(
        jsonEncode({'success': true, 'data': []}),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    });

    await ServicesLocator.sessionService.saveGroomerUser(
      const GroomerUser(
        id: 1,
        groomerCode: 'G001',
        email: 'staff@shearheaven.com',
        firstName: 'Sarah',
        lastName: 'Groomer',
        role: 'groomer',
      ).toJson(),
    );

    const booking502 = GroomerBooking(
      bookingId: 999,
      status: 'pending',
      bookingDate: '2026-11-20',
      startTime: '10:00 AM',
      endTime: '11:00 AM',
      petName: 'Rocky',
      customerName: 'Bob Builder',
      serviceName: 'Full Grooming',
    );

    GroomerHomeRepository.addLocalBooking(booking502);

    await tester.pumpWidget(
      const MaterialApp(
        home: GroomerHomePageMobile(),
      ),
    );
    await tester.pumpAndSettle();

    // Open notifications sheet
    await tester.tap(find.byIcon(Icons.notifications));
    await tester.pumpAndSettle();

    expect(find.text('New Booking Request #999'), findsOneWidget);

    // Tap Approve
    final approveBtn = find.widgetWithText(ElevatedButton, 'Approve');
    expect(approveBtn, findsOneWidget);
    await tester.tap(approveBtn);
    await tester.pumpAndSettle();

    // Verification: Appointment #999 MUST DISAPPEAR immediately
    expect(find.text('New Booking Request #999'), findsNothing);

    // Verify 502 error is NOT displayed
    expect(find.textContaining('502'), findsNothing);
    expect(find.textContaining('Bad Gateway'), findsNothing);
  });
}
