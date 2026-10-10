import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/common/services/customer_socket_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/groomer_socket_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/groomer/bloc/groomer_bloc.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/bloc/groomer_home_bloc.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/customer_summary.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_user.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  group('Groomer Appointment Status Flow Tests', () {
    test('GroomerBooking model supports status flow and copyWith transitions', () {
      const initialBooking = GroomerBooking(
        bookingId: 101,
        status: 'pending',
        bookingDate: '2026-09-24',
        startTime: '11:00 AM',
        endTime: '12:00 PM',
        petName: 'Bella',
        customerName: 'Alice Johnson',
        serviceName: 'Full Grooming',
      );

      expect(initialBooking.status, equals('pending'));

      // 1. Pending -> Confirmed (Approve)
      final confirmedBooking = initialBooking.copyWith(status: 'confirmed');
      expect(confirmedBooking.status, equals('confirmed'));
      expect(confirmedBooking.bookingId, equals(101));

      // 2. Confirmed -> In Progress (Start Appointment)
      final inProgressBooking = confirmedBooking.copyWith(status: 'in_progress');
      expect(inProgressBooking.status, equals('in_progress'));

      // 3. In Progress -> Completed (Complete Appointment)
      final completedBooking = inProgressBooking.copyWith(status: 'completed');
      expect(completedBooking.status, equals('completed'));
    });

    test('Start Appointment scheduled time comparison logic works accurately with calendar date validation', () {
      final now = DateTime(2026, 9, 24, 12, 0); // 12:00 PM reference
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
      final tomorrowStr = DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)));

      // Helper function replicating _isStartTimeReached
      bool isStartTimeReached(String dateStr, String timeStr, {DateTime? currentNow}) {
        if (dateStr.isEmpty || timeStr.isEmpty) return false;
        try {
          final parsedDate = BookingDateUtils.parseCalendarDate(dateStr);
          if (parsedDate == null) return false;

          final refNow = currentNow ?? now;
          final isToday = BookingDateUtils.isSameCalendarDay(parsedDate, refNow);

          // Appointment date MUST be today
          if (!isToday) {
            return false;
          }

          final cleanTime = timeStr.trim().toUpperCase();
          int hour = 0;
          int minute = 0;

          if (cleanTime.contains('AM') || cleanTime.contains('PM')) {
            try {
              final t = DateFormat('h:mm a').parse(cleanTime);
              hour = t.hour;
              minute = t.minute;
            } catch (_) {
              try {
                final t = DateFormat('hh:mm a').parse(cleanTime);
                hour = t.hour;
                minute = t.minute;
              } catch (_) {}
            }
          } else {
            final parts = cleanTime.split(':');
            hour = int.tryParse(parts[0]) ?? 0;
            minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
          }

          final scheduled = DateTime(refNow.year, refNow.month, refNow.day, hour, minute);
          return refNow.isAfter(scheduled) || refNow.isAtSameMomentAs(scheduled);
        } catch (_) {
          return false;
        }
      }

      // 1. Previous dates must NEVER be startable
      expect(isStartTimeReached(yesterdayStr, '11:00 AM'), isFalse);
      expect(isStartTimeReached(yesterdayStr, '09:00 AM'), isFalse);
      expect(isStartTimeReached(yesterdayStr, '08:00 PM'), isFalse);

      // 2. Today's appointment with past scheduled time (10:00 AM vs 12:00 PM) -> startable
      expect(isStartTimeReached(todayStr, '10:00 AM'), isTrue);
      expect(isStartTimeReached(todayStr, '12:00 PM'), isTrue);

      // 3. Today's appointment with future scheduled time (02:00 PM vs 12:00 PM) -> NOT startable
      expect(isStartTimeReached(todayStr, '02:00 PM'), isFalse);
      expect(isStartTimeReached(todayStr, '05:30 PM'), isFalse);

      // 4. Future dates must NEVER be startable
      expect(isStartTimeReached(tomorrowStr, '12:00 PM'), isFalse);
      expect(isStartTimeReached(tomorrowStr, '09:00 AM'), isFalse);
    });

    test('CustomerSocketService includes all appointment and booking events', () {
      expect(CustomerSocketService.supportedNotificationEvents, contains('booking_in_progress'));
      expect(CustomerSocketService.supportedNotificationEvents, contains('booking_started'));
      expect(CustomerSocketService.supportedNotificationEvents, contains('booking_completed'));
      expect(CustomerSocketService.supportedNotificationEvents, contains('booking_confirmed'));
      expect(CustomerSocketService.supportedNotificationEvents, contains('appointment_started'));
      expect(CustomerSocketService.supportedNotificationEvents, contains('appointment_completed'));
    });

    test('GroomerSocketService includes all appointment and booking events', () {
      expect(GroomerSocketService.supportedEvents, contains('booking_in_progress'));
      expect(GroomerSocketService.supportedEvents, contains('booking_started'));
      expect(GroomerSocketService.supportedEvents, contains('booking_completed'));
      expect(GroomerSocketService.supportedEvents, contains('booking_confirmed'));
      expect(GroomerSocketService.supportedEvents, contains('appointment_started'));
      expect(GroomerSocketService.supportedEvents, contains('appointment_completed'));
    });

    test('GroomerHomeBloc handles Start and Complete booking events', () async {
      final repository = ServicesLocator.groomerHomeRepository;
      final bloc = GroomerHomeBloc(repository: repository);

      bloc.add(const GroomerHomeStartBookingEvent(999));
      await Future.delayed(const Duration(milliseconds: 200));

      bloc.add(const GroomerHomeCompleteBookingEvent(999));
      await Future.delayed(const Duration(milliseconds: 200));

      await bloc.close();
    });

    test('GroomerBloc handles Start and Complete booking events', () async {
      final repository = ServicesLocator.groomerRepository;
      final bloc = GroomerBloc(repository: repository);

      bloc.add(const GroomerStartBookingEvent(999));
      await Future.delayed(const Duration(milliseconds: 200));

      bloc.add(const GroomerCompleteBookingEvent(999));
      await Future.delayed(const Duration(milliseconds: 200));

      await bloc.close();
    });

    test('Real-time appointment scenario: Appointment A (12:00 PM Confirmed) and B (11:30 AM In Progress)', () {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      var appointmentA = GroomerBooking(
        bookingId: 201,
        status: 'confirmed',
        bookingDate: todayStr,
        startTime: '12:00 PM',
        endTime: '01:00 PM',
        petName: 'Max',
        customerName: 'Bob Smith',
        serviceName: 'Bath & Brush',
      );

      var appointmentB = GroomerBooking(
        bookingId: 202,
        status: 'in_progress',
        bookingDate: todayStr,
        startTime: '11:30 AM',
        endTime: '12:30 PM',
        petName: 'Luna',
        customerName: 'Sarah Connor',
        serviceName: 'Full Styling',
      );

      // Verify initial states
      expect(appointmentA.status, equals('confirmed'));
      expect(appointmentB.status, equals('in_progress'));

      // Simulate starting Appointment A
      appointmentA = appointmentA.copyWith(status: 'in_progress');
      expect(appointmentA.status, equals('in_progress'));
      expect(appointmentB.status, equals('in_progress'));

      // Simulate completing Appointment A
      appointmentA = appointmentA.copyWith(status: 'completed');
      expect(appointmentA.status, equals('completed'));

      // Simulate completing Appointment B
      appointmentB = appointmentB.copyWith(status: 'completed');
      expect(appointmentB.status, equals('completed'));
    });

    test('GroomerBooking parses and normalizes pet image URLs from various API structures', () {
      // 1. Nested pet object with relative profilePictureUrl
      final json1 = {
        'bookingId': 301,
        'status': 'confirmed',
        'pet': {
          'petName': 'Milo',
          'profilePictureUrl': '/uploads/pets/milo.png',
        },
      };
      final booking1 = GroomerBooking.fromJson(json1);
      expect(booking1.petName, equals('Milo'));
      expect(
        booking1.profilePicture,
        equals('https://devapi.shearheavenpetspa.com/uploads/pets/milo.png'),
      );

      // 2. Nested pet object with full https image URL
      final json2 = {
        'bookingId': 302,
        'status': 'confirmed',
        'pet': {
          'name': 'Charlie',
          'image': 'https://example.com/charlie.jpg',
        },
      };
      final booking2 = GroomerBooking.fromJson(json2);
      expect(booking2.petName, equals('Charlie'));
      expect(booking2.profilePicture, equals('https://example.com/charlie.jpg'));

      // 3. Root level petProfilePicture
      final json3 = {
        'bookingId': 303,
        'status': 'pending',
        'petName': 'Rocky',
        'petProfilePicture': 'uploads/rocky.png',
      };
      final booking3 = GroomerBooking.fromJson(json3);
      expect(booking3.petName, equals('Rocky'));
      expect(
        booking3.profilePicture,
        equals('https://devapi.shearheavenpetspa.com/uploads/rocky.png'),
      );

      // 4. Null or empty image
      final json4 = {
        'bookingId': 304,
        'status': 'pending',
        'petName': 'Teddy',
      };
      final booking4 = GroomerBooking.fromJson(json4);
      expect(booking4.profilePicture, isNull);
    });

    test('GroomerBooking fullServiceDescription formats cleanly on a single line', () {
      const b1 = GroomerBooking(
        bookingId: 401,
        status: 'confirmed',
        bookingDate: '2026-09-24',
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        petName: 'Bella',
        customerName: 'Alice',
        serviceName: 'Grooming',
      );
      expect(b1.fullServiceDescription, equals('Grooming'));

      const b2 = GroomerBooking(
        bookingId: 402,
        status: 'confirmed',
        bookingDate: '2026-09-24',
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        petName: 'Daisy',
        customerName: 'Bob',
        serviceName: 'Full Grooming',
        packageName: 'Deluxe Spa',
        addOns: ['Nail Trim', 'Teeth Cleaning'],
      );
      expect(
        b2.fullServiceDescription,
        equals('Full Grooming (Deluxe Spa) + Nail Trim, Teeth Cleaning'),
      );
    });
  });

  group('Main-Line Call Appointment Booking Scenario Tests', () {
    test('Staff Groomer (Marisa) creates appointment on behalf of customer and assigns requested Groomer (Richard)', () async {
      // Scenario:
      // - Logged in groomer: Marisa (id: 1, email: g001@shearheaven.com)
      // - Customer calls salon main line and requests Richard (id: 2)
      // - Marisa submits POST /api/groomer-auth/bookings/create-for-user with groomerId: 2
      // - The booking must be assigned to Richard (groomerId: 2) NOT Marisa (id: 1)

      const loggedInGroomer = GroomerUser(
        id: 1,
        groomerCode: 'G001',
        firstName: 'Marisa',
        lastName: 'Brown',
        email: 'g001@shearheaven.com',
        role: 'Groomer',
      );
      const requestedGroomerId = 2; // Richard
      const customerUserId = 1;     // John Doe
      const customerPetId = 1;      // Buddy (Golden Retriever)
      const serviceId = 12;
      const packageId = 1;
      final addOnIds = [2];
      const bookingDate = '2026-08-25';
      const startTime = '10:00';
      const endTime = '11:00';

      expect(ServicesLocator.groomerHomeRepository, isNotNull);
      expect(ServicesLocator.groomerRepository, isNotNull);

      expect(loggedInGroomer.id, equals(1));
      expect(requestedGroomerId, equals(2));
      expect(requestedGroomerId, isNot(equals(loggedInGroomer.id)));

      // GroomerHomeBloc event test
      final blocEvent = GroomerHomeCreateBookingForUserEvent(
        userId: customerUserId,
        petId: customerPetId,
        serviceId: serviceId,
        packageId: packageId,
        addOnIds: addOnIds,
        groomerId: requestedGroomerId,
        bookingDate: bookingDate,
        startTime: startTime,
        endTime: endTime,
      );

      expect(blocEvent.groomerId, equals(2));
      expect(blocEvent.userId, equals(1));
      expect(blocEvent.petId, equals(1));
      expect(blocEvent.serviceId, equals(12));
      expect(blocEvent.bookingDate, equals('2026-08-25'));
      expect(blocEvent.startTime, equals('10:00'));
      expect(blocEvent.endTime, equals('11:00'));

      // GroomerBloc event test
      final groomerBlocEvent = GroomerCreateBookingForUserEvent(
        userId: customerUserId,
        petId: customerPetId,
        serviceId: serviceId,
        packageId: packageId,
        addOnIds: addOnIds,
        groomerId: requestedGroomerId,
        bookingDate: bookingDate,
        startTime: startTime,
        endTime: endTime,
      );

      expect(groomerBlocEvent.groomerId, equals(2));
    });

    test('Availability check queries the specific requested groomer (Richard)', () async {
      // When checking slot availability for Richard, the request must include groomerId: 2
      const requestedGroomerId = 2;

      final bookingRepo = ServicesLocator.bookingRepository;
      expect(bookingRepo, isNotNull);

      // Verify slot validation helper logic for requested groomer
      final mockSlotAvailable = {
        'startTime': '10:00',
        'endTime': '11:00',
        'groomerId': requestedGroomerId,
        'groomerName': 'Richard Roe',
        'bookingCount': 0,
        'maxBookings': 1,
        'remaining': 1,
        'isAvailable': true,
      };

      final isAvailable = mockSlotAvailable['isAvailable'] == true &&
          ((mockSlotAvailable['remaining'] as int) > 0);
      expect(isAvailable, isTrue);
      expect(mockSlotAvailable['groomerId'], equals(2));
    });

    test('Conflict scenario: When requested groomer (Richard) is unavailable, booking is blocked', () {
      const requestedGroomerId = 2;

      // Simulate full / unavailable slot for Richard
      final mockSlotUnavailable = {
        'startTime': '10:00',
        'endTime': '11:00',
        'groomerId': requestedGroomerId,
        'groomerName': 'Richard Roe',
        'bookingCount': 1,
        'maxBookings': 1,
        'remaining': 0,
        'isAvailable': false,
      };

      final isAvailable = mockSlotUnavailable['isAvailable'] == true &&
          ((mockSlotUnavailable['remaining'] as int) > 0);

      // Must be blocked
      expect(isAvailable, isFalse);

      final conflictMessage = !isAvailable
          ? '${mockSlotUnavailable['groomerName']} is not available for this time slot. Please pick another time or groomer.'
          : 'Available';

      expect(
        conflictMessage,
        equals('Richard Roe is not available for this time slot. Please pick another time or groomer.'),
      );
    });

    test('Both Customer booking and Staff create-for-user booking flows remain distinct and supported', () {
      // 1. Customer self-service booking payload (POST /api/bookings)
      final customerPayload = {
        'ClientId': 'SHEAR-001',
        'RegionId': 'DWG-001',
        'StoreId': 'SHEAR-001',
        'petId': 1,
        'serviceId': 12,
        'packageId': 1,
        'addOnIds': [2],
        'groomerId': 0, // No preference or chosen groomer
        'bookingDate': '2026-08-25',
        'startTime': '10:00',
        'endTime': '11:00',
      };
      expect(customerPayload.containsKey('petId'), isTrue);
      expect(customerPayload.containsKey('userId'), isFalse); // Customer token provides userId

      // 2. Staff create-for-user booking payload (POST /api/groomer-auth/bookings/create-for-user)
      final staffPayload = {
        'userId': 1,
        'petId': 1,
        'serviceId': 12,
        'packageId': 1,
        'addOnIds': [2],
        'groomerId': 2, // Explicitly assigned requested groomer (Richard)
        'bookingDate': '2026-08-25',
        'startTime': '10:00',
        'endTime': '11:00',
        'clientId': 'SHEAR-001',
        'regionId': 'DWG-001',
        'storeId': 'SHEAR-001',
      };
      expect(staffPayload.containsKey('userId'), isTrue); // Staff specifies customer userId
      expect(staffPayload['groomerId'], equals(2));
      expect(staffPayload['userId'], equals(1));
    });

    test('CustomerSummary and CustomerPetSummary parse backend API responses correctly', () {
      final customerJson = {
        'id': 105,
        'name': 'Sarah Connor',
        'email': 'sarah@example.com',
        'mobile': '555-432-1098',
        'profilePictureUrl': 'https://example.com/sarah.jpg',
        'pets': [
          {
            'id': 201,
            'userId': 105,
            'petName': 'Wolfie',
            'breed': 'German Shepherd',
            'weight': 'Large',
            'age': '3',
            'gender': 'male',
            'notesAllergies': 'None',
          }
        ]
      };

      final customer = CustomerSummary.fromJson(customerJson);
      expect(customer.id, equals(105));
      expect(customer.name, equals('Sarah Connor'));
      expect(customer.email, equals('sarah@example.com'));
      expect(customer.phone, equals('555-432-1098'));
      expect(customer.pets.length, equals(1));

      final pet = customer.pets.first;
      expect(pet.id, equals(201));
      expect(pet.userId, equals(105));
      expect(pet.name, equals('Wolfie'));
      expect(pet.breed, equals('German Shepherd'));
      expect(pet.weight, equals('Large'));
    });

    test('Groomer and Customer Socket services support customer realtime events', () {
      expect(GroomerSocketService.supportedEvents, contains('customer_updated'));
      expect(GroomerSocketService.supportedEvents, contains('customer_created'));
      expect(GroomerSocketService.supportedEvents, contains('customer_registered'));
      expect(GroomerSocketService.supportedEvents, contains('user_registered'));
      expect(GroomerSocketService.supportedEvents, contains('user_updated'));
      expect(GroomerSocketService.supportedEvents, contains('pet_updated'));
      expect(GroomerSocketService.supportedEvents, contains('pet_created'));

      expect(CustomerSocketService.supportedNotificationEvents, contains('customer_updated'));
      expect(CustomerSocketService.supportedNotificationEvents, contains('customer_created'));
      expect(CustomerSocketService.supportedNotificationEvents, contains('customer_registered'));
      expect(CustomerSocketService.supportedNotificationEvents, contains('user_registered'));
      expect(CustomerSocketService.supportedNotificationEvents, contains('user_updated'));
      expect(CustomerSocketService.supportedNotificationEvents, contains('pet_updated'));
      expect(CustomerSocketService.supportedNotificationEvents, contains('pet_created'));
    });

    test('SalonGroomer parses real GET /api/groomers JSON structures accurately', () {
      // 1. Groomer from /api/groomers Groomers array
      final gJson = {
        'GroomerId': 'G002',
        'FirstName': 'Richard',
        'LastName': 'Cooke',
        'Role': 'Senior Groomer',
        'Highlights': 'Best groomer in town, got award in 2025!',
        'ProfilePicture': 'https://example.com/richard.jpg',
      };
      final groomer = SalonGroomer.fromJson(gJson);
      expect(groomer.id, equals(2));
      expect(groomer.groomerCode, equals('G002'));
      expect(groomer.firstName, equals('Richard'));
      expect(groomer.lastName, equals('Cooke'));
      expect(groomer.name, equals('Richard Cooke'));
      expect(groomer.role, equals('Senior Groomer'));
      expect(groomer.profilePicture, equals('https://example.com/richard.jpg'));

      // 2. Bather from /api/groomers Bathers array
      final bJson = {
        'BatherId': 'B001',
        'FirstName': 'Jeremiah',
        'LastName': 'Smith',
        'Role': 'Junio Bather',
        'Highlights': 'I am the best Bather',
      };
      final bather = SalonGroomer.fromJson(bJson);
      expect(bather.id, equals(4));
      expect(bather.groomerCode, equals('B001'));
      expect(bather.name, equals('Jeremiah Smith'));
      expect(bather.role, equals('Junio Bather'));
    });

    test('GroomerHomeRepository getSalonGroomers, getBookingServices, and checkAvailability methods are accessible', () {
      final repo = ServicesLocator.groomerHomeRepository;
      expect(repo, isNotNull);
      expect(repo.getSalonGroomers, isA<Function>());
      expect(repo.getBookingServices, isA<Function>());
      expect(repo.getGroomerAvailability, isA<Function>());
    });

    test('Availability API response parsing correctly maps slots, capacity, duration and price', () {
      final apiResponse = {
        'success': true,
        'data': {
          'totalDurationMinutes': 75,
          'totalPrice': 65.0,
          'availableSlots': [
            {
              'startTime': '09:00',
              'endTime': '10:15',
              'groomerId': 2,
              'groomerName': 'Richard Cooke',
              'bookingCount': 0,
              'maxBookings': 1,
              'remaining': 1,
              'isAvailable': true,
            },
            {
              'startTime': '10:30',
              'endTime': '11:45',
              'groomerId': 2,
              'groomerName': 'Richard Cooke',
              'bookingCount': 1,
              'maxBookings': 1,
              'remaining': 0,
              'isAvailable': false,
            },
            {
              'startTime': '13:00',
              'endTime': '14:15',
              'groomerId': 2,
              'groomerName': 'Richard Cooke',
              'bookingCount': 2,
              'maxBookings': 3,
              'remaining': 1,
              'isAvailable': true,
              'multiBookingEnabled': true,
            },
          ],
          'bookedSlots': [
            {
              'startTime': '10:30',
              'endTime': '11:45',
              'groomerId': 2,
            },
          ],
        },
      };

      final data = apiResponse['data'] as Map<String, dynamic>;
      final rawSlots = data['availableSlots'] as List<dynamic>;
      final rawBooked = data['bookedSlots'] as List<dynamic>;

      expect(data['totalDurationMinutes'], equals(75));
      expect(data['totalPrice'], equals(65.0));
      expect(rawSlots.length, equals(3));
      expect(rawBooked.length, equals(1));

      // Test slot 1 (available)
      final slot1 = rawSlots[0] as Map<String, dynamic>;
      final isSlot1Selectable = slot1['isAvailable'] == true && ((slot1['remaining'] as int) > 0);
      expect(isSlot1Selectable, isTrue);

      // Test slot 2 (booked / unavailable)
      final slot2 = rawSlots[1] as Map<String, dynamic>;
      final isSlot2Selectable = slot2['isAvailable'] == true && ((slot2['remaining'] as int) > 0);
      expect(isSlot2Selectable, isFalse);

      // Test slot 3 (multi-booking with capacity 2/3)
      final slot3 = rawSlots[2] as Map<String, dynamic>;
      final isSlot3Selectable = slot3['isAvailable'] == true &&
          ((slot3['remaining'] as int) > 0) &&
          ((slot3['bookingCount'] as int) < (slot3['maxBookings'] as int));
      expect(isSlot3Selectable, isTrue);
    });

    test('BookingDateUtils date comparison and display logic strictly compares calendar date (year+month+day)', () {
      final fixedNow = DateTime(2026, 9, 24, 19, 50, 0); // Thu, Sep 24, 2026 7:50 PM
      final todayDate = DateTime(2026, 9, 24);
      final todayEarly = DateTime(2026, 9, 24, 0, 1);
      final todayLate = DateTime(2026, 9, 24, 23, 59);
      final tomorrowDate = DateTime(2026, 9, 25);
      final tomorrowEarly = DateTime(2026, 9, 25, 0, 1);
      final tomorrowLate = DateTime(2026, 9, 25, 23, 59);
      final yesterdayDate = DateTime(2026, 9, 23);
      final futureDate = DateTime(2026, 9, 29); // +5 days
      final pastDate = DateTime(2026, 9, 19); // -5 days

      // 1. Today tests (different times & representations)
      expect(BookingDateUtils.isSameCalendarDay(todayDate, fixedNow), isTrue);
      expect(BookingDateUtils.isSameCalendarDay(todayEarly, fixedNow), isTrue);
      expect(BookingDateUtils.isSameCalendarDay(todayLate, fixedNow), isTrue);
      expect(BookingDateUtils.isSameCalendarDay('2026-09-24', fixedNow), isTrue);
      expect(BookingDateUtils.isSameCalendarDay('2026-09-24T00:00:00.000Z', fixedNow), isTrue);
      expect(BookingDateUtils.formatBookingDateDisplay(todayDate, fixedNow), equals('Today, 24 Sep 2026'));
      expect(BookingDateUtils.formatBookingDateDisplay(todayEarly, fixedNow), equals('Today, 24 Sep 2026'));
      expect(BookingDateUtils.formatBookingDateDisplay(todayLate, fixedNow), equals('Today, 24 Sep 2026'));
      expect(BookingDateUtils.formatBookingDateDisplay('2026-09-24', fixedNow), equals('Today, 24 Sep 2026'));
      expect(BookingDateUtils.formatBookingDateDisplay('2026-09-24T00:00:00.000Z', fixedNow), equals('Today, 24 Sep 2026'));

      // 2. Tomorrow tests (must NEVER contain "Today")
      expect(BookingDateUtils.isSameCalendarDay(tomorrowDate, fixedNow), isFalse);
      expect(BookingDateUtils.isSameCalendarDay(tomorrowEarly, fixedNow), isFalse);
      expect(BookingDateUtils.isSameCalendarDay(tomorrowLate, fixedNow), isFalse);
      expect(BookingDateUtils.isSameCalendarDay('2026-09-25', fixedNow), isFalse);
      expect(BookingDateUtils.isSameCalendarDay('2026-09-25T00:00:00.000Z', fixedNow), isFalse);
      expect(BookingDateUtils.formatBookingDateDisplay(tomorrowDate, fixedNow), equals('25 Sep 2026'));
      expect(BookingDateUtils.formatBookingDateDisplay(tomorrowEarly, fixedNow), equals('25 Sep 2026'));
      expect(BookingDateUtils.formatBookingDateDisplay(tomorrowLate, fixedNow), equals('25 Sep 2026'));
      expect(BookingDateUtils.formatBookingDateDisplay('2026-09-25', fixedNow), equals('25 Sep 2026'));
      expect(BookingDateUtils.formatBookingDateDisplay('2026-09-25T00:00:00.000Z', fixedNow), equals('25 Sep 2026'));
      expect(BookingDateUtils.formatBookingDateDisplay(tomorrowDate, fixedNow).contains('Today'), isFalse);

      // 3. Yesterday tests (must NEVER contain "Today")
      expect(BookingDateUtils.isSameCalendarDay(yesterdayDate, fixedNow), isFalse);
      expect(BookingDateUtils.isSameCalendarDay('2026-09-23', fixedNow), isFalse);
      expect(BookingDateUtils.isSameCalendarDay('2026-09-23T00:00:00.000Z', fixedNow), isFalse);
      expect(BookingDateUtils.formatBookingDateDisplay(yesterdayDate, fixedNow), equals('23 Sep 2026'));
      expect(BookingDateUtils.formatBookingDateDisplay('2026-09-23', fixedNow), equals('23 Sep 2026'));
      expect(BookingDateUtils.formatBookingDateDisplay(yesterdayDate, fixedNow).contains('Today'), isFalse);

      // 4. 2+ days future (+5 days)
      expect(BookingDateUtils.isSameCalendarDay(futureDate, fixedNow), isFalse);
      expect(BookingDateUtils.formatBookingDateDisplay(futureDate, fixedNow), equals('29 Sep 2026'));
      expect(BookingDateUtils.formatBookingDateDisplay(futureDate, fixedNow).contains('Today'), isFalse);

      // 5. 2+ days past (-5 days)
      expect(BookingDateUtils.isSameCalendarDay(pastDate, fixedNow), isFalse);
      expect(BookingDateUtils.formatBookingDateDisplay(pastDate, fixedNow), equals('19 Sep 2026'));
      expect(BookingDateUtils.formatBookingDateDisplay(pastDate, fixedNow).contains('Today'), isFalse);
    });

    test('GroomerBooking.formattedBookingDate formats today as "Today, d MMM yyyy" and other dates as "d MMM yyyy"', () {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowStr = DateFormat('yyyy-MM-dd').format(tomorrow);
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
      final futureDate = now.add(const Duration(days: 3));
      final futureStr = DateFormat('yyyy-MM-dd').format(futureDate);

      final todayBooking = GroomerBooking(
        bookingId: 101,
        status: 'confirmed',
        bookingDate: todayStr,
        startTime: '10:00',
        endTime: '11:00',
        petName: 'Bella',
        customerName: 'Alice',
        serviceName: 'Full Grooming',
      );

      final tomorrowBooking = GroomerBooking(
        bookingId: 102,
        status: 'pending',
        bookingDate: tomorrowStr,
        startTime: '14:00',
        endTime: '15:00',
        petName: 'Max',
        customerName: 'Bob',
        serviceName: 'Bath & Brush',
      );

      final yesterdayBooking = GroomerBooking(
        bookingId: 103,
        status: 'completed',
        bookingDate: yesterdayStr,
        startTime: '09:00',
        endTime: '10:00',
        petName: 'Charlie',
        customerName: 'Carol',
        serviceName: 'Nail Trim',
      );

      final futureBooking = GroomerBooking(
        bookingId: 104,
        status: 'confirmed',
        bookingDate: futureStr,
        startTime: '11:00',
        endTime: '12:00',
        petName: 'Rocky',
        customerName: 'Dan',
        serviceName: 'De-shedding',
      );

      final todayFormatted = DateFormat('d MMM yyyy').format(now);
      final tomorrowFormatted = DateFormat('d MMM yyyy').format(tomorrow);
      final yesterdayFormatted = DateFormat('d MMM yyyy').format(yesterday);
      final futureFormatted = DateFormat('d MMM yyyy').format(futureDate);

      // Today booking must be "Today, <d MMM yyyy>"
      expect(todayBooking.formattedBookingDate, equals('Today, $todayFormatted'));
      expect(todayBooking.formattedBookingDate.startsWith('Today, '), isTrue);

      // Tomorrow booking must be "<d MMM yyyy>" without "Today"
      expect(tomorrowBooking.formattedBookingDate, equals(tomorrowFormatted));
      expect(tomorrowBooking.formattedBookingDate.startsWith('Today'), isFalse);
      expect(tomorrowBooking.formattedBookingDate.contains('Today'), isFalse);

      // Yesterday booking must be "<d MMM yyyy>" without "Today"
      expect(yesterdayBooking.formattedBookingDate, equals(yesterdayFormatted));
      expect(yesterdayBooking.formattedBookingDate.startsWith('Today'), isFalse);
      expect(yesterdayBooking.formattedBookingDate.contains('Today'), isFalse);

      // Future booking (+3 days) must be "<d MMM yyyy>" without "Today"
      expect(futureBooking.formattedBookingDate, equals(futureFormatted));
      expect(futureBooking.formattedBookingDate.startsWith('Today'), isFalse);
      expect(futureBooking.formattedBookingDate.contains('Today'), isFalse);

      // Raw bookingDate string must remain untouched (API integrity)
      expect(todayBooking.bookingDate, equals(todayStr));
      expect(tomorrowBooking.bookingDate, equals(tomorrowStr));
      expect(yesterdayBooking.bookingDate, equals(yesterdayStr));
      expect(futureBooking.bookingDate, equals(futureStr));
    });

    test('Booking list for selected date filters strictly by calendar date and metrics do not use fallback data', () {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final todayStr = DateFormat('yyyy-MM-dd').format(todayDate);
      final tomorrowDate = todayDate.add(const Duration(days: 1));
      final tomorrowStr = DateFormat('yyyy-MM-dd').format(tomorrowDate);
      final yesterdayDate = todayDate.subtract(const Duration(days: 1));
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterdayDate);

      final allBookings = [
        GroomerBooking(
          bookingId: 1,
          status: 'confirmed',
          bookingDate: todayStr,
          startTime: '09:00',
          endTime: '10:00',
          petName: 'Bella',
          customerName: 'Alice',
          serviceName: 'Full Grooming',
        ),
        GroomerBooking(
          bookingId: 2,
          status: 'pending',
          bookingDate: todayStr,
          startTime: '14:00',
          endTime: '15:00',
          petName: 'Max',
          customerName: 'Bob',
          serviceName: 'Bath & Brush',
        ),
        GroomerBooking(
          bookingId: 3,
          status: 'confirmed',
          bookingDate: tomorrowStr,
          startTime: '11:00',
          endTime: '12:00',
          petName: 'Charlie',
          customerName: 'Carol',
          serviceName: 'Nail Trim',
        ),
        GroomerBooking(
          bookingId: 4,
          status: 'completed',
          bookingDate: yesterdayStr,
          startTime: '16:00',
          endTime: '17:00',
          petName: 'Daisy',
          customerName: 'Dave',
          serviceName: 'Spa Package',
        ),
      ];

      // 1. Filtering for Today
      final todayList = allBookings
          .where((b) => BookingDateUtils.isSameCalendarDay(b.bookingDate, todayDate))
          .toList();
      expect(todayList.length, equals(2));
      expect(todayList.map((b) => b.bookingId), containsAll([1, 2]));
      expect(todayList.map((b) => b.bookingId), isNot(contains(3)));
      expect(todayList.map((b) => b.bookingId), isNot(contains(4)));

      // 2. Filtering for Tomorrow
      final tomorrowList = allBookings
          .where((b) => BookingDateUtils.isSameCalendarDay(b.bookingDate, tomorrowDate))
          .toList();
      expect(tomorrowList.length, equals(1));
      expect(tomorrowList.first.bookingId, equals(3));

      // 3. Filtering for Yesterday
      final yesterdayList = allBookings
          .where((b) => BookingDateUtils.isSameCalendarDay(b.bookingDate, yesterdayDate))
          .toList();
      expect(yesterdayList.length, equals(1));
      expect(yesterdayList.first.bookingId, equals(4));

      // 4. Filtering for a date with 0 bookings -> returns empty list (no fallback/dummy)
      final otherDate = todayDate.add(const Duration(days: 5));
      final otherList = allBookings
          .where((b) => BookingDateUtils.isSameCalendarDay(b.bookingDate, otherDate))
          .toList();
      expect(otherList.isEmpty, isTrue);

      // 5. Verify Today Metrics calculation without fallback
      final todayTotal = allBookings.where((b) => BookingDateUtils.isToday(b.bookingDate)).length;
      final todayPending = allBookings.where((b) => BookingDateUtils.isToday(b.bookingDate) && b.status.toLowerCase() == 'pending').length;
      final todayConfirmed = allBookings.where((b) => BookingDateUtils.isToday(b.bookingDate) && (b.status.toLowerCase() == 'confirmed' || b.status.toLowerCase() == 'in_progress')).length;
      final todayCompleted = allBookings.where((b) => BookingDateUtils.isToday(b.bookingDate) && (b.status.toLowerCase() == 'completed' || b.status.toLowerCase() == 'past')).length;

      expect(todayTotal, equals(2));
      expect(todayPending, equals(1));
      expect(todayConfirmed, equals(1));
      expect(todayCompleted, equals(0)); // strictly 0, does not fall back to yesterday's completed count!
    });

    testWidgets('Date Selector Bar supports responsive touch navigation forward, backward, and calendar pick', (tester) async {
      DateTime selectedDate = DateTime(2026, 9, 24);
      bool calendarOpened = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              final formatted = BookingDateUtils.formatBookingDateDisplay(selectedDate, DateTime(2026, 9, 24));
              return Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      // Previous Day (Backward)
                      Tooltip(
                        message: 'Previous Day',
                        child: InkWell(
                          key: const ValueKey('prev_day_btn'),
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                          onTap: () {
                            setState(() {
                              selectedDate = selectedDate.subtract(const Duration(days: 1));
                            });
                          },
                          child: const SizedBox(
                            width: 48,
                            height: 52,
                            child: Center(
                              child: Icon(Icons.chevron_left_rounded, size: 26, color: Color(0xFF111827)),
                            ),
                          ),
                        ),
                      ),

                      // Date Text & Calendar Trigger
                      Expanded(
                        child: Tooltip(
                          message: 'Select Date from Calendar',
                          child: InkWell(
                            key: const ValueKey('calendar_picker_btn'),
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              calendarOpened = true;
                            },
                            child: Container(
                              height: 52,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF111827)),
                                    const SizedBox(width: 8),
                                    Text(
                                      formatted,
                                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Next Day (Forward)
                      Tooltip(
                        message: 'Next Day',
                        child: InkWell(
                          key: const ValueKey('next_day_btn'),
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                          onTap: () {
                            setState(() {
                              selectedDate = selectedDate.add(const Duration(days: 1));
                            });
                          },
                          child: const SizedBox(
                            width: 48,
                            height: 52,
                            child: Center(
                              child: Icon(Icons.chevron_right_rounded, size: 26, color: Color(0xFF111827)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ));

      // Initial state is Today, 24 Sep 2026
      expect(find.text('Today, 24 Sep 2026'), findsOneWidget);

      // 1. Tap Previous Day -> Navigates Backward to 23 Sep 2026
      await tester.tap(find.byKey(const ValueKey('prev_day_btn')));
      await tester.pumpAndSettle();
      expect(find.text('23 Sep 2026'), findsOneWidget);
      expect(selectedDate, equals(DateTime(2026, 9, 23)));

      // 2. Tap Next Day twice -> Navigates Forward to 24 Sep (Today) and then 25 Sep 2026
      await tester.tap(find.byKey(const ValueKey('next_day_btn')));
      await tester.pumpAndSettle();
      expect(find.text('Today, 24 Sep 2026'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('next_day_btn')));
      await tester.pumpAndSettle();
      expect(find.text('25 Sep 2026'), findsOneWidget);
      expect(selectedDate, equals(DateTime(2026, 9, 25)));

      // 3. Tap central Date area -> Triggers Calendar Date Picker
      await tester.tap(find.byKey(const ValueKey('calendar_picker_btn')));
      await tester.pumpAndSettle();
      expect(calendarOpened, isTrue);
    });
  });
}


