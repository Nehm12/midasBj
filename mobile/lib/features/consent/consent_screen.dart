/**
 * Écran de gestion des consentements.
 *
 * Affiche la liste des consentements donnés par l'utilisateur
 * pour le partage de données. Chaque consentement peut être :
 * - GRANTED (vert) : actif
 * - REVOKED (rouge) : révoqué
 * - PENDING (orange) : en attente
 *
 * Actions possibles : accorder, révoquer, ou supprimer un consentement.
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'consent_provider.dart';

class ConsentScreen extends ConsumerWidget {
  const ConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(consentProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Consentements'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(consentProvider.notifier).loadConsents(),
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.consents.isEmpty
                ? _buildEmptyState(theme, colorScheme)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.consents.length,
                    itemBuilder: (ctx, i) => _ConsentCard(
                      consent: state.consents[i],
                      theme: theme,
                      colorScheme: colorScheme,
                      onGrant: () => ref
                          .read(consentProvider.notifier)
                          .grantConsent(state.consents[i]['id']),
                      onRevoke: () => ref
                          .read(consentProvider.notifier)
                          .revokeConsent(state.consents[i]['id']),
                      onDelete: () => ref
                          .read(consentProvider.notifier)
                          .deleteConsent(state.consents[i]['id']),
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'Aucun consentement',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les consentements apparaîtront ici\nlorsque vous partagerez des données',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  final Map<String, dynamic> consent;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final VoidCallback onGrant;
  final VoidCallback onRevoke;
  final VoidCallback onDelete;

  const _ConsentCard({
    required this.consent,
    required this.theme,
    required this.colorScheme,
    required this.onGrant,
    required this.onRevoke,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final status = consent['status'] as String? ?? 'PENDING';
    final purpose = consent['purpose'] as String? ?? 'Partage de données';
    final dataClasses = consent['dataClasses'] as List<dynamic>? ?? [];
    final createdAt = consent['createdAt'] as String? ?? '—';

    final statusColor = switch (status) {
      'GRANTED' => Colors.green,
      'REVOKED' => Colors.red,
      _ => Colors.orange,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'grant':
                        onGrant();
                      case 'revoke':
                        onRevoke();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'grant',
                      child: ListTile(
                        leading: Icon(Icons.check_circle_outline),
                        title: Text('Accorder'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'revoke',
                      child: ListTile(
                        leading: Icon(Icons.block),
                        title: Text('Révoquer'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: Colors.red),
                        title: Text('Supprimer', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  ],
                  icon: Icon(Icons.more_vert, color: colorScheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              purpose,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (dataClasses.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: dataClasses.map((dc) => Chip(
                  label: Text(
                    dc.toString(),
                    style: const TextStyle(fontSize: 11),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                  backgroundColor: colorScheme.surfaceContainerHigh,
                )).toList(),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Créé le $createdAt',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
