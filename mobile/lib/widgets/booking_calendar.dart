import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../theme.dart';
import '../utils.dart';

class CalendarRange {
  CalendarRange(this.start, this.end, this.color);
  final DateTime start, end;
  final Color color;
}

/// Month calendar that paints every booked day with its booking's colour,
/// with rounded "pill" ends where a booking starts and finishes.
class BookingCalendar extends StatefulWidget {
  const BookingCalendar({super.key, required this.ranges, this.onDayTap, this.selected});
  final List<CalendarRange> ranges;
  final void Function(DateTime day)? onDayTap;
  final DateTime? selected;

  @override
  State<BookingCalendar> createState() => _BookingCalendarState();
}

class _BookingCalendarState extends State<BookingCalendar> {
  DateTime _focused = DateTime.now();

  CalendarRange? _rangeFor(DateTime day) {
    for (final r in widget.ranges) {
      if (rangeTouchesDay(r.start, r.end, day)) return r;
    }
    return null;
  }

  Widget _cell(DateTime day, {bool today = false, bool outside = false}) {
    final r = _rangeFor(day);
    final selected = widget.selected != null && isSameDay(widget.selected, day);
    final textColor = outside ? AppColors.muted.withValues(alpha: 0.5) : AppColors.ink;
    if (r == null) {
      return Center(
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: today || selected ? Border.all(color: AppColors.gold, width: 2) : null,
          ),
          child: Text('${day.day}', style: TextStyle(color: textColor, fontWeight: today ? FontWeight.w800 : null)),
        ),
      );
    }
    // Round the pill where the booking starts/ends and at week-row edges.
    final isStart = isSameDay(r.start, day) || day.weekday == DateTime.monday;
    final isEnd = isSameDay(r.end, day) || day.weekday == DateTime.sunday;
    return Container(
      margin: EdgeInsets.only(top: 6, bottom: 6, left: isStart ? 4 : 0, right: isEnd ? 4 : 0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: r.color.withValues(alpha: outside ? 0.25 : 0.85),
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(isStart ? 20 : 0),
          right: Radius.circular(isEnd ? 20 : 0),
        ),
        border: today || selected ? Border.all(color: AppColors.gold, width: 2) : null,
      ),
      child: Text('${day.day}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TableCalendar(
      firstDay: DateTime(2020),
      lastDay: DateTime(2100),
      focusedDay: _focused,
      startingDayOfWeek: StartingDayOfWeek.monday,
      availableCalendarFormats: const {CalendarFormat.month: 'Month'},
      rowHeight: 46,
      headerStyle: const HeaderStyle(
        titleCentered: true,
        formatButtonVisible: false,
        titleTextStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700, fontSize: 12),
        weekendStyle: TextStyle(color: AppColors.plumSoft, fontWeight: FontWeight.w700, fontSize: 12),
      ),
      selectedDayPredicate: (d) => widget.selected != null && isSameDay(widget.selected, d),
      onDaySelected: (sel, foc) {
        setState(() => _focused = foc);
        widget.onDayTap?.call(sel);
      },
      onPageChanged: (f) => setState(() => _focused = f),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (c, d, _) => _cell(d),
        todayBuilder: (c, d, _) => _cell(d, today: true),
        selectedBuilder: (c, d, _) => _cell(d, today: isSameDay(d, DateTime.now())),
        outsideBuilder: (c, d, _) => _cell(d, outside: true),
      ),
    );
  }
}

class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key, required this.items});
  final Map<String, Color> items;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 14,
        runSpacing: 6,
        children: items.entries
            .map((e) => Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: e.value, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(e.key, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
                ]))
            .toList(),
      );
}
