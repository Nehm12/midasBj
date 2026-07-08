library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audit_provider.dart';

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});
  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  String? _filterType;
  String? _filterAction;
  final _entityIdCtrl = TextEditingController();

  @override
  void dispose() {
    _entityIdCtrl.dispose();
    super.dispose();
  }

  IconData _actionIcon(String action) {
    if (action.contains('LOGIN') || action.contains('AUTH')) return Icons.login;
    if (action.contains('ACCESS')) return Icons.lock_open;
    if (action.contains('MODIFY') || action.contains('UPDATE')) return Icons.edit;
    if (action.contains('CREATE') || action.contains('REGISTER')) return Icons.add_circle;
    if (action.contains('DELETE') || action.contains('UNREGISTER')) return Icons.delete;
    if (action.contains('DENIED') || action.contains('FAILED')) return Icons.warning_amber;
    if (action.contains('BREACH') || action.contains('VIOLATION')) return Icons.gpp_bad;
    if (action.contains('PAIR') || action.contains('CONNECT')) return Icons.link;
    return Icons.info_outline;
  }

  Color _actionColor(String action) {
    if (action.contains('DENIED') || action.contains('FAILED') || action.contains('BREACH')) return Colors.red;
    if (action.contains('DELETE') || action.contains('UNREGISTER')) return Colors.orange;
    if (action.contains('CREATE') || action.contains('REGISTER') || action.contains('PAIR')) return Colors.green;
    return Colors.blueGrey;
  }

  String _timeAgo(String? ts) {
    if (ts == null) return '—';
    try {
      final dt = DateTime.parse(ts);
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'À l\'instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
      return 'Il y a ${diff.inDays}j';
    } catch (_) { return ts; }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(auditProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Audit & Gouvernance'),
        actions: [
          if (state.hasViolations)
            IconButton(
              icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFF8B1A1A)),
              tooltip: 'Violations détectées',
              onPressed: () {
                ref.read(auditProvider.notifier).loadViolations();
                _showViolationsDialog(context, state);
              },
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'export') _showExportDialog(context);
              if (v == 'verify') _showVerifyDialog(context);
              if (v == 'violations') ref.read(auditProvider.notifier).loadViolations();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'export', child: ListTile(leading: Icon(Icons.file_download), title: Text('Exporter preuve'), dense: true)),
              const PopupMenuItem(value: 'verify', child: ListTile(leading: Icon(Icons.verified), title: Text('Vérifier chaîne'), dense: true)),
              const PopupMenuItem(value: 'violations', child: ListTile(leading: Icon(Icons.warning_amber, color: Colors.red), title: Text('Violations'), dense: true)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(theme, state),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(auditProvider.notifier).loadEvents(
                entityType: _filterType, action: _filterAction,
              ),
              child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.events.isEmpty
                  ? _buildEmptyState(theme)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: state.events.length,
                      itemBuilder: (ctx, i) => _AuditEventCard(
                        event: state.events[i], theme: theme,
                        actionIcon: _actionIcon(state.events[i]['action'] as String? ?? ''),
                        actionColor: _actionColor(state.events[i]['action'] as String? ?? ''),
                        timeAgo: _timeAgo(state.events[i]['createdAt'] as String?),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme, AuditState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _filterType,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Type', border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tous')),
                ...state.entityTypes.map((t) => DropdownMenuItem(
                  value: t['type'] as String,
                  child: Text('${t['type']} (${t['count']})', style: const TextStyle(fontSize: 12)),
                )),
              ],
              onChanged: (v) {
                setState(() => _filterType = v);
                ref.read(auditProvider.notifier).loadEvents(entityType: v, action: _filterAction);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _filterAction,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Action', border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Toutes')),
                DropdownMenuItem(value: 'LOGIN', child: Text('Connexion')),
                DropdownMenuItem(value: 'ACCESS', child: Text('Accès')),
                DropdownMenuItem(value: 'CREATE', child: Text('Création')),
                DropdownMenuItem(value: 'DELETE', child: Text('Suppression')),
                DropdownMenuItem(value: 'BREACH', child: Text('Violation')),
              ],
              onChanged: (v) {
                setState(() => _filterAction = v);
                ref.read(auditProvider.notifier).loadEvents(entityType: _filterType, action: v);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exporter une preuve'),
        content: TextField(
          controller: _entityIdCtrl,
          decoration: const InputDecoration(labelText: 'ID de l\'entité', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () async {
            final proof = await ref.read(auditProvider.notifier).exportProof(_entityIdCtrl.text);
            if (!context.mounted) return;
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(proof != null ? 'Preuve exportée (${proof['eventCount']} événements)' : 'Échec de l\'export')),
            );
          }, child: const Text('Exporter')),
        ],
      ),
    );
  }

  void _showVerifyDialog(BuildContext context) {
    final idCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vérifier chaîne'),
        content: TextField(controller: idCtrl, decoration: const InputDecoration(labelText: 'ID de l\'entité', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () async {
            final result = await ref.read(auditProvider.notifier).verifyChain(idCtrl.text);
            if (!context.mounted) return;
            Navigator.pop(ctx);
            final valid = result?['valid'] == true;
            showDialog(
              context: context,
              builder: (c) => AlertDialog(
                title: Row(children: [
                  Icon(valid ? Icons.verified : Icons.cancel, color: valid ? Colors.green : Colors.red),
                  const SizedBox(width: 12),
                  Text(valid ? 'Chaîne valide' : 'Chaîne corrompue'),
                ]),
                content: Text(valid
                  ? '${result?['eventCount']} événements vérifiés'
                  : 'Rupture détectée : ${result?['reason']}'),
                actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Fermer'))],
              ),
            );
          }, child: const Text('Vérifier')),
        ],
      ),
    );
  }

  void _showViolationsDialog(BuildContext context, AuditState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 12),
          Text('${state.violations.length} violation(s)'),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: state.violations.isEmpty
            ? const Text('Aucune violation détectée')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: state.violations.length,
                itemBuilder: (_, i) {
                  final v = state.violations[i];
                  return ListTile(
                    leading: Icon(Icons.gpp_bad, color: Colors.red, size: 20),
                    title: Text(v['action'] as String? ?? '', style: const TextStyle(fontSize: 12)),
                    subtitle: Text('${v['reason']} — ${v['entityId']}', style: const TextStyle(fontSize: 10)),
                    dense: true,
                  );
                },
              ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: const Color(0xFFB0B0B0)),
          const SizedBox(height: 16),
          Text("Aucun événement d'audit", style: theme.textTheme.titleMedium?.copyWith(color: const Color(0xFF1A1A1A).withAlpha(153))),
        ],
      ),
    );
  }
}

