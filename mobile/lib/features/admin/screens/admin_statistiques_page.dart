import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_empty_state.dart';

final _statsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await DioClient.get('/verification/admin/drivers/stats/');
  final data = res.data;
  if (data is Map<String, dynamic>) return data;
  return {};
});

final _resumeProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final res = await DioClient.get('/statistiques/globales/');
    debugPrint('[AdminStats] globales raw: ${res.data}');
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    return {};
  } catch (e) {
    debugPrint('[AdminStats] globales error: $e');
    return {};
  }
});

class AdminStatistiquesPage extends ConsumerWidget {
  const AdminStatistiquesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_statsProvider);
    final resumeAsync = ref.watch(_resumeProvider);

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        title: Text('Statistiques', style: KTextStyles.bodySm.copyWith(
          fontWeight: FontWeight.w700, color: KColors.baseContent,
        )),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: KColors.baseContentMid, size: 20),
            onPressed: () {
              ref.invalidate(_statsProvider);
              ref.invalidate(_resumeProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: KColors.primary,
        onRefresh: () async {
          ref.invalidate(_statsProvider);
          ref.invalidate(_resumeProvider);
        },
        child: statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: KColors.primary)),
          error: (e, _) => Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.error_outline, size: 48, color: KColors.baseContentLow),
              const SizedBox(height: 8),
              Text(e.toString(), style: KTextStyles.caption),
              TextButton(
                onPressed: () => ref.refresh(_statsProvider),
                child: Text('Réessayer', style: KTextStyles.bodySm.copyWith(color: KColors.primary)),
              ),
            ]),
          ),
          data: (stats) {
            if (stats.isEmpty) {
              return const KEmptyState(emoji: '📊', message: 'Aucune statistique disponible');
            }

            final total = (stats['total'] as num?)?.toInt() ?? 0;
            final actifs = (stats['approved'] as num?)?.toInt()
                ?? (stats['actifs'] as num?)?.toInt() ?? 0;
            final enAttente = (stats['pending'] as num?)?.toInt()
                ?? (stats['en_attente'] as num?)?.toInt() ?? 0;
            final rejetes = (stats['rejected'] as num?)?.toInt()
                ?? (stats['rejetes'] as num?)?.toInt() ?? 0;
            final suspendus = (stats['suspended'] as num?)?.toInt()
                ?? (stats['suspendus'] as num?)?.toInt() ?? 0;

            final resume = resumeAsync.maybeWhen(
              data: (d) => d,
              orElse: () => <String, dynamic>{},
            );

            return ListView(
              padding: const EdgeInsets.all(KSpacing.pagePaddingH),
              children: [
                Text('Vue d\'ensemble conducteurs',
                    style: KTextStyles.label.copyWith(letterSpacing: 1.2)),
                const SizedBox(height: KSpacing.md),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: KSpacing.md,
                  mainAxisSpacing: KSpacing.md,
                  childAspectRatio: 1.5,
                  children: [
                    _StatCard(
                      label: 'Total conducteurs',
                      value: total.toString(),
                      icon: Icons.drive_eta_outlined,
                      color: KColors.primary,
                    ),
                    _StatCard(
                      label: 'Actifs',
                      value: actifs.toString(),
                      icon: Icons.check_circle_outline,
                      color: KColors.successContent,
                    ),
                    _StatCard(
                      label: 'En attente',
                      value: enAttente.toString(),
                      icon: Icons.hourglass_empty_outlined,
                      color: KColors.warningContent,
                    ),
                    _StatCard(
                      label: 'Rejetés',
                      value: rejetes.toString(),
                      icon: Icons.cancel_outlined,
                      color: KColors.error,
                    ),
                  ],
                ),

                const SizedBox(height: KSpacing.xl),

                if (total > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(KSpacing.xl),
                    decoration: BoxDecoration(
                      color: KColors.base100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: KColors.border),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Répartition conducteurs', style: KTextStyles.bodySm.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
                      const SizedBox(height: KSpacing.xl),
                      SizedBox(
                        height: 180,
                        child: PieChart(
                          PieChartData(
                            sections: [
                              if (actifs > 0) PieChartSectionData(
                                value: actifs.toDouble(),
                                color: KColors.successContent,
                                title: 'Actifs\n$actifs',
                                radius: 70,
                                titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                              if (enAttente > 0) PieChartSectionData(
                                value: enAttente.toDouble(),
                                color: KColors.warningContent,
                                title: 'Attente\n$enAttente',
                                radius: 70,
                                titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                              if (rejetes > 0) PieChartSectionData(
                                value: rejetes.toDouble(),
                                color: KColors.error,
                                title: 'Rejetés\n$rejetes',
                                radius: 70,
                                titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                              if (suspendus > 0) PieChartSectionData(
                                value: suspendus.toDouble(),
                                color: KColors.baseContentMid,
                                title: 'Suspendus\n$suspendus',
                                radius: 70,
                                titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ],
                            sectionsSpace: 3,
                            centerSpaceRadius: 30,
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: KSpacing.lg),
                ],

                if (resume.isNotEmpty) ...[
                  Text('Activité globale', style: KTextStyles.label.copyWith(letterSpacing: 1.2)),
                  const SizedBox(height: KSpacing.md),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: KSpacing.md,
                    mainAxisSpacing: KSpacing.md,
                    childAspectRatio: 1.5,
                    children: [
                      if (resume['total_utilisateurs'] != null)
                        _StatCard(
                          label: 'Utilisateurs',
                          value: resume['total_utilisateurs'].toString(),
                          icon: Icons.people_outlined,
                          color: KColors.secondary,
                        ),
                      if (resume['total_trajets'] != null)
                        _StatCard(
                          label: 'Trajets',
                          value: resume['total_trajets'].toString(),
                          icon: Icons.route_outlined,
                          color: KColors.primary,
                        ),
                      if (resume['total_reservations'] != null)
                        _StatCard(
                          label: 'Réservations',
                          value: resume['total_reservations'].toString(),
                          icon: Icons.confirmation_number_outlined,
                          color: KColors.accent,
                        ),
                      if (resume['total_revenus'] != null)
                        _StatCard(
                          label: 'Revenus (FCFA)',
                          value: resume['total_revenus'].toString(),
                          icon: Icons.account_balance_wallet_outlined,
                          color: KColors.successContent,
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: KSpacing.xl),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: KColors.base100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const Spacer(),
          ]),
          const SizedBox(height: KSpacing.sm),
          Text(value, style: KTextStyles.statValue.copyWith(fontSize: 22, color: color)),
          Text(label, style: KTextStyles.caption, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
