import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

enum DeviceStatus { pending, paired, active, disabled }

class IoTDevice {
  final String deviceId;
  final String? ownerId;
  final DeviceStatus status;
  final DateTime? lastSeenAt;
  final DateTime? pairedAt;

  const IoTDevice({
    required this.deviceId,
    this.ownerId,
    required this.status,
    this.lastSeenAt,
    this.pairedAt,
  });

  factory IoTDevice.fromJson(Map<String, dynamic> json) => IoTDevice(
    deviceId: json['deviceId'] as String,
    ownerId: json['ownerId'] as String?,
    status: DeviceStatus.values.firstWhere((e) => e.name == json['status']),
    lastSeenAt: json['lastSeenAt'] != null ? DateTime.parse(json['lastSeenAt'] as String) : null,
    pairedAt: json['pairedAt'] != null ? DateTime.parse(json['pairedAt'] as String) : null,
  );
}

class IoTState {
  final List<IoTDevice> devices;
  final bool isLoading;

  const IoTState({this.devices = const [], this.isLoading = false});
}

class IoTNotifier extends StateNotifier<IoTState> {
  final ApiClient _api;

  IoTNotifier(this._api) : super(const IoTState());

  Future<void> loadDevices(String ownerId) async {
    state = IoTState(isLoading: true);
    final res = await _api.get('/iot/devices', params: {'ownerId': ownerId});
    final list = (res.data as List).map((e) => IoTDevice.fromJson(e)).toList();
    state = IoTState(devices: list);
  }

  Future<void> pairDevice(String deviceId, String ownerId) async {
    await _api.post('/iot/pair', {'deviceId': deviceId, 'ownerId': ownerId});
    await loadDevices(ownerId);
  }
}

final iotProvider = StateNotifierProvider<IoTNotifier, IoTState>((ref) {
  return IoTNotifier(ref.watch(apiClientProvider));
});
