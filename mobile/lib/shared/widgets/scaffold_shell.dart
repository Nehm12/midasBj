/**
 * Shell de navigation principal (AppShell).
 *
 * Fournit une barre de navigation inférieure Material 3 (NavigationBar)
 * entre les écrans protégés :
 * - Wallet (portefeuille d'identité)
 * - Consentements (gestion des consentements)
 * - IoT (appareils connectés)
 * - Audit (journal de vérification)
 */
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final colorScheme = Theme.of(context).colorScheme;

    // Déterminer l'index sélectionné à partir de la route courante
    int currentIndex = 0;
    if (location.startsWith('/wallet')) {
      currentIndex = 0;
    } else if (location.startsWith('/consent')) {
      currentIndex = 1;
    } else if (location.startsWith('/iot')) {
      currentIndex = 2;
    } else if (location.startsWith('/audit')) {
      currentIndex = 3;
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/wallet');
            case 1:
              context.go('/consent');
            case 2:
              context.go('/iot');
            case 3:
              context.go('/audit');
          }
        },
        indicatorColor: colorScheme.secondaryContainer,
        destinations: const [
          NavigationDestination(
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Wallet',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.shield_rounded),
            icon: Icon(Icons.shield_outlined),
            label: 'Consent',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.sensors_rounded),
            icon: Icon(Icons.sensors_outlined),
            label: 'IoT',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.receipt_long_rounded),
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Audit',
          ),
        ],
      ),
    );
  }
}
