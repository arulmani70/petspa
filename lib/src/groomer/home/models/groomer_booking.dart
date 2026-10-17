import 'package:intl/intl.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/common/constants/constansts.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_check_in_record.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_milestone_record.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/utils/groomer_milestone_resolver.dart';

class GroomerBooking {
  final int bookingId;
  final String status;
  final String bookingDate; // YYYY-MM-DD
  final String startTime;
  final String endTime;
  final int? petId;
  final String petName;
  final String breed;
  final String? profilePicture;
  final int? userId;
  final String customerName;
  final String customerEmail;
  final String customerMobile;
  final int? serviceId;
  final String serviceName;
  final int? packageId;
  final String? packageName;
  final List<String> addOns;
  final List<int> addOnIds;
  final double totalPrice;
  final double? tipAmount;
  final double? taxAmount;
  final bool? isPaid;
  final String? paymentStatus;
  final int totalDurationMinutes;
  final String storeId;
  final String? createdAt;
  final String? cancellationReason;
  final int? groomerId;
  final String? groomerName;
  final String? groomerCode;
  final String? specialInstructions;
  final GroomerCheckInRecord? checkInRecord;
  final String? petMedicalNotes;
  final GroomerMilestoneRecord? milestoneRecord;
  final String? serviceStage;

  const GroomerBooking({
    required this.bookingId,
    required this.status,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    this.petId,
    required this.petName,
    this.breed = '',
    this.profilePicture,
    this.userId,
    required this.customerName,
    this.customerEmail = '',
    this.customerMobile = '',
    this.serviceId,
    required this.serviceName,
    this.packageId,
    this.packageName,
    this.addOns = const [],
    this.addOnIds = const [],
    this.totalPrice = 0.0,
    this.tipAmount,
    this.taxAmount,
    this.isPaid,
    this.paymentStatus,
    this.totalDurationMinutes = 30,
    this.storeId = '',
    this.createdAt,
    this.cancellationReason,
    this.groomerId,
    this.groomerName,
    this.groomerCode,
    this.specialInstructions,
    this.checkInRecord,
    this.petMedicalNotes,
    this.milestoneRecord,
    this.serviceStage,
  });

  double? get totalCollected {
    if (tipAmount == null && taxAmount == null && isPaid != true) {
      return null;
    }
    return totalPrice + (taxAmount ?? 0.0) + (tipAmount ?? 0.0);
  }

  double get effectiveTipAmount => tipAmount ?? 0.0;
  double get effectiveTaxAmount => taxAmount ?? 0.0;
  bool get hasPaymentData => isPaid != null || (paymentStatus != null && paymentStatus!.isNotEmpty);
  bool get hasTipData => tipAmount != null;
  bool get hasTaxData => taxAmount != null;
  bool get isPaidVerified => isPaid == true || paymentStatus?.toLowerCase() == 'paid';

  String? get notes => specialInstructions;
  String? get serviceRequestNotes => specialInstructions;
  bool get hasSpecialInstructions =>
      specialInstructions != null && specialInstructions!.trim().isNotEmpty;

  // Step 6 Check-in Checklist helpers
  String? get checkInTimestamp => checkInRecord?.checkInTimestamp;
  String? get groomerCheckInNotes => checkInRecord?.groomerCheckInNotes;
  bool get isVaccinationVerified => checkInRecord?.vaccinationVerified ?? false;
  bool get isHealthVerified => checkInRecord?.healthVerified ?? false;
  bool get isCustomerRequestAcknowledged => checkInRecord?.customerRequestAcknowledged ?? false;
  bool get isCheckedIn =>
      status.toLowerCase() == 'checked_in' ||
      status.toLowerCase() == 'in_service' ||
      status.toLowerCase() == 'in_progress' ||
      status.toLowerCase() == 'dogserviceinprogress' ||
      status.toLowerCase() == 'bath_completed' ||
      status.toLowerCase() == 'grooming_completed' ||
      status.toLowerCase() == 'ready_for_checkout' ||
      status.toLowerCase() == 'completed' ||
      serviceStage?.toLowerCase() == 'dogserviceinprogress' ||
      serviceStage?.toLowerCase() == 'bath_completed' ||
      serviceStage?.toLowerCase() == 'grooming_completed' ||
      serviceStage?.toLowerCase() == 'ready_for_checkout' ||
      serviceStage?.toLowerCase() == 'checkout_completed' ||
      (milestoneRecord != null && milestoneRecord!.isCheckInDone) ||
      (checkInRecord != null && checkInRecord!.isFullyVerified);
  bool get isConfirmedReadyForCheckIn =>
      status.toLowerCase() == 'confirmed' && !isCheckedIn;
  bool get hasCheckInRecord => checkInRecord != null;
  bool get hasPetMedicalNotes =>
      petMedicalNotes != null && petMedicalNotes!.trim().isNotEmpty;

