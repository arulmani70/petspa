import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';

/// Predefined reporting periods supported by the Groomer Portal Reports Summary.
enum ReportDatePreset {
  today,
  thisWeek,
  thisMonth,
  custom;

  String get label {
    switch (this) {
      case ReportDatePreset.today:
        return 'Today';
      case ReportDatePreset.thisWeek:
        return 'This Week';
      case ReportDatePreset.thisMonth:
        return 'This Month';
      case ReportDatePreset.custom:
        return 'Custom';
    }
  }

  /// Resolves the concrete [DateTimeRange] for this preset relative to [now].
  DateTimeRange resolveRange([DateTime? now]) {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);

    switch (this) {
      case ReportDatePreset.today:
        return DateTimeRange(start: today, end: today);

      case ReportDatePreset.thisWeek:
        // Week starts on Monday (ISO-8601: 1 = Mon, 7 = Sun)
        final weekday = today.weekday;
        final startOfWeek = today.subtract(Duration(days: weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return DateTimeRange(start: startOfWeek, end: endOfWeek);

      case ReportDatePreset.thisMonth:
        final startOfMonth = DateTime(today.year, today.month, 1);
        final nextMonth = today.month == 12
            ? DateTime(today.year + 1, 1, 1)
            : DateTime(today.year, today.month + 1, 1);
        final endOfMonth = nextMonth.subtract(const Duration(days: 1));
        return DateTimeRange(start: startOfMonth, end: endOfMonth);

      case ReportDatePreset.custom:
        return DateTimeRange(
          start: today,
          end: today.add(const Duration(days: 6)),
        );
    }
  }
}

/// Authoritative financial projections and appointment statistics model
/// for Step 12 Groomer Portal Reports Summary.
///
/// Implements strict business rules:
/// 1. Completed appointment status is NEVER treated as payment confirmation.
/// 2. Actual collected revenue requires explicit server payment confirmation
///    (`b.isPaid == true` or `b.paymentStatus == 'paid'`).
/// 3. Forecast revenue includes pure service fees for active unpaid appointments.
/// 4. Cancelled appointments are excluded from forecast and actual sales.
/// 5. When server omits payment data, metrics are cleanly marked unavailable
///    instead of fabricating misleading $0.00 figures.
class GroomerReportSummary {
  final int totalAppointments;
  final int completedAppointments;
  final int confirmedAppointments;
  final int inProgressAppointments;
  final int readyForCheckoutAppointments;
  final int pendingAppointments;
  final int cancelledAppointments;

  final double forecastRevenue;
  final double? actualRevenue;
  final double? actualTips;
  final double? actualTaxes;
  final double? actualTotalCollected;

  final bool isActualRevenueAvailable;
  final bool isTipsAvailable;
  final bool isTaxAvailable;
  final bool isTotalCollectedAvailable;

  final String currencySymbol;
  final String currencyCode;

  const GroomerReportSummary({
    this.totalAppointments = 0,
    this.completedAppointments = 0,
    this.confirmedAppointments = 0,
    this.inProgressAppointments = 0,
    this.readyForCheckoutAppointments = 0,
    this.pendingAppointments = 0,
    this.cancelledAppointments = 0,
    this.forecastRevenue = 0.0,
    this.actualRevenue,
    this.actualTips,
    this.actualTaxes,
    this.actualTotalCollected,
    this.isActualRevenueAvailable = true,
    this.isTipsAvailable = true,
    this.isTaxAvailable = true,
    this.isTotalCollectedAvailable = true,
    this.currencySymbol = '\$',
    this.currencyCode = 'USD',
  });

