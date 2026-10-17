import 'package:flutter/foundation.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/store_milestone_config.dart';

/// Represents service milestones completed during dog grooming.
/// Corresponds to Step 7 of the Groomer Workflow with dynamic store milestone support.
@immutable
class GroomerMilestoneRecord {
  final bool bathCompleted;
  final String? bathCompletedAt;
  final String? bathNotes;
  final bool groomingCompleted;
  final String? groomingCompletedAt;
  final String? groomingNotes;
  final bool readyForCheckoutCompleted;
  final String? readyForCheckoutCompletedAt;
  final int? completedByGroomerId;

  // Dynamic store milestone extensions
  final String? currentMilestoneKey;
  final String? currentStatus;
  final List<String> allowedNextKeys;
  final bool canSkipToReadyForCheckout;
  final Map<String, ({bool completed, String? occurredAt, String? notes, String? action, String? status})>
      dynamicMilestones;

  const GroomerMilestoneRecord({
    this.bathCompleted = false,
    this.bathCompletedAt,
    this.bathNotes,
    this.groomingCompleted = false,
    this.groomingCompletedAt,
    this.groomingNotes,
    this.readyForCheckoutCompleted = false,
    this.readyForCheckoutCompletedAt,
    this.completedByGroomerId,
    this.currentMilestoneKey,
    this.currentStatus,
    this.allowedNextKeys = const [],
    this.canSkipToReadyForCheckout = false,
    this.dynamicMilestones = const {},
  });

  bool get hasAnyMilestone =>
      bathCompleted ||
      groomingCompleted ||
      readyForCheckoutCompleted ||
      dynamicMilestones.values.any((m) => m.completed);

  bool get isCheckInDone => isMilestoneDone('check_in_completed');
  bool get isBathDone => isMilestoneDone('bath_completed');
  bool get isGroomingDone => isMilestoneDone('grooming_completed');
  bool get isReadyForCheckoutDone =>
      isMilestoneDone('ready_for_checkout') || isMilestoneDone('readyforcheckout');
  bool get areAllMilestonesDone => isBathDone && isGroomingDone;

  bool isMilestoneDone(String key) {
    if (dynamicMilestones.containsKey(key)) {
      return dynamicMilestones[key]!.completed;
    }
    if (key == 'bath_completed') return bathCompleted;
    if (key == 'grooming_completed') return groomingCompleted;
    if (key == 'ready_for_checkout' || key == 'readyforcheckout') {
      return readyForCheckoutCompleted;
    }
    return false;
  }

  String? getMilestoneNotes(String key) {
    if (dynamicMilestones.containsKey(key)) {
      return dynamicMilestones[key]!.notes;
    }
    if (key == 'bath_completed') return bathNotes;
    if (key == 'grooming_completed') return groomingNotes;
    return null;
  }

  String? getMilestoneOccurredAt(String key) {
    if (dynamicMilestones.containsKey(key)) {
      return dynamicMilestones[key]!.occurredAt;
    }
    if (key == 'bath_completed') return bathCompletedAt;
    if (key == 'grooming_completed') return groomingCompletedAt;
    if (key == 'ready_for_checkout' || key == 'readyforcheckout') {
      return readyForCheckoutCompletedAt;
    }
    return null;
  }

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

    List<String> parseStringList(dynamic list) {
      if (list is List) {
        return list.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
      }
      return const [];
    }

    final dynamicMap = <String, ({bool completed, String? occurredAt, String? notes, String? action, String? status})>{};

    if (json['milestones'] is List) {
      for (final item in json['milestones'] as List) {
        if (item is! Map) continue;
        final k = item['milestoneKey']?.toString() ?? item['key']?.toString();
        if (k == null || k.isEmpty) continue;
        final isDone = parseBool(item['completed']);
        final occurredAt = item['occurredAt']?.toString() ?? item['updatedAt']?.toString();
        final notes = item['notes']?.toString();
        final action = item['action']?.toString();
        final status = item['status']?.toString();
        dynamicMap[k] = (
          completed: isDone,
          occurredAt: occurredAt,
          notes: notes,
          action: action,
          status: status,
        );
      }
    }

