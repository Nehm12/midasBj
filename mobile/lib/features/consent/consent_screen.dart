library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'consent_provider.dart';

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  final _npiController = TextEditingController();
  final _purposeController = TextEditingController();
  final _durationController = TextEditingController(text: '3600');
  final _usageController = TextEditingController(text: '1');
  String _selectedConsentType = 'TEMPORARY';
  List<String> _selectedDataClasses = [];
  bool _showRequestForm = false;

  @override
  void dispose() {
    _npiController.dispose();
    _purposeController.dispose();
    _durationController.dispose();
    _usageController.dispose();
    super.dispose();
  }

  String _consentTypeLabel(String type) => switch (type) {
    'TEMPORARY' => 'Temporaire',
    'PERMANENT' => 'Permanent',
    'SINGLE_USE' => 'Usage unique',
    _ => type,
  };

  IconData _consentTypeIcon(String type) => switch (type) {
    'TEMPORARY' => Icons.timer_outlined,
    'PERMANENT' => Icons.star_border,
    'SINGLE_USE' => Icons.looks_one,
    _ => Icons.shield_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(consentProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Consentements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Exporter mes données',
            onPressed: _exportData,
          ),
          IconButton(
            icon: Icon(_showRequestForm ? Icons.close : Icons.add),
            tooltip: 'Nouvelle demande',
            onPressed: () => setState(() => _showRequestForm = !_showRequestForm),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(consentProvider.notifier).loadConsents(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(state.error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_showRequestForm) _buildRequestForm(theme, colorScheme, state),
            if (state.isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ))
            else if (state.consents.isEmpty && !_showRequestForm)
              _buildEmptyState(theme, colorScheme)
            else
              ...state.consents.map((c) => _ConsentCard(
                consent: c,
                theme: theme,
                colorScheme: colorScheme,
                onGrant: () => ref.read(consentProvider.notifier)
                    .grantConsent(c['id'], c),
                onRevoke: () => ref.read(consentProvider.notifier)
                    .revokeConsent(c['id'], c),
                onDeny: () => ref.read(consentProvider.notifier)
                    .denyConsent(c['id']),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestForm(ThemeData theme, ColorScheme colorScheme, ConsentState state) {
    final purposes = state.availableDataClasses.keys.toList();
    final availableClasses = state.availableDataClasses[_purposeController.text] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nouveau consentement', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: _npiController,
              decoration: const InputDecoration(
                labelText: 'DID du fournisseur',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (purposes.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: purposes.contains(_purposeController.text) ? _purposeController.text : null,
                decoration: const InputDecoration(
                  labelText: 'Finalité',
                  border: OutlineInputBorder(),
                ),
                items: purposes.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (v) {
                  setState(() {
                    _purposeController.text = v ?? '';
                    _selectedDataClasses = [];
                  });
                  ref.read(consentProvider.notifier).getDataClassesForPurpose(v ?? '');
                },
              )
            else
              TextField(
                controller: _purposeController,
                decoration: const InputDecoration(
                  labelText: 'Finalité',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 12),
            if (availableClasses.isNotEmpty) ...[
              const Text('Données partagées :', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: availableClasses.map((dc) => FilterChip(
                  label: Text(dc),
                  selected: _selectedDataClasses.contains(dc),
                  onSelected: (sel) {
                    setState(() {
                      if (sel) {
                        _selectedDataClasses.add(dc);
                      } else {
                        _selectedDataClasses.remove(dc);
                      }
                    });
                  },
                )).toList(),
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<String>(
              initialValue: _selectedConsentType,
              decoration: const InputDecoration(
                labelText: 'Type de consentement',
                border: OutlineInputBorder(),
              ),
              items: ConsentNotifier.consentTypes.map((t) => DropdownMenuItem(
                value: t,
                child: Row(children: [
                  Icon(_consentTypeIcon(t), size: 18),
                  const SizedBox(width: 8),
                  Text(_consentTypeLabel(t)),
                ]),
              )).toList(),
              onChanged: (v) => setState(() => _selectedConsentType = v ?? 'TEMPORARY'),
            ),
            if (_selectedConsentType == 'TEMPORARY') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: 'Durée (secondes)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
            if (_selectedConsentType == 'SINGLE_USE') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _usageController,
                decoration: const InputDecoration(
                  labelText: 'Nombre d\'utilisations max',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Envoyer la demande'),
                onPressed: () async {
                  await ref.read(consentProvider.notifier).requestConsent(
                    providerDID: _npiController.text,
                    purpose: _purposeController.text,
                    dataClasses: _selectedDataClasses,
                    consentType: _selectedConsentType,
                    duration: int.tryParse(_durationController.text),
                    maxUsageCount: int.tryParse(_usageController.text),
                  );
                  setState(() => _showRequestForm = false);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData() async {
    final data = await ref.read(consentProvider.notifier).exportData();
    if (!context.mounted) return;
    if (data != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Données exportées avec succès')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec de l\'export')),
      );
    }
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 64),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 64, color: const Color(0xFFB0B0B0)),
            const SizedBox(height: 16),
            Text(
              'Aucun consentement',
              style: theme.textTheme.titleMedium?.copyWith(
                color: const Color(0xFF1A1A1A).withAlpha(153),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Appuyez sur + pour créer une demande',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF1A1A1A).withAlpha(128),
              ),
            ),
          ],
        ),
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
  final VoidCallback onDeny;

  const _ConsentCard({
    required this.consent,
    required this.theme,
    required this.colorScheme,
    required this.onGrant,
    required this.onRevoke,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    final status = consent['status'] as String? ?? 'REQUESTED';
    final statusLabel = switch (status) {
      'REQUESTED' => 'Demandé',
      'PENDING_REVIEW' => 'En attente',
      'GRANTED' => 'Approuvé',
      'ACTIVE' => 'Actif',
      'REVOKED' => 'Révoqué',
      'EXPIRED' => 'Expiré',
      'DENIED' => 'Refusé',
      'COMPLETED' => 'Terminé',
      _ => status,
    };
    final consentType = consent['consentType'] as String? ?? 'TEMPORARY';
    final consentTypeLabel = switch (consentType) {
      'TEMPORARY' => 'Temporaire',
      'PERMANENT' => 'Permanent',
      'SINGLE_USE' => 'Usage unique',
      _ => consentType,
    };
    final purpose = consent['purpose'] as String? ?? 'Partage de données';
    final dataClasses = consent['dataClasses'] as List<dynamic>? ?? [];
    final providerDID = consent['providerDID'] as String? ?? '';
    final usageCount = consent['usageCount'] as int? ?? 0;
    final maxUsage = consent['maxUsageCount'] as int? ?? 1;
    final createdAt = consent['createdAt'] as String? ?? '';
    final statusColor = switch (status) {
      'GRANTED' || 'ACTIVE' => Colors.green,
      'REVOKED' || 'DENIED' => Colors.red,
      'COMPLETED' => Colors.blue,
      'EXPIRED' => Colors.grey,
      _ => Colors.orange,
    };

    final icon = switch (consentType) {
      'TEMPORARY' => Icons.timer_outlined,
    'PERMANENT' => Icons.star_border,
      'SINGLE_USE' => Icons.looks_one,
      _ => Icons.shield_outlined,
    };

    final canGrant = status == 'REQUESTED' || status == 'PENDING_REVIEW';
    final canRevoke = status == 'ACTIVE' || status == 'GRANTED';
    final canDeny = status == 'REQUESTED' || status == 'PENDING_REVIEW';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: statusColor),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(statusLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(consentTypeLabel, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'grant': onGrant();
                      case 'revoke': onRevoke();
                      case 'deny': onDeny();
                    }
                  },
                  itemBuilder: (_) => [
                    if (canGrant)
                      const PopupMenuItem(value: 'grant', child: ListTile(
                        leading: Icon(Icons.check_circle_outline, color: Colors.green),
                        title: Text('Accorder'),
                      )),
                    if (canDeny)
                      const PopupMenuItem(value: 'deny', child: ListTile(
                        leading: Icon(Icons.cancel_outlined, color: Colors.orange),
                        title: Text('Refuser'),
                      )),
                    if (canRevoke)
                      const PopupMenuItem(value: 'revoke', child: ListTile(
                        leading: Icon(Icons.block, color: Colors.red),
                        title: Text('Révoquer'),
                      )),
                  ],
                  icon: Icon(Icons.more_vert, color: const Color(0xFFB0B0B0)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(purpose, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            if (providerDID.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(providerDID, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontSize: 11)),
            ],
            const SizedBox(height: 8),
            if (dataClasses.isNotEmpty) ...[
              Wrap(spacing: 6, runSpacing: 4, children: dataClasses.map((dc) => Chip(
                label: Text(dc.toString(), style: const TextStyle(fontSize: 11)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                backgroundColor: const Color(0xFFF0F0F0),
              )).toList()),
              const SizedBox(height: 8),
            ],
            if (consentType == 'SINGLE_USE')
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Utilisation : $usageCount / $maxUsage',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.blueGrey)),
              ),
            if (createdAt.isNotEmpty)
              Text('Créé le $createdAt', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
            if (canGrant || canRevoke)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    if (canGrant)
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Accorder'),
                          onPressed: onGrant,
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
                        ),
                      ),
                    if (canGrant && canDeny) const SizedBox(width: 8),
                    if (canDeny)
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Refuser'),
                          onPressed: onDeny,
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                        ),
                      ),
                    if (canRevoke)
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.block, size: 16),
                          label: const Text('Révoquer'),
                          onPressed: onRevoke,
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