  /// Factory computing authoritative metrics from a list of [GroomerBooking] appointments.
  factory GroomerReportSummary.fromBookings(
    Iterable<GroomerBooking> bookings, {
    String currencySymbol = '\$',
    String currencyCode = 'USD',
  }) {
    int total = 0;
    int completed = 0;
    int confirmed = 0;
    int inProgress = 0;
    int readyForCheckout = 0;
    int pending = 0;
    int cancelled = 0;

    double forecast = 0.0;
    double actualSales = 0.0;
    double tips = 0.0;
    double taxes = 0.0;

    bool hasAnyPaymentData = false;
    bool hasAnyTipData = false;
    bool hasAnyTaxData = false;
    int paidBookingsCount = 0;

    for (final b in bookings) {
      total++;
      final statusLower = b.status.trim().toLowerCase();

      // Track payment indicators
      if (b.hasPaymentData) {
        hasAnyPaymentData = true;
      }
      if (b.hasTipData) {
        hasAnyTipData = true;
      }
      if (b.hasTaxData) {
        hasAnyTaxData = true;
      }

      // ── Status Classification ──────────────────────────────────────────────
      if (statusLower == 'cancelled' ||
          statusLower == 'canceled' ||
          statusLower == 'rejected') {
        cancelled++;
        // Cancelled bookings do not contribute to forecast or actual revenue
        continue;
      } else if (statusLower == 'pending') {
        pending++;
        // Pending bookings are unpaid prospective bookings
        forecast += b.totalPrice;
      } else if (statusLower == 'confirmed') {
        confirmed++;
        if (b.isPaidVerified) {
          paidBookingsCount++;
          actualSales += b.totalPrice;
          if (b.hasTipData) tips += (b.tipAmount ?? 0.0);
          if (b.hasTaxData) taxes += (b.taxAmount ?? 0.0);
        } else {
          forecast += b.totalPrice;
        }
      } else if (statusLower == 'in_progress' ||
          statusLower == 'in-progress' ||
          statusLower == 'checked_in' ||
          statusLower == 'bath_completed' ||
          statusLower == 'grooming_completed') {
        inProgress++;
        if (b.isPaidVerified) {
          paidBookingsCount++;
          actualSales += b.totalPrice;
          if (b.hasTipData) tips += (b.tipAmount ?? 0.0);
          if (b.hasTaxData) taxes += (b.taxAmount ?? 0.0);
        } else {
          forecast += b.totalPrice;
        }
      } else if (statusLower == 'ready_for_checkout') {
        readyForCheckout++;
        if (b.isPaidVerified) {
          paidBookingsCount++;
          actualSales += b.totalPrice;
          if (b.hasTipData) tips += (b.tipAmount ?? 0.0);
          if (b.hasTaxData) taxes += (b.taxAmount ?? 0.0);
        } else {
          forecast += b.totalPrice;
        }
      } else if (statusLower == 'completed' || b.isCompleted) {
        completed++;
        // CRITICAL RULE: Completed status alone NEVER qualifies as paid revenue.
        // Payment MUST be authoritatively verified.
        if (b.isPaidVerified) {
          paidBookingsCount++;
          actualSales += b.totalPrice;
          if (b.hasTipData) tips += (b.tipAmount ?? 0.0);
          if (b.hasTaxData) taxes += (b.taxAmount ?? 0.0);
        } else {
          // Completed but unpaid (awaiting counter payment settlement)
          forecast += b.totalPrice;
        }
      } else {
        // Fallback for other prospective statuses
        if (b.isPaidVerified) {
          paidBookingsCount++;
          actualSales += b.totalPrice;
          if (b.hasTipData) tips += (b.tipAmount ?? 0.0);
          if (b.hasTaxData) taxes += (b.taxAmount ?? 0.0);
        } else {
          forecast += b.totalPrice;
        }
      }
    }

    // Availability determination
    final bool isActualRevenueAvailable =
        total == 0 || hasAnyPaymentData;
    final bool isTipsAvailable = total == 0 ||
        (hasAnyPaymentData && (paidBookingsCount == 0 || hasAnyTipData));
    final bool isTaxAvailable = total == 0 ||
        (hasAnyPaymentData && (paidBookingsCount == 0 || hasAnyTaxData));
    final bool isTotalCollectedAvailable = total == 0 ||
        (hasAnyPaymentData &&
            (paidBookingsCount == 0 || (hasAnyTipData && hasAnyTaxData)));

    final double? finalActualRevenue =
        isActualRevenueAvailable ? actualSales : null;
    final double? finalTips = isTipsAvailable ? tips : null;
    final double? finalTax = isTaxAvailable ? taxes : null;
    final double? finalTotalCollected =
        isTotalCollectedAvailable ? (actualSales + taxes + tips) : null;

    return GroomerReportSummary(
      totalAppointments: total,
      completedAppointments: completed,
      confirmedAppointments: confirmed,
      inProgressAppointments: inProgress,
      readyForCheckoutAppointments: readyForCheckout,
      pendingAppointments: pending,
      cancelledAppointments: cancelled,
      forecastRevenue: forecast,
      actualRevenue: finalActualRevenue,
      actualTips: finalTips,
      actualTaxes: finalTax,
      actualTotalCollected: finalTotalCollected,
      isActualRevenueAvailable: isActualRevenueAvailable,
      isTipsAvailable: isTipsAvailable,
      isTaxAvailable: isTaxAvailable,
      isTotalCollectedAvailable: isTotalCollectedAvailable,
      currencySymbol: currencySymbol,
      currencyCode: currencyCode,
    );
  }

