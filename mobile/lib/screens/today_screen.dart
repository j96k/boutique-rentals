import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/rental_journey.dart';
import 'cloth_detail_screen.dart';
import 'find_cloth.dart';
import 'scan_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.onChanged, required this.onOpenWardrobe});
  final VoidCallback onChanged;
  final VoidCallback onOpenWardrobe;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late Future<Dashboard> _future = Api.instance.dashboard();
  final _search = TextEditingController();

  Future<void> _reload() async {
    setState(() => _future = Api.instance.dashboard());
    await _future;
  }

  Future<void> _find([String? code]) async {
    final c = code ?? _search.text;
    await openClothByCode(context, c, onChanged: widget.onChanged);
  }

  Future<void> _scan() async {
    final code = await scanClothTag(context);
    if (code != null && mounted) await _find(code);
  }

  Future<void> _return(Rental r) async {
    if (!await confirm(context, 'Mark returned?', '${r.clothName} (${r.clothCode}) from ${r.customerName}')) return;
    try {
      await Api.instance.markReturned(r.id);
      if (mounted) showSnack(context, 'Marked as returned ✓');
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _reload,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _header()),
          SliverToBoxAdapter(
            child: FutureBuilder<Dashboard>(
              future: _future,
              builder: (context, snap) {
                if (snap.hasError) return ErrorRetry(snap.error.toString(), onRetry: _reload);
                if (!snap.hasData) {
                  return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
                }
                return _body(snap.data!);
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _header() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.plumDeep, AppColors.plum], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 18, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$_greeting,', style: const TextStyle(color: Colors.white70, fontSize: 15)),
        Text(Api.instance.user?.boutiqueName ?? 'Boutique',
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(fmtDay(DateTime.now()), style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        // The heart of the app: find any cloth by its ID in one step.
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          padding: const EdgeInsets.only(left: 6),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _search,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _find(),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 1),
                decoration: const InputDecoration(
                  hintText: 'Type Cloth ID  e.g. LH001',
                  hintStyle: TextStyle(fontWeight: FontWeight.w400, letterSpacing: 0, color: AppColors.muted),
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.plum),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Material(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _scan,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.qr_code_scanner_rounded, color: AppColors.plumDeep),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _body(Dashboard d) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _Stat('Available', d.available, AppColors.available, Icons.check_circle_rounded),
          const SizedBox(width: 10),
          _Stat('On rent', d.onRent, AppColors.onRent, Icons.shopping_bag_rounded),
          const SizedBox(width: 10),
          _Stat('Overdue', d.overdue, AppColors.overdue, Icons.warning_rounded),
        ]),
        if (d.total == 0)
          EmptyState(
            icon: Icons.checkroom_rounded,
            title: 'Your wardrobe is empty',
            subtitle: 'Add your first cloth with a photo and an ID like LH001.',
            action: SizedBox(
                width: 200, child: FilledButton(onPressed: widget.onOpenWardrobe, child: const Text('Go to Wardrobe'))),
          ),
        if (d.overdueList.isNotEmpty) ...[
          SectionTitle('Overdue — follow up', trailing: Text('${d.overdueList.length}')),
          ...d.overdueList.map(_card),
        ],
        SectionTitle('Going out today', trailing: Text('${d.goingOutToday.length}')),
        if (d.goingOutToday.isEmpty) const _Nothing('No pickups scheduled today'),
        ...d.goingOutToday.map(_card),
        SectionTitle('Coming back today', trailing: Text('${d.returningToday.length}')),
        if (d.returningToday.isEmpty) const _Nothing('No returns due today'),
        ...d.returningToday.map(_card),
      ]),
    );
  }

  Widget _card(Rental r) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GestureDetector(
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => ClothDetailScreen(clothId: r.clothId)));
            widget.onChanged();
          },
          child: RentalJourneyCard(rental: r, showCloth: true, onReturn: () => _return(r)),
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color, this.icon);
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 8),
              Text('$value', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}

class _Nothing extends StatelessWidget {
  const _Nothing(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
      );
}
