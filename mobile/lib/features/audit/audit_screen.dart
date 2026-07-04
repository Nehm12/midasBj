/**
 * Écran de vérification d'audit (journal des événements de sécurité).
 *
 * Affiche :
 * - Un badge d'intégrité général (vert si tout est OK, rouge si violation)
 * - La liste des événements (connexions, accès, modifications)
 * - Chaque événement avec timestamp, action, statut, et DPI concerné
 * - Pull-to-refresh pour recharger
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audit_provider.dart';

class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(auditProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit'),
        centerTitle: true,
        actions: [
          if (!state.isLoading)
            IconButton(
              icon: Icon(
                state.hasViolations
                    ? Icons.warning_amber_rounded
                    : Icons.verified_rounded,
                color: state.hasViolations ? Colors.red : Colors.green,
              ),
              tooltip: state.hasViolations
                  ? 'Violations détectées'
                  : 'Journal intègre',
              onPressed: () => _showIntegrityDialog(
                context,
                state.hasViolations,
                colorScheme,
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(auditProvider.notifier).loadEvents(),
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.events.isEmpty
                ? _buildEmptyState(theme, colorScheme)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.events.length,
                    itemBuilder: (ctx, i) => _AuditEventCard(
                      event: state.events[i],
                      theme: theme,
                      colorScheme: colorScheme,
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
          Icon(Icons.receipt_long_outlined, size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'Aucun événement d\'audit',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showIntegrityDialog(
      BuildContext context, bool hasViolations, ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              hasViolations
                  ? Icons.warning_amber_rounded
                  : Icons.verified_rounded,
              color: hasViolations ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 12),
            Text(hasViolations ? 'Violation détectée' : 'Journal intègre'),
          ],
        ),
        content: Text(
          hasViolations
              ? 'Des événements suspects ont été détectés dans le journal d\'audit. Consultez la liste des événements pour plus de détails.'
              : 'Le journal d\'audit ne contient aucune anomalie. Tous les événements sont vérifiés.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

class _AuditEventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _AuditEventCard({
    required this.event,
    required this.theme,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final action = event['action'] as String? ?? 'ACTION_INCONNUE';
    final status = event['status'] as String? ?? 'UNKNOWN';
    final timestamp = event['timestamp'] as String? ?? '—';
    final dpi = event['dpi'] as String? ?? '—';
    final details = event['details'] as String? ?? '';

    final isViolation = status == 'VIOLATION' || status == 'FAILED';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0.5,
      color: isViolation
          ? Colors.red.withValues(alpha: 0.03)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isViolation
                        ? Colors.red.withValues(alpha: 0.1)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _actionIcon(action),
                    size: 16,
                    color: isViolation ? Colors.red : colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    action,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isViolation ? Colors.red.shade700 : null,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isViolation
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isViolation ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              timestamp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
                fontSize: 11,
              ),
            ),
            if (dpi != '—') ...[
              const SizedBox(height: 4),
              Text(
                'DPI: $dpi',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: colorScheme.outline,
                ),
              ),
            ],
            if (details.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                details,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _actionIcon(String action) {
    if (action.contains('LOGIN')) return Icons.login;
    if (action.contains('ACCESS')) return Icons.lock_open;
    if (action.contains('MODIFY')) return Icons.edit;
    if (action.contains('CREATE')) return Icons.add_circle;
    if (action.contains('DELETE')) return Icons.delete;
    return Icons.info_outline;
  }
}
