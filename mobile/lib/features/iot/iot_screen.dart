library;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'iot_provider.dart';
import 'qr_scanner_screen.dart';

class IoTDeviceScreen extends ConsumerStatefulWidget {
  const IoTDeviceScreen({super.key});
  @override
  ConsumerState<IoTDeviceScreen> createState() => _IoTDeviceScreenState();
}

class _IoTDeviceScreenState extends ConsumerState<IoTDeviceScreen> {
  String? _selectedMetric;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _timeAgo(String? timestamp) {
    if (timestamp == null) return '—';
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'À l\'instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
      return 'Il y a ${diff.inDays}j';
    } catch (_) {
      return timestamp;
    }
  }

  Color _statusColor(String status) => switch (status) {
    'ACTIVE' || 'PAIRED' => Colors.green,
    'PENDING' => Colors.orange,
    'DISABLED' => Colors.grey,
    _ => Colors.grey,
  };

  IconData _metricIcon(String? metric) => switch (metric) {
    'temperature' => Icons.thermostat,
    'humidity' => Icons.water_drop,
    'pressure' => Icons.air,
    _ => Icons.sensors,
  };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(iotProvider);
    final theme = Theme.of(context);

    if (state.selectedDevice != null) return _buildDeviceDetail(state, theme);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('IoT Bridge'),
        actions: [
          if (state.unreadAlerts > 0)
            IconButton(
              icon: Badge(
                label: Text('${state.unreadAlerts}'),
                child: const Icon(Icons.notifications_active),
              ),
              onPressed: () => ref.read(iotProvider.notifier).loadAlerts(unreadOnly: true),
            ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _showAlertsDialog(context, state),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(iotProvider.notifier).loadDevices(),
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.devices.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.devices.length,
                    itemBuilder: (ctx, i) => _DeviceCard(
                      device: state.devices[i],
                      theme: theme,
                      onTap: () {
                        final id = state.devices[i]['id'] as String;
                        ref.read(iotProvider.notifier).loadDeviceDetail(id);
                      },
                    ),
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _scanQrCode(context),
        backgroundColor: const Color(0xFF8B1A1A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Scanner QR'),
      ),
    );
  }

  Widget _buildDeviceDetail(IoTState state, ThemeData theme) {
    final device = state.selectedDevice!;
    final deviceId = device['id'] as String? ?? '';
    final name = device['name'] as String? ?? 'Appareil IoT';
    final status = device['status'] as String? ?? 'PENDING';
    final lastSeen = device['lastSeenAt'] as String?;
    final dataCount = device['_count'] is Map ? (device['_count'] as Map)['data'] : 0;
    final thresholds = device['thresholds'] as List? ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editName(context, deviceId, name),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => ref.read(iotProvider.notifier).loadDevices(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.sensors, color: _statusColor(status), size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(device['deviceId'] as String? ?? '', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey)),
                      ],
                    )),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(status, style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    _StatChip(icon: Icons.access_time, label: 'Dernière activité', value: _timeAgo(lastSeen)),
                    const SizedBox(width: 8),
                    _StatChip(icon: Icons.storage, label: 'Données', value: '$dataCount'),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Text('Télémétrie', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            DropdownButton<String?>(
              value: _selectedMetric,
              hint: const Text('Tout', style: TextStyle(fontSize: 12)),
              items: const [
                DropdownMenuItem(value: null, child: Text('Tout', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'temperature', child: Text('Température', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'humidity', child: Text('Humidité', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'pressure', child: Text('Pression', style: TextStyle(fontSize: 12))),
              ],
              onChanged: (m) {
                setState(() => _selectedMetric = m);
                ref.read(iotProvider.notifier).loadTelemetry(deviceId, metric: m);
              },
            ),
          ]),
          const SizedBox(height: 8),
          _buildTelemetryChart(state, theme),
          const SizedBox(height: 16),
          Text('Seuils', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...thresholds.isEmpty
            ? [const Text('Aucun seuil configuré', style: TextStyle(color: Colors.grey, fontSize: 13))]
            : thresholds.map<Widget>((t) => Card(
                color: Colors.white,
                child: ListTile(
                  leading: Icon(_metricIcon(t['metric'] as String?), size: 20),
                  title: Text(t['metric'] as String? ?? '', style: const TextStyle(fontSize: 13)),
                  subtitle: Text('Min: ${t['minValue'] ?? '-'}  Max: ${t['maxValue'] ?? '-'}', style: const TextStyle(fontSize: 11)),
                  trailing: Icon(t['enabled'] == true ? Icons.check_circle : Icons.cancel, color: t['enabled'] == true ? Colors.green : Colors.grey, size: 18),
                ),
              )),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Configurer un seuil'),
            onPressed: () => _showThresholdDialog(context, deviceId),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('Désenregistrer l\'appareil', style: TextStyle(color: Colors.red)),
            onPressed: () => ref.read(iotProvider.notifier).unregisterDevice(deviceId),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryChart(IoTState state, ThemeData theme) {
    if (state.telemetry.isEmpty) {
      return Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.show_chart, color: Colors.grey[300], size: 32),
              const SizedBox(width: 12),
              const Text('En attente de données...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final data = state.telemetry.take(30).toList().reversed.toList();
    if (data.isEmpty) return const SizedBox.shrink();

    final values = data.map((t) => (t['metricValue'] as num?)?.toDouble() ?? 0).toList();
    final minVal = values.reduce(min);
    final maxVal = values.reduce(max);
    final range = (maxVal - minVal).clamp(0.1, double.infinity);

    final metric = data.first['metricName'] as String? ?? '';
    final unit = data.first['unit'] as String? ?? '';

    final spots = data.asMap().entries.map((e) =>
      FlSpot(e.key.toDouble(), (e.value['metricValue'] as num? ?? 0).toDouble())
    ).toList();

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_metricIcon(metric), size: 16, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text('$metric ($unit)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${minVal.toStringAsFixed(1)} – ${maxVal.toStringAsFixed(1)} $unit',
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: range / 4,
                    getDrawingHorizontalLine: (val) => FlLine(
                      color: Colors.grey.withAlpha(30),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        getTitlesWidget: (val, meta) => Text(
                          val.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: max(1, (data.length / 5).floor()).toDouble(),
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx < 0 || idx >= data.length) return const SizedBox.shrink();
                          final time = _timeAgo(data[idx]['receivedAt'] as String?);
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(time, style: const TextStyle(fontSize: 8, color: Colors.grey)),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (data.length - 1).toDouble(),
                  minY: minVal - range * 0.1,
                  maxY: maxVal + range * 0.1,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: const Color(0xFF8B1A1A),
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: data.length < 20,
                        getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                            radius: 3,
                            color: const Color(0xFF8B1A1A),
                            strokeWidth: 1,
                            strokeColor: Colors.white,
                          ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF8B1A1A).withAlpha(20),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                        final idx = s.x.toInt();
                        final time = idx < data.length ? data[idx]['receivedAt'] as String? : '';
                        return LineTooltipItem(
                          '${s.y.toStringAsFixed(1)} $unit\n$time',
                          const TextStyle(color: Colors.white, fontSize: 10),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...data.take(5).map((t) {
              final metricName = t['metricName'] as String? ?? '—';
              final value = t['metricValue'] as num? ?? 0;
              final unitName = t['unit'] as String? ?? '';
              final time = _timeAgo(t['receivedAt'] as String?);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Icon(_metricIcon(metricName), size: 14, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Text(metricName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text('$value $unitName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text(time, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _editName(BuildContext context, String deviceId, String currentName) {
    _nameController.text = currentName;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer'),
        content: TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nom')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () {
            ref.read(iotProvider.notifier).updateDeviceName(deviceId, _nameController.text);
            Navigator.pop(ctx);
          }, child: const Text('OK')),
        ],
      ),
    );
  }

  void _showThresholdDialog(BuildContext context, String deviceId) {
    final metricCtrl = TextEditingController();
    final minCtrl = TextEditingController();
    final maxCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau seuil'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Métrique', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'temperature', child: Text('Température')),
              DropdownMenuItem(value: 'humidity', child: Text('Humidité')),
              DropdownMenuItem(value: 'pressure', child: Text('Pression')),
            ],
            onChanged: (v) => metricCtrl.text = v ?? '',
          ),
          const SizedBox(height: 12),
          TextField(controller: minCtrl, decoration: const InputDecoration(labelText: 'Min', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          TextField(controller: maxCtrl, decoration: const InputDecoration(labelText: 'Max', border: OutlineInputBorder()), keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () {
            ref.read(iotProvider.notifier).setThreshold(
              deviceId: deviceId,
              metric: metricCtrl.text,
              minValue: double.tryParse(minCtrl.text),
              maxValue: double.tryParse(maxCtrl.text),
            );
            Navigator.pop(ctx);
          }, child: const Text('Ajouter')),
        ],
      ),
    );
  }

  void _showAlertsDialog(BuildContext context, IoTState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alertes'),
        content: SizedBox(
          width: double.maxFinite,
          child: state.alerts.isEmpty
            ? const Text('Aucune alerte')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: state.alerts.length,
                itemBuilder: (_, i) {
                  final a = state.alerts[i];
                  return ListTile(
                    leading: Icon(
                      a['severity'] == 'WARNING' ? Icons.warning_amber : Icons.info_outline,
                      color: a['severity'] == 'WARNING' ? Colors.orange : Colors.blue,
                      size: 20,
                    ),
                    title: Text(a['message'] as String? ?? '', style: const TextStyle(fontSize: 12)),
                    subtitle: Text(a['createdAt'] as String? ?? '', style: const TextStyle(fontSize: 10)),
                    trailing: a['read'] == true ? null : IconButton(
                      icon: const Icon(Icons.check, size: 18),
                      onPressed: () => ref.read(iotProvider.notifier).markAlertRead(a['id'] as String),
                    ),
                    dense: true,
                  );
                },
              ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 64),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sensors_off_outlined, size: 64, color: const Color(0xFFB0B0B0)),
            const SizedBox(height: 16),
            Text('Aucun appareil IoT', style: theme.textTheme.titleMedium?.copyWith(color: const Color(0xFF1A1A1A).withAlpha(153))),
            const SizedBox(height: 8),
            Text('Scannez un QR code pour ajouter\nun appareil connecté', textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF1A1A1A).withAlpha(128))),
          ],
        ),
      ),
    );
  }

  void _scanQrCode(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final Map<String, dynamic> device;
  final ThemeData theme;
  final VoidCallback onTap;

  const _DeviceCard({required this.device, required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = device['name'] as String? ?? 'Appareil IoT';
    final deviceId = device['deviceId'] as String? ?? '';
    final status = device['status'] as String? ?? 'PENDING';
    final lastSeen = device['lastSeenAt'] as String?;
    final count = device['_count'] is Map ? (device['_count'] as Map)['data'] : 0;

    final isOnline = status == 'PAIRED' || status == 'ACTIVE';
    final statusColor = isOnline ? Colors.green : status == 'PENDING' ? Colors.orange : Colors.grey;

    String timeAgo(String? ts) {
      if (ts == null) return '—';
      try {
        final dt = DateTime.parse(ts);
        final diff = DateTime.now().difference(dt);
        if (diff.inSeconds < 60) return 'À l\'instant';
        if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
        if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
        return 'Il y a ${diff.inDays}j';
      } catch (_) { return ts; }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: statusColor.withAlpha(25), borderRadius: BorderRadius.circular(12)),
                child: Icon(isOnline ? Icons.sensors_rounded : Icons.sensors_off_outlined, color: statusColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(deviceId, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(isOnline ? 'En ligne' : 'Hors ligne', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 12),
                    Text('$count données', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    const Spacer(),
                    Icon(Icons.access_time, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(timeAgo(lastSeen), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ]),
                ],
              )),
              const Icon(Icons.chevron_right, color: Color(0xFFB0B0B0), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}
