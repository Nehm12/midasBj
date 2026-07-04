/**
 * Écran du portefeuille d'identité numérique.
 *
 * Affiche :
 * - Une carte d'identité avec le DID, le NPI et un QR code
 * - La liste des Verifiable Credentials (VC)
 * - Un indicateur de chargement avec skeleton pendant le chargement
 * - Un bottom sheet détaillant un VC au tap
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'wallet_provider.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(walletProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portefeuille'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Mon DID',
            onPressed: () => _showDidDialog(context, state.did ?? ''),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(walletProvider.notifier).loadWallet(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (state.isLoading)
              ..._buildSkeletons(theme)
            else ...[
              _IdentityCard(state: state, colorScheme: colorScheme, theme: theme),
              const SizedBox(height: 24),
              Text(
                'Mes Credentials',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (state.credentials.isEmpty)
                _buildEmptyState(theme, colorScheme)
              else
                ...state.credentials.map(
                  (vc) => _CredentialCard(
                    vc: vc,
                    theme: theme,
                    colorScheme: colorScheme,
                    onTap: () => _showVcDetail(context, vc, colorScheme),
                  ),
                ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ref.read(walletProvider.notifier).issueCredential(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouveau VC'),
      ),
    );
  }

  List<Widget> _buildSkeletons(ThemeData theme) {
    return [
      Container(
        height: 200,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      const SizedBox(height: 24),
      ...List.generate(3, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      )),
    ];
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.verified_outlined, size: 48, color: colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            'Aucun credential pour le moment',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tapez "Nouveau VC" pour en créer un',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  void _showDidDialog(BuildContext context, String did) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Mon Identifiant Décentralisé'),
        content: SelectableText(did, style: const TextStyle(fontSize: 12)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showVcDetail(BuildContext context, Map<String, dynamic> vc, ColorScheme colorScheme) {
    final type = (vc['type'] as List?)?.join(', ') ?? 'Credential';
    final issuer = vc['issuer'] ?? vc['iss'] ?? 'Inconnu';
    final issuanceDate = vc['issuanceDate'] ?? vc['iat'] ?? '—';
    final credentialSubject = vc['credentialSubject'] as Map<String, dynamic>? ?? {};

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Chip(
              label: Text(type, style: const TextStyle(fontSize: 12)),
              backgroundColor: colorScheme.primaryContainer,
              side: BorderSide.none,
            ),
            const SizedBox(height: 16),
            _detailRow('Émetteur', issuer.toString()),
            _detailRow('Date d\'émission', issuanceDate.toString()),
            ...credentialSubject.entries.map((e) =>
              _detailRow(e.key, e.value.toString()),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Fermer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            )),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  final WalletState state;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _IdentityCard({
    required this.state,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.onPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  color: colorScheme.onPrimary,
                  size: 28,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.onPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'MIDAS',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Carte d\'Identité Numérique',
            style: TextStyle(
              color: colorScheme.onPrimary.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            state.npi ?? 'NPI inconnu',
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            state.did ?? 'DID inconnu',
            style: TextStyle(
              color: colorScheme.onPrimary.withValues(alpha: 0.65),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          // QR code placeholder
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colorScheme.onPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.qr_code_rounded,
                size: 36,
                color: colorScheme.onPrimary.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CredentialCard extends StatelessWidget {
  final Map<String, dynamic> vc;
  final ThemeData theme;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _CredentialCard({
    required this.vc,
    required this.theme,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final type = (vc['type'] as List?)?.join(', ') ?? 'Credential';
    final issuer = vc['issuer'] ?? 'Unknown';
    final did = vc['id'] ?? vc['jti'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.verified_rounded,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      issuer.toString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (did.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        did.toString(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: colorScheme.outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