  // ── Step 7 Dynamic Service Milestone helpers ─────────────────────────────

  /// Dynamically resolved list of required milestone keys for this booking based on selected services.
  List<String> get requiredMilestones => GroomerMilestoneResolver.resolveRequiredMilestones(
        serviceId: serviceId,
        serviceName: serviceName,
        packageId: packageId,
        packageName: packageName,
        addOnIds: addOnIds,
        addOns: addOns,
      );

  bool get requiresBath => requiredMilestones.contains(GroomerMilestoneResolver.bathMilestone);
  bool get requiresGrooming => requiredMilestones.contains(GroomerMilestoneResolver.groomingMilestone);

  bool isMilestoneDone(String milestoneKey) {
    if (milestoneRecord?.isMilestoneDone(milestoneKey) == true) return true;
    if (milestoneKey == 'check_in_completed') return isCheckedIn;
    if (milestoneKey == GroomerMilestoneResolver.bathMilestone) return isBathCompleted;
    if (milestoneKey == GroomerMilestoneResolver.groomingMilestone) return isGroomingCompleted;
    if (milestoneKey == 'ready_for_checkout' || milestoneKey == 'readyforcheckout') {
      return isReadyForCheckout;
    }
    if (status.toLowerCase() == milestoneKey.toLowerCase()) return true;
    return false;
  }

  List<String> get completedRequiredMilestones =>
      requiredMilestones.where((m) => isMilestoneDone(m)).toList();

  List<String> get pendingRequiredMilestones =>
      requiredMilestones.where((m) => !isMilestoneDone(m)).toList();

  bool get areRequiredMilestonesCompleted => pendingRequiredMilestones.isEmpty;

  String? get nextPendingMilestone {
    for (final m in requiredMilestones) {
      if (!isMilestoneDone(m)) return m;
    }
    return null;
  }

  bool canCompleteMilestone(String milestoneKey) {
    if (isMilestoneDone(milestoneKey)) return false;
    if (milestoneKey == GroomerMilestoneResolver.bathMilestone) return canCompleteBath;
    if (milestoneKey == GroomerMilestoneResolver.groomingMilestone) return canCompleteGrooming;
    if (milestoneKey == 'ready_for_checkout' || milestoneKey == 'readyforcheckout') {
      return canMarkReadyForCheckout;
    }
    return isCheckedIn && status.toLowerCase() != 'cancelled' && status.toLowerCase() != 'pending';
  }

  bool get isBathCompleted =>
      status.toLowerCase() == 'bath_completed' ||
      (requiresBath &&
          (status.toLowerCase() == 'grooming_completed' ||
              serviceStage?.toLowerCase() == 'grooming_completed')) ||
      status.toLowerCase() == 'ready_for_checkout' ||
      status.toLowerCase() == 'completed' ||
      serviceStage?.toLowerCase() == 'bath_completed' ||
      serviceStage?.toLowerCase() == 'ready_for_checkout' ||
      serviceStage?.toLowerCase() == 'checkout_completed' ||
      (milestoneRecord?.bathCompleted ?? false);

  bool get isGroomingCompleted =>
      status.toLowerCase() == 'grooming_completed' ||
      status.toLowerCase() == 'ready_for_checkout' ||
      status.toLowerCase() == 'completed' ||
      serviceStage?.toLowerCase() == 'grooming_completed' ||
      serviceStage?.toLowerCase() == 'ready_for_checkout' ||
      serviceStage?.toLowerCase() == 'checkout_completed' ||
      (milestoneRecord?.groomingCompleted ?? false);

