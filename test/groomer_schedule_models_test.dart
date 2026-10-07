import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_schedule_models.dart';

void main() {
  group('Groomer Schedule Time Helpers', () {
    test('timeToMinutes converts 24h and 12h time strings correctly', () {
      expect(timeToMinutes('09:00'), equals(540));
      expect(timeToMinutes('09:30'), equals(570));
      expect(timeToMinutes('17:00'), equals(1020));
      expect(timeToMinutes('09:00 AM'), equals(540));
      expect(timeToMinutes('05:30 PM'), equals(1050));
      expect(timeToMinutes(''), equals(0));
    });

    test('formatTimeTo12h converts 24h time to standard 12h AM/PM display', () {
      expect(formatTimeTo12h('09:00'), equals('09:00 AM'));
      expect(formatTimeTo12h('17:30'), equals('05:30 PM'));
      expect(formatTimeTo12h('12:00'), equals('12:00 PM'));
      expect(formatTimeTo12h('00:00'), equals('12:00 AM'));
      expect(formatTimeTo12h(''), equals('—'));
    });

    test('formatTimeTo24h converts 12h time to standard 24h format', () {
      expect(formatTimeTo24h('09:00 AM'), equals('09:00'));
      expect(formatTimeTo24h('05:30 PM'), equals('17:30'));
      expect(formatTimeTo24h('09:00'), equals('09:00'));
    });
  });

  group('StoreServiceHour Model Tests', () {
    test('StoreServiceHour fromJson parses standard and alternate keys correctly', () {
      final json = {
        'dayOfWeek': 'Monday',
        'isOpen': true,
        'startTime': '09:00',
        'endTime': '18:00',
        'clientId': 'SHEAR-001',
      };

      final hour = StoreServiceHour.fromJson(json);
      expect(hour.dayOfWeek, equals('Monday'));
      expect(hour.isOpen, isTrue);
      expect(hour.startTime, equals('09:00'));
      expect(hour.endTime, equals('18:00'));
      expect(hour.startFormatted, equals('09:00 AM'));
      expect(hour.endFormatted, equals('06:00 PM'));
      expect(hour.isValidRange, isTrue);
    });

    test('StoreServiceHour validates invalid opening/closing range', () {
      final invalid = const StoreServiceHour(
        dayOfWeek: 'Tuesday',
        isOpen: true,
        startTime: '18:00',
        endTime: '09:00',
      );
      expect(invalid.isValidRange, isFalse);

      final closedInvalidTime = const StoreServiceHour(
        dayOfWeek: 'Tuesday',
        isOpen: false,
        startTime: '18:00',
        endTime: '09:00',
      );
      expect(closedInvalidTime.isValidRange, isTrue); // Closed days are always considered valid
    });
  });

  group('GroomerWorkingHour & GroomerBreak Model Tests', () {
    test('GroomerBreak parses and formats correctly', () {
      final json = {
        'id': 5,
        'groomerCode': 'G001',
        'dayOfWeek': 'Monday',
        'startTime': '13:00',
        'endTime': '14:00',
        'reason': 'Lunch break',
      };

      final b = GroomerBreak.fromJson(json);
      expect(b.id, equals(5));
      expect(b.groomerCode, equals('G001'));
      expect(b.dayOfWeek, equals('Monday'));
      expect(b.formattedRange, equals('01:00 PM – 02:00 PM'));
      expect(b.isValidRange, isTrue);
    });

    test('GroomerWorkingHour with nested breaks parses correctly', () {
      final json = {
        'id': 10,
        'groomerCode': 'G001',
        'dayOfWeek': 'Monday',
        'isWorking': true,
        'startTime': '09:00',
        'endTime': '17:00',
        'breaks': [
          {
            'id': 1,
            'groomerCode': 'G001',
            'dayOfWeek': 'Monday',
            'startTime': '13:00',
            'endTime': '14:00',
            'reason': 'Lunch break',
          }
        ],
      };

      final hour = GroomerWorkingHour.fromJson(json);
      expect(hour.id, equals(10));
      expect(hour.isWorking, isTrue);
      expect(hour.breaks.length, equals(1));
      expect(hour.breaks.first.reason, equals('Lunch break'));
      expect(hour.isValidRange, isTrue);
    });
  });
}
