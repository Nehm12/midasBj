import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../auth/auth_provider.dart';
import 'wallet_provider.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final wallet = ref.watch(walletProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    (auth.npi ?? '??').substring(0, 2),
                    style: TextStyle(fontSize: 24, color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Mon Identité Numérique', style: theme.textTheme.titleMedium),
                Text(auth.did ?? 'Aucun DID', style: theme.textTheme.bodySmall),
                const SizedBox(height: 16),
                if (wallet.did != null)
                  QrImageView(data: wallet.did!, size: 120, eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: theme.colorScheme.primary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Mes Credentials Vérifiables', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (wallet.credentials.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.badge_outlined, size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 8),
                  const Text('Aucun credential pour le moment'),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => ref.read(walletProvider.notifier).requestVC(auth.userId ?? ''),
                    child: const Text('Demander un VC ANIP')),
                ],
              ),
            ),
          ),
        ...wallet.credentials.map((vc) => Card(
          child: ListTile(
            leading: Icon(Icons.verified, color: theme.colorScheme.primary),
            title: Text(vc['type']?.toString() ?? 'VC'),
            subtitle: Text('Issu par: ${vc['issuer'] ?? 'N/A'}'),
            trailing: const Icon(Icons.qr_code),
          ),
        )),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => ref.read(walletProvider.notifier).createWallet(auth.did ?? ''),
          icon: const Icon(Icons.refresh),
          label: const Text('Initialiser le Wallet'),
        ),
      ],
    );
  }
}
