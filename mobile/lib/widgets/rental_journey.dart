import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../screens/customers_screen.dart';
import '../theme.dart';
import '../utils.dart';
import 'common.dart';
import 'message_sheet.dart';

/// The signature card: a garment's trip from the boutique to the customer
/// and back, drawn like a thread with a needle moving along it.
class RentalJourneyCard extends StatefulWidget {
  const RentalJourneyCard(
      {super.key,
      required this.rental,
      this.onReturn,
      this.onEdit,
      this.onCancel,
      this.onAmounts,
      this.showCloth = false});
  final Rental rental;
  final VoidCallback? onReturn;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel; // shown for bookings that haven't gone out yet
  final VoidCallback? onAmounts; // edit rent / paid / deposit
  final bool showCloth;

  @override
  State<RentalJourneyCard> createState() => _RentalJourneyCardState();
}

class _RentalJourneyCardState extends State<RentalJourneyCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Keep the countdown fresh while the card is on screen.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rental;
    final now = DateTime.now();
    final status = r.returnedAt != null
        ? 'returned'
        : now.isBefore(r.startAt)
            ? 'booked'
            : now.isAfter(r.endAt)
                ? 'overdue'
                : 'on_rent';
    final color = AppColors.forStatus(status);
    final total = r.endAt.difference(r.startAt).inSeconds;
    final done = now.difference(r.startAt).inSeconds;
    final progress = status == 'returned' ? 1.0 : (total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0));

    final headline = switch (status) {
      'booked' => 'Goes out in ${fmtDuration(r.startAt.difference(now))}',
      'on_rent' => 'Comes back in ${fmtDuration(r.endAt.difference(now))}',
      'overdue' => 'Late by ${fmtDuration(now.difference(r.endAt))}',
      _ => 'Returned ${fmtDateTime(r.returnedAt!)}',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (widget.showCloth) ...[
              SizedBox(width: 46, height: 46, child: ClothImage(r.clothImage, radius: 12, iconSize: 20)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (widget.showCloth) ...[
                  Row(children: [
                    CodeTag(r.clothCode),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(r.clothName,
                            overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                  ]),
                  const SizedBox(height: 4),
                ],
                // Tap the name → this customer's full history.
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CustomerDetailScreen(customerKey: customerKey(r.customerName, r.customerPhone))),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(
                      child: Text(r.customerName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.history_rounded, size: 16, color: AppColors.plumSoft),
                  ]),
                ),
                if (r.customerPhone != null && r.customerPhone!.isNotEmpty)
                  CopyText(r.customerPhone!, what: 'Phone number'),
              ]),
            ),
            StatusChip(status, dense: true),
          ]),
          const SizedBox(height: 14),
          Text(headline, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 10),
          _Thread(progress: progress, color: color),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _Stop(label: 'OUT', date: r.startAt, icon: Icons.north_east_rounded)),
            Expanded(
              child: _Stop(label: 'RETURN', date: r.endAt, icon: Icons.south_west_rounded, alignEnd: true),
            ),
          ]),
          if (r.rentAmount > 0 || r.depositAmount > 0 || (r.notes?.isNotEmpty ?? false)) ...[
            const Divider(height: 24),
            MoneyLine(rental: r),
            if (r.notes?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(r.notes!, style: const TextStyle(color: AppColors.muted)),
              ),
          ],
          if (r.isActive && (widget.onReturn != null || widget.onEdit != null || widget.onCancel != null || widget.onAmounts != null || r.customerPhone != null || r.customerEmail != null || r.customerInstagram != null)) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (widget.onReturn != null && status != 'booked')
                _Action(Icons.assignment_turned_in_rounded, 'Mark returned', widget.onReturn!, filled: true),
              if (widget.onEdit != null) _Action(Icons.edit_calendar_rounded, 'Change', widget.onEdit!),
              if (widget.onAmounts != null) _Action(Icons.currency_rupee_rounded, 'Amounts', widget.onAmounts!),
              if (widget.onCancel != null && status == 'booked')
                _Action(Icons.event_busy_rounded, 'Cancel booking', widget.onCancel!, danger: true),
              if (r.customerPhone?.isNotEmpty ?? false) ...[
                _Action(Icons.call_rounded, 'Call', () => launchUrl(Uri.parse('tel:${r.customerPhone}'))),
                _Action(Icons.chat_rounded, 'WhatsApp', () => _message(Channel.whatsapp)),
              ],
              if (r.customerInstagram?.isNotEmpty ?? false)
                _Action(Icons.camera_alt_rounded, 'Instagram', () => _message(Channel.instagram)),
              if (r.customerEmail?.isNotEmpty ?? false) _Action(Icons.mail_rounded, 'Gmail', () => _message(Channel.gmail)),
            ]),
          ],
        ]),
      ),
    );
  }

  /// Opens the composer: message type + optional invoice, editable, then WhatsApp / Gmail / Instagram.
  void _message(Channel channel) {
    final r = widget.rental;
    showMessageSheet(context,
        name: r.customerName,
        phone: r.customerPhone,
        email: r.customerEmail,
        instagram: r.customerInstagram,
        rental: r,
        channel: channel);
  }

}

