import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_list_tile.dart';
import '../../../features/auth/providers/auth_provider.dart';

class AdminSettingsPage extends ConsumerWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        title: Text(
          'Paramètres',
          style: KTextStyles.bodySm.copyWith(
            fontWeight: FontWeight.w700,
            color: KColors.baseContent,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 16),

          // Profil admin
          KCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: KColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: KColors.error,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'Administrateur',
                          style: KTextStyles.h3,
                        ),
                        Text(user?.email ?? '', style: KTextStyles.caption),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: KColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'ADMIN',
                            style: KTextStyles.caption.copyWith(
                              color: KColors.error,
                              fontWeight: FontWeight.w700,
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
          const SizedBox(height: 24),

          KCard(
            child: Column(
              children: [
                const KCardHeader(title: 'Application'),
                KListTile(title: 'Statistiques globales', onTap: () {}),
                const Divider(color: KColors.border, height: 0),
                KListTile(
                  title: 'Journal d\'audit',
                  onTap: () => context.go('/admin/audit'),
                ),
                const Divider(color: KColors.border, height: 0),
                KListTile(title: 'Paramètres système', onTap: () {}),
              ],
            ),
          ),
          const SizedBox(height: 24),

          KCard(
            child: Column(
              children: [
                const KCardHeader(title: 'Compte'),
                KListTile(
                  title: 'Se déconnecter',
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
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
