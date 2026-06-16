import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';
import '../../trajets/repositories/trajet_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_badge.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_list_tile.dart';

final _conducteurDashProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final repo = TrajetRepository();
  final trajets = await repo.mesTrajets();
  return {
    'trajets': trajets.map((t) => {
      'statut': t.statut,
      'date_heure_depart': t.dateHeureDepart.toIso8601String(),
      'depart': t.depart,
      'destination': t.destination,
      'places_restantes': t.placesRestantes,
    }).toList(),
  };
});

/// Dashboard Conducteur — reproduit /conducteur/dashboard du Web
class ConducteurDashboardPage extends ConsumerWidget {
  const ConducteurDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final dashAsync = ref.watch(_conducteurDashProvider);

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
        onRefresh: () => ref.refresh(_conducteurDashProvider.future),
        child: CustomScrollView(
          slivers: [
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
                    '· Conducteur',
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
                      'TABLEAU DE BORD — CONDUCTEUR',
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

                    // ── STATS ────────────────────────────────────────────────
                    dashAsync.when(
                      loading: () => _StatsSkeleton(),
                      error: (_, _) => const KEmptyState(
                        message: 'Erreur',
                        icon: Icons.error_outline,
                      ),
                      data: (data) {
                        final trajets = data['trajets'] as List? ?? [];
                        final actifs = trajets
                            .where(
                              (t) =>
                                  (t['statut'] as String?) == 'ouvert' ||
                                  (t['statut'] as String?) == 'en_cours',
                            )
                            .length;
                        return _StatsGrid(
                          proposes: trajets.length,
                          actifs: actifs,
                          note: (user?.note ?? 0).toStringAsFixed(1),
                        );
                      },
                    ),
                    const SizedBox(height: KSpacing.xl),

                    // ── TRAJETS RÉCENTS ──────────────────────────────────────
                    dashAsync.when(
                      loading: () => _TrajetsSkeleton(),
                      error: (_, _) => const SizedBox(),
                      data: (data) {
                        final all = (data['trajets'] as List? ?? []);
                        all.sort(
                          (a, b) => (b['date_heure_depart'] as String? ?? '')
                              .compareTo(
                                a['date_heure_depart'] as String? ?? '',
                              ),
                        );
                        final recents = all.take(5).toList();

                        return KCard(
                          child: Column(
                            children: [
                              KCardHeader(
                                title: 'Trajets récents',
                                action: 'Voir tout',
                                onAction: () =>
                                    context.go('/conducteur/trajets'),
                              ),
                              if (recents.isEmpty)
                                KEmptyState(
                                  message:
                                      'Aucun trajet proposé pour le moment',
                                  actionLabel: 'Proposer un trajet',
                                  onAction: () =>
                                      context.go('/conducteur/create-trajet'),
                                )
                              else
                                for (final t in recents) _TrajetRow(trajet: t),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: KSpacing.xl),

                    // ── NAVIGATION ───────────────────────────────────────────
                    KCard(
                      child: Column(
                        children: [
                          const KCardHeader(title: 'Navigation'),
                          for (final item in [
                            {
                              'label': 'Vérification du compte',
                              'route': '/conducteur/verification',
                            },
                            {
                              'label': 'Mes documents',
                              'route': '/conducteur/documents',
                            },
                            {
                              'label': 'Réservations reçues',
                              'route': '/conducteur/reservations',
                            },
                            {
                              'label': 'Véhicules',
                              'route': '/conducteur/vehicules',
                            },
                            {
                              'label': 'Économies',
                              'route': '/conducteur/economie',
                            },
                            {
                              'label': 'Évaluations',
                              'route': '/conducteur/evaluations',
                            },
                            {
                              'label': 'Profil & Paramètres',
                              'route': '/conducteur/profile',
                            },
                          ])
                            KListTile(
                              title: item['label']!,
                              onTap: () => context.go(item['route']!),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 100), // espace pour le FAB
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

class _StatsGrid extends StatelessWidget {
  final int proposes, actifs;
  final String note;
  const _StatsGrid({
    required this.proposes,
    required this.actifs,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: KSpacing.md,
      crossAxisSpacing: KSpacing.md,
      childAspectRatio: 1.6,
      children:
          [
                {'v': '$proposes', 'l': 'Trajets proposés', 's': 'total'},
                {'v': '$actifs', 'l': 'Trajets actifs', 's': 'en cours'},
                {'v': '$note / 5', 'l': 'Note', 's': 'moyenne'},
              ]
              .map(
                (s) => KCard(
                  child: Padding(
                    padding: const EdgeInsets.all(KSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s['v']!, style: KTextStyles.statValue),
                        const SizedBox(height: 4),
                        Text(s['l']!, style: KTextStyles.bodySm),
                        Text(s['s']!, style: KTextStyles.meta),
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
      3,
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

class _TrajetsSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => KCard(
    child: Column(
      children: [
        const KCardHeader(title: 'Trajets récents'),
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

class _TrajetRow extends StatelessWidget {
  final Map<String, dynamic> trajet;
  const _TrajetRow({required this.trajet});

  @override
  Widget build(BuildContext context) {
    final statut = trajet['statut'] as String? ?? '';
    final depart = trajet['depart'] as String? ?? '';
    final dest = trajet['destination'] as String? ?? '';
    final date = trajet['date_heure_depart'] as String? ?? '';
    final places = trajet['places_restantes'] ?? 0;

    String dateLabel = '';
    try {
      final dt = DateTime.parse(date);
      final today = DateTime.now();
      if (dt.day == today.day) {
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
                Text(
                  '$dateLabel · $places place${places > 1 ? 's' : ''}',
                  style: KTextStyles.meta,
                ),
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
