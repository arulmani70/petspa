import 'package:flutter/services.dart';

/// Formats US phone numbers as (XXX) XXX-XXXX and strictly prevents typing extra numbers beyond 10 digits.
class UsPhoneInputFormatter extends TextInputFormatter {
  const UsPhoneInputFormatter();

  /// Formats raw digit string into (XXX) XXX-XXXX progressively.
  static String formatDigits(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('1')) {
      digits = digits.substring(1);
    }
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }
    if (digits.isEmpty) return '';

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 3) buffer.write(') ');
      if (i == 6) buffer.write('-');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// Extracts clean digits (max 10 digits, strips leading 1 country code if 11 digits).
  static String cleanDigits(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('1')) {
      digits = digits.substring(1);
    }
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }
    return digits;
  }

  /// Checks whether input contains a valid 10-digit US phone number.
  static bool isValid(String input) {
    final digits = cleanDigits(input);
    return digits.length == 10;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final oldDigits = oldValue.text.replaceAll(RegExp(r'\D'), '');
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    // Handle backspace when cursor is after a formatting character
    if (oldValue.text.length > newValue.text.length &&
        oldDigits == digits &&
        digits.isNotEmpty) {
      digits = digits.substring(0, digits.length - 1);
    }

    // Strip leading 1 if 11-digit US number with country code is entered
    if (digits.length == 11 && digits.startsWith('1')) {
      digits = digits.substring(1);
    }

    // Strictly limit to 10 digits max (do not allow extra numbers)
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final formatted = formatDigits(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Helper class to calculate and format pet age consistently based on Date of Birth or age string.
class PetAgeFormatter {
  const PetAgeFormatter._();

  static int daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  static int calculateTotalMonths(DateTime birthDate, [DateTime? currentDate]) {
    final now = currentDate ?? DateTime.now();
    if (birthDate.isAfter(now)) return 0;
    int months = (now.year - birthDate.year) * 12 + (now.month - birthDate.month);
    final isNowLastDayOfMonth = now.day == daysInMonth(now.year, now.month);
    if (now.day < birthDate.day && !(isNowLastDayOfMonth && birthDate.day >= now.day)) {
      months--;
    }
    return months < 0 ? 0 : months;
  }

  static String formatAgeFromMonths(int totalMonths) {
    if (totalMonths < 5) {
      return '3 Months';
    }
    if (totalMonths <= 7) {
      return '6 Months';
    }
    if (totalMonths < 12) {
      return '9 Months';
    }
    int years = totalMonths ~/ 12;
    if (years < 1) years = 1;
    if (years > 20) years = 20;
    return '$years Year${years == 1 ? '' : 's'}';
  }

  static String formatPetCardAge(Map<String, dynamic> pet) {
    // 1. If dateOfBirth is present, calculate accurately from dateOfBirth
    final birthStr = pet['dateOfBirth']?.toString() ??
        pet['birthDate']?.toString() ??
        pet['birth_date']?.toString() ??
        pet['COLUMN_BIRTH_DATE']?.toString();
    if (birthStr != null && birthStr.isNotEmpty && birthStr != 'null') {
      final dob = DateTime.tryParse(birthStr);
      if (dob != null) {
        final totalMonths = calculateTotalMonths(dob);
        return formatAgeFromMonths(totalMonths);
      }
    }

    // 2. Otherwise format based on pet['age']
    final rawAge = pet['age']?.toString().trim() ?? '';
    if (rawAge.isNotEmpty && rawAge != 'null') {
      final match = RegExp(r'(\d+)\s*(month|mon|mos|mo|m|year|yr|yrs|y)?', caseSensitive: false).firstMatch(rawAge);
      if (match != null) {
        final num = int.tryParse(match.group(1)!) ?? 0;
        final unit = match.group(2)?.toLowerCase();
        if (unit != null && unit.startsWith('m')) {
          return formatAgeFromMonths(num);
        } else if (unit != null && (unit.startsWith('y') || unit.startsWith('yr'))) {
          final y = num < 1 ? 1 : (num > 20 ? 20 : num);
          return '$y Year${y == 1 ? '' : 's'}';
        } else {
          if (num <= 9 && (num == 3 || num == 6 || num == 9)) {
            return '$num Months';
          }
          if (num > 20) {
            return formatAgeFromMonths(num);
          }
          if (num >= 1) {
            return '$num Year${num == 1 ? '' : 's'}';
          }
        }
      }
      return rawAge;
    }

    return '3 Months';
  }
}

