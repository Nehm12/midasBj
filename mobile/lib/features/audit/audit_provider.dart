library;
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/crypto/crypto_service.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/storage_service.dart';
import '../auth/auth_provider.dart';

class AuditState {
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> violations;
  final bool isLoading;
  final bool hasViolations;
  final int totalEvents;
  final String? searchEntityType;
  final String? searchAction;
  final List<Map<String, dynamic>> entityTypes;

  const AuditState({
    this.events = const [],
    this.violations = const [],
    this.isLoading = false,
    this.hasViolations = false,
    this.totalEvents = 0,
    this.searchEntityType,
    this.searchAction,
    this.entityTypes = const [],
  });
}

class AuditNotifier extends StateNotifier<AuditState> {
  final ApiClient _api;
  final CryptoService _crypto;
  final StorageService _storage;
  final AuthState _authState;

  AuditNotifier(this._api, this._crypto, this._storage, this._authState)
      : super(const AuditState());

  Future<void> loadEvents({
    String? entityType,
    String? action,
    String? from,
    String? to,
    int? limit,
    int? offset,
  }) async {
    state = AuditState(isLoading: true);
    try {
      final params = <String, dynamic>{};
      if (entityType != null) params['entityType'] = entityType;
      if (action != null) params['action'] = action;
      if (from != null) params['from'] = from;
      if (to != null) params['to'] = to;
      if (limit != null) params['limit'] = limit.toString();
      if (offset != null) params['offset'] = offset.toString();

      final res = await _api.get('/audit/search', params: params);
      final data = res.data as Map<String, dynamic>;
      final list = (data['events'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final total = data['total'] as int? ?? 0;
      final violations = list.where((e) {
        final action = e['action'] as String? ?? '';
        return action.contains('ACCESS_DENIED') || action.contains('FAILED');
      }).toList();

      state = AuditState(
        events: list,
        violations: violations,
        hasViolations: violations.isNotEmpty,
        totalEvents: total,
        searchEntityType: entityType,
        searchAction: action,
        entityTypes: state.entityTypes,
      );
    } catch (_) {
      state = AuditState(entityTypes: state.entityTypes);
    }
  }

  Future<void> loadEntityTypes() async {
    try {
      final res = await _api.get('/audit/entity-types');
      final list = (res.data as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      state = AuditState(
        events: state.events,
        violations: state.violations,
        hasViolations: state.hasViolations,
        entityTypes: list,
      );
    } catch (_) {}
  }

  Future<void> loadViolations() async {
    state = AuditState(isLoading: true, entityTypes: state.entityTypes);
    try {
      final res = await _api.get('/audit/violations');
      final list = (res.data as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      state = AuditState(
        violations: list,
        hasViolations: list.isNotEmpty,
        entityTypes: state.entityTypes,
      );
    } catch (_) {
      state = AuditState(entityTypes: state.entityTypes);
    }
  }

  Future<Map<String, dynamic>?> verifyChain(String entityId) async {
    try {
      final res = await _api.post('/audit/verify', {'entityId': entityId});
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> exportProof(String entityId) async {
    try {
      final res = await _api.get('/audit/export/$entityId');
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Signe un événement d'audit avec la clé privée de l'utilisateur
  /// et l'envoie au serveur. Retourne l'événement créé ou null.
  Future<Map<String, dynamic>?> signAndLogEvent({
    required String entityType,
    required String entityId,
    required String action,
    Map<String, dynamic>? payload,
  }) async {
    final npi = _authState.npi;
    final did = _authState.did;
    if (npi == null) return null;

    try {
      final privKeyHex = await _storage.readSecure('kp_${npi}_priv');
      final pubKeyHex = await _storage.readSecure('kp_${npi}_pub');
      if (privKeyHex == null || pubKeyHex == null) return null;

      final privKeyBytes = base64Decode(privKeyHex);
      final keyPair = await _crypto.ed25519.newKeyPairFromSeed(privKeyBytes);

      final message = 'audit:$entityType:$entityId:$action';
      final signature = await _crypto.signEd25519(keyPair, utf8.encode(message));
      final userSignature = base64Encode(signature);

      final res = await _api.post('/audit/event', {
        'entityType': entityType,
        'entityId': entityId,
        'action': action,
        'payload': payload ?? {},
        'actorDID': did,
        'userSignature': userSignature,
      });
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

final auditProvider = StateNotifierProvider<AuditNotifier, AuditState>((ref) {
  final authState = ref.watch(authProvider);
  return AuditNotifier(
    ref.watch(apiClientProvider),
    CryptoService(),
    StorageService(),
    authState,
  );
});
