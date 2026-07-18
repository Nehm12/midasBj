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
  final String? error;

  const IoTState({
    this.devices = const [],
    this.selectedDevice,
    this.telemetry = const [],
    this.alerts = const [],
    this.isLoading = false,
    this.unreadAlerts = 0,
    this.error,
  });

  IoTState copyWith({
    List<Map<String, dynamic>>? devices,
    Map<String, dynamic>? selectedDevice,
    bool clearSelectedDevice = false,
    List<Map<String, dynamic>>? telemetry,
    List<Map<String, dynamic>>? alerts,
    bool? isLoading,
    int? unreadAlerts,
    String? error,
    bool clearError = false,
  }) {
    return IoTState(
      devices: devices ?? this.devices,
      selectedDevice: clearSelectedDevice ? null : (selectedDevice ?? this.selectedDevice),
      telemetry: telemetry ?? this.telemetry,
      alerts: alerts ?? this.alerts,
      isLoading: isLoading ?? this.isLoading,
      unreadAlerts: unreadAlerts ?? this.unreadAlerts,
      error: clearError ? null : (error ?? this.error),
    );
  }
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
          state = state.copyWith(
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
    state = state.copyWith(isLoading: true, clearError: true, clearSelectedDevice: true);
    try {
      final res = await _api.get('/iot/devices');
      final list = (res.data as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      state = state.copyWith(devices: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erreur de chargement: $e');
    }
  }

  Future<void> loadDeviceDetail(String id) async {
    try {
      final res = await _api.get('/iot/devices/$id');
      state = state.copyWith(selectedDevice: res.data as Map<String, dynamic>);
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
  }

  Future<void> loadTelemetry(String deviceId, {String? metric}) async {
    try {
      final params = <String, dynamic>{'limit': '50'};
      if (metric != null) params['metric'] = metric;
      final res = await _api.get('/iot/devices/$deviceId/telemetry', params: params);
      final list = (res.data as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      state = state.copyWith(telemetry: list);
    } catch (e) {
      state = state.copyWith(error: 'Erreur télémétrie: $e');
    }
  }

  Future<void> loadAlerts({String? deviceId, bool unreadOnly = false}) async {
    try {
      final path = deviceId != null ? '/iot/devices/$deviceId/alerts' : '/iot/alerts';
      final params = unreadOnly ? <String, dynamic>{'unread': 'true'} : null;
      final res = await _api.get(path, params: params);
      final list = (res.data as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      state = state.copyWith(
        alerts: list,
        unreadAlerts: list.where((a) => a['read'] == false).length,
      );
    } catch (e) {
      state = state.copyWith(error: 'Erreur alertes: $e');
    }
  }

  Future<void> markAlertRead(String alertId) async {
    try {
      await _api.post('/iot/alerts/$alertId/read', {});
      await loadAlerts();
    } catch (e) {
      state = state.copyWith(error: 'Erreur: $e');
    }
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
    } catch (e) {
      state = state.copyWith(error: 'Erreur seuil: $e');
    }
  }

  Future<void> pairDevice(String deviceId, String signature, String challenge) async {
    try {
      await _api.post('/iot/pair', {
        'deviceId': deviceId,
        'signature': signature,
        'challenge': challenge,
      });
      await loadDevices();
    } catch (e) {
      state = state.copyWith(error: 'Erreur jumelage: $e');
    }
  }

  Future<void> pairDeviceByQr(String deviceId, String signature, String challenge) async {
    try {
      await _api.post('/iot/pair-qr', {
        'deviceId': deviceId,
        'signature': signature,
        'challenge': challenge,
      });
      await loadDevices();
    } catch (e) {
      state = state.copyWith(error: 'Erreur jumelage QR: $e');
    }
  }

  Future<String?> getPairingChallenge(String deviceId) async {
    try {
      final res = await _api.get('/iot/pair-challenge/$deviceId');
      final data = res.data as Map<String, dynamic>;
      return jsonEncode(data);
    } catch (e) {
      state = state.copyWith(error: 'Erreur défi: $e');
      return null;
    }
  }

  Future<void> updateDeviceName(String deviceId, String name) async {
    try {
      await _api.put('/iot/devices/$deviceId/name', {'name': name});
      await loadDevices();
    } catch (e) {
      state = state.copyWith(error: 'Erreur renommage: $e');
    }
  }

  Future<void> unregisterDevice(String deviceId) async {
    try {
      await _api.post('/iot/unregister', {'deviceId': deviceId});
      await loadDevices();
    } catch (e) {
      state = state.copyWith(error: 'Erreur désenregistrement: $e');
    }
  }

  Future<void> registerExternalDevice({
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
    } catch (e) {
      state = state.copyWith(error: 'Erreur d\'enregistrement: $e');
      return null;
    }
  }
}

final iotProvider = StateNotifierProvider<IoTNotifier, IoTState>((ref) {
  return IoTNotifier(ref.watch(apiClientProvider), ref.watch(mqttServiceProvider));
});
