import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/service_groomer_assignments_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  group('ServiceProgressItem & GroomerBooking Serialization Tests', () {
    test('ServiceProgressItem parses assigned groomer, price, and status correctly', () {
      final json = {
        'taskKey': 'svc-193-parent',
        'taskType': 'service',
        'label': 'Full Grooming',
        'sortOrder': 10,
        'percent': 0,
        'status': 'not_started',
        'assignedGroomerId': 104,
        'assignedGroomerName': 'liam L',
        'assignedGroomerCode': 'G00223',
        'lineServiceAmount': 65.0,
        'durationMinutes': 60,
        'assignable': true,
        'primaryGroomerId': 104,
        'primaryGroomerName': 'liam L',
      };

      final item = ServiceProgressItem.fromJson(json);

      expect(item.taskKey, 'svc-193-parent');
      expect(item.displayName, 'Full Grooming');
      expect(item.assignedGroomerId, 104);
      expect(item.assignedGroomerName, 'liam L');
      expect(item.assignedGroomerCode, 'G00223');
      expect(item.lineServiceAmount, 65.0);
      expect(item.assignable, true);
      expect(item.isAssigned, true);
      expect(item.sortOrder, 10);
      expect(item.primaryGroomerName, 'liam L');

      final serialized = item.toJson();
      expect(serialized['assignedGroomerId'], 104);
      expect(serialized['assignedGroomerName'], 'liam L');
      expect(serialized['lineServiceAmount'], 65.0);
    });

    test('GroomerBooking parses serviceAssignmentActivity and primaryGroomer details', () {
      final bookingJson = {
        'bookingId': 133,
        'status': 'confirmed',
        'bookingDate': '2026-11-03',
        'startTime': '10:00 AM',
        'endTime': '11:00 AM',
        'petName': 'Max',
        'breed': 'Golden Retriever',
        'customerName': 'Alice Smith',
        'serviceName': 'Full Grooming',
        'totalPrice': 75.0,
        'storeId': 'SHEAR-001',
        'bookingPrimaryGroomer': {
          'catalogGroomerId': 104,
          'primaryGroomerDbId': 104,
          'primaryGroomerName': 'liam L',
          'petGroomerPreferenceLocked': false,
        },
        'serviceProgress': [
          {
            'taskKey': 'svc-193-parent',
            'label': 'Grooming',
            'lineServiceAmount': 60.0,
            'assignedGroomerId': 104,
            'assignedGroomerName': 'liam L',
            'assignable': true,
          },
          {
            'taskKey': 'svc-193-sub-329',
            'label': 'Sanitary Hygiene Trim',
            'lineServiceAmount': 15.0,
            'assignedGroomerId': null,
            'assignedGroomerName': null,
            'assignable': true,
          }
        ],
        'serviceAssignmentActivity': [
          {
            'id': 47,
            'taskKey': 'svc-193-sub-329',
            'taskLabel': 'Sanitary Hygiene Trim',
            'groomerId': 104,
            'groomerName': 'liam L',
            'previousGroomerId': 1,
            'previousGroomerName': 'Merisa Brown',
            'at': '2026-11-03T16:09:34.000Z',
          }
        ],
      };

      final booking = GroomerBooking.fromJson(bookingJson);

      expect(booking.bookingId, 133);
      expect(booking.primaryGroomerName, 'liam L');
      expect(booking.primaryGroomerId, 104);
      expect(booking.effectivePrimaryGroomerName, 'liam L');
      expect(booking.serviceProgress.length, 2);
      expect(booking.serviceProgress[0].assignedGroomerName, 'liam L');
      expect(booking.serviceProgress[1].assignedGroomerName, isNull);
      expect(booking.serviceAssignmentActivity.length, 1);
      expect(booking.serviceAssignmentActivity[0]['groomerName'], 'liam L');
      expect(booking.serviceAssignmentActivity[0]['previousGroomerName'], 'Merisa Brown');
    });
  });

  group('assignServiceGroomer Repository Logic', () {
    test('Preferred Groomer strictly blocks service line groomer assignment', () async {
      final repo = ServicesLocator.groomerHomeRepository;

      final preferredBooking = GroomerBooking(
        bookingId: 201,
        status: 'confirmed',
        bookingDate: '2026-11-03',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Bella',
        customerName: 'Carol Danvers',
        serviceName: 'Full Grooming',
        isPreferredGroomer: true,
        serviceProgress: const [
          ServiceProgressItem(
            taskKey: 'svc-1-bath',
            taskName: 'Bath',
            assignable: true,
          ),
        ],
      );

      final result = await repo.assignServiceGroomer(
        bookingId: 201,
        taskKey: 'svc-1-bath',
        groomerId: 104,
        currentBooking: preferredBooking,
      );

      expect(result.success, false);
      expect(result.message, contains('Preferred Groomer'));
      expect(result.updatedBooking, isNull);
    });

    test('Assigning groomer to service line updates local booking and activity history', () async {
      final session = ServicesLocator.sessionService;
      final repo = ServicesLocator.groomerHomeRepository;

      // Mock admin or current groomer session
      await session.saveGroomerUser({
        'id': 104,
        'userId': '104',
        'groomerId': 104,
        'name': 'liam L',
        'fullName': 'liam L',
        'role': 'groomer',
      });

      final booking = GroomerBooking(
        bookingId: 202,
        status: 'confirmed',
        bookingDate: '2026-11-03',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Rocky',
        customerName: 'John Doe',
        serviceName: 'Bath & Haircut',
        groomerId: 104,
        groomerName: 'liam L',
        serviceProgress: const [
          ServiceProgressItem(
            taskKey: 'svc-202-bath',
            taskName: 'Bath',
            lineServiceAmount: 30.0,
            assignedGroomerId: null,
            assignedGroomerName: null,
          ),
          ServiceProgressItem(
            taskKey: 'svc-202-cut',
            taskName: 'Haircut',
            lineServiceAmount: 40.0,
            assignedGroomerId: null,
            assignedGroomerName: null,
          ),
        ],
      );

      final result = await repo.assignServiceGroomer(
        bookingId: 202,
        taskKey: 'svc-202-bath',
        groomerId: 104,
        currentBooking: booking,
      );

      expect(result.success, true);
      expect(result.updatedBooking, isNotNull);
      final updatedTask = result.updatedBooking!.getServiceProgressForTask('svc-202-bath');
      expect(updatedTask?.assignedGroomerId, 104);
      expect(result.updatedBooking!.serviceAssignmentActivity.isNotEmpty, true);
      expect(result.updatedBooking!.serviceAssignmentActivity.first['taskKey'], 'svc-202-bath');
    });
  });

  group('ServiceGroomerAssignmentsCard Widget Tests', () {
    testWidgets('Renders header, subtitle, service lines and handles groomer selection', (tester) async {
      final salonGroomers = [
        const SalonGroomer(
          id: 104,
          groomerCode: 'G00223',
          firstName: 'liam',
          lastName: 'L',
          name: 'liam L',
          isSelf: true,
        ),
        const SalonGroomer(
          id: 1,
          groomerCode: 'G001',
          firstName: 'Marissa',
          lastName: 'Brown',
          name: 'Marissa Brown',
        ),
      ];

      final booking = GroomerBooking(
        bookingId: 133,
        status: 'confirmed',
        bookingDate: '2026-11-03',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Buddy',
        customerName: 'Sam Wilson',
        serviceName: 'Full Grooming',
        primaryGroomerName: 'liam L',
        primaryGroomerId: 104,
        serviceProgress: const [
          ServiceProgressItem(
            taskKey: 'svc-193-parent',
            taskName: 'Grooming',
            lineServiceAmount: 60.0,
            assignedGroomerId: 104,
            assignedGroomerName: 'liam L',
            sortOrder: 1,
          ),
          ServiceProgressItem(
            taskKey: 'svc-193-sub',
            taskName: 'Sanitary Hygiene Trim',
            lineServiceAmount: 15.0,
            assignedGroomerId: null,
            assignedGroomerName: null,
            sortOrder: 2,
          ),
        ],
        serviceAssignmentActivity: const [
          {
            'id': 1,
            'taskKey': 'svc-193-parent',
            'taskLabel': 'Grooming',
            'groomerId': 104,
            'groomerName': 'liam L',
            'previousGroomerName': 'Marissa Brown',
            'at': '2026-11-03T10:00:00.000Z',
          }
        ],
      );

      String? assignedKey;
      int? assignedGroomerId;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ServiceGroomerAssignmentsCard(
                booking: booking,
                groomers: salonGroomers,
                primaryGroomerName: 'liam L',
                onAssignGroomer: (key, gId) async {
                  assignedKey = key;
                  assignedGroomerId = gId;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header and exact subtitle text
      expect(find.text('Service groomer assignments'), findsOneWidget);
      expect(
        find.textContaining('Calendar primary groomer: liam L (booking owner). Each service line starts unassigned — pick a groomer manually; only then they see the visit and are blocked on the schedule.'),
        findsOneWidget,
      );

      // Verify Service lines
      expect(find.text('Grooming'), findsOneWidget);
      expect(find.text('Booked \$60.00 · Assigned: liam L'), findsOneWidget);

      expect(find.text('Sanitary Hygiene Trim'), findsOneWidget);
      expect(find.text('Booked \$15.00 · Not assigned'), findsOneWidget);

      // Verify Assignment history
      expect(find.text('ASSIGNMENT HISTORY'), findsOneWidget);
      expect(find.textContaining('Grooming → liam L (was Marissa Brown)'), findsOneWidget);

      // Verify Dropdown exists for unassigned service
      expect(find.text('Select groomer…'), findsOneWidget);

      // Tap the dropdown for the unassigned task and select Marissa Brown
      await tester.tap(find.text('Select groomer…'));
      await tester.pumpAndSettle();

      expect(find.text('Marissa Brown'), findsWidgets);
      await tester.tap(find.text('Marissa Brown').last, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(assignedKey, 'svc-193-sub');
      expect(assignedGroomerId, 1);
    });

    testWidgets('Preferred groomer locks service line assignments', (tester) async {
      final salonGroomers = [
        const SalonGroomer(
          id: 104,
          groomerCode: 'G00223',
          firstName: 'liam',
          lastName: 'L',
          name: 'liam L',
        ),
      ];

      final booking = GroomerBooking(
        bookingId: 134,
        status: 'confirmed',
        bookingDate: '2026-11-03',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Milo',
        customerName: 'Diana Prince',
        serviceName: 'Full Grooming',
        isPreferredGroomer: true,
        serviceProgress: const [
          ServiceProgressItem(
            taskKey: 'svc-1',
            taskName: 'Bath',
            lineServiceAmount: 40.0,
            assignedGroomerId: 104,
            assignedGroomerName: 'liam L',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServiceGroomerAssignmentsCard(
              booking: booking,
              groomers: salonGroomers,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify lock message & disabled dropdown
      expect(
        find.text('Customer requested preferred groomer. Reassignment to other groomers is disabled.'),
        findsOneWidget,
      );
      expect(find.text('Assignment disabled'), findsOneWidget);
      expect(find.text('Select groomer…'), findsNothing);
    });
  });

  group('Service Groomer Assignments & Reassignment Integration (Same API)', () {
    test('reassignBooking updates all serviceProgress lines and serviceAssignmentActivity for booking 133', () async {
      final session = ServicesLocator.sessionService;
      final repo = ServicesLocator.groomerHomeRepository;

      // Log in as groomer 104 (liam L)
      await session.saveGroomerUser({
        'id': 104,
        'userId': '104',
        'groomerId': 104,
        'name': 'liam L',
        'fullName': 'liam L',
        'role': 'groomer',
      });

      final booking133 = GroomerBooking(
        bookingId: 133,
        status: 'confirmed',
        bookingDate: '2026-11-03',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Bella',
        customerName: 'Sam Wilson',
        serviceName: 'Full Grooming',
        totalPrice: 75.0,
        groomerId: 104,
        groomerName: 'liam L',
        primaryGroomerId: 104,
        primaryGroomerName: 'liam L',
        serviceProgress: const [
          ServiceProgressItem(
            taskKey: 'svc-193-parent',
            taskName: 'Grooming',
            lineServiceAmount: 60.0,
            assignedGroomerId: 104,
            assignedGroomerName: 'liam L',
          ),
          ServiceProgressItem(
            taskKey: 'svc-193-sub-329',
            taskName: 'Sanitary Hygiene Trim',
            lineServiceAmount: 15.0,
            assignedGroomerId: 104,
            assignedGroomerName: 'liam L',
          ),
        ],
        serviceAssignmentActivity: const [],
      );

      const targetGroomer = SalonGroomer(
        id: 1,
        groomerCode: 'G001',
        firstName: 'Marissa',
        lastName: 'Brown',
        name: 'Marissa Brown',
      );

      final result = await repo.reassignBooking(
        booking: booking133,
        targetGroomer: targetGroomer,
      );

      expect(result.success, isTrue);
      expect(result.updatedBooking, isNotNull);

      final updated = result.updatedBooking!;
      // Preserved attributes
      expect(updated.bookingId, equals(133));
      expect(updated.petName, equals('Bella'));
      expect(updated.customerName, equals('Sam Wilson'));
      expect(updated.totalPrice, equals(75.0));
      expect(updated.bookingDate, equals('2026-11-03'));
      expect(updated.startTime, equals('10:00 AM'));
      expect(updated.endTime, equals('11:00 AM'));

      // Updated groomer & primary groomer
      expect(updated.groomerId, equals(1));
      expect(updated.groomerName, equals('Marissa Brown'));
      expect(updated.primaryGroomerId, equals(1));
      expect(updated.primaryGroomerName, equals('Marissa Brown'));

      // Both service lines updated to Marissa Brown
      expect(updated.serviceProgress.length, equals(2));
      for (final sp in updated.serviceProgress) {
        expect(sp.assignedGroomerId, equals(1));
        expect(sp.assignedGroomerName, equals('Marissa Brown'));
      }

      // Reassignment history tracked
      expect(updated.reassignmentHistory.isNotEmpty, isTrue);
      expect(updated.reassignmentHistory.last['toGroomerName'], equals('Marissa Brown'));

      // Service assignment activities recorded for both tasks
      expect(updated.serviceAssignmentActivity.length, equals(2));
      expect(updated.serviceAssignmentActivity.any((a) => a['taskKey'] == 'svc-193-parent' && a['groomerId'] == 1), isTrue);
      expect(updated.serviceAssignmentActivity.any((a) => a['taskKey'] == 'svc-193-sub-329' && a['groomerId'] == 1), isTrue);
    });

    test('reassignBooking when serviceProgress is empty synthesizes tasks and updates them cleanly', () async {
      final session = ServicesLocator.sessionService;
      final repo = ServicesLocator.groomerHomeRepository;

      await session.saveGroomerUser({
        'id': 2,
        'userId': '2',
        'groomerId': 2,
        'name': 'Richard Cooke',
        'fullName': 'Richard Cooke',
        'role': 'groomer',
      });

      const initialBooking = GroomerBooking(
        bookingId: 155,
        status: 'confirmed',
        bookingDate: '2026-11-05',
        startTime: '02:00 PM',
        endTime: '03:00 PM',
        petName: 'Daisy',
        customerName: 'Alice Springs',
        serviceName: 'Deluxe Bath',
        totalPrice: 50.0,
        groomerId: 2,
        groomerName: 'Richard Cooke',
        serviceProgress: [],
      );

      const targetGroomer = SalonGroomer(
        id: 1,
        groomerCode: 'G001',
        firstName: 'Marissa',
        lastName: 'Brown',
        name: 'Marissa Brown',
      );

      final result = await repo.reassignBooking(
        booking: initialBooking,
        targetGroomer: targetGroomer,
      );

      expect(result.success, isTrue);
      expect(result.updatedBooking, isNotNull);
      final updated = result.updatedBooking!;
      expect(updated.groomerId, equals(1));
      expect(updated.groomerName, equals('Marissa Brown'));
      expect(updated.serviceProgress.isNotEmpty, isTrue);
      expect(updated.serviceProgress.first.assignedGroomerId, equals(1));
    });
  });
}
