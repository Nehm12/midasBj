/// Écran Profil / Paramètres.
///
/// Affiche toutes les informations de l'utilisateur connecté :
/// - Prénom, Nom, NPI, DID, ID utilisateur
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

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authProvider);
    _firstNameController = TextEditingController(text: authState.firstName ?? '');
    _lastNameController = TextEditingController(text: authState.lastName ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  _getDisplayName(authState),
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

          // Section informations personnelles
          _sectionHeader(theme, 'Informations personnelles'),
          const SizedBox(height: 12),
          _editableTile(
            'Prénom',
            TextEditingController(text: authState.firstName ?? '—'),
            Icons.person_outline,
            isEditing: _isEditing,
            editController: _firstNameController,
          ),
          _editableTile(
            'Nom',
            TextEditingController(text: authState.lastName ?? '—'),
            Icons.person_outline,
            isEditing: _isEditing,
            editController: _lastNameController,
          ),
          if (_isEditing) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton.icon(
                onPressed: () async {
                  await ref.read(authProvider.notifier).updateProfile(
                    firstName: _firstNameController.text.isNotEmpty ? _firstNameController.text : null,
                    lastName: _lastNameController.text.isNotEmpty ? _lastNameController.text : null,
                  );
                  setState(() => _isEditing = false);
                },
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Enregistrer', style: TextStyle(fontSize: 14)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B1A1A),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _isEditing = true;
                    _firstNameController.text = authState.firstName ?? '';
                    _lastNameController.text = authState.lastName ?? '';
                  });
                },
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Modifier le profil', style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Section compte
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
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.fingerprint, size: 20, color: Color(0xFF8B1A1A)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Biométrie',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        authState.biometricEnabled ? 'Active' : 'Inactive',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: authState.biometricEnabled,
                  activeColor: const Color(0xFF8B1A1A),
                  onChanged: (_) async {
                    try {
                      await ref.read(authProvider.notifier).toggleBiometric();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: Theme.of(context).colorScheme.error,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
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

  String _getDisplayName(AuthState authState) {
    final parts = [authState.firstName, authState.lastName].where((s) => s != null && s.isNotEmpty);
    if (parts.isNotEmpty) return parts.join(' ');
    return authState.npi ?? 'NPI inconnu';
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

  Widget _editableTile(String label, TextEditingController controller, IconData icon, {required bool isEditing, TextEditingController? editController}) {
    if (isEditing && editController != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: editController,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFF8B1A1A)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      );
    }
    return _infoTile(label, controller.text, icon);
  }
}
