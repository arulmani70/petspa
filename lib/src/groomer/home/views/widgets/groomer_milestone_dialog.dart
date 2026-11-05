import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_milestone_record.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/salon_groomer.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/store_milestone_config.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/utils/groomer_milestone_resolver.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/service_groomer_assignments_card.dart';

enum MilestoneType {
  bath,
  grooming,
}

/// Mobile implementation of the Web Application's Milestone Update Modal (WC).
/// Replicates the exact milestone flow, status updates, UI behavior, and business logic
/// from https://pcmdev.shearheavenpetspa.com/groomer, adapted cleanly for mobile devices.
class GroomerMilestoneDialog extends StatefulWidget {
  final GroomerBooking booking;
  final MilestoneType? milestoneType;
  final String? initialMilestoneKey;
  final ValueChanged<GroomerBooking>? onMilestoneSuccess;

  const GroomerMilestoneDialog({
    super.key,
    required this.booking,
    this.milestoneType,
    this.initialMilestoneKey,
    this.onMilestoneSuccess,
  });

  static Future<GroomerBooking?> show(
    BuildContext context, {
    required GroomerBooking booking,
    MilestoneType? milestoneType,
    String? initialMilestoneKey,
    ValueChanged<GroomerBooking>? onMilestoneSuccess,
  }) {
    return showModalBottomSheet<GroomerBooking>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GroomerMilestoneDialog(
        booking: booking,
        milestoneType: milestoneType,
        initialMilestoneKey: initialMilestoneKey,
        onMilestoneSuccess: onMilestoneSuccess,
      ),
    );
  }

  @override
  State<GroomerMilestoneDialog> createState() => _GroomerMilestoneDialogState();
}

class _GroomerMilestoneDialogState extends State<GroomerMilestoneDialog> {
  late GroomerBooking _booking;
  BookingMilestoneTimeline? _timeline;
  List<SalonGroomer> _salonGroomers = const [];
  List<StoreMilestoneConfig> _storeCatalog = const [];

  late final TextEditingController _notesController;
  bool _vaccinationVerified = true;
  bool _healthCheckVerified = true;
  bool _customerConfirmed = false;
  double _tipAmount = 0.0;
  String _customerPaymentMethod = 'card';

  bool _isSubmitting = false;
  bool _isLoading = true;
  String? _savingTaskKey;
  int? _savingPercent;
  String? _selectedStoreMilestone;
  Timer? _checkoutPollingTimer;

  // Selected legacy milestone for compatibility tests
  String? _legacyActiveKey;

  // Exact Web Portal progress buttons Qv = [20, 40, 60, 80, 100]
  static const List<int> _progressPercentOptions = [20, 40, 60, 80, 100];

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;

    // Determine initial legacy milestone key if specified
    if (widget.initialMilestoneKey != null && widget.initialMilestoneKey!.isNotEmpty) {
      _legacyActiveKey = widget.initialMilestoneKey;
    } else if (widget.milestoneType != null) {
      _legacyActiveKey = widget.milestoneType == MilestoneType.bath
          ? GroomerMilestoneResolver.bathMilestone
          : GroomerMilestoneResolver.groomingMilestone;
    }

    _notesController = TextEditingController(text: _booking.notes ?? '');

