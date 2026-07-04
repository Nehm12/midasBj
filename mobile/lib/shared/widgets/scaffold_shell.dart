import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateIndex(context),
        onDestinationSelected: (index) => _onTap(context, index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.wallet), label: 'Wallet'),
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Consent'),
          NavigationDestination(icon: Icon(Icons.sensors), label: 'IoT'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Audit'),
        ],
      ),
    );
  }

  int _calculateIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/wallet')) return 0;
    if (location.startsWith('/consent')) return 1;
    if (location.startsWith('/iot')) return 2;
    if (location.startsWith('/audit')) return 3;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/wallet');
      case 1: context.go('/consent');
      case 2: context.go('/iot');
      case 3: context.go('/audit');
    }
  }
}
