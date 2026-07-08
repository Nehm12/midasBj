/// Service d'authentification Keycloak OIDC côté mobile.
///
/// Implémente le flow OIDC avec PKCE (Proof Key for Code Exchange)
/// pour authentifier l'utilisateur via Keycloak.
library;
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class KeycloakConfig {
  final String baseUrl;
  final String realm;
  final String clientId;
  final String redirectUri;

  const KeycloakConfig({
    this.baseUrl = 'http://localhost:8080',
    this.realm = 'midas-benin',
    this.clientId = 'mobile-app',
    this.redirectUri = 'midasbenin://callback',
  });

  String get authUrl => '$baseUrl/realms/$realm/protocol/openid-connect/auth';
  String get tokenUrl => '$baseUrl/realms/$realm/protocol/openid-connect/token';
  String get logoutUrl => '$baseUrl/realms/$realm/protocol/openid-connect/logout';
  String get userInfoUrl => '$baseUrl/realms/$realm/protocol/openid-connect/userinfo';
}

class KeycloakService {
  final KeycloakConfig config;
  final http.Client _client = http.Client();

  KeycloakService({KeycloakConfig? config})
      : config = config ?? const KeycloakConfig();

  void dispose() => _client.close();

  /// Génère un code verifier PKCE (43-128 chars alphanum)
  String generateCodeVerifier() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(64, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Dérive le code challenge S256 à partir du verifier
  String generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Construit l'URL d'authentification OIDC
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

  /// Échange le code d'autorisation contre des tokens
  Future<Map<String, dynamic>> exchangeCodeForToken({
    required String code,
    required String codeVerifier,
  }) async {
    final res = await _client.post(
      Uri.parse(config.tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'client_id': config.clientId,
        'redirect_uri': config.redirectUri,
        'code': code,
        'code_verifier': codeVerifier,
      },
    );
    if (res.statusCode != 200) {
      throw Exception('Keycloak token exchange failed: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Rafraîchit le token d'accès
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final res = await _client.post(
      Uri.parse(config.tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'client_id': config.clientId,
        'refresh_token': refreshToken,
      },
    );
    if (res.statusCode != 200) throw Exception('Keycloak token refresh failed');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Récupère les informations utilisateur depuis Keycloak
  Future<Map<String, dynamic>> getUserInfo(String accessToken) async {
    final res = await _client.get(
      Uri.parse(config.userInfoUrl),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (res.statusCode != 200) throw Exception('Failed to get user info');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Construit l'URL de déconnexion
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
