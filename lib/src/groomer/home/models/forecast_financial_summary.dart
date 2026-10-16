import 'package:intl/intl.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';

/// Encapsulates financial projections, sales history, and appointment statistics
/// for the Groomer Portal Forecast screen.
///
/// Implements strict business rules:
/// 1. Forecast includes eligible unpaid appointments only (`!isPaid`, `status != 'checkout_completed'`).
/// 2. Strict Rule: Appointment status alone is NEVER treated as proof of payment.
///    Payment completion requires explicit backend payment confirmation (`isPaid == true` or `paymentStatus == 'paid'`).
///    A generic `completed` appointment represents grooming finished, awaiting customer pickup/checkout (unpaid).
/// 3. Incomplete / Missing Data Handling:
///    When the backend endpoint (e.g. `/api/groomer-auth/groomer-availability/:groomerId`) omits
///    payment status (`isPaid`), tips (`tipAmount`), or tax (`taxAmount`), metrics are clearly marked
///    as unavailable or incomplete rather than defaulted to misleading zero totals ($0.00).
/// 4. Exclude cancelled appointments (`status == 'cancelled'`) and exclude pending appointments by default (`status == 'pending'`).
/// 5. Forecast amount includes pure service charges only (`totalPrice`), strictly excluding tax and tips.
/// 6. Completed sales, tax, tips, and total collected are calculated and presented separately.
/// 7. Paid appointments are never counted in the forecast again (prevents double-counting).
/// 8. Configurable currency support: respects store and app currency configurations without hardcoding.
/// 9. Financial summaries cover the entire filtered date range (up to 92 days) and all selected groomers.
class ForecastFinancialSummary {
  final double forecastServiceAmount;
  final double? completedSales;
  final double? tipsCollected;
  final double? taxCollected;
  final double? totalCollected;

  final int forecastAppointmentsCount;
  final int completedAppointmentsCount;
  final int cancelledAppointmentsCount;
  final int pendingAppointmentsCount;
  final int totalAppointmentsCount;

  final bool isForecastDataComplete;
  final bool isCompletedSalesAvailable;
  final bool isTipsAvailable;
  final bool isTaxAvailable;
  final bool isTotalCollectedAvailable;

  final String currencySymbol;
  final String currencyCode;

  const ForecastFinancialSummary({
    this.forecastServiceAmount = 0.0,
    this.completedSales,
    this.tipsCollected,
    this.taxCollected,
    this.totalCollected,
    this.forecastAppointmentsCount = 0,
    this.completedAppointmentsCount = 0,
    this.cancelledAppointmentsCount = 0,
    this.pendingAppointmentsCount = 0,
    this.totalAppointmentsCount = 0,
    this.isForecastDataComplete = true,
    this.isCompletedSalesAvailable = true,
    this.isTipsAvailable = true,
    this.isTaxAvailable = true,
    this.isTotalCollectedAvailable = true,
    this.currencySymbol = '\$',
    this.currencyCode = 'USD',
  });

