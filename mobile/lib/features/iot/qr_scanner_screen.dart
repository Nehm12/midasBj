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
  bool _processing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _resetScanner() {
    if (!mounted) return;
    setState(() {
      _scanning = true;
      _processing = false;
    });
    _scannerController.start();
  }

  void _showManualEntry() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.edit, color: Color(0xFF8B1A1A), size: 22),
            SizedBox(width: 10),
            Text('Ajouter un appareil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'ID de l\'appareil',
            hintText: 'Ex: CAM-SURV-001, AA:BB:CC:DD:EE:FF...',
            prefixIcon: const Icon(Icons.devices, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.of(ctx).pop();
              _handleDeviceId(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.of(ctx).pop();
                _handleDeviceId(value);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeviceId(String deviceId) async {
    if (_processing) return;
    setState(() => _processing = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Enregistrement de $deviceId...'), behavior: SnackBarBehavior.floating),
    );

    try {
      final id = await ref.read(iotProvider.notifier).registerExternalDevice(deviceId: deviceId);
      if (!mounted) return;

      if (id != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Appareil $deviceId enregistre'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Echec: $deviceId existe deja ou erreur serveur'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _resetScanner();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _resetScanner();
    }
  }

  void _handleMidasQr(Map<String, dynamic> data) async {
    if (_processing) return;
    setState(() => _processing = true);

    final deviceId = data['deviceId'] as String;
    final challenge = data['challenge'] as String;
    final signature = data['signature'] as String;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Appairage securise de $deviceId...'), behavior: SnackBarBehavior.floating),
    );

    try {
      await ref.read(iotProvider.notifier).pairDeviceByQr(deviceId, signature, challenge);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appareil $deviceId apparie'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Echec de l\'appairage: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _resetScanner();
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_scanning || _processing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    _scanning = false;
    _scannerController.stop();

    final raw = barcode!.rawValue!;

    // Tentative 1: JSON MIDAS complet (deviceId + challenge + signature)
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final deviceId = data['deviceId'] as String?;
      final challenge = data['challenge'] as String?;
      final signature = data['signature'] as String?;

      if (deviceId != null && challenge != null && signature != null) {
        _handleMidasQr(data);
        return;
      }

      // JSON partiel — on peut extraire un deviceId
      if (deviceId != null) {
        _handleDeviceId(deviceId);
        return;
      }
    } catch (_) {}

    // Tentative 2: URL — extraire le dernier segment comme ID
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      try {
        final uri = Uri.parse(raw);
        final segments = uri.pathSegments;
        if (segments.isNotEmpty) {
          _handleDeviceId(segments.last);
          return;
        }
      } catch (_) {}
    }

    // Tentative 3: String brut (serie, MAC, modele, etc.)
    final cleaned = raw.trim();
    if (cleaned.isNotEmpty && cleaned.length < 128) {
      _handleDeviceId(cleaned);
      return;
    }

    // Aucun format reconnu
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contenu non reconnu (${cleaned.length} car.)\n${cleaned.length > 60 ? "${cleaned.substring(0, 60)}..." : cleaned}'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Saisir manuellement',
          onPressed: _showManualEntry,
        ),
      ),
    );
    _resetScanner();
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
            icon: const Icon(Icons.edit),
            onPressed: _showManualEntry,
            tooltip: 'Saisie manuelle',
          ),
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
              width: 280,
              height: 280,
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
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(150),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Ou appuyez sur [ ] pour saisir\nmanuellement l\'ID de l\'appareil',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_processing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text('Enregistrement...', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
