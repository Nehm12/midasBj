/**
 * Gestion d'état des appareils IoT.
 *
 * IoTState stocke la liste des appareils connectés et le statut
 * de chargement.
 *
 * IoTNotifier :
 *   loadDevices() → récupère les appareils depuis l'API
 *   addDevice()   → associe un nouvel appareil (via QR code)
 */
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

class IoTState {
  final List<Map<String, dynamic>> devices;
  final bool isLoading;

  const IoTState({this.devices = const [], this.isLoading = false});
}

class IoTNotifier extends StateNotifier<IoTState> {
  final ApiClient _api;

  IoTNotifier(this._api) : super(const IoTState());

  Future<void> loadDevices() async {
    state = IoTState(isLoading: true);
    try {
      final res = await _api.get('/iot/devices');
      final list = (res.data['devices'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      state = IoTState(devices: list);
    } catch (e) {
      state = const IoTState();
    }
  }

  Future<void> addDevice(Map<String, dynamic> deviceData) async {
    try {
      await _api.post('/iot/devices', deviceData);
      await loadDevices();
    } catch (_) {}
  }
}

final iotProvider = StateNotifierProvider<IoTNotifier, IoTState>((ref) {
  return IoTNotifier(ref.watch(apiClientProvider));
});
