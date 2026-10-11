import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _day = DateFormat('EEE, d MMM yyyy');
final _short = DateFormat('d MMM');
final _time = DateFormat('h:mm a');
final _money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

String fmtDay(DateTime d) => _day.format(d);
String fmtShort(DateTime d) => _short.format(d);
String fmtTime(DateTime d) => _time.format(d);
String fmtDateTime(DateTime d) => '${_day.format(d)} • ${_time.format(d)}';
String fmtMoney(num v) => _money.format(v);

/// "2d 4h", "3h 20m", "12m".
String fmtDuration(Duration d) {
  d = d.abs();
  if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inMinutes.clamp(1, 59)}m';
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// True if the [start, end] range touches calendar day [day].
bool rangeTouchesDay(DateTime start, DateTime end, DateTime day) {
  final s = dayOnly(day), e = s.add(const Duration(days: 1));
  return start.isBefore(e) && end.isAfter(s);
}

void showSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? const Color(0xFFB83A3A) : const Color(0xFF26122F),
    ));
}

Future<bool> confirm(BuildContext context, String title, String message, {String ok = 'Yes', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(90, 44),
            backgroundColor: danger ? const Color(0xFFB83A3A) : null,
          ),
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}
