import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../screens/cloth_detail_screen.dart';
import '../screens/inquiry_form_screen.dart';
import '../screens/rental_form_screen.dart';
import '../theme.dart';
import '../utils.dart';
import 'common.dart';

Color inquiryStatusColor(String s) => switch (s) {
      'waiting' => AppColors.booked,
      'contacted' => AppColors.onRent,
      'booked' => AppColors.available,
      _ => AppColors.returned,
    };

String inquiryStatusLabel(String s) => switch (s) {
      'waiting' => 'Waiting',
      'contacted' => 'Contacted',
      'booked' => 'Booked',
      'not_interested' => 'Not interested',
      _ => s,
    };

String inquiryDates(Inquiry i) =>
    i.hasDates ? 'Wants ${fmtShort(i.wantedFrom!)} – ${fmtShort(i.wantedTo!)}' : 'Any dates';

String _offerMessage(Inquiry i) {
  final boutique = Api.instance.user?.boutiqueName ?? 'our boutique';
  final dates = i.hasDates ? ' for ${fmtShort(i.wantedFrom!)} – ${fmtShort(i.wantedTo!)}' : '';
  return 'Hi ${i.name}, good news from $boutique! "${i.clothName}" (${i.clothCode}) is now available$dates. '
      'Are you still interested? Please reply to confirm your booking.';
}

/// Opens Call / WhatsApp / Instagram / Gmail, then marks a waiting inquiry as "contacted".
Future<void> contactInquiry(BuildContext context, Inquiry i, String how, {VoidCallback? onChanged}) async {
  final Uri uri;
  switch (how) {
    case 'call':
      uri = Uri.parse('tel:${i.phone}');
    case 'whatsapp':
      final digits = i.phone!.replaceAll(RegExp(r'[^0-9]'), '');
      final phone = digits.length == 10 ? '91$digits' : digits; // assume India if no country code
      uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(_offerMessage(i))}');
    case 'instagram':
      uri = Uri.parse('https://instagram.com/${Uri.encodeComponent(i.instagram!)}');
    default:
      uri = Uri(scheme: 'mailto', path: i.email, query: _mailQuery(i));
  }
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) {
    if (context.mounted) showSnack(context, 'Could not open the app for this', error: true);
    return;
  }
  if (i.status == 'waiting') {
    try {
      await Api.instance.setInquiryStatus(i.id, 'contacted');
      onChanged?.call();
    } on ApiException catch (_) {}
  }
}

String _mailQuery(Inquiry i) => 'subject=${Uri.encodeComponent('${i.clothName} (${i.clothCode}) is available')}'
    '&body=${Uri.encodeComponent(_offerMessage(i))}';

/// Opens the booking form filled from the inquiry; marks it "booked" when saved.
Future<bool> convertInquiryToBooking(BuildContext context, Inquiry i) async {
  try {
    final cloth = await Api.instance.cloth(i.clothId);
    if (!context.mounted) return false;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RentalFormScreen(cloth: cloth, fromInquiry: i)),
    );
    return ok == true;
  } on ApiException catch (e) {
    if (context.mounted) showSnack(context, e.message, error: true);
    return false;
  }
}

class InquiryCard extends StatelessWidget {
  const InquiryCard({super.key, required this.inquiry, required this.onChanged, this.showCloth = false});
  final Inquiry inquiry;
  final VoidCallback onChanged;
  final bool showCloth;