class _Thread extends StatelessWidget {
  const _Thread({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      return SizedBox(
        height: 22,
        child: Stack(alignment: Alignment.centerLeft, children: [
          // dashed "stitch" track
          Row(
            children: List.generate(
              (w / 9).floor(),
              (_) => Container(
                width: 5,
                height: 2,
                margin: const EdgeInsets.only(right: 4),
                color: AppColors.line,
              ),
            ),
          ),
          Container(
            width: w * progress,
            height: 4,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
          Positioned(
            left: (w - 22) * progress,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
              ),
              child: Icon(Icons.checkroom_rounded, size: 11, color: color),
            ),
          ),
        ]),
      );
    });
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.label, required this.date, required this.icon, this.alignEnd = false});
  final String label;
  final DateTime date;
  final IconData icon;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final align = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(crossAxisAlignment: align, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: AppColors.muted),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: AppColors.muted)),
      ]),
      const SizedBox(height: 2),
      Text(fmtDay(date), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      Text(fmtTime(date), style: const TextStyle(color: AppColors.plumSoft, fontWeight: FontWeight.w600, fontSize: 13)),
    ]);
  }
}

class _Action extends StatelessWidget {
  const _Action(this.icon, this.label, this.onTap, {this.filled = false, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : (danger ? AppColors.overdue : AppColors.plum);
    return Material(
      color: filled ? AppColors.plum : (danger ? AppColors.overdue.withValues(alpha: 0.08) : AppColors.ivory),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 17, color: fg),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: fg)),
          ]),
        ),
      ),
    );
  }
}

/// "Rent ₹4,500 · Paid ₹2,000 · Due ₹2,500" and the deposit state, as small chips.
class MoneyLine extends StatelessWidget {
  const MoneyLine({super.key, required this.rental});
  final Rental rental;

  @override
  Widget build(BuildContext context) {
    final r = rental;
    final chips = <Widget>[
      if (r.rentAmount > 0) _MoneyChip('Rent ${fmtMoney(r.rentAmount)}', AppColors.plum),
      if (r.rentAmount > 0)
        r.balanceDue > 0
            ? _MoneyChip('Due ${fmtMoney(r.balanceDue)}', AppColors.onRent, icon: Icons.schedule_rounded)
            : const _MoneyChip('Rent paid', AppColors.available, icon: Icons.check_rounded),
      if (r.rentAmount > 0 && r.advancePaid > 0 && r.balanceDue > 0)
        _MoneyChip('Paid ${fmtMoney(r.advancePaid)}', AppColors.muted),
      ...switch (r.depositStatus) {
        'held' => [_MoneyChip('Deposit ${fmtMoney(r.depositAmount)} held', AppColors.booked, icon: Icons.shield_rounded)],
        'refunded' => [_MoneyChip('Deposit returned', AppColors.available, icon: Icons.check_rounded)],
        'part_kept' => [
            _MoneyChip('Deposit: kept ${fmtMoney(r.depositKept)}', AppColors.overdue, icon: Icons.report_rounded)
          ],
        _ => <Widget>[],
      },
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 6, runSpacing: 6, children: chips),
      if (r.depositStatus == 'part_kept' && (r.depositNote?.isNotEmpty ?? false))
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Reason: ${r.depositNote}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ),
    ]);
  }
}

class _MoneyChip extends StatelessWidget {
  const _MoneyChip(this.text, this.color, {this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 3)],
          // Text stays in ink colour; the tinted chip + icon carry the meaning.
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink)),
        ]),
      );
}
