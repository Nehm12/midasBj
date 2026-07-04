import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/crypto/crypto_service.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/storage_service.dart';
import '../auth/auth_provider.dart';

enum ConsentStatus { requested, granted, active, revoked, expired }

class Consent {
  final String id;
  final String providerDID;
  final String purpose;
  final List<String> dataClasses;
  final int duration;
  final ConsentStatus status;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const Consent({
    required this.id,
    required this.providerDID,
    required this.purpose,
    required this.dataClasses,
    required this.duration,
    required this.status,
    required this.createdAt,
    this.expiresAt,
  });

  factory Consent.fromJson(Map<String, dynamic> json) => Consent(
    id: json['id'] as String,
    providerDID: json['providerDID'] as String,
    purpose: json['purpose'] as String,
    dataClasses: List<String>.from(json['dataClasses']),
    duration: json['duration'] as int,
    status: ConsentStatus.values.firstWhere((e) => e.name == json['status']),
    createdAt: DateTime.parse(json['createdAt'] as String),
    expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt'] as String) : null,
  );
}

class ConsentState {
  final List<Consent> consents;
  final bool isLoading;

  const ConsentState({this.consents = const [], this.isLoading = false});
}

class ConsentNotifier extends StateNotifier<ConsentState> {
  final ApiClient _api;
  final CryptoService _crypto;
  final StorageService _storage;
  final Ref _ref;

  ConsentNotifier(this._api, this._crypto, this._storage, this._ref)
      : super(const ConsentState());

  Future<String?> _sign(String message) async {
    final npi = _ref.read(authProvider).npi;
    if (npi == null) return null;
    final privKeyHex = await _storage.readSecure('kp_${npi}_priv');
    final pubKeyHex = await _storage.readSecure('kp_${npi}_pub');
    if (privKeyHex == null || pubKeyHex == null) return null;

    final privKeyBytes = base64Decode(privKeyHex);
    final keyPair = await _crypto.ed25519.newKeyPairFromSeed(privKeyBytes);
    final sig = await _crypto.signEd25519(keyPair, utf8.encode(message));
    return base64Encode(sig);
  }

  Future<void> loadHistory(String userId) async {
    state = ConsentState(isLoading: true);
    final res = await _api.get('/consent/history', params: {'userId': userId});
    final list = (res.data as List).map((e) => Consent.fromJson(e)).toList();
    state = ConsentState(consents: list);
  }

  Future<void> grant(String consentId, String publicKey) async {
    final msg = 'grant:$consentId:${_ref.read(authProvider).userId}';
    final sig = await _sign(msg);
    if (sig == null) return;
    await _api.post('/consent/grant', {
      'consentId': consentId,
      'signature': sig,
      'publicKey': publicKey,
    });
    final userId = _ref.read(authProvider).userId ?? '';
    await loadHistory(userId);
  }

  Future<void> revoke(String consentId, String publicKey) async {
    final msg = 'revoke:$consentId:${_ref.read(authProvider).userId}';
    final sig = await _sign(msg);
    if (sig == null) return;
    await _api.post('/consent/revoke', {
      'consentId': consentId,
      'signature': sig,
      'publicKey': publicKey,
    });
    final userId = _ref.read(authProvider).userId ?? '';
    await loadHistory(userId);
  }
}

final consentProvider = StateNotifierProvider<ConsentNotifier, ConsentState>((ref) {
  return ConsentNotifier(
    ref.watch(apiClientProvider),
    CryptoService(),
    StorageService(),
    ref,
  );
});