    final bathDone = parseBool(
      json['bathCompleted'] ??
          json['bath_completed'] ??
          json['isBathCompleted'] ??
          dynamicMap['bath_completed']?.completed,
    );
    final bathAt = json['bathCompletedAt']?.toString() ??
        json['bath_completed_at']?.toString() ??
        json['bathTimestamp']?.toString() ??
        json['bath_timestamp']?.toString() ??
        dynamicMap['bath_completed']?.occurredAt;
    final bathNotes = json['bathNotes']?.toString() ??
        json['bath_notes']?.toString() ??
        dynamicMap['bath_completed']?.notes;

    final groomingDone = parseBool(
      json['groomingCompleted'] ??
          json['grooming_completed'] ??
          json['isGroomingCompleted'] ??
          dynamicMap['grooming_completed']?.completed,
    );
    final groomingAt = json['groomingCompletedAt']?.toString() ??
        json['grooming_completed_at']?.toString() ??
        json['groomingTimestamp']?.toString() ??
        json['grooming_timestamp']?.toString() ??
        dynamicMap['grooming_completed']?.occurredAt;
    final groomingNotes = json['groomingNotes']?.toString() ??
        json['grooming_notes']?.toString() ??
        dynamicMap['grooming_completed']?.notes;

    final readyDone = parseBool(
      json['readyForCheckoutCompleted'] ??
          json['ready_for_checkout_completed'] ??
          json['readyForCheckout'] ??
          json['ready_for_checkout'] ??
          dynamicMap['ready_for_checkout']?.completed,
    );
    final readyAt = json['readyForCheckoutCompletedAt']?.toString() ??
        json['ready_for_checkout_completed_at']?.toString() ??
        dynamicMap['ready_for_checkout']?.occurredAt;

    final groomerId = parseInt(
      json['completedByGroomerId'] ?? json['completed_by_groomer_id'] ?? json['groomerId'],
    );

