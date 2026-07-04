import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

final mqttServiceProvider = Provider<MqttService>((ref) => MqttService());

class MqttService {
  MqttServerClient? _client;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get dataStream => _controller.stream;

  Future<void> connect(String deviceId) async {
    _client = MqttServerClient('10.0.2.2', 'flutter_$deviceId');
    _client!.port = 1883;
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
      // ignore: avoid_print
      print('MQTT connection failed: $e');
    }
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
