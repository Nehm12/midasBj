/// Client MQTT pour la communication avec les appareils IoT.
///
/// Se connecte au broker MQTT du backend, s'abonne aux topics
/// de télémétrie et notifie l'application via un Stream broadcast.
library;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

const _kMqttHost = String.fromEnvironment(
  'MQTT_HOST',
  defaultValue: '10.0.2.2',
);

const _kMqttPort = int.fromEnvironment(
  'MQTT_PORT',
  defaultValue: 1883,
);

final mqttServiceProvider = Provider<MqttService>((ref) => MqttService());

class MqttService {
  MqttServerClient? _client;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get dataStream => _controller.stream;

  /// Se connecte au broker et s'abonne aux données IoT
  Future<void> connect(String deviceId) async {
    final host = kIsWeb ? 'localhost' : _kMqttHost;
    _client = MqttServerClient(host, 'flutter_$deviceId');
    _client!.port = _kMqttPort;
    _client!.secure = false;
    _client!.logging(on: false);

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_$deviceId')
        .startClean();
    _client!.connectionMessage = connMessage;

    try {
      await _client!.connect();
      _client!.subscribe('midas/+/telemetry', MqttQos.atLeastOnce);

      _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final rec = c[0].payload as MqttPublishMessage;
        final payload = utf8.decode(rec.payload.message);
        _controller.add(jsonDecode(payload) as Map<String, dynamic>);
      });
    } catch (e) {
      // Le log est volontairement laissé pour le débogage mobile
      // ignore: avoid_print
      print('MQTT connection failed: $e');
    }
  }

  /// Publie un message sur un topic MQTT
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
