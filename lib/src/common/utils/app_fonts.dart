import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralised access to every font family used in the Figma design.
///
/// Fonts referenced by the design:
///  - Parkinsans   (headings, buttons)  weights 600 / 700
///  - Poppins      (body, labels)       weights 300 / 400 / 500 / 600
///  - DM Sans      (footer links, "or continue with")
///  - Montserrat   (prices, "Skip")
///  - Roboto       (OTP keypad digits)
///  - Product Sans (Log in / Sign up toggle) - not on Google Fonts, so it
///    falls back to Poppins (closest available match).
abstract final class AppFonts {
  static TextStyle parkinsans({
    double size = 16,
    FontWeight weight = FontWeight.w600,
    Color color = Colors.black,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    return GoogleFonts.parkinsans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
    );
  }

  static TextStyle poppins({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = Colors.black,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
    );
  }

  /// "Product Sans" (used for the Log in / Sign up toggle) is proprietary,
  /// so we approximate it with Poppins SemiBold/Bold.
  static TextStyle productSans({
    double size = 18,
    FontWeight weight = FontWeight.w700,
    Color color = Colors.black,
    double? height,
  }) {
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  static TextStyle dmSans({
    double size = 14,
    FontWeight weight = FontWeight.w300,
    Color color = Colors.black,
    double? height,
  }) {
    return GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  static TextStyle montserrat({
    double size = 22,
    FontWeight weight = FontWeight.w700,
    Color color = Colors.black,
    double? height,
  }) {
    return GoogleFonts.montserrat(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  static TextStyle roboto({
    double size = 38,
    FontWeight weight = FontWeight.w400,
    Color color = Colors.black,
    double? height,
  }) {
    return GoogleFonts.roboto(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }
}
