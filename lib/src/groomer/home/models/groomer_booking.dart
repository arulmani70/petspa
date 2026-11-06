import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shear_heaven_pet_spa/src/bookings/utils/booking_date_utils.dart';
import 'package:shear_heaven_pet_spa/src/common/common.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_check_in_record.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_milestone_record.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/utils/groomer_milestone_resolver.dart';

/// Represents an individual task/milestone in the service progress workflow.
/// Corresponds to the Service Progress API contract:
/// PUT /api/common/groomer/bookings/:id/service-progress
/// POST /api/common/groomer/bookings/:id/service-progress/skip
@immutable
class ServiceProgressItem {
  final String taskKey;
  final String? taskName;
  final String? label;
  final int percent;
  final String status;
  final bool skipAllowed;
  final int durationMinutes;
  final String? notes;
  final String? reason;
  final String? updatedAt;
  final int? assignedGroomerId;
  final String? assignedGroomerName;
  final String? assignedGroomerCode;
  final int? primaryGroomerId;
  final String? primaryGroomerName;
  final double? lineServiceAmount;
  final bool assignable;
  final int? sortOrder;
  final String? taskType;
  final String? milestoneKey;
  final String? packageGroupKey;
  final String? packageGroupLabel;

  const ServiceProgressItem({
    required this.taskKey,
    this.taskName,
    this.label,
    this.percent = 0,
    this.status = 'pending',
    this.skipAllowed = true,
    this.durationMinutes = 0,
    this.notes,
    this.reason,
    this.updatedAt,
    this.assignedGroomerId,
    this.assignedGroomerName,
    this.assignedGroomerCode,
    this.primaryGroomerId,
    this.primaryGroomerName,
    this.lineServiceAmount,
    this.assignable = true,
    this.sortOrder,
    this.taskType,
    this.milestoneKey,
    this.packageGroupKey,
    this.packageGroupLabel,
  });

  bool get isCompleted => percent >= 100 || status.toLowerCase() == 'completed';
  bool get isSkipped => status.toLowerCase() == 'skipped';
  bool get isInProgress =>
      !isCompleted &&
      !isSkipped &&
      (percent > 0 || status.toLowerCase() == 'in_progress');
  bool get isPending => !isCompleted && !isSkipped && !isInProgress;

  String get displayName {
    if (taskName != null && taskName!.trim().isNotEmpty) return taskName!.trim();
    if (label != null && label!.trim().isNotEmpty) return label!.trim();
    var cleaned = taskKey.replaceAll(RegExp(r'^svc-[0-9]+-'), '');
    cleaned = cleaned.replaceAll('_completed', '').replaceAll('_', ' ').replaceAll('-', ' ');
    if (cleaned.isEmpty) return 'Service';
    return '${cleaned[0].toUpperCase()}${cleaned.substring(1)}';
  }

  bool get isAssigned => assignedGroomerId != null && assignedGroomerId! > 0;

