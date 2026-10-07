import 'package:flutter/material.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_schedule_models.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/views/widgets/schedule/time_picker_selector.dart';

class BreakScheduleDialog extends StatefulWidget {
  final String dayOfWeek;
  final GroomerBreak? initialBreak;
  final String groomerCode;
  final int workingStartMin;
  final int workingEndMin;

  const BreakScheduleDialog({
    super.key,
    required this.dayOfWeek,
    this.initialBreak,
    required this.groomerCode,
    this.workingStartMin = 540,
    this.workingEndMin = 1020,
  });

  @override
  State<BreakScheduleDialog> createState() => _BreakScheduleDialogState();
}

class _BreakScheduleDialogState extends State<BreakScheduleDialog> {
  late String _startTime;
  late String _endTime;
  late String _reason;
  late TextEditingController _customReasonController;
  bool _isCustomReason = false;
  String? _validationError;

  final List<String> _commonReasons = [
    'Lunch break',
    'Short break',
    'Tea break',
    'Personal errand',
    'Doctor appointment',
  ];

  @override
  void initState() {
    super.initState();
    _startTime = widget.initialBreak?.startTime ?? '13:00';
    _endTime = widget.initialBreak?.endTime ?? '14:00';
    _reason = widget.initialBreak?.reason ?? 'Lunch break';

    _isCustomReason = !_commonReasons.contains(_reason);
    _customReasonController = TextEditingController(
      text: _isCustomReason ? _reason : '',
    );
    _validateTimes();
  }

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  void _validateTimes() {
    final startMin = timeToMinutes(_startTime);
    final endMin = timeToMinutes(_endTime);

    setState(() {
      if (startMin >= endMin) {
        _validationError = 'Start time must be before end time.';
      } else if (startMin < widget.workingStartMin || endMin > widget.workingEndMin) {
        _validationError = 'Break must fall within working hours.';
      } else {
        _validationError = null;
      }
    });
  }

  void _handleSave() {
    final startMin = timeToMinutes(_startTime);
    final endMin = timeToMinutes(_endTime);

    if (startMin >= endMin) {
      setState(() => _validationError = 'Start time must be before end time.');
      return;
    }

    final finalReason = _isCustomReason
        ? (_customReasonController.text.trim().isNotEmpty
            ? _customReasonController.text.trim()
            : 'Break')
        : _reason;

    final groomerBreak = GroomerBreak(
      id: widget.initialBreak?.id,
      groomerCode: widget.groomerCode,
      dayOfWeek: widget.dayOfWeek,
      startTime: _startTime,
      endTime: _endTime,
      reason: finalReason,
      leaveType: 'break',
    );

    Navigator.of(context).pop(groomerBreak);
  }

  @override
  Widget build(BuildContext context) {
    final startMin = timeToMinutes(_startTime);
    final endMin = timeToMinutes(_endTime);
    final duration = endMin > startMin ? endMin - startMin : 0;
    final hours = duration ~/ 60;
    final mins = duration % 60;

    String durationText = '';
    if (hours > 0 && mins > 0) {
      durationText = '${hours}h ${mins}m';
    } else if (hours > 0) {
      durationText = '${hours}h';
    } else if (mins > 0) {
      durationText = '${mins}m';
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.initialBreak == null ? 'Add Break' : 'Edit Break',
                      style: AppFonts.parkinsans(
                        size: 16,
                        weight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      widget.dayOfWeek,
                      style: AppFonts.poppins(size: 12, color: const Color(0xFF6B7280)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 20, color: Color(0xFFE5E7EB)),
            const SizedBox(height: 8),

            // Time Selector Row
            Text(
              'Break Duration',
              style: AppFonts.poppins(size: 12.5, weight: FontWeight.w600, color: const Color(0xFF374151)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Start', style: AppFonts.poppins(size: 11, color: const Color(0xFF6B7280))),
                      const SizedBox(height: 4),
                      TimePickerSelector(
                        width: double.infinity,
                        time: _startTime,
                        onTimeSelected: (t) {
                          setState(() => _startTime = t);
                          _validateTimes();
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 18, left: 8, right: 8),
                  child: Text('to', style: AppFonts.poppins(size: 12, color: const Color(0xFF9CA3AF))),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('End', style: AppFonts.poppins(size: 11, color: const Color(0xFF6B7280))),
                      const SizedBox(height: 4),
                      TimePickerSelector(
                        width: double.infinity,
                        time: _endTime,
                        onTimeSelected: (t) {
                          setState(() => _endTime = t);
                          _validateTimes();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (durationText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Duration: $durationText',
                  style: AppFonts.poppins(size: 11, color: const Color(0xFF0F766E), weight: FontWeight.w600),
                ),
              ),
            ],

            if (_validationError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 14, color: Color(0xFFDC2626)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: AppFonts.poppins(size: 11, color: const Color(0xFFDC2626)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Reason Pills
            Text(
              'Reason / Label',
              style: AppFonts.poppins(size: 12.5, weight: FontWeight.w600, color: const Color(0xFF374151)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ..._commonReasons.map((r) {
                  final isSelected = !_isCustomReason && _reason == r;
                  return ChoiceChip(
                    label: Text(
                      r,
                      style: AppFonts.poppins(
                        size: 11.5,
                        weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? Colors.white : const Color(0xFF374151),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0F766E),
                    backgroundColor: const Color(0xFFF3F4F6),
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _reason = r;
                          _isCustomReason = false;
                        });
                      }
                    },
                  );
                }),
                ChoiceChip(
                  label: Text(
                    'Other',
                    style: AppFonts.poppins(
                      size: 11.5,
                      weight: _isCustomReason ? FontWeight.w600 : FontWeight.w400,
                      color: _isCustomReason ? Colors.white : const Color(0xFF374151),
                    ),
                  ),
                  selected: _isCustomReason,
                  selectedColor: const Color(0xFF0F766E),
                  backgroundColor: const Color(0xFFF3F4F6),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (selected) {
                    setState(() => _isCustomReason = true);
                  },
                ),
              ],
            ),

            if (_isCustomReason) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _customReasonController,
                style: AppFonts.poppins(size: 12.5),
                decoration: InputDecoration(
                  hintText: 'Enter custom reason (e.g. Team meeting)',
                  hintStyle: AppFonts.poppins(size: 12, color: const Color(0xFF9CA3AF)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],

            const SizedBox(height: 22),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: AppFonts.poppins(size: 13, color: const Color(0xFF6B7280))),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  onPressed: _validationError == null ? _handleSave : null,
                  child: Text('Save Break', style: AppFonts.poppins(size: 13, weight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
