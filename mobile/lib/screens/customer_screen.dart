import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/booking_calendar.dart';
import '../widgets/common.dart';
import 'scan_screen.dart';

/// No-login screen for customers: "Is this dress free on my wedding date?"
class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key, this.initialBoutique});
  final String? initialBoutique;

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  late final _boutique = TextEditingController(text: widget.initialBoutique ?? '');
  final _code = TextEditingController();
  PublicCloth? _result;
  String? _error;
  bool _busy = false;
  DateTime? _day;

  Future<void> _check() async {
    if (_boutique.text.trim().isEmpty || _code.text.trim().isEmpty) {
      setState(() => _error = 'Enter both the Boutique code and the Cloth ID');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await Api.instance.publicCloth(_boutique.text, _code.text);
      setState(() {
        _result = r;
        _day = null;
      });
    } on ApiException catch (e) {
      setState(() {
        _result = null;
        _error = e.message;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  DateTime? _freeFrom(PublicCloth c) {
    if (c.availableNow) return null;
    var t = DateTime.now();
    for (final b in c.busy) {
      if (b.start.isAfter(t)) break;
      if (b.end.isAfter(t)) t = b.end;
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check availability')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        const Text('Find out if an outfit is free on your date — no login needed.',
            style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 16),
        TextField(
          controller: _boutique,
          autocorrect: false,
          decoration: const InputDecoration(
              labelText: 'Boutique code', hintText: 'Ask the boutique', prefixIcon: Icon(Icons.storefront_rounded)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _check(),
          decoration: InputDecoration(
            labelText: 'Cloth ID',
            hintText: 'e.g. LH001',
            prefixIcon: const Icon(Icons.sell_rounded),
            suffixIcon: IconButton(
              tooltip: 'Scan tag',
              icon: const Icon(Icons.qr_code_scanner_rounded),
              onPressed: () async {
                final v = await scanClothTag(context);
                if (v != null) {
                  _code.text = v;
                  _check();
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _check,
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.search_rounded),
          label: const Text('Check'),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.overdue)),
          ),
        if (_result != null) ..._resultView(_result!),
      ]),
    );
  }

  List<Widget> _resultView(PublicCloth c) {
    final freeFrom = _freeFrom(c);
    final dayBusy = _day != null && c.busy.any((b) => rangeTouchesDay(b.start, b.end, _day!));
    return [
      const SizedBox(height: 24),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(height: 300, width: double.infinity, child: ClothImage(c.imageUrl, radius: 0, iconSize: 64)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.boutiqueName.toUpperCase(),
                  style: const TextStyle(fontSize: 11, letterSpacing: 1.6, color: AppColors.gold, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Row(children: [
                CodeTag(c.code),
                const SizedBox(width: 8),
                Expanded(child: Text(c.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 6),
              Text(
                [
                  if (c.rentPrice > 0) '${fmtMoney(c.rentPrice)} per rent',
                  if (c.size != null) 'Size ${c.size}',
                  if (c.category != null) c.category!,
                ].join('  •  '),
                style: const TextStyle(color: AppColors.muted),
              ),
              if (c.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(c.description, style: const TextStyle(height: 1.4)),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (c.availableNow ? AppColors.available : AppColors.onRent).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  Icon(c.availableNow ? Icons.check_circle_rounded : Icons.schedule_rounded,
                      color: c.availableNow ? AppColors.available : AppColors.onRent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      c.availableNow ? 'Available right now!' : 'Currently rented — free from ${fmtDateTime(freeFrom!)}',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: c.availableNow ? AppColors.available : AppColors.onRent),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
      const SectionTitle('Tap your date'),
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: Column(children: [
            BookingCalendar(
              ranges: c.busy.map((b) => CalendarRange(b.start, b.end, AppColors.overdue)).toList(),
              selected: _day,
              onDayTap: (d) => setState(() => _day = d),
            ),
            const CalendarLegend(items: {'Already booked': AppColors.overdue}),
          ]),
        ),
      ),
      if (_day != null)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(
            dayBusy ? '✗ Sorry, booked on ${fmtDay(_day!)}' : '✓ Free on ${fmtDay(_day!)} — contact the boutique to book!',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: dayBusy ? AppColors.overdue : AppColors.available),
          ),
        ),
    ];
  }
}
