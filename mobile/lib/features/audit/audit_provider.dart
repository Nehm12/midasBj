/**
 * Gestion d'état du journal d'audit.
 *
 * AuditState stocke la liste des événements d'audit, le statut
 * de chargement, et un flag hasViolations pour alerter l'utilisateur
 * en cas d'anomalies.
 *
 * AuditNotifier :
 *   loadEvents() → récupère les événements depuis l'API
 */
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

class AuditState {
  final List<Map<String, dynamic>> events;
  final bool isLoading;
  final bool hasViolations;

  const AuditState({
    this.events = const [],
    this.isLoading = false,
    this.hasViolations = false,
  });
}

class AuditNotifier extends StateNotifier<AuditState> {
  final ApiClient _api;

  AuditNotifier(this._api) : super(const AuditState());

  Future<void> loadEvents() async {
    state = const AuditState(isLoading: true);
    try {
      final res = await _api.get('/audit/events');
      final list = (res.data['events'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      final violations = list.any((e) {
        final status = e['status'] as String? ?? '';
        return status == 'VIOLATION' || status == 'FAILED';
      });
      state = AuditState(events: list, hasViolations: violations);
    } catch (e) {
      state = const AuditState();
    }
  }
}

final auditProvider = StateNotifierProvider<AuditNotifier, AuditState>((ref) {
  return AuditNotifier(ref.watch(apiClientProvider));
});
