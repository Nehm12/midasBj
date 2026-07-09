library;

const _kApiUrl = 'https://midasbj.onrender.com/api/v1';
const _kKeycloakUrl = 'https://midasbj.onrender.com';
const _kMqttHost = 'midasbj.onrender.com';

String get primaryApiUrl => _kApiUrl;
String get fallbackApiUrl => _kApiUrl;

String get primaryKeycloakUrl => _kKeycloakUrl;
String get fallbackKeycloakUrl => _kKeycloakUrl;

String get primaryMqttHost => _kMqttHost;
String get fallbackMqttHost => _kMqttHost;
