import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/saved_account.dart';
import '../providers/auth_provider.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/constants/api_constants.dart';

class ContinueAsScreen extends ConsumerStatefulWidget {
  const ContinueAsScreen({super.key});

  @override
  ConsumerState<ContinueAsScreen> createState() => _ContinueAsScreenState();
}

class _ContinueAsScreenState extends ConsumerState<ContinueAsScreen> {
  List<SavedAccount> _accounts = [];
  bool _loading = true;
  String? _loadingAccountId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accounts = await StorageService.getSavedAccounts();
    if (!mounted) return;
    if (accounts.isEmpty) {
      context.go('/login');
      return;
    }
    setState(() {
      _accounts = accounts;
      _loading = false;
    });
  }

  Future<void> _continueAs(SavedAccount account) async {
    setState(() { _error = null; _loadingAccountId = account.id; });

    // Tentative 1 : auto-login avec les credentials Remember Me
    if (account.authProvider == 'email') {
      final saved = await StorageService.getSavedCredentials();
      if (saved != null && saved.email == account.email) {
        final success = await ref.read(authProvider.notifier).connexion(
          email: saved.email,
          password: saved.password,
        );
        if (!mounted) return;
        if (success) {
          _navigateToDashboard();
          return;
        }
        // Identifiants invalides (mot de passe changé) → aller au formulaire
        await StorageService.clearSavedCredentials();
      }
    }

    // Tentative 2 : auto-login Google
    if (account.authProvider == 'google') {
      final success = await ref.read(authProvider.notifier).googleConnexion();
      if (!mounted) return;
      if (success) {
        _navigateToDashboard();
        return;
      }
    }

    // Fallback : formulaire de connexion pré-rempli
    if (!mounted) return;
    setState(() => _loadingAccountId = null);
    ref.read(continueAsAccountProvider.notifier).state = account;
    context.go('/login');
  }

  void _navigateToDashboard() {
    final user = ref.read(authProvider).user;
    if (user?.role == 'conducteur') { context.go('/conducteur'); }
    else if (user?.role == 'admin')  { context.go('/admin'); }
    else                             { context.go('/passager'); }
  }

  void _useAnotherAccount() {
    ref.read(continueAsAccountProvider.notifier).state = null;
    context.go('/login');
  }

  Future<void> _removeAccount(SavedAccount account) async {
    await StorageService.removeAccount(account.id);
    final updated = await StorageService.getSavedAccounts();
    if (!mounted) return;
    if (updated.isEmpty) {
      context.go('/login');
    } else {
      setState(() => _accounts = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: KColors.base200,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: KColors.base200,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: KSpacing.pagePaddingH,
            vertical: KSpacing.xl,
          ),
          child: Column(
            children: [
              const SizedBox(height: KSpacing.xxl),

              // Logo
              Image.asset('assets/logos/logo1.png', width: 72, height: 72),
              const SizedBox(height: KSpacing.xl),

              Text('Bon retour !', style: KTextStyles.h1),
              const SizedBox(height: 4),
              Text(
                'Continuez avec votre compte',
                style: KTextStyles.caption,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: KSpacing.xxl),

              // Erreur éventuelle
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: KColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: KColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _error!,
                    style: KTextStyles.bodySm.copyWith(color: KColors.error),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: KSpacing.md),
              ],

              // Comptes sauvegardés
              ..._accounts.map((account) => Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.md),
                child: _AccountTile(
                  account: account,
                  isPrimary: account == _accounts.first,
                  isLoading: _loadingAccountId == account.id,
                  onTap: _loadingAccountId != null ? null : () => _continueAs(account),
                  onRemove: _loadingAccountId != null ? () {} : () => _removeAccount(account),
                ),
              )),

              const SizedBox(height: KSpacing.xl),

              // Autre compte
              OutlinedButton.icon(
                onPressed: _useAnotherAccount,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: KColors.border),
                ),
                icon: const Icon(Icons.person_add_outlined, size: 20),
                label: const Text('Utiliser un autre compte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final SavedAccount account;
  final bool isPrimary;
  final bool isLoading;
  final VoidCallback? onTap;
  final VoidCallback onRemove;

  const _AccountTile({
    required this.account,
    required this.isPrimary,
    required this.isLoading,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KColors.base100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPrimary ? KColors.primary.withValues(alpha: 0.4) : KColors.border,
          width: isPrimary ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: KColors.neutral.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.cardPadding,
              vertical: 16,
            ),
            child: Row(
              children: [
                // Avatar
                _Avatar(account: account),
                const SizedBox(width: KSpacing.md),

                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.displayName,
                        style: KTextStyles.bodyLg
                            .copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        account.email,
                        style: KTextStyles.bodySm
                            .copyWith(color: KColors.baseContentMid),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      _RoleBadge(role: account.role, provider: account.authProvider),
                    ],
                  ),
                ),

                // Spinner de chargement ou flèche + supprimer
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: KColors.baseContentMid,
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: onRemove,
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: KColors.baseContentLow,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final SavedAccount account;
  const _Avatar({required this.account});

  @override
  Widget build(BuildContext context) {
    final photoUrl = account.photoUrl;
    final absoluteUrl = (photoUrl != null && photoUrl.isNotEmpty)
        ? ApiConstants.buildMediaUrl(photoUrl)
        : null;

    return CircleAvatar(
      radius: 28,
      backgroundColor: KColors.primaryLight,
      backgroundImage:
          (absoluteUrl != null && absoluteUrl.isNotEmpty)
              ? NetworkImage(absoluteUrl)
              : null,
      child: (absoluteUrl == null || absoluteUrl.isEmpty)
          ? Text(
              account.displayName.isNotEmpty
                  ? account.displayName[0].toUpperCase()
                  : '?',
              style: KTextStyles.h2.copyWith(color: KColors.primary),
            )
          : null,
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  final String provider;
  const _RoleBadge({required this.role, required this.provider});

  @override
  Widget build(BuildContext context) {
    final roleLabel = switch (role) {
      'conducteur' => 'Conducteur',
      'admin'      => 'Admin',
      _            => 'Passager',
    };

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: KColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            roleLabel,
            style: KTextStyles.caption.copyWith(
              color: KColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (provider == 'google') ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF4285F4).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Google',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF4285F4),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
