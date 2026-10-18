import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import 'cloth_detail_screen.dart';

/// Money dashboard: totals, earnings per day/month, and which clothes earn most.
/// Counts bookings by the day they go out on rent.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

enum _Range { thisMonth, lastMonth, last3Months, thisYear, custom }

class _EarningsScreenState extends State<EarningsScreen> {
  _Range _range = _Range.thisMonth;
  late DateTimeRange _dates = _rangeFor(_Range.thisMonth);
  late Future<Earnings> _future = _load();

  static DateTimeRange _rangeFor(_Range r) {
    final n = DateTime.now();
    return switch (r) {
      _Range.thisMonth => DateTimeRange(start: DateTime(n.year, n.month), end: DateTime(n.year, n.month + 1)),
      _Range.lastMonth => DateTimeRange(start: DateTime(n.year, n.month - 1), end: DateTime(n.year, n.month)),
      _Range.last3Months => DateTimeRange(start: DateTime(n.year, n.month - 2), end: DateTime(n.year, n.month + 1)),
      _Range.thisYear => DateTimeRange(start: DateTime(n.year), end: DateTime(n.year + 1)),
      _Range.custom => DateTimeRange(start: DateTime(n.year, n.month), end: DateTime(n.year, n.month + 1)),
    };
  }

  Future<Earnings> _load() => Api.instance.earnings(_dates.start, _dates.end);

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _pick(_Range r) async {
    if (r == _Range.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(DateTime.now().year + 2),
        initialDateRange: DateTimeRange(start: _dates.start, end: _dates.end.subtract(const Duration(days: 1))),
      );
      if (picked == null) return;
      _dates = DateTimeRange(start: picked.start, end: dayOnly(picked.end).add(const Duration(days: 1)));
    } else {
      _dates = _rangeFor(r);
    }
    _range = r;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    const labels = {
      _Range.thisMonth: 'This month',
      _Range.lastMonth: 'Last month',
      _Range.last3Months: 'Last 3 months',
      _Range.thisYear: 'This year',
      _Range.custom: 'Custom…',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
          // Filters: one row above everything they control.
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: labels.entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(e.value),
                          selected: _range == e.key,
                          selectedColor: AppColors.goldSoft,
                          onSelected: (_) => _pick(e.key),
                        ),
                      ))
                  .toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              '${fmtDay(_dates.start)}  –  ${fmtDay(_dates.end.subtract(const Duration(days: 1)))}',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
          FutureBuilder<Earnings>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) return ErrorRetry(snap.error.toString(), onRetry: _reload);
              if (!snap.hasData) {
                return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
              }
              return _Body(e: snap.data!, onChanged: _reload);
            },
          ),
        ]),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.e, required this.onChanged});
  final Earnings e;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final rented = e.byCloth.where((c) => c.bookings > 0).toList();
    final idle = e.byCloth.where((c) => c.bookings == 0).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 12),
      _HeroTile(e: e),
      const SizedBox(height: 10),
      Row(children: [
        _Stat('Collected', fmtMoney(e.rentCollected), Icons.payments_rounded),
        const SizedBox(width: 10),
        _Stat('Still to collect', fmtMoney(e.rentPending), Icons.schedule_rounded),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _Stat('Kept from deposits', fmtMoney(e.depositKept), Icons.report_rounded),
        const SizedBox(width: 10),
        _Stat('Deposits held now', fmtMoney(e.depositsHeldNow), Icons.shield_rounded,
            hint: 'To give back (all dates)'),
      ]),
      SectionTitle(e.group == 'day' ? 'Earnings by day' : 'Earnings by month'),
      if (e.bookings == 0)
        const _Nothing('No bookings start in this period.')
      else
        _DateChart(rows: e.byDate, monthly: e.group == 'month'),
      SectionTitle('Earnings by cloth', trailing: Text('${rented.length} rented')),
      if (rented.isEmpty) const _Nothing('No cloth was rented in this period.'),
      ...rented.map((c) => _ClothRow(
            c: c,
            max: rented.first.income,
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => ClothDetailScreen(clothId: c.clothId)));
              onChanged();
            },
          )),
      if (idle.isNotEmpty) ...[
        SectionTitle('Not rented in this period', trailing: Text('${idle.length}')),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: idle.map((c) => CodeTag(c.label)).toList(),
        ),
      ],
    ]);
  }
}

class _HeroTile extends StatelessWidget {
  const _HeroTile({required this.e});
  final Earnings e;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.plumDeep, AppColors.plum]),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Total earned', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(fmtMoney(e.income),
              style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(
            '${e.bookings} booking${e.bookings == 1 ? '' : 's'}  •  rent ${fmtMoney(e.rentTotal)}'
            '${e.depositKept > 0 ? '  +  kept deposits ${fmtMoney(e.depositKept)}' : ''}',
            style: const TextStyle(color: AppColors.goldSoft, fontSize: 13),
          ),
        ]),
      );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon, {this.hint});
  final String label, value;
  final IconData icon;
  final String? hint;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 20, color: AppColors.plumSoft),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
              if (hint != null) Text(hint!, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            ]),
          ),
        ),
      );
}

class _Nothing extends StatelessWidget {
  const _Nothing(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
      );
}

