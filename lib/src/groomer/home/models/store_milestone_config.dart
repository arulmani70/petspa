import 'package:flutter/material.dart';

/// Represents a store-configured appointment milestone definition from
/// GET /api/common/groomer/appointment-milestones or GET /api/common/appointment-milestones
class StoreMilestoneConfig {
  final String key;
  final int order;
  final String phase; // 'pre_store', 'in_store', 'checkout', 'customer', etc.
  final String action; // e.g. 'CheckInCompleted', 'ServiceCompleted', 'CustomStep'
  final String status; // e.g. 'DogServiceInProgress', 'BathCompleted', 'welcome Back'
  final String? serviceStage;
  final bool autoOnServiceDay;
  final bool groomerSelectable;
  final bool requiresCheckInPayload;
  final bool requiresCheckoutPayload;
  final String? title;
  final String? description;
  final List<int> serviceIds;
  final List<String> services;
  final String? category;

  const StoreMilestoneConfig({
    required this.key,
    required this.order,
    this.phase = 'in_store',
    this.action = '',
    this.status = '',
    this.serviceStage,
    this.autoOnServiceDay = false,
    this.groomerSelectable = true,
    this.requiresCheckInPayload = false,
    this.requiresCheckoutPayload = false,
    this.title,
    this.description,
    this.serviceIds = const [],
    this.services = const [],
    this.category,
  });

  /// In-store actions that should appear in the groomer's milestone dropdown.
  /// Explicitly excludes pre-store, customer confirmation/tip, and final checkout actions.
  bool get isInStoreAction {
    final p = phase.trim().toLowerCase();
    if (p != 'in_store') return false;
    if (!groomerSelectable) return false;
    if (isCustomerAction || isFinalCheckoutAction) return false;
    return true;
  }

  /// Whether this milestone belongs to customer-side action (tip, confirmation).
  bool get isCustomerAction {
    final a = action.toLowerCase();
    final k = key.toLowerCase();
    final p = phase.toLowerCase();
    return p == 'customer' ||
        a.contains('tip') ||
        k.contains('tip') ||
        k == 'final_checkout' ||
        a == 'entertipandconfirm';
  }

  /// Whether this milestone belongs to final payment / transaction checkout.
  bool get isFinalCheckoutAction {
    final a = action.toLowerCase();
    final k = key.toLowerCase();
    final p = phase.toLowerCase();
    return (p == 'checkout' && (k.contains('checkout') || a.contains('checkout'))) ||
        k == 'final_service_completed' ||
        requiresCheckoutPayload;
  }

  /// Whether this is the Check-in milestone (mandatory start of in-store workflow).
  bool get isCheckIn =>
      key == 'check_in_completed' ||
      key == 'checkincompleted' ||
      requiresCheckInPayload;

  /// Whether this is the Service Completed / Ready for Checkout milestone.
  bool get isReadyForCheckout =>
      key == 'ready_for_checkout' ||
      key == 'readyforcheckout' ||
      status == 'ReadyForCheckout';

  /// Whether this milestone can be skipped if permitted by backend.
  bool get isSkippable => !isCheckIn && !isReadyForCheckout;

  /// Whether this milestone is designated for specific services rather than being common to all appointments.
  bool get isServiceSpecific {
    if (isCheckIn || isReadyForCheckout) return false;
    if (serviceIds.isNotEmpty || services.isNotEmpty) return true;
    final k = key.toLowerCase();
    final a = action.toLowerCase();
    final st = status.toLowerCase();
    return k.contains('nail') ||
        k.contains('teeth') ||
        k.contains('bath') ||
        k.contains('groom') ||
        k.contains('medicated') ||
        k.contains('ear') ||
        a.contains('nail') ||
        a.contains('teeth') ||
        st.contains('bath') ||
        st.contains('groom');
  }

