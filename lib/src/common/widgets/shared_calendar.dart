import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shear_heaven_pet_spa/src/common/utils/app_fonts.dart';

class SharedCalendar extends StatefulWidget {
  final DateTime? initialDate;
  final DateTime? minDate;
  final DateTime? maxDate;
  final ValueChanged<DateTime> onDateSelected;
  final bool Function(DateTime)? isDateUnavailable;

  const SharedCalendar({
    super.key,
    this.initialDate,
    this.minDate,
    this.maxDate,
    required this.onDateSelected,
    this.isDateUnavailable,
  });

  @override
  State<SharedCalendar> createState() => _SharedCalendarState();
}

class _SharedCalendarState extends State<SharedCalendar> {
  late DateTime _visibleMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate != null
        ? DateTime(widget.initialDate!.year, widget.initialDate!.month, widget.initialDate!.day)
        : null;
    final start = widget.initialDate ?? widget.minDate ?? DateTime.now();
    _visibleMonth = DateTime(start.year, start.month);
  }

  @override
  void didUpdateWidget(covariant SharedCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDate != oldWidget.initialDate) {
      setState(() {
        _selectedDate = widget.initialDate != null
            ? DateTime(widget.initialDate!.year, widget.initialDate!.month, widget.initialDate!.day)
            : null;
        if (_selectedDate != null) {
          _visibleMonth = DateTime(_selectedDate!.year, _selectedDate!.month);
        }
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _leadingOffset(DateTime monthStart) => monthStart.weekday % 7;

  int _daysInMonth(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

  List<DateTime> _calendarCells() {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month);
    final leading = _leadingOffset(first);
    final prevMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
    final prevDays = _daysInMonth(prevMonth);

    final cells = <DateTime>[];
    for (var i = prevDays - leading + 1; i <= prevDays; i++) {
      cells.add(DateTime(prevMonth.year, prevMonth.month, i));
    }
    for (var d = 1; d <= _daysInMonth(_visibleMonth); d++) {
      cells.add(DateTime(_visibleMonth.year, _visibleMonth.month, d));
    }
    while (cells.length % 7 != 0) {
      final last = cells.last;
      cells.add(DateTime(last.year, last.month, last.day + 1));
    }
    return cells;
  }

  void _selectDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    
    // Check min/max bounds
    if (widget.minDate != null) {
      final min = DateTime(widget.minDate!.year, widget.minDate!.month, widget.minDate!.day);
      if (normalizedDate.isBefore(min)) return;
    }
    if (widget.maxDate != null) {
      final max = DateTime(widget.maxDate!.year, widget.maxDate!.month, widget.maxDate!.day);
      if (normalizedDate.isAfter(max)) return;
    }

    if (widget.isDateUnavailable != null && widget.isDateUnavailable!(normalizedDate)) return;

    setState(() {
      _selectedDate = normalizedDate;
      if (normalizedDate.month != _visibleMonth.month || normalizedDate.year != _visibleMonth.year) {
        _visibleMonth = DateTime(normalizedDate.year, normalizedDate.month);
      }
    });
    widget.onDateSelected(normalizedDate);
  }

  @override
  Widget build(BuildContext context) {
    final cells = _calendarCells();

    bool canGoPrev = true;
    if (widget.minDate != null) {
      final minMonth = DateTime(widget.minDate!.year, widget.minDate!.month);
      final currentMonth = DateTime(_visibleMonth.year, _visibleMonth.month);
      if (!currentMonth.isAfter(minMonth)) {
        canGoPrev = false;
      }
    }

    bool canGoNext = true;
    if (widget.maxDate != null) {
      final maxMonth = DateTime(widget.maxDate!.year, widget.maxDate!.month);
      final currentMonth = DateTime(_visibleMonth.year, _visibleMonth.month);
      if (!currentMonth.isBefore(maxMonth)) {
        canGoNext = false;
      }
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(13, 20, 13, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: canGoPrev ? () => _changeMonth(-1) : null,
                child: Icon(
                  Icons.chevron_left,
                  size: 24,
                  color: canGoPrev ? Colors.black : const Color(0xFFD1D5DB),
                ),
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(_visibleMonth),
                  textAlign: TextAlign.center,
                  style: AppFonts.poppins(size: 16, weight: FontWeight.w600),
                ),
              ),
              GestureDetector(
                onTap: canGoNext ? () => _changeMonth(1) : null,
                child: Icon(
                  Icons.chevron_right,
                  size: 24,
                  color: canGoNext ? Colors.black : const Color(0xFFD1D5DB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat',
            ].map((day) {
              return Expanded(
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          for (var row = 0; row < (cells.length / 7).ceil(); row++)
            Row(
              children: List.generate(7, (col) {
                final date = cells[row * 7 + col];
                final isCurrentMonth =
                    date.month == _visibleMonth.month && date.year == _visibleMonth.year;
                final isSelected = _selectedDate != null && _isSameDay(date, _selectedDate!);
                final normalizedDate = DateTime(date.year, date.month, date.day);
                
                bool isUnavailable = false;
                if (widget.isDateUnavailable != null) {
                  isUnavailable = widget.isDateUnavailable!(normalizedDate);
                }
                if (!isUnavailable && widget.minDate != null) {
                  final min = DateTime(widget.minDate!.year, widget.minDate!.month, widget.minDate!.day);
                  if (normalizedDate.isBefore(min)) isUnavailable = true;
                }
                if (!isUnavailable && widget.maxDate != null) {
                  final max = DateTime(widget.maxDate!.year, widget.maxDate!.month, widget.maxDate!.day);
                  if (normalizedDate.isAfter(max)) isUnavailable = true;
                }

                final isToday = _isSameDay(date, DateTime.now());
                final isSelectable = !isUnavailable;

                final Color textColor;
                final BoxDecoration cellDecoration;
                final FontWeight fontWeight;

                if (isSelected) {
                  textColor = Colors.white;
                  fontWeight = FontWeight.w600;
                  cellDecoration = BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(14),
                  );
                } else if (isToday && isSelectable) {
                  textColor = Colors.black;
                  fontWeight = FontWeight.w600;
                  cellDecoration = BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black, width: 1.3),
                  );
                } else if (isSelectable) {
                  textColor = isCurrentMonth ? const Color(0xFF120C0C) : const Color(0xFF4B5563);
                  fontWeight = FontWeight.w400;
                  cellDecoration = BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  );
                } else {
                  textColor = const Color(0xFFAFAFAF);
                  fontWeight = FontWeight.w400;
                  cellDecoration = BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  );
                }

                return Expanded(
                  child: Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: isSelectable ? () => _selectDate(normalizedDate) : null,
                      child: Container(
                        height: 28,
                        constraints: const BoxConstraints(minWidth: 38),
                        alignment: Alignment.center,
                        decoration: cellDecoration,
                        child: Text(
                          '${date.day}',
                          style: AppFonts.poppins(
                            size: 14,
                            weight: fontWeight,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

