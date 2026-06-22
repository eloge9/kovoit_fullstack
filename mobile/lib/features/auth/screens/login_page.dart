import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_text_field.dart';
import '../../../core/widgets/k_alert.dart';
import '../../../core/widgets/k_section_header.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);

    final success = await ref
        .read(authProvider.notifier)
        .connexion(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);

    if (!mounted) return;

    if (success) {
      final user = ref.read(authProvider).user;
      if (user?.role == 'conducteur') {
        context.go('/conducteur');
      } else if (user?.role == 'admin') {
        context.go('/admin');
      } else {
        context.go('/passager');
      }
    } else {
      setState(() {
        _error =
            ref.read(authProvider).error ?? 'Email ou mot de passe incorrect.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      backgroundColor: KColors.base200,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: KSpacing.pagePaddingH,
            vertical: KSpacing.xl,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: KSpacing.xxl),

                // ── Logo + Titre (identique au Web) ────────────────────────
                Column(
                  children: [
                    Image.asset(
                      'assets/logos/logo1.png',
                      width: 80,
                      height: 80,
                    ),
                    const SizedBox(height: KSpacing.lg),
                    Text('Bon retour !', style: KTextStyles.h1),
                    const SizedBox(height: 4),
                    Text(
                      'Connectez-vous à votre compte',
                      style: KTextStyles.caption,
                    ),
                  ],
                ),

                const SizedBox(height: KSpacing.xxl),

                // ── Card (identique au Web) ─────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: KColors.base100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: KColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: KColors.neutral.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(KSpacing.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Erreur
                      if (_error != null) ...[
                        KAlert(message: _error!, type: KAlertType.error),
                        const SizedBox(height: KSpacing.lg),
                      ],

                      // Email
                      KTextField(
                        controller: _emailCtrl,
                        label: 'Email',
                        hint: 'exemple@email.com',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        prefixIcon: const Icon(Icons.email_outlined),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Email requis';
                          if (!v.contains('@')) return 'Email invalide';
                          return null;
                        },
                      ),
                      const SizedBox(height: KSpacing.lg),

                      // Mot de passe + lien oublié
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Mot de passe',
                                style: KTextStyles.bodySm.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => context.push('/forgot-password'),
                                child: Text(
                                  'Mot de passe oublié ?',
                                  style: KTextStyles.caption.copyWith(
                                    color: KColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Mot de passe requis';
                              }
                              return null;
                            },
                            style: KTextStyles.bodyLg,
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: KColors.baseContentMid,
                                  size: 18,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: KSpacing.xl),

                      // Bouton connexion
                      KButton(
                        label: 'Se connecter',
                        onPressed: isLoading ? null : _submit,
                        isLoading: isLoading,
                      ),
                      const SizedBox(height: KSpacing.xl),

                      // Divider
                      const KDividerText(text: 'ou'),
                      const SizedBox(height: KSpacing.lg),

                      // Lien inscription
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Pas encore de compte ? ",
                            style: KTextStyles.caption,
                          ),
                          GestureDetector(
                            onTap: () => context.push('/register'),
                            child: Text(
                              "S'inscrire",
                              style: KTextStyles.caption.copyWith(
                                color: KColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Accès aux paramètres serveur (utile en dev)
                const SizedBox(height: KSpacing.lg),
                GestureDetector(
                  onTap: () => context.push('/server-settings'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.settings_ethernet_rounded,
                        size: 14,
                        color: KColors.baseContentLow,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Paramètres du serveur',
                        style: KTextStyles.caption.copyWith(
                          color: KColors.baseContentLow,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
