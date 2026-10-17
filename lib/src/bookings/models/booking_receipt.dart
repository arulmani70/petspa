import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';

/// Authoritative Receipt & Invoice Model (Step 11).
///
/// Designed to represent completed booking financial details for both customer
/// and groomer views.
///
/// Strict Financial Safety Rules:
/// - Never fabricates fake receipt numbers, payment references, or transaction IDs.
/// - Never fabricates $0.00 for missing taxes.
/// - Never infers that a booking is paid solely because its status is 'completed'.
/// - Payment status is considered paid ONLY if explicitly verified by server fields.
class BookingReceipt {
  final int bookingId;
  final String? transactionId;
  final String status;
  final bool? isPaid;
  final String? paymentStatus;
  final String? paymentMethod;
  final String petName;
  final String breed;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String groomerName;
  final String serviceName;
  final String? packageName;
  final List<String> addOns;
  final double basePrice;
  final double? tipAmount;
  final double? taxAmount;
  final double? discountAmount;
  final double? depositAmount;
  final double totalAuthoritativeAmount;
  final String appointmentDate;
  final String appointmentTime;
  final String? completedAt;

  const BookingReceipt({
    required this.bookingId,
    this.transactionId,
    required this.status,
    this.isPaid,
    this.paymentStatus,
    this.paymentMethod,
    required this.petName,
    this.breed = '',
    required this.customerName,
    this.customerPhone = '',
    this.customerEmail = '',
    required this.groomerName,
    required this.serviceName,
    this.packageName,
    this.addOns = const [],
    required this.basePrice,
    this.tipAmount,
    this.taxAmount,
    this.discountAmount,
    this.depositAmount,
    required this.totalAuthoritativeAmount,
    required this.appointmentDate,
    required this.appointmentTime,
    this.completedAt,
  });

  /// True ONLY if explicitly marked as paid by server fields.
  /// Status 'completed' alone is NEVER treated as proof of payment.
  bool get isAuthoritativelyPaid =>
      isPaid == true || paymentStatus?.toLowerCase() == 'paid';

  bool get hasReceiptData => bookingId > 0;

  bool get hasTip => tipAmount != null && tipAmount! > 0;
  bool get hasTax => taxAmount != null && taxAmount! > 0;
  bool get hasDiscount => discountAmount != null && discountAmount! > 0;
  bool get hasDeposit => depositAmount != null && depositAmount! > 0;

  String get fullServiceDescription {
    final buffer = StringBuffer(serviceName);
    if (packageName != null && packageName!.isNotEmpty) {
      buffer.write(' ($packageName)');
    }
    return buffer.toString();
  }

  factory BookingReceipt.fromGroomerBooking(GroomerBooking b) {
    return BookingReceipt(
      bookingId: b.bookingId,
      status: b.status,
      isPaid: b.isPaid,
      paymentStatus: b.paymentStatus,
      paymentMethod: null, // Backend does not provide payment method
      petName: b.petName.isNotEmpty ? b.petName : 'Pet',
      breed: b.breed,
      customerName: b.customerName.isNotEmpty ? b.customerName : 'Customer',
      customerPhone: b.customerMobile,
      customerEmail: b.customerEmail,
      groomerName: b.effectiveGroomerName,
      serviceName: b.serviceName,
      packageName: b.packageName,
      addOns: b.addOns,
      basePrice: b.totalPrice,
      tipAmount: b.tipAmount,
      taxAmount: b.taxAmount,
      totalAuthoritativeAmount: b.totalAuthoritativeAmountDue,
      appointmentDate: b.formattedBookingDate,
      appointmentTime: b.formattedTimeRange,
      completedAt: b.milestoneRecord?.groomingCompletedAt ?? b.createdAt,
    );
  }

