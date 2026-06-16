import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../repositories/auth_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_text_field.dart';
import '../../../core/widgets/k_alert.dart';
import '../../../core/widgets/k_section_header.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _pass1Ctrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _success;
  int _step = 1; // 1=email, 2=code+nouveau mdp

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _pass1Ctrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Email requis.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });
    try {
      final repo = AuthRepository();
      await repo.demanderCodeReset(_emailCtrl.text.trim());
      setState(() {
        _success = 'Code envoyé à ${_emailCtrl.text.trim()}';
        _step = 2;
      });
    } catch (e) {
      setState(() => _error = 'Erreur. Vérifiez l\'email.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_pass1Ctrl.text != _pass2Ctrl.text) {
      setState(() => _error = 'Les mots de passe ne correspondent pas.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = AuthRepository();
      await repo.reinitialisation(
        email: _emailCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
        newPassword: _pass1Ctrl.text,
        newPassword2: _pass2Ctrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mot de passe réinitialisé avec succès.'),
          backgroundColor: KColors.success,
        ),
      );
      context.go('/login');
    } catch (e) {
      setState(() => _error = 'Code invalide ou expiré.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: KColors.baseContent),
          onPressed: () => context.pop(),
        ),
        shape: const Border(bottom: BorderSide(color: KColors.border)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(KSpacing.pagePaddingH),
          child: Column(
            children: [
              const SizedBox(height: KSpacing.xxl),

              Image.asset('assets/logos/logo1.png', width: 64, height: 64),
              const SizedBox(height: KSpacing.lg),

              Text(
                _step == 1 ? 'Mot de passe oublié ?' : 'Réinitialisation',
                style: KTextStyles.h2,
              ),
              const SizedBox(height: 4),
              Text(
                _step == 1
                    ? 'Entrez votre email pour recevoir un code'
                    : 'Entrez le code reçu et votre nouveau mot de passe',
                style: KTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: KSpacing.xxl),

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
                  children: [
                    if (_error != null) ...[
                      KAlert(message: _error!, type: KAlertType.error),
                      const SizedBox(height: KSpacing.lg),
                    ],
                    if (_success != null) ...[
                      KAlert(message: _success!, type: KAlertType.success),
                      const SizedBox(height: KSpacing.lg),
                    ],

                    if (_step == 1) ...[
                      KTextField(
                        controller: _emailCtrl,
                        label: 'Email',
                        hint: 'exemple@email.com',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      const SizedBox(height: KSpacing.xl),
                      KButton(
                        label: 'Envoyer le code',
                        isLoading: _loading,
                        onPressed: _loading ? null : _sendCode,
                      ),
                    ] else ...[
                      KTextField(
                        controller: _codeCtrl,
                        label: 'Code de réinitialisation',
                        hint: '123456',
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      const SizedBox(height: KSpacing.lg),
                      KTextField(
                        controller: _pass1Ctrl,
                        label: 'Nouveau mot de passe',
                        hint: '••••••••',
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: KSpacing.lg),
                      KTextField(
                        controller: _pass2Ctrl,
                        label: 'Confirmer le mot de passe',
                        hint: '••••••••',
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: KSpacing.xl),
                      KButton(
                        label: 'Réinitialiser le mot de passe',
                        isLoading: _loading,
                        onPressed: _loading ? null : _resetPassword,
                      ),
                      const SizedBox(height: KSpacing.lg),
                      KButton(
                        label: 'Renvoyer le code',
                        variant: KButtonVariant.ghost,
                        onPressed: () => setState(() {
                          _step = 1;
                          _error = null;
                          _success = null;
                        }),
                      ),
                    ],

                    const SizedBox(height: KSpacing.xl),
                    const KDividerText(text: 'ou'),
                    const SizedBox(height: KSpacing.lg),

                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: Text(
                        'Retour à la connexion',
                        style: KTextStyles.caption.copyWith(
                          color: KColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