  /// Computes financial aggregations from a list of [GroomerBooking] appointments.
  factory ForecastFinancialSummary.fromBookings(
    Iterable<GroomerBooking> bookings, {
    String currencySymbol = '\$',
    String currencyCode = 'USD',
  }) {
    double forecastAmount = 0.0;
    double salesAmount = 0.0;
    double tips = 0.0;
    double taxes = 0.0;

    int forecastCount = 0;
    int completedCount = 0;
    int cancelledCount = 0;
    int pendingCount = 0;
    int totalCount = 0;

    bool hasAnyPaymentData = false;
    bool hasAnyTipData = false;
    bool hasAnyTaxData = false;

    for (final b in bookings) {
      totalCount++;
      final statusLower = b.status.trim().toLowerCase();

      // Rule: Exclude cancelled appointments
      if (statusLower == 'cancelled' || statusLower == 'canceled') {
        cancelledCount++;
        continue;
      }

      // Rule: Exclude pending appointments by default
      if (statusLower == 'pending') {
        pendingCount++;
        continue;
      }

      if (b.hasPaymentData) {
        hasAnyPaymentData = true;
      }
      if (b.hasTipData) {
        hasAnyTipData = true;
      }
      if (b.hasTaxData) {
        hasAnyTaxData = true;
      }

      // Strict Rule: Appointment status alone is never treated as proof of payment.
      // Only explicit backend payment confirmation (isPaid == true or paymentStatus == 'paid')
      // qualifies an appointment as paid into Completed Sales.
      if (b.isPaidVerified) {
        completedCount++;
        salesAmount += b.totalPrice;
        if (b.hasTipData) {
          tips += (b.tipAmount ?? 0.0);
        }
        if (b.hasTaxData) {
          taxes += (b.taxAmount ?? 0.0);
        }
      } else {
        // Active unpaid or unverified appointments awaiting checkout
        forecastCount++;
        forecastAmount += b.totalPrice;
      }
    }

    // Availability determination:
    // If no appointments exist (totalCount == 0), totals are verified 0.00.
    // If appointments exist but payment/tip fields were omitted by the backend,
    // mark respective metrics as unavailable/incomplete so they are not shown as verified zero totals.
    final bool isCompletedSalesAvailable = totalCount == 0 || hasAnyPaymentData;
    final bool isTipsAvailable = totalCount == 0 ||
        (hasAnyPaymentData && (completedCount == 0 || hasAnyTipData));
    final bool isTaxAvailable = totalCount == 0 ||
        (hasAnyPaymentData && (completedCount == 0 || hasAnyTaxData));
    final bool isTotalCollectedAvailable = totalCount == 0 ||
        (hasAnyPaymentData &&
            (completedCount == 0 || (hasAnyTipData && hasAnyTaxData)));
    final bool isForecastDataComplete = totalCount == 0 || hasAnyPaymentData;

    final double? finalCompletedSales = isCompletedSalesAvailable ? salesAmount : null;
    final double? finalTips = isTipsAvailable ? tips : null;
    final double? finalTax = isTaxAvailable ? taxes : null;
    final double? finalTotalCollected = isTotalCollectedAvailable ? (salesAmount + taxes + tips) : null;

    return ForecastFinancialSummary(
      forecastServiceAmount: forecastAmount,
      completedSales: finalCompletedSales,
      tipsCollected: finalTips,
      taxCollected: finalTax,
      totalCollected: finalTotalCollected,
      forecastAppointmentsCount: forecastCount,
      completedAppointmentsCount: completedCount,
      cancelledAppointmentsCount: cancelledCount,
      pendingAppointmentsCount: pendingCount,
      totalAppointmentsCount: totalCount,
      isForecastDataComplete: isForecastDataComplete,
      isCompletedSalesAvailable: isCompletedSalesAvailable,
      isTipsAvailable: isTipsAvailable,
      isTaxAvailable: isTaxAvailable,
      isTotalCollectedAvailable: isTotalCollectedAvailable,
      currencySymbol: currencySymbol,
      currencyCode: currencyCode,
    );
  }

  /// Deserializes a backend-provided summary object (e.g. from `/api/groomer-auth/forecast`).
  factory ForecastFinancialSummary.fromJson(
    Map<String, dynamic> json, {
    String currencySymbol = '\$',
    String currencyCode = 'USD',
  }) {
    final hasForecast = json['forecastServiceAmount'] != null;
    final hasSales = json['completedSalesAmount'] != null || json['completedSales'] != null;
    final hasTips = json['completedTipAmount'] != null || json['tipsCollected'] != null;
    final hasTax = json['completedTaxAmount'] != null || json['taxCollected'] != null;
    final hasTotal = json['completedTotalCollected'] != null || json['totalCollected'] != null;

    final forecastAmount = double.tryParse(json['forecastServiceAmount']?.toString() ?? '') ?? 0.0;
    final salesAmount = hasSales
        ? double.tryParse(json['completedSalesAmount']?.toString() ?? json['completedSales']?.toString() ?? '')
        : null;
    final tipsAmount = hasTips
        ? double.tryParse(json['completedTipAmount']?.toString() ?? json['tipsCollected']?.toString() ?? '')
        : null;
    final taxAmount = hasTax
        ? double.tryParse(json['completedTaxAmount']?.toString() ?? json['taxCollected']?.toString() ?? '')
        : null;
    final totalAmount = hasTotal
        ? double.tryParse(json['completedTotalCollected']?.toString() ?? json['totalCollected']?.toString() ?? '')
        : null;

    return ForecastFinancialSummary(
      forecastServiceAmount: forecastAmount,
      completedSales: salesAmount,
      tipsCollected: tipsAmount,
      taxCollected: taxAmount,
      totalCollected: totalAmount,
      forecastAppointmentsCount: int.tryParse(json['forecastAppointmentsCount']?.toString() ?? '') ?? 0,
      completedAppointmentsCount: int.tryParse(json['completedAppointmentsCount']?.toString() ?? '') ?? 0,
      cancelledAppointmentsCount: int.tryParse(json['cancelledAppointmentsCount']?.toString() ?? '') ?? 0,
      pendingAppointmentsCount: int.tryParse(json['pendingAppointmentsCount']?.toString() ?? '') ?? 0,
      totalAppointmentsCount: int.tryParse(json['totalAppointments']?.toString() ?? json['totalAppointmentsCount']?.toString() ?? '') ?? 0,
      isForecastDataComplete: json['isForecastDataComplete'] as bool? ?? hasForecast,
      isCompletedSalesAvailable: json['isCompletedSalesAvailable'] as bool? ?? hasSales,
      isTipsAvailable: json['isTipsAvailable'] as bool? ?? hasTips,
      isTaxAvailable: json['isTaxAvailable'] as bool? ?? hasTax,
      isTotalCollectedAvailable: json['isTotalCollectedAvailable'] as bool? ?? hasTotal,
      currencySymbol: json['currencySymbol']?.toString() ?? currencySymbol,
      currencyCode: json['currencyCode']?.toString() ?? json['currency']?.toString() ?? currencyCode,
    );
  }