    return GroomerMilestoneRecord(
      bathCompleted: bathDone,
      bathCompletedAt: bathAt,
      bathNotes: bathNotes,
      groomingCompleted: groomingDone,
      groomingCompletedAt: groomingAt,
      groomingNotes: groomingNotes,
      readyForCheckoutCompleted: readyDone,
      readyForCheckoutCompletedAt: readyAt,
      completedByGroomerId: groomerId,
      currentMilestoneKey: json['currentMilestoneKey']?.toString(),
      currentStatus: json['currentStatus']?.toString(),
      allowedNextKeys: parseStringList(json['allowedNextKeys']),
      canSkipToReadyForCheckout: parseBool(json['canSkipToReadyForCheckout']),
      dynamicMilestones: Map.unmodifiable(dynamicMap),
    );
  }

  factory GroomerMilestoneRecord.fromTimeline(List<dynamic> milestones) {
    bool bath = false;
    String? bathAt;
    String? bathNotes;
    bool grooming = false;
    String? groomingAt;
    String? groomingNotes;
    bool readyForCheckout = false;
    String? readyForCheckoutAt;
    int? groomerId;

    final dynamicMap = <String, ({bool completed, String? occurredAt, String? notes, String? action, String? status})>{};

    for (final item in milestones) {
      if (item is! Map) continue;
      final key = item['milestoneKey']?.toString() ?? item['key']?.toString();
      if (key == null || key.isEmpty) continue;
      final isDone = item['completed'] == true;
      final occurredAt = item['occurredAt']?.toString() ?? item['updatedAt']?.toString();
      final notes = item['notes']?.toString();
      final action = item['action']?.toString();
      final status = item['status']?.toString();
      final gId = item['actorId'] is int
          ? item['actorId'] as int
          : int.tryParse(item['actorId']?.toString() ?? '');

      dynamicMap[key] = (
        completed: isDone,
        occurredAt: occurredAt,
        notes: notes,
        action: action,
        status: status,
      );

      if (key == 'bath_completed' && isDone) {
        bath = true;
        bathAt = occurredAt;
        bathNotes = notes;
        if (gId != null) groomerId = gId;
      } else if (key == 'grooming_completed' && isDone) {
        grooming = true;
        groomingAt = occurredAt;
        groomingNotes = notes;
        if (gId != null) groomerId = gId;
      } else if ((key == 'ready_for_checkout' || key == 'readyforcheckout') && isDone) {
        readyForCheckout = true;
        readyForCheckoutAt = occurredAt;
        if (gId != null) groomerId = gId;
      }
    }

    return GroomerMilestoneRecord(
      bathCompleted: bath,
      bathCompletedAt: bathAt,
      bathNotes: bathNotes,
      groomingCompleted: grooming,
      groomingCompletedAt: groomingAt,
      groomingNotes: groomingNotes,
      readyForCheckoutCompleted: readyForCheckout,
      readyForCheckoutCompletedAt: readyForCheckoutAt,
      completedByGroomerId: groomerId,
      dynamicMilestones: Map.unmodifiable(dynamicMap),
    );
  }

  factory GroomerMilestoneRecord.fromTimelineResponse(BookingMilestoneTimeline timeline) {
    final base = GroomerMilestoneRecord.fromTimeline(
      timeline.milestones.map((m) => m.toJson()).toList(),
    );
    return base.copyWith(
      currentMilestoneKey: timeline.currentMilestoneKey,
      currentStatus: timeline.currentStatus,
      allowedNextKeys: timeline.allowedNextKeys,
      canSkipToReadyForCheckout: timeline.canSkipToReadyForCheckout,
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
      'readyForCheckoutCompleted': readyForCheckoutCompleted,
      if (readyForCheckoutCompletedAt != null)
        'readyForCheckoutCompletedAt': readyForCheckoutCompletedAt,
      if (completedByGroomerId != null) 'completedByGroomerId': completedByGroomerId,
      if (currentMilestoneKey != null) 'currentMilestoneKey': currentMilestoneKey,
      if (currentStatus != null) 'currentStatus': currentStatus,
      'allowedNextKeys': allowedNextKeys,
      'canSkipToReadyForCheckout': canSkipToReadyForCheckout,
    };
  }

  GroomerMilestoneRecord copyWith({
    bool? bathCompleted,
    String? bathCompletedAt,
    String? bathNotes,
    bool? groomingCompleted,
    String? groomingCompletedAt,
    String? groomingNotes,
    bool? readyForCheckoutCompleted,
    String? readyForCheckoutCompletedAt,
    int? completedByGroomerId,
    String? currentMilestoneKey,
    String? currentStatus,
    List<String>? allowedNextKeys,
    bool? canSkipToReadyForCheckout,
    Map<String, ({bool completed, String? occurredAt, String? notes, String? action, String? status})>?
        dynamicMilestones,
  }) {
    return GroomerMilestoneRecord(
      bathCompleted: bathCompleted ?? this.bathCompleted,
      bathCompletedAt: bathCompletedAt ?? this.bathCompletedAt,
      bathNotes: bathNotes ?? this.bathNotes,
      groomingCompleted: groomingCompleted ?? this.groomingCompleted,
      groomingCompletedAt: groomingCompletedAt ?? this.groomingCompletedAt,
      groomingNotes: groomingNotes ?? this.groomingNotes,
      readyForCheckoutCompleted:
          readyForCheckoutCompleted ?? this.readyForCheckoutCompleted,
      readyForCheckoutCompletedAt:
          readyForCheckoutCompletedAt ?? this.readyForCheckoutCompletedAt,
      completedByGroomerId: completedByGroomerId ?? this.completedByGroomerId,
      currentMilestoneKey: currentMilestoneKey ?? this.currentMilestoneKey,
      currentStatus: currentStatus ?? this.currentStatus,
      allowedNextKeys: allowedNextKeys ?? this.allowedNextKeys,
      canSkipToReadyForCheckout:
          canSkipToReadyForCheckout ?? this.canSkipToReadyForCheckout,
      dynamicMilestones: dynamicMilestones ?? this.dynamicMilestones,
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
          readyForCheckoutCompleted == other.readyForCheckoutCompleted &&
          readyForCheckoutCompletedAt == other.readyForCheckoutCompletedAt &&
          completedByGroomerId == other.completedByGroomerId &&
          currentMilestoneKey == other.currentMilestoneKey &&
          currentStatus == other.currentStatus &&
          canSkipToReadyForCheckout == other.canSkipToReadyForCheckout;

  @override
  int get hashCode => Object.hash(
        bathCompleted,
        bathCompletedAt,
        bathNotes,
        groomingCompleted,
        groomingCompletedAt,
        groomingNotes,
        readyForCheckoutCompleted,
        readyForCheckoutCompletedAt,
        completedByGroomerId,
        currentMilestoneKey,
        currentStatus,
        canSkipToReadyForCheckout,
      );
}
