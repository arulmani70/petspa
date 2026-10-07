import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/widgets/shared_calendar.dart';
import 'package:shear_heaven_pet_spa/src/store/repo/store_repository.dart';

class MockStoreRepositoryWithRealData extends StoreRepository {
  final List<Map<String, dynamic>> mockHolidays;
  final List<Map<String, dynamic>> mockSchedule;

  MockStoreRepositoryWithRealData({
    required this.mockHolidays,
    required this.mockSchedule,
  });

  @override
  Future<List<Map<String, dynamic>>> getHolidays() async => mockHolidays;

  @override
  Future<List<Map<String, dynamic>>> getStoreSchedule() async => mockSchedule;

  @override
  bool isHoliday(DateTime date) {
    return getHolidayName(date) != null;
  }

  @override
  String? getHolidayName(DateTime date) {
    for (var h in mockHolidays) {
      final dateStr = h['Date']?.toString() ?? h['date']?.toString();
      if (dateStr == null || dateStr.trim().isEmpty) continue;
      
      final clean = dateStr.trim();
      final slashParts = clean.split('/');
      if (slashParts.length == 3) {
        final month = int.tryParse(slashParts[0]);
        final day = int.tryParse(slashParts[1]);
        final year = int.tryParse(slashParts[2]);
        if (month == date.month && day == date.day && year == date.year) {
          return h['Name']?.toString() ?? h['name']?.toString() ?? 'Holiday';
        }
      }

      final dateOnly = clean.split('T')[0];
      final dashParts = dateOnly.split('-');
      if (dashParts.length == 3) {
        final year = int.tryParse(dashParts[0]);
        final month = int.tryParse(dashParts[1]);
        final day = int.tryParse(dashParts[2]);
        if (month == date.month && day == date.day && year == date.year) {
          return h['Name']?.toString() ?? h['name']?.toString() ?? 'Holiday';
        }
      }
    }
    return null;
  }