/// ₹850 / ₹12.5k / ₹1.2L — short labels for the chart axis.
String _compact(double v) {
  if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(v % 100000 == 0 ? 0 : 1)}L';
  if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k';
  return '₹${v.toStringAsFixed(0)}';
}

/// Single-series bar chart (income per day or month). Tap a bar for its details;
/// "List" shows the same numbers as a table.
class _DateChart extends StatefulWidget {
  const _DateChart({required this.rows, required this.monthly});
  final List<EarningsRow> rows;
  final bool monthly;

  @override
  State<_DateChart> createState() => _DateChartState();
}

class _DateChartState extends State<_DateChart> {
  int? _selected;
  bool _asList = false;

  String _label(EarningsRow r, {bool long = false}) {
    final d = DateTime.parse(widget.monthly ? '${r.label}-01' : r.label);
    if (widget.monthly) return DateFormat(long ? 'MMMM yyyy' : 'MMM').format(d);
    return long ? fmtDay(d) : '${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final maxV = rows.map((r) => r.income).fold<double>(0, (a, b) => b > a ? b : a);
    final top = maxV <= 0 ? 1.0 : maxV;
    final sel = _selected != null && _selected! < rows.length ? rows[_selected!] : null;
    // Show ~6 x-axis labels at most, so they never collide.
    final every = (rows.length / 6).ceil().clamp(1, 1000);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(
              child: Text('Rent + kept deposits, by the day the booking starts',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _asList = !_asList),
              icon: Icon(_asList ? Icons.bar_chart_rounded : Icons.table_rows_rounded, size: 18),
              label: Text(_asList ? 'Chart' : 'List'),
            ),
          ]),
          if (_asList)
            ...rows.where((r) => r.bookings > 0).map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(child: Text(_label(r, long: true), style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text('${r.bookings} × ', style: const TextStyle(color: AppColors.muted)),
                    SizedBox(
                      width: 92,
                      child: Text(fmtMoney(r.income),
                          textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ))
          else ...[
            SizedBox(
              height: 170,
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // y-axis labels (recessive)
                SizedBox(
                  width: 44,
                  child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(_compact(top), style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                    Text(_compact(top / 2), style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                    const Text('₹0', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                  ]),
                ),
                Expanded(
                  child: Stack(children: [
                    // gridlines
                    Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      for (var i = 0; i < 3; i++) Container(height: 1, color: AppColors.line.withValues(alpha: i == 2 ? 1 : 0.6)),
                    ]),
                    Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (var i = 0; i < rows.length; i++)
                        Expanded(
                          // The whole column is the tap target, not just the (maybe tiny) bar.
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _selected = _selected == i ? null : i),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1), // 2px gap between bars
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: rows[i].income <= 0 ? 0 : (rows[i].income / top).clamp(0.02, 1.0),
                                  child: Container(
                                    constraints: const BoxConstraints(maxWidth: 28),
                                    decoration: BoxDecoration(
                                      color: _selected == null || _selected == i
                                          ? AppColors.plum
                                          : AppColors.plum.withValues(alpha: 0.35),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ]),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 4),
            Row(children: [
              const SizedBox(width: 44),
              for (var i = 0; i < rows.length; i++)
                Expanded(
                  child: Text(i % every == 0 ? _label(rows[i]) : '',
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.visible,
                      softWrap: false,
                      style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                ),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.ivory, borderRadius: BorderRadius.circular(12)),
              child: sel == null
                  ? const Text('Tap a bar to see its details', style: TextStyle(color: AppColors.muted))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_label(sel, long: true), style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        '${sel.bookings} booking${sel.bookings == 1 ? '' : 's'}  •  earned ${fmtMoney(sel.income)}\n'
                        'Rent ${fmtMoney(sel.rent)}  •  collected ${fmtMoney(sel.collected)}'
                        '${sel.depositKept > 0 ? '  •  kept deposits ${fmtMoney(sel.depositKept)}' : ''}',
                        style: const TextStyle(color: AppColors.ink, height: 1.4),
                      ),
                    ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _ClothRow extends StatelessWidget {
  const _ClothRow({required this.c, required this.max, required this.onTap});
  final ClothEarnings c;
  final double max;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final frac = max <= 0 ? 0.0 : (c.income / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              SizedBox(width: 46, height: 46, child: ClothImage(c.clothImage, radius: 12, iconSize: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CodeTag(c.label),
                    const SizedBox(width: 6),
                    Expanded(child: Text(c.clothName, overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 6),
                  // magnitude bar: one hue, anchored left
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(children: [
                      Container(height: 8, color: AppColors.line),
                      FractionallySizedBox(widthFactor: frac, child: Container(height: 8, color: AppColors.plum)),
                    ]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${c.bookings} booking${c.bookings == 1 ? '' : 's'} • ${c.daysRented.toStringAsFixed(c.daysRented % 1 == 0 ? 0 : 1)} days on rent'
                    '${c.depositKept > 0 ? ' • kept ${fmtMoney(c.depositKept)}' : ''}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ]),
              ),
              const SizedBox(width: 10),
              Text(fmtMoney(c.income), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ]),
          ),
        ),
      ),
    );
  }
}