  factory ServiceProgressItem.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val, {int defaultValue = 0}) {
      if (val == null) return defaultValue;
      if (val is int) return val;
      return int.tryParse(val.toString()) ?? defaultValue;
    }

    int? parseIntNullable(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      return int.tryParse(val.toString());
    }

    double? parseDoubleNullable(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    bool parseBool(dynamic val, {bool defaultValue = true}) {
      if (val == null) return defaultValue;
      if (val is bool) return val;
      final str = val.toString().trim().toLowerCase();
      if (str == 'false' || str == '0' || str == 'no') return false;
      return str == 'true' || str == '1' || str == 'yes';
    }

    final p = parseInt(json['percent'] ?? json['percentage'] ?? json['progress']);
    String st = (json['status'] ?? '').toString().trim().toLowerCase();
    if (st.isEmpty) {
      if (p >= 100) {
        st = 'completed';
      } else if (p > 0) {
        st = 'in_progress';
      } else {
        st = 'pending';
      }
    }

    final rawLabel = json['label']?.toString() ??
        json['taskName']?.toString() ??
        json['name']?.toString() ??
        json['title']?.toString();

    return ServiceProgressItem(
      taskKey: (json['taskKey'] ?? json['key'] ?? json['milestoneKey'] ?? '').toString(),
      taskName: rawLabel,
      label: rawLabel,
      percent: p,
      status: st,
      skipAllowed: parseBool(json['skipAllowed'] ?? json['canSkip'], defaultValue: true),
      durationMinutes: parseInt(json['durationMinutes'] ?? json['duration']),
      notes: json['notes']?.toString(),
      reason: json['reason']?.toString() ?? json['skipReason']?.toString(),
      updatedAt: json['updatedAt']?.toString() ?? json['timestamp']?.toString(),
      assignedGroomerId: parseIntNullable(json['assignedGroomerId'] ?? json['groomerId']),
      assignedGroomerName: json['assignedGroomerName']?.toString() ?? json['groomerName']?.toString(),
      assignedGroomerCode: json['assignedGroomerCode']?.toString() ?? json['groomerCode']?.toString(),
      primaryGroomerId: parseIntNullable(json['primaryGroomerId']),
      primaryGroomerName: json['primaryGroomerName']?.toString(),
      lineServiceAmount: parseDoubleNullable(json['lineServiceAmount'] ?? json['amount'] ?? json['price']),
      assignable: parseBool(json['assignable'], defaultValue: true),
      sortOrder: parseIntNullable(json['sortOrder']),
      taskType: json['taskType']?.toString(),
      milestoneKey: json['milestoneKey']?.toString(),
      packageGroupKey: json['packageGroupKey']?.toString(),
      packageGroupLabel: json['packageGroupLabel']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'taskKey': taskKey,
        if (taskName != null) 'taskName': taskName,
        if (label != null) 'label': label,
        'percent': percent,
        'status': status,
        'skipAllowed': skipAllowed,
        'durationMinutes': durationMinutes,
        if (notes != null) 'notes': notes,
        if (reason != null) 'reason': reason,
        if (updatedAt != null) 'updatedAt': updatedAt,
        if (assignedGroomerId != null) 'assignedGroomerId': assignedGroomerId,
        if (assignedGroomerName != null) 'assignedGroomerName': assignedGroomerName,
        if (assignedGroomerCode != null) 'assignedGroomerCode': assignedGroomerCode,
        if (primaryGroomerId != null) 'primaryGroomerId': primaryGroomerId,
        if (primaryGroomerName != null) 'primaryGroomerName': primaryGroomerName,
        if (lineServiceAmount != null) 'lineServiceAmount': lineServiceAmount,
        'assignable': assignable,
        if (sortOrder != null) 'sortOrder': sortOrder,
        if (taskType != null) 'taskType': taskType,
        if (milestoneKey != null) 'milestoneKey': milestoneKey,
        if (packageGroupKey != null) 'packageGroupKey': packageGroupKey,
        if (packageGroupLabel != null) 'packageGroupLabel': packageGroupLabel,
      };

  ServiceProgressItem copyWith({
    String? taskKey,
    String? taskName,
    String? label,
    int? percent,
    String? status,
    bool? skipAllowed,
    int? durationMinutes,
    String? notes,
    String? reason,
    String? updatedAt,
    int? assignedGroomerId,
    String? assignedGroomerName,
    String? assignedGroomerCode,
    int? primaryGroomerId,
    String? primaryGroomerName,
    double? lineServiceAmount,
    bool? assignable,
    int? sortOrder,
    String? taskType,
    String? milestoneKey,
    String? packageGroupKey,
    String? packageGroupLabel,
  }) {
    return ServiceProgressItem(
      taskKey: taskKey ?? this.taskKey,
      taskName: taskName ?? this.taskName,
      label: label ?? this.label,
      percent: percent ?? this.percent,
      status: status ?? this.status,
      skipAllowed: skipAllowed ?? this.skipAllowed,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      notes: notes ?? this.notes,
      reason: reason ?? this.reason,
      updatedAt: updatedAt ?? this.updatedAt,
      assignedGroomerId: assignedGroomerId ?? this.assignedGroomerId,
      assignedGroomerName: assignedGroomerName ?? this.assignedGroomerName,
      assignedGroomerCode: assignedGroomerCode ?? this.assignedGroomerCode,
      primaryGroomerId: primaryGroomerId ?? this.primaryGroomerId,
      primaryGroomerName: primaryGroomerName ?? this.primaryGroomerName,
      lineServiceAmount: lineServiceAmount ?? this.lineServiceAmount,
      assignable: assignable ?? this.assignable,
      sortOrder: sortOrder ?? this.sortOrder,
      taskType: taskType ?? this.taskType,
      milestoneKey: milestoneKey ?? this.milestoneKey,
      packageGroupKey: packageGroupKey ?? this.packageGroupKey,
      packageGroupLabel: packageGroupLabel ?? this.packageGroupLabel,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceProgressItem &&
          runtimeType == other.runtimeType &&
          taskKey == other.taskKey &&
          percent == other.percent &&
          status == other.status &&
          skipAllowed == other.skipAllowed &&
          durationMinutes == other.durationMinutes &&
          notes == other.notes &&
          reason == other.reason &&
          assignedGroomerId == other.assignedGroomerId &&
          assignedGroomerName == other.assignedGroomerName &&
          lineServiceAmount == other.lineServiceAmount &&
          assignable == other.assignable;

  @override
  int get hashCode => Object.hash(
        taskKey,
        percent,
        status,
        skipAllowed,
        durationMinutes,
        notes,
        reason,
        assignedGroomerId,
        assignedGroomerName,
        lineServiceAmount,
        assignable,
      );
}


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
  final List<String> bookedServices;
  final List<ServiceProgressItem> serviceProgress;
  final bool isPreferredGroomer;
  final List<Map<String, dynamic>> reassignmentHistory;
  final String? primaryGroomerName;
  final int? primaryGroomerId;
  final List<Map<String, dynamic>> serviceAssignmentActivity;

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
    this.bookedServices = const [],
    this.serviceProgress = const [],
    this.isPreferredGroomer = false,
    this.reassignmentHistory = const [],
    this.primaryGroomerName,
    this.primaryGroomerId,
    this.serviceAssignmentActivity = const [],
  });

  String get effectivePrimaryGroomerName {
    if (primaryGroomerName != null && primaryGroomerName!.trim().isNotEmpty) {
      return primaryGroomerName!.trim();
    }
    return effectiveGroomerName;
  }

  int? get effectivePrimaryGroomerId => primaryGroomerId ?? groomerId;

  /// Whether this booking or any of its individual services/tasks is assigned to the specified groomer.
  /// Matches canonical groomer ID, groomerCode, groomerName, primary groomer,
  /// serviceProgress line items, serviceAssignmentActivity, or reassignmentHistory.
  bool isAssignedToGroomer(
    int? targetGroomerId, {
    String? targetGroomerCode,
    String? targetGroomerName,
  }) {
    final hasId = targetGroomerId != null && targetGroomerId > 0;
    final hasCode = targetGroomerCode != null && targetGroomerCode.trim().isNotEmpty;
    final hasName = targetGroomerName != null && targetGroomerName.trim().isNotEmpty;

    if (!hasId && !hasCode && !hasName) return false;

    final targetCodeUpper = hasCode ? targetGroomerCode.trim().toUpperCase() : null;
    final targetNameLower = hasName ? targetGroomerName.trim().toLowerCase() : null;

    final canonTarget = hasId
        ? (BookingDateUtils.resolveCanonicalGroomerId(
            targetGroomerId,
            groomerCode: targetGroomerCode,
            groomerName: targetGroomerName,
          ) ?? targetGroomerId)
        : null;

    // 1. Direct booking groomerId
    if (hasId && groomerId != null && groomerId! > 0) {
      if (groomerId == targetGroomerId) return true;
      final canonG = BookingDateUtils.resolveCanonicalGroomerId(
        groomerId,
        groomerCode: groomerCode,
        groomerName: groomerName,
      );
      if (canonTarget != null && canonG != null && canonG == canonTarget) return true;
    }

    // 2. Primary groomer ID
    if (hasId && primaryGroomerId != null && primaryGroomerId! > 0) {
      if (primaryGroomerId == targetGroomerId) return true;
      final canonPrimary = BookingDateUtils.resolveCanonicalGroomerId(
        primaryGroomerId,
        groomerName: primaryGroomerName,
      );
      if (canonTarget != null && canonPrimary != null && canonPrimary == canonTarget) return true;
    }

    // 3. Groomer Code match
    if (targetCodeUpper != null && groomerCode != null && groomerCode!.trim().isNotEmpty) {
      if (groomerCode!.trim().toUpperCase() == targetCodeUpper) return true;
    }

    // 4. Groomer Name match
    if (targetNameLower != null) {
      final gName = (groomerName ?? effectiveGroomerName).trim().toLowerCase();
      if (gName.isNotEmpty &&
          (gName == targetNameLower ||
              gName.contains(targetNameLower) ||
              targetNameLower.contains(gName))) {
        return true;
      }
      final pName = (primaryGroomerName ?? '').trim().toLowerCase();
      if (pName.isNotEmpty &&
          (pName == targetNameLower ||
              pName.contains(targetNameLower) ||
              targetNameLower.contains(pName))) {
        return true;
      }
    }

    // 5. Individual task assignments in serviceProgress
    for (final task in serviceProgress) {
      if (hasId && task.assignedGroomerId != null && task.assignedGroomerId! > 0) {
        if (task.assignedGroomerId == targetGroomerId) return true;
        final canonTask = BookingDateUtils.resolveCanonicalGroomerId(
          task.assignedGroomerId,
          groomerCode: task.assignedGroomerCode,
          groomerName: task.assignedGroomerName,
        );
        if (canonTarget != null && canonTask != null && canonTask == canonTarget) return true;
      }
      if (hasId && task.primaryGroomerId != null && task.primaryGroomerId! > 0) {
        if (task.primaryGroomerId == targetGroomerId) return true;
        final canonTaskPrimary = BookingDateUtils.resolveCanonicalGroomerId(
          task.primaryGroomerId,
          groomerName: task.primaryGroomerName,
        );
        if (canonTarget != null && canonTaskPrimary != null && canonTaskPrimary == canonTarget) return true;
      }
      if (targetCodeUpper != null &&
          task.assignedGroomerCode != null &&
          task.assignedGroomerCode!.trim().isNotEmpty) {
        if (task.assignedGroomerCode!.trim().toUpperCase() == targetCodeUpper) return true;
      }
      if (targetNameLower != null) {
        final tName = (task.assignedGroomerName ?? '').trim().toLowerCase();
        if (tName.isNotEmpty &&
            (tName == targetNameLower ||
                tName.contains(targetNameLower) ||
                targetNameLower.contains(tName))) {
          return true;
        }
        final tpName = (task.primaryGroomerName ?? '').trim().toLowerCase();
        if (tpName.isNotEmpty &&
            (tpName == targetNameLower ||
                tpName.contains(targetNameLower) ||
                targetNameLower.contains(tpName))) {
          return true;
        }
      }
    }

    // 6. Service assignment activity
    for (final act in serviceAssignmentActivity) {
      final actGid = int.tryParse(act['groomerId']?.toString() ?? '');
      if (hasId && actGid != null && actGid > 0) {
        if (actGid == targetGroomerId) return true;
        final canonAct = BookingDateUtils.resolveCanonicalGroomerId(
          actGid,
          groomerCode: act['groomerCode']?.toString(),
          groomerName: act['groomerName']?.toString(),
        );
        if (canonTarget != null && canonAct != null && canonAct == canonTarget) return true;
      }
      if (targetNameLower != null && act['groomerName'] != null) {
        final aName = act['groomerName'].toString().trim().toLowerCase();
        if (aName.isNotEmpty &&
            (aName == targetNameLower ||
                aName.contains(targetNameLower) ||
                targetNameLower.contains(aName))) {
          return true;
        }
      }
    }

    // 7. Reassignment history
    for (final hist in reassignmentHistory) {
      final toGid = int.tryParse(hist['toGroomerId']?.toString() ?? '');
      if (hasId && toGid != null && toGid > 0) {
        if (toGid == targetGroomerId) return true;
        final canonHist = BookingDateUtils.resolveCanonicalGroomerId(
          toGid,
          groomerCode: hist['toGroomerCode']?.toString(),
          groomerName: hist['toGroomerName']?.toString(),
        );
        if (canonTarget != null && canonHist != null && canonHist == canonTarget) return true;
      }
      if (targetNameLower != null && hist['toGroomerName'] != null) {
        final toName = hist['toGroomerName'].toString().trim().toLowerCase();
        if (toName.isNotEmpty &&
            (toName == targetNameLower ||
                toName.contains(targetNameLower) ||
                targetNameLower.contains(toName))) {
          return true;
        }
      }
    }

    return false;
  }

  bool get isGroomerAssignmentLocked =>
      isReadyForCheckout ||
      status.toLowerCase() == 'completed' ||
      status.toLowerCase() == 'ready_for_checkout' ||
      serviceStage?.toLowerCase() == 'ready_for_checkout' ||
      serviceStage?.toLowerCase() == 'checkout_completed';

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
  /// Whether the appointment is scheduled for today in the store/appointment calendar.
  bool isScheduledForToday({DateTime? referenceDate, Duration? timeZoneOffset}) {
    if (bookingDate.isEmpty) return false;
    return BookingDateUtils.isBookingDateToday(
      bookingDate,
      referenceDate: referenceDate,
      timeZoneOffset: timeZoneOffset,
    );
  }

  /// Whether current store time is strictly before the appointment's scheduled booking date.
  bool isBeforeScheduledDate({DateTime? referenceDate, Duration? timeZoneOffset}) {
    if (bookingDate.isEmpty) return false;
    return BookingDateUtils.isBeforeBookingDate(
      bookingDate,
      referenceDate: referenceDate,
      timeZoneOffset: timeZoneOffset,
    );
  }

  /// Whether current store time is strictly after the appointment's scheduled booking date.
  bool isAfterScheduledDate({DateTime? referenceDate, Duration? timeZoneOffset}) {
    if (bookingDate.isEmpty) return false;
    return BookingDateUtils.isAfterBookingDate(
      bookingDate,
      referenceDate: referenceDate,
      timeZoneOffset: timeZoneOffset,
    );
  }

  /// Whether this unaccepted/pending appointment has reached or passed its scheduled start time.
  bool get isExpiredPending {
    final sLower = status.toLowerCase();
    if (sLower != 'pending' && sLower != 'unaccepted' && sLower != 'awaiting_acceptance') {
      return false;
    }
    if (ServicesLocator.isBookingCancellationManagerRegistered) {
      return ServicesLocator.bookingCancellationManager.isScheduledStartTimeReached(
        bookingDate,
        startTime,
      );
    }
    return false;
  }

  /// Whether check-in is permitted for this booking.
  /// Rule: Check-in is allowed ONLY on the scheduled booking date,
  /// subject to existing status validation rules.
  bool canCheckIn({DateTime? referenceDate, Duration? timeZoneOffset}) {
    // 1. Must be on the scheduled booking date in the store/appointment timezone
    if (!isScheduledForToday(referenceDate: referenceDate, timeZoneOffset: timeZoneOffset)) {
      return false;
    }

    // 2. Already checked in, completed, or cancelled bookings cannot be checked in
    if (isCheckedIn || isCompleted) return false;
    final sLower = status.toLowerCase();
    if (sLower == 'cancelled' || sLower == 'rejected' || sLower == 'pending') {
      return false;
    }

    return true;
  }

  bool get hasCheckInRecord => checkInRecord != null;
  bool get hasPetMedicalNotes =>
      petMedicalNotes != null && petMedicalNotes!.trim().isNotEmpty;

  // ── Step 7 Dynamic Service Milestone helpers ─────────────────────────────

  /// Complete list of service and add-on names booked for this appointment.
  List<String> get allBookedServiceNames {
    final names = <String>[];
    if (serviceName.isNotEmpty && serviceName != 'Service') {
      names.add(serviceName);
    }
    if (packageName != null && packageName!.trim().isNotEmpty) {
      names.add(packageName!.trim());
    }
    names.addAll(addOns);
    names.addAll(bookedServices);
    return names;
  }

  /// Whether customer booked a nail service (Nail Cut, Nail Trimming, Nail Grinding).
  bool get hasNailService {
    if (serviceId == 14 || addOnIds.contains(1) || addOnIds.contains(14)) return true;
    return allBookedServiceNames.any((s) {
      final l = s.toLowerCase();
      return l.contains('nail') || l.contains('paw');
    });
  }

  /// Whether customer booked a teeth or dental service (Teeth Cleaning, Teeth Brushing).
  bool get hasTeethService {
    if (serviceId == 16 || addOnIds.contains(2) || addOnIds.contains(6)) return true;
    return allBookedServiceNames.any((s) {
      final l = s.toLowerCase();
      return l.contains('teeth') || l.contains('dental');
    });
  }

  /// Whether customer booked a medicated shampoo or treatment service.
  bool get hasMedicatedService {
    if (serviceId == 17 || serviceId == 20 || addOnIds.contains(4) || addOnIds.contains(7)) return true;
    return allBookedServiceNames.any((s) {
      final l = s.toLowerCase();
      return l.contains('medicated') || l.contains('flea') || l.contains('skin care');
    });
  }

  /// Whether customer booked an ear cleaning service.
  bool get hasEarService {
    if (serviceId == 15) return true;
    return allBookedServiceNames.any((s) {
      final l = s.toLowerCase();
      return l.contains('ear');
    });
  }

  /// Whether customer booked a de-shedding treatment.
  bool get hasDeSheddingService {
    if (serviceId == 19 || addOnIds.contains(5)) return true;
    return allBookedServiceNames.any((s) {
      final l = s.toLowerCase();
      return l.contains('de-shed') || l.contains('deshed') || l.contains('furminator');
    });
  }

  /// Dynamically resolved list of required milestone keys for this booking based on selected services.
  List<String> get requiredMilestones => GroomerMilestoneResolver.resolveRequiredMilestones(
        serviceId: serviceId,
        serviceName: serviceName,
        packageId: packageId,
        packageName: packageName,
        addOnIds: addOnIds,
        addOns: addOns,
        bookedServices: bookedServices,
      );

  bool get requiresBath => requiredMilestones.contains(GroomerMilestoneResolver.bathMilestone);
  bool get requiresGrooming => requiredMilestones.contains(GroomerMilestoneResolver.groomingMilestone);


  /// Total consumed duration in minutes, preserving the duration of skipped milestones.
  int get consumedDurationMinutes {
    if (serviceProgress.isEmpty) {
      return (isCompleted || isReadyForCheckout) ? totalDurationMinutes : 0;
    }
    return serviceProgress
        .where((task) => task.isCompleted || task.isSkipped || task.isInProgress)
        .fold<int>(0, (sum, task) => sum + task.durationMinutes);
  }

  /// Locates the [ServiceProgressItem] corresponding to a task/milestone key.
  ServiceProgressItem? getServiceProgressForTask(String key) {
    if (serviceProgress.isEmpty) return null;
    final exact = serviceProgress.where((p) => p.taskKey.toLowerCase() == key.toLowerCase());
    if (exact.isNotEmpty) return exact.first;

    final norm = key.replaceAll('_completed', '').replaceAll('_', '').replaceAll('-', '').toLowerCase();
    for (final p in serviceProgress) {
      final pNorm = p.taskKey.replaceAll('_completed', '').replaceAll('_', '').replaceAll('-', '').toLowerCase();
      if (pNorm == norm || pNorm.contains(norm) || norm.contains(pNorm)) {
        return p;
      }
    }
    return null;
  }

  /// Current progress percentage (0-100) for a specific task/milestone.
  int getProgressPercentForTask(String key) {
    final item = getServiceProgressForTask(key);
    if (item != null) return item.percent;
    if (isMilestoneDone(key)) return 100;
    return 0;
  }

  /// Whether a specific milestone or task has been marked skipped.
  bool isTaskSkipped(String key) {
    final item = getServiceProgressForTask(key);
    return item?.isSkipped ?? false;
  }

  /// Resolves the canonical backend taskKey for a given milestone.
  String resolveTaskKey(String milestoneKey) {
    final item = getServiceProgressForTask(milestoneKey);
    if (item != null && item.taskKey.isNotEmpty) return item.taskKey;

    if (milestoneKey == 'bath_completed' || milestoneKey == 'bath') {
      return 'svc-1-bath';
    }
    if (milestoneKey == 'grooming_completed' || milestoneKey == 'grooming') {
      return 'svc-2-grooming';
    }
    return milestoneKey;
  }

  bool isMilestoneDone(String milestoneKey) {
    if (isTaskSkipped(milestoneKey)) return true;
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

  /// Whether this booking can show the Skip option on the appointment card.
  /// Displayed immediately after check-in is completed, and hidden before check-in or
  /// once ready for checkout, completed, cancelled, or all milestones are already done.
  bool get canShowSkipOption {
    if (!isCheckedIn) return false;
    final sLower = status.toLowerCase();
    if (sLower == 'ready_for_checkout' || isReadyForCheckout) return false;
    if (sLower == 'completed' || isCompleted) return false;
    if (sLower == 'cancelled' || sLower == 'rejected' || sLower == 'pending') return false;
    if (bookingId <= 0) return false;
    if (areRequiredMilestonesCompleted) return false;
    return true;
  }

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
    if (json['pet'] is Map) {
      final petMap = json['pet'] as Map;
      pName = petMap['petName']?.toString() ?? petMap['name']?.toString() ?? 'Pet';
      pBreed = petMap['breed']?.toString() ?? petMap['petBreed']?.toString() ?? '';
      pPic = PetImageHelper.extractPetPhoto(petMap);
      pId ??= int.tryParse(petMap['id']?.toString() ?? petMap['petId']?.toString() ?? '');
    } else {
      pName = json['petName']?.toString() ??
          json['pet_name']?.toString() ??
          'Pet';
      pBreed = json['breed']?.toString() ??
          json['petBreed']?.toString() ??
          json['pet_breed']?.toString() ??
          '';
      pPic = PetImageHelper.extractPetPhoto(json);
    }

    if (pPic == null || pPic.isEmpty) {
      pPic = PetImageHelper.extractPetPhoto(json);
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

    // Parse Multiple Booked Services (if present)
    List<String> parsedBookedServices = [];
    if (json['bookedServices'] is List) {
      parsedBookedServices = (json['bookedServices'] as List)
          .map((e) => e is Map ? (e['name'] ?? e['serviceName'] ?? '').toString() : e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (json['services'] is List) {
      parsedBookedServices = (json['services'] as List)
          .map((e) => e is Map ? (e['name'] ?? e['serviceName'] ?? '').toString() : e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
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


    // Parse Service Progress List
    final List<ServiceProgressItem> parsedServiceProgress = [];
    final rawServiceProgress = json['serviceProgress'] ?? json['service_progress'];
    if (rawServiceProgress is List) {
      for (final sp in rawServiceProgress) {
        if (sp is Map) {
          parsedServiceProgress.add(
            ServiceProgressItem.fromJson(Map<String, dynamic>.from(sp)),
          );
        }
      }
    }

    // Parse Preferred Groomer restriction
    bool parsedIsPreferredGroomer = false;
    if (json['isPreferredGroomer'] != null) {
      final val = json['isPreferredGroomer'];
      parsedIsPreferredGroomer = val == true || val.toString().toLowerCase() == 'true' || val == 1 || val.toString() == '1';
    } else if (json['is_preferred_groomer'] != null) {
      final val = json['is_preferred_groomer'];
      parsedIsPreferredGroomer = val == true || val.toString().toLowerCase() == 'true' || val == 1 || val.toString() == '1';
    } else if (json['preferredGroomer'] != null) {
      final val = json['preferredGroomer'];
      if (val is bool) {
        parsedIsPreferredGroomer = val;
      } else if (val is Map) {
        parsedIsPreferredGroomer = true;
      } else {
        parsedIsPreferredGroomer = val.toString().toLowerCase() == 'true';
      }
    } else if (json['hasPreferredGroomer'] != null) {
      final val = json['hasPreferredGroomer'];
      parsedIsPreferredGroomer = val == true || val.toString().toLowerCase() == 'true';
    } else if (json['preferredGroomerSelected'] != null) {
      final val = json['preferredGroomerSelected'];
      parsedIsPreferredGroomer = val == true || val.toString().toLowerCase() == 'true';
    }

    // Parse Reassignment History
    final List<Map<String, dynamic>> parsedReassignmentHistory = [];
    final rawHistory = json['reassignmentHistory'] ?? json['reassignment_history'];
    if (rawHistory is List) {
      for (final item in rawHistory) {
        if (item is Map) {
          parsedReassignmentHistory.add(Map<String, dynamic>.from(item));
        }
      }
    }

    // Parse Primary Groomer and Service Assignment Activity
    String? parsedPrimaryGroomerName;
    int? parsedPrimaryGroomerId;
    if (json['bookingPrimaryGroomer'] is Map) {
      final bpg = json['bookingPrimaryGroomer'] as Map;
      parsedPrimaryGroomerName = bpg['primaryGroomerName']?.toString();
      parsedPrimaryGroomerId = int.tryParse(bpg['primaryGroomerDbId']?.toString() ?? bpg['catalogGroomerId']?.toString() ?? '');
      if (bpg['petGroomerPreferenceLocked'] == true || bpg['petPreferredGroomerId'] != null) {
        parsedIsPreferredGroomer = true;
      }
    }
    parsedPrimaryGroomerName ??= json['primaryGroomerName']?.toString() ?? json['primary_groomer_name']?.toString() ?? gName;
    parsedPrimaryGroomerId ??= int.tryParse(json['primaryGroomerId']?.toString() ?? json['primary_groomer_id']?.toString() ?? '') ?? gId;

    final List<Map<String, dynamic>> parsedServiceAssignmentActivity = [];
    final rawActivity = json['serviceAssignmentActivity'] ?? json['service_assignment_activity'];
    if (rawActivity is List) {
      for (final item in rawActivity) {
        if (item is Map) {
          parsedServiceAssignmentActivity.add(Map<String, dynamic>.from(item));
        }
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
      bookingDate: json['bookingDate']?.toString() ??
          json['booking_date']?.toString() ??
          json['BookingDate']?.toString() ??
          json['date']?.toString() ??
          json['appointmentDate']?.toString() ??
          json['appointment_date']?.toString() ??
          '',
      startTime: json['startTime']?.toString() ??
          json['start_time']?.toString() ??
          json['time']?.toString() ??
          json['slot']?.toString() ??
          json['appointmentTime']?.toString() ??
          json['appointment_time']?.toString() ??
          '09:00 AM',
      endTime: json['endTime']?.toString() ??
          json['end_time']?.toString() ??
          '10:00 AM',
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
      bookedServices: parsedBookedServices,
      serviceProgress: parsedServiceProgress,
      isPreferredGroomer: parsedIsPreferredGroomer,
      reassignmentHistory: parsedReassignmentHistory,
      primaryGroomerName: parsedPrimaryGroomerName,
      primaryGroomerId: parsedPrimaryGroomerId,
      serviceAssignmentActivity: parsedServiceAssignmentActivity,
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
    if (bookedServices.isNotEmpty) 'bookedServices': bookedServices,
    if (serviceProgress.isNotEmpty) 'serviceProgress': serviceProgress.map((e) => e.toJson()).toList(),
    'isPreferredGroomer': isPreferredGroomer,
    'preferredGroomer': isPreferredGroomer,
    if (reassignmentHistory.isNotEmpty) 'reassignmentHistory': reassignmentHistory,
    if (primaryGroomerName != null) 'primaryGroomerName': primaryGroomerName,
    if (primaryGroomerId != null) 'primaryGroomerId': primaryGroomerId,
    if (serviceAssignmentActivity.isNotEmpty) 'serviceAssignmentActivity': serviceAssignmentActivity,
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
    List<String>? bookedServices,
    List<ServiceProgressItem>? serviceProgress,
    bool? isPreferredGroomer,
    List<Map<String, dynamic>>? reassignmentHistory,
    String? primaryGroomerName,
    int? primaryGroomerId,
    List<Map<String, dynamic>>? serviceAssignmentActivity,
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
      bookedServices: bookedServices ?? this.bookedServices,
      serviceProgress: serviceProgress ?? this.serviceProgress,
      isPreferredGroomer: isPreferredGroomer ?? this.isPreferredGroomer,
      reassignmentHistory: reassignmentHistory ?? this.reassignmentHistory,
      primaryGroomerName: primaryGroomerName ?? this.primaryGroomerName,
      primaryGroomerId: primaryGroomerId ?? this.primaryGroomerId,
      serviceAssignmentActivity: serviceAssignmentActivity ?? this.serviceAssignmentActivity,
    );
  }
}
