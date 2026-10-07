import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/models/groomer_schedule_models.dart';

class StoreHoursTableWidget extends StatelessWidget {
  final List<StoreServiceHour> hours;

  const StoreHoursTableWidget({
    super.key,
    required this.hours,
  });

  static const List<String> weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String get _currentDayName => DateFormat('EEEE').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final sortedHours = _sortDays(hours);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          // Header title & READ ONLY badge
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.storefront_outlined, color: Color(0xFF0F766E), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Store Hours',
                        style: AppFonts.parkinsans(
                          size: 15.5,
                          weight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Store operating hours are managed by your administrator.',
                        style: AppFonts.poppins(size: 11, color: const Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          if (sortedHours.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.schedule_outlined, size: 30, color: Color(0xFF9CA3AF)),
                    const SizedBox(height: 6),
                    Text(
                      'No schedule available',
                      style: AppFonts.poppins(size: 12.5, weight: FontWeight.w600, color: const Color(0xFF374151)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Schedule information has not been configured yet.',
                      style: AppFonts.poppins(size: 11, color: const Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 480;

                if (isWide) {
                  // Wide 4-column Table Layout
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        color: const Color(0xFFF9FAFB),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Day',
                                style: AppFonts.poppins(size: 11, weight: FontWeight.w600, color: const Color(0xFF6B7280)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Status',
                                style: AppFonts.poppins(size: 11, weight: FontWeight.w600, color: const Color(0xFF6B7280)),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Opening',
                                style: AppFonts.poppins(size: 11, weight: FontWeight.w600, color: const Color(0xFF6B7280)),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Closing',
                                style: AppFonts.poppins(size: 11, weight: FontWeight.w600, color: const Color(0xFF6B7280)),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE5E7EB)),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sortedHours.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        itemBuilder: (context, index) => _buildWideRow(sortedHours[index]),
                      ),
                    ],
                  );
                } else {
                  // Compact Mobile Stacked Layout (100% Overflow-Proof)
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sortedHours.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    itemBuilder: (context, index) => _buildCompactRow(sortedHours[index]),
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCompactRow(StoreServiceHour item) {
    final isToday = item.dayOfWeek.toLowerCase() == _currentDayName.toLowerCase();

    return Container(
      decoration: BoxDecoration(
        color: isToday ? const Color(0xFF0F766E).withValues(alpha: 0.035) : null,
        border: isToday ? const Border(left: BorderSide(color: Color(0xFF0F766E), width: 3)) : null,
      ),
      padding: EdgeInsets.fromLTRB(isToday ? 11 : 14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.dayOfWeek,
                    style: AppFonts.poppins(
                      size: 12.5,
                      weight: isToday ? FontWeight.w700 : FontWeight.w600,
                      color: isToday ? const Color(0xFF0F766E) : const Color(0xFF111827),
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Today',
                        style: TextStyle(fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
              _buildStatusPill(item.isOpen),
            ],
          ),
          const SizedBox(height: 5),
          if (item.isOpen)
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 12.5, color: Color(0xFF6B7280)),
                const SizedBox(width: 5),
                Text(
                  '${item.startFormatted}  —  ${item.endFormatted}',
                  style: AppFonts.poppins(
                    size: 11.5,
                    weight: FontWeight.w500,
                    color: const Color(0xFF374151),
                  ),
                ),
              ],
            )
          else
            Text(
              'Closed all day',
              style: AppFonts.poppins(
                size: 11,
                color: const Color(0xFF9CA3AF),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWideRow(StoreServiceHour item) {
    final isToday = item.dayOfWeek.toLowerCase() == _currentDayName.toLowerCase();

    return Container(
      decoration: BoxDecoration(
        color: isToday ? const Color(0xFF0F766E).withValues(alpha: 0.035) : null,
        border: isToday ? const Border(left: BorderSide(color: Color(0xFF0F766E), width: 3)) : null,
      ),
      padding: EdgeInsets.fromLTRB(isToday ? 11 : 14, 9, 14, 9),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    item.dayOfWeek,
                    style: AppFonts.poppins(
                      size: 12,
                      weight: isToday ? FontWeight.w700 : FontWeight.w500,
                      color: isToday ? const Color(0xFF0F766E) : const Color(0xFF111827),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildStatusPill(item.isOpen),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              decoration: BoxDecoration(
                color: item.isOpen ? const Color(0xFFF9FAFB) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(
                item.isOpen ? item.startFormatted : '—',
                style: AppFonts.poppins(
                  size: 11,
                  weight: FontWeight.w500,
                  color: item.isOpen ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              decoration: BoxDecoration(
                color: item.isOpen ? const Color(0xFFF9FAFB) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(
                item.isOpen ? item.endFormatted : '—',
                style: AppFonts.poppins(
                  size: 11,
                  weight: FontWeight.w500,
                  color: item.isOpen ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(bool isOpen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: isOpen ? const Color(0xFFECFDF5) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOpen ? const Color(0xFFA7F3D0) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOpen ? const Color(0xFF059669) : const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(width: 3.5),
          Text(
            isOpen ? 'Open' : 'Closed',
            style: AppFonts.poppins(
              size: 10.5,
              weight: FontWeight.w600,
              color: isOpen ? const Color(0xFF059669) : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  List<StoreServiceHour> _sortDays(List<StoreServiceHour> input) {
    if (input.isEmpty) return [];

    final map = <String, StoreServiceHour>{};
    for (final h in input) {
      map[h.dayOfWeek.toLowerCase()] = h;
    }

    final sorted = <StoreServiceHour>[];
    for (final day in weekDays) {
      final existing = map[day.toLowerCase()];
      if (existing != null) {
        sorted.add(existing);
      }
    }

    for (final h in input) {
      if (!weekDays.any((d) => d.toLowerCase() == h.dayOfWeek.toLowerCase())) {
        sorted.add(h);
      }
    }

    return sorted;
  }
}


