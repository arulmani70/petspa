import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/repo/groomer_home_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  setUp(() async {
    GroomerHomeRepository.clearLocalCreatedBookings();
    GroomerHomeRepository.resetBookingApprovalCache();
  });

  group('GroomerBooking.isAssignedToGroomer Unit Tests', () {
    test('matches direct groomerId, code, and canonical name', () {
      const booking = GroomerBooking(
        bookingId: 101,
        status: 'confirmed',
        bookingDate: '2026-11-10',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Bella',
        customerName: 'John',
        serviceName: 'Full Grooming',
        groomerId: 104,
        groomerCode: 'G00104',
        groomerName: 'Liam Lawson',
      );

      // Matches target ID
      expect(booking.isAssignedToGroomer(104), isTrue);
      // Matches target code
      expect(booking.isAssignedToGroomer(0, targetGroomerCode: 'G00104'), isTrue);
      // Matches target name
      expect(booking.isAssignedToGroomer(0, targetGroomerName: 'Liam Lawson'), isTrue);
      // Does not match other groomer
      expect(booking.isAssignedToGroomer(999, targetGroomerCode: 'G999', targetGroomerName: 'Other Groomer'), isFalse);
    });

    test('matches when groomer is assigned to an individual task in serviceProgress', () {
      const booking = GroomerBooking(
        bookingId: 102,
        status: 'confirmed',
        bookingDate: '2026-11-10',
        startTime: '11:00 AM',
        endTime: '12:00 PM',
        petName: 'Charlie',
        customerName: 'Emma',
        serviceName: 'Spa Package',
        groomerId: 1, // Primary/original booking groomer: Marissa (ID: 1)
        groomerName: 'Marissa Brown',
        serviceProgress: [
          ServiceProgressItem(
            taskKey: 'svc-102-bath',
            taskName: 'Bath',
            assignedGroomerId: 1,
            assignedGroomerName: 'Marissa Brown',
          ),
          ServiceProgressItem(
            taskKey: 'svc-102-haircut',
            taskName: 'Haircut',
            assignedGroomerId: 104, // Assigned service groomer: Liam (ID: 104)
            assignedGroomerName: 'Liam Lawson',
            assignedGroomerCode: 'G00104',
          ),
        ],
      );

      // Primary groomer Marissa is recognized
      expect(booking.isAssignedToGroomer(1, targetGroomerName: 'Marissa Brown'), isTrue);
      // Service-assigned groomer Liam is recognized as assigned to this appointment!
      expect(booking.isAssignedToGroomer(104, targetGroomerCode: 'G00104', targetGroomerName: 'Liam Lawson'), isTrue);
      // An unassigned third groomer (ID: 55) is NOT recognized
      expect(booking.isAssignedToGroomer(55, targetGroomerCode: 'G0055', targetGroomerName: 'Alex'), isFalse);
    });

    test('matches when groomer is recorded in reassignmentHistory or serviceAssignmentActivity', () {
      const booking = GroomerBooking(
        bookingId: 103,
        status: 'confirmed',
        bookingDate: '2026-11-10',
        startTime: '01:00 PM',
        endTime: '02:00 PM',
        petName: 'Milo',
        customerName: 'Sarah',
        serviceName: 'Bath',
        groomerId: 1,
        reassignmentHistory: [
          {
            'fromGroomerId': 1,
            'toGroomerId': 205,
            'toGroomerName': 'Noah Davis',
          }
        ],
        serviceAssignmentActivity: [
          {
            'taskKey': 'svc-103-brush',
            'groomerId': 301,
            'groomerName': 'Oliver Twist',
          }
        ],
      );

      expect(booking.isAssignedToGroomer(205, targetGroomerName: 'Noah Davis'), isTrue);
      expect(booking.isAssignedToGroomer(301, targetGroomerName: 'Oliver Twist'), isTrue);
      expect(booking.isAssignedToGroomer(999), isFalse);
    });
  });

  group('Service Groomer Assignment & Assigned Groomer Login Visibility', () {
    test('When Groomer 1 assigns service line to Groomer 2, Groomer 2 sees visit upon login', () async {
      final session = ServicesLocator.sessionService;
      final repo = ServicesLocator.groomerHomeRepository;

      // 1. Groomer 1 (ID: 1, Marissa Brown) logs in
      await session.saveGroomerUser({
        'id': 1,
        'groomerId': 1,
        'groomerCode': 'G001',
        'name': 'Marissa Brown',
        'fullName': 'Marissa Brown',
        'role': 'groomer',
      });

      // Existing booking in salon initially booked under Marissa (ID: 1)
      const initialBooking = GroomerBooking(
        bookingId: 501,
        status: 'confirmed',
        bookingDate: '2026-11-10',
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        petName: 'Buddy',
        customerName: 'David Lee',
        serviceName: 'Full Grooming',
        groomerId: 1,
        groomerName: 'Marissa Brown',
        groomerCode: 'G001',
        serviceProgress: [
          ServiceProgressItem(
            taskKey: 'svc-501-bath',
            taskName: 'Bath',
            lineServiceAmount: 35.0,
            assignedGroomerId: 1,
            assignedGroomerName: 'Marissa Brown',
          ),
          ServiceProgressItem(
            taskKey: 'svc-501-trim',
            taskName: 'Nail Trim & Groom',
            lineServiceAmount: 45.0,
            assignedGroomerId: null,
            assignedGroomerName: null,
          ),
        ],
      );

      GroomerHomeRepository.addLocalBooking(initialBooking);

      // 2. Marissa assigns 'Nail Trim & Groom' to Liam Lawson (Groomer ID: 104)
      final assignResult = await repo.assignServiceGroomer(
        bookingId: 501,
        taskKey: 'svc-501-trim',
        groomerId: 104,
        currentBooking: initialBooking,
      );

      expect(assignResult.success, isTrue);
      expect(assignResult.updatedBooking, isNotNull);
      final assignedTask = assignResult.updatedBooking!.getServiceProgressForTask('svc-501-trim');
      expect(assignedTask?.assignedGroomerId, 104);

      // Verify notification was dispatched to Groomer 104
      final liamNotifs = session.getGroomerPortalNotifications(groomerId: 104);
      expect(liamNotifs.any((n) => n['message'].toString().contains('501')), isTrue);

      // 3. Marissa logs out
      await repo.logout();

      // Verify that local created bookings are preserved in session storage across groomer switch
      final persistedBookings = session.getLocalBookings();
      expect(persistedBookings.any((b) => b.bookingId == 501), isTrue);

      // 4. Groomer 2 (Liam Lawson, ID: 104) logs in
      await session.saveGroomerUser({
        'id': 104,
        'groomerId': 104,
        'groomerCode': 'G00104',
        'name': 'Liam Lawson',
        'fullName': 'Liam Lawson',
        'role': 'groomer',
      });

      // 5. Liam fetches upcoming bookings
      final liamBookings = await repo.getUpcomingBookings();

      // VERIFY: The assigned appointment #501 IS returned and visible to Liam!
      expect(liamBookings.any((b) => b.bookingId == 501), isTrue,
          reason: 'Groomer 2 must see appointment #501 after being assigned via Service Groomer Assignment');

      final liamViewedBooking = liamBookings.firstWhere((b) => b.bookingId == 501);
      final liamTask = liamViewedBooking.getServiceProgressForTask('svc-501-trim');
      expect(liamTask?.assignedGroomerId, 104);

      // 6. Groomer 3 (Sophia, ID: 999) logs in
      await session.saveGroomerUser({
        'id': 999,
        'groomerId': 999,
        'groomerCode': 'G00999',
        'name': 'Sophia Unassigned',
        'fullName': 'Sophia Unassigned',
        'role': 'groomer',
      });

      final sophiaBookings = await repo.getUpcomingBookings();
      // VERIFY: Groomer 3 (not assigned) does NOT see booking #501
      expect(sophiaBookings.any((b) => b.bookingId == 501), isFalse,
          reason: 'Groomer 3 who has no service assignment on appointment #501 must not see it');
    });

    test('Assigning an unassigned salon visit updates primary groomer and makes it visible to target groomer', () async {
      final session = ServicesLocator.sessionService;
      final repo = ServicesLocator.groomerHomeRepository;

      // Salon admin or current groomer assigns unassigned booking
      await session.saveGroomerUser({
        'id': 1,
        'groomerId': 1,
        'role': 'admin',
      });

      const unassignedBooking = GroomerBooking(
        bookingId: 502,
        status: 'confirmed',
        bookingDate: '2026-11-10',
        startTime: '02:00 PM',
        endTime: '03:00 PM',
        petName: 'Daisy',
        customerName: 'Robert',
        serviceName: 'Bath',
        groomerId: null, // Unassigned
        serviceProgress: [
          ServiceProgressItem(
            taskKey: 'svc-502-bath',
            taskName: 'Bath',
            lineServiceAmount: 50.0,
          ),
        ],
      );

      GroomerHomeRepository.addLocalBooking(unassignedBooking);

      final res = await repo.assignServiceGroomer(
        bookingId: 502,
        taskKey: 'svc-502-bath',
        groomerId: 104,
        currentBooking: unassignedBooking,
      );

      expect(res.success, isTrue);
      expect(res.updatedBooking?.groomerId, 104);
      expect(res.updatedBooking?.primaryGroomerId, 104);

      // Target groomer logs in
      await session.saveGroomerUser({
        'id': 104,
        'groomerId': 104,
        'groomerCode': 'G00104',
        'name': 'Liam Lawson',
        'fullName': 'Liam Lawson',
        'role': 'groomer',
      });

      final upcoming = await repo.getUpcomingBookings();
      expect(upcoming.any((b) => b.bookingId == 502), isTrue);
    });

    test('Salon groomers schedule recognizes service-assigned groomer', () {
      const targetGroomer = SalonGroomer(
        id: 104,
        groomerCode: 'G00104',
        firstName: 'Liam',
        lastName: 'Lawson',
        name: 'Liam Lawson',
      );

      const booking = GroomerBooking(
        bookingId: 503,
        status: 'confirmed',
        bookingDate: '2026-11-10',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Rocky',
        customerName: 'Jane',
        serviceName: 'Full Groom',
        groomerId: 1, // Main groomer is 1
        serviceProgress: [
          ServiceProgressItem(
            taskKey: 'svc-503-teeth',
            taskName: 'Teeth Brushing',
            assignedGroomerId: 104,
            assignedGroomerName: 'Liam Lawson',
          ),
        ],
      );

      expect(
        booking.isAssignedToGroomer(
          targetGroomer.id,
          targetGroomerCode: targetGroomer.groomerCode,
          targetGroomerName: targetGroomer.name,
        ),
        isTrue,
      );
    });
  });
}
