import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme.dart';

/// Opens the camera and returns the first QR / barcode value it sees.
Future<String?> scanClothTag(BuildContext context) =>
    Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const ScanScreen()));

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final value = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (value == null || value.trim().isEmpty) return;
    _done = true;
    Navigator.pop(context, value.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan cloth tag', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(onPressed: () => _controller.toggleTorch(), icon: const Icon(Icons.flashlight_on_rounded)),
        ],
      ),
      body: Stack(alignment: Alignment.center, children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (c, e) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Camera not available.\n${e.errorDetails?.message ?? e.errorCode.name}',
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
            ),
          ),
        ),
        IgnorePointer(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.gold, width: 4),
              borderRadius: BorderRadius.circular(28),
            ),
          ),
        ),
        const Positioned(
          bottom: 60,
          child: Text('Point at the QR code on the cloth tag',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