  /// Formatted display title for UI representation.
  String get displayTitle {
    if (title != null && title!.trim().isNotEmpty) return title!.trim();
    switch (key) {
      case 'ready_for_check_in':
        return 'Ready for Check-in';
      case 'check_in_completed':
        return 'Check-in Completed';
      case 'bath_completed':
        return 'Bath Completed';
      case 'grooming_in_progress':
        return 'Grooming In Progress';
      case 'grooming_completed':
        return 'Grooming Completed';
      case 'ready_for_checkout':
        return 'Ready for Checkout';
      case 'final_checkout':
        return 'Customer Tip & Confirmation';
      case 'final_service_completed':
        return 'Final Service Completed';
      default:
        if (status.isNotEmpty && !status.contains('_') && status != status.toUpperCase()) {
          final spaced = status.replaceAllMapped(
            RegExp(r'([a-z])([A-Z])'),
            (m) => '${m[1]} ${m[2]}',
          );
          return spaced
              .split(' ')
              .map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '')
              .join(' ');
        }
        return key
            .replaceAll('_', ' ')
            .split(' ')
            .map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '')
            .join(' ');
    }
  }

  /// Short label for chips and tabs.
  String get shortLabel {
    switch (key) {
      case 'check_in_completed':
        return 'Check-in';
      case 'bath_completed':
        return 'Bath';
      case 'grooming_in_progress':
        return 'Grooming Prep';
      case 'grooming_completed':
        return 'Groomed';
      case 'ready_for_checkout':
        return 'Ready';
      default:
        return displayTitle.split(' ').first;
    }
  }

  /// Contextual icon for UI.
  IconData get icon {
    switch (key) {
      case 'ready_for_check_in':
        return Icons.schedule_rounded;
      case 'check_in_completed':
        return Icons.how_to_reg_rounded;
      case 'bath_completed':
        return Icons.bathtub_outlined;
      case 'grooming_in_progress':
        return Icons.content_cut_outlined;
      case 'grooming_completed':
        return Icons.content_cut_rounded;
      case 'ready_for_checkout':
        return Icons.shopping_bag_outlined;
      case 'final_checkout':
        return Icons.monetization_on_outlined;
      case 'final_service_completed':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.pets_rounded;
    }
  }

  factory StoreMilestoneConfig.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic val, {bool defaultValue = false}) {
      if (val == null) return defaultValue;
      if (val is bool) return val;
      final str = val.toString().trim().toLowerCase();
      return str == 'true' || str == '1' || str == 'yes';
    }

    int parseInt(dynamic val, {int defaultValue = 0}) {
      if (val == null) return defaultValue;
      if (val is int) return val;
      return int.tryParse(val.toString()) ?? defaultValue;
    }

    final key = json['key']?.toString() ?? json['milestoneKey']?.toString() ?? '';
    final order = parseInt(json['order']);
    final phase = json['phase']?.toString() ?? 'in_store';
    final action = json['action']?.toString() ?? '';
    final status = json['status']?.toString() ?? '';
    final serviceStage = json['serviceStage']?.toString();
    final autoOnServiceDay = parseBool(json['autoOnServiceDay']);
    final groomerSelectable = parseBool(json['groomerSelectable'], defaultValue: true);
    final requiresCheckInPayload = parseBool(json['requiresCheckInPayload']);
    final requiresCheckoutPayload = parseBool(json['requiresCheckoutPayload']);
    final title = json['title']?.toString() ?? json['name']?.toString() ?? json['label']?.toString();
    final description = json['description']?.toString();
    final category = json['category']?.toString() ?? json['group']?.toString();

    List<int> parseServiceIds(dynamic val) {
      if (val == null) return const [];
      if (val is List) {
        return val.map((e) => int.tryParse(e.toString())).whereType<int>().toList();
      }
      if (val is int) return [val];
      final p = int.tryParse(val.toString());
      return p != null ? [p] : const [];
    }

    List<String> parseServices(dynamic val) {
      if (val == null) return const [];
      if (val is List) {
        return val.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
      }
      final s = val.toString().trim();
      return s.isNotEmpty ? [s] : const [];
    }

    final sIds = parseServiceIds(json['serviceIds'] ?? json['serviceId']);
    final sList = parseServices(json['services'] ?? json['serviceName'] ?? json['serviceNames']);

    return StoreMilestoneConfig(
      key: key,
      order: order,
      phase: phase,
      action: action,
      status: status,
      serviceStage: serviceStage,
      autoOnServiceDay: autoOnServiceDay,
      groomerSelectable: groomerSelectable,
      requiresCheckInPayload: requiresCheckInPayload,
      requiresCheckoutPayload: requiresCheckoutPayload,
      title: title,
      description: description,
      serviceIds: sIds,
      services: sList,
      category: category,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'order': order,
      'phase': phase,
      'action': action,
      'status': status,
      if (serviceStage != null) 'serviceStage': serviceStage,
      'autoOnServiceDay': autoOnServiceDay,
      'groomerSelectable': groomerSelectable,
      'requiresCheckInPayload': requiresCheckInPayload,
      'requiresCheckoutPayload': requiresCheckoutPayload,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (serviceIds.isNotEmpty) 'serviceIds': serviceIds,
      if (services.isNotEmpty) 'services': services,
      if (category != null) 'category': category,
    };
  }
}