    _loadStoreCatalogAndTimeline();
  }

  @override
  void dispose() {
    _checkoutPollingTimer?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadStoreCatalogAndTimeline() async {
    try {
      final repo = ServicesLocator.groomerHomeRepository;
      final timelineFuture = repo.getMilestonesTimeline(
        _booking.bookingId,
        storeId: _booking.storeId.isNotEmpty ? _booking.storeId : null,
      );
      final groomersFuture = repo.getSalonGroomers();
      final catalogFuture = repo.getMilestonesCatalog(
        storeId: _booking.storeId.isNotEmpty ? _booking.storeId : null,
      );

      final results = await Future.wait([timelineFuture, groomersFuture, catalogFuture]);
      if (!mounted) return;

      final fetchedTimeline = results[0] as BookingMilestoneTimeline?;
      final fetchedGroomers = results[1] as List<SalonGroomer>? ?? const [];
      final fetchedCatalog = results[2] as List<StoreMilestoneConfig>? ?? const [];

      setState(() {
        _timeline = fetchedTimeline;
        _salonGroomers = fetchedGroomers;
        _storeCatalog = fetchedCatalog;
        _isLoading = false;

        if (fetchedTimeline != null) {
          final updatedRecord = GroomerMilestoneRecord.fromTimelineResponse(fetchedTimeline);
          _booking = _booking.copyWith(
            status: fetchedTimeline.status ?? _booking.status,
            serviceStage: fetchedTimeline.serviceStage ?? _booking.serviceStage,
            serviceProgress: fetchedTimeline.serviceProgress.isNotEmpty
                ? fetchedTimeline.serviceProgress
                : _booking.serviceProgress,
            serviceAssignmentActivity: fetchedTimeline.serviceAssignmentActivity.isNotEmpty
                ? fetchedTimeline.serviceAssignmentActivity
                : _booking.serviceAssignmentActivity,
            milestoneRecord: updatedRecord,
          );

          if (fetchedTimeline.customerConfirmed) {
            _customerConfirmed = true;
          }
          if (fetchedTimeline.tipAmount != null && fetchedTimeline.tipAmount! > 0) {
            _tipAmount = fetchedTimeline.tipAmount!;
          }
          if (fetchedTimeline.customerPaymentMethod != null) {
            _customerPaymentMethod = fetchedTimeline.customerPaymentMethod!;
          }
        }
      });

      // If in await_customer_tip stage, start real-time polling
      if (_currentStage == 'await_customer_tip') {
        _startCheckoutPolling();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startCheckoutPolling() {
    _checkoutPollingTimer?.cancel();
    _checkoutPollingTimer = Timer.periodic(const Duration(milliseconds: 2000), (timer) async {
      if (!mounted || _currentStage == 'done') {
        timer.cancel();
        return;
      }
      try {
        final statusMap = await ServicesLocator.groomerHomeRepository.getCheckoutStatus(_booking.bookingId);
        if (statusMap != null && mounted) {
          final confirmed = statusMap['customerConfirmed'] == true || statusMap['readyForFinalCheckout'] == true;
          final tipVal = statusMap['tipAmount'] ?? statusMap['tip_amount'];
          final payMethod = statusMap['customerPaymentMethod'] ?? statusMap['paymentMethod'];

          if (confirmed) {
            setState(() {
              _customerConfirmed = true;
              if (tipVal != null) {
                _tipAmount = (tipVal is num)
                    ? tipVal.toDouble()
                    : (double.tryParse(tipVal.toString()) ?? _tipAmount);
              }
              if (payMethod != null && (payMethod == 'cash' || payMethod == 'card')) {
                _customerPaymentMethod = payMethod.toString();
              }
            });
            timer.cancel();
            _loadStoreCatalogAndTimeline();
          }
        }
      } catch (_) {}
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Business Logic: Web Portal Stage Machine (QC(e, t))
  // ─────────────────────────────────────────────────────────────────────────

  /// Effective task list O = xa(m)
  List<ServiceProgressItem> get _effectiveTasks {
    if (_booking.serviceProgress.isNotEmpty) {
      return _booking.serviceProgress;
    }
    if (_timeline != null && _timeline!.serviceProgress.isNotEmpty) {
      return _timeline!.serviceProgress;
    }
    // Fallback: construct single task from booking services
    return [
      ServiceProgressItem(
        taskKey: 'svc-${_booking.bookingId}-parent',
        taskName: _booking.serviceName,
        label: _booking.serviceName,
        lineServiceAmount: _booking.totalPrice,
        durationMinutes: _booking.totalDurationMinutes,
        assignedGroomerId: _booking.groomerId,
        assignedGroomerName: _booking.effectiveGroomerName,
        primaryGroomerName: _booking.effectivePrimaryGroomerName,
        primaryGroomerId: _booking.effectivePrimaryGroomerId,
        status: _booking.isCompleted
            ? 'completed'
            : (_booking.isCheckedIn ? 'in_progress' : 'pending'),
        percent: _booking.isCompleted ? 100 : 0,
      ),
    ];
  }

  /// Determines the current active visit step / stage matching web component QC(e, t)
  String get _currentStage {
    final b = _booking;
    final t = _effectiveTasks;
    final timeline = _timeline;

    // T0(e): serviceStage == 'checkout_completed' || status == 'completed'
    final st = b.status.toLowerCase();
    final sStage = (timeline?.serviceStage ?? b.serviceStage)?.toLowerCase() ?? '';
    if (sStage == 'checkout_completed' || st == 'completed' || b.isCompleted) {
      return 'done';
    }

    // !C0(e): check_in_completed is not completed
    final isCheckInDone = b.isCheckedIn ||
        b.isMilestoneDone('check_in_completed') ||
        (timeline != null && timeline.isMilestoneCompleted('check_in_completed'));
    if (!isCheckInDone) {
      return 'check_in';
    }

    // k0(t): all tasks completed or skipped
    final allTasksDone = t.isNotEmpty
        ? t.every((item) => item.isCompleted || item.isSkipped)
        : b.areRequiredMilestonesCompleted;

    // Xr(e, t): checkout initiated or allowed
    final isReadyForCheckoutDone = b.isMilestoneDone('ready_for_checkout') ||
        b.isMilestoneDone('readyforcheckout') ||
        (timeline != null && timeline.isMilestoneCompleted('ready_for_checkout')) ||
        sStage == 'ready_for_checkout' ||
        sStage == 'final_checkout' ||
        st == 'ready_for_checkout' ||
        b.isReadyForCheckout;

    final isConfirmed = _customerConfirmed || (timeline?.customerConfirmed ?? false);
    final inCheckoutFlow = isReadyForCheckoutDone || isConfirmed;

    if (!allTasksDone && !inCheckoutFlow) {
      return 'service_progress';
    }

    if (inCheckoutFlow) {
      if (isConfirmed) {
        return 'final_checkout';
      }
      return 'await_customer_tip';
    }

    return 'ready_checkout';
  }

  /// Overall service percentage (FC(O))
  int get _overallServicePercent {
    final tasks = _effectiveTasks.where((t) => !t.isSkipped).toList();
    if (tasks.isEmpty) return _booking.isCompleted ? 100 : 0;
    final total = tasks.fold<int>(0, (sum, t) {
      if (t.isCompleted) return sum + 100;
      if (t.isInProgress) return sum + t.percent;
      return sum;
    });
    return (total / tasks.length).round();
  }

  /// Status string displayed in the top gradient card (Gc || HC(m))
  String get _currentStatusText {
    final inProg = _effectiveTasks.firstWhere(
      (t) => t.isInProgress,
      orElse: () => const ServiceProgressItem(taskKey: '', percent: -1),
    );
    if (inProg.percent >= 0) {
      return '${inProg.label ?? inProg.taskName ?? 'Service'} — ${inProg.percent}%';
    }
    switch (_currentStage) {
      case 'done':
        return 'Visit completed';
      case 'check_in':
        return 'Ready for check-in';
      case 'ready_checkout':
        return 'Ready for checkout';
      case 'await_customer_tip':
        return 'Ready for checkout';
      case 'final_checkout':
        return 'Customer confirmed checkout';
      case 'service_progress':
      default:
        if (_booking.isCheckedIn) {
          return 'Dog service in progress';
        }
        return _booking.status.replaceAll('_', ' ');
    }
  }

  /// Completed and skipped service labels (bI(O))
  List<String> get _completedAndSkippedLabels {
    final list = _effectiveTasks.where((t) => t.isCompleted || t.isSkipped).toList()
      ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
    return list.map((t) {
      final name = t.label ?? t.taskName ?? 'Service';
      return t.isSkipped ? '$name — skipped' : '$name — completed';
    }).toList();
  }

  /// Active services that need progress or skip controls (fI(O))
  List<ServiceProgressItem> get _activeTasks {
    return _effectiveTasks
        .where((t) => !t.isCompleted && !t.isSkipped)
        .toList()
      ..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
  }

  /// Logged in groomer ID for permission checks
  int? get _viewerGroomerId {
    try {
      final g = ServicesLocator.sessionService.getGroomerUser();
      if (g != null) {
        final id = g['id'] ?? g['groomerId'] ?? g['userId'];
        if (id != null) return int.tryParse(id.toString());
      }
    } catch (_) {}
    return null;
  }

  /// Whether current viewer is a restricted groomer (cannot manage all service lines)
  bool get _isRestrictedGroomerView {
    final role = (ServicesLocator.sessionService.userRole ?? '').toLowerCase().trim();
    if (role != 'groomer') return false;
    final canManageAll = _timeline?.canManageAllServiceLines ?? false;
    return !canManageAll;
  }

  /// Whether current user can edit the given task (matching web portal Ah(task, viewerId, perms))
  bool _canEditTask(ServiceProgressItem task) {
    if (ServicesLocator.sessionService.isAdmin) return true;
    if (_timeline?.canShopWideServiceProgress == true) return true;

    final viewerId = _viewerGroomerId;
    if (viewerId == null) {
      return true;
    }

    final canManageAll = _timeline?.canManageAllServiceLines ?? false;
    final assignedId = task.assignedGroomerId;
    if (assignedId == null || assignedId <= 0) {
      return canManageAll;
    }
    return assignedId == viewerId;
  }

  /// Service line subtitle matching web component Xc
  String _getServiceSubtitle(ServiceProgressItem task) {
    final durationStr = task.durationMinutes > 0 ? '${task.durationMinutes} min booked' : null;
    final timeStr = _formatTimestamp(task.updatedAt);

    final statusStr = task.isSkipped && timeStr.isNotEmpty
        ? 'Skipped · $timeStr'
        : (task.isCompleted && timeStr.isNotEmpty
            ? '${task.displayName} completed · $timeStr'
            : (task.percent > 0 && timeStr.isNotEmpty
                ? 'Updated $timeStr'
                : (task.percent > 0 ? 'In progress' : 'Not started')));

    return durationStr != null ? '$durationStr · $statusStr' : statusStr;
  }

  /// Whether service assignments are locked (NI(e, t))
  bool get _assignmentsLocked {
    final stage = _currentStage;
    if (stage == 'done' || stage == 'ready_checkout' || stage == 'await_customer_tip' || stage == 'final_checkout') {
      return true;
    }
    return _booking.isGroomerAssignmentLocked;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // API Action Submissions
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _handleCheckIn() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final res = await ServicesLocator.groomerHomeRepository.updateServiceMilestone(
        bookingId: _booking.bookingId,
        milestone: 'check_in_completed',
        storeId: _booking.storeId,
        booking: _booking,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        payload: {
          'vaccinationVerified': _vaccinationVerified,
          'healthVerified': _healthCheckVerified,
          'customerRequestAcknowledged': true,
        },
      );
      if (!mounted) return;
      if (res.success) {
        ToastUtil.showSuccessToast(context, 'Check-in completed');
        final updated = res.updatedBooking ?? _booking.copyWith(status: 'checked_in');
        setState(() {
          _booking = updated;
          if (res.timeline != null) _timeline = res.timeline;
        });
        widget.onMilestoneSuccess?.call(updated);
        _loadStoreCatalogAndTimeline();
      } else {
        ToastUtil.showErrorToast(context, res.message);
      }
    } catch (e) {
      if (mounted) ToastUtil.showErrorToast(context, 'Failed to check in: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleUpdateServiceProgress(String taskKey, int percent) async {
    if (_isSubmitting || _savingTaskKey != null) return;

    final previousBooking = _booking;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final nextStatus = percent >= 100 ? 'completed' : 'in_progress';

    // Optimistically update task progress in local state immediately
    final optimisticTasks = _effectiveTasks.map((t) {
      if (t.taskKey == taskKey) {
        return t.copyWith(
          percent: percent,
          status: nextStatus,
          updatedAt: nowIso,
        );
      }
      return t;
    }).toList();

    setState(() {
      _savingTaskKey = taskKey;
      _savingPercent = percent;
      _booking = _booking.copyWith(serviceProgress: optimisticTasks);
    });

    try {
      final res = await ServicesLocator.groomerHomeRepository.updateServiceProgress(
        _booking.bookingId,
        taskKey: taskKey,
        percent: percent,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        storeId: _booking.storeId,
        booking: _booking,
      );

      if (!mounted) return;

      if (res.success) {
        final updated = res.updatedBooking ?? _booking;
        setState(() {
          _booking = updated;
        });
        widget.onMilestoneSuccess?.call(updated);
        final label = percent >= 100 ? 'Service completed' : 'Progress updated to $percent%';
        ToastUtil.showSuccessToast(context, label);
        _loadStoreCatalogAndTimeline();
      } else {
        setState(() {
          _booking = previousBooking;
        });
        ToastUtil.showErrorToast(context, res.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _booking = previousBooking;
        });
        ToastUtil.showErrorToast(context, 'Error updating progress: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingTaskKey = null;
          _savingPercent = null;
        });
      }
    }
  }

  Future<void> _handleSkipService(String taskKey) async {
    if (_isSubmitting || _savingTaskKey != null) return;

    final previousBooking = _booking;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final optimisticTasks = _effectiveTasks.map((t) {
      if (t.taskKey == taskKey) {
        return t.copyWith(
          percent: 0,
          status: 'skipped',
          updatedAt: nowIso,
          reason: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : 'Skipped by groomer',
        );
      }
      return t;
    }).toList();

    setState(() {
      _savingTaskKey = taskKey;
      _savingPercent = null;
      _booking = _booking.copyWith(serviceProgress: optimisticTasks);
    });

    try {
      final res = await ServicesLocator.groomerHomeRepository.skipServiceProgressTask(
        _booking.bookingId,
        taskKey: taskKey,
        reason: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : 'Skipped by groomer',
        storeId: _booking.storeId,
        booking: _booking,
      );

      if (!mounted) return;

      if (res.success) {
        final updated = res.updatedBooking ?? _booking;
        setState(() {
          _booking = updated;
        });
        widget.onMilestoneSuccess?.call(updated);
        ToastUtil.showSuccessToast(context, 'Service skipped');
        _loadStoreCatalogAndTimeline();
      } else {
        setState(() {
          _booking = previousBooking;
        });
        ToastUtil.showErrorToast(context, res.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _booking = previousBooking;
        });
        ToastUtil.showErrorToast(context, 'Error skipping service: $e');
      }
    } finally {
      if (mounted) setState(() => _savingTaskKey = null);
    }
  }

  Future<void> _handleReadyForCheckout() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final res = await ServicesLocator.groomerHomeRepository.updateServiceMilestone(
        bookingId: _booking.bookingId,
        milestone: 'ready_for_checkout',
        storeId: _booking.storeId,
        booking: _booking,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        payload: {
          'additionalServiceNotes':
              _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        },
      );
      if (!mounted) return;
      if (res.success) {
        ToastUtil.showSuccessToast(context, 'Marked ready for checkout');
        final updated = res.updatedBooking ??
            _booking.copyWith(status: 'ready_for_checkout', serviceStage: 'ready_for_checkout');
        setState(() {
          _booking = updated;
          if (res.timeline != null) _timeline = res.timeline;
        });
        widget.onMilestoneSuccess?.call(updated);
        _startCheckoutPolling();
      } else {
        ToastUtil.showErrorToast(context, res.message);
      }
    } catch (e) {
      if (mounted) ToastUtil.showErrorToast(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleFinalCheckout() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final res = await ServicesLocator.groomerHomeRepository.updateServiceMilestone(
        bookingId: _booking.bookingId,
        milestone: 'final_service_completed',
        storeId: _booking.storeId,
        booking: _booking,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        payload: {
          'idempotencyKey': 'checkout-${_booking.bookingId}-${DateTime.now().millisecondsSinceEpoch}',
          'paymentMethod': _customerPaymentMethod,
          'tipAmount': _tipAmount,
        },
      );
      if (!mounted) return;
      if (res.success) {
        ToastUtil.showSuccessToast(context, 'Visit completed');
        final updated = res.updatedBooking ??
            _booking.copyWith(status: 'completed', serviceStage: 'checkout_completed');
        setState(() {
          _booking = updated;
          if (res.timeline != null) _timeline = res.timeline;
        });
        widget.onMilestoneSuccess?.call(updated);
      } else {
        ToastUtil.showErrorToast(context, res.message);
      }
    } catch (e) {
      if (mounted) ToastUtil.showErrorToast(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleApplyStoreMilestone(String milestoneKey) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final trimmedNotes = _notesController.text.trim();
      final res = await ServicesLocator.groomerHomeRepository.updateServiceMilestone(
        bookingId: _booking.bookingId,
        milestone: milestoneKey,
        storeId: _booking.storeId,
        booking: _booking,
        notes: trimmedNotes.isNotEmpty ? trimmedNotes : null,
      );
      if (!mounted) return;
      if (res.success) {
        // Resolve friendly title for the milestone
        String milestoneTitle = MilestoneConfig.forMilestone(milestoneKey).title;
        for (final opt in _availableStoreMilestoneOptions) {
          if (opt.key == milestoneKey) {
            milestoneTitle = opt.label;
            break;
          }
        }

        ToastUtil.showSuccessToast(context, 'Milestone updated: $milestoneTitle');
        _notesController.clear();

        // Update local booking and timeline state immediately
        final nowIso = DateTime.now().toUtc().toIso8601String();
        var updatedBooking = res.updatedBooking ?? _booking;

        // Ensure milestoneRecord reflects the completed milestone
        var record = res.milestoneRecord ?? updatedBooking.milestoneRecord ?? _booking.milestoneRecord ?? const GroomerMilestoneRecord();
        if (!record.isMilestoneDone(milestoneKey)) {
          final dynMap = Map<String, ({bool completed, String? occurredAt, String? notes, String? action, String? status})>.from(
            record.dynamicMilestones,
          );
          dynMap[milestoneKey] = (
            completed: true,
            occurredAt: nowIso,
            notes: trimmedNotes.isNotEmpty ? trimmedNotes : null,
            action: null,
            status: null,
          );
          if (milestoneKey == 'bath_completed') {
            record = record.copyWith(
              bathCompleted: true,
              bathCompletedAt: nowIso,
              bathNotes: trimmedNotes.isNotEmpty ? trimmedNotes : record.bathNotes,
              dynamicMilestones: Map.unmodifiable(dynMap),
            );
          } else if (milestoneKey == 'grooming_completed') {
            record = record.copyWith(
              groomingCompleted: true,
              groomingCompletedAt: nowIso,
              groomingNotes: trimmedNotes.isNotEmpty ? trimmedNotes : record.groomingNotes,
              dynamicMilestones: Map.unmodifiable(dynMap),
            );
          } else if (milestoneKey == 'ready_for_checkout') {
            record = record.copyWith(
              readyForCheckoutCompleted: true,
              readyForCheckoutCompletedAt: nowIso,
              dynamicMilestones: Map.unmodifiable(dynMap),
            );
          } else {
            record = record.copyWith(
              dynamicMilestones: Map.unmodifiable(dynMap),
            );
          }
        }

        updatedBooking = updatedBooking.copyWith(
          status: res.timeline?.currentMilestoneKey ?? (updatedBooking.status == 'in_progress' ? milestoneKey : updatedBooking.status),
          serviceStage: res.timeline?.serviceStage ?? updatedBooking.serviceStage,
          milestoneRecord: record,
        );

        setState(() {
          _booking = updatedBooking;
          if (res.timeline != null) {
            _timeline = res.timeline;
          }
          _selectedStoreMilestone = null;
        });

        widget.onMilestoneSuccess?.call(updatedBooking);
        _loadStoreCatalogAndTimeline();
      } else {
        ToastUtil.showErrorToast(context, res.message);
      }
    } catch (e) {
      if (mounted) ToastUtil.showErrorToast(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI Builders
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final stage = _currentStage;
    final overallPct = _overallServicePercent;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Modal Header (Appointment #ID, Pet, Service, Date, Service % Badge)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _booking.petName.isNotEmpty ? _booking.petName[0].toUpperCase() : 'P',
                        style: AppFonts.parkinsans(
                          size: 18,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _booking.petName,
                                style: AppFonts.parkinsans(
                                  size: 16,
                                  weight: FontWeight.w700,
                                  color: const Color(0xFF111827),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_booking.breed.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                '• ${_booking.breed}',
                                style: AppFonts.poppins(
                                  size: 12,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                            if (_booking.bookingId > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                '#${_booking.bookingId}',
                                style: AppFonts.poppins(
                                  size: 12,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${_booking.serviceName} · ${_booking.bookingDate}',
                          style: AppFonts.poppins(
                            size: 11.5,
                            color: const Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (overallPct > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'SERVICE',
                            style: AppFonts.poppins(
                              size: 8.5,
                              weight: FontWeight.w700,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                          Text(
                            '$overallPct%',
                            style: AppFonts.parkinsans(
                              size: 15,
                              weight: FontWeight.w800,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF), size: 22),
                    onPressed: () => Navigator.of(context).pop(_booking),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),

            // Scrollable Modal Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card 1: Current Status Card (Gradient from-brand to-teal-800)
                    _buildCurrentStatusCard(),
                    const SizedBox(height: 14),

                    // Card 2: Progress Overview
                    _buildProgressOverviewCard(overallPct),
                    const SizedBox(height: 14),

                    // Customer Special Instructions (if present)
                    if (_booking.hasSpecialInstructions) ...[
                      _buildCustomerNotesCard(_booking.specialInstructions!),
                      const SizedBox(height: 12),
                    ],

                    // Pet Medical Alert Notes (if present)
                    if (_booking.hasPetMedicalNotes) ...[
                      _buildMedicalNotesCard(_booking.petMedicalNotes!),
                      const SizedBox(height: 12),
                    ],

                    // Legacy Prior Bath Notes if applicable
                    if ((_legacyActiveKey == 'grooming_completed' || widget.milestoneType == MilestoneType.grooming) &&
                        _booking.bathNotes != null &&
                        _booking.bathNotes!.trim().isNotEmpty) ...[
                      _buildPriorBathNotesCard(_booking.bathNotes!),
                      const SizedBox(height: 12),
                    ],

                    // Card 3: Service Groomer Assignments Card (LI)
                    if (_assignmentsLocked) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF6B7280)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Groomer assignments are locked — all booked services are complete or checkout has started.',
                                style: AppFonts.poppins(
                                  size: 11.5,
                                  color: const Color(0xFF4B5563),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ] else ...[
                      ServiceGroomerAssignmentsCard(
                        booking: _booking,
                        groomers: _salonGroomers,
                        primaryGroomerName: _booking.effectivePrimaryGroomerName,
                        assignmentsLocked: _assignmentsLocked,
                        onAssignGroomer: (taskKey, groomerId) async {
                          final res = await ServicesLocator.groomerHomeRepository.assignServiceGroomer(
                            bookingId: _booking.bookingId,
                            taskKey: taskKey,
                            groomerId: groomerId,
                            storeId: _booking.storeId,
                            currentBooking: _booking,
                          );
                          if (!mounted || !context.mounted) return;
                          if (res.success && res.updatedBooking != null) {
                            setState(() => _booking = res.updatedBooking!);
                            widget.onMilestoneSuccess?.call(res.updatedBooking!);
                            ToastUtil.showSuccessToast(context, res.message);
                            _loadStoreCatalogAndTimeline();
                          } else {
                            ToastUtil.showErrorToast(context, res.message);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Card 4: Completed & Skipped Services List (We)
                    if (_completedAndSkippedLabels.isNotEmpty) ...[
                      _buildCompletedAndSkippedBox(),
                      const SizedBox(height: 14),
                    ],

                    // Card 5: Update Each Booked Service (II)
                    if (_activeTasks.isNotEmpty) ...[
                      _buildActiveServicesList(),
                      const SizedBox(height: 14),
                    ],

                    // Card 6: Timeline Section (XC)
                    _buildTimelineCard(),
                    const SizedBox(height: 14),

                    // Card 7: Visit Steps Section (Sl)
                    _buildVisitStepsCard(stage),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Card Components
  // ─────────────────────────────────────────────────────────────────────────

  /// Card 1: Current Status Card with Teal/Brand Gradient
  Widget _buildCurrentStatusCard() {
    final statusText = _currentStatusText;
    final anyInProgress = _effectiveTasks.any((t) => t.isInProgress);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF115E59)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CURRENT STATUS',
                style: AppFonts.poppins(
                  size: 10.5,
                  weight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.75),
                  letterSpacing: 1.1,
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            statusText,
            style: AppFonts.parkinsans(
              size: 20,
              weight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          if (anyInProgress) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF5EEAD4)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Customer sees updates in their app instantly.',
                    style: AppFonts.poppins(
                      size: 11.5,
                      color: const Color(0xFFCCFBF1),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Card 2: Progress Overview
  Widget _buildProgressOverviewCard(int overallPct) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PROGRESS OVERVIEW',
                style: AppFonts.poppins(
                  size: 11,
                  weight: FontWeight.w700,
                  color: const Color(0xFF6B7280),
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                '$overallPct% Overall',
                style: AppFonts.poppins(
                  size: 11.5,
                  weight: FontWeight.w700,
                  color: const Color(0xFF0F766E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (overallPct.clamp(0, 100)) / 100.0,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
            ),
          ),
        ],
      ),
    );
  }

  /// Card 4: Completed & Skipped Services Box (We)
  Widget _buildCompletedAndSkippedBox() {
    final labels = _completedAndSkippedLabels;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: labels.map((label) {
          final isSkipped = label.contains('skipped');
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(
                  isSkipped ? Icons.skip_next_rounded : Icons.check_circle_rounded,
                  size: 16,
                  color: isSkipped ? const Color(0xFFD97706) : const Color(0xFF059669),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: AppFonts.poppins(
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: isSkipped ? const Color(0xFF92400E) : const Color(0xFF065F46),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Card 5: Update Each Booked Service List (II)
  Widget _buildActiveServicesList() {
    final tasks = _activeTasks;
    final viewerId = _viewerGroomerId;
    final isRestricted = _isRestrictedGroomerView && viewerId != null && tasks.any((t) => t.assignedGroomerId == viewerId);
    final title = isRestricted ? 'Your assigned services' : 'Update each booked service';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.checklist_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              title,
              style: AppFonts.parkinsans(
                size: 13.5,
                weight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...tasks.map((task) => _buildSingleTaskCard(task)),
      ],
    );
  }

  /// Individual Service Line Item Card matching Web Component II
  Widget _buildSingleTaskCard(ServiceProgressItem task) {
    final isSavingThis = _savingTaskKey == task.taskKey;
    final currentPercent = task.percent;
    final groomerName = task.assignedGroomerName ?? (task.assignedGroomerId != null ? 'Groomer #${task.assignedGroomerId}' : 'Not assigned');
    final durationStr = task.durationMinutes > 0 ? ' · ${task.durationMinutes} min booked' : '';
    final milestoneStr = task.milestoneKey != null && task.milestoneKey!.isNotEmpty ? ' · ${task.milestoneKey}' : '';
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final onPrimaryColor = theme.colorScheme.onPrimary;
    final canEdit = _canEditTask(task);
    final isPackageTask = RegExp(r'^pkg-(\d+)-svc-\d+(-sub-\d+)?$').hasMatch(task.taskKey);
    final nextPct = _progressPercentOptions.firstWhere(
      (f) => f > currentPercent,
      orElse: () => -1,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: canEdit ? const Color(0xFFE2E8F0) : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        opacity: canEdit ? 1.0 : 0.92,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.content_cut_rounded, size: 18, color: onPrimaryColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.label ?? task.taskName ?? 'Service',
                          style: AppFonts.parkinsans(
                            size: 14,
                            weight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Groomer: $groomerName$durationStr$milestoneStr',
                          style: AppFonts.poppins(
                            size: 11.5,
                            weight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (currentPercent > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$currentPercent%',
                        style: AppFonts.parkinsans(
                          size: 11.5,
                          weight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Read-only Banner (if assigned to another groomer and view-only)
            if (!canEdit)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'View only — assigned to ${task.assignedGroomerName ?? "another groomer"}. You can track progress here but cannot update this line.',
                        style: AppFonts.poppins(
                          size: 11,
                          weight: FontWeight.w500,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Card Body (Progress Indicator Xc + Controls)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress Indicator Top Row (Status & Percentage)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _getServiceSubtitle(task),
                          style: AppFonts.poppins(
                            size: 11.5,
                            weight: FontWeight.w500,
                            color: task.isSkipped ? const Color(0xFFB45309) : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        task.isSkipped ? '—' : (currentPercent <= 0 ? '·' : '$currentPercent%'),
                        style: AppFonts.parkinsans(
                          size: 15,
                          weight: FontWeight.w700,
                          color: task.isCompleted
                              ? const Color(0xFF059669)
                              : (currentPercent > 0 ? primaryColor : const Color(0xFF94A3B8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Progress Bar Track
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final fillRatio = (currentPercent.clamp(0, 100) / 100.0);
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            height: 8,
                            width: constraints.maxWidth * fillRatio,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              gradient: task.isCompleted
                                  ? const LinearGradient(
                                      colors: [Color(0xFF34D399), Color(0xFF059669)],
                                    )
                                  : LinearGradient(
                                      colors: [
                                        primaryColor.withValues(alpha: 0.85),
                                        primaryColor,
                                      ],
                                    ),
                              boxShadow: currentPercent > 0 && !task.isCompleted
                                  ? [
                                      BoxShadow(
                                        color: primaryColor.withValues(alpha: 0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Controls: Percentage Buttons & Skip (only when canEdit)
                  if (canEdit) ...[
                    const SizedBox(height: 12),
                    // 5 Percentage Buttons (Qv = [20, 40, 60, 80, 100])
                    Row(
                      children: _progressPercentOptions.map((pct) {
                        final isReached = currentPercent >= pct;
                        final isNextStep = !isReached && pct == nextPct;
                        final isSavingThisPct = isSavingThis && _savingPercent == pct;
                        final isOtherSaving = isSavingThis && _savingPercent != pct;
                        final label = pct == 100 ? 'Done' : '$pct%';

                        Color bgColor;
                        Color borderColor;
                        Color textColor;

                        if (isReached) {
                          bgColor = primaryColor;
                          borderColor = primaryColor;
                          textColor = onPrimaryColor;
                        } else if (isNextStep) {
                          bgColor = primaryColor.withValues(alpha: 0.08);
                          borderColor = primaryColor.withValues(alpha: 0.45);
                          textColor = primaryColor;
                        } else {
                          bgColor = Colors.white;
                          borderColor = const Color(0xFFE2E8F0);
                          textColor = const Color(0xFF475569);
                        }

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.5),
                            child: Opacity(
                              opacity: isOtherSaving ? 0.6 : 1.0,
                              child: InkWell(
                                onTap: (isSavingThis || _isSubmitting)
                                    ? null
                                    : () => _handleUpdateServiceProgress(task.taskKey, pct),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: borderColor,
                                      width: isNextStep ? 1.5 : (isReached ? 1.2 : 1.0),
                                    ),
                                    boxShadow: isReached
                                        ? [
                                            BoxShadow(
                                              color: primaryColor.withValues(alpha: 0.2),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isSavingThisPct) ...[
                                        SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              isReached ? onPrimaryColor : primaryColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        label,
                                        style: AppFonts.parkinsans(
                                          size: 11.5,
                                          weight: FontWeight.w700,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Skip Service Option
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFB45309),
                            side: const BorderSide(color: Color(0xFFFDE68A), width: 1.2),
                            backgroundColor: const Color(0xFFFFFBEB),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            minimumSize: const Size(0, 32),
                          ),
                          onPressed: (isSavingThis || _isSubmitting)
                              ? null
                              : () => _handleSkipService(task.taskKey),
                          icon: isSavingThis && _savingPercent == null
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB45309)),
                                  ),
                                )
                              : const Icon(Icons.skip_next_rounded, size: 15, color: Color(0xFFD97706)),
                          label: Text(
                            'Skip this service',
                            style: AppFonts.poppins(
                              size: 11.5,
                              weight: FontWeight.w600,
                              color: const Color(0xFFB45309),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isPackageTask
                                ? 'Package service: skip or update in any order.'
                                : 'Skip anytime — no order required. Mix completed and skipped services; checkout unlocks when all lines are done.',
                            style: AppFonts.poppins(
                              size: 10.5,
                              color: const Color(0xFF6B7280),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<StoreMilestoneConfig> get _timelineMilestones {
    final baseList = <StoreMilestoneConfig>[];
    final filtered = _storeCatalog.isNotEmpty
        ? GroomerMilestoneResolver.filterMilestonesForBooking(
            storeCatalog: _storeCatalog,
            booking: _booking,
          )
        : const <StoreMilestoneConfig>[];

    if (filtered.isNotEmpty) {
      baseList.addAll(filtered);
    } else {
      int order = 1;
      baseList.add(const StoreMilestoneConfig(
        key: 'check_in_completed',
        order: 1,
        title: 'Check-in Completed',
      ));
      for (final key in _booking.requiredMilestones) {
        if (key == GroomerMilestoneResolver.bathMilestone) {
          baseList.add(StoreMilestoneConfig(
            key: 'bath_completed',
            order: ++order,
            title: 'Bath Completed',
          ));
        } else if (key == GroomerMilestoneResolver.groomingMilestone) {
          baseList.add(StoreMilestoneConfig(
            key: 'grooming_completed',
            order: ++order,
            title: 'Grooming Completed',
          ));
        } else if (key != 'check_in_completed' && key != 'ready_for_checkout') {
          final title = key
              .replaceAll('_', ' ')
              .split(' ')
              .map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '')
              .join(' ');
          baseList.add(StoreMilestoneConfig(
            key: key,
            order: ++order,
            title: title,
          ));
        }
      }
      baseList.add(StoreMilestoneConfig(
        key: 'ready_for_checkout',
        order: ++order,
        title: 'Ready for Checkout',
      ));
      baseList.add(StoreMilestoneConfig(
        key: 'final_service_completed',
        order: ++order,
        title: 'Checkout & Payment',
      ));
    }

    // Append any completed dynamic milestones that aren't in baseList yet
    final dyn = _booking.milestoneRecord?.dynamicMilestones;
    if (dyn != null && dyn.isNotEmpty) {
      final existingKeys = baseList.map((m) => m.key).toSet();
      int insertIndex = baseList.indexWhere((m) => m.key == 'ready_for_checkout');
      if (insertIndex < 0) insertIndex = baseList.length;

      for (final entry in dyn.entries) {
        if (entry.value.completed && !existingKeys.contains(entry.key)) {
          final title = MilestoneConfig.forMilestone(entry.key).title;
          baseList.insert(
            insertIndex++,
            StoreMilestoneConfig(
              key: entry.key,
              order: 50,
              title: title,
            ),
          );
          existingKeys.add(entry.key);
        }
      }
    }

    return baseList;
  }

  /// Available store milestone options for the dropdown (matching Web Portal Ee = [m.groomerMilestoneOptions || jI(m, O)])
  List<({String key, String label})> get _availableStoreMilestoneOptions {
    final result = <({String key, String label})>[];
    final seenKeys = <String>{};

    bool isDone(String key) {
      if (_booking.isMilestoneDone(key)) return true;
      if (_timeline != null) {
        if (_timeline!.isMilestoneCompleted(key)) return true;
        for (final opt in _timeline!.groomerMilestoneOptions) {
          final optKey = opt['key']?.toString() ?? opt['milestoneKey']?.toString();
          if (optKey == key && (opt['completed'] == true || opt['isCompleted'] == true)) {
            return true;
          }
        }
      }
      return false;
    }

    bool isExcluded(String key) {
      final k = key.toLowerCase();
      return k == 'final_service_completed' ||
          k == 'final_checkout' ||
          k == 'ready_for_check_in' ||
          k == 'check_in' ||
          k == 'check_in_completed';
    }

    // 1. First priority: Backend timeline groomerMilestoneOptions (matching Web Portal Ee priority #1)
    if (_timeline != null && _timeline!.groomerMilestoneOptions.isNotEmpty) {
      for (final item in _timeline!.groomerMilestoneOptions) {
        final key = item['key']?.toString() ?? item['milestoneKey']?.toString() ?? '';
        final label = item['label']?.toString() ??
            item['title']?.toString() ??
            item['name']?.toString() ??
            MilestoneConfig.forMilestone(key).title;
        final completed = item['completed'] == true || item['isCompleted'] == true;

        if (key.isNotEmpty && !completed && !isExcluded(key) && !seenKeys.contains(key) && !isDone(key)) {
          seenKeys.add(key);
          result.add((key: key, label: label));
        }
      }
      if (result.isNotEmpty) return result;
    }

    // 2. Second priority: Timeline milestones from API (matching Web Portal jI(m, O))
    if (_timeline != null && _timeline!.milestones.isNotEmpty) {
      for (final m in _timeline!.milestones) {
        final key = m.milestoneKey;
        final label = MilestoneConfig.forMilestone(key).title;
        if (key.isNotEmpty &&
            !m.completed &&
            m.groomerSelectable &&
            !isExcluded(key) &&
            !seenKeys.contains(key) &&
            !isDone(key)) {
          seenKeys.add(key);
          result.add((key: key, label: label));
        }
      }
      if (result.isNotEmpty) return result;
    }

    // 3. Third priority: Filtered timeline milestones for this booking
    for (final config in _timelineMilestones) {
      final key = config.key;
      final label = config.displayTitle;
      if (key.isNotEmpty &&
          config.groomerSelectable &&
          !isExcluded(key) &&
          !seenKeys.contains(key) &&
          !isDone(key)) {
        seenKeys.add(key);
        result.add((key: key, label: label));
      }
    }

    // 4. Fourth priority: Applicable in-store groomerSelectable milestones from store catalog
    for (final config in _storeCatalog) {
      final key = config.key;
      final label = config.displayTitle;
      if (key.isNotEmpty &&
          config.groomerSelectable &&
          config.isInStoreAction &&
          GroomerMilestoneResolver.isConfigApplicableForBooking(config: config, booking: _booking) &&
          !isExcluded(key) &&
          !seenKeys.contains(key) &&
          !isDone(key)) {
        seenKeys.add(key);
        result.add((key: key, label: label));
      }
    }

    return result;
  }

  /// Card 6: Timeline Section (XC)
  Widget _buildTimelineCard() {
    final milestones = _timelineMilestones;

    final reassignments = _booking.serviceAssignmentActivity;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TIMELINE',
            style: AppFonts.poppins(
              size: 11,
              weight: FontWeight.w700,
              color: const Color(0xFF6B7280),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          ...milestones.map((m) {
            final isDone = _booking.isMilestoneDone(m.key);
            final timeStr = _booking.milestoneRecord?.getMilestoneOccurredAt(m.key);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: isDone ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      m.displayTitle,
                      style: AppFonts.poppins(
                        size: 12,
                        weight: isDone ? FontWeight.w600 : FontWeight.w400,
                        color: isDone ? const Color(0xFF111827) : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  if (timeStr != null && timeStr.isNotEmpty)
                    Text(
                      _formatTimestamp(timeStr),
                      style: AppFonts.poppins(size: 11, color: const Color(0xFF16A34A)),
                    ),
                ],
              ),
            );
          }),

          // Reassignment history if present
          if (reassignments.isNotEmpty) ...[
            const Divider(height: 20, color: Color(0xFFE5E7EB)),
            Text(
              'GROOMER REASSIGNMENTS',
              style: AppFonts.poppins(
                size: 10.5,
                weight: FontWeight.w700,
                color: const Color(0xFF6B7280),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            ...reassignments.take(5).map((entry) {
              final at = entry['at']?.toString() ?? '';
              final taskLabel = entry['taskLabel']?.toString() ?? 'Service';
              final toGroomer = entry['groomerName']?.toString() ?? 'Groomer';
              final wasGroomer = entry['previousGroomerName']?.toString();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${_formatTimestamp(at)} · $taskLabel → $toGroomer${wasGroomer != null ? ' (was $wasGroomer)' : ''}',
                  style: AppFonts.poppins(size: 11, color: const Color(0xFF4B5563)),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// Card 7: Stage-based Visit Steps (Sl)
  Widget _buildVisitStepsCard(String stage) {
    final availableMilestones = _availableStoreMilestoneOptions;
    final validSelectedValue = availableMilestones.any((m) => m.key == _selectedStoreMilestone)
        ? _selectedStoreMilestone
        : null;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final onPrimaryColor = theme.colorScheme.onPrimary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.playlist_add_check_rounded, size: 18, color: primaryColor),
              const SizedBox(width: 8),
              Text(
                'Visit steps',
                style: AppFonts.poppins(
                  size: 13.5,
                  weight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stage: check_in
          if (stage == 'check_in') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    CheckboxListTile(
                      title: Text(
                        'Vaccination verified',
                        style: AppFonts.poppins(size: 12.5, weight: FontWeight.w600, color: const Color(0xFF78350F)),
                      ),
                      value: _vaccinationVerified,
                      onChanged: (val) => setState(() => _vaccinationVerified = val ?? true),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: primaryColor,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      title: Text(
                        'Health check verified',
                        style: AppFonts.poppins(size: 12.5, weight: FontWeight.w600, color: const Color(0xFF78350F)),
                      ),
                      value: _healthCheckVerified,
                      onChanged: (val) => setState(() => _healthCheckVerified = val ?? true),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: primaryColor,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: onPrimaryColor,
                  disabledBackgroundColor: const Color(0xFFE5E7EB),
                  disabledForegroundColor: const Color(0xFF9CA3AF),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _isSubmitting ? null : _handleCheckIn,
                icon: _isSubmitting
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: onPrimaryColor))
                    : Icon(Icons.how_to_reg_rounded, size: 18, color: onPrimaryColor),
                label: Text(
                  _isSubmitting ? 'Checking in...' : 'Check In',
                  style: AppFonts.parkinsans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: _isSubmitting ? const Color(0xFF9CA3AF) : onPrimaryColor,
                  ),
                ),
              ),
            ),
          ],

          // Stage: service_progress
          if (stage == 'service_progress') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF6B7280)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Finish or skip every booked service below. Ready for checkout appears when all are done.',
                      style: AppFonts.poppins(size: 11.5, color: const Color(0xFF4B5563)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Stage: ready_checkout
          if (stage == 'ready_checkout') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: onPrimaryColor,
                  disabledBackgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                  disabledForegroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.38),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _isSubmitting ? null : _handleReadyForCheckout,
                icon: _isSubmitting
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: onPrimaryColor))
                    : Icon(Icons.shopping_bag_outlined, size: 18, color: onPrimaryColor),
                label: Text(
                  _isSubmitting ? 'Updating...' : 'Ready for checkout',
                  style: AppFonts.parkinsans(size: 13, weight: FontWeight.w600, color: onPrimaryColor),
                ),
              ),
            ),
          ],

          // Stage: await_customer_tip
          if (stage == 'await_customer_tip') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Waiting for customer',
                    style: AppFonts.poppins(size: 13, weight: FontWeight.w700, color: const Color(0xFF78350F)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Only the customer sets tip and card/cash in their app. Tip & payment on the timeline updates when they tap Confirm checkout. This screen refreshes automatically.',
                    style: AppFonts.poppins(size: 11.5, color: const Color(0xFF92400E)),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: _loadStoreCatalogAndTimeline,
                    icon: Icon(Icons.refresh_rounded, size: 16, color: primaryColor),
                    label: Text(
                      'Refresh status',
                      style: AppFonts.poppins(size: 12, weight: FontWeight.w600, color: primaryColor),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Stage: final_checkout
          if (stage == 'final_checkout') ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer confirmed checkout',
                    style: AppFonts.poppins(size: 13, weight: FontWeight.w700, color: const Color(0xFF065F46)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tip \$${_tipAmount.toStringAsFixed(2)} · Pay with $_customerPaymentMethod. Complete payment below to finish the visit.',
                    style: AppFonts.poppins(size: 11.5, color: const Color(0xFF047857)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete visit (checkout)',
                    style: AppFonts.poppins(size: 13, weight: FontWeight.w700, color: const Color(0xFF166534)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tip (customer)', style: AppFonts.poppins(size: 12, color: const Color(0xFF4B5563))),
                      Text('\$${_tipAmount.toStringAsFixed(2)}', style: AppFonts.poppins(size: 12, weight: FontWeight.w700, color: const Color(0xFF111827))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Pay with', style: AppFonts.poppins(size: 12, color: const Color(0xFF4B5563))),
                      Text(_customerPaymentMethod.toUpperCase(), style: AppFonts.poppins(size: 12, weight: FontWeight.w700, color: const Color(0xFF111827))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: onPrimaryColor,
                        disabledBackgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                        disabledForegroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.38),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _isSubmitting ? null : _handleFinalCheckout,
                      icon: _isSubmitting
                          ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: onPrimaryColor))
                          : Icon(Icons.check_circle_rounded, size: 18, color: onPrimaryColor),
                      label: Text(
                        _isSubmitting ? 'Completing...' : 'Visit completed',
                        style: AppFonts.parkinsans(size: 13, weight: FontWeight.w600, color: onPrimaryColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Stage: done
          if (stage == 'done') ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF059669)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All Milestones Completed!',
                      style: AppFonts.parkinsans(size: 13.5, weight: FontWeight.w700, color: const Color(0xFF065F46)),
                    ),
                  ),
                ],
              ),
            ),
          ],


          // Milestone Notes input (Optional)
          const SizedBox(height: 14),
          Text(
            'Milestone Notes (Optional)',
            style: AppFonts.poppins(size: 12.5, weight: FontWeight.w600, color: const Color(0xFF374151)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController,
            maxLines: 2,
            style: AppFonts.poppins(size: 12.5, color: const Color(0xFF111827)),
            decoration: InputDecoration(
              hintText: 'Visible on milestone record',
              hintStyle: AppFonts.poppins(size: 12, color: const Color(0xFF9CA3AF)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: primaryColor, width: 1.5)),
            ),
          ),

          // Update any store milestone dropdown (Ee)
          if (availableMilestones.isNotEmpty && stage != 'done' && stage != 'check_in') ...[
            const SizedBox(height: 14),
            Text(
              'Update any store milestone',
              style: AppFonts.poppins(
                size: 12.5,
                weight: FontWeight.w600,
                color: const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: validSelectedValue != null
                            ? primaryColor
                            : const Color(0xFFE5E7EB),
                        width: validSelectedValue != null ? 1.5 : 1.0,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: validSelectedValue,
                        hint: Text(
                          'Select milestone…',
                          style: AppFonts.poppins(size: 12.5, color: const Color(0xFF9CA3AF)),
                        ),
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: validSelectedValue != null
                              ? primaryColor
                              : const Color(0xFF6B7280),
                        ),
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        isExpanded: true,
                        items: availableMilestones.map((c) {
                          return DropdownMenuItem<String>(
                            value: c.key,
                            child: Text(
                              c.label,
                              style: AppFonts.poppins(
                                size: 12.5,
                                weight: FontWeight.w500,
                                color: const Color(0xFF111827),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (val) => setState(() => _selectedStoreMilestone = val),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: onPrimaryColor,
                      disabledBackgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                      disabledForegroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.38),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: validSelectedValue == null || _isSubmitting
                        ? null
                        : () => _handleApplyStoreMilestone(validSelectedValue),
                    child: _isSubmitting
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: onPrimaryColor),
                          )
                        : Text(
                            'Apply',
                            style: AppFonts.parkinsans(
                              size: 13,
                              weight: FontWeight.w600,
                              color: validSelectedValue == null
                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
                                  : onPrimaryColor,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerNotesCard(String notes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sticky_note_2_outlined, size: 16, color: Color(0xFFD97706)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer Request:',
                  style: AppFonts.poppins(
                    size: 11,
                    weight: FontWeight.w700,
                    color: const Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notes.startsWith('"') ? notes : '"$notes"',
                  style: AppFonts.poppins(
                    size: 11.5,
                    color: const Color(0xFF78350F),
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalNotesCard(String notes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.medical_services_outlined, size: 16, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Medical Alert:',
                  style: AppFonts.poppins(
                    size: 11,
                    weight: FontWeight.w700,
                    color: const Color(0xFFB91C1C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notes.startsWith('"') ? notes : '"$notes"',
                  style: AppFonts.poppins(
                    size: 11.5,
                    color: const Color(0xFF991B1B),
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorBathNotesCard(String notes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bath Note Recorded:',
                  style: AppFonts.poppins(
                    size: 11,
                    weight: FontWeight.w600,
                    color: const Color(0xFF1E40AF),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notes.startsWith('"') ? notes : '"$notes"',
                  style: AppFonts.poppins(
                    size: 12,
                    color: const Color(0xFF1E3A8A),
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('h:mm a').format(dt.toLocal());
    } catch (_) {
      return raw;
    }
  }
}
