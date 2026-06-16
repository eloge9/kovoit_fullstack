import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_avatar.dart';
import '../../../core/widgets/k_list_tile.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final prefix = (user?.role == 'conducteur') ? '/conducteur' : '/passager';

    if (user == null) {
      return const Scaffold(
        backgroundColor: KColors.base200,
        body: Center(child: CircularProgressIndicator(color: KColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        title: Row(
          children: [
            Image.asset('assets/logos/logo1.png', width: 22, height: 22),
            const SizedBox(width: 8),
            Text(
              'Mon profil',
              style: KTextStyles.bodySm.copyWith(
                fontWeight: FontWeight.w700,
                color: KColors.baseContent,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('$prefix/profile/edit'),
            child: Text(
              'Modifier',
              style: KTextStyles.caption.copyWith(color: KColors.primary),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(KSpacing.pagePaddingH),
        children: [
          const SizedBox(height: KSpacing.lg),

          // ── Avatar + Nom ───────────────────────────────────────────────
          KCard(
            child: Padding(
              padding: const EdgeInsets.all(KSpacing.xl),
              child: Column(
                children: [
                  KAvatar(
                    name: user.displayName,
                    photoUrl: user.photoProfile,
                    size: 72,
                  ),
                  const SizedBox(height: KSpacing.lg),
                  Text(user.displayName, style: KTextStyles.h2),
                  const SizedBox(height: 4),
                  Text(user.email, style: KTextStyles.caption),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: KColors.warning,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${user.note.toStringAsFixed(1)} / 5.0',
                        style: KTextStyles.bodySm.copyWith(
                          color: KColors.baseContent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: KColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          user.role == 'conducteur' ? 'Conducteur' : 'Passager',
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
          ),
          const SizedBox(height: KSpacing.xl),

          // ── Informations ───────────────────────────────────────────────
          KCard(
            child: Column(
              children: [
                const KCardHeader(title: 'Informations personnelles'),
                KDataRow(label: 'Prénom', value: user.firstName ?? '—'),
                const Divider(color: KColors.border, height: 0),
                KDataRow(label: 'Nom', value: user.lastName ?? '—'),
                const Divider(color: KColors.border, height: 0),
                KDataRow(label: 'Email', value: user.email),
                const Divider(color: KColors.border, height: 0),
                KDataRow(label: 'Téléphone', value: user.phoneNumber ?? '—'),
                const Divider(color: KColors.border, height: 0),
                KDataRow(
                  label: 'Rôle',
                  value: _roleLabel(user.role, user.peutConduire),
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpacing.xl),

          // ── Vérification ──────────────────────────────────────────────
          KCard(
            child: Column(
              children: [
                const KCardHeader(title: 'Vérification'),
                KListTile(
                  title: "Documents d'identité",
                  subtitle: _statutLabel(user.statutValidation),
                  leading: Icon(
                    _statutIcon(user.statutValidation),
                    color: _statutColor(user.statutValidation),
                    size: 20,
                  ),
                  titleColor: KColors.baseContent,
                  onTap: () => context.go('$prefix/profile/documents'),
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpacing.xl),

          // ── Navigation ─────────────────────────────────────────────────
          KCard(
            child: Column(
              children: [
                const KCardHeader(title: 'Menu'),
                KListTile(
                  title: 'Mes documents',
                  onTap: () => context.go('$prefix/profile/documents'),
                ),
                const Divider(color: KColors.border, height: 0),
                if (user.role == 'conducteur') ...[
                  KListTile(
                    title: 'Mes véhicules',
                    onTap: () => context.go('/conducteur/vehicules'),
                  ),
                  const Divider(color: KColors.border, height: 0),
                  KListTile(
                    title: 'Vérification du compte',
                    onTap: () => context.go('/conducteur/verification'),
                  ),
                  const Divider(color: KColors.border, height: 0),
                ],
                KListTile(
                  title: 'Modifier le profil',
                  onTap: () => context.go('$prefix/profile/edit'),
                ),
                const Divider(color: KColors.border, height: 0),
                KListTile(
                  title: 'Déconnexion',
                  titleColor: KColors.error,
                  showChevron: false,
                  onTap: () async {
                    await ref.read(authProvider.notifier).deconnexion();
                    if (context.mounted) context.go('/login');
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: KSpacing.xxl),
        ],
      ),
    );
  }

  String _roleLabel(String role, bool peutConduire) {
    if (role == 'conducteur') return 'Conducteur';
    if (peutConduire) return 'Passager / Conducteur';
    return 'Passager';
  }

  IconData _statutIcon(String s) {
    switch (s) {
      case 'valide':
        return Icons.verified_outlined;
      case 'en_attente':
        return Icons.hourglass_empty_outlined;
      case 'rejete':
        return Icons.cancel_outlined;
      default:
        return Icons.upload_file_outlined;
    }
  }

  Color _statutColor(String s) {
    switch (s) {
      case 'valide':
        return KColors.success;
      case 'en_attente':
        return KColors.warning;
      case 'rejete':
        return KColors.error;
      default:
        return KColors.baseContentMid;
    }
  }

  String _statutLabel(String s) {
    switch (s) {
      case 'valide':
        return 'Documents validés ✓';
      case 'en_attente':
        return 'En cours de vérification…';
      case 'rejete':
        return 'Documents rejetés — Renvoyez';
      default:
        return 'Non soumis — Cliquez pour soumettre';
    }
  }
}
