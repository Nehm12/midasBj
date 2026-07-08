library;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'iot_provider.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});
  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _scanning = true;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_scanning) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    _scanning = false;
    _scannerController.stop();

    try {
      final raw = barcode!.rawValue!;
      Map<String, dynamic> data;
      try {
        data = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Format QR invalide. Attendu: JSON avec deviceId, challenge, signature')),
        );
        Navigator.pop(context);
        return;
      }

      final deviceId = data['deviceId'] as String?;
      final challenge = data['challenge'] as String?;
      final signature = data['signature'] as String?;

      if (deviceId == null || challenge == null || signature == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR code incomplet: deviceId, challenge et signature requis')),
        );
        Navigator.pop(context);
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Appairage de $deviceId...'), behavior: SnackBarBehavior.floating),
      );

      await ref.read(iotProvider.notifier).pairDeviceByQr(deviceId, signature, challenge);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appareil $deviceId apparie'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Echec de l\'appairage: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scanner un appareil IoT'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_scanner, color: Colors.white54, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Scannez le QR code\nde l\'appareil IoT',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
