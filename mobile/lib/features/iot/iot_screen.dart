/**
 * Écran de gestion des appareils IoT.
 *
 * Affiche la liste des appareils connectés avec :
 * - Le nom, l'ID et le type d'appareil
 * - L'état (online/offline) avec indicateur coloré
 * - Le timestamp de la dernière activité
 *
 * Permet aussi de scanner un QR code pour associer un nouvel appareil.
 * Utilise pull-to-refresh pour actualiser la liste.
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'iot_provider.dart';

class IoTDeviceScreen extends ConsumerWidget {
  const IoTDeviceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(iotProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appareils IoT'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(iotProvider.notifier).loadDevices(),
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.devices.isEmpty
                ? _buildEmptyState(theme, colorScheme)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.devices.length,
                    itemBuilder: (ctx, i) => _DeviceCard(
                      device: state.devices[i],
                      theme: theme,
                      colorScheme: colorScheme,
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _scanQrCode(context, ref),
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Scanner QR'),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sensors_off_outlined, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'Aucun appareil IoT',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scannez un QR code pour ajouter\nun appareil connecté',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  void _scanQrCode(BuildContext context, WidgetRef ref) {
    // Placeholder : intégrer un package QR scanner
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scanner non implémenté'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final Map<String, dynamic> device;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _DeviceCard({
    required this.device,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final name = device['name'] as String? ?? 'Appareil inconnu';
    final id = device['id'] as String? ?? '';
    final type = device['type'] as String? ?? 'Generic';
    final isOnline = device['isOnline'] as bool? ?? false;
    final lastSeen = device['lastSeen'] as String? ?? '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isOnline
                    ? Colors.green.withValues(alpha: 0.1)
                    : colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isOnline
                    ? Icons.sensors_rounded
                    : Icons.sensors_off_outlined,
                color: isOnline ? Colors.green : colorScheme.outline,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$type • $id',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOnline ? 'En ligne' : 'Hors ligne',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOnline ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.access_time, size: 12, color: colorScheme.outline),
                      const SizedBox(width: 4),
                      Text(
                        _timeAgo(lastSeen),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colorScheme.outline),
          ],
        ),
      ),
    );
  }

  /** Affiche "il y a X minutes" */
  String _timeAgo(String timestamp) {
    if (timestamp == '—') return timestamp;
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'À l\'instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
      return 'Il y a ${diff.inDays}j';
    } catch (_) {
      return timestamp;
    }
  }
}
