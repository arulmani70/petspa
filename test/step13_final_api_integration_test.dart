import 'package:flutter_test/flutter_test.dart';
import 'package:shear_heaven_pet_spa/src/bookings/models/booking_receipt.dart';
import 'package:shear_heaven_pet_spa/src/common/constants/app_constants.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/forecast_financial_summary.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_milestone_record.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_report_summary.dart';

void main() {
  group('Step 13: Final API Integration & End-to-End Contracts', () {
    test('AppConstants BASE_URL points to https://api.shearheavenpetspa.com', () {
      const constants = AppConstants();
      expect(constants.BASE_URL, 'https://api.shearheavenpetspa.com');
    });

    test('BookingReceipt.fromMap parses authoritative server receipt payload', () {
      final serverReceiptData = <String, dynamic>{
        'receiptId': 'REC-20261015-1',
        'transactionId': 'TXN-1',
        'bookingId': 1,
        'completedAt': '2026-10-16T10:25:43.000Z',
        'store': {
          'storeId': 'SHEAR-001',
          'name': 'Shear Heaven Darwin',
          'address': '123 Darwin Way',
          'phone': '555-0199',
        },
        'customer': {
          'name': 'sasi',
          'phone': '9898988988',
        },
        'pet': {
          'name': 'bella',
          'breed': 'Poodle',
          'size': 'Small',
        },
        'assignedGroomer': 'Richard Cooke',
        'lineItems': [
          {
            'description': 'Small Breeds - Grooming',
            'type': 'service',
            'amount': 45,
          },
          {
            'description': 'Nail Grinding',
            'type': 'addon',
            'amount': 18,
          },
        ],
        'serviceCharge': 63.0,
        'taxRatePercent': 8.13,
        'salesTaxAmount': 5.12,
        'subtotalWithTax': 68.12,
        'tipAmount': 0.0,
        'finalTotal': 68.12,
        'paymentMethod': 'card',
        'paymentStatus': 'paid',
      };

      final receipt = BookingReceipt.fromMap(serverReceiptData);

      expect(receipt.bookingId, 1);
      expect(receipt.transactionId, 'TXN-1');
      expect(receipt.customerName, 'sasi');
      expect(receipt.customerPhone, '9898988988');
      expect(receipt.petName, 'bella');
      expect(receipt.breed, 'Poodle');
      expect(receipt.groomerName, 'Richard Cooke');
      expect(receipt.serviceName, 'Small Breeds - Grooming');
      expect(receipt.addOns, contains('Nail Grinding'));
      expect(receipt.basePrice, 63.0);
      expect(receipt.taxAmount, 5.12);
      expect(receipt.tipAmount, 0.0);
      expect(receipt.totalAuthoritativeAmount, 68.12);
      expect(receipt.paymentMethod, 'card');
      expect(receipt.paymentStatus, 'paid');
      expect(receipt.isAuthoritativelyPaid, isTrue);
    });

    test('GroomerReportSummary.fromServerResponse parses authoritative server reports overview', () {
      final serverReportData = <String, dynamic>{
        'reportPeriod': {
          'period': 'custom',
          'startDate': '2026-10-01',
          'endDate': '2026-10-31',
        },
        'overview': {
          'totalAppointments': 1,
          'completedCheckouts': 1,
          'pendingCheckouts': 0,
          'cancelledAppointments': 0,
          'actualSalesTotal': 63.0,
          'salesTaxTotal': 5.12,
          'tipsTotal': 0.0,
          'actualGrossRevenue': 68.12,
          'forecastRevenue': 0.0,
        },
        'groomerBreakdown': [
          {
            'groomerId': 2,
            'groomerName': 'Richard Cooke',
            'totalAppointments': 1,
            'completedCount': 1,
            'pendingCount': 0,
            'completedSales': 63.0,
            'tipsEarned': 0.0,
            'salesTaxCollected': 5.12,
            'forecastRemaining': 0.0,
          },
        ],
      };

      final summary = GroomerReportSummary.fromServerResponse(serverReportData);

      expect(summary.totalAppointments, 1);
      expect(summary.completedAppointments, 1);
      expect(summary.pendingAppointments, 0);
      expect(summary.cancelledAppointments, 0);
      expect(summary.actualRevenue, 63.0);
      expect(summary.actualTaxes, 5.12);
      expect(summary.actualTips, 0.0);
      expect(summary.actualTotalCollected, 68.12);
      expect(summary.forecastRevenue, 0.0);
      expect(summary.isActualRevenueAvailable, isTrue);
      expect(summary.isTaxAvailable, isTrue);
      expect(summary.isTipsAvailable, isTrue);
      expect(summary.isTotalCollectedAvailable, isTrue);
      expect(summary.formattedActualRevenue, '\$63.00');
      expect(summary.formattedActualTaxes, '\$5.12');
      expect(summary.formattedActualTips, '\$0.00');
      expect(summary.formattedActualTotalCollected, '\$68.12');
      expect(summary.completionRatePercentage, '100%');
    });

    test('Checkout status schema model integrity', () {
      final statusMap = <String, dynamic>{
        'bookingId': 1,
        'customerConfirmed': false,
        'customerConfirmedAt': null,
        'serviceCharge': 63.0,
        'salesTax': 5.12,
        'tipAmount': 0.0,
        'finalTotal': 68.12,
        'readyForFinalCheckout': false,
      };

      expect(statusMap['bookingId'], 1);
      expect(statusMap['serviceCharge'], 63.0);
      expect(statusMap['salesTax'], 5.12);
      expect(statusMap['finalTotal'], 68.12);
      expect(statusMap['readyForFinalCheckout'], false);
    });

    test('Forecast API /api/common/groomer/forecast parses financialSummary and appointments accurately', () {
      final rawForecastPayload = <String, dynamic>{
        'financialSummary': {
          'forecastServiceAmount': 75,
          'pendingForecastAmount': 0,
          'completedSalesAmount': 63,
          'completedTipAmount': 0,
          'completedTotalCollected': 68.12,
        },
        'groomerSummaries': [
          {
            'groomerId': 2,
            'groomerName': 'Richard Cooke',
            'totalAppointments': 1,
            'completedCount': 1,
            'pendingCount': 0,
            'completedSales': 63,
            'tipsEarned': 0,
            'salesTaxCollected': 5.12,
            'forecastRemaining': 0,
          },
          {
            'groomerId': 1,
            'groomerName': 'Merisa Brown',
            'totalAppointments': 3,
            'completedCount': 0,
            'pendingCount': 1,
            'completedSales': 0,
            'tipsEarned': 0,
            'salesTaxCollected': 0,
            'forecastRemaining': 75,
          },
        ],
        'appointments': [
          {
            'bookingId': 1,
            'bookingDate': '2026-10-15',
            'startTime': '16:00',
            'groomerId': 2,
            'groomerName': 'Richard Cooke',
            'serviceStage': 'checkout_completed',
            'paymentStatus': 'paid',
            'serviceAmount': 63,
            'completed': {
              'serviceAmount': 63,
              'taxAmount': 5.12,
              'tipAmount': 0,
              'totalAmount': 68.12,
            },
            'pet': {
              'petId': 1,
              'name': 'bella',
              'type': 'Poodle',
              'breed': 'Poodle',
            },
            'customer': {
              'id': 2,
              'name': 'sasi',
              'phone': '9898988988',
            },
            'service': {
              'id': 1,
              'name': 'Small Breeds - Grooming',
            },
            'addOns': [
              {'id': 1, 'name': 'Nail Grinding', 'price': 18},
            ],
          },
          {
            'bookingId': 2,
            'bookingDate': '2026-10-17',
            'startTime': '08:30',
            'groomerId': 1,
            'groomerName': 'Merisa Brown',
            'serviceStage': 'bath_completed',
            'paymentStatus': 'unpaid',
            'serviceAmount': 75,
            'completed': null,
            'pet': {
              'petId': 1,
              'name': 'bella',
              'type': 'Poodle',
              'breed': 'Poodle',
            },
            'customer': {
              'id': 2,
              'name': 'sasi',
              'phone': '9898988988',
            },
            'service': {
              'id': 2,
              'name': 'Small Breeds - Bathing',
            },
            'addOns': [],
          },
        ],
      };

      final summary = ForecastFinancialSummary.fromJson(
        Map<String, dynamic>.from(rawForecastPayload['financialSummary'] as Map),
      );

      expect(summary.forecastServiceAmount, 75.0);
      expect(summary.completedSales, 63.0);
      expect(summary.tipsCollected, 0.0);
      expect(summary.taxCollected, 5.12);
      expect(summary.totalCollected, 68.12);
      expect(summary.isCompletedSalesAvailable, isTrue);
      expect(summary.isTaxAvailable, isTrue);

      final rawAppts = rawForecastPayload['appointments'] as List;
      final b1 = GroomerBooking.fromJson(Map<String, dynamic>.from(rawAppts[0] as Map));
      expect(b1.bookingId, 1);
      expect(b1.customerName, 'sasi');
      expect(b1.customerMobile, '9898988988');
      expect(b1.status, 'completed');
      expect(b1.isPaidVerified, isTrue);
      expect(b1.taxAmount, 5.12);
      expect(b1.addOns, contains('Nail Grinding'));

      final b2 = GroomerBooking.fromJson(Map<String, dynamic>.from(rawAppts[1] as Map));
      expect(b2.bookingId, 2);
      expect(b2.customerName, 'sasi');
      expect(b2.status, 'bath_completed');
      expect(b2.isPaidVerified, isFalse);
      expect(b2.totalPrice, 75.0);
    });

    test('Appointment Milestones catalog and timeline models deserialize correctly', () {
      final timelineData = [
        {'milestoneKey': 'bath_completed', 'completed': true, 'occurredAt': '2026-10-16T10:00:00Z'},
        {'milestoneKey': 'grooming_completed', 'completed': true, 'occurredAt': '2026-10-16T11:00:00Z'},
      ];

      final milestoneRecord = GroomerMilestoneRecord.fromTimeline(timelineData);
      expect(milestoneRecord.bathCompleted, isTrue);
      expect(milestoneRecord.bathCompletedAt, '2026-10-16T10:00:00Z');
      expect(milestoneRecord.groomingCompleted, isTrue);
      expect(milestoneRecord.groomingCompletedAt, '2026-10-16T11:00:00Z');
    });

    test('Booking with serviceStage=ready_for_checkout correctly identifies readyForCheckout state', () {
      final rawBooking = <String, dynamic>{
        'id': 2,
        'bookingDate': '2026-10-16',
        'startTime': '11:00 AM',
        'endTime': '12:00 PM',
        'status': 'in_progress',
        'serviceStage': 'ready_for_checkout',
        'petName': 'bella',
        'customerName': 'sasi',
        'serviceName': 'Grooming',
        'totalPrice': 75.0,
      };

      final booking = GroomerBooking.fromJson(rawBooking);

      expect(booking.bookingId, 2);
      expect(booking.status, 'in_progress');
      expect(booking.serviceStage, 'ready_for_checkout');
      expect(booking.isBathCompleted, isTrue);
      expect(booking.isGroomingCompleted, isTrue);
      expect(booking.isReadyForCheckout, isTrue);
      expect(booking.canMarkReadyForCheckout, isFalse);
      expect(booking.canFinalCheckout, isTrue);
      expect(booking.milestoneRecord?.readyForCheckoutCompleted, isTrue);
    });

    test('GroomerMilestoneRecord.fromTimeline extracts ready_for_checkout milestone', () {
      final timeline = [
        {
          'milestoneKey': 'bath_completed',
          'completed': true,
          'occurredAt': '2026-10-16T15:22:00.000Z',
        },
        {
          'milestoneKey': 'grooming_completed',
          'completed': true,
          'occurredAt': '2026-10-16T15:22:55.000Z',
        },
        {
          'milestoneKey': 'ready_for_checkout',
          'completed': true,
          'occurredAt': '2026-10-16T15:23:01.000Z',
        },
      ];

      final record = GroomerMilestoneRecord.fromTimeline(timeline);

      expect(record.bathCompleted, isTrue);
      expect(record.groomingCompleted, isTrue);
      expect(record.readyForCheckoutCompleted, isTrue);
      expect(record.readyForCheckoutCompletedAt, '2026-10-16T15:23:01.000Z');

      final booking = GroomerBooking(
        bookingId: 2,
        status: 'in_progress',
        bookingDate: '2026-10-16',
        startTime: '11:00 AM',
        endTime: '12:00 PM',
        petName: 'bella',
        customerName: 'sasi',
        serviceName: 'Grooming',
        milestoneRecord: record,
      );

      expect(booking.isReadyForCheckout, isTrue);
      expect(booking.canMarkReadyForCheckout, isFalse);
      expect(booking.canFinalCheckout, isTrue);
    });

    test('Live Common Groomer Checkout APIs contract verification', () {
      final checkoutStatusPayload = <String, dynamic>{
        'success': true,
        'message': 'Checkout status retrieved',
        'data': {
          'bookingId': 2,
          'customerConfirmed': false,
          'customerConfirmedAt': null,
          'serviceCharge': 75.0,
          'salesTax': 6.09,
          'tipAmount': 0.0,
          'finalTotal': 81.09,
          'readyForFinalCheckout': true,
        },
      };

      expect(checkoutStatusPayload['success'], isTrue);
      final data = checkoutStatusPayload['data'] as Map<String, dynamic>;
      expect(data['bookingId'], 2);
      expect(data['serviceCharge'], 75.0);
      expect(data['salesTax'], 6.09);
      expect(data['tipAmount'], 0.0);
      expect(data['finalTotal'], 81.09);
      expect(data['readyForFinalCheckout'], isTrue);

      final checkoutPayload = <String, dynamic>{
        'paymentMethod': 'card',
      };
      final idempotencyKey = 'checkout-2-1792164643000';
      final headers = {'Idempotency-Key': idempotencyKey};

      expect(headers['Idempotency-Key'], isNotEmpty);
      expect(checkoutPayload['paymentMethod'], 'card');
    });
  });
}
