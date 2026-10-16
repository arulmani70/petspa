import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/bookings/models/booking_receipt.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/booking_details_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/bookings/views/mobile/booking_receipt_page_mobile.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/all_groomers/all_groomers_schedule_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  group('Step 11 – BookingReceipt Model & Financial Integrity Tests', () {
    test('Constructs correctly from GroomerBooking', () {
      const gBooking = GroomerBooking(
        bookingId: 1101,
        status: 'completed',
        customerName: 'Alice Green',
        customerMobile: '555-1234',
        customerEmail: 'alice@example.com',
        petName: 'Bella',
        breed: 'Poodle',
        serviceName: 'Full Grooming',
        packageName: 'Platinum Spa',
        addOns: ['De-shedding', 'Nail Trim'],
        bookingDate: '2026-10-16',
        startTime: '09:00 AM',
        endTime: '10:30 AM',
        totalPrice: 85.0,
        tipAmount: 15.0,
        taxAmount: 6.80,
        isPaid: true,
        paymentStatus: 'paid',
        groomerId: 1,
        groomerName: 'Sarah Jenkins',
      );

      final receipt = BookingReceipt.fromGroomerBooking(gBooking);

      expect(receipt.bookingId, equals(1101));
      expect(receipt.customerName, equals('Alice Green'));
      expect(receipt.petName, equals('Bella'));
      expect(receipt.breed, equals('Poodle'));
      expect(receipt.groomerName, equals('Sarah Jenkins'));
      expect(receipt.serviceName, equals('Full Grooming'));
      expect(receipt.packageName, equals('Platinum Spa'));
      expect(receipt.addOns, containsAll(['De-shedding', 'Nail Trim']));
      expect(receipt.basePrice, equals(85.0));
      expect(receipt.tipAmount, equals(15.0));
      expect(receipt.taxAmount, equals(6.80));
      expect(receipt.totalAuthoritativeAmount, closeTo(106.80, 0.001));
      expect(receipt.isAuthoritativelyPaid, isTrue);
    });

    test('Constructs correctly from Customer Booking Map', () {
      final map = {
        'id': 1102,
        'status': 'completed',
        'customerName': 'Bob Vance',
        'phone': '555-9876',
        'pet': {'name': 'Milo', 'breed': 'Beagle'},
        'service': {'name': 'Bath & Brush'},
        'addOns': ['Teeth Brushing'],
        'totalPrice': '60.00',
        'tipAmount': '12.00',
        'taxAmount': '4.80',
        'date': '2026-10-16',
        'time': '11:00 AM',
        'groomerName': 'Mark Davis',
        'isPaid': true,
      };

      final receipt = BookingReceipt.fromMap(map);

      expect(receipt.bookingId, equals(1102));
      expect(receipt.customerName, equals('Bob Vance'));
      expect(receipt.petName, equals('Milo'));
      expect(receipt.breed, equals('Beagle'));
      expect(receipt.serviceName, equals('Bath & Brush'));
      expect(receipt.addOns, contains('Teeth Brushing'));
      expect(receipt.basePrice, equals(60.0));
      expect(receipt.tipAmount, equals(12.0));
      expect(receipt.taxAmount, equals(4.80));
      expect(receipt.totalAuthoritativeAmount, closeTo(76.80, 0.001));
      expect(receipt.isAuthoritativelyPaid, isTrue);
    });

    test('CRITICAL RULE: isAuthoritativelyPaid is FALSE when isPaid is missing, even if status is completed', () {
      final completedUnpaidMap = {
        'id': 1103,
        'status': 'completed', // Status is completed
        'customerName': 'Charlie',
        'petName': 'Luna',
        'serviceName': 'Full Groom',
        'totalPrice': 70.0,
        // isPaid and paymentStatus are omitted
      };

      final receipt = BookingReceipt.fromMap(completedUnpaidMap);

      expect(receipt.status, equals('completed'));
      expect(receipt.isAuthoritativelyPaid, isFalse);
    });

    test('Missing tip and tax are handled cleanly without fabricating 0.00', () {
      const b = BookingReceipt(
        bookingId: 1104,
        status: 'completed',
        customerName: 'Diana',
        petName: 'Rusty',
        groomerName: 'Staff',
        serviceName: 'Express Groom',
        basePrice: 45.0,
        tipAmount: null,
        taxAmount: null,
        totalAuthoritativeAmount: 45.0,
        appointmentDate: '2026-10-16',
        appointmentTime: '01:00 PM',
      );

      expect(b.hasTip, isFalse);
      expect(b.hasTax, isFalse);
      expect(b.tipAmount, isNull);
      expect(b.taxAmount, isNull);
      expect(b.totalAuthoritativeAmount, equals(45.0));
    });

    test('Authoritative total accounts for discounts when present', () {
      final mapWithDiscount = {
        'id': 1105,
        'status': 'completed',
        'customerName': 'Edward',
        'petName': 'Daisy',
        'serviceName': 'Spa Bath',
        'totalPrice': 50.0,
        'discountAmount': 10.0,
        'taxAmount': 3.20,
      };

      final receipt = BookingReceipt.fromMap(mapWithDiscount);

      expect(receipt.discountAmount, equals(10.0));
      // 50.0 - 10.0 + 3.20 = 43.20
      expect(receipt.totalAuthoritativeAmount, closeTo(43.20, 0.001));
    });
  });

  group('Step 11 – Receipt Screen Rendering & Financial UI Tests', () {
    testWidgets('Renders official spa header, metadata, itemized charges, and total', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const receipt = BookingReceipt(
        bookingId: 1106,
        transactionId: 'TXN-98421',
        status: 'completed',
        isPaid: true,
        paymentStatus: 'paid',
        petName: 'Barnaby',
        breed: 'Golden Retriever',
        customerName: 'Sarah Jenkins',
        customerPhone: '555-0192',
        groomerName: 'John Doe',
        serviceName: 'Deluxe Bath & Trim',
        packageName: 'Spa Package',
        addOns: ['Teeth Brushing', 'Nail Dremel'],
        basePrice: 95.0,
        tipAmount: 19.0,
        taxAmount: 7.60,
        totalAuthoritativeAmount: 121.60,
        appointmentDate: '2026-10-16',
        appointmentTime: '02:00 PM',
        completedAt: '2026-10-16 03:45 PM',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BookingReceiptPageMobile(receipt: receipt),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Receipt & Invoice'), findsOneWidget);
      expect(find.text('Shear Heaven Pet Spa'), findsOneWidget);
      expect(find.text('Official Service Receipt • Arlington, TX'), findsOneWidget);
      expect(find.text('PAID IN FULL'), findsOneWidget);
      expect(find.text('#1106'), findsOneWidget);
      expect(find.text('TXN-98421'), findsOneWidget);
      expect(find.text('Sarah Jenkins (555-0192)'), findsOneWidget);
      expect(find.text('Barnaby • Golden Retriever'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('\$95.00'), findsOneWidget);
      expect(find.text('Teeth Brushing'), findsOneWidget);
      expect(find.text('Nail Dremel'), findsOneWidget);
      expect(find.text('\$19.00'), findsOneWidget);
      expect(find.text('\$7.60'), findsOneWidget);
      expect(find.text('\$121.60'), findsOneWidget);
      expect(find.text('Copy Receipt'), findsOneWidget);
    });

    testWidgets('Displays fallback text for missing optional fields without fabricating values', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const receiptWithoutOptionals = BookingReceipt(
        bookingId: 1107,
        transactionId: null, // No transaction ID
        status: 'completed',
        isPaid: null, // No payment confirmation
        petName: 'Rocky',
        customerName: 'Dave',
        groomerName: 'Staff',
        serviceName: 'Full Groom',
        basePrice: 70.0,
        tipAmount: null, // No tip
        taxAmount: null, // No tax
        totalAuthoritativeAmount: 70.0,
        appointmentDate: '2026-10-16',
        appointmentTime: '04:00 PM',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BookingReceiptPageMobile(receipt: receiptWithoutOptionals),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('COUNTER SETTLEMENT PENDING'), findsOneWidget);
      expect(find.text('Pending counter sync'), findsOneWidget);
      expect(find.text('No tip recorded on server'), findsOneWidget);
      expect(find.text('Calculated at counter'), findsOneWidget);
      expect(find.text('\$70.00'), findsNWidgets(2)); // base and total
    });

    testWidgets('Renders clean unavailable state when booking receipt data is invalid', (tester) async {
      const invalidReceipt = BookingReceipt(
        bookingId: 0, // invalid ID
        status: 'unknown',
        petName: '',
        customerName: '',
        groomerName: '',
        serviceName: '',
        basePrice: 0.0,
        totalAuthoritativeAmount: 0.0,
        appointmentDate: '',
        appointmentTime: '',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BookingReceiptPageMobile(receipt: invalidReceipt),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Receipt Unavailable'), findsOneWidget);
      expect(find.text('Detailed receipt data could not be found for this booking.'), findsOneWidget);
    });
  });

  group('Step 11 – Navigation & UI Entry Point Tests', () {
    testWidgets('BookingDetailsPageMobile renders Official Service Receipt banner for completed booking', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final completedBookingData = {
        'id': 1108,
        'status': 'completed',
        'customerName': 'Tina Turner',
        'petName': 'Simba',
        'serviceName': 'Full Grooming',
        'bookingDate': '2026-10-16',
        'startTime': '09:00 AM',
        'totalPrice': 80.0,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: BookingDetailsPageMobile(bookingData: completedBookingData),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Official Service Receipt'), findsOneWidget);
      expect(find.text('View Receipt & Invoice'), findsOneWidget);

      await tester.tap(find.text('View Receipt & Invoice'));
      await tester.pumpAndSettle();

      expect(find.text('Receipt & Invoice'), findsOneWidget);
      expect(find.text('#1108'), findsOneWidget);
      expect(find.text('Tina Turner'), findsOneWidget);
    });

    testWidgets('AllGroomersSchedulePage renders Receipt button for completed appointment and opens modal', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await ServicesLocator.sessionService.saveGroomerUser({
        'id': 1,
        'name': 'John Doe',
        'email': 'john@groomer.com',
      });

      final testGroomers = [
        const SalonGroomer(
          id: 1,
          groomerCode: 'G001',
          firstName: 'John',
          lastName: 'Doe',
          name: 'John Doe',
        ),
      ];

      final testBookings = [
        GroomerBooking(
          bookingId: 1109,
          status: 'completed',
          customerName: 'Sam',
          petName: 'Rusty',
          serviceName: 'Full Groom',
          bookingDate: todayStr,
          startTime: '09:00 AM',
          endTime: '10:00 AM',
          totalPrice: 80.0,
          groomerId: 1,
          groomerCode: 'G001',
          groomerName: 'John Doe',
          isPaid: true,
          paymentStatus: 'paid',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AllGroomersSchedulePage(
            initialBookings: testBookings,
            initialSalonGroomers: testGroomers,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Receipt'), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long_rounded), findsOneWidget);

      await tester.tap(find.text('Receipt'));
      await tester.pumpAndSettle();

      expect(find.text('Receipt & Invoice'), findsOneWidget);
      expect(find.text('#1109'), findsWidgets);
      expect(find.text('Rusty'), findsWidgets);
    });
  });
}
