import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import 'cloth_detail_screen.dart';

/// Boutique-wide calendar: for any day see what goes out, what comes back,
/// and what is still with customers.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = dayOnly(DateTime.now());
  List<Rental> _rentals = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // Load a window around the visible month so edges look right.
    final from = DateTime(_focused.year, _focused.month - 1, 20);
    final to = DateTime(_focused.year, _focused.month + 1, 12);
    try {
      final r = await Api.instance.rentals(from, to);
      if (mounted) setState(() => _rentals = r);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Rental> _out(DateTime d) => _rentals.where((r) => isSameDay(r.startAt, d)).toList();
  List<Rental> _back(DateTime d) => _rentals.where((r) => r.isActive && isSameDay(r.endAt, d)).toList();
  List<Rental> _with(DateTime d) => _rentals
      .where((r) => r.isActive && rangeTouchesDay(r.startAt, r.endAt, d) && !isSameDay(r.startAt, d) && !isSameDay(r.endAt, d))
      .toList();

  @override
  Widget build(BuildContext context) {
    final out = _out(_selected), back = _back(_selected), withC = _with(_selected);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _focused = DateTime.now();
                _selected = dayOnly(DateTime.now());
              });
              _load();
            },
            child: const Text('Today'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
              child: Column(children: [
                TableCalendar<String>(
                  firstDay: DateTime(2020),
                  lastDay: DateTime(2100),
                  focusedDay: _focused,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                  rowHeight: 48,
                  selectedDayPredicate: (d) => isSameDay(d, _selected),
                  onDaySelected: (s, f) => setState(() {
                    _selected = dayOnly(s);
                    _focused = f;
                  }),
                  onPageChanged: (f) {
                    _focused = f;
                    _load();
                  },
                  eventLoader: (d) => [
                    ..._out(d).map((_) => 'out'),
                    ..._back(d).map((_) => 'back'),
                  ],
                  headerStyle: const HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: false,
                    titleTextStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: AppColors.goldSoft,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold, width: 1.5),
                    ),
                    todayTextStyle: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800),
                    selectedDecoration: const BoxDecoration(color: AppColors.plum, shape: BoxShape.circle),
                  ),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return null;
                      final o = events.where((e) => e == 'out').length;
                      final b = events.length - o;
                      return Positioned(
                        bottom: 3,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (o > 0) _Dot(AppColors.onRent, o),
                          if (b > 0) _Dot(AppColors.available, b),
                        ]),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const _Dot(AppColors.onRent, 0),
                  const Text(' Goes out    ', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  const _Dot(AppColors.available, 0),
                  const Text(' Comes back', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  if (_loading) ...[
                    const SizedBox(width: 12),
                    const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ]),
              ]),
            ),
          ),
          if (_error != null) ErrorRetry(_error!, onRetry: _load),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 0),
            child: Text(fmtDay(_selected), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          _group('Goes out', Icons.north_east_rounded, AppColors.onRent, out, (r) => r.startAt),
          _group('Comes back', Icons.south_west_rounded, AppColors.available, back, (r) => r.endAt),
          _group('With customers', Icons.home_work_rounded, AppColors.booked, withC, (r) => r.endAt, prefix: 'back '),
          if (out.isEmpty && back.isEmpty && withC.isEmpty && !_loading)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: EmptyState(icon: Icons.event_available_rounded, title: 'Nothing on this day'),
            ),
        ]),
      ),
    );
  }

  Widget _group(String title, IconData icon, Color color, List<Rental> list, DateTime Function(Rental) time,
      {String prefix = ''}) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(title, trailing: Text('${list.length}')),
      ...list.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: SizedBox(width: 48, height: 48, child: ClothImage(r.clothImage, radius: 12, iconSize: 20)),
                title: Row(children: [
                  CodeTag(r.clothCode),
                  const SizedBox(width: 6),
                  Expanded(child: Text(r.clothName, overflow: TextOverflow.ellipsis)),
                ]),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${r.customerName}  •  $prefix${prefix.isEmpty ? fmtTime(time(r)) : fmtShort(time(r))}'),
                ),
                trailing: StatusChip(r.status, dense: true),
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => ClothDetailScreen(clothId: r.clothId)));
                  widget.onChanged();
                },
              ),
            ),
          )),
    ]);
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color, this.count);
  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        width: count > 1 ? 14 : 7,
        height: 7,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      );
}
