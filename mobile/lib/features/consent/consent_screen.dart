import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import 'consent_provider.dart';

class ConsentScreen extends ConsumerWidget {
  const ConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consentState = ref.watch(consentProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text('Mes Consentements', style: theme.textTheme.titleLarge),
            const Spacer(),
            Text('${consentState.consents.length}', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 16),
        if (consentState.consents.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.shield_outlined, size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  const Text('Aucun consentement actif'),
                  Text('Les demandes apparaîtront ici', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ...consentState.consents.map((c) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: Icon(
              c.status == ConsentStatus.active || c.status == ConsentStatus.granted
                  ? Icons.check_circle : Icons.pending,
              color: c.status == ConsentStatus.active
                  ? Colors.green : c.status == ConsentStatus.revoked
                  ? Colors.red : Colors.orange,
            ),
            title: Text(c.purpose),
            subtitle: Text('Fournisseur: ${c.providerDID.substring(0, 16)}...'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Données partagées:', style: theme.textTheme.titleSmall),
                    Wrap(
                      spacing: 4,
                      children: c.dataClasses.map((d) => Chip(label: Text(d))).toList(),
                    ),
                    const SizedBox(height: 8),
                    Text('Durée: ${c.duration}s', style: theme.textTheme.bodySmall),
                    if (c.expiresAt != null)
                      Text('Expire: ${c.expiresAt!.toLocal()}', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 12),
                    if (c.status == ConsentStatus.requested)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => ref.read(consentProvider.notifier)
                                .revoke(c.id, authState.publicKey ?? ''),
                            child: const Text('Refuser')),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => ref.read(consentProvider.notifier)
                                .grant(c.id, authState.publicKey ?? ''),
                            child: const Text('Accepter')),
                        ],
                      ),
                    if (c.status == ConsentStatus.granted || c.status == ConsentStatus.active)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => ref.read(consentProvider.notifier)
                              .revoke(c.id, authState.publicKey ?? ''),
                          icon: const Icon(Icons.block, color: Colors.red),
                          label: const Text('Révoquer', style: TextStyle(color: Colors.red)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}
