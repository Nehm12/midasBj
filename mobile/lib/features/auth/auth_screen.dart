import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_provider.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go('/wallet');
      }
    });

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', height: 120, errorBuilder: (_, __, ___) =>
                Icon(Icons.verified_user, size: 80, color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 24),
              Text('MIDAS-Bénin', style: Theme.of(context).textTheme.headlineLarge),
              Text('Identité Numérique Souveraine', style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 48),
              FilledButton.icon(
                onPressed: authState.status == AuthStatus.authenticating
                    ? null
                    : () => _showNpiDialog(context, ref, 'enroll'),
                icon: const Icon(Icons.person_add),
                label: const Text('S\'enrôler avec mon NPI'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: authState.status == AuthStatus.authenticating
                    ? null
                    : () => _showNpiDialog(context, ref, 'login'),
                icon: const Icon(Icons.login),
                label: const Text('Se connecter'),
              ),
              if (authState.status == AuthStatus.authenticating)
                const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
              if (authState.error != null)
                Padding(padding: const EdgeInsets.all(8), child: Text(authState.error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            ],
          ),
        ),
      ),
    );
  }

  void _showNpiDialog(BuildContext context, WidgetRef ref, String mode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(mode == 'enroll' ? 'Saisir votre NPI' : 'Connexion'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(labelText: 'NPI', hintText: 'NPIBENIN2024...'),
          onSubmitted: (value) {
            Navigator.of(ctx).pop();
            if (mode == 'enroll') {
              ref.read(authProvider.notifier).register(value);
            } else {
              ref.read(authProvider.notifier).login(value);
            }
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
        ],
      ),
    );
  }
}
