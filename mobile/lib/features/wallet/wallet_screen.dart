/// Écran du portefeuille d'identité numérique.
///
/// Affiche :
/// - Carte d'identité avec DID, NPI, QR code
/// - Statut chiffrement wallet
/// - Liste des Verifiable Credentials
/// - Boutons par type d'émetteur (ANIP, CNA, Université)
/// - Révocation de VC
library;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'wallet_provider.dart';
import '../auth/auth_provider.dart';

const _issuerConfigs = [
  {'type': 'NpiCredential', 'issuer': 'did:midas:benin:anip', 'label': 'CIN (ANIP)', 'icon': Icons.badge_rounded},
  {'type': 'Passport', 'issuer': 'did:midas:benin:dgmep', 'label': 'Passeport', 'icon': Icons.flight_rounded},
  {'type': 'DriverLicense', 'issuer': 'did:midas:benin:cna', 'label': 'Permis (CNA)', 'icon': Icons.directions_car_rounded},
  {'type': 'HealthInsurance', 'issuer': 'did:midas:benin:cnamu', 'label': 'Assurance Maladie', 'icon': Icons.medical_services_rounded},
  {'type': 'SocialSecurity', 'issuer': 'did:midas:benin:cnss', 'label': 'Carte CNSS', 'icon': Icons.security_rounded},
  {'type': 'VoterCard', 'issuer': 'did:midas:benin:cena', 'label': 'Carte d\'Électeur', 'icon': Icons.how_to_vote_rounded},
  {'type': 'Diploma', 'issuer': 'did:midas:benin:uac', 'label': 'Diplôme (UAC)', 'icon': Icons.school_rounded},
  {'type': 'BirthCertificate', 'issuer': 'did:midas:benin:mairie', 'label': 'Acte de Naissance', 'icon': Icons.child_care_rounded},
  {'type': 'MarriageCertificate', 'issuer': 'did:midas:benin:mairie', 'label': 'Certificat Mariage', 'icon': Icons.favorite_rounded},
  {'type': 'BankAccount', 'issuer': 'did:midas:benin:banque', 'label': 'Compte Bancaire', 'icon': Icons.account_balance_rounded},
  {'type': 'EmploymentAttestation', 'issuer': 'did:midas:benin:employeur', 'label': 'Attestation Emploi', 'icon': Icons.work_rounded},
  {'type': 'ProfessionalCard', 'issuer': 'did:midas:benin:ordre', 'label': 'Carte Professionnelle', 'icon': Icons.badge_rounded},
];

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(walletProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Portefeuille'),
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
              const SizedBox(height: 16),
              _WalletSecurityCard(
                state: state,
                authState: authState,
                theme: theme,
                ref: ref,
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mes Credentials',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.add_rounded, color: Color(0xFF1A1A1A)),
                    onSelected: (type) {
                      final config = _issuerConfigs.firstWhere((c) => c['type'] == type);
                      ref.read(walletProvider.notifier).issueCredential(
                        type: type,
                        issuer: config['issuer'] as String,
                      );
                    },
                    itemBuilder: (_) => _issuerConfigs.map((c) {
                      return PopupMenuItem(
                        value: c['type'] as String,
                        child: ListTile(
                          leading: Icon(c['icon'] as IconData, size: 20),
                          title: Text(c['label'] as String, style: const TextStyle(fontSize: 14)),
                          dense: true,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (state.credentials.isEmpty)
                _buildEmptyState(theme, colorScheme)
              else
                ...state.credentials.map(
                  (vc) => _CredentialCard(
                    vc: vc,
                    theme: theme,
                    colorScheme: colorScheme,
                    onTap: () => _showVcDetail(context, vc, colorScheme, ref),
                  ),
                ),
            ],
          ],
        ),
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
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        children: [
          Icon(Icons.verified_outlined, size: 48,
              color: const Color(0xFFB0B0B0)),
          const SizedBox(height: 12),
          Text(
            'Aucun credential pour le moment',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ajoutez un credential avec le bouton +',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.5),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  void _showVcDetail(BuildContext context, Map<String, dynamic> vc, ColorScheme colorScheme, WidgetRef ref) {
    // Supporte les deux formats : Prisma (type: String) ou JSON-LD (type: List)
    final rawType = vc['type'];
    final type = (rawType is List) ? rawType.join(', ') : (rawType?.toString() ?? 'Credential');
    final issuer = vc['issuer']?.toString() ?? 'Inconnu';
    final vcId = vc['id']?.toString() ?? '';

    final credential = vc['credential'] as Map<String, dynamic>? ?? {};
    final credentialSubject = credential['credentialSubject'] as Map<String, dynamic>? ?? {};
    final issuanceDate = credential['issuanceDate']?.toString() ?? vc['createdAt']?.toString() ?? '—';

    final qrData = jsonEncode({
      'vcId': vcId,
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6D6D6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Chip(
                label: Text(type, style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A1A))),
                backgroundColor: const Color(0xFF8B1A1A).withValues(alpha: 0.08),
                side: BorderSide.none,
              ),
              const SizedBox(height: 20),
              Center(
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF1A1A1A),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Fermer'),
                    ),
                  ),
                  if (vcId.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.qr_code, size: 18),
                        label: const Text('Partager'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (vcId.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      ref.read(walletProvider.notifier).revokeCredential(vcId);
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Révoquer ce credential'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              _detailRow('Émetteur', issuer.toString()),
              _detailRow("Date d'émission", issuanceDate.toString()),
              ...credentialSubject.entries.map((e) =>
                _detailRow(e.key, e.value.toString()),
              ),
              const SizedBox(height: 24),
            ],
          ),
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
              color: Color(0xFF1A1A1A),
            )),
          ),
          Expanded(child: Text(value, style: const TextStyle(color: Color(0xFF1A1A1A)))),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B1A1A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF8B1A1A),
                  size: 24,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'MIDASBJ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            "Carte d'Identité Numérique",
            style: TextStyle(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.4),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            state.npi ?? 'NPI inconnu',
            style: theme.textTheme.titleLarge?.copyWith(
              color: const Color(0xFF1A1A1A),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            state.did ?? 'DID inconnu',
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8E8E8)),
              ),
              child: QrImageView(
                data: state.did ?? 'did:midas:benin:unknown',
                version: QrVersions.auto,
                size: 96,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF1A1A1A),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletSecurityCard extends StatelessWidget {
  final WalletState state;
  final AuthState authState;
  final ThemeData theme;
  final WidgetRef ref;

  const _WalletSecurityCard({
    required this.state,
    required this.authState,
    required this.theme,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          Icon(
            state.isEncrypted ? Icons.lock_rounded : Icons.lock_open_rounded,
            color: state.isEncrypted ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              state.isEncrypted ? 'Wallet chiffré E2E' : 'Wallet non chiffré',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ),
          TextButton(
            onPressed: () => _showEncryptionDialog(context),
            child: Text(
              state.isEncrypted ? 'Gérer' : 'Chiffrer',
              style: const TextStyle(color: Color(0xFF8B1A1A)),
            ),
          ),
        ],
      ),
    );
  }

  void _showEncryptionDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Chiffrement du Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Entrez votre phrase secrète pour dériver la clé de chiffrement.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Phrase secrète',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty && authState.npi != null) {
                final notifier = ref.read(walletProvider.notifier);
                if (state.isEncrypted) {
                  notifier.decryptWallet(authState.npi!, controller.text);
                } else {
                  notifier.encryptWallet(authState.npi!, controller.text);
                }
                Navigator.of(ctx).pop();
              }
            },
            child: Text(state.isEncrypted ? 'Déchiffrer' : 'Chiffrer'),
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
    final rawType = vc['type'];
    final type = (rawType is List) ? rawType.join(', ') : (rawType?.toString() ?? 'Credential');
    final issuer = vc['issuer']?.toString() ?? 'Inconnu';
    final did = vc['id']?.toString() ?? '';
    final issuerIcon = _getIssuerIcon(issuer);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
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
                  color: const Color(0xFF8B1A1A).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  issuerIcon,
                  color: const Color(0xFF8B1A1A),
                  size: 22,
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
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      issuer.toString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF1A1A1A).withValues(alpha: 0.5),
                      ),
                    ),
                    if (did.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        did.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: Color(0xFF1A1A1A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFB0B0B0), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIssuerIcon(String issuer) {
    if (issuer.contains('anip')) return Icons.badge_rounded;
    if (issuer.contains('dgmep')) return Icons.flight_rounded;
    if (issuer.contains('cna')) return Icons.directions_car_rounded;
    if (issuer.contains('cnamu')) return Icons.medical_services_rounded;
    if (issuer.contains('cnss')) return Icons.security_rounded;
    if (issuer.contains('cena')) return Icons.how_to_vote_rounded;
    if (issuer.contains('uac') || issuer.contains('univ')) return Icons.school_rounded;
    if (issuer.contains('mairie')) return Icons.location_city_rounded;
    if (issuer.contains('banque')) return Icons.account_balance_rounded;
    if (issuer.contains('employeur')) return Icons.work_rounded;
    if (issuer.contains('ordre')) return Icons.badge_rounded;
    return Icons.verified_rounded;
  }
}