/// Represents an individual milestone step item inside a booking's timeline
class BookingMilestoneItem {
  final String milestoneKey;
  final String? action;
  final String? status;
  final int order;
  final String? phase;
  final bool groomerSelectable;
  final bool completed;
  final String? occurredAt;
  final String? updatedAt;
  final String? notes;
  final String? actorType;
  final int? actorId;

  const BookingMilestoneItem({
    required this.milestoneKey,
    this.action,
    this.status,
    this.order = 0,
    this.phase,
    this.groomerSelectable = true,
    this.completed = false,
    this.occurredAt,
    this.updatedAt,
    this.notes,
    this.actorType,
    this.actorId,
  });

  factory BookingMilestoneItem.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic val, {bool defaultValue = false}) {
      if (val == null) return defaultValue;
      if (val is bool) return val;
      final str = val.toString().trim().toLowerCase();
      return str == 'true' || str == '1' || str == 'yes';
    }

    int parseInt(dynamic val, {int defaultValue = 0}) {
      if (val == null) return defaultValue;
      if (val is int) return val;
      return int.tryParse(val.toString()) ?? defaultValue;
    }

    int? parseNullableInt(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      return int.tryParse(val.toString());
    }

    return BookingMilestoneItem(
      milestoneKey: json['milestoneKey']?.toString() ?? json['key']?.toString() ?? '',
      action: json['action']?.toString(),
      status: json['status']?.toString(),
      order: parseInt(json['order']),
      phase: json['phase']?.toString(),
      groomerSelectable: parseBool(json['groomerSelectable'], defaultValue: true),
      completed: parseBool(json['completed']),
      occurredAt: json['occurredAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      notes: json['notes']?.toString(),
      actorType: json['actorType']?.toString(),
      actorId: parseNullableInt(json['actorId']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'milestoneKey': milestoneKey,
      if (action != null) 'action': action,
      if (status != null) 'status': status,
      'order': order,
      if (phase != null) 'phase': phase,
      'groomerSelectable': groomerSelectable,
      'completed': completed,
      if (occurredAt != null) 'occurredAt': occurredAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
      if (notes != null) 'notes': notes,
      if (actorType != null) 'actorType': actorType,
      if (actorId != null) 'actorId': actorId,
    };
  }
}

/// Represents the appointment milestone timeline returned by
/// GET /api/common/groomer/bookings/:id/milestones?storeId=:storeId
class BookingMilestoneTimeline {
  final int appointmentId;
  final String storeId;
  final String? clientId;
  final String? regionId;
  final String? currentMilestoneKey;
  final String? currentAction;
  final String? currentStatus;
  final String? currentMilestoneOccurredAt;
  final String? currentMilestoneUpdatedAt;
  final String? serviceStage;
  final String? status;
  final List<String> allowedNextKeys;
  final bool canSkipToReadyForCheckout;
  final List<BookingMilestoneItem> milestones;

