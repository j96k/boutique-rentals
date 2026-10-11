import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';

/// Give a cloth on rent (or book it for later). Pops `true` when saved.
class RentalFormScreen extends StatefulWidget {
  const RentalFormScreen({super.key, required this.cloth, this.rental, this.startDay});
  final Cloth cloth;
  final Rental? rental;
  final DateTime? startDay;

  @override
  State<RentalFormScreen> createState() => _RentalFormScreenState();
}

class _RentalFormScreenState extends State<RentalFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.rental?.customerName ?? '');
  late final _phone = TextEditingController(text: widget.rental?.customerPhone ?? '');
  late final _advance = TextEditingController(
      text: (widget.rental?.advancePaid ?? 0) == 0 ? '' : widget.rental!.advancePaid.toStringAsFixed(0));
  late final _notes = TextEditingController(text: widget.rental?.notes ?? '');
  late DateTime _start;
  late DateTime _end;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (widget.rental != null) {
      _start = widget.rental!.startAt;
      _end = widget.rental!.endAt;
    } else {
      final d = widget.startDay;
      // Starting today → now (rounded); a future day → 10:00 AM.
      _start = d == null || isSameDayAs(d, now)
          ? DateTime(now.year, now.month, now.day, now.hour, now.minute - now.minute % 15)
          : DateTime(d.year, d.month, d.day, 10);
      _end = _start.add(const Duration(days: 2));
    }
  }

  bool isSameDayAs(DateTime a, DateTime b) => dayOnly(a) == dayOnly(b);

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return null;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (!_end.isAfter(_start)) {
      showSnack(context, 'Return must be after the rent-out time', error: true);
      return;
    }
    setState(() => _busy = true);
    final body = {
      'customer_name': _name.text.trim(),
      'customer_phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'start_at': apiDate(_start),
      'end_at': apiDate(_end),
      'advance_paid': double.tryParse(_advance.text.trim()) ?? 0,
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    };
    try {
      if (widget.rental == null) {
        await Api.instance.createRental(widget.cloth.id, body);
      } else {
        await Api.instance.updateRental(widget.rental!.id, body);
      }
      if (!mounted) return;
      showSnack(context, 'Saved ✓');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Cancel this booking?', 'It will be removed completely.', ok: 'Remove', danger: true)) {
      return;
    }
    try {
      await Api.instance.deleteRental(widget.rental!.id);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _end.difference(_start);
    final c = widget.cloth;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rental == null ? 'Give on rent' : 'Change booking'),
        actions: [
          if (widget.rental != null)
            IconButton(tooltip: 'Cancel booking', onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Text(_start.isAfter(DateTime.now()) ? 'Confirm booking' : 'Confirm — cloth goes out'),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                SizedBox(width: 64, height: 64, child: ClothImage(c.imageUrl, radius: 14, iconSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CodeTag(c.code),
                    const SizedBox(height: 4),
                    Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    if (c.rentPrice > 0) Text(fmtMoney(c.rentPrice), style: const TextStyle(color: AppColors.muted)),
                  ]),
                ),
              ]),
            ),
          ),
          const SectionTitle('When'),
          _DateTile(
            icon: Icons.north_east_rounded,
            label: 'Goes out (rent date & time)',
            value: _start,
            onTap: () async {
              final v = await _pickDateTime(_start);
              if (v != null) {
                setState(() {
                  final len = _end.difference(_start);
                  _start = v;
                  _end = v.add(len); // keep the same rental length
                });
              }
            },
          ),
          const SizedBox(height: 10),
          _DateTile(
            icon: Icons.south_west_rounded,
            label: 'Comes back (return date & time)',
            value: _end,
            onTap: () async {
              final v = await _pickDateTime(_end);
              if (v != null) setState(() => _end = v);
            },
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text('Quick:', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
            for (final d in [1, 2, 3, 5, 7])
              ChoiceChip(
                label: Text(d == 7 ? '1 week' : '$d day${d > 1 ? 's' : ''}'),
                selected: days == Duration(days: d),
                selectedColor: AppColors.goldSoft,
                onSelected: (_) => setState(() => _end = _start.add(Duration(days: d))),
              ),
          ]),
          if (days.inMinutes > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Rental length: ${fmtDuration(days)}',
                  style: const TextStyle(color: AppColors.plumSoft, fontWeight: FontWeight.w700)),
            ),
          const SectionTitle('Customer'),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Customer name *', prefixIcon: Icon(Icons.person_rounded)),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Enter customer name' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone (for reminders)',
              prefixIcon: Icon(Icons.phone_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _advance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Advance / deposit paid', prefixText: '₹ '),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Notes', hintText: 'Alterations, ID proof taken, items included…', alignLabelWithHint: true),
          ),
        ]),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.icon, required this.label, required this.value, required this.onTap});
  final IconData icon;
  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.plum),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(fmtDay(value), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(fmtTime(value), style: const TextStyle(color: AppColors.plumSoft, fontWeight: FontWeight.w700)),
                ]),
              ),
              const Icon(Icons.edit_calendar_rounded, color: AppColors.muted),
            ]),
          ),
        ),
      );
}
