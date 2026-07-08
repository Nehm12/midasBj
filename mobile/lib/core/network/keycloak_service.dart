library;
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class KeycloakConfig {
  final String baseUrl;
  final String fallbackUrl;
  final String realm;
  final String clientId;
  final String redirectUri;

  const KeycloakConfig({
    this.baseUrl = 'http://localhost:8080',
    this.fallbackUrl = 'https://midasbj.onrender.com',
    this.realm = 'midas-benin',
    this.clientId = 'mobile-app',
    this.redirectUri = 'midasbenin://callback',
  });

  String get authUrl => '$baseUrl/realms/$realm/protocol/openid-connect/auth';
  String get tokenUrl => '$baseUrl/realms/$realm/protocol/openid-connect/token';
  String get logoutUrl => '$baseUrl/realms/$realm/protocol/openid-connect/logout';
  String get userInfoUrl => '$baseUrl/realms/$realm/protocol/openid-connect/userinfo';

  String authUrlFor(String url) => '$url/realms/$realm/protocol/openid-connect/auth';
  String tokenUrlFor(String url) => '$url/realms/$realm/protocol/openid-connect/token';
  String logoutUrlFor(String url) => '$url/realms/$realm/protocol/openid-connect/logout';
  String userInfoUrlFor(String url) => '$url/realms/$realm/protocol/openid-connect/userinfo';
}

class KeycloakService {
  final KeycloakConfig config;
  final http.Client _client = http.Client();

  KeycloakService({KeycloakConfig? config})
      : config = config ?? const KeycloakConfig();

  void dispose() => _client.close();

  String generateCodeVerifier() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(64, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  Uri buildAuthUrl({
    required String codeChallenge,
    String state = 'midas-state',
  }) {
    return Uri.parse(config.authUrl).replace(queryParameters: {
      'response_type': 'code',
      'client_id': config.clientId,
      'redirect_uri': config.redirectUri,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'scope': 'openid profile email',
      'state': state,
    });
  }

  Future<Map<String, dynamic>> exchangeCodeForToken({
    required String code,
    required String codeVerifier,
  }) async {
    final body = {
      'grant_type': 'authorization_code',
      'client_id': config.clientId,
      'redirect_uri': config.redirectUri,
      'code': code,
      'code_verifier': codeVerifier,
    };
    try {
      return await _tryKeycloakPost(config.tokenUrlFor(config.baseUrl), body);
    } catch (_) {
      return await _tryKeycloakPost(config.tokenUrlFor(config.fallbackUrl), body);
    }
  }

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final body = {
      'grant_type': 'refresh_token',
      'client_id': config.clientId,
      'refresh_token': refreshToken,
    };
    try {
      return await _tryKeycloakPost(config.tokenUrlFor(config.baseUrl), body);
    } catch (_) {
      return await _tryKeycloakPost(config.tokenUrlFor(config.fallbackUrl), body);
    }
  }

  Future<Map<String, dynamic>> getUserInfo(String accessToken) async {
    try {
      return await _tryKeycloakGet(config.userInfoUrlFor(config.baseUrl), accessToken);
    } catch (_) {
      return await _tryKeycloakGet(config.userInfoUrlFor(config.fallbackUrl), accessToken);
    }
  }

  Future<Map<String, dynamic>> _tryKeycloakPost(String url, Map<String, String> body) async {
    final res = await _client.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    );
    if (res.statusCode != 200) {
      throw Exception('Keycloak request failed: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _tryKeycloakGet(String url, String accessToken) async {
    final res = await _client.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (res.statusCode != 200) throw Exception('Failed to get user info');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Uri buildLogoutUrl({String? idTokenHint}) {
    final params = <String, String>{
      'client_id': config.clientId,
      'post_logout_redirect_uri': config.redirectUri,
    };
    if (idTokenHint != null) {
      params['id_token_hint'] = idTokenHint;
    }
    return Uri.parse(config.logoutUrl).replace(queryParameters: params);
  }
}
