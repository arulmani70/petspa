import 'package:flutter/material.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_schedule_models.dart';

class TimePickerSelector extends StatelessWidget {
  final String time;
  final ValueChanged<String> onTimeSelected;
  final bool isEnabled;
  final bool hasError;
  final String placeholder;
  final double width;

  const TimePickerSelector({
    super.key,
    required this.time,
    required this.onTimeSelected,
    this.isEnabled = true,
    this.hasError = false,
    this.placeholder = '—',
    this.width = 108.0,
  });

  static final List<String> standardSlots = _generateTimeSlots();

  static List<String> _generateTimeSlots() {
    final list = <String>[];
    for (int hour = 6; hour <= 22; hour++) {
      list.add(':00');
      if (hour < 22) {
        list.add(':30');
      }
    }
    return list;
  }

  void _showPickerModal(BuildContext context) {
    if (!isEnabled) return;

    final current24h = formatTimeTo24h(time);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Time',
                      style: AppFonts.parkinsans(
                        size: 16,
                        weight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              Expanded(
                child: ListView.builder(
                  itemCount: standardSlots.length,
                  itemBuilder: (context, index) {
                    final slot = standardSlots[index];
                    final isSelected = slot == current24h;
                    final display = formatTimeTo12h(slot);

                    return ListTile(
                      dense: true,
                      tileColor: isSelected ? const Color(0xFF0F766E).withValues(alpha: 0.08) : null,
                      leading: Icon(
                        isSelected ? Icons.check_circle : Icons.access_time,
                        size: 18,
                        color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF9CA3AF),
                      ),
                      title: Text(
                        display,
                        style: AppFonts.poppins(
                          size: 13.5,
                          weight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? const Color(0xFF0F766E) : const Color(0xFF111827),
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        onTimeSelected(slot);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatted = isEnabled && time.isNotEmpty ? formatTimeTo12h(time) : placeholder;

    final borderColor = hasError
        ? const Color(0xFFEF4444)
        : (isEnabled ? const Color(0xFFD1D5DB) : const Color(0xFFE5E7EB));

    final bgColor = isEnabled
        ? (hasError ? const Color(0xFFFEF2F2) : Colors.white)
        : const Color(0xFFF9FAFB);

    final textColor = isEnabled
        ? (hasError ? const Color(0xFFDC2626) : const Color(0xFF111827))
        : const Color(0xFF9CA3AF);

    return InkWell(
      onTap: isEnabled ? () => _showPickerModal(context) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: width,
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: hasError ? 1.5 : 1.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                formatted,
                style: AppFonts.poppins(
                  size: 12,
                  weight: isEnabled ? FontWeight.w500 : FontWeight.w400,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            if (isEnabled)
              const Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: Color(0xFF6B7280),
              ),
          ],
        ),
      ),
    );
  }
}
