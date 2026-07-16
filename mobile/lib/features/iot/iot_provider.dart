library;
import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/network/mqtt_service.dart';

class IoTState {
  final List<Map<String, dynamic>> devices;
  final Map<String, dynamic>? selectedDevice;
  final List<Map<String, dynamic>> telemetry;
  final List<Map<String, dynamic>> alerts;
  final bool isLoading;
  final int unreadAlerts;

  const IoTState({
    this.devices = const [],
    this.selectedDevice,
    this.telemetry = const [],
    this.alerts = const [],
    this.isLoading = false,
    this.unreadAlerts = 0,
  });
}

class IoTNotifier extends StateNotifier<IoTState> {
  final ApiClient _api;
  final MqttService _mqtt;
  StreamSubscription<Map<String, dynamic>>? _mqttSub;

  IoTNotifier(this._api, this._mqtt) : super(const IoTState()) {
    _listenMqtt();
  }

  void _listenMqtt() {
    _mqttSub = _mqtt.dataStream.listen((data) {
      if (data['type'] == 'ALERT') {
        final newAlert = data['data'] as Map<String, dynamic>?;
        if (newAlert != null) {
          state = IoTState(
            devices: state.devices,
            selectedDevice: state.selectedDevice,
            telemetry: state.telemetry,
            alerts: [newAlert, ...state.alerts],
            unreadAlerts: state.unreadAlerts + 1,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _mqttSub?.cancel();
    super.dispose();
  }

  Future<void> loadDevices() async {
    state = IoTState(isLoading: true);
    try {
      final res = await _api.get('/iot/devices');
      final list = (res.data as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      state = IoTState(devices: list);
    } catch (_) {
      state = const IoTState();
    }
  }

  Future<void> loadDeviceDetail(String id) async {
    try {
      final res = await _api.get('/iot/devices/$id');
      state = IoTState(
        devices: state.devices,
        selectedDevice: res.data as Map<String, dynamic>,
      );
    } catch (_) {}
  }

  Future<void> loadTelemetry(String deviceId, {String? metric}) async {
    try {
      final params = <String, dynamic>{'limit': '50'};
      if (metric != null) params['metric'] = metric;
      final res = await _api.get('/iot/devices/$deviceId/telemetry', params: params);
      final list = (res.data as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      state = IoTState(
        devices: state.devices,
        selectedDevice: state.selectedDevice,
        telemetry: list,
      );
    } catch (_) {}
  }

  Future<void> loadAlerts({String? deviceId, bool unreadOnly = false}) async {
    try {
      final path = deviceId != null ? '/iot/devices/$deviceId/alerts' : '/iot/alerts';
      final params = unreadOnly ? <String, dynamic>{'unread': 'true'} : null;
      final res = await _api.get(path, params: params);
      final list = (res.data as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      state = IoTState(
        devices: state.devices,
        selectedDevice: state.selectedDevice,
        telemetry: state.telemetry,
        alerts: list,
        unreadAlerts: list.where((a) => a['read'] == false).length,
      );
    } catch (_) {}
  }

  Future<void> markAlertRead(String alertId) async {
    try {
      await _api.post('/iot/alerts/$alertId/read', {});
      await loadAlerts();
    } catch (_) {}
  }

  Future<void> setThreshold({
    required String deviceId,
    required String metric,
    double? minValue,
    double? maxValue,
    bool enabled = true,
  }) async {
    try {
      await _api.post('/iot/thresholds', {
        'deviceId': deviceId,
        'metric': metric,
        'minValue': minValue,
        'maxValue': maxValue,
        'enabled': enabled,
      });
      await loadDeviceDetail(deviceId);
    } catch (_) {}
  }

  Future<void> pairDevice(String deviceId, String signature, String challenge) async {
    try {
      await _api.post('/iot/pair', {
        'deviceId': deviceId,
        'signature': signature,
        'challenge': challenge,
      });
      await loadDevices();
    } catch (_) {}
  }

  Future<void> pairDeviceByQr(String deviceId, String signature, String challenge) async {
    try {
      await _api.post('/iot/pair-qr', {
        'deviceId': deviceId,
        'signature': signature,
        'challenge': challenge,
      });
      await loadDevices();
    } catch (_) {}
  }

  Future<String?> getPairingChallenge(String deviceId) async {
    try {
      final res = await _api.get('/iot/pair-challenge/$deviceId');
      final data = res.data as Map<String, dynamic>;
      return jsonEncode(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateDeviceName(String deviceId, String name) async {
    try {
      await _api.put('/iot/devices/$deviceId/name', {'name': name});
      await loadDevices();
    } catch (_) {}
  }

  Future<void> unregisterDevice(String deviceId) async {
    try {
      await _api.post('/iot/unregister', {'deviceId': deviceId});
      await loadDevices();
    } catch (_) {}
  }

  Future<String?> registerExternalDevice({
    required String deviceId,
    String? name,
  }) async {
    try {
      final res = await _api.post('/iot/register', {
        'deviceId': deviceId,
        'name': name ?? deviceId,
        'publicKey': 'external-device-no-crypto',
        'attestation': {
          'secureBoot': false,
          'flashEncryption': false,
          'tpm': false,
          'type': 'EXTERNAL',
        },
      });
      await loadDevices();
      return (res.data as Map<String, dynamic>)['id']?.toString();
    } catch (_) {
      return null;
    }
  }
}

final iotProvider = StateNotifierProvider<IoTNotifier, IoTState>((ref) {
  return IoTNotifier(ref.watch(apiClientProvider), ref.watch(mqttServiceProvider));
});
