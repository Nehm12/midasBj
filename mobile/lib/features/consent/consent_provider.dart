library;
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/crypto/crypto_service.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/storage_service.dart';
import '../../features/auth/auth_provider.dart';

class ConsentState {
  final List<Map<String, dynamic>> consents;
  final bool isLoading;
  final String? error;
  final Map<String, List<String>> availableDataClasses;

  const ConsentState({
    this.consents = const [],
    this.isLoading = false,
    this.error,
    this.availableDataClasses = const {},
  });
}

class ConsentNotifier extends StateNotifier<ConsentState> {
  final ApiClient _api;
  final CryptoService _crypto;
  final StorageService _storage;
  final AuthState _auth;

  ConsentNotifier(this._api, this._crypto, this._storage, this._auth)
      : super(const ConsentState()) {
    loadDataClasses();
  }

  static const consentTypes = ['TEMPORARY', 'PERMANENT', 'SINGLE_USE'];

  Future<void> loadDataClasses() async {
    try {
      final res = await _api.get('/consent/data-classes');
      final data = res.data as Map<String, dynamic>;
      state = ConsentState(
        consents: state.consents,
        availableDataClasses: data.map((k, v) => MapEntry(k, List<String>.from(v as List))),
      );
    } catch (_) {}
  }

  Future<String?> _signConsentMessage(String message) async {
    final npi = _auth.npi;
    if (npi == null) return null;
    final privKeyHex = await _storage.readSecure('kp_${npi}_priv');
    if (privKeyHex == null) return null;
    final privKeyBytes = base64Decode(privKeyHex);
    final keyPair = await _crypto.ed25519.newKeyPairFromSeed(privKeyBytes);
    final sig = await _crypto.signEd25519(keyPair, utf8.encode(message));
    return base64Encode(sig);
  }

  Future<void> loadConsents() async {
    state = ConsentState(
      isLoading: true,
      availableDataClasses: state.availableDataClasses,
    );
    try {
      final res = await _api.get('/consent/history');
      final list = (res.data as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      state = ConsentState(
        consents: list,
        availableDataClasses: state.availableDataClasses,
      );
    } catch (e) {
      state = ConsentState(
        error: e.toString(),
        availableDataClasses: state.availableDataClasses,
      );
    }
  }

  Future<void> requestConsent({
    required String providerDID,
    required String purpose,
    required List<String> dataClasses,
    required String consentType,
    int? duration,
    int? maxUsageCount,
  }) async {
    try {
      await _api.post('/consent/request', {
        'providerDID': providerDID,
        'purpose': purpose,
        'dataClasses': dataClasses,
        'consentType': consentType,
        'duration': ?duration,
        if (consentType == 'SINGLE_USE' && maxUsageCount != null) 'maxUsageCount': maxUsageCount,
      });
      await loadConsents();
    } catch (e) {
      state = ConsentState(
        consents: state.consents,
        availableDataClasses: state.availableDataClasses,
        error: e.toString(),
      );
    }
  }

  Future<bool> grantConsent(String id, Map<String, dynamic> consent) async {
    try {
      final npi = _auth.npi;
      if (npi == null) return false;
      final pubKeyHex = await _storage.readSecure('kp_${npi}_pub');
      if (pubKeyHex == null) return false;

      final dataClasses = (consent['dataClasses'] as List?)?.join(',') ?? '';
      final consentType = consent['consentType'] as String? ?? 'TEMPORARY';
      final message = 'grant:$id:${_auth.userId}:${consent['purpose']}:$dataClasses:$consentType';
      final signature = await _signConsentMessage(message);
      if (signature == null) return false;

      await _api.post('/consent/grant', {
        'consentId': id,
        'signature': signature,
        'publicKey': pubKeyHex,
      });
      await loadConsents();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> revokeConsent(String id, Map<String, dynamic> consent) async {
    try {
      final npi = _auth.npi;
      if (npi == null) return false;
      final pubKeyHex = await _storage.readSecure('kp_${npi}_pub');
      if (pubKeyHex == null) return false;

      final message = 'revoke:$id:${_auth.userId}:${consent['purpose']}';
      final signature = await _signConsentMessage(message);
      if (signature == null) return false;

      await _api.post('/consent/revoke', {
        'consentId': id,
        'signature': signature,
        'publicKey': pubKeyHex,
      });
      await loadConsents();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> denyConsent(String id) async {
    try {
      await _api.post('/consent/deny', {'consentId': id});
      await loadConsents();
    } catch (_) {}
  }

  Future<List<String>> getDataClassesForPurpose(String purpose) async {
    try {
      final res = await _api.get('/consent/data-classes', params: {'purpose': purpose});
      final data = res.data as Map<String, dynamic>;
      return List<String>.from(data['dataClasses'] as List);
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> exportData() async {
    try {
      final res = await _api.get('/consent/export');
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

final consentProvider = StateNotifierProvider<ConsentNotifier, ConsentState>((ref) {
  return ConsentNotifier(
    ref.watch(apiClientProvider),
    CryptoService(),
    StorageService(),
    ref.watch(authProvider),
  );
});
