import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';

const _categories = {
  'feature': ('New feature', Icons.auto_awesome_rounded),
  'change': ('Change something', Icons.tune_rounded),
  'problem': ('Problem / bug', Icons.bug_report_rounded),
  'other': ('Other', Icons.chat_rounded),
};

const _statuses = {
  'new': ('Sent', AppColors.booked),
  'seen': ('Seen', AppColors.plumSoft),
  'planned': ('Planned', AppColors.onRent),
  'done': ('Done ✓', AppColors.available),
  'not_planned': ('Not planned', AppColors.returned),
};

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _statuses[status] ?? (status, AppColors.muted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.ink)),
    );
  }
}

/// Every boutique can ask for changes / new features in any language, and see the answers.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  String _category = 'feature';
  final _message = TextEditingController();
  late final _contact = TextEditingController(text: Api.instance.user?.phone ?? '');
  bool _busy = false;
  late Future<List<FeedbackItem>> _mine = Api.instance.myFeedback();

  Future<void> _send() async {
    if (_message.text.trim().length < 3) {
      showSnack(context, 'Please write your idea first', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.instance.sendFeedback(_category, _message.text.trim(), _contact.text.trim());
      if (!mounted) return;
      _message.clear();
      showSnack(context, 'Thank you! We received it 🙏');
      setState(() => _mine = Api.instance.myFeedback());
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ideas & requests')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.goldSoft, borderRadius: BorderRadius.circular(16)),
          child: const Text(
            'Want something changed or a new feature? Tell us — write in any language you like '
            '(English, हिंदी, ગુજરાતી, मराठी, தமிழ்…). We read every request and upgrade the app.',
            style: TextStyle(height: 1.4),
          ),
        ),
        const SectionTitle('What is it about?'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.entries
              .map((e) => ChoiceChip(
                    avatar: Icon(e.value.$2, size: 18),
                    label: Text(e.value.$1),
                    selected: _category == e.key,
                    selectedColor: AppColors.goldSoft,
                    onSelected: (_) => setState(() => _category = e.key),
                  ))
              .toList(),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _message,
          minLines: 5,
          maxLines: 12,
          maxLength: 4000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Your idea / request (any language)',
            hintText: 'e.g. Please add SMS reminders… / कृपया SMS रिमाइंडर जोड़ें…',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _contact,
          decoration: const InputDecoration(
              labelText: 'Phone / Gmail to reach you (optional)', prefixIcon: Icon(Icons.contact_phone_rounded)),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _busy ? null : _send,
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded),
          label: const Text('Send'),
        ),
        const SectionTitle('Your requests'),
        FutureBuilder<List<FeedbackItem>>(
          future: _mine,
          builder: (context, snap) {
            if (snap.hasError) {
              return ErrorRetry(snap.error.toString(), onRetry: () => setState(() => _mine = Api.instance.myFeedback()));
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.isEmpty) {
              return const Text('Nothing sent yet.', style: TextStyle(color: AppColors.muted));
            }
            return Column(children: snap.data!.map((f) => _FeedbackCard(f: f)).toList());
          },
        ),
      ]),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.f, this.admin = false, this.onTap});
  final FeedbackItem f;
  final bool admin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = _categories[f.category] ?? ('Other', Icons.chat_rounded);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 18, color: AppColors.plumSoft),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('$label · ${fmtShort(f.createdAt)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                _StatusChip(f.status),
              ]),
              if (admin) ...[
                const SizedBox(height: 6),
                Text('${f.boutiqueName} (@${f.username})', style: const TextStyle(fontWeight: FontWeight.w800)),
                Wrap(spacing: 10, children: [
                  if (f.boutiquePhone != null) CopyText(f.boutiquePhone!, what: 'Phone number', icon: Icons.phone_rounded),
                  if (f.contact != null && f.contact != f.boutiquePhone)
                    CopyText(f.contact!, what: 'Contact', icon: Icons.contact_phone_rounded),
                ]),
              ],
              const SizedBox(height: 8),
              // Selectable on the boutique's own list; plain text when the card is tappable (admin list),
              // so a tap anywhere opens the reply dialog (which shows the message as selectable text).
              if (onTap == null)
                SelectableText(f.message, style: const TextStyle(fontSize: 15, height: 1.4))
              else
                Text(f.message, style: const TextStyle(fontSize: 15, height: 1.4)),
              if (f.adminReply != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.ivory, borderRadius: BorderRadius.circular(12)),
                  child: Text('Reply: ${f.adminReply}', style: const TextStyle(color: AppColors.plum)),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// For the app maker: every boutique's ideas & requests, with status + reply.
class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  String? _status = 'new';
  late Future<List<FeedbackItem>> _future = Api.instance.allFeedback(status: _status);

  Future<void> _reload() async {
    setState(() => _future = Api.instance.allFeedback(status: _status));
    await _future;
  }

  Future<void> _answer(FeedbackItem f) async {
    final reply = TextEditingController(text: f.adminReply ?? '');
    var status = f.status == 'new' ? 'seen' : f.status;
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text('${f.boutiqueName}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              SelectableText(f.message, style: const TextStyle(height: 1.4)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _statuses.entries
                    .map((e) => ChoiceChip(
                          label: Text(e.value.$1),
                          selected: status == e.key,
                          selectedColor: AppColors.goldSoft,
                          onSelected: (_) => set(() => status = e.key),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reply,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Reply (the boutique sees it)'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      await Api.instance.answerFeedback(f.id, status, reply.text.trim());
      if (mounted) showSnack(context, 'Saved ✓');
      _reload();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = <String?, String>{null: 'All', for (final e in _statuses.entries) e.key: e.value.$1};
    return Scaffold(
      appBar: AppBar(title: const Text('All requests (admin)')),
      body: Column(children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: filters.entries
                .map((e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(e.key == 'new' ? 'New' : e.value),
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
            child: FutureBuilder<List<FeedbackItem>>(
              future: _future,
              builder: (context, snap) {
                if (snap.hasError) return ListView(children: [ErrorRetry(snap.error.toString(), onRetry: _reload)]);
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                if (snap.data!.isEmpty) {
                  return ListView(children: const [
                    EmptyState(icon: Icons.inbox_rounded, title: 'Nothing here', subtitle: 'No requests with this status.'),
                  ]);
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: snap.data!.map((f) => _FeedbackCard(f: f, admin: true, onTap: () => _answer(f))).toList(),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}