  const BookingMilestoneTimeline({
    required this.appointmentId,
    required this.storeId,
    this.clientId,
    this.regionId,
    this.currentMilestoneKey,
    this.currentAction,
    this.currentStatus,
    this.currentMilestoneOccurredAt,
    this.currentMilestoneUpdatedAt,
    this.serviceStage,
    this.status,
    this.allowedNextKeys = const [],
    this.canSkipToReadyForCheckout = false,
    this.milestones = const [],
  });

  bool isMilestoneCompleted(String key) {
    return milestones.any((m) => m.milestoneKey == key && m.completed);
  }

  BookingMilestoneItem? getMilestone(String key) {
    try {
      return milestones.firstWhere((m) => m.milestoneKey == key);
    } catch (_) {
      return null;
    }
  }

  /// Whether a transition to [key] is permitted by backend allowedNextKeys.
  bool canTransitionTo(String key) {
    if (allowedNextKeys.isEmpty) return true;
    return allowedNextKeys.contains(key);
  }

  factory BookingMilestoneTimeline.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic val, {int defaultValue = 0}) {
      if (val == null) return defaultValue;
      if (val is int) return val;
      return int.tryParse(val.toString()) ?? defaultValue;
    }

    bool parseBool(dynamic val, {bool defaultValue = false}) {
      if (val == null) return defaultValue;
      if (val is bool) return val;
      final str = val.toString().trim().toLowerCase();
      return str == 'true' || str == '1' || str == 'yes';
    }

    List<String> parseStringList(dynamic list) {
      if (list is List) {
        return list.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
      }
      return const [];
    }

    final milestoneItems = <BookingMilestoneItem>[];
    if (json['milestones'] is List) {
      for (final item in json['milestones'] as List) {
        if (item is Map<String, dynamic>) {
          milestoneItems.add(BookingMilestoneItem.fromJson(item));
        } else if (item is Map) {
          milestoneItems.add(BookingMilestoneItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return BookingMilestoneTimeline(
      appointmentId: parseInt(json['appointmentId'] ?? json['bookingId'] ?? json['id']),
      storeId: json['storeId']?.toString() ??
          (json['store'] is Map ? json['store']['storeId']?.toString() : null) ??
          'SHEAR-001',
      clientId: json['clientId']?.toString() ??
          (json['store'] is Map ? json['store']['clientId']?.toString() : null),
      regionId: json['regionId']?.toString() ??
          (json['store'] is Map ? json['store']['regionId']?.toString() : null),
      currentMilestoneKey: json['currentMilestoneKey']?.toString(),
      currentAction: json['currentAction']?.toString(),
      currentStatus: json['currentStatus']?.toString(),
      currentMilestoneOccurredAt: json['currentMilestoneOccurredAt']?.toString(),
      currentMilestoneUpdatedAt: json['currentMilestoneUpdatedAt']?.toString(),
      serviceStage: json['serviceStage']?.toString(),
      status: json['status']?.toString(),
      allowedNextKeys: parseStringList(json['allowedNextKeys']),
      canSkipToReadyForCheckout: parseBool(json['canSkipToReadyForCheckout']),
      milestones: List.unmodifiable(milestoneItems),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appointmentId': appointmentId,
      'storeId': storeId,
      if (clientId != null) 'clientId': clientId,
      if (regionId != null) 'regionId': regionId,
      if (currentMilestoneKey != null) 'currentMilestoneKey': currentMilestoneKey,
      if (currentAction != null) 'currentAction': currentAction,
      if (currentStatus != null) 'currentStatus': currentStatus,
      if (currentMilestoneOccurredAt != null)
        'currentMilestoneOccurredAt': currentMilestoneOccurredAt,
      if (currentMilestoneUpdatedAt != null)
        'currentMilestoneUpdatedAt': currentMilestoneUpdatedAt,
      if (serviceStage != null) 'serviceStage': serviceStage,
      if (status != null) 'status': status,
      'allowedNextKeys': allowedNextKeys,
      'canSkipToReadyForCheckout': canSkipToReadyForCheckout,
      'milestones': milestones.map((m) => m.toJson()).toList(),
    };
  }
}