  String? get bathNotes => milestoneRecord?.bathNotes;
  String? get groomingNotes => milestoneRecord?.groomingNotes;
  String? get bathCompletedAt => milestoneRecord?.bathCompletedAt;
  String? get groomingCompletedAt => milestoneRecord?.groomingCompletedAt;

  bool get canCompleteBath =>
      requiresBath &&
      (status.toLowerCase() == 'in_progress' ||
          status.toLowerCase() == 'checked_in' ||
          isCheckedIn) &&
      !isBathCompleted &&
      status.toLowerCase() != 'cancelled' &&
      status.toLowerCase() != 'pending';

  bool get canCompleteGrooming {
    if (!requiresGrooming) return false;
    if (isGroomingCompleted) return false;
    if (status.toLowerCase() == 'cancelled' || status.toLowerCase() == 'pending') {
      return false;
    }

    // Dependency check: If bath is also required for this booking, bath must be done first.
    if (requiresBath && !isBathCompleted) {
      return false;
    }

    return status.toLowerCase() == 'in_progress' ||
        status.toLowerCase() == 'checked_in' ||
        status.toLowerCase() == 'bath_completed' ||
        isCheckedIn;
  }

  bool get hasMilestones => milestoneRecord?.hasAnyMilestone ?? false;

  // Step 8 Ready for Checkout helpers
  bool get isReadyForCheckout =>
      status.toLowerCase() == 'ready_for_checkout' ||
      serviceStage?.toLowerCase() == 'ready_for_checkout' ||
      serviceStage?.toLowerCase() == 'checkout_completed' ||
      (milestoneRecord?.readyForCheckoutCompleted ?? false);

  /// Dynamically available only when ALL required milestones for this booking are completed.
  bool get canMarkReadyForCheckout =>
      areRequiredMilestonesCompleted &&
      !isReadyForCheckout &&
      status.toLowerCase() != 'completed' &&
      status.toLowerCase() != 'cancelled' &&
      status.toLowerCase() != 'pending';

  // Step 10 Groomer Final Checkout helpers
  bool get isCompleted =>
      status.toLowerCase() == 'completed' ||
      serviceStage?.toLowerCase() == 'checkout_completed' ||
      serviceStage?.toLowerCase() == 'completed';

  bool get canFinalCheckout =>
      isReadyForCheckout &&
      !isCompleted &&
      status.toLowerCase() != 'cancelled' &&
      status.toLowerCase() != 'pending';

  double get totalAuthoritativeAmountDue {
    double total = totalPrice;
    if (tipAmount != null && tipAmount! > 0) {
      total += tipAmount!;
    }
    if (taxAmount != null && taxAmount! > 0) {
      total += taxAmount!;
    }
    return total;
  }

  String get effectiveGroomerName {
    if (groomerName != null && groomerName!.trim().isNotEmpty) {
      return groomerName!.trim();
    }
    if (groomerId != null && groomerId! > 0) {
      final name = BookingDateUtils.resolveGroomerNameById(groomerId!);
      if (name != null && name.isNotEmpty) return name;
      return 'Groomer #$groomerId';
    }
    if (groomerCode != null && groomerCode!.trim().isNotEmpty) {
      return 'Groomer ${groomerCode!.trim()}';
    }
    return 'Assigned Staff';
  }

  String get formattedBookingDate =>
      BookingDateUtils.formatBookingDateDisplay(bookingDate);

  String get formattedTimeRange {
    try {
      final start = _formatSingleTime(startTime);
      final end = _formatSingleTime(endTime);
      return '$start – $end';
    } catch (_) {
      return '$startTime – $endTime';
    }
  }

