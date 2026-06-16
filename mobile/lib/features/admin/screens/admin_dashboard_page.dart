import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_list_tile.dart';
import '../../../features/auth/providers/auth_provider.dart';

final _adminStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final res = await DioClient.get('/utilisateurs/admin/stats/');
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
  } catch (_) {}
  try {
    final res = await DioClient.get('/statistiques/resume/');
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
  } catch (_) {}
  return {};
});

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_adminStatsProvider);
    final user = ref.watch(currentUserProvider);

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
              'Administration',
              style: KTextStyles.bodySm.copyWith(
                fontWeight: FontWeight.w700,
                color: KColors.baseContent,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          ),
        ],
      ),
      body: RefreshIndicator(
        color: KColors.primary,
        onRefresh: () async => ref.refresh(_adminStatsProvider),
        child: ListView(
          padding: const EdgeInsets.all(KSpacing.pagePaddingH),
          children: [
            const SizedBox(height: KSpacing.lg),

            // ── Bienvenue ─────────────────────────────────────────────────
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.xl),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: KColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: KColors.primary,
                      ),
                    ),
                    const SizedBox(width: KSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bienvenue, ${user?.displayName ?? 'Admin'}',
                            style: KTextStyles.h3,
                          ),
                          Text(
                            'Tableau de bord administrateur',
                            style: KTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: KSpacing.xl),

            // ── Stats ─────────────────────────────────────────────────────
            statsAsync.when(
              loading: () => GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: KSpacing.md,
                crossAxisSpacing: KSpacing.md,
                childAspectRatio: 1.4,
                children: List.generate(4, (_) => const KSkeleton(height: 80)),
              ),
              error: (_, _) => const SizedBox.shrink(),
              data: (stats) => GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: KSpacing.md,
                crossAxisSpacing: KSpacing.md,
                childAspectRatio: 1.4,
                children: [
                  _AdminStatCard(
                    label: 'Utilisateurs',
                    value: _str(stats, ['total_utilisateurs', 'utilisateurs']),
                    icon: Icons.people_outline,
                    color: KColors.primary,
                    onTap: () => context.go('/admin/utilisateurs'),
                  ),
                  _AdminStatCard(
                    label: 'Conducteurs',
                    value: _str(stats, ['total_conducteurs', 'conducteurs']),
                    icon: Icons.drive_eta_outlined,
                    color: KColors.info,
                    onTap: () => context.go('/admin/conducteurs'),
                  ),
                  _AdminStatCard(
                    label: 'Trajets',
                    value: _str(stats, ['total_trajets', 'trajets']),
                    icon: Icons.route_outlined,
                    color: KColors.success,
                  ),
                  _AdminStatCard(
                    label: 'Revenus',
                    value: _strRevenu(stats),
                    icon: Icons.payments_outlined,
                    color: KColors.warning,
                  ),
                ],
              ),
            ),
            const SizedBox(height: KSpacing.xl),

            // ── Actions rapides ───────────────────────────────────────────
            KCard(
              child: Column(
                children: [
                  const KCardHeader(title: 'Actions rapides'),
                  KListTile(
                    title: 'Gérer les utilisateurs',
                    leading: const Icon(
                      Icons.manage_accounts_outlined,
                      color: KColors.primary,
                      size: 20,
                    ),
                    onTap: () => context.go('/admin/utilisateurs'),
                  ),
                  const Divider(color: KColors.border, height: 0),
                  KListTile(
                    title: 'Vérifier les conducteurs',
                    leading: const Icon(
                      Icons.verified_user_outlined,
                      color: KColors.info,
                      size: 20,
                    ),
                    onTap: () => context.go('/admin/conducteurs'),
                  ),
                  const Divider(color: KColors.border, height: 0),
                  KListTile(
                    title: 'Voir les trajets',
                    leading: const Icon(
                      Icons.route_outlined,
                      color: KColors.success,
                      size: 20,
                    ),
                    onTap: () => context.go('/admin/trajets'),
                  ),
                  const Divider(color: KColors.border, height: 0),
                  KListTile(
                    title: 'Journal d\'audit',
                    leading: const Icon(
                      Icons.history_outlined,
                      color: KColors.baseContentMid,
                      size: 20,
                    ),
                    onTap: () => context.go('/admin/audit'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KSpacing.xl),

            // ── Se déconnecter ────────────────────────────────────────────
            KButton(
              label: 'Se déconnecter',
              variant: KButtonVariant.outline,
              onPressed: () async {
                await ref.read(authProvider.notifier).deconnexion();
                if (context.mounted) context.go('/login');
              },
            ),
            const SizedBox(height: KSpacing.xxl),
          ],
        ),
      ),
    );
  }

  String _str(Map<String, dynamic> stats, List<String> keys) {
    for (final k in keys) {
      if (stats.containsKey(k)) return stats[k].toString();
    }
    return '—';
  }

  String _strRevenu(Map<String, dynamic> stats) {
    for (final k in ['total_revenus', 'revenus', 'chiffre_affaires']) {
      if (stats.containsKey(k)) {
        final v = stats[k];
        if (v is num) return '${v.toStringAsFixed(0)} FCFA';
        return v.toString();
      }
    }
    return '—';
  }
}

class _AdminStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _AdminStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              Text(value, style: KTextStyles.statValue.copyWith(color: color)),
              Text(label, style: KTextStyles.caption),
            ],
          ),
        ),
      ),
    );
  }
}
