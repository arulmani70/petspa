import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/all_groomers/all_groomers_schedule_page.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/forecast/forecast_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  group('Groomer Selection List Appointment Count Tests', () {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final mockSalonGroomers = [
      const SalonGroomer(
        id: 1,
        groomerCode: 'G001',
        firstName: 'Merisa',
        lastName: 'Brown',
        name: 'Merisa Brown',
        role: 'Lead Groomer',
      ),
      const SalonGroomer(
        id: 2,
        groomerCode: 'G002',
        firstName: 'Richard',
        lastName: 'Cooke',
        name: 'Richard Cooke',
        role: 'Senior Groomer',
      ),
      const SalonGroomer(
        id: 3,
        groomerCode: 'G003',
        firstName: 'Tracie',
        lastName: 'Jamison',
        name: 'Tracie Jamison',
        role: 'Groomer',
      ),
    ];

    final mockBookings = [
      // 2 appointments for Merisa (ID 1)
      GroomerBooking(
        bookingId: 101,
        status: 'confirmed',
        bookingDate: todayStr,
        startTime: '09:00',
        endTime: '10:00',
        petName: 'Max',
        customerName: 'Alice Smith',
        serviceName: 'Full Grooming',
        groomerId: 1,
        groomerName: 'Merisa Brown',
        groomerCode: 'G001',
      ),
      GroomerBooking(
        bookingId: 102,
        status: 'pending',
        bookingDate: todayStr,
        startTime: '10:30',
        endTime: '11:30',
        petName: 'Bella',
        customerName: 'Bob Jones',
        serviceName: 'Bath & Brush',
        groomerId: 1,
        groomerName: 'Merisa Brown',
        groomerCode: 'G001',
      ),
      // 3 appointments for Richard (ID 2)
      GroomerBooking(
        bookingId: 201,
        status: 'confirmed',
        bookingDate: todayStr,
        startTime: '11:00',
        endTime: '12:00',
        petName: 'Rocky',
        customerName: 'Charlie Green',
        serviceName: 'Nail Trim',
        groomerId: 2,
        groomerName: 'Richard Cooke',
        groomerCode: 'G002',
      ),
      GroomerBooking(
        bookingId: 202,
        status: 'in_progress',
        bookingDate: todayStr,
        startTime: '13:00',
        endTime: '14:00',
        petName: 'Milo',
        customerName: 'David White',
        serviceName: 'Full Spa',
        groomerId: 2,
        groomerName: 'Richard Cooke',
        groomerCode: 'G002',
      ),
      GroomerBooking(
        bookingId: 203,
        status: 'completed',
        bookingDate: todayStr,
        startTime: '14:30',
        endTime: '15:30',
        petName: 'Luna',
        customerName: 'Emma Brown',
        serviceName: 'Haircut',
        groomerId: 2,
        groomerName: 'Richard Cooke',
        groomerCode: 'G002',
      ),
      // 1 appointment for Tracie (ID 3)
      GroomerBooking(
        bookingId: 301,
        status: 'confirmed',
        bookingDate: todayStr,
        startTime: '16:00',
        endTime: '17:00',
        petName: 'Daisy',
        customerName: 'Frank Miller',
        serviceName: 'Bath & Brush',
        groomerId: 3,
        groomerName: 'Tracie Jamison',
        groomerCode: 'G003',
      ),
    ];

    testWidgets('AllGroomersSchedulePage displays accurate appointment count for every groomer, even when unselected', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      // Simulate logged in as Merisa (ID 1)
      await ServicesLocator.sessionService.saveGroomerUser({
        'id': 1,
        'groomerCode': 'G001',
        'firstName': 'Merisa',
        'lastName': 'Brown',
        'email': 'merisa@shearheaven.com',
        'role': 'Groomer',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: mockBookings,
            initialSalonGroomers: mockSalonGroomers,
            initialGroomerFilterId: '1', // Merisa selected initially
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify 'All Groomers' chip displays total count = 6
      expect(find.text('All Groomers'), findsOneWidget);
      expect(find.text('6'), findsWidgets);

      // 2. Merisa (selected) should display count = 2
      expect(find.text('Merisa (You)'), findsOneWidget);
      expect(find.text('2'), findsWidgets);

      // 3. Richard (UNSELECTED) MUST NOT display 0; it should display count = 3
      expect(find.text('Richard'), findsOneWidget);
      expect(find.text('3'), findsWidgets);

      // 4. Tracie (UNSELECTED) MUST NOT display 0; it should display count = 1
      expect(find.text('Tracie'), findsOneWidget);
      expect(find.text('1'), findsWidgets);

      // 5. Tap Richard's chip to select Richard
      await tester.tap(find.text('Richard'));
      await tester.pumpAndSettle();

      // 6. When selecting Richard, Richard's count (3) is displayed correctly
      expect(find.text('3'), findsWidgets);
      // And Merisa's count (2) is STILL displayed correctly (does not become 0)
      expect(find.text('2'), findsWidgets);
      // And Tracie's count (1) is STILL displayed correctly (does not become 0)
      expect(find.text('1'), findsWidgets);

      // Clean up session
      await ServicesLocator.sessionService.clearGroomerSession();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('ForecastPage displays accurate appointment count for every groomer, even when unselected', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        MaterialApp(
          home: ForecastPage(
            initialBookings: mockBookings,
            initialSalonGroomers: mockSalonGroomers,
            initialGroomerFilterIds: {'1'}, // Merisa selected initially
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify 'All Groomers' chip displays total count = 6
      expect(find.text('All Groomers'), findsOneWidget);
      expect(find.text('6'), findsWidgets);

      // 2. Merisa displays 2, Richard displays 3, Tracie displays 1
      expect(find.text('2'), findsWidgets);
      expect(find.text('3'), findsWidgets);
      expect(find.text('1'), findsWidgets);

      // 3. Tap Richard's chip to select Richard
      await tester.tap(find.text('Richard'));
      await tester.pumpAndSettle();

      // 4. All counts remain accurate
      expect(find.text('2'), findsWidgets);
      expect(find.text('3'), findsWidgets);
      expect(find.text('1'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
