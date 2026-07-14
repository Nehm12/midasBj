library;
import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'backend_config.dart';

const _kMqttHost = String.fromEnvironment(
  'MQTT_HOST',
  defaultValue: '',
);

const _kMqttPort = int.fromEnvironment(
  'MQTT_PORT',
  defaultValue: 8084,
);

final mqttServiceProvider = Provider<MqttService>((ref) => MqttService());

class MqttService {
  MqttServerClient? _client;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get dataStream => _controller.stream;

  Future<void> connect(String deviceId) async {
    final primaryHost = _kMqttHost.isNotEmpty ? _kMqttHost : primaryMqttHost;
    try {
      await _doConnect(primaryHost, deviceId);
    } catch (_) {
      try {
        await _doConnect(fallbackMqttHost, deviceId);
      } catch (_) {
        // MQTT indisponible — les alertes ne seront pas temps réel
        // L'app fonctionne quand même via HTTP polling
      }
    }
  }

  Future<void> _doConnect(String host, String deviceId) async {
    _client = MqttServerClient(host, 'flutter_$deviceId');
    _client!.port = _kMqttPort;
    _client!.secure = false;
    _client!.useWebSocket = true;
    _client!.logging(on: false);

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_$deviceId')
        .startClean();
    _client!.connectionMessage = connMessage;

    await _client!.connect();
    _client!.subscribe('midas/+/telemetry', MqttQos.atLeastOnce);

    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final rec = c[0].payload as MqttPublishMessage;
      final payload = utf8.decode(rec.payload.message);
      _controller.add(jsonDecode(payload) as Map<String, dynamic>);
    });
  }

  Future<void> publish(String topic, Map<String, dynamic> message) async {
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(message));
    _client?.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void disconnect() {
    _client?.disconnect();
    _controller.close();
  }
}
