/// Configuration du routeur GoRouter.
///
/// Deux zones :
///   - /auth : écran d'authentification
///   - /wallet, /consent, /iot, /audit, /profile : écrans protégés avec barre nav
library;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/keycloak_login_screen.dart';
import '../features/wallet/wallet_screen.dart';
import '../features/consent/consent_screen.dart';
import '../features/iot/iot_screen.dart';
import '../features/audit/audit_screen.dart';
import '../features/profile/profile_screen.dart';
import '../shared/widgets/scaffold_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/auth',
    routes: [
      GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
      GoRoute(path: '/auth/keycloak', builder: (_, __) => const KeycloakLoginScreen()),
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
          GoRoute(path: '/consent', builder: (_, __) => const ConsentScreen()),
          GoRoute(path: '/iot', builder: (_, __) => const IoTDeviceScreen()),
          GoRoute(path: '/audit', builder: (_, __) => const AuditScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
    ],
  );
});
