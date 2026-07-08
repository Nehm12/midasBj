library;
import 'package:flutter/foundation.dart';

const _kLocalApiUrl = 'http://10.0.2.2:3000/api/v1';
const _kWebApiUrl = 'http://localhost:3000/api/v1';
const _kRemoteApiUrl = 'https://midasbj.onrender.com/api/v1';

const _kLocalKeycloakUrl = 'http://localhost:8080';
const _kRemoteKeycloakUrl = 'https://midasbj.onrender.com';

const _kLocalMqttHost = '10.0.2.2';
const _kRemoteMqttHost = 'midasbj.onrender.com';

String get primaryApiUrl => kIsWeb ? _kWebApiUrl : _kLocalApiUrl;
String get fallbackApiUrl => _kRemoteApiUrl;

String get primaryKeycloakUrl => _kLocalKeycloakUrl;
String get fallbackKeycloakUrl => _kRemoteKeycloakUrl;

String get primaryMqttHost => kIsWeb ? 'localhost' : _kLocalMqttHost;
String get fallbackMqttHost => _kRemoteMqttHost;