  factory BookingReceipt.fromMap(Map<String, dynamic> map) {
    final rawId = map['bookingId'] ?? map['id'] ?? map['_id'];
    final bookingId = int.tryParse(rawId?.toString() ?? '') ?? 0;

    // Pet info
    String pName = 'Pet';
    String pBreed = '';
    if (map['pet'] is Map) {
      final petMap = map['pet'] as Map;
      pName = petMap['name']?.toString() ?? 'Pet';
      pBreed = petMap['breed']?.toString() ?? '';
    } else {
      pName = map['petName']?.toString() ?? 'Pet';
      pBreed = map['breed']?.toString() ?? '';
    }

    // Customer info
    String cName = 'Customer';
    String cPhone = '';
    String cEmail = '';
    if (map['customer'] is Map) {
      final cMap = map['customer'] as Map;
      cName = cMap['name']?.toString() ?? 'Customer';
      cPhone = cMap['phone']?.toString() ?? cMap['mobile']?.toString() ?? '';
      cEmail = cMap['email']?.toString() ?? '';
    } else {
      cName = map['customerName']?.toString() ?? map['user_name']?.toString() ?? 'Customer';
      cPhone = map['customerMobile']?.toString() ?? map['phone']?.toString() ?? '';
      cEmail = map['customerEmail']?.toString() ?? map['email']?.toString() ?? '';
    }

    // Groomer info
    String gName = 'Assigned Staff';
    if (map['groomer'] is Map) {
      gName = map['groomer']['name']?.toString() ?? 'Assigned Staff';
    } else if (map['groomerName'] != null) {
      gName = map['groomerName'].toString();
    } else if (map['assignedGroomer'] != null) {
      gName = map['assignedGroomer'].toString();
    }

    // Service & Package info
    String sName = 'Grooming Service';
    if (map['service'] is Map) {
      sName = map['service']['name']?.toString() ?? 'Grooming Service';
    } else if (map['serviceName'] != null) {
      sName = map['serviceName'].toString();
    }

    String? pkgName;
    if (map['package'] is Map) {
      pkgName = map['package']['name']?.toString();
    } else if (map['packageName'] != null) {
      pkgName = map['packageName'].toString();
    }

    // AddOns & Line Items
    List<String> addOns = [];
    if (map['addOns'] is List) {
      addOns = (map['addOns'] as List).map((e) {
        if (e is Map) return e['name']?.toString() ?? '';
        return e.toString();
      }).where((s) => s.isNotEmpty).toList();
    }
    if (map['lineItems'] is List) {
      final items = map['lineItems'] as List;
      for (final it in items) {
        if (it is Map) {
          final desc = it['description']?.toString() ?? '';
          final type = it['type']?.toString();
          if (type == 'service' && desc.isNotEmpty && sName == 'Grooming Service') {
            sName = desc;
          } else if (type == 'addon' && desc.isNotEmpty) {
            if (!addOns.contains(desc)) addOns.add(desc);
          }
        }
      }
    }

    // Financials
    double base = 0.0;
    if (map['totalPrice'] != null) {
      base = double.tryParse(map['totalPrice'].toString()) ?? 0.0;
    } else if (map['totalAmount'] != null) {
      base = double.tryParse(map['totalAmount'].toString()) ?? 0.0;
    } else if (map['price'] != null) {
      base = double.tryParse(map['price'].toString()) ?? 0.0;
    } else if (map['serviceAmount'] != null) {
      base = double.tryParse(map['serviceAmount'].toString()) ?? 0.0;
    } else if (map['serviceCharge'] != null) {
      base = double.tryParse(map['serviceCharge'].toString()) ?? 0.0;
    }

    double? tip;
    if (map['tipAmount'] != null) {
      tip = double.tryParse(map['tipAmount'].toString());
    } else if (map['tip'] != null) {
      tip = double.tryParse(map['tip'].toString());
    }

    double? tax;
    if (map['taxAmount'] != null) {
      tax = double.tryParse(map['taxAmount'].toString());
    } else if (map['salesTaxAmount'] != null) {
      tax = double.tryParse(map['salesTaxAmount'].toString());
    } else if (map['salesTax'] != null) {
      tax = double.tryParse(map['salesTax'].toString());
    } else if (map['tax'] != null) {
      tax = double.tryParse(map['tax'].toString());
    }

    double? discount;
    if (map['discountAmount'] != null) {
      discount = double.tryParse(map['discountAmount'].toString());
    } else if (map['discount'] != null) {
      discount = double.tryParse(map['discount'].toString());
    }

    double? deposit;
    if (map['depositAmount'] != null) {
      deposit = double.tryParse(map['depositAmount'].toString());
    } else if (map['deposit'] != null) {
      deposit = double.tryParse(map['deposit'].toString());
    }

    double authoritativeTotal = base;
    if (tip != null && tip > 0) authoritativeTotal += tip;
    if (tax != null && tax > 0) authoritativeTotal += tax;
    if (discount != null && discount > 0) authoritativeTotal -= discount;
    if (map['finalTotal'] != null) {
      final ft = double.tryParse(map['finalTotal'].toString());
      if (ft != null && ft > 0) {
        authoritativeTotal = ft;
      }
    }

    // Payment status parsing (Strict: never infer paid from completed status)
    bool? isPaid;
    if (map['isPaid'] != null) {
      final val = map['isPaid'];
      isPaid = val == true || val.toString().toLowerCase() == 'true' || val == 1;
    } else if (map['paid'] != null) {
      final val = map['paid'];
      isPaid = val == true || val.toString().toLowerCase() == 'true' || val == 1;
    }

    String? paymentStatus;
    if (map['paymentStatus'] != null) {
      paymentStatus = map['paymentStatus'].toString();
    } else if (map['payment_status'] != null) {
      paymentStatus = map['payment_status'].toString();
    } else if (isPaid != null) {
      paymentStatus = isPaid ? 'paid' : 'unpaid';
    }

    final String dateStr = map['bookingDate']?.toString() ?? map['date']?.toString() ?? '';
    final String timeStr = map['startTime']?.toString() ?? map['time']?.toString() ?? '';

    return BookingReceipt(
      bookingId: bookingId,
      transactionId: map['transactionId']?.toString() ?? map['transaction_id']?.toString() ?? map['receiptId']?.toString(),
      status: map['status']?.toString() ?? 'completed',
      isPaid: isPaid,
      paymentStatus: paymentStatus,
      paymentMethod: map['paymentMethod']?.toString() ?? map['payment_method']?.toString(),
      petName: pName,
      breed: pBreed,
      customerName: cName,
      customerPhone: cPhone,
      customerEmail: cEmail,
      groomerName: gName,
      serviceName: sName,
      packageName: pkgName,
      addOns: addOns,
      basePrice: base,
      tipAmount: tip,
      taxAmount: tax,
      discountAmount: discount,
      depositAmount: deposit,
      totalAuthoritativeAmount: authoritativeTotal,
      appointmentDate: dateStr,
      appointmentTime: timeStr,
      completedAt: map['completedAt']?.toString() ?? map['updatedAt']?.toString(),
    );
  }
}
