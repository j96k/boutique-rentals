import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';

/// Change rent / rent paid / deposit of a booking at any time (also after it came back),
/// e.g. a discount at pickup, extra advance paid, or a bigger deposit taken. Returns true when saved.
Future<bool> editAmountsFlow(BuildContext context, Rental r) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.ivory,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _AmountsSheet(rental: r),
  );
  return ok == true;
}

class _AmountsSheet extends StatefulWidget {
  const _AmountsSheet({required this.rental});
  final Rental rental;

  @override
  State<_AmountsSheet> createState() => _AmountsSheetState();
}

class _AmountsSheetState extends State<_AmountsSheet> {
  late final _rent = TextEditingController(text: _fmt(widget.rental.rentAmount));
  late final _paid = TextEditingController(text: _fmt(widget.rental.advancePaid));
  late final _deposit = TextEditingController(text: _fmt(widget.rental.depositAmount));
  bool _busy = false;
  String? _error;

  static String _fmt(double v) => v == 0 ? '' : v.toStringAsFixed(v % 1 == 0 ? 0 : 2);
  double _v(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  Future<void> _save() async {
    final r = widget.rental;
    final rent = _v(_rent), paid = _v(_paid), deposit = _v(_deposit);
    for (final c in [_rent, _paid, _deposit]) {
      if (c.text.trim().isNotEmpty && double.tryParse(c.text.trim()) == null) {
        setState(() => _error = 'Use numbers only');
        return;
      }
    }
    if (paid > rent) {
      setState(() => _error = 'Rent paid (${fmtMoney(paid)}) can\'t be more than the rent (${fmtMoney(rent)})');
      return;
    }
    if (r.depositReturned != null && r.depositReturned! > deposit) {
      setState(() => _error = 'You already gave back ${fmtMoney(r.depositReturned!)} — the deposit can\'t be less than that');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.instance.updateRental(r.id, {
        'customer_name': r.customerName,
        'customer_phone': r.customerPhone,
        'start_at': apiDate(r.startAt),
        'end_at': apiDate(r.endAt),
        'rent_amount': rent,
        'advance_paid': paid,
        'deposit_amount': deposit,
        'notes': r.notes,
      });
      if (!mounted) return;
      showSnack(context, 'Amounts updated ✓');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController c, String label, IconData icon, {String? helper}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: label, helperText: helper, prefixText: '₹ ', prefixIcon: Icon(icon)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final r = widget.rental;
    final rent = _v(_rent), paid = _v(_paid);
    final due = (rent - paid).clamp(0, double.infinity);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
                width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4))),
          ),
          const SizedBox(height: 16),
          const Text('Edit amounts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text('${r.clothCode} · ${r.customerName} · ${fmtShort(r.startAt)} – ${fmtShort(r.endAt)}',
              style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          _field(_rent, 'Rent amount', Icons.sell_rounded, helper: 'Agreed rent (change for a discount or extra days)'),
          _field(_paid, 'Rent paid so far', Icons.payments_rounded, helper: 'Total of all rent payments received'),
          _field(_deposit, 'Security deposit taken', Icons.shield_rounded,
              helper: r.depositReturned != null ? 'Already given back: ${fmtMoney(r.depositReturned!)}' : null),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Expanded(child: Text('Rent still to collect', style: TextStyle(color: AppColors.muted))),
              Text(fmtMoney(due), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: AppColors.overdue)),
            ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : const Text('Save amounts'),
          ),
        ]),
      ),
    );
  }
}
