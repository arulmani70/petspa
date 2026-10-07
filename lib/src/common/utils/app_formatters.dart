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
