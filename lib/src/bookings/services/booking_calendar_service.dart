import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingCalendarService {
  BookingCalendarService._();

  static final Logger _log = Logger();

  /// Builds an [Event] object from a booking summary map.
  static Event buildEvent(Map<String, dynamic> summary) {
    final petMap = (summary['pet'] is Map)
        ? Map<String, dynamic>.from(summary['pet'] as Map)
        : summary;

    final petName = petMap['pet_name']?.toString().trim() ??
        petMap['name']?.toString().trim() ??
        summary['pet_name']?.toString().trim() ??
        'Pet';

    final petBreed = petMap['pet_breed']?.toString().trim() ??
        petMap['breed']?.toString().trim() ??
        summary['pet_breed']?.toString().trim() ??
        '';

    final rawServiceName = summary['service_name']?.toString().trim() ??
        summary['service']?['service_name']?.toString().trim() ??
        '';
    final serviceName = rawServiceName.isNotEmpty ? rawServiceName : 'Pet Grooming';

    final groomerName = summary['groomer_name']?.toString().trim() ??
        summary['groomer']?['name']?.toString().trim() ??
        summary['groomer']?['groomer_name']?.toString().trim() ??
        '';

    final bookingId = summary['booking_id']?.toString() ??
        summary['bookingId']?.toString() ??
        summary['id']?.toString() ??
        '';

    final durationMinutes = int.tryParse(summary['total_duration_minutes']?.toString() ??
            summary['duration']?.toString() ??
            summary['totalDurationMinutes']?.toString() ??
            '60') ??
        60;

    final rawDate = summary['booking_date'] ??
        summary['bookingDate'] ??
        summary['date'] ??
        summary['date_label'] ??
        '';

    final rawStartTime = summary['start_time'] ??
        summary['startTime'] ??
        summary['time_slot'] ??
        summary['time'] ??
        summary['time_label'] ??
        '';

    final rawEndTime = summary['end_time'] ??
        summary['endTime'] ??
        '';

    final startDateTime = parseBookingDateTime(rawDate, rawStartTime) ??
        DateTime.now().add(const Duration(hours: 1));

    DateTime endDateTime;
    final parsedEnd = parseBookingDateTime(rawDate, rawEndTime);
    if (parsedEnd != null && parsedEnd.isAfter(startDateTime)) {
      endDateTime = parsedEnd;
    } else {
      endDateTime = startDateTime.add(
        Duration(minutes: durationMinutes > 0 ? durationMinutes : 60),
      );
    }

    final descriptionBuffer = StringBuffer();
    descriptionBuffer.writeln('Appointment at Shear Heaven Pet Spa');
    if (serviceName.isNotEmpty) descriptionBuffer.writeln('Service: $serviceName');
    if (petName.isNotEmpty) {
      final petInfo = petBreed.isNotEmpty ? '$petName ($petBreed)' : petName;
      descriptionBuffer.writeln('Pet: $petInfo');
    }
    if (groomerName.isNotEmpty) descriptionBuffer.writeln('Groomer: $groomerName');
    if (bookingId.isNotEmpty) descriptionBuffer.writeln('Booking ID: #$bookingId');

    final title = 'Shear Heaven: $petName - $serviceName';

    return Event(
      title: title,
      description: descriptionBuffer.toString().trim(),
      location: 'Shear Heaven Pet Spa',
      startDate: startDateTime,
      endDate: endDateTime,
      iosParams: const IOSParams(
        reminder: Duration(minutes: 60),
      ),
      androidParams: const AndroidParams(
        emailInvites: [],
      ),
    );
  }

  /// Builds a Google Calendar web fallback URL for universal device support.
  static Uri buildGoogleCalendarUrl({
    required String title,
    required String description,
    required String location,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    String formatGCalDate(DateTime dt) {
      final utc = dt.toUtc();
      return '${utc.year.toString().padLeft(4, '0')}'
          '${utc.month.toString().padLeft(2, '0')}'
          '${utc.day.toString().padLeft(2, '0')}T'
          '${utc.hour.toString().padLeft(2, '0')}'
          '${utc.minute.toString().padLeft(2, '0')}'
          '${utc.second.toString().padLeft(2, '0')}Z';
    }

    final dates = '${formatGCalDate(startDate)}/${formatGCalDate(endDate)}';

    return Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': title,
      'details': description,
      'location': location,
      'dates': dates,
    });
  }

  /// Launches the native calendar app to add the booking event,
  /// with automatic fallback to Web Calendar / Google Calendar if native fails.
  static Future<bool> addToCalendar(
    BuildContext context,
    Map<String, dynamic> summary,
  ) async {
    final event = buildEvent(summary);

    // 1. Try native platform calendar via add_2_calendar plugin
    try {
      _log.d("BookingCalendarService::addToCalendar::Attempting native calendar for: ${event.title}");
      final success = await Add2Calendar.addEvent2Cal(event);
      if (success) {
        if (context.mounted) {
          ToastUtil.showSuccessToast(context, 'Opening calendar...');
        }
        return true;
      }
    } catch (e, stack) {
      _log.w("BookingCalendarService::addToCalendar::Native calendar failed ($e). Trying fallback...", error: e, stackTrace: stack);
    }

    // 2. Fallback: Open in Google Calendar / default browser
    try {
      final gCalUrl = buildGoogleCalendarUrl(
        title: event.title,
        description: event.description ?? '',
        location: event.location ?? 'Shear Heaven Pet Spa',
        startDate: event.startDate,
        endDate: event.endDate,
      );

      _log.d("BookingCalendarService::addToCalendar::Launching web calendar fallback: $gCalUrl");
      final launched = await launchUrl(gCalUrl, mode: LaunchMode.externalApplication);
      if (launched) {
        if (context.mounted) {
          ToastUtil.showSuccessToast(context, 'Opening calendar in browser...');
        }
        return true;
      }
    } catch (fallbackError, stack) {
      _log.e("BookingCalendarService::addToCalendar::Web calendar fallback error: $fallbackError", error: fallbackError, stackTrace: stack);
    }

    // 3. If all fails, show user error toast
    if (context.mounted) {
      ToastUtil.showErrorToast(context, 'Could not open calendar. Please check device calendar permissions.');
    }
    return false;
  }

  /// Parses date and time from various formats into a unified [DateTime].
  static DateTime? parseBookingDateTime(dynamic rawDate, dynamic rawTime) {
    if (rawDate == null && rawTime == null) return null;

    String dateStr = rawDate?.toString().trim() ?? '';
    String timeStr = rawTime?.toString().trim() ?? '';

    // Handle combined date & time string like "Aug 4, 2026 · 10:30 AM"
    if (dateStr.contains('·')) {
      final parts = dateStr.split('·');
      dateStr = parts[0].trim();
      if (timeStr.isEmpty && parts.length > 1) {
        timeStr = parts[1].trim();
      }
    }

    DateTime? baseDate;
    if (rawDate is DateTime) {
      baseDate = DateTime(rawDate.year, rawDate.month, rawDate.day);
    } else if (dateStr.isNotEmpty) {
      baseDate = BookingDateUtils.parseCalendarDate(dateStr);

      if (baseDate == null) {
        final cleanDate = dateStr
            .replaceAll(RegExp(r'^Today,?\s*', caseSensitive: false), '')
            .trim();
        final formats = [
          'MMM d, yyyy',
          'MMMM d, yyyy',
          'd MMM yyyy',
          'd MMMM yyyy',
          'yyyy-MM-dd',
          'MM/dd/yyyy',
          'dd/MM/yyyy',
        ];
        for (final fmt in formats) {
          try {
            final parsed = DateFormat(fmt).parseLoose(cleanDate);
            baseDate = DateTime(parsed.year, parsed.month, parsed.day);
            break;
          } catch (_) {}
        }
      }
    }

    baseDate ??= DateTime.now();

    int hour = 9;
    int minute = 0;

    if (timeStr.isNotEmpty) {
      final cleanTime = timeStr.toUpperCase();
      final mainPart = cleanTime.contains('-')
          ? cleanTime.split('-').first.trim()
          : (cleanTime.contains('·') ? cleanTime.split('·').first.trim() : cleanTime);

      final amPmMatch = RegExp(r'(\d{1,2}):?(\d{2})?\s*(AM|PM)').firstMatch(mainPart);
      if (amPmMatch != null) {
        int h = int.parse(amPmMatch.group(1)!);
        final m = amPmMatch.group(2) != null ? int.parse(amPmMatch.group(2)!) : 0;
        final period = amPmMatch.group(3)!;
        if (period == 'PM' && h < 12) h += 12;
        if (period == 'AM' && h == 12) h = 0;
        hour = h;
        minute = m;
      } else {
        final match24 = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(mainPart);
        if (match24 != null) {
          final h = int.parse(match24.group(1)!);
          final m = int.parse(match24.group(2)!);
          hour = h;
          minute = m;
        }
      }
    }

    return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
  }
}