  @override
  bool isStoreClosedDay(DateTime date) {
    final match = mockSchedule.firstWhere(
      (s) {
        final dayStr = (s['Day'] ?? s['dayOfWeek'] ?? s['day'] ?? '').toString().toLowerCase();
        final weekdayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
        final currentWeekday = weekdayNames[date.weekday - 1];
        return dayStr == currentWeekday ||
            (currentWeekday == 'sunday' && dayStr == 'sumday') ||
            (currentWeekday == 'tuesday' && dayStr == 'tueday');
      },
      orElse: () => <String, dynamic>{},
    );

    if (match.isNotEmpty) {
      if (match.containsKey('isOpen')) {
        final isOpenVal = match['isOpen'];
        if (isOpenVal == false || isOpenVal == 'false' || isOpenVal == 0) return true;
        if (isOpenVal == true || isOpenVal == 'true' || isOpenVal == 1) return false;
      }
      final open = match['Open']?.toString().toLowerCase();
      if (open == 'no' || open == 'false' || open == '0') return true;
      if (open == 'yes' || open == 'true' || open == '1') return false;
    }
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await ServicesLocator.initialize();
  });

  group('BookingDateUtils - 14-Day Date Restriction Tests', () {
    test('Calculates normalized min and max dates correctly', () {
      final now = DateTime.now();
      final expectedMin = DateTime(now.year, now.month, now.day);
      final expectedMax = DateTime(expectedMin.year, expectedMin.month, expectedMin.day + 14);

      expect(BookingDateUtils.minAllowedDate, expectedMin);
      expect(BookingDateUtils.maxAllowedDate, expectedMax);
      expect(BookingDateUtils.maxBookingDaysAhead, 14);
    });

    test('isDateAllowed accepts today, tomorrow, and today + 14 days', () {
      final today = BookingDateUtils.minAllowedDate;
      final tomorrow = today.add(const Duration(days: 1));
      final day14 = today.add(const Duration(days: 14));

      expect(BookingDateUtils.isDateAllowed(today), isTrue, reason: 'Today must be allowed');
      expect(BookingDateUtils.isDateAllowed(tomorrow), isTrue, reason: 'Tomorrow must be allowed');
      expect(BookingDateUtils.isDateAllowed(day14), isTrue, reason: 'Today + 14 days must be allowed');
    });

    test('isDateAllowed rejects yesterday, past dates, and future dates > 14 days', () {
      final today = BookingDateUtils.minAllowedDate;
      final yesterday = today.subtract(const Duration(days: 1));
      final pastDate = today.subtract(const Duration(days: 10));
      final day15 = today.add(const Duration(days: 15));
      final nextMonthBeyond = today.add(const Duration(days: 30));

      expect(BookingDateUtils.isDateAllowed(yesterday), isFalse, reason: 'Yesterday must be disabled');
      expect(BookingDateUtils.isDateAllowed(pastDate), isFalse, reason: 'Past dates must be disabled');
      expect(BookingDateUtils.isDateAllowed(day15), isFalse, reason: 'Today + 15 must be disabled');
      expect(BookingDateUtils.isDateAllowed(nextMonthBeyond), isFalse, reason: 'Future > 14 days must be disabled');
      expect(BookingDateUtils.isDateAllowed(null), isFalse, reason: 'Null date must be rejected');
    });

    test('findFirstAvailableDate finds next open non-holiday date', () {
      // If Sunday (closed), findFirstAvailableDate should skip to Tuesday (open)
      final sunday = DateTime(2026, 8, 30);

      bool isUnavailable(DateTime d) {
        if (!BookingDateUtils.isDateAllowed(d)) return true;
        if (d.weekday == DateTime.sunday || d.weekday == DateTime.monday) return true; // closed
        return false;
      }

      final firstAvail = BookingDateUtils.findFirstAvailableDate(
        isDateUnavailable: isUnavailable,
        preferredStart: sunday,
      );

      expect(isUnavailable(firstAvail), isFalse);
    });

    test('validateDate and validateDateString throw ArgumentError on invalid dates', () {
      final today = BookingDateUtils.minAllowedDate;
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(today.subtract(const Duration(days: 1)));
      final day15Str = DateFormat('yyyy-MM-dd').format(today.add(const Duration(days: 15)));
      final validStr = DateFormat('yyyy-MM-dd').format(today.add(const Duration(days: 2)));

      expect(() => BookingDateUtils.validateDate(today.subtract(const Duration(days: 1))),
          throwsA(isA<ArgumentError>()));
      expect(() => BookingDateUtils.validateDate(today.add(const Duration(days: 15))),
          throwsA(isA<ArgumentError>()));

      expect(() => BookingDateUtils.validateDateString(yesterdayStr),
          throwsA(isA<ArgumentError>()));
      expect(() => BookingDateUtils.validateDateString(day15Str),
          throwsA(isA<ArgumentError>()));
      expect(() => BookingDateUtils.validateDateString('invalid-date'),
          throwsA(isA<ArgumentError>()));
      expect(() => BookingDateUtils.validateDateString(null),
          throwsA(isA<ArgumentError>()));

      // Valid cases must not throw
      expect(() => BookingDateUtils.validateDate(today), returnsNormally);
      expect(() => BookingDateUtils.validateDateString(validStr), returnsNormally);
    });
  });

  group('StoreRepository - Real-Time Holidays and Store Hours Validation', () {
    late StoreRepository repo;

    setUp(() {
      repo = MockStoreRepositoryWithRealData(
        mockHolidays: [
          {'HolidayId': 'H001', 'Name': 'Independence Day', 'Date': '07/04/2026'},
          {'HolidayId': 'H003', 'Name': 'Thanks giving day', 'Date': '11/25/2026'},
          {'HolidayId': 'H004', 'Name': 'Christmas Day', 'Date': '2026-12-25'},
        ],
        mockSchedule: [
          {'Day': 'Sumday', 'Open': 'No'},
          {'Day': 'Monday', 'Open': 'No'},
          {'Day': 'Tueday', 'Open': 'Yes'},
          {'Day': 'Wednesday', 'Open': 'Yes'},
          {'Day': 'Thursday', 'Open': 'Yes'},
          {'Day': 'Friday', 'Open': 'Yes'},
          {'Day': 'Saturday', 'Open': 'Yes'},
        ],
      );
    });

    test('Identifies real holidays across date formats', () {
      expect(repo.isHoliday(DateTime(2026, 7, 4)), isTrue);
      expect(repo.getHolidayName(DateTime(2026, 7, 4)), 'Independence Day');

      expect(repo.isHoliday(DateTime(2026, 11, 25)), isTrue);
      expect(repo.getHolidayName(DateTime(2026, 11, 25)), 'Thanks giving day');

      expect(repo.isHoliday(DateTime(2026, 12, 25)), isTrue);
      expect(repo.getHolidayName(DateTime(2026, 12, 25)), 'Christmas Day');

      expect(repo.isHoliday(DateTime(2026, 8, 26)), isFalse);
      expect(repo.getHolidayName(DateTime(2026, 8, 26)), isNull);
    });

    test('Identifies store closed days (Sunday & Monday) and open days (Tuesday-Saturday)', () {
      // 2026-08-30 is Sunday
      expect(repo.isStoreClosedDay(DateTime(2026, 8, 30)), isTrue);
      // 2026-08-31 is Monday
      expect(repo.isStoreClosedDay(DateTime(2026, 8, 31)), isTrue);
      // 2026-09-01 is Tuesday
      expect(repo.isStoreClosedDay(DateTime(2026, 9, 1)), isFalse);
      // 2026-09-02 is Wednesday
      expect(repo.isStoreClosedDay(DateTime(2026, 9, 2)), isFalse);
      // 2026-09-05 is Saturday
      expect(repo.isStoreClosedDay(DateTime(2026, 9, 5)), isFalse);
    });
  });

  group('SharedCalendar - 3 Conditions Integration (14 Days, Holidays, Closed Days)', () {
    testWidgets('Disables closed days and holidays while keeping open days selectable', (tester) async {
      DateTime? selected;
      final minDate = BookingDateUtils.minAllowedDate;
      final maxDate = BookingDateUtils.maxAllowedDate;

      // Ensure a future date in range (e.g. tomorrow or day after) is tested for holiday/closed
      final holidayDate = minDate.add(const Duration(days: 2));
      final holidayDateStr = DateFormat('MM/dd/yyyy').format(holidayDate);

      final repo = MockStoreRepositoryWithRealData(
        mockHolidays: [
          {'Name': 'Spa Special Holiday', 'Date': holidayDateStr},
        ],
        mockSchedule: [
          {'Day': 'Sumday', 'Open': 'No'},
          {'Day': 'Monday', 'Open': 'No'},
          {'Day': 'Tueday', 'Open': 'Yes'},
          {'Day': 'Wednesday', 'Open': 'Yes'},
          {'Day': 'Thursday', 'Open': 'Yes'},
          {'Day': 'Friday', 'Open': 'Yes'},
          {'Day': 'Saturday', 'Open': 'Yes'},
        ],
      );

      bool isDateUnavailable(DateTime d) {
        if (!BookingDateUtils.isDateAllowed(d)) return true;
        if (repo.isHoliday(d)) return true;
        if (repo.isStoreClosedDay(d)) return true;
        return false;
      }

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SharedCalendar(
              initialDate: minDate,
              minDate: minDate,
              maxDate: maxDate,
              isDateUnavailable: isDateUnavailable,
              onDateSelected: (d) => selected = d,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // 1. Yesterday is in the past -> Unavailable
      expect(isDateUnavailable(minDate.subtract(const Duration(days: 1))), isTrue);

      // 2. Day 15 is beyond 14 days -> Unavailable
      expect(isDateUnavailable(minDate.add(const Duration(days: 15))), isTrue);

      // 3. holidayDate is marked as holiday -> Unavailable
      expect(isDateUnavailable(holidayDate), isTrue);

      // 4. Sunday / Monday are closed -> Unavailable
      final nextSunday = minDate.add(Duration(days: (7 - minDate.weekday) % 7));
      expect(isDateUnavailable(nextSunday), isTrue);

      // Tap on the next available open date that is unselected
      DateTime targetOpenDate = minDate.add(const Duration(days: 1));
      while (isDateUnavailable(targetOpenDate)) {
        targetOpenDate = targetOpenDate.add(const Duration(days: 1));
      }
      final targetDayStr = targetOpenDate.day.toString();

      final openDayFinder = find.byWidgetPredicate((widget) {
        if (widget is Text && widget.data == targetDayStr) {
          final color = widget.style?.color;
          return color == const Color(0xFF4B5563) || color == const Color(0xFF120C0C) || color == const Color(0xFF111827);
        }
        return false;
      });

      expect(openDayFinder, findsWidgets);
      await tester.tap(openDayFinder.first);
      await tester.pumpAndSettle();

      expect(selected, DateTime(targetOpenDate.year, targetOpenDate.month, targetOpenDate.day));
    });
  });
}