  static String _formatSingleTime(String timeStr) {
    final clean = timeStr.trim();
    if (clean.toLowerCase().contains('am') || clean.toLowerCase().contains('pm')) {
      return clean;
    }
    final parts = clean.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      final dt = DateTime(2026, 1, 1, hour, minute);
      return DateFormat('hh:mm a').format(dt);
    }
    return clean;
  }

  String get fullServiceDescription {
    final buffer = StringBuffer(serviceName);
    if (packageName != null && packageName!.isNotEmpty) {
      buffer.write(' ($packageName)');
    }
    if (addOns.isNotEmpty) {
      buffer.write(' + ${addOns.join(', ')}');
    }
    return buffer.toString();
  }

  static String? _normalizeImageUrl(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim();
    if (str.isEmpty || str == 'null' || str == 'undefined') return null;
    if (str.startsWith('http://') || str.startsWith('https://')) {
      return str;
    }
    if (str.startsWith('assets/')) {
      return str;
    }
    final base = Constants.app.BASE_URL;
    if (str.startsWith('/')) {
      return '$base$str';
    }
    return '$base/$str';
  }

  factory GroomerBooking.fromJson(Map<String, dynamic> json) {
    int parsedId = 0;
    if (json['bookingId'] != null) {
      parsedId = int.tryParse(json['bookingId'].toString()) ?? 0;
    } else if (json['id'] != null) {
      parsedId = int.tryParse(json['id'].toString()) ?? 0;
    }

    // Parse Pet
    String pName = 'Pet';
    String pBreed = '';
    String? pPic;
    int? pId = int.tryParse(json['petId']?.toString() ?? json['pet_id']?.toString() ?? '');
    if (json['pet'] is Map<String, dynamic>) {
      final petMap = json['pet'] as Map<String, dynamic>;
      pName = petMap['petName']?.toString() ?? petMap['name']?.toString() ?? 'Pet';
      pBreed = petMap['breed']?.toString() ?? petMap['petBreed']?.toString() ?? '';
      final rawPic = petMap['profilePictureUrl'] ??
          petMap['profilePicture'] ??
          petMap['petProfilePicture'] ??
          petMap['photoUrl'] ??
          petMap['petPhotoUrl'] ??
          petMap['pet_photo_url'] ??
          petMap['image'] ??
          petMap['avatar'];
      pPic = _normalizeImageUrl(rawPic);
      pId ??= int.tryParse(petMap['id']?.toString() ?? petMap['petId']?.toString() ?? '');
    } else {
      pName = json['petName']?.toString() ??
          json['pet_name']?.toString() ??
          'Pet';
      pBreed = json['breed']?.toString() ??
          json['petBreed']?.toString() ??
          json['pet_breed']?.toString() ??
          '';
      final rawPic = json['petProfilePicture'] ??
          json['profilePictureUrl'] ??
          json['profilePicture'] ??
          json['petPhotoUrl'] ??
          json['pet_photo_url'] ??
          json['photoUrl'] ??
          json['petImage'];
      pPic = _normalizeImageUrl(rawPic);
    }

    if (pPic == null || pPic.isEmpty) {
      final fallbackRaw = json['petProfilePicture'] ??
          json['profilePictureUrl'] ??
          json['profilePicture'] ??
          json['petPhotoUrl'] ??
          json['pet_photo_url'] ??
          json['photoUrl'] ??
          json['petImage'];
      pPic = _normalizeImageUrl(fallbackRaw);
    }

    // Parse User
    // Parse User / Customer
    String cName = 'Customer';
    String cEmail = '';
    String cMobile = '';
    int? uId;
    if (json['customer'] is Map) {
      final custMap = json['customer'] as Map;
      cName = custMap['name']?.toString() ?? custMap['fullName']?.toString() ?? 'Customer';
      cEmail = custMap['email']?.toString() ?? '';
      cMobile = custMap['mobile']?.toString() ?? custMap['phone']?.toString() ?? '';
      uId = int.tryParse(custMap['id']?.toString() ?? '');
    } else if (json['user'] is Map) {
      final userMap = json['user'] as Map;
      cName = userMap['name']?.toString() ?? userMap['fullName']?.toString() ?? 'Customer';
      cEmail = userMap['email']?.toString() ?? '';
      cMobile = userMap['mobile']?.toString() ?? userMap['phone']?.toString() ?? '';
      uId = int.tryParse(userMap['id']?.toString() ?? '');
    } else {
      cName = json['customerName']?.toString() ??
          json['customer_name']?.toString() ??
          json['userName']?.toString() ??
          json['user_name']?.toString() ??
          'Customer';
      cEmail = json['customerEmail']?.toString() ??
          json['customer_email']?.toString() ??
          json['userEmail']?.toString() ??
          json['user_email']?.toString() ??
          '';
      cMobile = json['customerMobile']?.toString() ??
          json['customer_mobile']?.toString() ??
          json['userMobile']?.toString() ??
          json['phone']?.toString() ??
          '';
    }

    // Parse Service
    String sName = 'Service';
    int? sId;
    if (json['service'] is Map<String, dynamic>) {
      final serviceMap = json['service'] as Map<String, dynamic>;
      sName = serviceMap['name']?.toString() ?? 'Service';
      sId = int.tryParse(serviceMap['id']?.toString() ?? '');
    } else {
      sName = json['serviceName']?.toString() ?? 'Service';
      sId = int.tryParse(json['serviceId']?.toString() ?? '');
    }

    // Parse Package
    String? pkgName;
    int? pkgId;
    if (json['package'] is Map<String, dynamic>) {
      final pkgMap = json['package'] as Map<String, dynamic>;
      pkgName = pkgMap['name']?.toString();
      pkgId = int.tryParse(pkgMap['id']?.toString() ?? '');
    } else if (json['packageName'] != null) {
      pkgName = json['packageName'].toString();
      pkgId = int.tryParse(json['packageId']?.toString() ?? '');
    }

    // Parse Add-ons
    List<String> parsedAddOns = [];
    List<int> parsedAddOnIds = [];
    if (json['addOnIds'] is List) {
      parsedAddOnIds = (json['addOnIds'] as List)
          .map((e) => int.tryParse(e.toString()))
          .whereType<int>()
          .toList();
    }
    if (json['addOns'] is List) {
      for (final e in json['addOns'] as List) {
        if (e is Map) {
          final name = e['name']?.toString() ?? '';
          if (name.isNotEmpty) parsedAddOns.add(name);
          final aId = int.tryParse(e['id']?.toString() ??
              e['addOnId']?.toString() ??
              e['addon_id']?.toString() ??
              '');
          if (aId != null && !parsedAddOnIds.contains(aId)) {
            parsedAddOnIds.add(aId);
          }
        } else {
          final s = e.toString().trim();
          if (s.isNotEmpty) parsedAddOns.add(s);
        }
      }
    }

    double price = 0.0;
    if (json['totalPrice'] != null) {
      price = double.tryParse(json['totalPrice'].toString()) ?? 0.0;
    } else if (json['totalAmount'] != null) {
      price = double.tryParse(json['totalAmount'].toString()) ?? 0.0;
    } else if (json['serviceAmount'] != null) {
      price = double.tryParse(json['serviceAmount'].toString()) ?? 0.0;
    } else if (json['serviceFee'] != null) {
      price = double.tryParse(json['serviceFee'].toString()) ?? 0.0;
    } else if (json['price'] != null) {
      price = double.tryParse(json['price'].toString()) ?? 0.0;
    }

    double? parsedTip;
    if (json['tipAmount'] != null) {
      parsedTip = double.tryParse(json['tipAmount'].toString());
    } else if (json['tip'] != null) {
      parsedTip = double.tryParse(json['tip'].toString());
    } else if (json['tips'] != null) {
      parsedTip = double.tryParse(json['tips'].toString());
    } else if (json['completedTipAmount'] != null) {
      parsedTip = double.tryParse(json['completedTipAmount'].toString());
    }

    double? parsedTax;
    if (json['taxAmount'] != null) {
      parsedTax = double.tryParse(json['taxAmount'].toString());
    } else if (json['tax'] != null) {
      parsedTax = double.tryParse(json['tax'].toString());
    } else if (json['salesTax'] != null) {
      parsedTax = double.tryParse(json['salesTax'].toString());
    } else if (json['completedTaxAmount'] != null) {
      parsedTax = double.tryParse(json['completedTaxAmount'].toString());
    }

    if (json['completed'] is Map) {
      final compMap = json['completed'] as Map;
      parsedTax ??= double.tryParse(compMap['taxAmount']?.toString() ?? '');
      parsedTip ??= double.tryParse(compMap['tipAmount']?.toString() ?? '');
      if (price == 0.0 && compMap['serviceAmount'] != null) {
        price = double.tryParse(compMap['serviceAmount']?.toString() ?? '') ?? 0.0;
      }
    }

    if (parsedTip == null && ServicesLocator.isRegistered<SessionService>()) {
      parsedTip = ServicesLocator.sessionService.getConfirmedTipAmount(parsedId);
    }

    // Strict Rule: Appointment status alone is never treated as proof of payment.
    // Payment completion must be confirmed by explicit payment fields (isPaid, paymentStatus).
    bool? parsedIsPaid;
    if (json['isPaid'] != null) {
      final val = json['isPaid'];
      parsedIsPaid = val == true || val.toString().toLowerCase() == 'true' || val == 1 || val.toString() == '1';
    } else if (json['paid'] != null) {
      final val = json['paid'];
      parsedIsPaid = val == true || val.toString().toLowerCase() == 'true' || val == 1 || val.toString() == '1';
    } else if (json['isCompletedTransaction'] == true) {
      parsedIsPaid = true;
    } else if (json['paymentStatus'] != null || json['payment_status'] != null) {
      final ps = (json['paymentStatus'] ?? json['payment_status']).toString().toLowerCase().trim();
      if (ps == 'paid') {
        parsedIsPaid = true;
      } else if (ps == 'unpaid') {
        parsedIsPaid = false;
      }
    }

    String? parsedPaymentStatus;
    if (json['paymentStatus'] != null) {
      parsedPaymentStatus = json['paymentStatus'].toString();
    } else if (json['payment_status'] != null) {
      parsedPaymentStatus = json['payment_status'].toString();
    } else if (parsedIsPaid != null) {
      parsedPaymentStatus = parsedIsPaid ? 'paid' : 'unpaid';
    }

    String parsedStatus = 'pending';
    if (json['status'] != null) {
      parsedStatus = json['status'].toString();
    } else if (json['serviceStage'] != null || json['service_stage'] != null) {
      final stage = (json['serviceStage'] ?? json['service_stage']).toString().toLowerCase();
      if (stage == 'checkout_completed') {
        parsedStatus = 'completed';
      } else {
        parsedStatus = stage;
      }
    } else if (parsedIsPaid == true) {
      parsedStatus = 'completed';
    }

    // Parse Groomer
    int? gId;
    String? gName;
    String? gCode;
    if (json['groomer'] is Map<String, dynamic>) {
      final gMap = json['groomer'] as Map<String, dynamic>;
      gName = (gMap['name'] ?? '${gMap['firstName'] ?? ''} ${gMap['lastName'] ?? ''}').toString().trim();
      gId = int.tryParse(gMap['id']?.toString() ?? gMap['groomerId']?.toString() ?? '');
      gCode = (gMap['groomerCode'] ?? gMap['code'] ?? gMap['GroomerId'] ?? '').toString().trim();
    } else {
      gName = json['groomerName']?.toString() ??
          json['assignedGroomer']?.toString() ??
          (json['groomer'] is String ? json['groomer'] as String : null);
      gId = int.tryParse(json['groomerId']?.toString() ?? json['groomer_id']?.toString() ?? '');
      gCode = (json['groomerCode'] ?? json['groomer_code'] ?? '').toString().trim();
    }

    if (gId == null && (gCode.isNotEmpty || (gName != null && gName.isNotEmpty))) {
      gId = BookingDateUtils.resolveCanonicalGroomerId(null, groomerCode: gCode, groomerName: gName);
    }
    if ((gName == null || gName.isEmpty) && gId != null && gId > 0) {
      gName = BookingDateUtils.resolveGroomerNameById(gId);
    }

    final sInstructions = json['specialInstructions']?.toString() ??
        json['special_instructions']?.toString() ??
        json['notes']?.toString() ??
        json['serviceRequestNotes']?.toString() ??
        json['service_request_notes']?.toString();
    final cleanInstructions = (sInstructions != null &&
            sInstructions.trim().isNotEmpty &&
            sInstructions.trim().toLowerCase() != 'null')
        ? sInstructions.trim()
        : null;

    GroomerCheckInRecord? parsedCheckInRecord;
    if (json['checkInRecord'] is Map) {
      parsedCheckInRecord = GroomerCheckInRecord.fromJson(
        Map<String, dynamic>.from(json['checkInRecord'] as Map),
      );
    } else if (json['checkInTimestamp'] != null ||
        json['vaccinationVerified'] != null ||
        json['healthVerified'] != null ||
        json['groomerCheckInNotes'] != null) {
      parsedCheckInRecord = GroomerCheckInRecord.fromJson(json);
    }

    GroomerMilestoneRecord? parsedMilestoneRecord;
    if (json['milestones'] is List) {
      parsedMilestoneRecord = GroomerMilestoneRecord.fromTimeline(
        json['milestones'] as List,
      );
    } else if (json['milestoneRecord'] is Map) {
      parsedMilestoneRecord = GroomerMilestoneRecord.fromJson(
        Map<String, dynamic>.from(json['milestoneRecord'] as Map),
      );
    } else if (json['bathCompleted'] != null ||
        json['groomingCompleted'] != null ||
        json['bathCompletedAt'] != null ||
        json['groomingCompletedAt'] != null ||
        json['bathNotes'] != null ||
        json['groomingNotes'] != null) {
      parsedMilestoneRecord = GroomerMilestoneRecord.fromJson(json);
    } else {
      final st = (json['status']?.toString() ?? '').toLowerCase();
      final stage = (json['serviceStage']?.toString() ??
              json['service_stage']?.toString() ??
              '')
          .toLowerCase();
      if (stage == 'ready_for_checkout' ||
          stage == 'checkout_completed' ||
          st == 'ready_for_checkout' ||
          st == 'completed') {
        parsedMilestoneRecord = const GroomerMilestoneRecord(
          bathCompleted: true,
          groomingCompleted: true,
          readyForCheckoutCompleted: true,
        );
      } else if (stage == 'grooming_completed' || st == 'grooming_completed') {
        parsedMilestoneRecord = const GroomerMilestoneRecord(
          bathCompleted: true,
          groomingCompleted: true,
        );
      } else if (stage == 'bath_completed' || st == 'bath_completed') {
        parsedMilestoneRecord = const GroomerMilestoneRecord(
          bathCompleted: true,
        );
      }
    }

    final pMedical = json['petMedicalNotes']?.toString() ??
        json['notesAllergies']?.toString() ??
        json['notes_allergies']?.toString() ??
        json['medicalNotes']?.toString() ??
        json['medical_notes']?.toString() ??
        (json['pet'] is Map
            ? (json['pet']['notesAllergies']?.toString() ??
                json['pet']['notes_allergies']?.toString() ??
                json['pet']['notes']?.toString())
            : null);

    return GroomerBooking(
      bookingId: parsedId,
      status: parsedStatus,
      bookingDate: json['bookingDate']?.toString() ?? json['date']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? '09:00 AM',
      endTime: json['endTime']?.toString() ?? '10:00 AM',
      petId: pId,
      petName: pName,
      breed: pBreed,
      profilePicture: pPic,
      userId: uId,
      customerName: cName,
      customerEmail: cEmail,
      customerMobile: cMobile,
      serviceId: sId,
      serviceName: sName,
      packageId: pkgId,
      packageName: pkgName,
      addOns: parsedAddOns,
      addOnIds: parsedAddOnIds,
      totalPrice: price,
      tipAmount: parsedTip,
      taxAmount: parsedTax,
      isPaid: parsedIsPaid,
      paymentStatus: parsedPaymentStatus,
      totalDurationMinutes: int.tryParse(json['totalDurationMinutes']?.toString() ?? '30') ?? 30,
      storeId: json['storeId']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString(),
      cancellationReason: json['cancellationReason']?.toString() ?? json['cancellation_reason']?.toString(),
      groomerId: gId,
      groomerName: (gName != null && gName.isNotEmpty) ? gName : null,
      groomerCode: gCode.isNotEmpty ? gCode : null,
      specialInstructions: cleanInstructions,
      checkInRecord: parsedCheckInRecord,
      petMedicalNotes: pMedical != null && pMedical.trim().isNotEmpty ? pMedical.trim() : null,
      milestoneRecord: parsedMilestoneRecord,
      serviceStage: (json['serviceStage'] ?? json['service_stage'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'bookingId': bookingId,
    'status': status,
    'bookingDate': bookingDate,
    'startTime': startTime,
    'endTime': endTime,
    'petId': petId,
    'petName': petName,
    'breed': breed,
    'profilePicture': profilePicture,
    'userId': userId,
    'customerName': customerName,
    'customerEmail': customerEmail,
    'customerMobile': customerMobile,
    'serviceId': serviceId,
    'serviceName': serviceName,
    'packageId': packageId,
    'packageName': packageName,
    'addOns': addOns,
    'addOnIds': addOnIds,
    'totalPrice': totalPrice,
    'tipAmount': tipAmount,
    'taxAmount': taxAmount,
    'isPaid': isPaid,
    'paymentStatus': paymentStatus,
    'totalDurationMinutes': totalDurationMinutes,
    'storeId': storeId,
    'createdAt': createdAt,
    'cancellationReason': cancellationReason,
    if (groomerId != null) 'groomerId': groomerId,
    if (groomerName != null) 'groomerName': groomerName,
    if (groomerCode != null) 'groomerCode': groomerCode,
    if (specialInstructions != null) 'specialInstructions': specialInstructions,
    if (checkInRecord != null) 'checkInRecord': checkInRecord!.toJson(),
    if (petMedicalNotes != null) 'petMedicalNotes': petMedicalNotes,
    if (milestoneRecord != null) 'milestoneRecord': milestoneRecord!.toJson(),
    if (serviceStage != null) 'serviceStage': serviceStage,
  };

  GroomerBooking copyWith({
    int? bookingId,
    String? status,
    String? bookingDate,
    String? startTime,
    String? endTime,
    int? petId,
    String? petName,
    String? breed,
    String? profilePicture,
    int? userId,
    String? customerName,
    String? customerEmail,
    String? customerMobile,
    int? serviceId,
    String? serviceName,
    int? packageId,
    String? packageName,
    List<String>? addOns,
    List<int>? addOnIds,
    double? totalPrice,
    double? tipAmount,
    double? taxAmount,
    bool? isPaid,
    String? paymentStatus,
    int? totalDurationMinutes,
    String? storeId,
    String? createdAt,
    String? cancellationReason,
    int? groomerId,
    String? groomerName,
    String? groomerCode,
    String? specialInstructions,
    GroomerCheckInRecord? checkInRecord,
    String? petMedicalNotes,
    GroomerMilestoneRecord? milestoneRecord,
    String? serviceStage,
  }) {
    return GroomerBooking(
      bookingId: bookingId ?? this.bookingId,
      status: status ?? this.status,
      bookingDate: bookingDate ?? this.bookingDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      petId: petId ?? this.petId,
      petName: petName ?? this.petName,
      breed: breed ?? this.breed,
      profilePicture: profilePicture ?? this.profilePicture,
      userId: userId ?? this.userId,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      customerMobile: customerMobile ?? this.customerMobile,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      packageId: packageId ?? this.packageId,
      packageName: packageName ?? this.packageName,
      addOns: addOns ?? this.addOns,
      addOnIds: addOnIds ?? this.addOnIds,
      totalPrice: totalPrice ?? this.totalPrice,
      tipAmount: tipAmount ?? this.tipAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      isPaid: isPaid ?? this.isPaid,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      totalDurationMinutes: totalDurationMinutes ?? this.totalDurationMinutes,
      storeId: storeId ?? this.storeId,
      createdAt: createdAt ?? this.createdAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      groomerId: groomerId ?? this.groomerId,
      groomerName: groomerName ?? this.groomerName,
      groomerCode: groomerCode ?? this.groomerCode,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      checkInRecord: checkInRecord ?? this.checkInRecord,
      petMedicalNotes: petMedicalNotes ?? this.petMedicalNotes,
      milestoneRecord: milestoneRecord ?? this.milestoneRecord,
      serviceStage: serviceStage ?? this.serviceStage,
    );
  }
}
