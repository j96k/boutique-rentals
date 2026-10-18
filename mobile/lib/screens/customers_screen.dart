import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/amounts_sheet.dart';
import '../widgets/common.dart';
import '../widgets/inquiry_widgets.dart';
import '../widgets/rental_journey.dart';
import '../widgets/return_sheet.dart';
import 'cloth_detail_screen.dart';

/// Search customers by name or phone. Customers still owed a deposit come first.
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  late Future<List<CustomerSummary>> _future = Api.instance.customers('');

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reload);
  }

  Future<void> _reload() async {
    setState(() => _future = Api.instance.customers(_search.text.trim()));
    await _future;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _search,
            autofocus: true,
            onChanged: _onSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search name or phone number',
              prefixIcon: const Icon(Icons.person_search_rounded),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _search.clear();
                        _reload();
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: FutureBuilder<List<CustomerSummary>>(
              future: _future,
              builder: (context, snap) {
                if (snap.hasError) return ListView(children: [ErrorRetry(snap.error.toString(), onRetry: _reload)]);
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final list = snap.data!;
                if (list.isEmpty) {
                  return ListView(children: [
                    EmptyState(
                      icon: Icons.person_off_rounded,
                      title: _search.text.isEmpty ? 'No customers yet' : 'No customer found',
                      subtitle: _search.text.isEmpty
                          ? 'Customers appear here after their first booking.'
                          : 'Try part of the name, or the last digits of the phone number.',
                    ),
                  ]);
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _CustomerTile(
                    c: list[i],
                    onTap: () async {
                      await Navigator.push(
                          context, MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerKey: list[i].key)));
                      _reload();
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.c, required this.onTap});
  final CustomerSummary c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: CircleAvatar(
            backgroundColor: AppColors.goldSoft,
            child: Text(c.name.characters.first.toUpperCase(),
                style: const TextStyle(color: AppColors.plum, fontWeight: FontWeight.w800)),
          ),
          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            [
              c.phone ?? 'No phone',
              '${c.bookings} booking${c.bookings == 1 ? '' : 's'}',
              if (c.lastBookingAt != null) 'last ${fmtShort(c.lastBookingAt!)}',
            ].join('  •  '),
          ),
          trailing: c.depositsHeld > 0
              ? _Flag('Owes deposit\n${fmtMoney(c.depositsHeld)}', AppColors.overdue)
              : c.balanceDue > 0
                  ? _Flag('Rent due\n${fmtMoney(c.balanceDue)}', AppColors.onRent)
                  : const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(text,
            textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.ink)),
      );
}

