import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_calendar_service.dart';

void main() {
  group('BookingCalendarService', () {
    test('builds calendar event with valid date and time', () {
      final summary = {
        'booking_id': 1234,
        'pet_name': 'Max',
        'pet_breed': 'Golden Retriever',
        'service_name': 'Full Grooming',
        'groomer_name': 'Jane Groomer',
        'booking_date': '2026-08-04',
        'start_time': '10:30 AM',
        'total_duration_minutes': 90,
      };

      final event = BookingCalendarService.buildEvent(summary);

      expect(event.title, contains('Max'));
      expect(event.title, contains('Full Grooming'));
      expect(event.location, 'Shear Heaven Pet Spa');
      expect(event.description, contains('Max (Golden Retriever)'));
      expect(event.description, contains('Jane Groomer'));
      expect(event.description, contains('#1234'));

      expect(event.startDate.year, 2026);
      expect(event.startDate.month, 8);
      expect(event.startDate.day, 4);
      expect(event.startDate.hour, 10);
      expect(event.startDate.minute, 30);

      // Duration is 90 mins -> 10:30 + 90 min = 12:00
      expect(event.endDate.hour, 12);
      expect(event.endDate.minute, 0);
    });

    test('builds calendar event with date_label and 24-hour time', () {
      final summary = {
        'pet': {'name': 'Bella', 'breed': 'Poodle'},
        'service': {'service_name': 'Bath & Brush'},
        'date_label': 'Aug 4, 2026',
        'time_label': '14:00',
        'duration': 60,
      };

      final event = BookingCalendarService.buildEvent(summary);

      expect(event.title, contains('Bella'));
      expect(event.title, contains('Bath & Brush'));
      expect(event.startDate.year, 2026);
      expect(event.startDate.month, 8);
      expect(event.startDate.day, 4);
      expect(event.startDate.hour, 14);
      expect(event.startDate.minute, 0);

      // Duration is 60 mins -> 14:00 + 60 min = 15:00
      expect(event.endDate.hour, 15);
      expect(event.endDate.minute, 0);
    });

    test('handles combined date and time strings like "Aug 4, 2026 · 10:30 AM"', () {
      final summary = {
        'pet_name': 'Rocky',
        'service_name': 'Haircut',
        'booking_date': 'Aug 4, 2026 · 10:30 AM',
      };

      final event = BookingCalendarService.buildEvent(summary);

      expect(event.title, contains('Rocky'));
      expect(event.startDate.year, 2026);
      expect(event.startDate.month, 8);
      expect(event.startDate.day, 4);
      expect(event.startDate.hour, 10);
      expect(event.startDate.minute, 30);
    });

    test('builds google calendar fallback url correctly', () {
      final uri = BookingCalendarService.buildGoogleCalendarUrl(
        title: 'Shear Heaven: Milo - Full Grooming',
        description: 'Booking #101',
        location: 'Shear Heaven Pet Spa',
        startDate: DateTime.utc(2026, 8, 4, 10, 30),
        endDate: DateTime.utc(2026, 8, 4, 11, 30),
      );

      expect(uri.host, 'calendar.google.com');
      expect(uri.queryParameters['action'], 'TEMPLATE');
      expect(uri.queryParameters['text'], 'Shear Heaven: Milo - Full Grooming');
      expect(uri.queryParameters['dates'], '20260804T103000Z/20260804T113000Z');
      expect(uri.queryParameters['location'], 'Shear Heaven Pet Spa');
    });

    test('handles fallback when summary is empty', () {
      final summary = <String, dynamic>{};
      final event = BookingCalendarService.buildEvent(summary);

      expect(event.title, contains('Pet'));
      expect(event.location, 'Shear Heaven Pet Spa');
      expect(event.endDate.isAfter(event.startDate), isTrue);
    });
  });
}
