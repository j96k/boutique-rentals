import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/booking_calendar.dart';
import '../widgets/common.dart';
import '../widgets/rental_journey.dart';
import 'cloth_form_screen.dart';
import 'rental_form_screen.dart';

class ClothDetailScreen extends StatefulWidget {
  const ClothDetailScreen({super.key, required this.clothId});
  final int clothId;

  @override
  State<ClothDetailScreen> createState() => _ClothDetailScreenState();
}

class _ClothDetailScreenState extends State<ClothDetailScreen> {
  late Future<Cloth> _future = Api.instance.cloth(widget.clothId);
  DateTime? _selectedDay;

  Future<void> _reload() async {
    setState(() => _future = Api.instance.cloth(widget.clothId));
    await _future;
  }

  Future<void> _newRental(Cloth c, {Rental? edit, DateTime? startDay}) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RentalFormScreen(cloth: c, rental: edit, startDay: startDay)),
    );
    if (ok == true) _reload();
  }

  Future<void> _return(Rental r) async {
    if (!await confirm(context, 'Mark returned?', 'Did ${r.customerName} return this cloth?')) return;
    try {
      await Api.instance.markReturned(r.id);
      if (mounted) showSnack(context, 'Marked as returned ✓');
      _reload();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  Future<void> _delete(Cloth c) async {
    if (!await confirm(context, 'Delete ${c.code}?', 'This removes the cloth and its whole rental history.',
        ok: 'Delete', danger: true)) {
      return;
    }
    try {
      await Api.instance.deleteCloth(c.id);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  void _showQr(Cloth c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Cloth tag', textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 220, height: 220, child: QrImageView(data: c.code, backgroundColor: Colors.white)),
          const SizedBox(height: 8),
          Text(c.code, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2)),
          Text(c.name, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          const Text('Take a screenshot and print it. Stick it on the hanger tag — then just scan to find this cloth.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Cloth>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(appBar: AppBar(), body: ErrorRetry(snap.error.toString(), onRetry: _reload));
        }
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        return _page(snap.data!);
      },
    );
  }

  Widget _page(Cloth c) {
    final active = c.rentals.where((r) => r.isActive).toList()..sort((a, b) => a.startAt.compareTo(b.startAt));
    final upcoming = active.where((r) => r.id != c.currentRental?.id).toList();
    final history = c.rentals.where((r) => !r.isActive).toList();
    final ranges = active.map((r) => CalendarRange(r.startAt, r.endAt, AppColors.forStatus(r.status))).toList();
    final onDay = _selectedDay == null
        ? <Rental>[]
        : c.rentals.where((r) => rangeTouchesDay(r.startAt, r.endAt, _selectedDay!)).toList();

    return Scaffold(
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: () => _newRental(c),
          icon: const Icon(Icons.add_shopping_cart_rounded),
          label: const Text('Give on rent / Book'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: CustomScrollView(slivers: [
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            backgroundColor: AppColors.plumDeep,
            foregroundColor: Colors.white,
            actions: [
              IconButton(tooltip: 'QR tag', onPressed: () => _showQr(c), icon: const Icon(Icons.qr_code_2_rounded)),
              IconButton(
                tooltip: 'Edit',
                onPressed: () async {
                  final saved = await Navigator.push(context, MaterialPageRoute(builder: (_) => ClothFormScreen(cloth: c)));
                  if (saved != null) _reload();
                },
                icon: const Icon(Icons.edit_rounded),
              ),
              IconButton(tooltip: 'Delete', onPressed: () => _delete(c), icon: const Icon(Icons.delete_outline_rounded)),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                Hero(tag: 'cloth-${c.id}', child: ClothImage(c.imageUrl, radius: 0, iconSize: 80)),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66000000), Colors.transparent, Color(0xCC26122F)],
                      stops: [0, 0.4, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 18,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      CodeTag(c.code, light: true),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                        child: StatusChip(c.status, dense: true),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(c.name,
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            sliver: SliverList.list(children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (c.rentPrice > 0) _InfoPill(Icons.currency_rupee_rounded, '${fmtMoney(c.rentPrice)} / rent'),
                if (c.category != null) _InfoPill(Icons.category_rounded, c.category!),
                if (c.size != null) _InfoPill(Icons.straighten_rounded, 'Size ${c.size}'),
              ]),
              if (c.description.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(c.description, style: const TextStyle(fontSize: 15, height: 1.5)),
              ],
              const SectionTitle('Right now'),
              if (c.currentRental != null)
                RentalJourneyCard(
                  rental: c.currentRental!,
                  onReturn: () => _return(c.currentRental!),
                  onEdit: () => _newRental(c, edit: c.currentRental),
                )
              else
                _AvailableBanner(next: c.nextBooking),
              const SectionTitle('Booking calendar'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  child: Column(children: [
                    BookingCalendar(
                      ranges: ranges,
                      selected: _selectedDay,
                      onDayTap: (d) => setState(() => _selectedDay = d),
                    ),
                    CalendarLegend(items: const {
                      'Booked': AppColors.booked,
                      'On rent': AppColors.onRent,
                      'Overdue': AppColors.overdue,
                    }),
                  ]),
                ),
              ),
              if (_selectedDay != null) ...[
                SectionTitle(fmtDay(_selectedDay!),
                    trailing: onDay.isEmpty
                        ? TextButton.icon(
                            onPressed: () => _newRental(c, startDay: _selectedDay),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Book this day'),
                          )
                        : null),
                if (onDay.isEmpty)
                  const Text('Free on this day ✓',
                      style: TextStyle(color: AppColors.available, fontWeight: FontWeight.w700)),
                ...onDay.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RentalJourneyCard(
                          rental: r, onReturn: () => _return(r), onEdit: () => _newRental(c, edit: r)),
                    )),
              ],
              if (upcoming.isNotEmpty) ...[
                SectionTitle('Upcoming bookings', trailing: Text('${upcoming.length}')),
                ...upcoming.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RentalJourneyCard(
                          rental: r, onReturn: () => _return(r), onEdit: () => _newRental(c, edit: r)),
                    )),
              ],
              if (history.isNotEmpty) ...[
                SectionTitle('History', trailing: Text('${history.length} rentals')),
                ...history.map((r) => _HistoryTile(r)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: AppColors.plumSoft),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}

class _AvailableBanner extends StatelessWidget {
  const _AvailableBanner({this.next});
  final Rental? next;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.available.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.available.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.available, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('In the boutique — available',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.available)),
              Text(
                next == null
                    ? 'No upcoming bookings'
                    : 'Next booking: ${next!.customerName}, ${fmtDateTime(next!.startAt)}',
                style: const TextStyle(color: AppColors.muted),
              ),
            ]),
          ),
        ]),
      );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile(this.r);
  final Rental r;

  @override
  Widget build(BuildContext context) {
    final late = r.returnedAt!.isAfter(r.endAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.goldSoft,
            child: Text(r.customerName.characters.first.toUpperCase(),
                style: const TextStyle(color: AppColors.plum, fontWeight: FontWeight.w800)),
          ),
          title: Text(r.customerName, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${fmtShort(r.startAt)} → ${fmtShort(r.endAt)}  •  returned ${fmtShort(r.returnedAt!)}'),
          trailing: late
              ? const Tooltip(message: 'Returned late', child: Icon(Icons.schedule_rounded, color: AppColors.overdue))
              : const Icon(Icons.check_rounded, color: AppColors.available),
        ),
      ),
    );
  }
}
