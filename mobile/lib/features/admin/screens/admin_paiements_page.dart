import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_badge.dart';
import '../../../core/widgets/k_empty_state.dart';

final _adminPaiementsProvider = FutureProvider<List<dynamic>>((ref) async {
  try {
    final res = await DioClient.get('/paiements/admin/');
    final data = res.data;
    debugPrint('[AdminPaiements] /paiements/admin/ raw type: ${data.runtimeType}');
    if (data is List) {
      debugPrint('[AdminPaiements] ${data.length} paiements');
      return data;
    }
    if (data is Map && data['results'] is List) return data['results'] as List;
    return [];
  } catch (e) {
    debugPrint('[AdminPaiements] /paiements/admin/ error: $e');
    try {
      final res = await DioClient.get('/paiements/mes_paiements/');
      final data = res.data;
      if (data is List) return data;
      if (data is Map && data['results'] is List) return data['results'] as List;
    } catch (e2) {
      debugPrint('[AdminPaiements] fallback error: $e2');
    }
    return [];
  }
});

class AdminPaiementsPage extends ConsumerWidget {
  const AdminPaiementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paiementsAsync = ref.watch(_adminPaiementsProvider);

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        title: Text(
          'Paiements',
          style: KTextStyles.bodySm.copyWith(
            fontWeight: FontWeight.w700,
            color: KColors.baseContent,
          ),
        ),
      ),
      body: paiementsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: KColors.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: KColors.baseContentLow,
              ),
              const SizedBox(height: 8),
              Text(e.toString(), style: KTextStyles.caption),
              TextButton(
                onPressed: () => ref.refresh(_adminPaiementsProvider),
                child: Text(
                  'Réessayer',
                  style: KTextStyles.bodySm.copyWith(color: KColors.primary),
                ),
              ),
            ],
          ),
        ),
        data: (paiements) {
          if (paiements.isEmpty) {
            return const KEmptyState(
              emoji: '💳',
              message: 'Aucun paiement trouvé',
            );
          }

          final totalFCFA = paiements.fold<double>(0, (sum, p) {
            final m = (p as Map<String, dynamic>)['montant'];
            return sum + (m is num ? m.toDouble() : 0);
          });

          return RefreshIndicator(
            color: KColors.primary,
            onRefresh: () async => ref.refresh(_adminPaiementsProvider),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    color: KColors.base100,
                    padding: const EdgeInsets.all(KSpacing.xl),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'Total reçu',
                            value: '${totalFCFA.toStringAsFixed(0)} FCFA',
                            icon: Icons.account_balance_wallet_outlined,
                            color: KColors.success,
                          ),
                        ),
                        const SizedBox(width: KSpacing.md),
                        Expanded(
                          child: _StatCard(
                            label: 'Transactions',
                            value: '${paiements.length}',
                            icon: Icons.receipt_long_outlined,
                            color: KColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: KSpacing.lg)),
                SliverList(
                  delegate: SliverChildBuilderDelegate((ctx, i) {
                    final p = paiements[i] as Map<String, dynamic>;
                    final montant = p['montant']?.toString() ?? '0';
                    final methode =
                        p['methode']?.toString() ??
                        p['mode_paiement']?.toString() ??
                        'ESPECE';
                    final statut = p['statut']?.toString() ?? 'en_attente';
                    final date =
                        p['created_at']?.toString().substring(0, 10) ??
                        p['date']?.toString() ??
                        '';
                    final ref_ =
                        p['reference']?.toString() ??
                        p['transaction_id']?.toString() ??
                        '#${p['id']}';

                    final methodeIcon = methode == 'FLOOZ'
                        ? Icons.phone_android   // Moov Flooz
                        : methode == 'YAS'
                        ? Icons.sim_card_outlined // Mixx by Yas
                        : Icons.money_outlined;   // Espèces

                    return Container(
                      color: KColors.base100,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: KSpacing.pagePaddingH,
                              vertical: KSpacing.md,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: KColors.statusBgColor(statut),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    methodeIcon,
                                    color: KColors.statusColor(statut),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: KSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '$montant FCFA',
                                              style: KTextStyles.bodySm
                                                  .copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                          KBadge.fromStatut(statut),
                                        ],
                                      ),
                                      Text(
                                        '$methode • $ref_',
                                        style: KTextStyles.caption,
                                      ),
                                      if (date.isNotEmpty)
                                        Text(date, style: KTextStyles.meta),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(
                            color: KColors.border,
                            height: 0,
                            indent: 68,
                          ),
                        ],
                      ),
                    );
                  }, childCount: paiements.length),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: KSpacing.sm),
          Text(value, style: KTextStyles.h3.copyWith(color: color)),
          Text(label, style: KTextStyles.caption),
        ],
      ),
    );
  }
}
