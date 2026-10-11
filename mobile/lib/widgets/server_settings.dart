import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../utils.dart';

/// Lets the user point the app at their PC's FastAPI server.
Future<void> showServerSettings(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const _ServerSheet(),
  );
}

class _ServerSheet extends StatefulWidget {
  const _ServerSheet();

  @override
  State<_ServerSheet> createState() => _ServerSheetState();
}

class _ServerSheetState extends State<_ServerSheet> {
  final _ctrl = TextEditingController(text: Api.instance.baseUrl);
  bool _testing = false;
  bool? _ok;

  Future<void> _test() async {
    setState(() => _testing = true);
    final old = Api.instance.baseUrl;
    await Api.instance.setBaseUrl(_ctrl.text);
    final ok = await Api.instance.ping();
    if (!ok) await Api.instance.setBaseUrl(old);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _ok = ok;
    });
    if (ok) {
      showSnack(context, 'Connected and saved ✓');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(
          child: Container(
              width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4))),
        ),
        const SizedBox(height: 18),
        const Text('Server address', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text(
          'Android emulator: http://10.0.2.2:8000\n'
          'iOS simulator / browser: http://localhost:8000\n'
          'Real phone: http://<your PC Wi-Fi IP>:8000  (e.g. http://192.168.1.5:8000)',
          style: TextStyle(color: AppColors.muted, height: 1.5, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.dns_rounded),
            hintText: 'http://192.168.1.5:8000',
            errorText: _ok == false ? 'Could not connect. Is the server running?' : null,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _testing ? null : _test,
          icon: _testing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.wifi_tethering_rounded),
          label: const Text('Test & Save'),
        ),
      ]),
    );
  }
}
