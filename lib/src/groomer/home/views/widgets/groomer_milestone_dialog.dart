import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shear_heaven_pet_spa/src/common/services/services_locator.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/toast_util.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_booking.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_milestone_record.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/store_milestone_config.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/utils/groomer_milestone_resolver.dart';

enum MilestoneType {
  bath,
  grooming,
}

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
  late String _activeMilestoneKey;
  late final TextEditingController _notesController;
  bool _isSubmitting = false;
  bool _isLoadingCatalog = false;
  List<StoreMilestoneConfig> _storeCatalog = const [];
  BookingMilestoneTimeline? _timeline;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;

    // Determine initial active milestone dynamically
    final requiredKeys = _booking.requiredMilestones;
    if (widget.initialMilestoneKey != null && widget.initialMilestoneKey!.isNotEmpty) {
      _activeMilestoneKey = widget.initialMilestoneKey!;
    } else if (widget.milestoneType != null) {
      final key = widget.milestoneType == MilestoneType.bath
          ? GroomerMilestoneResolver.bathMilestone
          : GroomerMilestoneResolver.groomingMilestone;
      if (requiredKeys.contains(key)) {
        _activeMilestoneKey = key;
      } else {
        _activeMilestoneKey = _booking.nextPendingMilestone ?? requiredKeys.first;
      }
    } else {
      _activeMilestoneKey = _booking.nextPendingMilestone ??
          (requiredKeys.isNotEmpty ? requiredKeys.first : GroomerMilestoneResolver.bathMilestone);
    }

    _notesController = TextEditingController(text: _getNoteForMilestone(_activeMilestoneKey) ?? '');

    // Fetch store-based milestone configuration and timeline asynchronously
    _loadStoreCatalogAndTimeline();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadStoreCatalogAndTimeline() async {
    final cached = ServicesLocator.groomerHomeRepository.getCachedMilestonesCatalog(_booking.storeId);
    if (cached != null && cached.isNotEmpty) {
      if (mounted) {
        setState(() {
          _storeCatalog = cached;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingCatalog = true);
    }

    try {
      final catalogFuture = ServicesLocator.groomerHomeRepository.getMilestonesCatalog(
        storeId: _booking.storeId.isNotEmpty ? _booking.storeId : null,
      );
      final timelineFuture = ServicesLocator.groomerHomeRepository.getMilestonesTimeline(
        _booking.bookingId,
        storeId: _booking.storeId.isNotEmpty ? _booking.storeId : null,
      );

      final results = await Future.wait([catalogFuture, timelineFuture]);
      if (!mounted) return;

      final fetchedCatalog = results[0] as List<StoreMilestoneConfig>? ?? [];
      final fetchedTimeline = results[1] as BookingMilestoneTimeline?;

      setState(() {
        if (fetchedCatalog.isNotEmpty) {
          _storeCatalog = fetchedCatalog;
        }
        if (fetchedTimeline != null) {
          _timeline = fetchedTimeline;
          final updatedRecord = GroomerMilestoneRecord.fromTimelineResponse(fetchedTimeline);
          _booking = _booking.copyWith(milestoneRecord: updatedRecord);
        }
        _isLoadingCatalog = false;

        // If active milestone is not in in-store list, align to first pending or available
        final inStore = _inStoreMilestones;
        if (inStore.isNotEmpty && !inStore.any((m) => m.key == _activeMilestoneKey)) {
          final pending = inStore.firstWhere(
            (m) => !_booking.isMilestoneDone(m.key),
            orElse: () => inStore.first,
          );
          _activeMilestoneKey = pending.key;
          _notesController.text = _getNoteForMilestone(_activeMilestoneKey) ?? '';
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingCatalog = false);
    }
  }

  /// In-store actions only, grouped and ordered according to API configuration.
  /// Strictly excludes pre-store (ready_for_check_in), customer actions (tip), and final checkout.
  List<StoreMilestoneConfig> get _inStoreMilestones {
    List<StoreMilestoneConfig> catalog;
    if (_storeCatalog.isNotEmpty) {
      catalog = _storeCatalog.where((m) => m.isInStoreAction).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
    } else {
      // Graceful fallback to booking-specific required in-store milestones
      final list = <StoreMilestoneConfig>[];
      int order = 2;
      list.add(StoreMilestoneConfig(
        key: 'check_in_completed',
        order: order++,
        phase: 'in_store',
        action: 'CheckInCompleted',
        status: 'DogServiceInProgress',
        groomerSelectable: true,
        requiresCheckInPayload: true,
      ));
      for (final key in _booking.requiredMilestones) {
        if (key == GroomerMilestoneResolver.bathMilestone) {
          list.add(StoreMilestoneConfig(
            key: 'bath_completed',
            order: order++,
            phase: 'in_store',
            action: 'CheckInCompleted',
            status: 'BathCompleted',
            groomerSelectable: true,
          ));
        } else if (key == GroomerMilestoneResolver.groomingMilestone) {
          list.add(StoreMilestoneConfig(
            key: 'grooming_completed',
            order: order++,
            phase: 'in_store',
            action: 'CheckInCompleted',
            status: 'GroomingCompleted',
            groomerSelectable: true,
          ));
        } else {
          list.add(StoreMilestoneConfig(
            key: key,
            order: order++,
            phase: 'in_store',
            action: 'CustomStep',
            status: key,
            groomerSelectable: true,
          ));
        }
      }
      list.add(StoreMilestoneConfig(
        key: 'ready_for_checkout',
        order: order++,
        phase: 'in_store',
        action: 'ServiceCompleted',
        status: 'ReadyForCheckout',
        groomerSelectable: true,
      ));
      catalog = list;
    }

    // Combine store configuration with booking services & eliminate duplicate milestones
    return GroomerMilestoneResolver.filterMilestonesForBooking(
      storeCatalog: catalog,
      booking: _booking,
    );
  }

  StoreMilestoneConfig _getConfigForMilestone(String key) {
    try {
      return _inStoreMilestones.firstWhere((m) => m.key == key);
    } catch (_) {
      return StoreMilestoneConfig(
        key: key,
        order: 0,
        phase: 'in_store',
        action: 'CheckInCompleted',
        status: key,
        groomerSelectable: true,
      );
    }
  }

  String? _getNoteForMilestone(String key) {
    return _booking.milestoneRecord?.getMilestoneNotes(key) ??
        (key == GroomerMilestoneResolver.bathMilestone
            ? _booking.bathNotes
            : (key == GroomerMilestoneResolver.groomingMilestone ? _booking.groomingNotes : null));
  }

  String? _getTimestampForMilestone(String key) {
    return _booking.milestoneRecord?.getMilestoneOccurredAt(key) ??
        (key == GroomerMilestoneResolver.bathMilestone
            ? _booking.bathCompletedAt
            : (key == GroomerMilestoneResolver.groomingMilestone ? _booking.groomingCompletedAt : null));
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

  void _selectMilestone(String key) {
    if (_activeMilestoneKey == key) return;
    setState(() {
      _activeMilestoneKey = key;
      _notesController.text = _getNoteForMilestone(key) ?? '';
    });
  }

  bool _isMilestonePrerequisiteMet(String key) {
    // Check-in Completed is mandatory and cannot be bypassed
    if (!_booking.isCheckedIn && key != 'check_in_completed') {
      return false;
    }

    // Backend-defined allowedNextKeys check if present
    if (_timeline != null && _timeline!.allowedNextKeys.isNotEmpty) {
      if (_timeline!.allowedNextKeys.contains(key)) return true;
    }

    // Intermediate milestones may be skipped once pet is checked in
    final config = _getConfigForMilestone(key);
    if (config.isSkippable) {
      return true;
    }

    if (key == GroomerMilestoneResolver.bathMilestone) {
      return _booking.canCompleteBath || _booking.isBathCompleted;
    }
    if (key == GroomerMilestoneResolver.groomingMilestone) {
      // Intermediate milestones can be skipped when permitted
      return true;
    }
    if (key == 'ready_for_checkout' || key == 'readyforcheckout') {
      return _booking.areRequiredMilestonesCompleted ||
          (_timeline?.canSkipToReadyForCheckout ?? true) ||
          _booking.isCheckedIn;
    }
    return true;
  }

  Future<void> _submitMilestone() async {
    if (_isSubmitting) return;

    final activeConfig = _getConfigForMilestone(_activeMilestoneKey);

    // Enforce mandatory Check-in completion rule
    if (activeConfig.isCheckIn && !_booking.isCheckedIn) {
      ToastUtil.showInfoToast(context, 'Please complete the pet check-in checklist first.');
      return;
    }

    if (!_booking.isCheckedIn && !activeConfig.isCheckIn) {
      ToastUtil.showErrorToast(
        context,
        'Check-in Completed is mandatory and must be completed before updating service milestones.',
      );
      return;
    }

    // Determine if intermediate milestones are being skipped directly
    final bool isSkipping = !_booking.areRequiredMilestonesCompleted &&
        (activeConfig.isReadyForCheckout ||
            _activeMilestoneKey == 'grooming_completed' ||
            _activeMilestoneKey == 'ready_for_checkout');

    setState(() => _isSubmitting = true);

    try {
      final res = await ServicesLocator.groomerHomeRepository.updateServiceMilestone(
        bookingId: _booking.bookingId,
        milestone: _activeMilestoneKey,
        action: activeConfig.action.isNotEmpty ? activeConfig.action : null,
        status: activeConfig.status.isNotEmpty ? activeConfig.status : null,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        booking: _booking,
        storeId: _booking.storeId,
        skipMilestones: isSkipping,
      );

      if (!mounted) return;

      if (res.success) {
        ToastUtil.showSuccessToast(context, res.message);
        final updated = res.updatedBooking ??
            _booking.copyWith(
              status: _activeMilestoneKey,
              milestoneRecord: res.milestoneRecord,
            );

        setState(() {
          _booking = updated;
          if (res.timeline != null) {
            _timeline = res.timeline;
          }
          final next = updated.nextPendingMilestone;
          if (next != null) {
            _activeMilestoneKey = next;
            _notesController.text = _getNoteForMilestone(next) ?? '';
          }
        });

        widget.onMilestoneSuccess?.call(updated);
      } else {
        ToastUtil.showErrorToast(context, res.message);
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.showErrorToast(context, 'Failed to update milestone: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleReadyForCheckout({bool skipMilestones = false}) async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final res = await ServicesLocator.groomerHomeRepository.markReadyForCheckoutDetails(
        bookingId: _booking.bookingId,
        booking: _booking,
        skipMilestones: skipMilestones,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      if (!mounted) return;

      if (res.success) {
        ToastUtil.showSuccessToast(context, res.message);
        final updated = res.updatedBooking ?? _booking.copyWith(status: 'ready_for_checkout');
        widget.onMilestoneSuccess?.call(updated);
        Navigator.of(context).pop(updated);
      } else {
        ToastUtil.showErrorToast(context, res.message);
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.showErrorToast(context, 'Failed to mark ready for checkout: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final booking = _booking;
    final activeConfig = _getConfigForMilestone(_activeMilestoneKey);
    final milestoneConfig = MilestoneConfig.forMilestone(_activeMilestoneKey);
    final isActiveDone = booking.isMilestoneDone(_activeMilestoneKey);
    final allRequiredDone = booking.areRequiredMilestonesCompleted;

    final headerTitle = allRequiredDone
        ? 'Milestones Completed'
        : activeConfig.displayTitle;
    final headerSubtitle = allRequiredDone
        ? 'All required service milestones completed for this booking'
        : (activeConfig.description ?? milestoneConfig.subtitle);
    final headerIcon = allRequiredDone
        ? Icons.verified_rounded
        : activeConfig.icon;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
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
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (allRequiredDone ? const Color(0xFF10B981) : const Color(0xFF0F766E))
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      headerIcon,
                      size: 22,
                      color: allRequiredDone ? const Color(0xFF10B981) : const Color(0xFF0F766E),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          headerTitle,
                          style: AppFonts.parkinsans(
                            size: 16,
                            weight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          headerSubtitle,
                          style: AppFonts.poppins(
                            size: 11.5,
                            color: const Color(0xFF6B7280),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF9CA3AF)),
                    onPressed: () => Navigator.of(context).pop(_booking),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dynamic Service Stage Tracker
                    _buildDynamicStageTracker(booking),
                    const SizedBox(height: 16),

                    // Pet Info Header Card
                    _buildPetInfoCard(booking),
                    const SizedBox(height: 14),

                    // Customer Special Instructions (if present)
                    if (booking.hasSpecialInstructions) ...[
                      _buildCustomerNotesCard(booking.specialInstructions!),
                      const SizedBox(height: 12),
                    ],

                    // Pet Medical Alert Notes (if present)
                    if (booking.hasPetMedicalNotes) ...[
                      _buildMedicalNotesCard(booking.petMedicalNotes!),
                      const SizedBox(height: 12),
                    ],

                    // Mandatory Check-in Alert Banner if not checked in
                    if (!booking.isCheckedIn) ...[
                      _buildMandatoryCheckInBanner(),
                      const SizedBox(height: 14),
                    ],

                    // Section Title: Dynamic In-Store Milestone Dropdown
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select In-Store Action',
                          style: AppFonts.poppins(
                            size: 13,
                            weight: FontWeight.w700,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                        if (_isLoadingCatalog)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Dynamic In-Store Dropdown
                    _buildDynamicMilestoneDropdown(),
                    const SizedBox(height: 16),

                    // Dynamic Required Milestones List
                    _buildRequiredMilestonesList(booking),
                    const SizedBox(height: 16),

                    // Milestone Action Area
                    if (allRequiredDone)
                      _buildAllMilestonesCompletedBanner(booking)
                    else if (!isActiveDone)
                      _buildActiveMilestoneInput(booking, activeConfig, milestoneConfig)
                    else
                      _buildCompletedMilestoneView(booking, activeConfig),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMandatoryCheckInBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFB45309)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Check-in Completed is Mandatory',
                  style: AppFonts.poppins(
                    size: 12.5,
                    weight: FontWeight.w700,
                    color: const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pets must be checked in at the store before in-store grooming milestones can be progressed.',
                  style: AppFonts.poppins(
                    size: 11.5,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Dynamic Dropdown containing only configured in-store actions.
  /// Explicitly excludes pre-store, customer tip confirmation, and final checkout.
  Widget _buildDynamicMilestoneDropdown() {
    final inStoreList = _inStoreMilestones;
    if (inStoreList.isEmpty) return const SizedBox.shrink();

    final hasActiveKey = inStoreList.any((m) => m.key == _activeMilestoneKey);
    final selectedKey = hasActiveKey ? _activeMilestoneKey : inStoreList.first.key;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0F766E), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedKey,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Color(0xFF0F766E)),
          borderRadius: BorderRadius.circular(14),
          items: inStoreList.map((config) {
            final isDone = _booking.isMilestoneDone(config.key);
            final isCurrent = config.key == _activeMilestoneKey;
            return DropdownMenuItem<String>(
              value: config.key,
              child: Row(
                children: [
                  Icon(
                    isDone ? Icons.check_circle_rounded : config.icon,
                    size: 18,
                    color: isDone
                        ? const Color(0xFF16A34A)
                        : (isCurrent ? const Color(0xFF0F766E) : const Color(0xFF6B7280)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      config.displayTitle,
                      style: AppFonts.poppins(
                        size: 13,
                        weight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: const Color(0xFF111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isDone)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Done',
                        style: AppFonts.poppins(
                          size: 10,
                          weight: FontWeight.w600,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    )
                  else if (config.isSkippable)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Skippable',
                        style: AppFonts.poppins(
                          size: 9.5,
                          weight: FontWeight.w600,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) _selectMilestone(val);
          },
        ),
      ),
    );
  }

  Widget _buildDynamicStageTracker(GroomerBooking booking) {
    final stages = <({String label, bool isDone, bool isCurrent})>[
      (label: 'Check-in', isDone: booking.isCheckedIn, isCurrent: false),
    ];

    for (final milestone in _inStoreMilestones) {
      if (milestone.isCheckIn || milestone.isReadyForCheckout) continue;
      final isDone = booking.isMilestoneDone(milestone.key);
      final isCurrent = _activeMilestoneKey == milestone.key && !isDone;
      stages.add((label: milestone.shortLabel, isDone: isDone, isCurrent: isCurrent));
    }

    stages.add((
      label: 'Checkout',
      isDone: booking.isReadyForCheckout || booking.isCompleted,
      isCurrent: booking.areRequiredMilestonesCompleted && !booking.isReadyForCheckout,
    ));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(stages.length, (i) {
            final stage = stages[i];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: stage.isCurrent
                        ? const Color(0xFF0F766E)
                        : (stage.isDone ? const Color(0xFF10B981) : const Color(0xFFE5E7EB)),
                  ),
                  child: Center(
                    child: stage.isDone && !stage.isCurrent
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: stage.isCurrent ? Colors.white : const Color(0xFF6B7280),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  stage.label,
                  style: AppFonts.poppins(
                    size: 11.5,
                    weight: stage.isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: stage.isCurrent ? const Color(0xFF0F766E) : const Color(0xFF4B5563),
                  ),
                ),
                if (i < stages.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: Colors.grey.shade400,
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildRequiredMilestonesList(GroomerBooking booking) {
    final list = _inStoreMilestones;
    final completedCount = list.where((m) => booking.isMilestoneDone(m.key)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Configured In-Store Milestones',
              style: AppFonts.poppins(
                size: 13,
                weight: FontWeight.w700,
                color: const Color(0xFF1F2937),
              ),
            ),
            Text(
              '$completedCount/${list.length} Completed',
              style: AppFonts.poppins(
                size: 11.5,
                weight: FontWeight.w600,
                color: completedCount == list.length
                    ? const Color(0xFF10B981)
                    : const Color(0xFF0F766E),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...list.map((config) {
          final isSelected = _activeMilestoneKey == config.key;
          final isDone = booking.isMilestoneDone(config.key);
          final isPrereqMet = _isMilestonePrerequisiteMet(config.key);
          final note = _getNoteForMilestone(config.key);
          final timestamp = _getTimestampForMilestone(config.key);

          return GestureDetector(
            onTap: () => _selectMilestone(config.key),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF0FDFA) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF0F766E)
                      : (isDone ? const Color(0xFFBBF7D0) : const Color(0xFFE5E7EB)),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDone
                              ? const Color(0xFFDCFCE7)
                              : (isSelected
                                  ? const Color(0xFF0F766E).withValues(alpha: 0.1)
                                  : const Color(0xFFF3F4F6)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isDone ? Icons.check_circle_rounded : config.icon,
                          size: 18,
                          color: isDone
                              ? const Color(0xFF16A34A)
                              : (isSelected ? const Color(0xFF0F766E) : const Color(0xFF6B7280)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              config.displayTitle,
                              style: AppFonts.parkinsans(
                                size: 13,
                                weight: FontWeight.w600,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            if (timestamp != null && timestamp.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Recorded at ${_formatTimestamp(timestamp)}',
                                style: AppFonts.poppins(
                                  size: 10.5,
                                  color: const Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDone
                              ? const Color(0xFFDCFCE7)
                              : (!isPrereqMet
                                  ? const Color(0xFFF3F4F6)
                                  : (isSelected ? const Color(0xFFCCFBF1) : const Color(0xFFE5E7EB))),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isDone
                              ? '✓ Done'
                              : (!isPrereqMet
                                  ? 'Locked'
                                  : (isSelected ? 'Active' : 'Pending')),
                          style: AppFonts.poppins(
                            size: 10.5,
                            weight: FontWeight.w600,
                            color: isDone
                                ? const Color(0xFF15803D)
                                : (!isPrereqMet
                                    ? const Color(0xFF9CA3AF)
                                    : (isSelected ? const Color(0xFF0F766E) : const Color(0xFF4B5563))),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (note != null && note.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        'Note: "$note"',
                        style: AppFonts.poppins(
                          size: 11,
                          color: const Color(0xFF374151),
                        ).copyWith(fontStyle: FontStyle.italic),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActiveMilestoneInput(
    GroomerBooking booking,
    StoreMilestoneConfig config,
    MilestoneConfig milestoneConfig,
  ) {
    final isPrereqMet = _isMilestonePrerequisiteMet(_activeMilestoneKey);
    final isSkipping = !booking.areRequiredMilestonesCompleted &&
        (config.isReadyForCheckout || _activeMilestoneKey == 'ready_for_checkout');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isSkipping) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Skipping intermediate milestones directly to ${config.displayTitle}.',
                    style: AppFonts.poppins(
                      size: 11.5,
                      weight: FontWeight.w600,
                      color: const Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Prior Bath Notes if active milestone is Grooming
        if (_activeMilestoneKey == 'grooming_completed' &&
            booking.bathNotes != null &&
            booking.bathNotes!.trim().isNotEmpty) ...[
          Container(
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
                        '"${booking.bathNotes}"',
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
          ),
          const SizedBox(height: 12),
        ],

        // Optional Milestone Notes input
        Text(
          'Milestone Notes (Optional)',
          style: AppFonts.poppins(
            size: 13,
            weight: FontWeight.w600,
            color: const Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Record observations, shampoo/coat notes, or styling details for ${config.displayTitle}',
          style: AppFonts.poppins(
            size: 11.5,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 3,
          maxLength: 300,
          enabled: isPrereqMet && !_isSubmitting,
          style: AppFonts.poppins(size: 13, color: const Color(0xFF111827)),
          decoration: InputDecoration(
            hintText: 'e.g., Service stage notes or observations...',
            hintStyle: AppFonts.poppins(size: 12.5, color: const Color(0xFF9CA3AF)),
            filled: true,
            fillColor: isPrereqMet ? const Color(0xFFF9FAFB) : const Color(0xFFF3F4F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4B5563),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(_booking),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Cancel',
                    style: AppFonts.poppins(
                      size: 13,
                      weight: FontWeight.w600,
                      color: const Color(0xFF4B5563),
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPrereqMet ? const Color(0xFF0F766E) : const Color(0xFF9CA3AF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: (!isPrereqMet || _isSubmitting) ? null : _submitMilestone,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(config.icon, size: 18, color: Colors.white),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _isSubmitting
                        ? 'Saving...'
                        : 'Confirm ${config.displayTitle}',
                    style: AppFonts.poppins(
                      size: 13,
                      weight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_booking.isCheckedIn && !_booking.areRequiredMilestonesCompleted && !config.isReadyForCheckout) ...[
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB45309),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: _isSubmitting ? null : () => _handleReadyForCheckout(skipMilestones: true),
              icon: const Icon(Icons.fast_forward_rounded, size: 16, color: Color(0xFFD97706)),
              label: Text(
                'Busy? Skip intermediate steps & move to Ready for Checkout',
                style: AppFonts.poppins(
                  size: 11.5,
                  weight: FontWeight.w600,
                  color: const Color(0xFFB45309),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompletedMilestoneView(GroomerBooking booking, StoreMilestoneConfig config) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF16A34A)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${config.displayTitle} is already recorded for this appointment.',
                  style: AppFonts.poppins(
                    size: 12,
                    weight: FontWeight.w600,
                    color: const Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4B5563),
              side: const BorderSide(color: Color(0xFFD1D5DB)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(_booking),
            child: Text(
              'Close',
              style: AppFonts.poppins(
                size: 13,
                weight: FontWeight.w600,
                color: const Color(0xFF4B5563),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAllMilestonesCompletedBanner(GroomerBooking booking) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 24,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All Milestones Completed!',
                      style: AppFonts.parkinsans(
                        size: 14,
                        weight: FontWeight.w700,
                        color: const Color(0xFF15803D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pet service is complete. You can advance to Ready for Checkout.',
                      style: AppFonts.poppins(
                        size: 11.5,
                        color: const Color(0xFF166534),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!booking.isReadyForCheckout) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: _isSubmitting ? null : () => _handleReadyForCheckout(),
                icon: const Icon(Icons.shopping_bag_outlined, size: 18, color: Colors.white),
                label: Text(
                  _isSubmitting ? 'Updating...' : 'Mark Ready for Checkout',
                  style: AppFonts.poppins(
                    size: 13,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPetInfoCard(GroomerBooking booking) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.1),
            child: Text(
              booking.petName.isNotEmpty ? booking.petName[0].toUpperCase() : 'P',
              style: AppFonts.parkinsans(
                size: 16,
                weight: FontWeight.w700,
                color: const Color(0xFF0F766E),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      booking.petName,
                      style: AppFonts.parkinsans(
                        size: 14,
                        weight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    if (booking.breed.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '• ${booking.breed}',
                        style: AppFonts.poppins(
                          size: 12,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  booking.packageName?.isNotEmpty == true
                      ? booking.packageName!
                      : booking.serviceName,
                  style: AppFonts.poppins(
                    size: 11.5,
                    weight: FontWeight.w500,
                    color: const Color(0xFF0F766E),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
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
}
