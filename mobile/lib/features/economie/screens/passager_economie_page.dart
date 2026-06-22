import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';

final _passagerEconomieProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  Map<String, dynamic> stats = {};
  Map<String, dynamic> economies = {};

  // Requête statistiques passager
  try {
    final statsRes = await DioClient.get('/statistiques/passager/');
    debugPrint('[PassagerEconomie] stats raw: ${statsRes.data}');
    if (statsRes.data is Map) {
      stats = Map<String, dynamic>.from(statsRes.data as Map);
    }
  } catch (e) {
    debugPrint('[PassagerEconomie] stats error: $e');
  }

  // Requête économies passager
  try {
    final ecoRes = await DioClient.get('/economie/mes_economies/');
    debugPrint('[PassagerEconomie] economies raw: ${ecoRes.data}');
    if (ecoRes.data is Map) {
      economies = Map<String, dynamic>.from(ecoRes.data as Map);
    }
  } catch (e) {
    debugPrint('[PassagerEconomie] economies error: $e');
  }

  return {'stats': stats, 'economies': economies};
});

class PassagerEconomiePage extends ConsumerWidget {
  const PassagerEconomiePage({super.key});

  // Convertit n'importe quelle valeur numérique, y compris les Decimal Django (string)
  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  double _num(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k) && m[k] != null) {
        return _toDouble(m[k]);
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_passagerEconomieProvider);

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
              'Mes économies',
              style: KTextStyles.bodySm.copyWith(
                fontWeight: FontWeight.w700,
                color: KColors.baseContent,
              ),
            ),
          ],
        ),
      ),
      body: dataAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: KColors.primary),
        ),
        error: (e, _) => KEmptyState(
          icon: Icons.error_outline,
          message: 'Impossible de charger les statistiques',
          actionLabel: 'Réessayer',
          onAction: () => ref.refresh(_passagerEconomieProvider),
        ),
        data: (data) {
          final stats = data['stats'] as Map<String, dynamic>;
          final eco = data['economies'] as Map<String, dynamic>;

          debugPrint('[PassagerEconomie] stats keys: ${stats.keys.toList()}');
          debugPrint('[PassagerEconomie] eco keys: ${eco.keys.toList()}');

          // Backend /economie/mes_economies/ retourne:
          //   total_economie, total_depense_kovoit, total_depense_reference,
          //   nombre_reservations, economie_moyenne_reservation, details_reservations
          final economiesRealisees = _num(eco, ['total_economie', 'economies_realisees', 'montant_economise']);

          // Backend /statistiques/passager/ retourne:
          //   total_economies (Decimal→string), total_reservations, co2_total_evite (float)
          final co2Economise = _num(stats, ['co2_total_evite', 'co2_economise', 'co2']);
          final nombreReservations = _num(eco, ['nombre_reservations']).toInt()
              .clamp(0, 9999)
              .toInt();

          // Distance totale : calculée depuis details_reservations
          double distanceTotale = 0;
          if (eco['details_reservations'] is List) {
            for (final d in eco['details_reservations'] as List) {
              if (d is Map) {
                distanceTotale += _toDouble(d['distance_km']);
              }
            }
          }

          // Économie vs taxi = total_depense_reference - total_depense_kovoit
          final totalRef = _num(eco, ['total_depense_reference']);
          final totalKovoit = _num(eco, ['total_depense_kovoit']);
          final economieVsTaxi = totalRef > 0 ? totalRef - totalKovoit : economiesRealisees;

          // Carburant estimé (1L ~ 200 FCFA en Afrique de l'Ouest)
          final carburantEconomise = economieVsTaxi > 0 ? economieVsTaxi / 200 : 0.0;

          debugPrint('[PassagerEconomie] economiesRealisees=$economiesRealisees co2=$co2Economise km=$distanceTotale nb=$nombreReservations');

          return RefreshIndicator(
            color: KColors.primary,
            onRefresh: () async => ref.refresh(_passagerEconomieProvider),
            child: ListView(
              padding: const EdgeInsets.all(KSpacing.pagePaddingH),
              children: [
                const SizedBox(height: KSpacing.lg),

                // ── Bannière principale ───────────────────────────────────
                KCard(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          KColors.success,
                          KColors.success.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(KSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ÉCONOMIES RÉALISÉES',
                          style: KTextStyles.label.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${economiesRealisees.toStringAsFixed(0)} FCFA',
                          style: KTextStyles.statValue.copyWith(
                            color: Colors.white,
                            fontSize: 36,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'En choisissant le covoiturage plutôt qu\'un taxi',
                          style: KTextStyles.caption.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: KSpacing.xl),

                // ── Grid stats ────────────────────────────────────────────
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: KSpacing.md,
                  crossAxisSpacing: KSpacing.md,
                  childAspectRatio: 1.5,
                  children: [
                    _EcoCard(
                      emoji: '🚗',
                      label: 'Réservations',
                      value: nombreReservations.toString(),
                      color: KColors.primary,
                    ),
                    _EcoCard(
                      emoji: '🛣️',
                      label: 'Distance parcourue',
                      value: '${distanceTotale.toStringAsFixed(0)} km',
                      color: KColors.info,
                    ),
                    _EcoCard(
                      emoji: '🌱',
                      label: 'CO₂ économisé',
                      value: '${co2Economise.toStringAsFixed(1)} kg',
                      color: KColors.success,
                    ),
                    _EcoCard(
                      emoji: '💰',
                      label: 'Vs taxi/Gozem',
                      value: '${economieVsTaxi.toStringAsFixed(0)} FCFA',
                      color: KColors.warning,
                    ),
                  ],
                ),
                const SizedBox(height: KSpacing.xl),

                // ── Impact environnemental ────────────────────────────────
                KCard(
                  child: Column(
                    children: [
                      const KCardHeader(title: 'Impact environnemental'),
                      Padding(
                        padding: const EdgeInsets.all(KSpacing.xl),
                        child: Column(
                          children: [
                            _ImpactRow(
                              emoji: '🌍',
                              label: 'CO₂ non émis',
                              value: '${co2Economise.toStringAsFixed(2)} kg CO₂',
                              color: KColors.success,
                            ),
                            const SizedBox(height: KSpacing.lg),
                            _ImpactRow(
                              emoji: '⛽',
                              label: 'Carburant économisé (estimé)',
                              value: '${carburantEconomise.toStringAsFixed(1)} L',
                              color: KColors.warning,
                            ),
                            const SizedBox(height: KSpacing.lg),
                            _ImpactRow(
                              emoji: '🚦',
                              label: 'Véhicules retirés de la route',
                              value: nombreReservations > 0
                                  ? '~${(nombreReservations * 0.8).toInt()} trajets éliminés'
                                  : '—',
                              color: KColors.info,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: KSpacing.xxl),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EcoCard extends StatelessWidget {
  final String emoji, label, value;
  final Color color;
  const _EcoCard({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const Spacer(),
            Text(
              value,
              style: KTextStyles.statValue.copyWith(color: color, fontSize: 20),
            ),
            Text(label, style: KTextStyles.meta, maxLines: 2),
          ],
        ),
      ),
    );
  }
}

class _ImpactRow extends StatelessWidget {
  final String emoji, label, value;
  final Color color;
  const _ImpactRow({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(width: KSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: KTextStyles.caption),
              Text(
                value,
                style: KTextStyles.bodySm.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
