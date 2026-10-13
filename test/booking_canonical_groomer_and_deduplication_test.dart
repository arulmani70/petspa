import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';

void main() {
  group('BookingDateUtils - Canonical Groomer ID Resolution', () {
    test('Resolves Merisa Brown variations to canonical ID 1', () {
      // Direct portal ID 11 -> canonical ID 1
      expect(BookingDateUtils.resolveCanonicalGroomerId(11), equals(1));
      expect(BookingDateUtils.resolveCanonicalGroomerId('11'), equals(1));

      // Direct ID 1 -> 1
      expect(BookingDateUtils.resolveCanonicalGroomerId(1), equals(1));
      expect(BookingDateUtils.resolveCanonicalGroomerId('1'), equals(1));

      // Groomer code G001, G1, G-001
      expect(BookingDateUtils.resolveCanonicalGroomerId(null, groomerCode: 'G001'), equals(1));
      expect(BookingDateUtils.resolveCanonicalGroomerId(null, groomerCode: 'G1'), equals(1));
      expect(BookingDateUtils.resolveCanonicalGroomerId(11, groomerCode: 'G001'), equals(1));

      // Groomer names
      expect(BookingDateUtils.resolveCanonicalGroomerId(null, groomerName: 'Merisa Brown'), equals(1));
      expect(BookingDateUtils.resolveCanonicalGroomerId(11, groomerName: 'Merisa'), equals(1));
      expect(BookingDateUtils.resolveCanonicalGroomerId(99, groomerName: 'Brown, Merisa (Lead Groomer)'), equals(1));
    });

    test('Resolves Richard Cooke variations to canonical ID 2', () {
      expect(BookingDateUtils.resolveCanonicalGroomerId(2), equals(2));
      expect(BookingDateUtils.resolveCanonicalGroomerId('2'), equals(2));
      expect(BookingDateUtils.resolveCanonicalGroomerId(null, groomerCode: 'G002'), equals(2));
      expect(BookingDateUtils.resolveCanonicalGroomerId(null, groomerName: 'Richard Cooke'), equals(2));
    });

    test('Resolves Tracie Jamison variations to canonical ID 3', () {
      expect(BookingDateUtils.resolveCanonicalGroomerId(3), equals(3));
      expect(BookingDateUtils.resolveCanonicalGroomerId('3'), equals(3));
      expect(BookingDateUtils.resolveCanonicalGroomerId(null, groomerCode: 'G003'), equals(3));
      expect(BookingDateUtils.resolveCanonicalGroomerId(null, groomerName: 'Tracie Jamison'), equals(3));
    });

    test('Resolves Jeremiah Smith variations to canonical ID 4', () {
      expect(BookingDateUtils.resolveCanonicalGroomerId(4), equals(4));
      expect(BookingDateUtils.resolveCanonicalGroomerId('4'), equals(4));
      expect(BookingDateUtils.resolveCanonicalGroomerId(null, groomerCode: 'B001'), equals(4));
      expect(BookingDateUtils.resolveCanonicalGroomerId(null, groomerName: 'Jeremiah Smith'), equals(4));
    });

    test('Resolves dynamically using dynamicGroomerMap from API responses', () {
      final apiMap = <String, int>{
        'merisa brown': 1,
        'richard cooke': 2,
        'tracie jamison': 3,
        'jeremiah smith': 4,
        'g001': 1,
        'g002': 2,
        '11': 1,
      };

      // By name from API response
      expect(BookingDateUtils.resolveCanonicalGroomerId(null, groomerName: 'Merisa Brown', dynamicGroomerMap: apiMap), equals(1));
      // By code from API response
      expect(BookingDateUtils.resolveCanonicalGroomerId(null, groomerCode: 'G001', dynamicGroomerMap: apiMap), equals(1));
      // By ID from API response
      expect(BookingDateUtils.resolveCanonicalGroomerId(11, dynamicGroomerMap: apiMap), equals(1));
    });

    test('Handles null and unrecognized groomers gracefully', () {
      expect(BookingDateUtils.resolveCanonicalGroomerId(null), isNull);
      expect(BookingDateUtils.resolveCanonicalGroomerId(''), isNull);
      expect(BookingDateUtils.resolveCanonicalGroomerId(0), isNull);
      expect(BookingDateUtils.resolveCanonicalGroomerId(5), equals(5));
      expect(BookingDateUtils.resolveCanonicalGroomerId('5'), equals(5));
    });
  });

  group('BookingDateUtils - Time Slot Matching and Deduplication', () {
    test('isSameTimeSlot normalizes differing representations', () {
      expect(BookingDateUtils.isSameTimeSlot('09:00', '09:00:00'), isTrue);
      expect(BookingDateUtils.isSameTimeSlot('9:00 AM', '09:00'), isTrue);
      expect(BookingDateUtils.isSameTimeSlot('14:30', '2:30 PM'), isTrue);
      expect(BookingDateUtils.isSameTimeSlot('09:00', '10:00'), isFalse);
      expect(BookingDateUtils.isSameTimeSlot(null, '09:00'), isFalse);
    });

    test('deduplicateSlots removes identical slots while merging capacity', () {
      final rawSlots = <Map<String, dynamic>>[
        {
          'startTime': '09:00:00',
          'endTime': '10:00:00',
          'isAvailable': false,
          'remaining': 0,
          'groomerId': 1,
        },
        {
          'startTime': '09:00',
          'endTime': '10:00',
          'isAvailable': true,
          'remaining': 2,
          'groomerId': 2,
        },
        {
          'startTime': '10:00',
          'endTime': '11:00',
          'isAvailable': true,
          'remaining': 1,
          'groomerId': 1,
        },
      ];

      final deduplicated = BookingDateUtils.deduplicateSlots(rawSlots);
      expect(deduplicated.length, equals(2));
      expect(deduplicated[0]['startTime'], equals('09:00'));
      expect(deduplicated[0]['isAvailable'], isTrue);
      expect(deduplicated[0]['remaining'], equals(2));
      expect(deduplicated[1]['startTime'], equals('10:00'));
      expect(deduplicated[1]['remaining'], equals(1));
    });

    test('deduplicateSlots preserves distinct slots per groomer if groomerId varies and specific groomer context is given', () {
      final rawSlots = <Map<String, dynamic>>[
        {'startTime': '09:00', 'groomerId': 1, 'isAvailable': true},
        {'startTime': '09:00', 'groomerId': 2, 'isAvailable': true},
      ];

      // specificGroomerId = 1 differentiates by groomerId
      final perGroomer = BookingDateUtils.deduplicateSlots(rawSlots, specificGroomerId: 1);
      expect(perGroomer.length, equals(2));

      // specificGroomerId = null merges salon-wide into one slot for the user
      final salonWide = BookingDateUtils.deduplicateSlots(rawSlots);
      expect(salonWide.length, equals(1));
    });
  });
}
