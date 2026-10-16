import 'package:flutter/foundation.dart';

/// Represents service milestones completed during dog grooming (Bath Completed, Grooming Completed).
/// Corresponds to Step 7 of the Groomer Workflow.
@immutable
class GroomerMilestoneRecord {
  final bool bathCompleted;
  final String? bathCompletedAt;
  final String? bathNotes;
  final bool groomingCompleted;
  final String? groomingCompletedAt;
  final String? groomingNotes;
  final int? completedByGroomerId;

  const GroomerMilestoneRecord({
    this.bathCompleted = false,
    this.bathCompletedAt,
    this.bathNotes,
    this.groomingCompleted = false,
    this.groomingCompletedAt,
    this.groomingNotes,
    this.completedByGroomerId,
  });

  bool get hasAnyMilestone => bathCompleted || groomingCompleted;
  bool get isBathDone => bathCompleted;
  bool get isGroomingDone => groomingCompleted;
  bool get areAllMilestonesDone => bathCompleted && groomingCompleted;

  factory GroomerMilestoneRecord.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic val) {
      if (val == null) return false;
      if (val is bool) return val;
      final str = val.toString().trim().toLowerCase();
      return str == 'true' || str == '1' || str == 'yes';
    }

    int? parseInt(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      return int.tryParse(val.toString());
    }

    return GroomerMilestoneRecord(
      bathCompleted: parseBool(json['bathCompleted'] ?? json['bath_completed'] ?? json['isBathCompleted']),
      bathCompletedAt: json['bathCompletedAt']?.toString() ??
          json['bath_completed_at']?.toString() ??
          json['bathTimestamp']?.toString() ??
          json['bath_timestamp']?.toString(),
      bathNotes: json['bathNotes']?.toString() ?? json['bath_notes']?.toString(),
      groomingCompleted: parseBool(
        json['groomingCompleted'] ?? json['grooming_completed'] ?? json['isGroomingCompleted'],
      ),
      groomingCompletedAt: json['groomingCompletedAt']?.toString() ??
          json['grooming_completed_at']?.toString() ??
          json['groomingTimestamp']?.toString() ??
          json['grooming_timestamp']?.toString(),
      groomingNotes: json['groomingNotes']?.toString() ?? json['grooming_notes']?.toString(),
      completedByGroomerId: parseInt(
        json['completedByGroomerId'] ?? json['completed_by_groomer_id'] ?? json['groomerId'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bathCompleted': bathCompleted,
      if (bathCompletedAt != null) 'bathCompletedAt': bathCompletedAt,
      if (bathNotes != null && bathNotes!.trim().isNotEmpty) 'bathNotes': bathNotes!.trim(),
      'groomingCompleted': groomingCompleted,
      if (groomingCompletedAt != null) 'groomingCompletedAt': groomingCompletedAt,
      if (groomingNotes != null && groomingNotes!.trim().isNotEmpty)
        'groomingNotes': groomingNotes!.trim(),
      if (completedByGroomerId != null) 'completedByGroomerId': completedByGroomerId,
    };
  }

  GroomerMilestoneRecord copyWith({
    bool? bathCompleted,
    String? bathCompletedAt,
    String? bathNotes,
    bool? groomingCompleted,
    String? groomingCompletedAt,
    String? groomingNotes,
    int? completedByGroomerId,
  }) {
    return GroomerMilestoneRecord(
      bathCompleted: bathCompleted ?? this.bathCompleted,
      bathCompletedAt: bathCompletedAt ?? this.bathCompletedAt,
      bathNotes: bathNotes ?? this.bathNotes,
      groomingCompleted: groomingCompleted ?? this.groomingCompleted,
      groomingCompletedAt: groomingCompletedAt ?? this.groomingCompletedAt,
      groomingNotes: groomingNotes ?? this.groomingNotes,
      completedByGroomerId: completedByGroomerId ?? this.completedByGroomerId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroomerMilestoneRecord &&
          runtimeType == other.runtimeType &&
          bathCompleted == other.bathCompleted &&
          bathCompletedAt == other.bathCompletedAt &&
          bathNotes == other.bathNotes &&
          groomingCompleted == other.groomingCompleted &&
          groomingCompletedAt == other.groomingCompletedAt &&
          groomingNotes == other.groomingNotes &&
          completedByGroomerId == other.completedByGroomerId;

  @override
  int get hashCode => Object.hash(
        bathCompleted,
        bathCompletedAt,
        bathNotes,
        groomingCompleted,
        groomingCompletedAt,
        groomingNotes,
        completedByGroomerId,
      );
}
