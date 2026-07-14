/// Écran de connexion via Keycloak OIDC (flow PKCE dans un WebView).
library;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/network/keycloak_service.dart';
import 'auth_provider.dart';

class KeycloakLoginScreen extends ConsumerStatefulWidget {
  const KeycloakLoginScreen({super.key});

  @override
  ConsumerState<KeycloakLoginScreen> createState() => _KeycloakLoginScreenState();
}

class _KeycloakLoginScreenState extends ConsumerState<KeycloakLoginScreen> {
  late final KeycloakService _keycloak;
  late final WebViewController _webController;
  bool _loading = true;
  String? _error;
  bool _exchanged = false;
  late final String _codeVerifier;
  late final String _codeChallenge;

  static const _callbackScheme = 'midasbenin';

  @override
  void initState() {
    super.initState();
    _keycloak = KeycloakService();
    _codeVerifier = _keycloak.generateCodeVerifier();
    _codeChallenge = _keycloak.generateCodeChallenge(_codeVerifier);

    final authUrl = _keycloak.buildAuthUrl(
      codeChallenge: _codeChallenge,
      state: 'midas-state',
    );

    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (request) async {
            final url = request.url;
            if (url.startsWith('$_callbackScheme://') || url.contains('code=')) {
              final uri = Uri.parse(url);
              final code = uri.queryParameters['code'];
              if (code != null && !_exchanged) {
                await _exchangeCode(code);
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(authUrl);
  }

  Future<void> _exchangeCode(String code) async {
    _exchanged = true;
    try {
      final tokenData = await _keycloak.exchangeCodeForToken(
        code: code,
        codeVerifier: _codeVerifier,
      );
      final accessToken = tokenData['access_token'] as String;
      await ref.read(authProvider.notifier).loginWithKeycloak(accessToken);
      if (mounted) context.go('/wallet');
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Erreur d\'authentification: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go('/wallet');
      }
    });

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('SSO Keycloak'),
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 64, color: theme.colorScheme.error),
                const SizedBox(height: 24),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => context.go('/auth'),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Retour'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SSO Keycloak'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/auth'),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _webController),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF8B1A1A)),
            ),
        ],
      ),
    );
  }
}
