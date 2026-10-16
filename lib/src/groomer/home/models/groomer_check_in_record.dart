import 'package:flutter/foundation.dart';

/// Represents the intake checklist record completed by the groomer upon pet arrival.
/// Corresponds to POST /api/groomer-auth/bookings/:id/check-in contract.
@immutable
class GroomerCheckInRecord {
  final bool vaccinationVerified;
  final bool healthVerified;
  final bool customerRequestAcknowledged;
  final String? groomerCheckInNotes;
  final String? checkInTimestamp;
  final int? checkedInByGroomerId;

  const GroomerCheckInRecord({
    this.vaccinationVerified = false,
    this.healthVerified = false,
    this.customerRequestAcknowledged = false,
    this.groomerCheckInNotes,
    this.checkInTimestamp,
    this.checkedInByGroomerId,
  });

  /// True if both critical intake criteria (vaccination & health) were verified.
  bool get isFullyVerified => vaccinationVerified && healthVerified;

  /// True if the groomer entered intake notes.
  bool get hasNotes =>
      groomerCheckInNotes != null && groomerCheckInNotes!.trim().isNotEmpty;

  factory GroomerCheckInRecord.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic val) {
      if (val == null) return false;
      if (val is bool) return val;
      final str = val.toString().toLowerCase().trim();
      return str == 'true' || str == '1' || str == 'yes';
    }

    return GroomerCheckInRecord(
      vaccinationVerified: parseBool(
        json['vaccinationVerified'] ?? json['vaccination_verified'],
      ),
      healthVerified: parseBool(
        json['healthVerified'] ?? json['health_verified'],
      ),
      customerRequestAcknowledged: parseBool(
        json['customerRequestAcknowledged'] ??
            json['customer_request_acknowledged'],
      ),
      groomerCheckInNotes: (json['groomerCheckInNotes'] ??
              json['groomer_check_in_notes'] ??
              json['checkInNotes'] ??
              json['check_in_notes'] ??
              json['notes'])
          ?.toString()
          .trim(),
      checkInTimestamp: (json['checkInTimestamp'] ??
              json['check_in_timestamp'] ??
              json['timestamp'] ??
              json['createdAt'] ??
              json['created_at'])
          ?.toString(),
      checkedInByGroomerId: int.tryParse(
        (json['checkedInByGroomerId'] ??
                json['checked_in_by_groomer_id'] ??
                json['groomerId'] ??
                json['groomer_id'])
            ?.toString() ??
            '',
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'vaccinationVerified': vaccinationVerified,
        'healthVerified': healthVerified,
        'customerRequestAcknowledged': customerRequestAcknowledged,
        if (groomerCheckInNotes != null &&
            groomerCheckInNotes!.trim().isNotEmpty)
          'groomerCheckInNotes': groomerCheckInNotes!.trim(),
        if (checkInTimestamp != null && checkInTimestamp!.isNotEmpty)
          'checkInTimestamp': checkInTimestamp,
        if (checkedInByGroomerId != null)
          'checkedInByGroomerId': checkedInByGroomerId,
      };

  GroomerCheckInRecord copyWith({
    bool? vaccinationVerified,
    bool? healthVerified,
    bool? customerRequestAcknowledged,
    String? groomerCheckInNotes,
    String? checkInTimestamp,
    int? checkedInByGroomerId,
  }) {
    return GroomerCheckInRecord(
      vaccinationVerified: vaccinationVerified ?? this.vaccinationVerified,
      healthVerified: healthVerified ?? this.healthVerified,
      customerRequestAcknowledged:
          customerRequestAcknowledged ?? this.customerRequestAcknowledged,
      groomerCheckInNotes: groomerCheckInNotes ?? this.groomerCheckInNotes,
      checkInTimestamp: checkInTimestamp ?? this.checkInTimestamp,
      checkedInByGroomerId: checkedInByGroomerId ?? this.checkedInByGroomerId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroomerCheckInRecord &&
          runtimeType == other.runtimeType &&
          vaccinationVerified == other.vaccinationVerified &&
          healthVerified == other.healthVerified &&
          customerRequestAcknowledged == other.customerRequestAcknowledged &&
          groomerCheckInNotes == other.groomerCheckInNotes &&
          checkInTimestamp == other.checkInTimestamp &&
          checkedInByGroomerId == other.checkedInByGroomerId;

  @override
  int get hashCode => Object.hash(
        vaccinationVerified,
        healthVerified,
        customerRequestAcknowledged,
        groomerCheckInNotes,
        checkInTimestamp,
        checkedInByGroomerId,
      );
}
