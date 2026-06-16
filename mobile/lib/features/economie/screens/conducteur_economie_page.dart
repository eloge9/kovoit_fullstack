import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';

final _conducteurEconomieProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final statsRes = await DioClient.get('/statistiques/conducteur/');
    final ecoRes   = await DioClient.get('/economie/mes_economies/');
    return {
      'stats': statsRes.data is Map ? Map<String, dynamic>.from(statsRes.data as Map) : {},
      'economies': ecoRes.data,
    };
  } catch (_) {
    return {'stats': {}, 'economies': null};
  }
});

class ConducteurEconomiePage extends ConsumerWidget {
  const ConducteurEconomiePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_conducteurEconomieProvider);

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        title: Row(children: [
          Image.asset('assets/logos/logo1.png', width: 22, height: 22),
          const SizedBox(width: 8),
          Text('Revenus & Économies', style: KTextStyles.bodySm.copyWith(
            fontWeight: FontWeight.w700, color: KColors.baseContent,
          )),
        ]),
      ),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: KColors.primary)),
        error: (e, _) => KEmptyState(
          icon: Icons.error_outline,
          message: 'Impossible de charger les statistiques',
          actionLabel: 'Réessayer',
          onAction: () => ref.refresh(_conducteurEconomieProvider),
        ),
        data: (data) {
          final stats = data['stats'] as Map<String, dynamic>;
          final totalRevenus = _num(stats, ['total_revenus', 'revenus_total', 'montant_total']);
          final nombreTrajets = _num(stats, ['nombre_trajets', 'total_trajets', 'trajets_completes']);
          final noteMoyenne = _double(stats, ['note_moyenne', 'note']);
          final tauxAcceptation = _double(stats, ['taux_acceptation', 'taux']);

          final parMois = _extractParMois(stats);

          return RefreshIndicator(
            color: KColors.primary,
            onRefresh: () async => ref.refresh(_conducteurEconomieProvider),
            child: ListView(
              padding: const EdgeInsets.all(KSpacing.pagePaddingH),
              children: [
                const SizedBox(height: KSpacing.lg),

                // ── Header stats ──────────────────────────────────────────
                KCard(
                  child: Padding(
                    padding: const EdgeInsets.all(KSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('REVENUS TOTAUX', style: KTextStyles.label),
                        const SizedBox(height: 4),
                        Text(
                          '${totalRevenus.toStringAsFixed(0)} FCFA',
                          style: KTextStyles.statValue.copyWith(
                            color: KColors.success, fontSize: 32,
                          ),
                        ),
                        const SizedBox(height: KSpacing.xl),
                        const Divider(color: KColors.border),
                        const SizedBox(height: KSpacing.lg),
                        Row(children: [
                          _MiniStat(
                            label: 'Trajets effectués',
                            value: nombreTrajets.toInt().toString(),
                            icon: Icons.route_outlined,
                            color: KColors.primary,
                          ),
                          const SizedBox(width: KSpacing.lg),
                          _MiniStat(
                            label: 'Note moyenne',
                            value: '${noteMoyenne.toStringAsFixed(1)} ★',
                            icon: Icons.star_outline,
                            color: KColors.warning,
                          ),
                          const SizedBox(width: KSpacing.lg),
                          _MiniStat(
                            label: 'Taux acceptation',
                            value: '${tauxAcceptation.toStringAsFixed(0)}%',
                            icon: Icons.check_circle_outline,
                            color: KColors.success,
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: KSpacing.xl),

                // ── Graphique mensuel ─────────────────────────────────────
                if (parMois.isNotEmpty) ...[
                  KCard(
                    child: Padding(
                      padding: const EdgeInsets.all(KSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('REVENUS PAR MOIS', style: KTextStyles.label),
                          const SizedBox(height: KSpacing.xl),
                          SizedBox(
                            height: 180,
                            child: _RevenusChart(parMois: parMois),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: KSpacing.xl),
                ],

                // ── Détails stats ─────────────────────────────────────────
                KCard(
                  child: Column(children: [
                    const KCardHeader(title: 'Statistiques détaillées'),
                    KDataRow(
                      label: 'Revenus ce mois',
                      value: '${_num(stats, ['revenus_mois', 'revenus_ce_mois']).toStringAsFixed(0)} FCFA',
                    ),
                    const Divider(color: KColors.border, height: 0),
                    KDataRow(
                      label: 'Passagers transportés',
                      value: _num(stats, ['total_passagers', 'passagers']).toInt().toString(),
                    ),
                    const Divider(color: KColors.border, height: 0),
                    KDataRow(
                      label: 'Distance parcourue',
                      value: '${_num(stats, ['distance_totale', 'km_total']).toStringAsFixed(0)} km',
                    ),
                    const Divider(color: KColors.border, height: 0),
                    KDataRow(
                      label: 'Revenu moyen / trajet',
                      value: nombreTrajets > 0
                          ? '${(totalRevenus / nombreTrajets).toStringAsFixed(0)} FCFA'
                          : '—',
                    ),
                  ]),
                ),
                const SizedBox(height: KSpacing.xxl),
              ],
            ),
          );
        },
      ),
    );
  }

  double _num(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k) && m[k] != null) {
        return (m[k] as num).toDouble();
      }
    }
    return 0;
  }

  double _double(Map<String, dynamic> m, List<String> keys) => _num(m, keys);

  List<MapEntry<String, double>> _extractParMois(Map<String, dynamic> stats) {
    for (final k in ['revenus_par_mois', 'par_mois', 'monthly']) {
      if (stats[k] is Map) {
        final map = stats[k] as Map;
        return map.entries
            .map((e) => MapEntry(e.key.toString(),
                (e.value as num).toDouble()))
            .toList();
      }
      if (stats[k] is List) {
        final list = stats[k] as List;
        return list.asMap().entries.map((e) =>
            MapEntry('M${e.key + 1}', (e.value as num).toDouble()))
            .toList();
      }
    }
    return [];
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label, required this.value,
    required this.icon, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 4),
      Text(value, style: KTextStyles.bodySm.copyWith(
          fontWeight: FontWeight.w700, color: color)),
      Text(label, style: KTextStyles.meta,
          textAlign: TextAlign.center, maxLines: 2),
    ]));
  }
}

class _RevenusChart extends StatelessWidget {
  final List<MapEntry<String, double>> parMois;
  const _RevenusChart({required this.parMois});

  @override
  Widget build(BuildContext context) {
    final maxVal = parMois.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxVal * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: KColors.border, strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, _) {
                final i = val.toInt();
                if (i < 0 || i >= parMois.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    parMois[i].key,
                    style: KTextStyles.meta.copyWith(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: parMois.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.value,
                color: KColors.primary,
                width: 18,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
