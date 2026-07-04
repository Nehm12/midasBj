/**
 * Gestion d'état des consentements.
 *
 * ConsentState stocke la liste des consentements et le statut
 * de chargement.
 *
 * ConsentNotifier :
 *   loadConsents()   → récupère les consentements depuis l'API
 *   grantConsent()   → accorde un consentement
 *   revokeConsent()  → révoque un consentement
 *   deleteConsent()  → supprime un consentement
 */
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

class ConsentState {
  final List<Map<String, dynamic>> consents;
  final bool isLoading;

  const ConsentState({this.consents = const [], this.isLoading = false});
}

class ConsentNotifier extends StateNotifier<ConsentState> {
  final ApiClient _api;

  ConsentNotifier(this._api) : super(const ConsentState());

  Future<void> loadConsents() async {
    state = ConsentState(isLoading: true);
    try {
      final res = await _api.get('/consent');
      final list = (res.data['consents'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      state = ConsentState(consents: list);
    } catch (e) {
      state = const ConsentState();
    }
  }

  Future<void> grantConsent(String id) async {
    try {
      await _api.put('/consent/$id', {'status': 'GRANTED'});
      await loadConsents();
    } catch (_) {}
  }

  Future<void> revokeConsent(String id) async {
    try {
      await _api.put('/consent/$id', {'status': 'REVOKED'});
      await loadConsents();
    } catch (_) {}
  }

  Future<void> deleteConsent(String id) async {
    try {
      await _api.delete('/consent/$id');
      await loadConsents();
    } catch (_) {}
  }
}

final consentProvider =
    StateNotifierProvider<ConsentNotifier, ConsentState>((ref) {
  return ConsentNotifier(ref.watch(apiClientProvider));
});