  Future<void> _menu(BuildContext context, String action) async {
    final i = inquiry;
    try {
      switch (action) {
        case 'edit':
          final saved = await Navigator.push(
              context, MaterialPageRoute(builder: (_) => InquiryFormScreen(clothId: i.clothId, inquiry: i)));
          if (saved != null) onChanged();
        case 'open':
          await Navigator.push(context, MaterialPageRoute(builder: (_) => ClothDetailScreen(clothId: i.clothId)));
          onChanged();
        case 'convert':
          if (await convertInquiryToBooking(context, i)) onChanged();
        case 'delete':
          if (!await confirm(context, 'Delete inquiry?', 'Remove ${i.name} from the waitlist?', ok: 'Delete', danger: true)) {
            return;
          }
          await Api.instance.deleteInquiry(i.id);
          onChanged();
        default: // a status
          await Api.instance.setInquiryStatus(i.id, action);
          onChanged();
      }
    } on ApiException catch (e) {
      if (context.mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = inquiry;
    final color = inquiryStatusColor(i.status);
    return Opacity(
      opacity: i.isOpen ? 1 : 0.6,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (showCloth) ...[
                SizedBox(width: 44, height: 44, child: ClothImage(i.clothImage, radius: 10, iconSize: 18)),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (showCloth) ...[CodeTag(i.clothCode), const SizedBox(height: 4)],
                  Row(children: [
                    Flexible(
                      child: Text(i.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                    if (i.source == 'customer') ...[
                      const SizedBox(width: 6),
                      const Tooltip(
                        message: 'Added by the customer',
                        child: Icon(Icons.public_rounded, size: 15, color: AppColors.plumSoft),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(inquiryDates(i), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  if (i.phone != null) CopyText(i.phone!, what: 'Phone number', icon: Icons.phone_rounded),
                  if (i.email != null) CopyText(i.email!, what: 'Gmail', icon: Icons.mail_rounded),
                  if (i.instagram != null) CopyText(i.instagram!, what: 'Instagram ID', icon: Icons.camera_alt_rounded),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(i.offeredAmount > 0 ? fmtMoney(i.offeredAmount) : 'No offer',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: i.offeredAmount > 0 ? AppColors.plum : AppColors.muted)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(inquiryStatusLabel(i.status),
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ]),
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (a) => _menu(context, a),
                itemBuilder: (_) => [
                  if (showCloth) PopupMenuItem(value: 'open', child: Text('Open ${i.clothCode}')),
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (i.isOpen) const PopupMenuItem(value: 'convert', child: Text('Convert to booking')),
                  if (i.status != 'contacted' && i.isOpen)
                    const PopupMenuItem(value: 'contacted', child: Text('Mark contacted')),
                  if (i.isOpen) const PopupMenuItem(value: 'not_interested', child: Text('Not interested')),
                  if (!i.isOpen) const PopupMenuItem(value: 'waiting', child: Text('Back to waiting')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.overdue))),
                ],
              ),
            ]),
            if (i.notes?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 10),
                child: Text(i.notes!, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              ),
            if (i.isOpen) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (i.phone != null) ...[
                  _ContactChip(Icons.call_rounded, 'Call', () => contactInquiry(context, i, 'call', onChanged: onChanged)),
                  _ContactChip(Icons.chat_rounded, 'WhatsApp',
                      () => contactInquiry(context, i, 'whatsapp', onChanged: onChanged)),
                ],
                if (i.instagram != null)
                  _ContactChip(Icons.camera_alt_rounded, '@${i.instagram}',
                      () => contactInquiry(context, i, 'instagram', onChanged: onChanged)),
                if (i.email != null)
                  _ContactChip(Icons.mail_rounded, 'Gmail', () => contactInquiry(context, i, 'email', onChanged: onChanged)),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

class _ContactChip extends StatelessWidget {
  const _ContactChip(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.ivory,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: AppColors.plum),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.plum)),
              ),
            ]),
          ),
        ),
      );
}

/// Asks, cancels the booking, then shows who's waiting for the freed dates. Returns true if cancelled.
Future<bool> cancelBookingAndShowWaitlist(BuildContext context, Rental r) async {
  if (!await confirm(context, 'Cancel this booking?',
      "${r.customerName}'s booking (${fmtShort(r.startAt)} – ${fmtShort(r.endAt)}) will be removed.",
      ok: 'Cancel booking', danger: true)) {
    return false;
  }
  try {
    await Api.instance.deleteRental(r.id);
  } on ApiException catch (e) {
    if (context.mounted) showSnack(context, e.message, error: true);
    return false;
  }
  if (context.mounted) showSnack(context, 'Booking cancelled');
  // Freed dates (only the part not already over) → show who's waiting for them.
  final now = DateTime.now();
  if (context.mounted && r.endAt.isAfter(now)) {
    await showWaitlistSheet(context,
        clothId: r.clothId, clothCode: r.clothCode, from: r.startAt.isAfter(now) ? r.startAt : now, to: r.endAt);
  }
  return true;
}

/// After a cancellation or early return: shows who wants the cloth for the freed dates.
Future<void> showWaitlistSheet(
  BuildContext context, {
  required int clothId,
  required String clothCode,
  required DateTime from,
  required DateTime to,
}) async {
  List<Inquiry> people;
  try {
    people = await Api.instance.matchingInquiries(clothId, from, to);
  } on ApiException catch (_) {
    return; // the cancellation itself worked; the waitlist is a bonus
  }
  if (people.isEmpty || !context.mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.ivory,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => _WaitlistSheet(clothId: clothId, clothCode: clothCode, from: from, to: to, initial: people),
  );
}

class _WaitlistSheet extends StatefulWidget {
  const _WaitlistSheet(
      {required this.clothId, required this.clothCode, required this.from, required this.to, required this.initial});
  final int clothId;
  final String clothCode;
  final DateTime from, to;
  final List<Inquiry> initial;

  @override
  State<_WaitlistSheet> createState() => _WaitlistSheetState();
}

class _WaitlistSheetState extends State<_WaitlistSheet> {
  late List<Inquiry> _people = widget.initial;

  Future<void> _reload() async {
    try {
      final p = await Api.instance.matchingInquiries(widget.clothId, widget.from, widget.to);
      if (mounted) setState(() => _people = p);
    } on ApiException catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        Center(
          child: Container(
              width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4))),
        ),
        const SizedBox(height: 16),
        Row(children: [
          const Icon(Icons.celebration_rounded, color: AppColors.gold, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${widget.clothCode} is free ${fmtShort(widget.from)} – ${fmtShort(widget.to)}',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          '${_people.length} ${_people.length == 1 ? 'person wants' : 'people want'} it — best offer first. '
          'Tap WhatsApp to send a ready-made message.',
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        if (_people.isEmpty) const Text('Everyone on the list has been handled ✓'),
        ..._people.map((i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InquiryCard(inquiry: i, onChanged: _reload),
            )),
        const SizedBox(height: 6),
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ]),
    );
  }
}
