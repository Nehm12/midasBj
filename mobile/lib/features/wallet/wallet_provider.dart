/**
 * Gestion d'état du portefeuille.
 *
 * WalletState contient la liste des Verifiable Credentials (VC)
 * et le statut de chargement.
 *
 * WalletNotifier :
 *   loadWallet()   → récupère les VCs depuis l'API
 *   issueCredential() → demande un nouveau VC via l'API
 */
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

class WalletState {
  final List<Map<String, dynamic>> credentials;
  final String? did;
  final String? npi;
  final bool isLoading;

  const WalletState({
    this.credentials = const [],
    this.did,
    this.npi,
    this.isLoading = false,
  });
}

class WalletNotifier extends StateNotifier<WalletState> {
  final ApiClient _api;

  WalletNotifier(this._api) : super(const WalletState());

  Future<void> loadWallet() async {
    state = WalletState(isLoading: true, did: state.did, npi: state.npi);
    try {
      final res = await _api.get('/wallet');
      final walletData = res.data['wallet'] as Map<String, dynamic>?;
      final vcs = walletData?['credentials'] as List<dynamic>? ?? [];

      state = WalletState(
        credentials: vcs.cast<Map<String, dynamic>>(),
        did: res.data['did'] as String? ?? state.did,
        npi: res.data['npi'] as String? ?? state.npi,
        isLoading: false,
      );
    } catch (e) {
      state = WalletState(
        isLoading: false,
        did: state.did,
        npi: state.npi,
      );
    }
  }

  Future<void> issueCredential() async {
    try {
      await _api.post('/wallet/issue-vc', {
        'type': 'BasicIdentityCredential',
        'claims': {'fullName': 'Citoyen MIDAS', 'dateOfBirth': '1990-01-01'},
      });
      await loadWallet();
    } catch (e) {
      // L'erreur sera gérée dans l'écran
    }
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier(ref.watch(apiClientProvider));
});
