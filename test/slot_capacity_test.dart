import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/bookings/models/slot_capacity.dart';

void main() {
  group('SlotCapacity Model & Logic Verification', () {
    test('1. Default single booking capacity', () {
      const cap = SlotCapacity.singleBooking();
      expect(cap.isMultiBookingEnabled, isFalse);
      expect(cap.maxBookings, equals(1));
      expect(cap.bookingCount, equals(0));
      expect(cap.isAvailable, isTrue);
      expect(cap.capacityLabel, isNull);
    });

    test('2. Multi-booking 0/3 is Available', () {
      const cap = SlotCapacity(
        isMultiBookingEnabled: true,
        maxBookings: 3,
        bookingCount: 0,
      );
      expect(cap.isAvailable, isTrue);
      expect(cap.remaining, equals(3));
      expect(cap.capacityLabel, equals('0 / 3'));
    });

    test('3. Multi-booking 1/3 is Available (Customer 2 can book)', () {
      const cap = SlotCapacity(
        isMultiBookingEnabled: true,
        maxBookings: 3,
        bookingCount: 1,
      );
      expect(cap.isAvailable, isTrue);
      expect(cap.remaining, equals(2));
      expect(cap.capacityLabel, equals('1 / 3'));
    });

    test('4. Multi-booking 2/3 is Available (Customer 3 can book)', () {
      const cap = SlotCapacity(
        isMultiBookingEnabled: true,
        maxBookings: 3,
        bookingCount: 2,
      );
      expect(cap.isAvailable, isTrue);
      expect(cap.remaining, equals(1));
      expect(cap.capacityLabel, equals('2 / 3'));
    });

    test('5. Multi-booking 3/3 is Blocked / Full (Customer 4 cannot book)', () {
      const cap = SlotCapacity(
        isMultiBookingEnabled: true,
        maxBookings: 3,
        bookingCount: 3,
      );
      expect(cap.isAvailable, isFalse);
      expect(cap.remaining, equals(0));
      expect(cap.capacityLabel, equals('3 / 3'));
    });

    test('6. Multi-booking 4/3 is NEVER allowed / Blocked', () {
      const cap = SlotCapacity(
        isMultiBookingEnabled: true,
        maxBookings: 3,
        bookingCount: 4,
      );
      expect(cap.isAvailable, isFalse);
      expect(cap.remaining, equals(0));
    });

    test('7. fromGroomerData with default bookingCount = 0', () {
      final groomer = {
        'id': 1,
        'multiBookingEnabled': true,
        'slotBookingLimit': 3,
      };
      final cap = SlotCapacity.fromGroomerData(groomer);
      expect(cap.isMultiBookingEnabled, isTrue);
      expect(cap.maxBookings, equals(3));
      expect(cap.bookingCount, equals(0));
      expect(cap.isAvailable, isTrue);
    });

    test('8. fromGroomerData with per-slot booking count', () {
      final groomer = {
        'id': 1,
        'multiBookingEnabled': true,
        'slotBookingLimit': 3,
      };
      final cap1 = SlotCapacity.fromGroomerData(groomer, bookingCountForSlot: 1);
      expect(cap1.bookingCount, equals(1));
      expect(cap1.isAvailable, isTrue);

      final cap3 = SlotCapacity.fromGroomerData(groomer, bookingCountForSlot: 3);
      expect(cap3.bookingCount, equals(3));
      expect(cap3.isAvailable, isFalse);
    });

    test('9. isSlotAvailable helper matching spec', () {
      expect(isSlotAvailable(bookingCount: 0, maxBookings: 3, isMultiBookingEnabled: true), isTrue);
      expect(isSlotAvailable(bookingCount: 1, maxBookings: 3, isMultiBookingEnabled: true), isTrue);
      expect(isSlotAvailable(bookingCount: 2, maxBookings: 3, isMultiBookingEnabled: true), isTrue);
      expect(isSlotAvailable(bookingCount: 3, maxBookings: 3, isMultiBookingEnabled: true), isFalse);
      expect(isSlotAvailable(bookingCount: 4, maxBookings: 3, isMultiBookingEnabled: true), isFalse);
    });

    test('10. fromSlotData directly maps backend fields (2/3 available)', () {
      final slotMap = {
        'startTime': '09:00',
        'endTime': '10:00',
        'bookingCount': 2,
        'maxBookings': 3,
        'remaining': 1,
        'isAvailable': true,
      };
      final cap = SlotCapacity.fromSlotData(slotMap);
      expect(cap.bookingCount, equals(2));
      expect(cap.maxBookings, equals(3));
      expect(cap.remaining, equals(1));
      expect(cap.isAvailable, isTrue);
      expect(cap.isMultiBookingEnabled, isTrue);
      expect(cap.capacityLabel, equals('2 / 3'));
    });

    test('11. fromSlotData directly maps backend fields (3/3 full/unavailable)', () {
      final slotMap = {
        'startTime': '10:00',
        'endTime': '11:00',
        'bookingCount': 3,
        'maxBookings': 3,
        'remaining': 0,
        'isAvailable': false,
      };
      final cap = SlotCapacity.fromSlotData(slotMap);
      expect(cap.bookingCount, equals(3));
      expect(cap.maxBookings, equals(3));
      expect(cap.remaining, equals(0));
      expect(cap.isAvailable, isFalse);
      expect(cap.capacityLabel, equals('3 / 3'));
    });

    test('12. fromSlotData fallback behavior for legacy responses', () {
      final legacySlot = {
        'startTime': '09:00',
        'endTime': '10:00',
      };
      final groomerData = {
        'multiBookingEnabled': true,
        'slotBookingLimit': 3,
      };
      final cap = SlotCapacity.fromSlotData(legacySlot, groomerData: groomerData);
      expect(cap.bookingCount, equals(0));
      expect(cap.maxBookings, equals(3));
      expect(cap.remaining, equals(3));
      expect(cap.isAvailable, isTrue);
    });

    test('13. Pre-flight check: 0/3, 1/3, 2/3 allowed, 3/3 blocked', () {
      bool isAllowed(SlotCapacity cap) =>
          cap.isAvailable && cap.remaining > 0 && cap.bookingCount < cap.maxBookings;

      final cap0 = SlotCapacity.fromSlotData({'bookingCount': 0, 'maxBookings': 3, 'remaining': 3, 'isAvailable': true});
      final cap1 = SlotCapacity.fromSlotData({'bookingCount': 1, 'maxBookings': 3, 'remaining': 2, 'isAvailable': true});
      final cap2 = SlotCapacity.fromSlotData({'bookingCount': 2, 'maxBookings': 3, 'remaining': 1, 'isAvailable': true});
      final cap3 = SlotCapacity.fromSlotData({'bookingCount': 3, 'maxBookings': 3, 'remaining': 0, 'isAvailable': false});

      expect(isAllowed(cap0), isTrue);
      expect(isAllowed(cap1), isTrue);
      expect(isAllowed(cap2), isTrue);
      expect(isAllowed(cap3), isFalse);
    });

    test('14. Pre-flight check: isAvailable=false or remaining=0 or count>=limit blocked', () {
      bool isAllowed(SlotCapacity cap) =>
          cap.isAvailable && cap.remaining > 0 && cap.bookingCount < cap.maxBookings;

      // isAvailable is false
      final capFalseAvail = SlotCapacity.fromSlotData({'bookingCount': 1, 'maxBookings': 3, 'remaining': 2, 'isAvailable': false});
      expect(isAllowed(capFalseAvail), isFalse);

      // remaining is 0
      final capZeroRem = SlotCapacity.fromSlotData({'bookingCount': 1, 'maxBookings': 3, 'remaining': 0, 'isAvailable': true});
      expect(isAllowed(capZeroRem), isFalse);

      // bookingCount >= maxBookings
      final capOverLimit = SlotCapacity.fromSlotData({'bookingCount': 3, 'maxBookings': 3, 'remaining': 1, 'isAvailable': true});
      expect(isAllowed(capOverLimit), isFalse);
    });
  });
}
