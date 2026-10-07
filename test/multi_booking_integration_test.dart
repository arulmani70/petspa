import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/bookings/models/slot_capacity.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';

void main() {
  group('Multi-Booking & Groomer Slot Capacity Test Suite', () {
    // ─────────────────────────────────────────────────────────────────────────
    // 1. Capacity States (0/3 -> 3/3 & 4th Rejection)
    // ─────────────────────────────────────────────────────────────────────────
    group('1. Slot Capacity Transitions (0/3 -> 3/3)', () {
      test('Scenario 1: 0/3 capacity is available and selectable', () {
        final slot = SlotCapacity.fromSlotData({
          'startTime': '09:00',
          'endTime': '10:00',
          'bookingCount': 0,
          'maxBookings': 3,
          'remaining': 3,
          'isAvailable': true,
        });

        expect(slot.isAvailable, isTrue);
        expect(slot.remaining, equals(3));
        expect(slot.bookingCount, equals(0));
        expect(slot.maxBookings, equals(3));
        expect(slot.capacityLabel, equals('0 / 3'));
      });

      test('Scenario 2: 1/3 capacity is available and selectable', () {
        final slot = SlotCapacity.fromSlotData({
          'startTime': '09:00',
          'endTime': '10:00',
          'bookingCount': 1,
          'maxBookings': 3,
          'remaining': 2,
          'isAvailable': true,
        });

        expect(slot.isAvailable, isTrue);
        expect(slot.remaining, equals(2));
        expect(slot.bookingCount, equals(1));
        expect(slot.maxBookings, equals(3));
        expect(slot.capacityLabel, equals('1 / 3'));
      });

      test('Scenario 3: 2/3 capacity is available and selectable', () {
        final slot = SlotCapacity.fromSlotData({
          'startTime': '09:00',
          'endTime': '10:00',
          'bookingCount': 2,
          'maxBookings': 3,
          'remaining': 1,
          'isAvailable': true,
        });

        expect(slot.isAvailable, isTrue);
        expect(slot.remaining, equals(1));
        expect(slot.bookingCount, equals(2));
        expect(slot.maxBookings, equals(3));
        expect(slot.capacityLabel, equals('2 / 3'));
      });

      test('Scenario 4: 3/3 capacity is FULL / BLOCKED and unselectable', () {
        final slot = SlotCapacity.fromSlotData({
          'startTime': '09:00',
          'endTime': '10:00',
          'bookingCount': 3,
          'maxBookings': 3,
          'remaining': 0,
          'isAvailable': false,
        });

        expect(slot.isAvailable, isFalse);
        expect(slot.remaining, equals(0));
        expect(slot.bookingCount, equals(3));
        expect(slot.capacityLabel, equals('3 / 3'));
      });

      test('Scenario 5: 4th booking attempt is blocked', () {
        final slot = SlotCapacity.fromSlotData({
          'startTime': '09:00',
          'endTime': '10:00',
          'bookingCount': 4,
          'maxBookings': 3,
          'remaining': 0,
          'isAvailable': false,
        });

        expect(slot.isAvailable, isFalse);
        expect(slot.remaining, equals(0));
        expect(slot.bookingCount, equals(4));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Single-Booking Mode (multiBookingEnabled = false)
    // ─────────────────────────────────────────────────────────────────────────
    group('2. Single-Booking Mode Validation', () {
      test('0/1 capacity is available', () {
        final groomer = {'multiBookingEnabled': false, 'slotBookingLimit': 1};
        final slot = SlotCapacity.fromSlotData({
          'startTime': '09:00',
          'endTime': '10:00',
          'bookingCount': 0,
          'maxBookings': 1,
          'remaining': 1,
          'isAvailable': true,
        }, groomerData: groomer);

        expect(slot.isMultiBookingEnabled, isFalse);
        expect(slot.isAvailable, isTrue);
        expect(slot.maxBookings, equals(1));
        expect(slot.bookingCount, equals(0));
      });

      test('1/1 capacity is blocked (any existing booking blocks slot)', () {
        final groomer = {'multiBookingEnabled': false, 'slotBookingLimit': 1};
        final slot = SlotCapacity.fromSlotData({
          'startTime': '09:00',
          'endTime': '10:00',
          'bookingCount': 1,
          'maxBookings': 1,
          'remaining': 0,
          'isAvailable': false,
        }, groomerData: groomer);

        expect(slot.isMultiBookingEnabled, isFalse);
        expect(slot.isAvailable, isFalse);
        expect(slot.remaining, equals(0));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Multi-Groomer Independence
    // ─────────────────────────────────────────────────────────────────────────
    group('3. Multi-Groomer Independence', () {
      test('Groomer A full (3/3) does not block Groomer B (1/3)', () {
        final groomerA = {'id': 1, 'name': 'Alice', 'multiBookingEnabled': true, 'slotBookingLimit': 3};
        final groomerB = {'id': 2, 'name': 'Bob', 'multiBookingEnabled': true, 'slotBookingLimit': 3};

        final slotA = SlotCapacity.fromSlotData({
          'startTime': '10:00',
          'bookingCount': 3,
          'maxBookings': 3,
          'remaining': 0,
          'isAvailable': false,
        }, groomerData: groomerA);

        final slotB = SlotCapacity.fromSlotData({
          'startTime': '10:00',
          'bookingCount': 1,
          'maxBookings': 3,
          'remaining': 2,
          'isAvailable': true,
        }, groomerData: groomerB);

        expect(slotA.isAvailable, isFalse);
        expect(slotB.isAvailable, isTrue);
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Pre-Flight Review Capacity Validation
    // ─────────────────────────────────────────────────────────────────────────
    group('4. Pre-Flight Review Page Capacity Validation', () {
      bool isPreFlightValid(SlotCapacity cap) {
        return cap.isAvailable && cap.remaining > 0 && cap.bookingCount < cap.maxBookings;
      }

      test('Allows booking when slot capacity has remaining spots (2/3)', () {
        final cap = SlotCapacity.fromSlotData({
          'startTime': '14:00',
          'bookingCount': 2,
          'maxBookings': 3,
          'remaining': 1,
          'isAvailable': true,
        });

        expect(isPreFlightValid(cap), isTrue);
      });

      test('Blocks booking when slot capacity reached (3/3)', () {
        final cap = SlotCapacity.fromSlotData({
          'startTime': '14:00',
          'bookingCount': 3,
          'maxBookings': 3,
          'remaining': 0,
          'isAvailable': false,
        });

        expect(isPreFlightValid(cap), isFalse);
      });

      test('Blocks booking when isAvailable is explicitly false', () {
        final cap = SlotCapacity.fromSlotData({
          'startTime': '14:00',
          'bookingCount': 1,
          'maxBookings': 3,
          'remaining': 2,
          'isAvailable': false,
        });

        expect(isPreFlightValid(cap), isFalse);
      });

      test('Blocks booking when remaining is 0', () {
        final cap = SlotCapacity.fromSlotData({
          'startTime': '14:00',
          'bookingCount': 1,
          'maxBookings': 3,
          'remaining': 0,
          'isAvailable': true,
        });

        expect(isPreFlightValid(cap), isFalse);
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Booking Status Capacity Rules
    // ─────────────────────────────────────────────────────────────────────────
    group('5. Booking Status Capacity Counting Rules', () {
      int calculateCapacityFromBookings(List<Map<String, dynamic>> bookings, int maxLimit) {
        int count = 0;
        for (final b in bookings) {
          final status = b['status']?.toString().toLowerCase();
          // Count: pending, confirmed, cancellation_requested
          // Exclude: cancelled, rejected, completed
          if (status == 'pending' || status == 'confirmed' || status == 'cancellation_requested') {
            count++;
          }
        }
        return count;
      }

      test('Pending, confirmed, and cancellation_requested bookings count toward capacity', () {
        final bookings = [
          {'id': 101, 'status': 'pending'},
          {'id': 102, 'status': 'confirmed'},
          {'id': 103, 'status': 'cancellation_requested'},
        ];

        final count = calculateCapacityFromBookings(bookings, 3);
        expect(count, equals(3));

        final cap = SlotCapacity.fromSlotData({
          'bookingCount': count,
          'maxBookings': 3,
          'remaining': 3 - count,
          'isAvailable': count < 3,
        });

        expect(cap.isAvailable, isFalse);
        expect(cap.remaining, equals(0));
      });

      test('Cancelled and rejected bookings are excluded from capacity', () {
        final bookings = [
          {'id': 101, 'status': 'pending'},
          {'id': 102, 'status': 'cancelled'},
          {'id': 103, 'status': 'rejected'},
        ];

        final count = calculateCapacityFromBookings(bookings, 3);
        expect(count, equals(1)); // Only the pending booking counts

        final cap = SlotCapacity.fromSlotData({
          'bookingCount': count,
          'maxBookings': 3,
          'remaining': 3 - count,
          'isAvailable': count < 3,
        });

        expect(cap.isAvailable, isTrue);
        expect(cap.remaining, equals(2));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 6. Backend 409 GROOMER_NOT_AVAILABLE Handling
    // ─────────────────────────────────────────────────────────────────────────
    group('6. Backend 409 / GROOMER_NOT_AVAILABLE Handling', () {
      test('Correctly recognizes GROOMER_NOT_AVAILABLE error code', () {
        final errorResponse = {
          'success': false,
          'code': 'GROOMER_NOT_AVAILABLE',
          'message': 'Groomer slot is no longer available.',
          'statusCode': 409,
        };

        final isSlotTaken = errorResponse['code'] == 'GROOMER_NOT_AVAILABLE' ||
            errorResponse['statusCode'] == 409;

        expect(isSlotTaken, isTrue);
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 7. Exact Frontend Slot Pipeline for 1/3 Case (09:00-10:00)
    // ─────────────────────────────────────────────────────────────────────────
    group('7. Exact Frontend Slot Pipeline for 1/3 Case (09:00-10:00)', () {
      test('09:00-10:00 slot with bookingCount=1, maxBookings=3 is selectable and NOT blocked', () {
        // Mock Step 1 API response data
        final step1Slot = {
          'startTime': '09:00',
          'endTime': '10:00',
          'groomerId': 1,
          'groomerName': 'Merisa Brown',
          'bookingCount': 1,
          'maxBookings': 3,
          'remaining': 2,
          'isAvailable': true,
        };

        final capacity = SlotCapacity.fromSlotData(step1Slot, groomerData: {
          'multiBookingEnabled': true,
          'slotBookingLimit': 3,
        });

        // 1. Capacity parsing
        expect(capacity.bookingCount, equals(1));
        expect(capacity.maxBookings, equals(3));
        expect(capacity.remaining, equals(2));
        expect(capacity.isAvailable, isTrue);
        expect(capacity.capacityLabel, equals('1 / 3'));

        // 2. Selectability check
        final bool isSelectable = (capacity.isAvailable && capacity.remaining > 0) ||
            (capacity.isMultiBookingEnabled && capacity.bookingCount < capacity.maxBookings);
        expect(isSelectable, isTrue);

        // 3. UI Status mapping check
        final bool isAtCapacity = !capacity.isAvailable || capacity.remaining <= 0;
        expect(isAtCapacity, isFalse);
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 8. Contiguous Slot Availability Sequence (09:00-10:00 & 10:00-11:00)
    // ─────────────────────────────────────────────────────────────────────────
    group('8. Contiguous Slot Availability Sequence (09:00-10:00 & 10:00-11:00)', () {
      int countOverlaps(int startMin, int durationMin, List<Map<String, dynamic>> booked) {
        final endMin = startMin + durationMin;
        int count = 0;
        for (final b in booked) {
          final partsS = (b['startTime'] as String).split(':');
          final partsE = (b['endTime'] as String).split(':');
          final bStart = int.parse(partsS[0]) * 60 + int.parse(partsS[1]);
          final bEnd = int.parse(partsE[0]) * 60 + int.parse(partsE[1]);
          if (bStart >= bEnd) continue;
          if (startMin < bEnd && endMin > bStart) {
            count++;
          }
        }
        return count;
      }

      test('Customer 1 books 09:00-10:00 -> 09:00 is 1/3 and 10:00 is 0/3 with no gap', () {
        const int maxBookings = 3;
        const int durationMin = 60;

        // Existing booked slots after Customer 1 books 09:00 - 10:00
        final bookedSlots = [
          {'bookingId': 101, 'startTime': '09:00', 'endTime': '10:00', 'status': 'confirmed'}
        ];

        // 1. Candidate 09:00 - 10:00 (540 to 600 min)
        final overlap0900 = countOverlaps(9 * 60, durationMin, bookedSlots);
        expect(overlap0900, equals(1));

        final cap0900 = SlotCapacity.fromSlotData({
          'startTime': '09:00',
          'endTime': '10:00',
          'bookingCount': overlap0900,
          'maxBookings': maxBookings,
          'remaining': maxBookings - overlap0900,
          'isAvailable': overlap0900 < maxBookings,
        }, groomerData: {'multiBookingEnabled': true, 'slotBookingLimit': maxBookings});

        expect(cap0900.bookingCount, equals(1));
        expect(cap0900.remaining, equals(2));
        expect(cap0900.isAvailable, isTrue);

        // 2. Candidate 10:00 - 11:00 (600 to 660 min)
        final overlap1000 = countOverlaps(10 * 60, durationMin, bookedSlots);
        expect(overlap1000, equals(0)); // 09:00-10:00 ends exactly at 10:00 -> NO OVERLAP

        final cap1000 = SlotCapacity.fromSlotData({
          'startTime': '10:00',
          'endTime': '11:00',
          'bookingCount': overlap1000,
          'maxBookings': maxBookings,
          'remaining': maxBookings - overlap1000,
          'isAvailable': overlap1000 < maxBookings,
        }, groomerData: {'multiBookingEnabled': true, 'slotBookingLimit': maxBookings});

        expect(cap1000.bookingCount, equals(0));
        expect(cap1000.remaining, equals(3));
        expect(cap1000.isAvailable, isTrue);

        // 3. Verify contiguous timing: 09:00 slot ends at 10:00, 10:00 slot starts at 10:00 (0 gap)
        expect(cap0900.isAvailable, isTrue);
        expect(cap1000.isAvailable, isTrue);
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 9. Working Hours Starting at 08:30 Offset with 15-minute Candidate Grid
    // ─────────────────────────────────────────────────────────────────────────
    group('9. Working Hours Starting at 08:30 with 15-minute Candidate Grid', () {
      List<String> generateCandidateStartTimes(int startMin, int endMin, int durationMin) {
        const int kSlotIntervalMinutes = 15;
        final list = <String>[];
        int cursor = startMin;
        while (cursor + durationMin <= endMin) {
          final h = cursor ~/ 60;
          final m = cursor % 60;
          list.add('${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
          cursor += kSlotIntervalMinutes;
        }
        return list;
      }

      test('08:30-17:00 shift with 60-minute service generates all 15-minute candidates including 09:00 and 10:00', () {
        final candidates = generateCandidateStartTimes(8 * 60 + 30, 17 * 60, 60);

        // Check start times: 08:30, 08:45, 09:00, 09:15, 09:30, 09:45, 10:00, 10:15, 10:30...
        expect(candidates.contains('08:30'), isTrue);
        expect(candidates.contains('08:45'), isTrue);
        expect(candidates.contains('09:00'), isTrue);
        expect(candidates.contains('09:15'), isTrue);
        expect(candidates.contains('09:30'), isTrue);
        expect(candidates.contains('09:45'), isTrue);
        expect(candidates.contains('10:00'), isTrue);
        expect(candidates.contains('10:15'), isTrue);

        // Verify that 09:00 and 10:00 were NOT skipped
        expect(candidates.indexOf('09:00'), equals(2));
        expect(candidates.indexOf('10:00'), equals(6));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 10. Multi-User Sequential Capacity Test (Customers A, B, C, D on same slot)
    // ─────────────────────────────────────────────────────────────────────────
    group('10. Multi-User Sequential Capacity Test (3 Concurrent Bookings on 09:00-10:00)', () {
      bool isSlotSelectable(SlotCapacity capacity) {
        return (capacity.isAvailable && capacity.remaining > 0) ||
            (capacity.isMultiBookingEnabled && capacity.bookingCount < capacity.maxBookings);
      }

      test('Sequential bookings by Customer A, B, C succeed and remaining goes 3 -> 2 -> 1 -> 0 (Customer D blocked)', () {
        const int maxBookings = 3;
        final groomerSettings = {'multiBookingEnabled': true, 'slotBookingLimit': maxBookings};

        // 1. Initial State (0 bookings)
        final initialSlot = {
          'startTime': '09:00',
          'endTime': '10:00',
          'bookingCount': 0,
          'maxBookings': maxBookings,
          'remaining': 3,
          'isAvailable': true,
        };
        final cap0 = SlotCapacity.fromSlotData(initialSlot, groomerData: groomerSettings);
        expect(cap0.bookingCount, equals(0));
        expect(cap0.remaining, equals(3));
        expect(cap0.isAvailable, isTrue);
        expect(isSlotSelectable(cap0), isTrue);

        // 2. Customer A books 09:00-10:00 -> Booking #1 succeeds
        // Active bookings: [Booking A]
        final activeBookingsAfterA = [
          {'id': 101, 'userId': 'user_A', 'startTime': '09:00', 'endTime': '10:00', 'status': 'confirmed'}
        ];
        final countAfterA = activeBookingsAfterA.length;

        // 3. Customer B requests availability
        final slotViewCustomerB = {
          'startTime': '09:00',
          'endTime': '10:00',
          'bookingCount': countAfterA,
          'maxBookings': maxBookings,
          'remaining': maxBookings - countAfterA,
          'isAvailable': countAfterA < maxBookings,
        };
        final capB = SlotCapacity.fromSlotData(slotViewCustomerB, groomerData: groomerSettings);
        expect(capB.bookingCount, equals(1));
        expect(capB.remaining, equals(2));
        expect(capB.isAvailable, isTrue);
        expect(isSlotSelectable(capB), isTrue); // MUST be selectable for Customer B!

        // 4. Customer B books 09:00-10:00 -> Booking #2 succeeds
        // Active bookings: [Booking A, Booking B]
        final activeBookingsAfterB = [
          {'id': 101, 'userId': 'user_A', 'startTime': '09:00', 'endTime': '10:00', 'status': 'confirmed'},
          {'id': 102, 'userId': 'user_B', 'startTime': '09:00', 'endTime': '10:00', 'status': 'confirmed'},
        ];
        final countAfterB = activeBookingsAfterB.length;

        // 5. Customer C requests availability
        final slotViewCustomerC = {
          'startTime': '09:00',
          'endTime': '10:00',
          'bookingCount': countAfterB,
          'maxBookings': maxBookings,
          'remaining': maxBookings - countAfterB,
          'isAvailable': countAfterB < maxBookings,
        };
        final capC = SlotCapacity.fromSlotData(slotViewCustomerC, groomerData: groomerSettings);
        expect(capC.bookingCount, equals(2));
        expect(capC.remaining, equals(1));
        expect(capC.isAvailable, isTrue);
        expect(isSlotSelectable(capC), isTrue); // MUST be selectable for Customer C!

        // 6. Customer C books 09:00-10:00 -> Booking #3 succeeds
        // Active bookings: [Booking A, Booking B, Booking C]
        final activeBookingsAfterC = [
          {'id': 101, 'userId': 'user_A', 'startTime': '09:00', 'endTime': '10:00', 'status': 'confirmed'},
          {'id': 102, 'userId': 'user_B', 'startTime': '09:00', 'endTime': '10:00', 'status': 'confirmed'},
          {'id': 103, 'userId': 'user_C', 'startTime': '09:00', 'endTime': '10:00', 'status': 'confirmed'},
        ];
        final countAfterC = activeBookingsAfterC.length;

        // 7. Customer D requests availability (Capacity is now 3/3 FULL)
        final slotViewCustomerD = {
          'startTime': '09:00',
          'endTime': '10:00',
          'bookingCount': countAfterC,
          'maxBookings': maxBookings,
          'remaining': maxBookings - countAfterC,
          'isAvailable': countAfterC < maxBookings,
        };
        final capD = SlotCapacity.fromSlotData(slotViewCustomerD, groomerData: groomerSettings);
        expect(capD.bookingCount, equals(3));
        expect(capD.remaining, equals(0));
        expect(capD.isAvailable, isFalse);
        expect(isSlotSelectable(capD), isFalse); // Slot is FULL / UNSELECTABLE for Customer D!

        // 8. Verify capacity progression: 3 -> 2 -> 1 -> 0
        expect([cap0.remaining, capB.remaining, capC.remaining, capD.remaining], equals([3, 2, 1, 0]));
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // 11. Multi-User Capacity & Selectability Test (15:30-16:30)
    // ─────────────────────────────────────────────────────────────────────────
    group('11. Multi-User Capacity & Selectability Test (15:30-16:30)', () {
      const int maxBookings = 3;
      final groomerSettings = {'multiBookingEnabled': true, 'slotBookingLimit': maxBookings};

      test('0/3 -> selectable, 1/3 -> selectable, 2/3 -> selectable, 3/3 -> not selectable', () {
        // State 0: 0 bookings (0/3)
        final slot0 = {
          'startTime': '15:30',
          'endTime': '16:30',
          'bookingCount': 0,
          'maxBookings': maxBookings,
          'remaining': 3,
          'isAvailable': true,
        };
        final cap0 = SlotCapacity.fromSlotData(slot0, groomerData: groomerSettings);
        expect(cap0.bookingCount, equals(0));
        expect(cap0.remaining, equals(3));
        expect(cap0.isAvailable, isTrue);
        expect(cap0.isSelectable, isTrue, reason: '0/3 must be selectable');

        // State 1: 1 booking (1/3)
        final slot1 = {
          'startTime': '15:30',
          'endTime': '16:30',
          'bookingCount': 1,
          'maxBookings': maxBookings,
          'remaining': 2,
          'isAvailable': true,
        };
        final cap1 = SlotCapacity.fromSlotData(slot1, groomerData: groomerSettings);
        expect(cap1.bookingCount, equals(1));
        expect(cap1.remaining, equals(2));
        expect(cap1.isAvailable, isTrue);
        expect(cap1.isSelectable, isTrue, reason: '1/3 must remain selectable because capacity remains');

        // State 2: 2 bookings (2/3)
        final slot2 = {
          'startTime': '15:30',
          'endTime': '16:30',
          'bookingCount': 2,
          'maxBookings': maxBookings,
          'remaining': 1,
          'isAvailable': true,
        };
        final cap2 = SlotCapacity.fromSlotData(slot2, groomerData: groomerSettings);
        expect(cap2.bookingCount, equals(2));
        expect(cap2.remaining, equals(1));
        expect(cap2.isAvailable, isTrue);
        expect(cap2.isSelectable, isTrue, reason: '2/3 must remain selectable because capacity remains');

        // State 3: 3 bookings (3/3 - FULL)
        final slot3 = {
          'startTime': '15:30',
          'endTime': '16:30',
          'bookingCount': 3,
          'maxBookings': maxBookings,
          'remaining': 0,
          'isAvailable': false,
        };
        final cap3 = SlotCapacity.fromSlotData(slot3, groomerData: groomerSettings);
        expect(cap3.bookingCount, equals(3));
        expect(cap3.remaining, equals(0));
        expect(cap3.isAvailable, isFalse);
        expect(cap3.isSelectable, isFalse, reason: '3/3 must NOT be selectable because capacity is exhausted');
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // GROUP 12: Pure Frontend Already-Booked Calculation & Normalization
    // ─────────────────────────────────────────────────────────────────────────
    group('Group 12: Pure Frontend Already-Booked Calculation (BookingDateUtils)', () {
      test('12.1 Exact match on date, groomer, startTime, endTime marks alreadyBooked = true', () {
        final userBookings = [
          {
            'bookingId': 101,
            'bookingDate': '2026-08-28',
            'groomerId': 1,
            'startTime': '15:30',
            'endTime': '16:30',
            'status': 'confirmed',
          },
        ];

        final alreadyBooked = BookingDateUtils.isSlotAlreadyBookedByUser(
          slotDate: '2026-08-28',
          slotStartTime: '15:30',
          slotEndTime: '16:30',
          slotGroomerId: 1,
          slotDurationMinutes: 60,
          userBookings: userBookings,
        );

        expect(alreadyBooked, isTrue);
      });

      test('12.2 Date normalization handles DateTime, ISO string, and space-separated formats', () {
        final userBookings = [
          {
            'bookingId': 102,
            'bookingDate': '2026-08-28T00:00:00.000Z',
            'groomerId': 1,
            'startTime': '15:30:00',
            'endTime': '16:30:00',
            'status': 'pending',
          },
        ];

        // Slot date passed as DateTime
        final alreadyBooked1 = BookingDateUtils.isSlotAlreadyBookedByUser(
          slotDate: DateTime(2026, 8, 28),
          slotStartTime: '15:30',
          slotEndTime: '16:30',
          slotGroomerId: 1,
          userBookings: userBookings,
        );
        expect(alreadyBooked1, isTrue);

        // Slot date passed as string '2026-08-28'
        final alreadyBooked2 = BookingDateUtils.isSlotAlreadyBookedByUser(
          slotDate: '2026-08-28',
          slotStartTime: '15:30',
          slotEndTime: '16:30',
          slotGroomerId: 1,
          userBookings: userBookings,
        );
        expect(alreadyBooked2, isTrue);
      });

      test('12.3 Time normalization handles HH:mm, HH:mm:ss, H:mm, AM/PM', () {
        final userBookings = [
          {
            'bookingId': 103,
            'bookingDate': '2026-08-28',
            'groomerId': 2,
            'startTime': '3:30 PM',
            'endTime': '4:30 PM',
            'status': 'confirmed',
          },
        ];

        final alreadyBooked = BookingDateUtils.isSlotAlreadyBookedByUser(
          slotDate: '2026-08-28',
          slotStartTime: '15:30',
          slotEndTime: '16:30',
          slotGroomerId: 2,
          userBookings: userBookings,
        );

        expect(alreadyBooked, isTrue);
      });

      test('12.4 Inactive booking statuses (cancelled, rejected, completed) do NOT block slot', () {
        final userBookings = [
          {
            'bookingId': 104,
            'bookingDate': '2026-08-28',
            'groomerId': 1,
            'startTime': '15:30',
            'endTime': '16:30',
            'status': 'cancelled',
          },
          {
            'bookingId': 105,
            'bookingDate': '2026-08-28',
            'groomerId': 1,
            'startTime': '15:30',
            'endTime': '16:30',
            'status': 'rejected',
          },
          {
            'bookingId': 106,
            'bookingDate': '2026-08-28',
            'groomerId': 1,
            'startTime': '15:30',
            'endTime': '16:30',
            'status': 'completed',
          },
        ];

        final alreadyBooked = BookingDateUtils.isSlotAlreadyBookedByUser(
          slotDate: '2026-08-28',
          slotStartTime: '15:30',
          slotEndTime: '16:30',
          slotGroomerId: 1,
          userBookings: userBookings,
        );

        expect(alreadyBooked, isFalse);
      });

      test('12.5 Different groomer ID or different date does NOT block slot', () {
        final userBookings = [
          {
            'bookingId': 107,
            'bookingDate': '2026-08-28',
            'groomerId': 1,
            'startTime': '15:30',
            'endTime': '16:30',
            'status': 'confirmed',
          },
        ];

        // Different groomer (Groomer 2)
        final alreadyBookedOtherGroomer = BookingDateUtils.isSlotAlreadyBookedByUser(
          slotDate: '2026-08-28',
          slotStartTime: '15:30',
          slotEndTime: '16:30',
          slotGroomerId: 2,
          userBookings: userBookings,
        );
        expect(alreadyBookedOtherGroomer, isFalse);

        // Different date (2026-08-29)
        final alreadyBookedOtherDate = BookingDateUtils.isSlotAlreadyBookedByUser(
          slotDate: '2026-08-29',
          slotStartTime: '15:30',
          slotEndTime: '16:30',
          slotGroomerId: 1,
          userBookings: userBookings,
        );
        expect(alreadyBookedOtherDate, isFalse);
      });

      test('12.6 Overlapping slot time window is detected', () {
        final userBookings = [
          {
            'bookingId': 108,
            'bookingDate': '2026-08-28',
            'groomerId': 1,
            'startTime': '15:30',
            'endTime': '16:30',
            'status': 'in_progress',
          },
        ];

        // Candidate 15:45 - 16:45 overlaps 15:30 - 16:30
        final alreadyBookedOverlap = BookingDateUtils.isSlotAlreadyBookedByUser(
          slotDate: '2026-08-28',
          slotStartTime: '15:45',
          slotEndTime: '16:45',
          slotGroomerId: 1,
          userBookings: userBookings,
        );
        expect(alreadyBookedOverlap, isTrue);

        // Candidate 16:30 - 17:30 starts right when previous ends (adjacent, non-overlapping)
        final alreadyBookedAdjacent = BookingDateUtils.isSlotAlreadyBookedByUser(
          slotDate: '2026-08-28',
          slotStartTime: '16:30',
          slotEndTime: '17:30',
          slotGroomerId: 1,
          userBookings: userBookings,
        );
        expect(alreadyBookedAdjacent, isFalse);
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // GROUP 13: Exact 3:00 PM Multi-Booking Capacity & 30-min Slot Grid Tests
    // ─────────────────────────────────────────────────────────────────────────
    group('Group 13: Multi-Booking 3:00 PM Capacity & 30-Minute Grid Rule', () {
      test('Case 1: bookingCount=0, maxBookings=3, remaining=3, isAvailable=true -> 3:00 selectable', () {
        final slotData = {
          'startTime': '15:00',
          'endTime': '15:30',
          'bookingCount': 0,
          'maxBookings': 3,
          'remaining': 3,
          'isAvailable': true,
        };
        final cap = SlotCapacity.fromSlotData(slotData);
        expect(cap.bookingCount, equals(0));
        expect(cap.maxBookings, equals(3));
        expect(cap.remaining, equals(3));
        expect(cap.isAvailable, isTrue);
        expect(cap.isSelectable, isTrue, reason: 'Case 1: 0/3 capacity must be selectable');
      });

      test('Case 2: bookingCount=1, maxBookings=3, remaining=2, isAvailable=true -> 3:00 selectable', () {
        final slotData = {
          'startTime': '15:00',
          'endTime': '15:30',
          'bookingCount': 1,
          'maxBookings': 3,
          'remaining': 2,
          'isAvailable': true,
        };
        final cap = SlotCapacity.fromSlotData(slotData);
        expect(cap.bookingCount, equals(1));
        expect(cap.maxBookings, equals(3));
        expect(cap.remaining, equals(2));
        expect(cap.isAvailable, isTrue);
        expect(cap.isSelectable, isTrue, reason: 'Case 2: 1/3 capacity must be selectable for next customer');
      });

      test('Case 3: bookingCount=2, maxBookings=3, remaining=1, isAvailable=true -> 3:00 selectable', () {
        final slotData = {
          'startTime': '15:00',
          'endTime': '15:30',
          'bookingCount': 2,
          'maxBookings': 3,
          'remaining': 1,
          'isAvailable': true,
        };
        final cap = SlotCapacity.fromSlotData(slotData);
        expect(cap.bookingCount, equals(2));
        expect(cap.maxBookings, equals(3));
        expect(cap.remaining, equals(1));
        expect(cap.isAvailable, isTrue);
        expect(cap.isSelectable, isTrue, reason: 'Case 3: 2/3 capacity must be selectable for next customer');
      });

      test('Case 4: bookingCount=3, maxBookings=3, remaining=0, isAvailable=false -> 3:00 NOT selectable', () {
        final slotData = {
          'startTime': '15:00',
          'endTime': '15:30',
          'bookingCount': 3,
          'maxBookings': 3,
          'remaining': 0,
          'isAvailable': false,
        };
        final cap = SlotCapacity.fromSlotData(slotData);
        expect(cap.bookingCount, equals(3));
        expect(cap.maxBookings, equals(3));
        expect(cap.remaining, equals(0));
        expect(cap.isAvailable, isFalse);
        expect(cap.isSelectable, isFalse, reason: 'Case 4: 3/3 capacity reached -> slot is blocked/unselectable');
      });

      test('Case 5: 30-minute availability slots (15:00-15:30, 15:30-16:00, 16:00-16:30) are rendered without artificial 15:15 slot', () {
        final backendAvailableSlots = [
          {
            'startTime': '15:00',
            'endTime': '15:30',
            'bookingCount': 1,
            'maxBookings': 3,
            'remaining': 2,
            'isAvailable': true,
          },
          {
            'startTime': '15:30',
            'endTime': '16:00',
            'bookingCount': 0,
            'maxBookings': 3,
            'remaining': 3,
            'isAvailable': true,
          },
          {
            'startTime': '16:00',
            'endTime': '16:30',
            'bookingCount': 0,
            'maxBookings': 3,
            'remaining': 3,
            'isAvailable': true,
          },
        ];

        // Parse slots directly from API response
        final parsedSlots = backendAvailableSlots.map((s) {
          final cap = SlotCapacity.fromSlotData(s);
          return {
            'startTime': s['startTime'],
            'endTime': s['endTime'],
            'capacity': cap,
            'isSelectable': cap.isSelectable,
          };
        }).toList();

        final startTimes = parsedSlots.map((s) => s['startTime']).toList();
        expect(startTimes, equals(['15:00', '15:30', '16:00']));
        expect(startTimes.contains('15:15'), isFalse, reason: 'No artificial 15:15 slot should exist');

        // Verify 15:00 is selectable for Customer B
        expect(parsedSlots[0]['isSelectable'], isTrue);
        expect((parsedSlots[0]['capacity'] as SlotCapacity).remaining, equals(2));
      });

      test('Case 6: 30-minute duration generates 30-minute grid across shift (15:00, 15:30, 16:00, 16:30)', () {
        const int shiftStart = 15 * 60; // 15:00
        const int shiftEnd = 17 * 60;   // 17:00
        const int durationMin = 30;

        final generatedStartTimes = <String>[];
        int cursor = shiftStart;
        while (cursor + durationMin <= shiftEnd) {
          final h = (cursor ~/ 60).toString().padLeft(2, '0');
          final m = (cursor % 60).toString().padLeft(2, '0');
          generatedStartTimes.add('$h:$m');
          cursor += durationMin;
        }

        expect(generatedStartTimes, equals(['15:00', '15:30', '16:00', '16:30']));
        expect(generatedStartTimes.contains('15:15'), isFalse);
      });

      test('Case 7: 60-minute duration generates 60-minute grid across shift (09:00, 10:00, 11:00, 12:00)', () {
        const int shiftStart = 9 * 60; // 09:00
        const int shiftEnd = 13 * 60;  // 13:00
        const int durationMin = 60;

        final generatedStartTimes = <String>[];
        int cursor = shiftStart;
        while (cursor + durationMin <= shiftEnd) {
          final h = (cursor ~/ 60).toString().padLeft(2, '0');
          final m = (cursor % 60).toString().padLeft(2, '0');
          generatedStartTimes.add('$h:$m');
          cursor += durationMin;
        }

        expect(generatedStartTimes, equals(['09:00', '10:00', '11:00', '12:00']));
        expect(generatedStartTimes.contains('09:15'), isFalse);
        expect(generatedStartTimes.contains('09:30'), isFalse);
      });

      test('Case 8: Customer B can select the same 3:00 slot when capacity remains (count=1, max=3, remaining=2, isAvailable=true)', () {
        final slotData = {
          'startTime': '15:00',
          'endTime': '15:30',
          'bookingCount': 1,
          'maxBookings': 3,
          'remaining': 2,
          'isAvailable': true,
        };
        final cap = SlotCapacity.fromSlotData(slotData);
        expect(cap.bookingCount, equals(1));
        expect(cap.maxBookings, equals(3));
        expect(cap.remaining, equals(2));
        expect(cap.isAvailable, isTrue);
        expect(cap.isSelectable, isTrue, reason: 'Customer B can select 3:00 PM because capacity remains');
      });

      test('Case 9: Reconstruct slot from working hours and bookedSlots when availableSlots is empty', () {
        final groomer = {
          'id': 1,
          'name': 'Sarah',
          'multiBookingEnabled': true,
          'slotBookingLimit': 3,
          'workingHours': {'startTime': '15:00', 'endTime': '17:00'},
          'bookedSlots': [
            {'startTime': '15:00', 'endTime': '15:30', 'groomerId': 1}
          ],
          'availableSlots': <dynamic>[],
        };

        const int durationMin = 30;
        final bookedSlots = (groomer['bookedSlots'] as List).cast<Map<String, dynamic>>();

        int countOverlapping(int start, int dur) {
          final end = start + dur;
          int count = 0;
          for (final b in bookedSlots) {
            final bs = int.parse(b['startTime'].split(':')[0]) * 60 + int.parse(b['startTime'].split(':')[1]);
            final be = int.parse(b['endTime'].split(':')[0]) * 60 + int.parse(b['endTime'].split(':')[1]);
            if (start < be && end > bs) count++;
          }
          return count;
        }

        final reconstructedSlots = <Map<String, dynamic>>[];
        int cursor = 15 * 60;
        while (cursor + durationMin <= 17 * 60) {
          final h = (cursor ~/ 60).toString().padLeft(2, '0');
          final m = (cursor % 60).toString().padLeft(2, '0');
          final st = '$h:$m';
          final overlap = countOverlapping(cursor, durationMin);
          final cap = SlotCapacity.fromGroomerData(groomer, maxBookingsForSlot: 3, bookingCountForSlot: overlap);
          reconstructedSlots.add({
            'startTime': st,
            'capacity': cap,
            'isSelectable': cap.isSelectable,
          });
          cursor += durationMin;
        }

        expect(reconstructedSlots.length, equals(4)); // 15:00, 15:30, 16:00, 16:30
        expect(reconstructedSlots[0]['startTime'], equals('15:00'));
        expect((reconstructedSlots[0]['capacity'] as SlotCapacity).bookingCount, equals(1));
        expect((reconstructedSlots[0]['capacity'] as SlotCapacity).remaining, equals(2));
        expect((reconstructedSlots[0]['capacity'] as SlotCapacity).isAvailable, isTrue);
        expect(reconstructedSlots[0]['isSelectable'], isTrue);
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // GROUP 14: Shared Capacity Across Customer Logins & Lifecycle (Tests 1–7)
    // ─────────────────────────────────────────────────────────────────────────
    group('Group 14: Shared Capacity Across Customer Logins & Lifecycle', () {
      const int maxBookings = 3;
      final groomerData = {
        'id': 1,
        'name': 'Sarah',
        'multiBookingEnabled': true,
        'slotBookingLimit': maxBookings,
      };

      test('TEST 1: Customer A sees 3:00 PM at 0/3 capacity -> visible + selectable', () {
        final slot = {'startTime': '15:00', 'endTime': '15:30', 'bookingCount': 0, 'maxBookings': 3, 'remaining': 3, 'isAvailable': true};
        final cap = SlotCapacity.fromSlotData(slot, groomerData: groomerData);
        expect(cap.bookingCount, equals(0));
        expect(cap.remaining, equals(3));
        expect(cap.isAvailable, isTrue);
        expect(cap.isSelectable, isTrue, reason: 'TEST 1: Customer A sees 3:00 as available and selectable');
      });

      test('TEST 2: After A books 3:00, capacity becomes 1/3 -> Customer B sees 3:00 + selectable', () {
        final slot = {'startTime': '15:00', 'endTime': '15:30', 'bookingCount': 1, 'maxBookings': 3, 'remaining': 2, 'isAvailable': true};
        final cap = SlotCapacity.fromSlotData(slot, groomerData: groomerData);
        expect(cap.bookingCount, equals(1));
        expect(cap.remaining, equals(2));
        expect(cap.isAvailable, isTrue);
        expect(cap.isSelectable, isTrue, reason: 'TEST 2: Customer B sees 3:00 as available and selectable');
      });

      test('TEST 3: After B books 3:00, capacity becomes 2/3 -> Customer C sees 3:00 + selectable', () {
        final slot = {'startTime': '15:00', 'endTime': '15:30', 'bookingCount': 2, 'maxBookings': 3, 'remaining': 1, 'isAvailable': true};
        final cap = SlotCapacity.fromSlotData(slot, groomerData: groomerData);
        expect(cap.bookingCount, equals(2));
        expect(cap.remaining, equals(1));
        expect(cap.isAvailable, isTrue);
        expect(cap.isSelectable, isTrue, reason: 'TEST 3: Customer C sees 3:00 as available and selectable');
      });

      test('TEST 4: After A logs in again, capacity is still 2/3 -> Customer A MUST see 3:00 + selectable', () {
        // Customer A logs back in. Capacity is shared: remaining = 1 spot left.
        final slot = {'startTime': '15:00', 'endTime': '15:30', 'bookingCount': 2, 'maxBookings': 3, 'remaining': 1, 'isAvailable': true};
        final cap = SlotCapacity.fromSlotData(slot, groomerData: groomerData);
        expect(cap.bookingCount, equals(2));
        expect(cap.remaining, equals(1));
        expect(cap.isAvailable, isTrue);
        expect(cap.isSelectable, isTrue, reason: 'TEST 4: Customer A MUST see and select 3:00 PM because 1 capacity spot remains');
      });

      test('TEST 5: After C books 3:00, capacity becomes 3/3 -> Customer D sees 3:00 + disabled/full', () {
        final slot = {'startTime': '15:00', 'endTime': '15:30', 'bookingCount': 3, 'maxBookings': 3, 'remaining': 0, 'isAvailable': false};
        final cap = SlotCapacity.fromSlotData(slot, groomerData: groomerData);
        expect(cap.bookingCount, equals(3));
        expect(cap.remaining, equals(0));
        expect(cap.isAvailable, isFalse);
        expect(cap.isSelectable, isFalse, reason: 'TEST 5: 3/3 capacity reached -> slot is disabled/full');
      });

      test('TEST 6: Existing booking by current user must NEVER hide the slot while remaining capacity > 0', () {
        // Shared capacity: 1 booking exists (by Customer A). Customer A opens slot view.
        final slot = {'startTime': '15:00', 'endTime': '15:30', 'bookingCount': 1, 'maxBookings': 3, 'remaining': 2, 'isAvailable': true};
        final cap = SlotCapacity.fromSlotData(slot, groomerData: groomerData);
        expect(cap.isAvailable, isTrue);
        expect(cap.remaining, equals(2));
        expect(cap.isSelectable, isTrue, reason: 'TEST 6: Customer A must NOT be hidden/disabled from slot while capacity remains');
      });

      test('TEST 7: No 3:15 / 15-minute artificial slot generation for 30-min and 60-min services', () {
        // 30-min service on 15:00-16:30
        final slots30 = <String>[];
        int cursor = 15 * 60;
        while (cursor + 30 <= 16 * 60 + 30) {
          final h = (cursor ~/ 60).toString().padLeft(2, '0');
          final m = (cursor % 60).toString().padLeft(2, '0');
          slots30.add('$h:$m');
          cursor += 30;
        }
        expect(slots30, equals(['15:00', '15:30', '16:00']));
        expect(slots30.contains('15:15'), isFalse);

        // 60-min service on 09:00-12:00
        final slots60 = <String>[];
        cursor = 9 * 60;
        while (cursor + 60 <= 12 * 60) {
          final h = (cursor ~/ 60).toString().padLeft(2, '0');
          final m = (cursor % 60).toString().padLeft(2, '0');
          slots60.add('$h:$m');
          cursor += 60;
        }
        expect(slots60, equals(['09:00', '10:00', '11:00']));
        expect(slots60.contains('09:15'), isFalse);
        expect(slots60.contains('09:30'), isFalse);
      });
    });

    // ─────────────────────────────────────────────────────────────────────────
    // GROUP 15: Customer Duplicate Booking Protection & Exact Duration Grid Tests
    // ─────────────────────────────────────────────────────────────────────────
    group('Group 15: Customer Duplicate Booking Protection & Exact Duration Grid', () {
      const String dateStr = '2026-08-27';
      const int groomerId = 1;
      const int maxBookings = 3;

      test('Case 1 & 2 & 3 & 4: Multi-customer capacity lifecycle on 11:00–12:00 (1/3 -> 2/3 -> 3/3 -> blocked)', () {
        // Customer A books 11:00-12:00 -> 1/3 capacity
        final slot1 = {'startTime': '11:00', 'endTime': '12:00', 'bookingCount': 1, 'maxBookings': maxBookings, 'remaining': 2, 'isAvailable': true};
        final cap1 = SlotCapacity.fromSlotData(slot1);
        expect(cap1.isSelectable, isTrue, reason: 'Customer B can book 11:00-12:00 when remaining=2');

        // Customer B books 11:00-12:00 -> 2/3 capacity
        final slot2 = {'startTime': '11:00', 'endTime': '12:00', 'bookingCount': 2, 'maxBookings': maxBookings, 'remaining': 1, 'isAvailable': true};
        final cap2 = SlotCapacity.fromSlotData(slot2);
        expect(cap2.isSelectable, isTrue, reason: 'Customer C can book 11:00-12:00 when remaining=1');

        // Customer C books 11:00-12:00 -> 3/3 capacity
        final slot3 = {'startTime': '11:00', 'endTime': '12:00', 'bookingCount': 3, 'maxBookings': maxBookings, 'remaining': 0, 'isAvailable': false};
        final cap3 = SlotCapacity.fromSlotData(slot3);
        expect(cap3.isSelectable, isFalse, reason: 'Customer D is blocked when remaining=0');
      });

      test('Case 5: Customer A cannot book 11:00–12:00 again (same exact slot)', () {
        final customerABookings = [
          {
            'bookingDate': dateStr,
            'startTime': '11:00',
            'endTime': '12:00',
            'groomerId': groomerId,
            'status': 'confirmed',
          }
        ];

        final isDuplicate = BookingDateUtils.isSlotAlreadyBookedByUser(
          slotDate: dateStr,
          slotStartTime: '11:00',
          slotEndTime: '12:00',
          slotGroomerId: groomerId,
          slotDurationMinutes: 60,
          userBookings: customerABookings,
        );
        expect(isDuplicate, isTrue, reason: 'Customer A cannot book exact same slot 11:00-12:00 again');
      });

      test('Case 6: Customer A cannot book overlapping 11:30–12:30 or 10:30–11:30', () {
        final customerABookings = [
          {
            'bookingDate': dateStr,
            'startTime': '11:00',
            'endTime': '12:00',
            'groomerId': groomerId,
            'status': 'confirmed',
          }
        ];

        // Attempt 11:30 - 12:30 (overlaps 11:00 - 12:00)
        final isDupOverlap1 = BookingDateUtils.isSlotAlreadyBookedByUser(
          slotDate: dateStr,
          slotStartTime: '11:30',
          slotEndTime: '12:30',
          slotGroomerId: groomerId,
          slotDurationMinutes: 60,
          userBookings: customerABookings,
        );
        expect(isDupOverlap1, isTrue, reason: 'Overlapping candidate 11:30-12:30 must be blocked for Customer A');

        // Attempt 10:30 - 11:30 (overlaps 11:00 - 12:00)
        final isDupOverlap2 = BookingDateUtils.isSlotAlreadyBookedByUser(
          slotDate: dateStr,
          slotStartTime: '10:30',
          slotEndTime: '11:30',
          slotGroomerId: groomerId,
          slotDurationMinutes: 60,
          userBookings: customerABookings,
        );
        expect(isDupOverlap2, isTrue, reason: 'Overlapping candidate 10:30-11:30 must be blocked for Customer A');
      });

      test('Case 7: Customer A may book non-overlapping adjacent 12:00–13:00', () {
        final customerABookings = [
          {
            'bookingDate': dateStr,
            'startTime': '11:00',
            'endTime': '12:00',
            'groomerId': groomerId,
            'status': 'confirmed',
          }
        ];

        final isDupAdjacent = BookingDateUtils.isSlotAlreadyBookedByUser(
          slotDate: dateStr,
          slotStartTime: '12:00',
          slotEndTime: '13:00',
          slotGroomerId: groomerId,
          slotDurationMinutes: 60,
          userBookings: customerABookings,
        );
        expect(isDupAdjacent, isFalse, reason: 'Adjacent slot 12:00-13:00 is not an overlap and is allowed');
      });

      test('Case 8 & 9: Selecting 11:00 for 60-min service produces 11:00–12:00 (never 10:30–11:00)', () {
        const int durationMin = 60;
        final groomer = {
          'id': 1,
          'name': 'Sarah',
          'multiBookingEnabled': true,
          'slotBookingLimit': 3,
          'workingHours': {'startTime': '09:00', 'endTime': '17:00'},
          'bookedSlots': [
            {'startTime': '11:00', 'endTime': '12:00'},
          ],
        };

        final bookedSlots = (groomer['bookedSlots'] as List).cast<Map<String, dynamic>>();

        int countOverlapping(int start, int dur) {
          final end = start + dur;
          int count = 0;
          for (final b in bookedSlots) {
            final bs = int.parse(b['startTime'].split(':')[0]) * 60 + int.parse(b['startTime'].split(':')[1]);
            final be = int.parse(b['endTime'].split(':')[0]) * 60 + int.parse(b['endTime'].split(':')[1]);
            if (start < be && end > bs) count++;
          }
          return count;
        }

        final slots = <Map<String, dynamic>>[];
        int cursor = 9 * 60;
        while (cursor + durationMin <= 17 * 60) {
          final h = (cursor ~/ 60).toString().padLeft(2, '0');
          final m = (cursor % 60).toString().padLeft(2, '0');
          final st = '$h:$m';
          final eh = ((cursor + durationMin) ~/ 60).toString().padLeft(2, '0');
          final em = ((cursor + durationMin) % 60).toString().padLeft(2, '0');
          final et = '$eh:$em';
          final overlap = countOverlapping(cursor, durationMin);
          final cap = SlotCapacity.fromGroomerData(groomer, maxBookingsForSlot: 3, bookingCountForSlot: overlap);
          slots.add({
            'startTime': st,
            'endTime': et,
            'capacity': cap,
            'isSelectable': cap.isSelectable,
          });
          cursor += durationMin;
        }

        final startTimes = slots.map((s) => s['startTime']).toList();
        expect(startTimes.contains('11:00'), isTrue);
        expect(startTimes.contains('10:30'), isFalse, reason: '10:30 must not be inserted for a 60-minute service');

        final slot11 = slots.firstWhere((s) => s['startTime'] == '11:00');
        expect(slot11['endTime'], equals('12:00'), reason: '60-min service at 11:00 must end at 12:00');
        expect((slot11['capacity'] as SlotCapacity).bookingCount, equals(1));
        expect((slot11['capacity'] as SlotCapacity).remaining, equals(2));
        expect(slot11['isSelectable'], isTrue, reason: 'Global capacity remains available for other customers');
      });

      test('Case 10 & 11 & 12: Service duration boundaries (30-min, 60-min, 90-min)', () {
        // 30-min service
        int cur30 = 11 * 60;
        final end30 = cur30 + 30;
        expect('${(cur30 ~/ 60).toString().padLeft(2, '0')}:${(cur30 % 60).toString().padLeft(2, '0')}', equals('11:00'));
        expect('${(end30 ~/ 60).toString().padLeft(2, '0')}:${(end30 % 60).toString().padLeft(2, '0')}', equals('11:30'));

        // 60-min service
        int cur60 = 11 * 60;
        final end60 = cur60 + 60;
        expect('${(cur60 ~/ 60).toString().padLeft(2, '0')}:${(cur60 % 60).toString().padLeft(2, '0')}', equals('11:00'));
        expect('${(end60 ~/ 60).toString().padLeft(2, '0')}:${(end60 % 60).toString().padLeft(2, '0')}', equals('12:00'));

        // 90-min service
        int cur90 = 11 * 60;
        final end90 = cur90 + 90;
        expect('${(cur90 ~/ 60).toString().padLeft(2, '0')}:${(cur90 % 60).toString().padLeft(2, '0')}', equals('11:00'));
        expect('${(end90 ~/ 60).toString().padLeft(2, '0')}:${(end90 % 60).toString().padLeft(2, '0')}', equals('12:30'));
      });

      test('Case 13 & 14: Existing booking counts affect global capacity without shifting start times or hiding slot', () {
        final slotData = {
          'startTime': '11:00',
          'endTime': '12:00',
          'bookingCount': 1,
          'maxBookings': 3,
          'remaining': 2,
          'isAvailable': true,
        };
        final cap = SlotCapacity.fromSlotData(slotData);
        expect(cap.bookingCount, equals(1));
        expect(cap.remaining, equals(2));
        expect(cap.isAvailable, isTrue);
        expect(cap.isSelectable, isTrue);
      });

      test('Case 15: Customer A sees slot as disabled (alreadyBooked) while Customer B sees same slot as available', () {
        final customerABookings = [
          {
            'bookingDate': dateStr,
            'startTime': '11:00',
            'endTime': '12:00',
            'groomerId': groomerId,
            'status': 'confirmed',
          }
        ];
        final customerBBookings = <Map<String, dynamic>>[];

        final slotCap = SlotCapacity.fromSlotData({
          'startTime': '11:00',
          'endTime': '12:00',
          'bookingCount': 1,
          'maxBookings': 3,
          'remaining': 2,
          'isAvailable': true,
        });

        // Customer A evaluation:
        final isAAlreadyBooked = BookingDateUtils.isSlotAlreadyBookedByUser(
          slotDate: dateStr,
          slotStartTime: '11:00',
          slotEndTime: '12:00',
          slotGroomerId: groomerId,
          slotDurationMinutes: 60,
          userBookings: customerABookings,
        );
        expect(isAAlreadyBooked, isTrue);

        // Customer B evaluation:
        final isBAlreadyBooked = BookingDateUtils.isSlotAlreadyBookedByUser(
          slotDate: dateStr,
          slotStartTime: '11:00',
          slotEndTime: '12:00',
          slotGroomerId: groomerId,
          slotDurationMinutes: 60,
          userBookings: customerBBookings,
        );
        expect(isBAlreadyBooked, isFalse);
        expect(slotCap.isSelectable, isTrue);
      });

      test('Case 16: Pre-flight safety check blocks confirmation if customer duplicate is detected', () {
        final customerABookings = [
          {
            'bookingDate': dateStr,
            'startTime': '11:00',
            'endTime': '12:00',
            'groomerId': groomerId,
            'status': 'confirmed',
          }
        ];

        // Customer A attempts to submit duplicate 11:00-12:00
        final isDup = BookingDateUtils.isSlotAlreadyBookedByUser(
          slotDate: dateStr,
          slotStartTime: '11:00',
          slotEndTime: '12:00',
          slotGroomerId: groomerId,
          slotDurationMinutes: 60,
          userBookings: customerABookings,
        );
        expect(isDup, isTrue, reason: 'Preflight safety check must detect customer duplicate and prevent submission');
      });
    });
  });
}
