import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../screens/feedback_screen.dart';
import '../theme.dart';
import '../utils.dart';

/// "Ideas & requests" pop-up, shown every time the app (phone or web) opens.
/// People can type a change they want right here, in any language, and send it.
Future<void> showIdeasDialog(BuildContext context) =>
    showDialog(context: context, builder: (_) => const _IdeasDialog());

class _IdeasDialog extends StatefulWidget {
  const _IdeasDialog();

  @override
  State<_IdeasDialog> createState() => _IdeasDialogState();
}

class _IdeasDialogState extends State<_IdeasDialog> {
  final _message = TextEditingController();
  bool _busy = false;

  Future<void> _send() async {
    if (_message.text.trim().length < 3) {
      showSnack(context, 'Please write your idea first', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.instance.sendFeedback('feature', _message.text.trim(), Api.instance.user?.phone);
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, 'Thank you! We received it 🙏');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.ivory,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(color: AppColors.goldSoft, shape: BoxShape.circle),
        child: const Icon(Icons.lightbulb_rounded, color: AppColors.plum, size: 30),
      ),
      title: const Text('Ideas & requests', textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text(
            'Want something changed or a new feature? Tell us in any language '
            '(English, हिंदी, ગુજરાતી, मराठी, தமிழ்…). We read every request and upgrade the app.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _message,
            minLines: 3,
            maxLines: 6,
            maxLength: 4000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Your idea / request (any language)',
              alignLabelWithHint: true,
            ),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _send,
            icon: _busy
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded),
            label: const Text('Send'),
          ),
          TextButton.icon(
            onPressed: () {
              final nav = Navigator.of(context);
              nav.pop();
              nav.push(MaterialPageRoute(builder: (_) => const FeedbackScreen()));
            },
            icon: const Icon(Icons.history_rounded, size: 18),
            label: const Text('See my requests & replies'),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Not now')),
      ],
    );
  }
}