  Map<String, dynamic> toJson() => {
    'forecastServiceAmount': forecastServiceAmount,
    'completedSalesAmount': completedSales,
    'completedTipAmount': tipsCollected,
    'completedTaxAmount': taxCollected,
    'completedTotalCollected': totalCollected,
    'forecastAppointmentsCount': forecastAppointmentsCount,
    'completedAppointmentsCount': completedAppointmentsCount,
    'cancelledAppointmentsCount': cancelledAppointmentsCount,
    'pendingAppointmentsCount': pendingAppointmentsCount,
    'totalAppointments': totalAppointmentsCount,
    'isForecastDataComplete': isForecastDataComplete,
    'isCompletedSalesAvailable': isCompletedSalesAvailable,
    'isTipsAvailable': isTipsAvailable,
    'isTaxAvailable': isTaxAvailable,
    'isTotalCollectedAvailable': isTotalCollectedAvailable,
    'currencySymbol': currencySymbol,
    'currencyCode': currencyCode,
  };

  /// Formats currency with the configured currency symbol.
  String formatCurrency(double amount, {String? symbol}) {
    final s = symbol ?? currencySymbol;
    final formatter = NumberFormat.currency(symbol: s, decimalDigits: 2);
    return formatter.format(amount);
  }

  static String format(double amount, {String symbol = '\$'}) {
    final formatter = NumberFormat.currency(symbol: symbol, decimalDigits: 2);
    return formatter.format(amount);
  }

  String get formattedForecastServiceAmount => formatCurrency(forecastServiceAmount);

  String get formattedCompletedSales {
    if (!isCompletedSalesAvailable || completedSales == null) {
      return 'Unavailable';
    }
    return formatCurrency(completedSales!);
  }

  String get formattedTipsCollected {
    if (!isTipsAvailable || tipsCollected == null) {
      return 'Unavailable';
    }
    return formatCurrency(tipsCollected!);
  }

  String get formattedTaxCollected {
    if (!isTaxAvailable || taxCollected == null) {
      return 'Unavailable';
    }
    return formatCurrency(taxCollected!);
  }

  String get formattedTotalCollected {
    if (!isTotalCollectedAvailable || totalCollected == null) {
      return 'Unavailable';
    }
    return formatCurrency(totalCollected!);
  }

  /// Total active revenue volume (forecast + completed sales) when sales are available
  double? get totalVolume {
    if (!isCompletedSalesAvailable || completedSales == null) {
      return null;
    }
    return forecastServiceAmount + completedSales!;
  }

  String get formattedTotalVolume {
    final v = totalVolume;
    if (v == null) return 'Unavailable';
    return formatCurrency(v);
  }

  /// Active billable appointments (forecast + completed)
  int get activeAppointmentsCount => forecastAppointmentsCount + completedAppointmentsCount;
}
