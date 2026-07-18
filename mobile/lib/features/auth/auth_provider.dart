/// Gestion d'état de l'authentification.
library;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:local_auth/local_auth.dart';
import '../../core/crypto/crypto_service.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/storage_service.dart';
import '../../core/network/keycloak_service.dart';

enum AuthStatus { unauthenticated, authenticating, authenticated }
enum AuthMode { npi, keycloak, biometric, simple }

class AuthState {
  final AuthStatus status;
  final AuthMode mode;
  final String? did;
  final String? npi;
  final String? userId;
  final String? publicKey;
  final String? firstName;
  final String? lastName;
  final List<String> roles;
  final bool biometricEnabled;
  final bool biometricAvailable;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.mode = AuthMode.npi,
    this.did,
    this.npi,
    this.userId,
    this.publicKey,
    this.firstName,
    this.lastName,
    this.roles = const [],
    this.biometricEnabled = false,
    this.biometricAvailable = false,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    AuthMode? mode,
    String? did,
    String? npi,
    String? userId,
    String? publicKey,
    String? firstName,
    String? lastName,
    List<String>? roles,
    bool? biometricEnabled,
    bool? biometricAvailable,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      mode: mode ?? this.mode,
      did: did ?? this.did,
      npi: npi ?? this.npi,
      userId: userId ?? this.userId,
      publicKey: publicKey ?? this.publicKey,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      roles: roles ?? this.roles,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      biometricAvailable: biometricAvailable ?? this.biometricAvailable,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;
  final CryptoService _crypto;
  final StorageService _storage;
  final KeycloakService _keycloak;
  final LocalAuthentication _localAuth;

