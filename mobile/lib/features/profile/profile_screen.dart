/// Écran Profil / Paramètres.
///
/// Affiche toutes les informations de l'utilisateur connecté :
/// - NPI, DID, ID utilisateur
/// - Mode d'authentification
/// - Rôles
/// - Mode de chiffrement du wallet
/// - Bouton déconnexion
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_provider.dart';
import '../wallet/wallet_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final walletState = ref.watch(walletProvider);
    final theme = Theme.of(context);

    final modeLabels = {
      AuthMode.npi: 'NPI + Ed25519',
      AuthMode.simple: 'NPI simple (dev)',
      AuthMode.keycloak: 'SSO Keycloak',
      AuthMode.biometric: 'Biométrique',
    };

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Profil'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Carte identité
          Container(
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
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFF8B1A1A).withValues(alpha: 0.1),
                  child: const Icon(Icons.person_rounded, size: 40, color: Color(0xFF8B1A1A)),
                ),
                const SizedBox(height: 16),
                Text(
                  authState.npi ?? 'NPI inconnu',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  authState.did ?? 'DID inconnu',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Color(0xFF1A1A1A),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section informations
          _sectionHeader(theme, 'Informations du compte'),
          const SizedBox(height: 12),
          _infoTile('NPI', authState.npi ?? '—', Icons.badge_outlined),
          _infoTile('DID', authState.did ?? '—', Icons.fingerprint),
          _infoTile('ID Utilisateur', authState.userId ?? '—', Icons.tag),
          _infoTile('Mode d\'auth', modeLabels[authState.mode] ?? '—', Icons.lock_outline),
          _infoTile('Rôles', authState.roles.join(', '), Icons.verified_user_outlined),
          _infoTile(
            'Wallet chiffré',
            walletState.isEncrypted ? 'Oui' : 'Non',
            walletState.isEncrypted ? Icons.lock_rounded : Icons.lock_open_rounded,
          ),
          _infoTile(
            'Biométrie',
            authState.biometricEnabled ? 'Active' : 'Inactive',
            Icons.fingerprint,
          ),
          const SizedBox(height: 32),
          // Section actions
          _sectionHeader(theme, 'Actions'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () {
                ref.read(authProvider.notifier).logout();
                context.go('/auth');
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'Se déconnecter',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8B1A1A),
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () {
                ref.read(authProvider.notifier).logout();
                context.go('/auth');
              },
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text(
                'Supprimer le compte local',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1A1A1A).withValues(alpha: 0.5),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF8B1A1A)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
