import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../auth/auth_provider.dart';
import 'iot_provider.dart';

class IoTDeviceScreen extends ConsumerWidget {
  const IoTDeviceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iotState = ref.watch(iotProvider);
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text('Mes Appareils IoT', style: theme.textTheme.titleLarge),
            const Spacer(),
            if (iotState.devices.isNotEmpty)
              Text('${iotState.devices.length} appareil(s)', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 16),
        if (iotState.devices.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.sensors_off, size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  const Text('Aucun appareil appairé'),
                  Text('Scannez le QR code de votre ESP32', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ...iotState.devices.map((d) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              d.status == DeviceStatus.active ? Icons.sensors : Icons.sensors_off,
              color: d.status == DeviceStatus.active ? Colors.green : Colors.grey,
            ),
            title: Text(d.deviceId),
            subtitle: Text('Statut: ${d.status.name}'),
            trailing: d.status == DeviceStatus.pending
                ? FilledButton.tonal(
                    onPressed: () => ref.read(iotProvider.notifier).pairDevice(d.deviceId, auth.did ?? ''),
                    child: const Text('Appairer'),
                  )
                : Icon(Icons.check_circle, color: Colors.green),
          ),
        )),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => _showScanner(context, ref, auth.did ?? ''),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scanner un ESP32'),
        ),
      ],
    );
  }

  void _showScanner(BuildContext context, WidgetRef ref, String ownerId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _ScannerPage(ownerId: ownerId, ref: ref)),
    );
  }
}

class _ScannerPage extends StatelessWidget {
  final String ownerId;
  final WidgetRef ref;

  const _ScannerPage({required this.ownerId, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner ESP32')),
      body: MobileScanner(
        onDetect: (capture) {
          final barcode = capture.barcodes.first.rawValue;
          if (barcode != null) {
            ref.read(iotProvider.notifier).pairDevice(barcode, ownerId);
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}
