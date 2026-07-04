import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

class AuditEvent {
  final String id;
  final String action;
  final String entityType;
  final String entityId;
  final String hash;
  final String previousHash;
  final DateTime createdAt;

  const AuditEvent({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.hash,
    required this.previousHash,
    required this.createdAt,
  });

  factory AuditEvent.fromJson(Map<String, dynamic> json) => AuditEvent(
    id: json['id'] as String,
    action: json['action'] as String,
    entityType: json['entityType'] as String,
    entityId: json['entityId'] as String,
    hash: json['hash'] as String,
    previousHash: json['previousHash'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class AuditState {
  final List<AuditEvent> events;
  final List<String> violations;
  final bool isValid;
  final bool isLoading;

  const AuditState({
    this.events = const [],
    this.violations = const [],
    this.isValid = true,
    this.isLoading = false,
  });
}

class AuditNotifier extends StateNotifier<AuditState> {
  final ApiClient _api;

  AuditNotifier(this._api) : super(const AuditState());

  Future<void> loadTrail(String entityId) async {
    state = AuditState(isLoading: true);
    final res = await _api.get('/audit/trail/$entityId');
    final list = (res.data as List).map((e) => AuditEvent.fromJson(e)).toList();
    state = AuditState(events: list);
    await _loadViolations();
  }

  Future<void> verifyChain(String entityId) async {
    final res = await _api.post('/audit/verify', {'entityId': entityId});
    state = AuditState(
      events: state.events,
      isValid: res.data['valid'] as bool,
      violations: state.violations,
    );
  }

  Future<void> _loadViolations() async {
    try {
      final res = await _api.get('/audit/violations');
      final list = (res.data as List).map((e) => e['reason'] as String).toList();
      state = AuditState(
        events: state.events,
        isValid: list.isEmpty,
        violations: list,
      );
    } catch (_) {}
  }
}

final auditProvider = StateNotifierProvider<AuditNotifier, AuditState>((ref) {
  return AuditNotifier(ref.watch(apiClientProvider));
});
