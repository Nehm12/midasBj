/// Shell de navigation principal (AppShell).
///
/// Barre de navigation inférieure Material 3 (NavigationBar) :
/// Wallet, Consent, IoT, Audit, Profil.
library;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    int currentIndex = 0;
    if (location.startsWith('/wallet')) {
      currentIndex = 0;
    } else if (location.startsWith('/consent')) {
      currentIndex = 1;
    } else if (location.startsWith('/iot')) {
      currentIndex = 2;
    } else if (location.startsWith('/audit')) {
      currentIndex = 3;
    } else if (location.startsWith('/profile')) {
      currentIndex = 4;
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        onDestinationSelected: (i) {
          switch (i) {
            case 0: context.go('/wallet');
            case 1: context.go('/consent');
            case 2: context.go('/iot');
            case 3: context.go('/audit');
            case 4: context.go('/profile');
          }
        },
        indicatorColor: const Color(0xFF8B1A1A).withValues(alpha: 0.1),
        destinations: const [
          NavigationDestination(
            selectedIcon: Icon(Icons.account_balance_wallet_rounded,
                color: Color(0xFF8B1A1A)),
            icon: Icon(Icons.account_balance_wallet_outlined,
                color: Color(0xFF1A1A1A)),
            label: 'Wallet',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.shield_rounded,
                color: Color(0xFF8B1A1A)),
            icon: Icon(Icons.shield_outlined,
                color: Color(0xFF1A1A1A)),
            label: 'Consent',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.sensors_rounded,
                color: Color(0xFF8B1A1A)),
            icon: Icon(Icons.sensors_outlined,
                color: Color(0xFF1A1A1A)),
            label: 'IoT',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.receipt_long_rounded,
                color: Color(0xFF8B1A1A)),
            icon: Icon(Icons.receipt_long_outlined,
                color: Color(0xFF1A1A1A)),
            label: 'Audit',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.person_rounded,
                color: Color(0xFF8B1A1A)),
            icon: Icon(Icons.person_outline_rounded,
                color: Color(0xFF1A1A1A)),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
