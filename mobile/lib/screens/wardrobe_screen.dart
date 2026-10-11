import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import 'cloth_detail_screen.dart';
import 'cloth_form_screen.dart';
import 'find_cloth.dart';
import 'scan_screen.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  final _search = TextEditingController();
  String? _status;
  Timer? _debounce;
  late Future<List<Cloth>> _future = _load();

  Future<List<Cloth>> _load() => Api.instance.cloths(q: _search.text.trim(), status: _status);

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reload);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _open(Cloth c) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ClothDetailScreen(clothId: c.id)));
    widget.onChanged();
  }

  Future<void> _add() async {
    final saved = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ClothFormScreen()));
    if (saved != null) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    const filters = {null: 'All', 'available': 'Available', 'on_rent': 'On rent', 'overdue': 'Overdue'};
    return Scaffold(
      appBar: AppBar(title: const Text('Wardrobe')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.plumDeep,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add cloth', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: _onSearch,
            onSubmitted: (v) => openClothByCode(context, v, onChanged: widget.onChanged),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search ID, name, category…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Scan tag',
                icon: const Icon(Icons.qr_code_scanner_rounded),
                onPressed: () async {
                  final code = await scanClothTag(context);
                  if (code != null && context.mounted) {
                    await openClothByCode(context, code, onChanged: widget.onChanged);
                  }
                },
              ),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: filters.entries
                .map((e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(e.value),
                        selected: _status == e.key,
                        selectedColor: AppColors.goldSoft,
                        onSelected: (_) {
                          _status = e.key;
                          _reload();
                        },
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: FutureBuilder<List<Cloth>>(
              future: _future,
              builder: (context, snap) {
                if (snap.hasError) {
                  return ListView(children: [ErrorRetry(snap.error.toString(), onRetry: _reload)]);
                }
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final items = snap.data!;
                if (items.isEmpty) {
                  return ListView(children: [
                    EmptyState(
                      icon: Icons.checkroom_rounded,
                      title: _search.text.isEmpty && _status == null ? 'No clothes yet' : 'Nothing matches',
                      subtitle: _search.text.isEmpty && _status == null ? 'Tap "Add cloth" to add your first outfit.' : null,
                    ),
                  ]);
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 230,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.62,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _ClothCard(items[i], onTap: () => _open(items[i])),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}

class _ClothCard extends StatelessWidget {
  const _ClothCard(this.c, {required this.onTap});
  final Cloth c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = c.currentRental;
    final hint = r != null
        ? 'Back ${fmtShort(r.endAt)}, ${fmtTime(r.endAt)}'
        : c.nextBooking != null
            ? 'Next out ${fmtShort(c.nextBooking!.startAt)}'
            : 'Ready to rent';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              Hero(tag: 'cloth-${c.id}', child: ClothImage(c.imageUrl, radius: 0)),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                  child: StatusChip(c.status, dense: true),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CodeTag(c.code),
              const SizedBox(height: 6),
              Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.forStatus(c.status), fontWeight: FontWeight.w600)),
              if (c.rentPrice > 0)
                Text('${fmtMoney(c.rentPrice)} / rent', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}