/// One customer's complete history: bookings, rent, deposits (with dates), waitlist.
class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({super.key, required this.customerKey});
  final String customerKey;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late Future<CustomerDetail> _future = Api.instance.customer(widget.customerKey);

  Future<void> _reload() async {
    setState(() => _future = Api.instance.customer(widget.customerKey));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer history')),
      body: FutureBuilder<CustomerDetail>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorRetry(snap.error.toString(), onRetry: _reload);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final c = snap.data!;
          final held = c.rentals.where((r) => r.depositStatus == 'held').toList();
          final settled = c.rentals.where((r) => r.depositStatus == 'refunded' || r.depositStatus == 'part_kept').toList();
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
              _Header(c: c),
              const SizedBox(height: 10),
              Row(children: [
                _Stat('Bookings', '${c.bookings}'),
                const SizedBox(width: 8),
                _Stat('Total rent', fmtMoney(c.rentTotal)),
                const SizedBox(width: 8),
                _Stat('Rent due', fmtMoney(c.balanceDue), alert: c.balanceDue > 0),
              ]),
              const SectionTitle('Deposits'),
              if (held.isEmpty && settled.isEmpty)
                const _Note('No deposits taken from this customer.'),
              ...held.map((r) => _DepositRow(
                    r: r,
                    icon: Icons.warning_rounded,
                    color: AppColors.overdue,
                    title: 'Still with you: ${fmtMoney(r.depositAmount)}',
                    detail: '${r.clothCode} · ${fmtShort(r.startAt)} – ${fmtShort(r.endAt)}'
                        '${r.returnedAt != null ? ' · cloth returned ${fmtShort(r.returnedAt!)}' : ' · cloth not returned yet'}',
                    action: r.returnedAt == null
                        ? null
                        : TextButton(
                            onPressed: () async {
                              if (await settleDepositFlow(context, r)) _reload();
                            },
                            child: const Text('Settle'),
                          ),
                  )),
              ...settled.map((r) => _DepositRow(
                    r: r,
                    icon: r.depositStatus == 'refunded' ? Icons.check_circle_rounded : Icons.content_cut_rounded,
                    color: r.depositStatus == 'refunded' ? AppColors.available : AppColors.onRent,
                    title: r.depositStatus == 'refunded'
                        ? 'Returned ${fmtMoney(r.depositReturned ?? 0)} in full'
                        : 'Returned ${fmtMoney(r.depositReturned ?? 0)}, kept ${fmtMoney(r.depositKept)}',
                    detail: [
                      '${r.clothCode} · ${fmtShort(r.startAt)} – ${fmtShort(r.endAt)}',
                      if (r.depositSettledAt != null) 'given back ${fmtDateTime(r.depositSettledAt!)}',
                      if (r.depositNote?.isNotEmpty ?? false) 'reason: ${r.depositNote}',
                    ].join('\n'),
                  )),
              SectionTitle('All bookings', trailing: Text('${c.rentals.length}')),
              if (c.rentals.isEmpty) const _Note('No bookings yet.'),
              ...c.rentals.map((r) => _BookingRow(r: r, onChanged: _reload)),
              if (c.waitlist.isNotEmpty) ...[
                SectionTitle('Waitlist requests', trailing: Text('${c.waitlist.length}')),
                ...c.waitlist.map((i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InquiryCard(inquiry: i, onChanged: _reload, showCloth: true),
                    )),
              ],
            ]),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.c});
  final CustomerDetail c;

  @override
  Widget build(BuildContext context) {
    final digits = (c.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final wa = digits.length == 10 ? '91$digits' : digits;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.plumDeep, AppColors.plum]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        if (c.otherNames.isNotEmpty)
          Text('also booked as: ${c.otherNames.join(', ')}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        if (c.phone != null)
          CopyText(c.phone!, what: 'Phone number', icon: Icons.phone_rounded, light: true, fontSize: 15)
        else
          const Text('No phone number saved', style: TextStyle(color: AppColors.goldSoft)),
        if (c.depositsHeld > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.warning_rounded, color: AppColors.overdue, size: 18),
              const SizedBox(width: 6),
              Text('You still hold ${fmtMoney(c.depositsHeld)} deposit',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
            ]),
          ),
        ],
        if (digits.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            _HeaderButton(Icons.call_rounded, 'Call', () => launchUrl(Uri.parse('tel:${c.phone}'))),
            const SizedBox(width: 8),
            _HeaderButton(Icons.chat_rounded, 'WhatsApp',
                () => launchUrl(Uri.parse('https://wa.me/$wa'), mode: LaunchMode.externalApplication)),
          ]),
        ],
      ]),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: Colors.white, size: 17),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.alert = false});
  final String label, value;
  final bool alert;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: alert ? AppColors.onRent : AppColors.ink)),
              Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
        child: Text(text, style: const TextStyle(color: AppColors.muted)),
      );
}

class _DepositRow extends StatelessWidget {
  const _DepositRow(
      {required this.r, required this.icon, required this.color, required this.title, required this.detail, this.action});
  final Rental r;
  final IconData icon;
  final Color color;
  final String title, detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(detail, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35)),
                ]),
              ),
              ?action,
            ]),
          ),
        ),
      );
}

class _BookingRow extends StatelessWidget {
  const _BookingRow({required this.r, required this.onChanged});
  final Rental r;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => ClothDetailScreen(clothId: r.clothId)));
              onChanged();
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 48, height: 48, child: ClothImage(r.clothImage, radius: 12, iconSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      CodeTag(r.clothCode),
                      const SizedBox(width: 6),
                      Expanded(child: Text(r.clothName, overflow: TextOverflow.ellipsis)),
                      StatusChip(r.status, dense: true),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      '${fmtDateTime(r.startAt)} → ${fmtShort(r.endAt)}'
                      '${r.returnedAt != null ? '\nreturned ${fmtDateTime(r.returnedAt!)}' : ''}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.35),
                    ),
                    const SizedBox(height: 6),
                    MoneyLine(rental: r),
                  ]),
                ),
                IconButton(
                  tooltip: 'Edit amounts',
                  icon: const Icon(Icons.currency_rupee_rounded, color: AppColors.plum),
                  onPressed: () async {
                    if (await editAmountsFlow(context, r)) onChanged();
                  },
                ),
              ]),
            ),
          ),
        ),
      );
}
