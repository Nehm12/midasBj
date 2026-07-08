/// Gestion d'état du portefeuille.
library;
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointycastle/export.dart' as pc;
import '../../core/network/api_client.dart';
import '../../core/storage/storage_service.dart';
import '../auth/auth_provider.dart';

class WalletState {
  final List<Map<String, dynamic>> credentials;
  final String? did;
  final String? npi;
  final bool isLoading;
  final bool isEncrypted;
  final bool isLocked;

  const WalletState({
    this.credentials = const [],
    this.did,
    this.npi,
    this.isLoading = false,
    this.isEncrypted = false,
    this.isLocked = true,
  });
}

class WalletNotifier extends StateNotifier<WalletState> {
  final ApiClient _api;
  final StorageService _storage;
  bool _initialLoadDone = false;

  WalletNotifier(this._api, this._storage, AuthState authState)
      : super(WalletState(
          did: authState.did,
          npi: authState.npi,
        ));

  void syncAuth(AuthState authState) {
    final isFirstLoad = !_initialLoadDone;
    final changed = authState.npi != state.npi || authState.did != state.did;
    state = WalletState(
      credentials: state.credentials,
      did: authState.did ?? state.did,
      npi: authState.npi ?? state.npi,
      isLoading: state.isLoading,
      isEncrypted: state.isEncrypted,
      isLocked: state.isLocked,
    );
    if (authState.npi != null && !_initialLoadDone) {
      _initialLoadDone = true;
      if (changed || isFirstLoad) {
        loadWallet();
      }
    }
  }

  Future<void> loadWallet() async {
    if (state.npi == null) return;
    state = WalletState(
      isLoading: true,
      did: state.did,
      npi: state.npi,
      isEncrypted: state.isEncrypted,
      isLocked: state.isLocked,
    );
    try {
      final res = await _api.get('/wallet/vcs');
      final vcsList = res.data as List<dynamic>? ?? [];

      state = WalletState(
        credentials: vcsList.cast<Map<String, dynamic>>(),
        did: state.did,
        npi: state.npi,
        isLoading: false,
        isEncrypted: state.isEncrypted,
        isLocked: false,
      );
    } catch (e) {
      state = WalletState(
        isLoading: false,
        did: state.did,
        npi: state.npi,
        isEncrypted: state.isEncrypted,
        isLocked: false,
      );
    }
  }

  Future<void> issueCredential({
    String type = 'NpiCredential',
    String issuer = 'did:midas:benin:anip',
  }) async {
    try {
      await _api.post('/wallet/issue-vc', {
        'type': type,
        'issuer': issuer,
      });
      await loadWallet();
    } catch (e) {
      loadWallet();
    }
  }

  Future<void> revokeCredential(String vcId) async {
    try {
      await _api.post('/wallet/revoke-vc', {'vcId': vcId});
      await loadWallet();
    } catch (e) {}
  }

  Future<Map<String, dynamic>?> presentCredential(String vcId) async {
    try {
      final res = await _api.post('/wallet/present-vc', {'vcId': vcId});
      return res.data as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<void> rotateKey(String newPublicKey) async {
    try {
      await _api.post('/wallet/rotate-key', {'newPublicKey': newPublicKey});
    } catch (e) {}
  }

  static Uint8List deriveKey(String npi, String secret) {
    final keyMaterial = utf8.encode('$npi:midas-benin-wallet-v1:$secret');
    final digest = sha256.convert(keyMaterial);
    return Uint8List.fromList(digest.bytes);
  }

  Future<void> encryptWallet(String npi, String secret) async {
    final key = deriveKey(npi, secret);
    final credentialsJson = jsonEncode(state.credentials);
    final plaintext = utf8.encode(credentialsJson);

    final cipher = pc.PaddedBlockCipherImpl(
      pc.PKCS7Padding(),
      pc.CBCBlockCipher(pc.AESEngine()),
    );
    final iv = Uint8List.fromList(
      List.generate(16, (_) => DateTime.now().microsecondsSinceEpoch & 0xFF),
    );
    cipher.init(
      true,
      pc.PaddedBlockCipherParameters(
        pc.KeyParameter(key),
        pc.ParametersWithIV(pc.KeyParameter(key), iv),
      ),
    );

    final encrypted = cipher.process(plaintext);
    final combined = Uint8List(iv.length + encrypted.length)
      ..setAll(0, iv)
      ..setAll(iv.length, encrypted);

    await _storage.saveSecure('wallet_encrypted_$npi', base64Encode(combined));
    state = WalletState(
      credentials: state.credentials,
      did: state.did,
      npi: state.npi,
      isLoading: false,
      isEncrypted: true,
      isLocked: false,
    );
  }

  Future<void> decryptWallet(String npi, String secret) async {
    final encoded = await _storage.readSecure('wallet_encrypted_$npi');
    if (encoded == null) return;

    final key = deriveKey(npi, secret);
    final combined = base64Decode(encoded);
    final iv = combined.sublist(0, 16);
    final ciphertext = combined.sublist(16);

    final cipher = pc.PaddedBlockCipherImpl(
      pc.PKCS7Padding(),
      pc.CBCBlockCipher(pc.AESEngine()),
    );
    cipher.init(
      false,
      pc.PaddedBlockCipherParameters(
        pc.KeyParameter(key),
        pc.ParametersWithIV(pc.KeyParameter(key), iv),
      ),
    );

    final decrypted = cipher.process(ciphertext);
    final json = utf8.decode(decrypted);
    final credentials = (jsonDecode(json) as List).cast<Map<String, dynamic>>();

    state = WalletState(
      credentials: credentials,
      did: state.did,
      npi: state.npi,
      isLoading: false,
      isEncrypted: true,
      isLocked: false,
    );
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  final authState = ref.watch(authProvider);
  final notifier = WalletNotifier(
    ref.watch(apiClientProvider),
    StorageService(),
    authState,
  );
  ref.listen<AuthState>(authProvider, (_, next) {
    notifier.syncAuth(next);
  });
  return notifier;
});
