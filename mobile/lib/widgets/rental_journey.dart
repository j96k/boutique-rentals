import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import 'common.dart';

/// The signature card: a garment's trip from the boutique to the customer
/// and back, drawn like a thread with a needle moving along it.
class RentalJourneyCard extends StatefulWidget {
  const RentalJourneyCard({super.key, required this.rental, this.onReturn, this.onEdit, this.showCloth = false});
  final Rental rental;
  final VoidCallback? onReturn;
  final VoidCallback? onEdit;
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
                Text(r.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                if (r.customerPhone != null && r.customerPhone!.isNotEmpty)
                  Text(r.customerPhone!, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
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
          if (r.advancePaid > 0 || (r.notes?.isNotEmpty ?? false)) ...[
            const Divider(height: 24),
            if (r.advancePaid > 0)
              Text('Advance paid: ${fmtMoney(r.advancePaid)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            if (r.notes?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(r.notes!, style: const TextStyle(color: AppColors.muted)),
              ),
          ],
          if (r.isActive && (widget.onReturn != null || widget.onEdit != null || r.customerPhone != null)) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (widget.onReturn != null && status != 'booked')
                _Action(Icons.assignment_turned_in_rounded, 'Mark returned', widget.onReturn!, filled: true),
              if (widget.onEdit != null) _Action(Icons.edit_calendar_rounded, 'Change', widget.onEdit!),
              if (r.customerPhone?.isNotEmpty ?? false) ...[
                _Action(Icons.call_rounded, 'Call', () => launchUrl(Uri.parse('tel:${r.customerPhone}'))),
                _Action(Icons.chat_rounded, 'WhatsApp', () => _whatsApp(r, status)),
              ],
            ]),
          ],
        ]),
      ),
    );
  }

  void _whatsApp(Rental r, String status) {
    final digits = r.customerPhone!.replaceAll(RegExp(r'[^0-9]'), '');
    final phone = digits.length == 10 ? '91$digits' : digits; // assume India if no country code
    final msg = status == 'overdue'
        ? 'Hello ${r.customerName}, a gentle reminder: "${r.clothName}" (${r.clothCode}) was due back on ${fmtDateTime(r.endAt)}. Please return it at the earliest. Thank you!'
        : 'Hello ${r.customerName}, a reminder that "${r.clothName}" (${r.clothCode}) is due back on ${fmtDateTime(r.endAt)}. Thank you!';
    launchUrl(Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(msg)}'), mode: LaunchMode.externalApplication);
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
  const _Action(this.icon, this.label, this.onTap, {this.filled = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.plum : AppColors.ivory,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 17, color: filled ? Colors.white : AppColors.plum),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13, color: filled ? Colors.white : AppColors.plum)),
          ]),
        ),
      ),
    );
  }
}
