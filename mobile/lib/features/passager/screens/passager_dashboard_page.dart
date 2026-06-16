import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';
import '../../reservations/repositories/reservation_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_badge.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_list_tile.dart';

/// Provider des données dashboard passager
final _passagerDashboardProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final repo = ReservationRepository();
  final reservations = await repo.mesReservations();
  return {
    'reservations': reservations.map((r) => {
      'statut': r.statut,
      'depart': r.trajet?.depart ?? '',
      'destination': r.trajet?.destination ?? '',
      'date_depart': r.trajet?.dateHeureDepart.toIso8601String() ?? '',
      'date_reservation': r.dateReservation.toIso8601String(),
    }).toList(),
  };
});

/// Dashboard Passager — reproduit fidèlement la page /passager/dashboard du Web
class PassagerDashboardPage extends ConsumerWidget {
  const PassagerDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final dashAsync = ref.watch(_passagerDashboardProvider);

    final hour = DateTime.now().hour;
    final salutation = hour < 12
        ? 'Bonjour'
        : hour < 18
        ? 'Bon après-midi'
        : 'Bonsoir';
    final dateStr = DateFormat(
      'EEEE d MMMM yyyy',
      'fr_FR',
    ).format(DateTime.now());

    return Scaffold(
      backgroundColor: KColors.base200,
      body: RefreshIndicator(
        color: KColors.primary,
        onRefresh: () => ref.refresh(_passagerDashboardProvider.future),
        child: CustomScrollView(
          slivers: [
            // ── AppBar sticky (remplace la navbar Web) ─────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor: KColors.base100,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              shape: const Border(bottom: BorderSide(color: KColors.border)),
              title: Row(
                children: [
                  Image.asset('assets/logos/logo1.png', width: 22, height: 22),
                  const SizedBox(width: 8),
                  Text(
                    'KoVoit',
                    style: KTextStyles.bodySm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: KColors.baseContent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '· Passager',
                    style: KTextStyles.caption.copyWith(
                      color: KColors.baseContentLow,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_none_outlined,
                    color: KColors.baseContentMid,
                  ),
                  onPressed: () {},
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.pagePaddingH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: KSpacing.lg),

                    // ── EN-TÊTE ──────────────────────────────────────────────
                    Text(
                      'TABLEAU DE BORD — PASSAGER',
                      style: KTextStyles.label,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$salutation, ${user?.firstName ?? user?.username ?? ''}',
                      style: KTextStyles.h1,
                    ),
                    const SizedBox(height: 4),
                    Text(dateStr, style: KTextStyles.meta),
                    const SizedBox(height: KSpacing.xl),
                    const Divider(color: KColors.border),
                    const SizedBox(height: KSpacing.xl),

                    // ── BARRE DE RECHERCHE ───────────────────────────────────
                    KCard(
                      child: Padding(
                        padding: const EdgeInsets.all(KSpacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('RECHERCHE RAPIDE', style: KTextStyles.label),
                            const SizedBox(height: KSpacing.lg),
                            Row(
                              children: [
                                Expanded(
                                  child: _SearchInput(hint: 'Ville de départ'),
                                ),
                                const SizedBox(width: KSpacing.sm),
                                Expanded(
                                  child: _SearchInput(hint: "Ville d'arrivée"),
                                ),
                              ],
                            ),
                            const SizedBox(height: KSpacing.md),
                            KButton(
                              label: 'Rechercher un trajet',
                              icon: Icons.search,
                              onPressed: () => context.go('/passager/trajets'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: KSpacing.xl),

                    // ── STATS ────────────────────────────────────────────────
                    dashAsync.when(
                      loading: () => _StatsSkeleton(),
                      error: (_, _) => const KEmptyState(
                        message: 'Erreur de chargement',
                        icon: Icons.error_outline,
                      ),
                      data: (data) {
                        final reservations =
                            data['reservations'] as List? ?? [];
                        final actives = reservations
                            .where(
                              (r) =>
                                  r['statut'] == 'en_attente' ||
                                  r['statut'] == 'confirmee',
                            )
                            .length;
                        return _StatsGrid(
                          trajets: reservations.length,
                          actives: actives,
                          note: (user?.note ?? 0).toStringAsFixed(1),
                        );
                      },
                    ),
                    const SizedBox(height: KSpacing.xl),

                    // ── RÉSERVATIONS RÉCENTES ───────────────────────────────
                    dashAsync.when(
                      loading: () => _ReservationsSkeleton(),
                      error: (_, _) => const SizedBox(),
                      data: (data) {
                        final reservations =
                            (data['reservations'] as List? ?? [])..sort(
                              (a, b) => (b['date_reservation'] as String)
                                  .compareTo(a['date_reservation'] as String),
                            );
                        final recentes = reservations.take(5).toList();

                        return KCard(
                          child: Column(
                            children: [
                              KCardHeader(
                                title: 'Réservations récentes',
                                action: 'Voir tout',
                                onAction: () =>
                                    context.go('/passager/reservations'),
                              ),
                              if (recentes.isEmpty)
                                KEmptyState(
                                  message: 'Aucune réservation pour le moment',
                                  actionLabel: 'Rechercher un trajet',
                                  onAction: () =>
                                      context.go('/passager/trajets'),
                                )
                              else
                                for (final r in recentes)
                                  _ReservationRow(reservation: r),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: KSpacing.xl),

                    // ── NAVIGATION RAPIDE ────────────────────────────────────
                    KCard(
                      child: Column(
                        children: [
                          const KCardHeader(title: 'Navigation'),
                          for (final item in [
                            {
                              'label': 'Historique des réservations',
                              'route': '/passager/reservations',
                            },
                            {
                              'label': 'Mes évaluations',
                              'route': '/passager/evaluations',
                            },
                            {
                              'label': 'Économies',
                              'route': '/passager/economie',
                            },
                            {
                              'label': 'Profil & Paramètres',
                              'route': '/passager/profile',
                            },
                            {
                              'label': 'Devenir conducteur',
                              'route': '/passager/devenir-conducteur',
                            },
                          ])
                            KListTile(
                              title: item['label']!,
                              onTap: () => context.go(item['route']!),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: KSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets internes ──────────────────────────────────────────────────────────

class _SearchInput extends StatelessWidget {
  final String hint;
  const _SearchInput({required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: KColors.base100,
        border: Border.all(color: KColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(hint, style: KTextStyles.caption),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final int trajets, actives;
  final String note;
  const _StatsGrid({
    required this.trajets,
    required this.actives,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      {'value': '$trajets', 'label': 'Trajets effectués', 'sub': 'au total'},
      {'value': '$actives', 'label': 'Réservations actives', 'sub': 'en cours'},
      {'value': '$note / 5', 'label': 'Note', 'sub': 'moyenne'},
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: KSpacing.md,
      crossAxisSpacing: KSpacing.md,
      childAspectRatio: 1.6,
      children: items
          .take(4)
          .map(
            (s) => KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s['value']!, style: KTextStyles.statValue),
                    const SizedBox(height: 4),
                    Text(s['label']!, style: KTextStyles.bodySm),
                    Text(s['sub']!, style: KTextStyles.meta),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: KSpacing.md,
    crossAxisSpacing: KSpacing.md,
    childAspectRatio: 1.6,
    children: List.generate(
      4,
      (_) => KCard(
        child: const Padding(
          padding: EdgeInsets.all(KSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KSkeleton(height: 28, width: 80),
              SizedBox(height: 8),
              KSkeleton(height: 14),
              SizedBox(height: 4),
              KSkeleton(height: 12, width: 60),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ReservationsSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => KCard(
    child: Column(
      children: [
        const KCardHeader(title: 'Réservations récentes'),
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const KSkeleton(height: 14, width: 160),
                      const SizedBox(height: 6),
                      const KSkeleton(height: 12, width: 100),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const KSkeleton(height: 24, width: 64),
              ],
            ),
          ),
      ],
    ),
  );
}

class _ReservationRow extends StatelessWidget {
  final Map<String, dynamic> reservation;
  const _ReservationRow({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final statut = reservation['statut'] as String? ?? '';
    final depart = reservation['depart'] as String? ?? '';
    final dest = reservation['destination'] as String? ?? '';
    final date = reservation['date_depart'] as String? ?? '';

    String dateLabel = '';
    try {
      final dt = DateTime.parse(date);
      final today = DateTime.now();
      if (dt.day == today.day && dt.month == today.month) {
        dateLabel = "Aujourd'hui, ${DateFormat('HH:mm').format(dt)}";
      } else {
        dateLabel = DateFormat('d MMM, HH:mm', 'fr_FR').format(dt);
      }
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: KColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: KTextStyles.bodySmBold,
                    children: [
                      TextSpan(text: depart),
                      TextSpan(
                        text: '  →  ',
                        style: KTextStyles.bodySmBold.copyWith(
                          color: KColors.baseContentLow,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      TextSpan(text: dest),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(dateLabel, style: KTextStyles.meta),
              ],
            ),
          ),
          const SizedBox(width: 8),
          KBadge.fromStatut(statut),
        ],
      ),
    );
  }
}
