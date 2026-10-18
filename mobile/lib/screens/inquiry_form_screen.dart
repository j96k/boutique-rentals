import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';

/// Add / edit a waitlist inquiry (owner), or "Notify me" (customer, when [publicBoutique] is set).
/// Pops with true when saved.
class InquiryFormScreen extends StatefulWidget {
  const InquiryFormScreen({
    super.key,
    this.clothId,
    this.inquiry,
    this.publicBoutique,
    this.publicClothCode,
    this.initialFrom,
    this.initialTo,
  });

  final int? clothId;
  final Inquiry? inquiry;
  final String? publicBoutique;
  final String? publicClothCode;
  final DateTime? initialFrom;
  final DateTime? initialTo;

  bool get isCustomer => publicBoutique != null;

  @override
  State<InquiryFormScreen> createState() => _InquiryFormScreenState();
}

class _InquiryFormScreenState extends State<InquiryFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.inquiry?.name ?? '');
  late final _phone = TextEditingController(text: widget.inquiry?.phone ?? '');
  late final _email = TextEditingController(text: widget.inquiry?.email ?? '');
  late final _insta = TextEditingController(text: widget.inquiry?.instagram ?? '');
  late final _amount = TextEditingController(
      text: (widget.inquiry?.offeredAmount ?? 0) == 0 ? '' : widget.inquiry!.offeredAmount.toStringAsFixed(0));
  late final _notes = TextEditingController(text: widget.inquiry?.notes ?? '');
  late DateTime? _from = widget.inquiry?.wantedFrom ?? widget.initialFrom;
  late DateTime? _to = widget.inquiry?.wantedTo ?? widget.initialTo;
  bool _busy = false;

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
      initialDateRange: _from != null && _to != null && !_from!.isBefore(DateTime(now.year, now.month, now.day))
          ? DateTimeRange(start: dayOnly(_from!), end: dayOnly(_to!))
          : null,
      helpText: 'Which dates do they want it?',
    );
    if (r == null) return;
    setState(() {
      _from = r.start; // from the start of the first day...
      _to = DateTime(r.end.year, r.end.month, r.end.day, 23, 59); // ...to the end of the last day
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final body = {
      'name': _name.text.trim(),
      'phone': _phone.text.trim(),
      'email': _email.text.trim(),
      'instagram': _insta.text.trim(),
      'offered_amount': double.tryParse(_amount.text.trim()) ?? 0,
      'wanted_from': _from == null ? null : apiDate(_from!),
      'wanted_to': _to == null ? null : apiDate(_to!),
      'notes': _notes.text.trim(),
    };
    try {
      if (widget.isCustomer) {
        final msg = await Api.instance.publicNotifyMe(widget.publicBoutique!, widget.publicClothCode!, body);
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            icon: const Icon(Icons.check_circle_rounded, color: AppColors.available, size: 44),
            title: const Text('Request sent'),
            content: Text(msg, textAlign: TextAlign.center),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
          ),
        );
      } else if (widget.inquiry == null) {
        await Api.instance.createInquiry(widget.clothId!, body);
      } else {
        await Api.instance.updateInquiry(widget.inquiry!.id, body);
      }
      if (!mounted) return;
      if (!widget.isCustomer) showSnack(context, 'Saved to waitlist ✓');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _contactCheck(String? _) =>
      _phone.text.trim().isEmpty && _email.text.trim().isEmpty && _insta.text.trim().isEmpty
          ? 'Add at least one: phone, Gmail or Instagram'
          : null;

  @override
  Widget build(BuildContext context) {
    final customer = widget.isCustomer;
    return Scaffold(
      appBar: AppBar(
          title: Text(customer ? 'Notify me' : (widget.inquiry == null ? 'New inquiry' : 'Edit inquiry'))),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Text(customer ? 'Send request' : 'Save to waitlist'),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          Text(
            customer
                ? 'This outfit is booked, but plans change! Leave your details and the boutique will contact you if it frees up.'
                : 'Save people who want this cloth. If a booking is cancelled, the app shows them to you — highest offer first.',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SectionTitle('Person'),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
                labelText: customer ? 'Your name *' : 'Name *', prefixIcon: const Icon(Icons.person_rounded)),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone / WhatsApp', prefixIcon: Icon(Icons.phone_rounded)),
            validator: _contactCheck,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Gmail', prefixIcon: Icon(Icons.mail_rounded)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _insta,
            decoration: const InputDecoration(
                labelText: 'Instagram ID', hintText: 'e.g. riya.styles', prefixIcon: Icon(Icons.camera_alt_rounded)),
          ),
          const SectionTitle('Offer & dates'),
          TextFormField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: customer ? 'Amount you can pay for the rental' : 'Amount they will pay',
              prefixText: '₹ ',
              prefixIcon: const Icon(Icons.payments_rounded),
            ),
            validator: (v) =>
                (v ?? '').trim().isNotEmpty && double.tryParse(v!.trim()) == null ? 'Number only' : null,
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.date_range_rounded, color: AppColors.plum),
              title: Text(_from == null ? 'Any dates' : '${fmtDay(_from!)}  →  ${fmtDay(_to!)}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Which dates do they want it? (optional)'),
              trailing: _from == null
                  ? const Icon(Icons.edit_calendar_rounded)
                  : IconButton(
                      tooltip: 'Clear dates',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _from = _to = null),
                    ),
              onTap: _pickDates,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notes,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Notes',
              hintText: customer ? 'Occasion, size, anything else…' : 'Size, occasion, how they found us…',
              alignLabelWithHint: true,
            ),
          ),
        ]),
      ),
    );
  }
}
