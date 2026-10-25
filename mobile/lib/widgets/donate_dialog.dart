import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../screens/feedback_screen.dart';
import '../theme.dart';
import '../utils.dart';

/// Friendly "this app is free — donate if you like it" pop-up.
/// Shown every time the app opens or someone logs in (phone and web).
Future<void> showDonateDialog(BuildContext context) async {
  DonateInfo? info;
  try {
    info = await Api.instance.donateInfo();
  } catch (_) {} // offline: still show the thank-you, just without UPI details
  if (!context.mounted) return;
  await showDialog(context: context, builder: (_) => _DonateDialog(info: info));
}

class _DonateDialog extends StatefulWidget {
  const _DonateDialog({this.info});
  final DonateInfo? info;

  @override
  State<_DonateDialog> createState() => _DonateDialogState();
}

class _DonateDialogState extends State<_DonateDialog> {
  static const _amounts = [51, 101, 251, 501];
  int _amount = 101;
  final _custom = TextEditingController();
  bool _showQr = false;

  double get _value => double.tryParse(_custom.text.trim()) ?? _amount.toDouble();

  /// UPI deep link understood by GPay, PhonePe, Paytm, BHIM…
  String get _upiLink {
    final i = widget.info!;
    final q = {
      'pa': i.upiId!,
      'pn': i.name,
      'am': _value.toStringAsFixed(0),
      'cu': 'INR',
      'tn': 'Donation for Boutique Rentals app',
    };
    return 'upi://pay?${q.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
  }

  /// A phone (app or phone browser) can open UPI apps; a PC browser can't.
  bool get _canOpenUpiApps =>
      defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  /// Opens the phone's UPI app chooser (GPay, PhonePe, CRED, Paytm, BHIM…) with amount filled in.
  /// On a PC, or if no UPI app opens, shows the QR code to scan with a phone instead.
  Future<void> _payUpi() async {
    var opened = false;
    if (_canOpenUpiApps) {
      try {
        opened = await launchUrl(Uri.parse(_upiLink), mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    if (!opened && mounted) {
      setState(() => _showQr = true);
      showSnack(context, _canOpenUpiApps ? 'No UPI app found — scan the QR code instead' : 'Scan this QR code with your phone');
    }
  }

  Future<void> _copyUpi() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.info!.upiId!));
      if (mounted) showSnack(context, 'UPI ID copied');
    } catch (_) {
      if (mounted) showSnack(context, 'UPI ID: ${widget.info!.upiId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final hasUpi = info?.upiId != null;
    return AlertDialog(
      backgroundColor: AppColors.ivory,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(color: AppColors.goldSoft, shape: BoxShape.circle),
        child: const Icon(Icons.favorite_rounded, color: AppColors.plum, size: 30),
      ),
      title: const Text('Boutique Rentals is free for you', textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text(
            'If it helps your boutique, please consider a small donation. '
            'It encourages us to keep improving this app and to create new free products for people. 💜',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.45),
          ),
          if (hasUpi) ...[
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: _amounts
                  .map((a) => ChoiceChip(
                        label: Text(fmtMoney(a)),
                        selected: _custom.text.trim().isEmpty && _amount == a,
                        selectedColor: AppColors.goldSoft,
                        onSelected: (_) => setState(() {
                          _amount = a;
                          _custom.clear();
                        }),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _custom,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Or your own amount', prefixText: '₹ ', isDense: true),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _value >= 1 ? _payUpi : null,
              icon: const Icon(Icons.volunteer_activism_rounded),
              label: Text('Donate ${fmtMoney(_value)} via UPI'),
            ),
            const SizedBox(height: 10),
            // The UPI ID itself: tap = open GPay / PhonePe / CRED…, copy icon = copy the ID.
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.line),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _value >= 1 ? _payUpi : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                  child: Row(children: [
                    const Icon(Icons.account_balance_wallet_rounded, color: AppColors.plum),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('UPI ID  •  tap to pay', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                        Text(info!.upiId!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      ]),
                    ),
                    IconButton(
                      tooltip: 'Copy UPI ID',
                      onPressed: _copyUpi,
                      icon: const Icon(Icons.copy_rounded, size: 20, color: AppColors.plumSoft),
                    ),
                  ]),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Opens GPay, PhonePe, CRED, Paytm or any UPI app',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.muted)),
            ),
            TextButton(
              onPressed: () => setState(() => _showQr = !_showQr),
              child: Text(_showQr ? 'Hide QR code' : 'Show QR code (scan from another phone)'),
            ),
            if (_showQr) ...[
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(width: 180, height: 180, child: QrImageView(data: _upiLink)),
                ),
              ),
              const SizedBox(height: 6),
              Text('Scan with any UPI app to donate ${fmtMoney(_value)}',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ],
          if (info?.url != null)
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse(info!.url!), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Donate online'),
            ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () {
              final nav = Navigator.of(context);
              nav.pop();
              nav.push(MaterialPageRoute(builder: (_) => const FeedbackScreen()));
            },
            icon: const Icon(Icons.lightbulb_rounded, size: 18),
            label: const Text('Want a change? Tell us (any language)'),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Maybe later')),
      ],
    );
  }
}
