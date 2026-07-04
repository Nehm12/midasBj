import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import 'audit_provider.dart';

class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditState = ref.watch(auditProvider);
    final auth = ref.watch(authProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text('Journal d\'Audit', style: theme.textTheme.titleLarge),
            const Spacer(),
            if (auditState.isValid)
              Chip(avatar: const Icon(Icons.verified, size: 16), label: const Text('Intègre'))
            else
              Chip(avatar: const Icon(Icons.warning, size: 16, color: Colors.red), label: const Text('Violation')),
          ],
        ),
        const SizedBox(height: 16),
        if (auditState.violations.isNotEmpty)
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${auditState.violations.length} violation(s) détectée(s)')),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        if (auditState.events.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.history, size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  const Text('Aucun événement d\'audit'),
                  Text('Les actions seront journalisées ici', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ...auditState.events.map((e) => Card(
          margin: const EdgeInsets.only(bottom: 4),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(e.action[0].toUpperCase(), style: TextStyle(fontSize: 12, color: theme.colorScheme.onPrimaryContainer)),
            ),
            title: Text(e.action, style: const TextStyle(fontSize: 14)),
            subtitle: Text(
              '${e.entityType}/${e.entityId.substring(0, 8)}...\n${e.createdAt.toLocal()}',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Icon(Icons.verified, size: 16, color: Colors.green),
          ),
        )),
        const SizedBox(height: 16),
        FilledButton.tonal(
          onPressed: () => ref.read(auditProvider.notifier).loadTrail(auth.did ?? ''),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh),
              const SizedBox(width: 8),
              const Text('Charger mon journal'),
            ],
          ),
        ),
      ],
    );
  }
}
