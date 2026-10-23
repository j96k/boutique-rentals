import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';

enum Channel { whatsapp, gmail, instagram }

/// Message types for a booking. The best one is pre-selected from the booking's state.
const Map<String, String> kScenarios = {
  'booked': 'Booking confirmed',
  'pickup': 'Pickup / handover',
  'reminder': 'Return reminder',
  'overdue': 'Not returned (overdue)',
  'returned': 'Thank you (returned)',
  'deposit': 'Deposit returned',
  'payment': 'Payment due',
  'custom': 'Custom',
};

String suggestedScenario(Rental r) {
  if (r.returnedAt != null) return 'returned';
  final now = DateTime.now();
  if (now.isBefore(r.startAt)) return 'booked';
  if (now.isAfter(r.endAt)) return 'overdue';
  return r.endAt.difference(now).inHours <= 24 ? 'reminder' : 'pickup';
}

String _shop() => Api.instance.user?.boutiqueName ?? 'our boutique';

String _depositLine(Rental r) {
  if (r.depositAmount <= 0) return '';
  if (r.depositReturned == null) return 'Your security deposit of ${fmtMoney(r.depositAmount)} is safe with us.';
  if (r.depositKept > 0) {
    return 'We have returned ${fmtMoney(r.depositReturned!)} of your ${fmtMoney(r.depositAmount)} deposit'
        '${r.depositNote?.isNotEmpty ?? false ? '; ${fmtMoney(r.depositKept)} was kept for ${r.depositNote}' : '; ${fmtMoney(r.depositKept)} was kept'}.';
  }
  return 'Your full deposit of ${fmtMoney(r.depositAmount)} has been returned.';
}

/// The message text for a booking (before the optional invoice block).
String bookingMessage(Rental r, String scenario) {
  final hi = 'Hi ${r.customerName},';
  final outfit = '"${r.clothName}" (${r.clothCode})';
  final due = r.balanceDue > 0 ? 'Balance to pay: ${fmtMoney(r.balanceDue)}.' : '';
  final sign = '\n\nThank you,\n${_shop()}';
  String join(List<String> parts) => parts.where((p) => p.trim().isNotEmpty).join('\n');
  return switch (scenario) {
    'booked' => join([
        hi,
        'Your booking for $outfit is confirmed! ✨',
        'Pickup: ${fmtDateTime(r.startAt)}',
        'Return: ${fmtDateTime(r.endAt)}',
        if (r.rentAmount > 0) 'Rent: ${fmtMoney(r.rentAmount)}  •  Paid: ${fmtMoney(r.advancePaid)}',
        due,
        if (r.depositAmount > 0) 'Refundable deposit: ${fmtMoney(r.depositAmount)}',
      ]) + sign,
    'pickup' => join([
        hi,
        'Thank you for picking up $outfit. Enjoy your occasion! 💐',
        'Please return it by ${fmtDateTime(r.endAt)}.',
        due,
        _depositLine(r),
      ]) + sign,
    'reminder' => join([
        hi,
        'A friendly reminder: $outfit is due back on ${fmtDateTime(r.endAt)}.',
        due,
      ]) + sign,
    'overdue' => join([
        hi,
        'A gentle reminder: $outfit was due back on ${fmtDateTime(r.endAt)} and has not been returned yet.',
        'Please return it at the earliest, or let us know when you can come.',
        due,
      ]) + sign,
    'returned' => join([
        hi,
        'Thank you for returning $outfit. We hope you loved our service! 💜',
        _depositLine(r),
        due,
        'We look forward to dressing you again!',
      ]) + sign,
    'deposit' => join([
        hi,
        _depositLine(r).isEmpty ? 'This is about your deposit for $outfit.' : _depositLine(r),
        'Booking: $outfit, ${fmtShort(r.startAt)} – ${fmtShort(r.endAt)}.',
      ]) + sign,
    'payment' => join([
        hi,
        'This is a reminder about the rent for $outfit (${fmtShort(r.startAt)} – ${fmtShort(r.endAt)}).',
        'Rent: ${fmtMoney(r.rentAmount)}  •  Paid: ${fmtMoney(r.advancePaid)}',
        r.balanceDue > 0 ? 'Balance to pay: ${fmtMoney(r.balanceDue)}.' : 'Everything is paid — thank you!',
      ]) + sign,
    _ => '$hi\n\n${sign.trimLeft()}',
  };
}