  AuthNotifier(this._api, this._crypto, this._storage, this._keycloak, this._localAuth)
      : super(const AuthState()) {
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final available = await _localAuth.canCheckBiometrics;
      final enrolled = await _localAuth.isDeviceSupported();
      final hasToken = await _storage.readSecure('auth_token') != null;
      state = state.copyWith(
        biometricAvailable: available && enrolled && hasToken,
        biometricEnabled: await _storage.readSecure('biometric_enabled') == 'true',
      );
    } catch (_) {}
  }

  Future<bool> authenticateBiometric({
    String reason = 'Déverrouiller MIDAS',
  }) async {
    if (!state.biometricAvailable) return false;
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (authenticated) {
        state = state.copyWith(biometricEnabled: true, mode: AuthMode.biometric);
        await _storage.saveSecure('biometric_enabled', 'true');
      }
      return authenticated;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveToken(String token) async {
    await _storage.saveSecure('auth_token', token);
  }

  Future<void> _saveSession({
    required String token,
    required String? did,
    required String? npi,
    required String? userId,
    String? publicKey,
    String? firstName,
    String? lastName,
    List<String> roles = const ['citizen'],
  }) async {
    await _saveToken(token);
    if (did != null) await _storage.saveSecure('session_did', did);
    if (npi != null) await _storage.saveSecure('session_npi', npi);
    if (userId != null) await _storage.saveSecure('session_userId', userId);
    if (publicKey != null) await _storage.saveSecure('session_publicKey', publicKey);
    if (firstName != null) await _storage.saveSecure('session_firstName', firstName);
    if (lastName != null) await _storage.saveSecure('session_lastName', lastName);
    await _storage.saveSecure('session_roles', roles.join(','));
  }

  Future<void> register(String npi) async {
    state = state.copyWith(status: AuthStatus.authenticating, mode: AuthMode.npi, error: null);
    try {
      final keyPair = await _crypto.generateEd25519KeyPair();
      final publicKey = await keyPair.extractPublicKey();
      final pubKeyHex = base64Encode(publicKey.bytes);
      final privKeyBytes = await keyPair.extractPrivateKeyBytes();
      final privKeyHex = base64Encode(privKeyBytes);

      final res = await _api.post('/auth/register', {'npi': npi, 'publicKey': pubKeyHex});
      final did = res.data['did'] as String;
      final userId = res.data['id'] as String;
      final token = res.data['token'] as String?;
      final firstName = res.data['firstName'] as String?;
      final lastName = res.data['lastName'] as String?;

      await _storage.saveKeyPair(npi, privKeyHex, pubKeyHex);
      await _storage.saveSecure('did_$npi', did);
      await _storage.saveSecure('userId_$npi', userId);
      if (token != null) {
        await _saveSession(
          token: token,
          did: did,
          npi: npi,
          userId: userId,
          publicKey: pubKeyHex,
          firstName: firstName,
          lastName: lastName,
        );
      }

      state = AuthState(
        status: AuthStatus.authenticated,
        mode: AuthMode.npi,
        did: did,
        npi: npi,
        userId: userId,
        publicKey: pubKeyHex,
        firstName: firstName,
        lastName: lastName,
        roles: ['citizen'],
      );
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data as Map)['error']?.toString()
          : null;
      if (e.response?.statusCode == 409) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: msg ?? 'Ce NPI est déjà enregistré. Connectez-vous plutôt.',
        );
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated, error: msg ?? e.message);
      }
    } catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: e.toString());
    }
  }

  Future<void> login(String npi) async {
    state = state.copyWith(status: AuthStatus.authenticating, mode: AuthMode.npi, error: null);
    try {
      final privKeyHex = await _storage.readSecure('kp_${npi}_priv');
      final pubKeyHex = await _storage.readSecure('kp_${npi}_pub');
      final did = await _storage.readSecure('did_$npi');
      final userId = await _storage.readSecure('userId_$npi');

      if (privKeyHex == null || pubKeyHex == null) {
        throw Exception('Identité non trouvée. Enrôlez-vous d\'abord.');
      }

      final privKeyBytes = base64Decode(privKeyHex);
      final keyPair = await _crypto.ed25519.newKeyPairFromSeed(privKeyBytes);
      final message = utf8.encode(npi);
      final signature = await _crypto.signEd25519(keyPair, message);
      final sigHex = base64Encode(signature);

      final res = await _api.post('/auth/login', {'npi': npi, 'signature': sigHex});
      final data = res.data as Map<String, dynamic>;
      final token = data['token'] as String?;
      final userIdFromResponse = data['id'] as String? ?? data['sub'] as String?;
      final firstName = data['firstName'] as String?;
      final lastName = data['lastName'] as String?;

      if (token != null) {
        await _saveSession(
          token: token,
          did: did ?? data['did'] as String?,
          npi: npi,
          userId: userId ?? userIdFromResponse,
          publicKey: pubKeyHex,
          firstName: firstName,
          lastName: lastName,
        );
      }
      if (userIdFromResponse != null) {
        await _storage.saveSecure('userId_$npi', userIdFromResponse);
      }

      state = AuthState(
        status: AuthStatus.authenticated,
        mode: AuthMode.npi,
        did: did ?? data['did'] as String?,
        npi: npi,
        userId: userId ?? userIdFromResponse,
        publicKey: pubKeyHex,
        firstName: firstName,
        lastName: lastName,
        roles: ['citizen'],
      );
    } catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: e.toString());
    }
  }

  Future<void> loginSimple(String npi) async {
    state = state.copyWith(status: AuthStatus.authenticating, mode: AuthMode.simple, error: null);
    try {
      final res = await _api.post('/auth/login-simple', {'npi': npi});
      final data = res.data as Map<String, dynamic>;
      final did = data['did'] as String;
      final userId = data['id'] as String? ?? data['sub'] as String? ?? '';
      final token = data['token'] as String?;
      final firstName = data['firstName'] as String?;
      final lastName = data['lastName'] as String?;

      await _storage.saveSecure('did_$npi', did);
      await _storage.saveSecure('userId_$npi', userId);
      if (token != null) {
        await _saveSession(
          token: token,
          did: did,
          npi: npi,
          userId: userId,
          firstName: firstName,
          lastName: lastName,
        );
      }

      state = AuthState(
        status: AuthStatus.authenticated,
        mode: AuthMode.simple,
        did: did,
        npi: npi,
        userId: userId,
        firstName: firstName,
        lastName: lastName,
        roles: ['citizen'],
      );
    } catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: e.toString());
    }
  }

  Future<void> loginWithKeycloak(String accessToken) async {
    state = state.copyWith(status: AuthStatus.authenticating, mode: AuthMode.keycloak, error: null);
    try {
      final userInfo = await _keycloak.getUserInfo(accessToken);
      final npi = userInfo['preferred_username'] as String? ?? userInfo['sub'] as String;
      await _storage.saveSecure('keycloak_token', accessToken);

      final res = await _api.post('/auth/keycloak', {'token': accessToken});
      final data = res.data as Map<String, dynamic>;
      final token = data['token'] as String?;
      final did = data['did'] as String?;
      final userId = data['id'] as String?;
      final roles = (data['roles'] as List?)?.cast<String>() ?? ['citizen'];
      final firstName = data['firstName'] as String?;
      final lastName = data['lastName'] as String?;

      if (token != null) {
        await _saveSession(
          token: token,
          did: did,
          npi: data['npi'] as String? ?? npi,
          userId: userId,
          roles: roles,
          firstName: firstName,
          lastName: lastName,
        );
      }

      state = AuthState(
        status: AuthStatus.authenticated,
        mode: AuthMode.keycloak,
        did: did,
        npi: data['npi'] as String? ?? npi,
        userId: userId,
        firstName: firstName,
        lastName: lastName,
        roles: roles,
      );
    } catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: e.toString());
    }
  }

  Future<void> toggleBiometric() async {
    if (state.biometricEnabled) {
      await _storage.deleteSecure('biometric_enabled');
      state = state.copyWith(biometricEnabled: false);
    } else {
      final ok = await authenticateBiometric();
      if (!ok) throw Exception('Échec de l\'authentification biométrique');
    }
  }

  Future<bool> loginWithBiometric() async {
    state = state.copyWith(status: AuthStatus.authenticating, mode: AuthMode.biometric, error: null);
    try {
      final token = await _storage.readSecure('auth_token');
      if (token == null) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: 'Aucune session enregistrée. Connectez-vous d\'abord.',
        );
        return false;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Déverrouiller MIDAS',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (!authenticated) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return false;
      }

      final did = await _storage.readSecure('session_did');
      final npi = await _storage.readSecure('session_npi');
      final userId = await _storage.readSecure('session_userId');
      final pubKey = await _storage.readSecure('session_publicKey');
      final rolesStr = await _storage.readSecure('session_roles');
      final roles = rolesStr?.split(',') ?? ['citizen'];
      final firstName = await _storage.readSecure('session_firstName');
      final lastName = await _storage.readSecure('session_lastName');

      state = AuthState(
        status: AuthStatus.authenticated,
        mode: AuthMode.biometric,
        did: did,
        npi: npi,
        userId: userId,
        publicKey: pubKey,
        firstName: firstName,
        lastName: lastName,
        roles: roles,
        biometricAvailable: true,
        biometricEnabled: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: e.toString());
      return false;
    }
  }

  void logout() {
    _storage.deleteSecure('auth_token');
    _storage.deleteSecure('keycloak_token');
    _storage.deleteSecure('session_did');
    _storage.deleteSecure('session_npi');
    _storage.deleteSecure('session_userId');
    _storage.deleteSecure('session_publicKey');
    _storage.deleteSecure('session_firstName');
    _storage.deleteSecure('session_lastName');
    _storage.deleteSecure('session_roles');
    state = const AuthState();
  }

  Future<void> updateProfile({String? firstName, String? lastName}) async {
    try {
      final res = await _api.put('/auth/profile', {
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
      });
      final data = res.data as Map<String, dynamic>;
      final newFirstName = data['firstName'] as String?;
      final newLastName = data['lastName'] as String?;

      if (newFirstName != null) await _storage.saveSecure('session_firstName', newFirstName);
      if (newLastName != null) await _storage.saveSecure('session_lastName', newLastName);

      state = state.copyWith(firstName: newFirstName, lastName: newLastName);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(apiClientProvider),
    CryptoService(),
    StorageService(),
    KeycloakService(),
    LocalAuthentication(),
  );
});
