import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';

class WalletState {
  final String? did;
  final String? didDoc;
  final List<Map<String, dynamic>> credentials;
  final bool isLoading;

  const WalletState({
    this.did,
    this.didDoc,
    this.credentials = const [],
    this.isLoading = false,
  });

  WalletState copyWith({
    String? did,
    String? didDoc,
    List<Map<String, dynamic>>? credentials,
    bool? isLoading,
  }) {
    return WalletState(
      did: did ?? this.did,
      didDoc: didDoc ?? this.didDoc,
      credentials: credentials ?? this.credentials,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  final ApiClient _api;

  WalletNotifier(this._api) : super(const WalletState());

  Future<void> createWallet(String userId) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _api.post('/wallet/create', {'userId': userId});
      state = WalletState(
        did: res.data['did'],
        didDoc: res.data['didDoc'].toString(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadCredentials(String userId) async {
    final res = await _api.get('/wallet/vcs', params: {'userId': userId});
    state = state.copyWith(
      credentials: List<Map<String, dynamic>>.from(res.data),
    );
  }

  Future<void> requestVC(String userId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _api.post('/wallet/issue-vc', {
        'userId': userId,
        'type': 'NpiCredential',
        'issuer': 'did:midas:benin:anip',
        'issuerPrivateKey': '',
      });
      await loadCredentials(userId);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier(ref.watch(apiClientProvider));
});