  /// Factory computing authoritative metrics from the backend reports summary response
  /// (`GET /api/common/groomer/reports/summary`).
  factory GroomerReportSummary.fromServerResponse(
    Map<String, dynamic> data, {
    String currencySymbol = '\$',
    String currencyCode = 'USD',
  }) {
    final overview = data['overview'] is Map
        ? Map<String, dynamic>.from(data['overview'] as Map)
        : <String, dynamic>{};

    final total = int.tryParse(overview['totalAppointments']?.toString() ?? '') ?? 0;
    final completed = int.tryParse(overview['completedCheckouts']?.toString() ?? '') ?? 0;
    final pending = int.tryParse(overview['pendingCheckouts']?.toString() ?? '') ?? 0;
    final cancelled = int.tryParse(overview['cancelledAppointments']?.toString() ?? '') ?? 0;

    final actualSales = double.tryParse(overview['actualSalesTotal']?.toString() ?? '');
    final taxes = double.tryParse(overview['salesTaxTotal']?.toString() ?? '');
    final tips = double.tryParse(overview['tipsTotal']?.toString() ?? '');
    final totalCollected = double.tryParse(overview['actualGrossRevenue']?.toString() ?? '');
    final forecast = double.tryParse(overview['forecastRevenue']?.toString() ?? '') ?? 0.0;

    return GroomerReportSummary(
      totalAppointments: total,
      completedAppointments: completed,
      confirmedAppointments: 0,
      inProgressAppointments: 0,
      readyForCheckoutAppointments: 0,
      pendingAppointments: pending,
      cancelledAppointments: cancelled,
      forecastRevenue: forecast,
      actualRevenue: actualSales,
      actualTips: tips,
      actualTaxes: taxes,
      actualTotalCollected: totalCollected,
      isActualRevenueAvailable: actualSales != null,
      isTipsAvailable: tips != null,
      isTaxAvailable: taxes != null,
      isTotalCollectedAvailable: totalCollected != null,
      currencySymbol: currencySymbol,
      currencyCode: currencyCode,
    );
  }

  // ── Currency Formatting Helpers ───────────────────────────────────────────

  String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2);
    return formatter.format(amount);
  }

  String get formattedForecastRevenue => formatCurrency(forecastRevenue);

  String get formattedActualRevenue {
    if (!isActualRevenueAvailable || actualRevenue == null) {
      return 'Unavailable';
    }
    return formatCurrency(actualRevenue!);
  }

  String get formattedActualTips {
    if (!isTipsAvailable || actualTips == null) {
      return 'Unavailable';
    }
    return formatCurrency(actualTips!);
  }

  String get formattedActualTaxes {
    if (!isTaxAvailable || actualTaxes == null) {
      return 'Unavailable';
    }
    return formatCurrency(actualTaxes!);
  }

  String get formattedActualTotalCollected {
    if (!isTotalCollectedAvailable || actualTotalCollected == null) {
      return 'Unavailable';
    }
    return formatCurrency(actualTotalCollected!);
  }

  /// Completion rate as a percentage string (e.g. "85%"), or "0%" if empty.
  String get completionRatePercentage {
    if (totalAppointments == 0) return '0%';
    final rate = (completedAppointments / totalAppointments) * 100;
    return '${rate.toStringAsFixed(0)}%';
  }
}