String invoiceBlock(Rental r, String number, String url) {
  final lines = <String>[
    '🧾 Invoice $number',
    '${r.clothCode} · ${r.clothName}',
    '${fmtDateTime(r.startAt)} → ${fmtDateTime(r.endAt)}',
    if (r.rentAmount > 0) 'Rent: ${fmtMoney(r.rentAmount)}',
    if (r.rentAmount > 0) 'Paid: ${fmtMoney(r.advancePaid)}',
    if (r.rentAmount > 0) 'Balance: ${fmtMoney(r.balanceDue)}',
    if (r.depositAmount > 0)
      'Deposit: ${fmtMoney(r.depositAmount)}'
          '${r.depositReturned == null ? ' (held)' : ' · returned ${fmtMoney(r.depositReturned!)}${r.depositKept > 0 ? ' · kept ${fmtMoney(r.depositKept)}' : ''}'}',
    'View / download: $url',
  ];
  return lines.join('\n');
}

/// Opens the composer. For a booking pass [rental] (message types + invoice); otherwise pass
/// [initialText] (e.g. a waitlist offer). Returns true if the message was handed to an app.
Future<bool> showMessageSheet(
  BuildContext context, {
  required String name,
  String? phone,
  String? email,
  String? instagram,
  Rental? rental,
  String? scenario,
  String? initialText,
  Channel? channel,
  String? title,
}) async {
  final channels = <Channel>[
    if ((phone ?? '').replaceAll(RegExp(r'[^0-9]'), '').length >= 6) Channel.whatsapp,
    if (email?.isNotEmpty ?? false) Channel.gmail,
    if (instagram?.isNotEmpty ?? false) Channel.instagram,
  ];
  if (channels.isEmpty) {
    showSnack(context, 'No phone, Gmail or Instagram saved for $name', error: true);
    return false;
  }
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.ivory,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _MessageSheet(
      name: name,
      phone: phone,
      email: email,
      instagram: instagram,
      rental: rental,
      scenario: scenario ?? (rental == null ? null : suggestedScenario(rental)),
      initialText: initialText,
      channels: channels,
      channel: channel != null && channels.contains(channel) ? channel : channels.first,
      title: title,
    ),
  );
  return sent == true;
}

/// Shortcut used after saving a booking / return / deposit: offers the message, can be skipped.
Future<void> offerBookingMessage(BuildContext context, Rental r, String scenario, {String? title}) async {
  final hasContact = (r.customerPhone?.isNotEmpty ?? false) ||
      (r.customerEmail?.isNotEmpty ?? false) ||
      (r.customerInstagram?.isNotEmpty ?? false);
  if (!hasContact || !context.mounted) return;
  await showMessageSheet(context,
      name: r.customerName,
      phone: r.customerPhone,
      email: r.customerEmail,
      instagram: r.customerInstagram,
      rental: r,
      scenario: scenario,
      title: title);
}

class _MessageSheet extends StatefulWidget {
  const _MessageSheet({
    required this.name,
    this.phone,
    this.email,
    this.instagram,
    this.rental,
    this.scenario,
    this.initialText,
    required this.channels,
    required this.channel,
    this.title,
  });

  final String name;
  final String? phone, email, instagram;
  final Rental? rental;
  final String? scenario;
  final String? initialText;
  final List<Channel> channels;
  final Channel channel;
  final String? title;

  @override
  State<_MessageSheet> createState() => _MessageSheetState();
}

