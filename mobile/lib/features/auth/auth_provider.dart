/**
 * Gestion d'état de l'authentification.
 *
 * AuthState stocke le statut (non connecté, en cours, connecté),
 * le DID, le NPI, l'ID utilisateur, la clé publique et les erreurs.
 *
 * AuthNotifier gère :
 *   register(npi) → génère une paire de clés Ed25519, envoie la clé
 *                    publique au serveur, stocke la clé privée localement
 *   login(npi)    → signe le NPI avec la clé privée, envoie la signature
 *                    au serveur pour vérification, reçoit un JWT
 *   logout()      → réinitialise l'état
 *
 * La clé privée ne quitte JAMAIS le téléphone (stockage sécurisé).
 */
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../../core/crypto/crypto_service.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/storage_service.dart';

enum AuthStatus { unauthenticated, authenticating, authenticated }

class AuthState {
  final AuthStatus status;
  final String? did;
  final String? npi;
  final String? userId;
  final String? publicKey;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.did,
    this.npi,
    this.userId,
    this.publicKey,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? did,
    String? npi,
    String? userId,
    String? publicKey,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      did: did ?? this.did,
      npi: npi ?? this.npi,
      userId: userId ?? this.userId,
      publicKey: publicKey ?? this.publicKey,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;
  final CryptoService _crypto;
  final StorageService _storage;

  AuthNotifier(this._api, this._crypto, this._storage)
      : super(const AuthState());

  /** Enrôlement : crée un compte avec NPI + clé publique Ed25519 */
  Future<void> register(String npi) async {
    state = state.copyWith(status: AuthStatus.authenticating, error: null);
    try {
      final keyPair = await _crypto.generateEd25519KeyPair();
      final publicKey = await keyPair.extractPublicKey();
      final pubKeyHex = base64Encode(publicKey.bytes);
      final privKeyBytes = await keyPair.extractPrivateKeyBytes();
      final privKeyHex = base64Encode(privKeyBytes);

      final res = await _api.post('/auth/register', {
        'npi': npi,
        'publicKey': pubKeyHex,
      });
      final did = res.data['did'] as String;
      final userId = res.data['id'] as String;

      // Sauvegarde sécurisée des clés
      await _storage.saveKeyPair(npi, privKeyHex, pubKeyHex);
      await _storage.saveSecure('did_$npi', did);
      await _storage.saveSecure('userId_$npi', userId);

      state = AuthState(
        status: AuthStatus.authenticated,
        did: did,
        npi: npi,
        userId: userId,
        publicKey: pubKeyHex,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
    }
  }

  /** Connexion : prouve son identité par signature Ed25519 du NPI */
  Future<void> login(String npi) async {
    state = state.copyWith(status: AuthStatus.authenticating, error: null);
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

      final res = await _api.post('/auth/login', {
        'npi': npi,
        'signature': sigHex,
      });
      final newDid = res.data['did'] as String;

      state = AuthState(
        status: AuthStatus.authenticated,
        did: did ?? newDid,
        npi: npi,
        userId: userId,
        publicKey: pubKeyHex,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
    }
  }

  void logout() {
    state = const AuthState();
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(apiClientProvider),
    CryptoService(),
    StorageService(),
  );
});
