/// Interface d'authentification.
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go('/wallet');
      }
      if (next.error != null && next.error!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B1A1A).withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      size: 56,
                      color: Color(0xFF8B1A1A),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'MIDASBJ',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1A1A),
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Identité Numérique Souveraine',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Gérez votre identité, vos consentements\net vos appareils connectés',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF1A1A1A).withValues(alpha: 0.5),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 56),
                  if (authState.status == AuthStatus.authenticating)
                    Column(
                      children: [
                        const CircularProgressIndicator(color: Color(0xFF8B1A1A)),
                        const SizedBox(height: 16),
                        Text(
                          'Opération en cours...',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () => _showNpiDialog(context, ref, 'enroll'),
                        icon: const Icon(Icons.person_add_rounded, size: 20),
                        label: const Text(
                          "S'enrôler avec mon NPI",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => _showNpiDialog(context, ref, 'login'),
                        icon: const Icon(Icons.login_rounded, size: 20),
                        label: const Text(
                          'Se connecter (NPI + signature)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/auth/keycloak'),
                        icon: const Icon(Icons.admin_panel_settings_outlined, size: 20),
                        label: const Text(
                          'SSO Keycloak',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    if (authState.biometricAvailable) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () => _biometricLogin(context, ref),
                          icon: Icon(
                            authState.biometricEnabled
                                ? Icons.fingerprint
                                : Icons.fingerprint_outlined,
                            size: 20,
                          ),
                          label: Text(
                            authState.biometricEnabled
                                ? 'Deverrouillage biometrique'
                                : 'Activer biométrie',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _biometricLogin(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(authProvider.notifier);
    final ok = await notifier.loginWithBiometric();
    if (ok && context.mounted) {
      context.go('/wallet');
    } else if (!ok && context.mounted) {
      final error = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Échec de l\'authentification biométrique'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showNpiDialog(BuildContext context, WidgetRef ref, String mode) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              mode == 'enroll' ? Icons.person_add_rounded : Icons.login_rounded,
              color: const Color(0xFF8B1A1A),
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              mode == 'enroll' ? 'Saisir votre NPI' : 'Connexion',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: Color(0xFF1A1A1A)),
          decoration: InputDecoration(
            labelText: 'Numéro NPI',
            hintText: 'NPIBENIN2024...',
            labelStyle: const TextStyle(color: Color(0xFF1A1A1A)),
            hintStyle: TextStyle(color: const Color(0xFF1A1A1A).withValues(alpha: 0.4)),
            prefixIcon: const Icon(Icons.badge_outlined, size: 20, color: Color(0xFF1A1A1A)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD6D6D6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD6D6D6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1A1A1A)),
            ),
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
          ),
          cursorColor: const Color(0xFF1A1A1A),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.of(ctx).pop();
              _handleAuth(ref, mode, value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Annuler',
              style: TextStyle(color: const Color(0xFF1A1A1A).withValues(alpha: 0.6))),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.of(ctx).pop();
                _handleAuth(ref, mode, value);
              }
            },
            child: Text(mode == 'enroll' ? 'Enrôler' : 'Connecter'),
          ),
        ],
      ),
    );
  }

  void _handleAuth(WidgetRef ref, String mode, String npi) {
    if (_submitting) return;
    _submitting = true;
    final notifier = ref.read(authProvider.notifier);
    switch (mode) {
      case 'enroll':
        notifier.register(npi);
        break;
      case 'login':
        notifier.login(npi);
        break;
      default:
        break;
    }
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _submitting = false);
    });
  }
}