class _MessageSheetState extends State<_MessageSheet> {
  late Channel _channel = widget.channel;
  late String _scenario = widget.scenario ?? 'custom';
  late bool _withInvoice = widget.rental != null && const {'booked', 'returned', 'deposit', 'payment'}.contains(_scenario);
  final _text = TextEditingController();
  (String, String)? _invoice; // (url, number)
  bool _loadingInvoice = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildText());
  }

  Future<void> _rebuildText() async {
    final r = widget.rental;
    if (r == null) {
      _text.text = widget.initialText ?? 'Hi ${widget.name},\n\n';
      return;
    }
    var msg = bookingMessage(r, _scenario);
    if (_withInvoice) {
      if (_invoice == null) {
        setState(() => _loadingInvoice = true);
        try {
          _invoice = await Api.instance.invoiceLink(r.id);
        } on ApiException catch (e) {
          _error = "Couldn't make the invoice link: ${e.message}";
        }
        if (!mounted) return;
        setState(() => _loadingInvoice = false);
      }
      if (_invoice != null) msg = '$msg\n\n${invoiceBlock(r, _invoice!.$2, _invoice!.$1)}';
    }
    setState(() => _text.text = msg);
  }

  String get _digits {
    final d = (widget.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    return d.length == 10 ? '91$d' : d; // assume India if no country code
  }

  Future<void> _send() async {
    final msg = _text.text.trim();
    if (msg.isEmpty) {
      setState(() => _error = 'Write a message first');
      return;
    }
    final Uri uri;
    switch (_channel) {
      case Channel.whatsapp:
        uri = Uri.parse('https://wa.me/$_digits?text=${Uri.encodeComponent(msg)}');
      case Channel.gmail:
        final subject = _invoice != null && _withInvoice
            ? 'Invoice ${_invoice!.$2} – ${_shop()}'
            : 'Message from ${_shop()}';
        uri = Uri(
          scheme: 'mailto',
          path: widget.email,
          query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(msg)}',
        );
      case Channel.instagram:
        // Instagram can't pre-fill a message: copy it, then open their chat to paste.
        try {
          await Clipboard.setData(ClipboardData(text: msg));
        } catch (_) {}
        uri = Uri.parse('https://ig.me/m/${Uri.encodeComponent(widget.instagram!.replaceAll('@', ''))}');
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = "Couldn't open ${_label(_channel)} on this device");
      return;
    }
    if (_channel == Channel.instagram) showSnack(context, 'Message copied — paste it in the Instagram chat');
    Navigator.pop(context, true);
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: _text.text));
      if (mounted) showSnack(context, 'Message copied');
    } catch (_) {
      if (mounted) showSnack(context, "Couldn't copy here", error: true);
    }
  }

  static String _label(Channel c) => switch (c) {
        Channel.whatsapp => 'WhatsApp',
        Channel.gmail => 'Gmail',
        Channel.instagram => 'Instagram',
      };

  static IconData _icon(Channel c) => switch (c) {
        Channel.whatsapp => Icons.chat_rounded,
        Channel.gmail => Icons.mail_rounded,
        Channel.instagram => Icons.camera_alt_rounded,
      };

  String _to(Channel c) => switch (c) {
        Channel.whatsapp => widget.phone ?? '',
        Channel.gmail => widget.email ?? '',
        Channel.instagram => '@${widget.instagram}',
      };

  @override
  Widget build(BuildContext context) {
    final r = widget.rental;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: Container(
                width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4))),
          ),
          const SizedBox(height: 14),
          Text(widget.title ?? 'Send message to ${widget.name}',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          // 1. Send via
          const _Label('Send via'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.channels
                .map((c) => ChoiceChip(
                      avatar: Icon(_icon(c), size: 18),
                      label: Text(_label(c)),
                      selected: _channel == c,
                      selectedColor: AppColors.goldSoft,
                      onSelected: (_) => setState(() => _channel = c),
                    ))
                .toList(),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('To: ${_to(_channel)}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
          if (r != null) ...[
            // 2. Message type
            const SizedBox(height: 12),
            const _Label('Message type'),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: kScenarios.entries
                    .map((e) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(e.value),
                            selected: _scenario == e.key,
                            selectedColor: AppColors.goldSoft,
                            onSelected: (_) {
                              _scenario = e.key;
                              _rebuildText();
                            },
                          ),
                        ))
                    .toList(),
              ),
            ),
            // 3. With / without invoice
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, icon: Icon(Icons.receipt_long_rounded), label: Text('Message + invoice')),
                ButtonSegment(value: false, icon: Icon(Icons.chat_bubble_outline_rounded), label: Text('Only message')),
              ],
              selected: {_withInvoice},
              onSelectionChanged: (v) {
                _withInvoice = v.first;
                _rebuildText();
              },
            ),
          ],
          // 4. Editable text
          const SizedBox(height: 12),
          Row(children: [
            const Expanded(child: _Label('Message (you can edit it)')),
            if (_loadingInvoice) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
          TextField(
            controller: _text,
            minLines: 6,
            maxLines: 14,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(alignLabelWithHint: true),
          ),
          if (r != null)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Changing the message type or invoice option rewrites the text.',
                  style: TextStyle(color: AppColors.muted, fontSize: 11)),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, style: const TextStyle(color: AppColors.overdue)),
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _loadingInvoice ? null : _send,
            icon: Icon(_icon(_channel)),
            label: Text('Send on ${_label(_channel)}'),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                  onPressed: _copy, icon: const Icon(Icons.copy_rounded, size: 18), label: const Text('Copy')),
            ),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Skip'))),
          ]),
        ]),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 11, letterSpacing: 1.3, fontWeight: FontWeight.w800, color: AppColors.muted)),
      );
}