class _AuditEventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final ThemeData theme;
  final IconData actionIcon;
  final Color actionColor;
  final String timeAgo;

  const _AuditEventCard({
    required this.event, required this.theme,
    required this.actionIcon, required this.actionColor, required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    final action = event['action'] as String? ?? '—';
    final entityType = event['entityType'] as String? ?? '';
    final entityId = event['entityId'] as String? ?? '';
    final actorDID = event['actorDID'] as String?;
    final hash = event['hash'] as String? ?? '';
    final isViolation = action.contains('DENIED') || action.contains('FAILED') || action.contains('BREACH');
    final hasUserSig = event['userSignature'] != null &&
        (event['userSignature'] as String?)?.isNotEmpty == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isViolation ? const Color(0xFF8B1A1A).withAlpha(8) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: actionColor.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                child: Icon(actionIcon, size: 16, color: actionColor),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(action, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
              if (hasUserSig)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.verified_user, size: 14, color: Colors.blue),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isViolation ? Colors.red.withAlpha(25) : Colors.green.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(isViolation ? 'VIOLATION' : 'OK', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(timeAgo, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (entityType.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('$entityType • $entityId', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            if (actorDID != null) ...[
              const SizedBox(height: 2),
              Text('Acteur: $actorDID', style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            if (hash.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                Text('Hash: ${hash.substring(0, 16)}...', style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Colors.grey)),
                const Spacer(),
                if (hasUserSig)
                  const Icon(Icons.verified_user, size: 10, color: Colors.blue),
                if (hasUserSig)
                  const SizedBox(width: 2),
                if (hasUserSig)
                  Text('Signé', style: TextStyle(fontSize: 8, color: Colors.blue[600])),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
