import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import 'inquiry_widgets.dart';

/// "Mark returned": collect the rent balance and settle the deposit, then (if it came back early)
/// show who's waiting for the freed dates. Returns true when the cloth was marked returned.
Future<bool> markReturnedFlow(BuildContext context, Rental r) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.ivory,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _MoneySheet(rental: r, returning: true),
  );
  if (ok != true) return false;
  final now = DateTime.now();
  if (context.mounted && r.endAt.isAfter(now)) {
    await showWaitlistSheet(context, clothId: r.clothId, clothCode: r.clothCode, from: now, to: r.endAt);
  }
  return true;
}

/// Give back a deposit that was "decided later". Returns true when saved.
Future<bool> settleDepositFlow(BuildContext context, Rental r) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.ivory,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _MoneySheet(rental: r, returning: false),
  );
  return ok == true;
}

enum _Deposit { full, keepSome, later }

class _MoneySheet extends StatefulWidget {
  const _MoneySheet({required this.rental, required this.returning});
  final Rental rental;
  final bool returning; // false = only settling the deposit

  @override
  State<_MoneySheet> createState() => _MoneySheetState();
}

class _MoneySheetState extends State<_MoneySheet> {
  bool _collect = true;
  _Deposit _deposit = _Deposit.full;
  final _kept = TextEditingController();
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  Rental get r => widget.rental;
  double get _keptValue => double.tryParse(_kept.text.trim()) ?? 0;

  Future<void> _save() async {
    double? returned;
    String? note;
    if (r.depositAmount > 0) {
      switch (_deposit) {
        case _Deposit.full:
          returned = r.depositAmount;
        case _Deposit.keepSome:
          if (_keptValue <= 0 || _keptValue > r.depositAmount) {
            setState(() => _error = 'Enter an amount between 1 and ${fmtMoney(r.depositAmount)}');
            return;
          }
          returned = r.depositAmount - _keptValue;
          note = _reason.text.trim();
        case _Deposit.later:
          returned = null;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.returning) {
        await Api.instance.markReturned(r.id,
            collectBalance: r.balanceDue > 0 ? _collect : true, depositReturned: returned, depositNote: note);
      } else {
        await Api.instance.settleDeposit(r.id, returned ?? r.depositAmount, note);
      }
      if (!mounted) return;
      showSnack(context, widget.returning ? 'Marked as returned ✓' : 'Deposit settled ✓');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDeposit = r.depositAmount > 0;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
                width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4))),
          ),
          const SizedBox(height: 16),
          Text(widget.returning ? 'Mark returned' : 'Settle deposit',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text('${r.clothCode} · ${r.clothName} · ${r.customerName}', style: const TextStyle(color: AppColors.muted)),
          if (widget.returning) ...[
            const SizedBox(height: 16),
            const Text('RENT', style: TextStyle(fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: AppColors.muted)),
            const SizedBox(height: 6),
            if (r.balanceDue > 0)
              Card(
                child: SwitchListTile(
                  value: _collect,
                  onChanged: (v) => setState(() => _collect = v),
                  title: Text('Collected balance ${fmtMoney(r.balanceDue)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Rent ${fmtMoney(r.rentAmount)}, paid before ${fmtMoney(r.advancePaid)}'),
                ),
              )
            else
              Card(
                child: ListTile(
                  leading: const Icon(Icons.check_circle_rounded, color: AppColors.available),
                  title: Text(r.rentAmount > 0 ? 'Rent fully paid (${fmtMoney(r.rentAmount)})' : 'No rent amount recorded'),
                ),
              ),
          ],
          if (hasDeposit) ...[
            const SizedBox(height: 16),
            Text('DEPOSIT · ${fmtMoney(r.depositAmount)}',
                style: const TextStyle(fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: AppColors.muted)),
            const SizedBox(height: 6),
            Card(
              child: RadioGroup<_Deposit>(
                groupValue: _deposit,
                onChanged: (v) => setState(() => _deposit = v!),
                child: Column(children: [
                  RadioListTile(
                    value: _Deposit.full,
                    title: Text('Give back full ${fmtMoney(r.depositAmount)}'),
                    subtitle: const Text('Cloth is fine'),
                  ),
                  const RadioListTile(
                    value: _Deposit.keepSome,
                    title: Text('Keep some (damage, late, cleaning…)'),
                  ),
                  if (widget.returning)
                    const RadioListTile(
                      value: _Deposit.later,
                      title: Text('Decide later'),
                      subtitle: Text('e.g. after checking the cloth'),
                    ),
                ]),
              ),
            ),
            if (_deposit == _Deposit.keepSome) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _kept,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Amount kept',
                  prefixText: '₹ ',
                  helperText: _keptValue > 0 && _keptValue <= r.depositAmount
                      ? 'Give back ${fmtMoney(r.depositAmount - _keptValue)}'
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reason,
                decoration: const InputDecoration(labelText: 'Reason', hintText: 'e.g. stain on dupatta'),
              ),
            ],
          ],
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
                : Text(widget.returning ? 'Confirm return' : 'Save'),
          ),
        ]),
      ),
    );
  }
}
