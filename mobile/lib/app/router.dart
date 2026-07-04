/**
 * Configuration du routeur GoRouter.
 *
 * Deux zones :
 *   - /auth   : écran d'authentification (indépendant, sans barre de navigation)
 *   - /wallet, /consent, /iot, /audit : écrans protégés avec barre de navigation
 *     (AppShell avec bottom NavigationBar)
 */
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_screen.dart';
import '../features/wallet/wallet_screen.dart';
import '../features/consent/consent_screen.dart';
import '../features/iot/iot_screen.dart';
import '../features/audit/audit_screen.dart';
import '../shared/widgets/scaffold_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/auth',
    routes: [
      GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
          GoRoute(path: '/consent', builder: (_, __) => const ConsentScreen()),
          GoRoute(path: '/iot', builder: (_, __) => const IoTDeviceScreen()),
          GoRoute(path: '/audit', builder: (_, __) => const AuditScreen()),
        ],
      ),
    ],
  );
});
