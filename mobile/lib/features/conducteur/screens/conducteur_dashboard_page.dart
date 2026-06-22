import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../reservations/models/reservation_model.dart';
import '../../reservations/repositories/reservation_repository.dart';
import '../../trajets/models/trajet_model.dart';
import '../../trajets/repositories/trajet_repository.dart';
import '../../messagerie/models/message_model.dart';
import '../../messagerie/repositories/messagerie_repository.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_avatar.dart';
import '../../../core/widgets/k_badge.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_list_tile.dart';

// ── Données dashboard ─────────────────────────────────────────────────────────

class _DashData {
  final List<TrajetModel> trajets;
  final List<ReservationModel> reservationsRecues;
  final List<ConversationModel> conversations;
  final Map<String, dynamic> stats;

  _DashData({
    required this.trajets,
    required this.reservationsRecues,
    required this.conversations,
    required this.stats,
  });
}

final _conducteurDashProvider = FutureProvider.autoDispose<_DashData>((ref) async {
  List<TrajetModel> trajets = [];
  List<ReservationModel> reservationsRecues = [];
  List<ConversationModel> conversations = [];
  Map<String, dynamic> stats = {};

  await Future.wait<void>([
    (() async {
      try { trajets = await TrajetRepository().mesTrajets(); }
      catch (e) { debugPrint('[ConducteurDash] trajets: $e'); }
    })(),
    (() async {
      try { reservationsRecues = await ReservationRepository().reservationsRecues(); }
      catch (e) { debugPrint('[ConducteurDash] reservations: $e'); }
    })(),
    (() async {
      try { conversations = await MessagerieRepository().getConversations(); }
      catch (e) { debugPrint('[ConducteurDash] conversations: $e'); }
    })(),
    (() async {
      try {
        final r = await DioClient.get(ApiConstants.statsConducteur);
        if (r.data is Map) stats = Map<String, dynamic>.from(r.data as Map);
      } catch (e) { debugPrint('[ConducteurDash] stats: $e'); }
    })(),
  ]);

  return _DashData(
    trajets: trajets,
    reservationsRecues: reservationsRecues,
    conversations: conversations,
    stats: stats,
  );
});

// ── Page principale ───────────────────────────────────────────────────────────

class ConducteurDashboardPage extends ConsumerWidget {
  const ConducteurDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final dashAsync = ref.watch(_conducteurDashProvider);

    final hour = DateTime.now().hour;
    final salutation =
        hour < 12 ? 'Bonjour' : hour < 18 ? 'Bon après-midi' : 'Bonsoir';
    final dateStr =
        DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(DateTime.now());

    return Scaffold(
      backgroundColor: KColors.base200,
      body: RefreshIndicator(
        color: KColors.primary,
        onRefresh: () => ref.refresh(_conducteurDashProvider.future),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _WelcomeCard(
                    user: user,
                    salutation: salutation,
                    dateStr: dateStr,
                    roleLabel: 'Conducteur',
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      KSpacing.pagePaddingH,
                      KSpacing.xl,
                      KSpacing.pagePaddingH,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Statistiques générales
                        dashAsync.when(
                          loading: () => _StatsSkeletonGrid(),
                          error: (_, _) => const SizedBox(),
                          data: (d) => _ConducteurStatsGrid(
                            data: d,
                            userNote: user?.note ?? 0,
                          ),
                        ),
                        const SizedBox(height: KSpacing.xl),

                        // Revenus
                        dashAsync.when(
                          loading: () => const SizedBox(),
                          error: (_, _) => const SizedBox(),
                          data: (d) {
                            if (d.stats.isEmpty) return const SizedBox();
                            return Column(
                              children: [
                                _RevenusMiniCard(stats: d.stats),
                                const SizedBox(height: KSpacing.xl),
                              ],
                            );
                          },
                        ),

                        // Prochains trajets
                        dashAsync.when(
                          loading: () =>
                              _SectionSkeleton('Prochains trajets', 3),
                          error: (_, _) => const SizedBox(),
                          data: (d) =>
                              _UpcomingTrajetsCard(trajets: d.trajets),
                        ),
                        const SizedBox(height: KSpacing.xl),

                        // Réservations reçues récentes
                        dashAsync.when(
                          loading: () =>
                              _SectionSkeleton('Réservations reçues', 3),
                          error: (_, _) => const SizedBox(),
                          data: (d) => _RecentReservationsCard(
                            reservations: d.reservationsRecues,
                          ),
                        ),
                        const SizedBox(height: KSpacing.xl),

                        // Messages récents
                        dashAsync.when(
                          loading: () =>
                              _SectionSkeleton('Messages récents', 2),
                          error: (_, _) => const SizedBox(),
                          data: (d) => _MessagesCard(
                            conversations: d.conversations,
                            prefix: '/conducteur',
                          ),
                        ),
                        const SizedBox(height: KSpacing.xl),

                        // Impact écologique
                        dashAsync.when(
                          loading: () => const SizedBox(),
                          error: (_, _) => const SizedBox(),
                          data: (d) {
                            if (d.stats.isEmpty) return const SizedBox();
                            return Column(
                              children: [
                                _EcoImpactCard(stats: d.stats),
                                const SizedBox(height: KSpacing.xl),
                              ],
                            );
                          },
                        ),

                        // Navigation rapide
                        _ConducteurQuickNav(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Welcome Card ──────────────────────────────────────────────────────────────

class _WelcomeCard extends StatelessWidget {
  final UserModel? user;
  final String salutation;
  final String dateStr;
  final String roleLabel;

  const _WelcomeCard({
    required this.user,
    required this.salutation,
    required this.dateStr,
    required this.roleLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        KSpacing.pagePaddingH,
        KSpacing.xl,
        KSpacing.pagePaddingH,
        KSpacing.xxl,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [KColors.primary, KColors.primaryDark],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    roleLabel.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  salutation,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  user?.displayName ?? user?.username ?? 'Utilisateur',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          KAvatar(
            photoUrl: user?.photoProfile,
            name: user?.displayName ?? user?.username,
            size: 52,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }
}

// ── Statistiques conducteur ───────────────────────────────────────────────────

class _ConducteurStatsGrid extends StatelessWidget {
  final _DashData data;
  final double userNote;

  const _ConducteurStatsGrid({required this.data, required this.userNote});

  @override
  Widget build(BuildContext context) {
    final stats = data.stats;
    final trajets = data.trajets;
    final reservations = data.reservationsRecues;

    // Total trajets: liste complète (toutes périodes/statuts)
    final statTrajets = stats['total_trajets'] ?? stats['nombre_trajets'];
    final statTrajetsInt = statTrajets is num
        ? statTrajets.toInt()
        : int.tryParse(statTrajets?.toString() ?? '') ?? 0;
    final total = trajets.isNotEmpty ? trajets.length : statTrajetsInt;

    // Total réservations reçues: liste complète
    final totalReserv = reservations.isNotEmpty
        ? reservations.length
        : (stats['reservations_total'] is num
            ? (stats['reservations_total'] as num).toInt()
            : 0);

    // Passagers transportés: somme des places des réservations confirmées/terminées
    final passagers = reservations
        .where((r) => r.statut == 'confirmee' || r.statut == 'terminee')
        .fold<int>(0, (sum, r) => sum + r.placesReservees);

    // Note: gérer Decimal-as-string du backend
    final noteRaw = stats['note_moyenne'] ?? stats['note'];
    final note = noteRaw is num
        ? noteRaw.toDouble()
        : double.tryParse(noteRaw?.toString() ?? '') ?? userNote;

    final items = [
      {'v': '$total', 'l': 'Trajets proposés', 's': 'au total'},
      {'v': '$totalReserv', 'l': 'Réservations reçues', 's': 'au total'},
      {'v': '$passagers', 'l': 'Passagers transportés', 's': 'au total'},
      {'v': '${note.toStringAsFixed(1)} / 5', 'l': 'Note', 's': 'moyenne'},
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: KSpacing.md,
      crossAxisSpacing: KSpacing.md,
      childAspectRatio: 1.5,
      children: items
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

// ── Revenus ───────────────────────────────────────────────────────────────────

class _RevenusMiniCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _RevenusMiniCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    // Backend renvoie total_revenus en Decimal→string, toDouble() gère les deux
    double toDouble(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
    final mois = toDouble(stats['total_revenus'] ?? stats['revenus_mois'] ?? stats['revenus_ce_mois']);
    final total = toDouble(stats['total_revenus']);
    debugPrint('[ConducteurDash] revenus mois=$mois total=$total');
    final fmt = NumberFormat('#,##0', 'fr_FR');

    return KCard(
      child: Column(
        children: [
          const KCardHeader(title: 'Revenus'),
          Padding(
            padding: const EdgeInsets.all(KSpacing.xl),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${fmt.format(mois)} FCFA',
                        style: KTextStyles.statValue
                            .copyWith(color: KColors.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ce mois',
                        style: KTextStyles.meta,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: KColors.border),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${fmt.format(total)} FCFA',
                        style: KTextStyles.statValue,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total',
                        style: KTextStyles.meta,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Prochains trajets ─────────────────────────────────────────────────────────

class _UpcomingTrajetsCard extends StatelessWidget {
  final List<TrajetModel> trajets;
  const _UpcomingTrajetsCard({required this.trajets});

  @override
  Widget build(BuildContext context) {
    // Inclure trajets ouverts et en cours (passés ou futurs)
    final upcoming = trajets
        .where((t) => t.statut == 'ouvert' || t.statut == 'en_cours')
        .toList()
      ..sort((a, b) => a.dateHeureDepart.compareTo(b.dateHeureDepart));
    final items = upcoming.take(3).toList();

    return KCard(
      child: Column(
        children: [
          KCardHeader(
            title: 'Prochains trajets',
            action: 'Voir tout',
            onAction: () => context.push('/conducteur/trajets'),
          ),
          if (items.isEmpty)
            KEmptyState(
              emoji: '🚗',
              message: 'Aucun trajet à venir',
              actionLabel: 'Proposer un trajet',
              onAction: () => context.push('/conducteur/create-trajet'),
            )
          else
            for (final t in items) _TrajetRow(trajet: t),
        ],
      ),
    );
  }
}

// ── Réservations reçues ───────────────────────────────────────────────────────

class _RecentReservationsCard extends StatelessWidget {
  final List<ReservationModel> reservations;
  const _RecentReservationsCard({required this.reservations});

  @override
  Widget build(BuildContext context) {
    final sorted = [...reservations]
      ..sort((a, b) => b.dateReservation.compareTo(a.dateReservation));
    final items = sorted.take(3).toList();

    return KCard(
      child: Column(
        children: [
          KCardHeader(
            title: 'Réservations reçues',
            action: 'Voir tout',
            onAction: () => context.push('/conducteur/reservations'),
          ),
          if (items.isEmpty)
            const KEmptyState(
              emoji: '📋',
              message: 'Aucune réservation reçue',
            )
          else
            for (final r in items) _ReservationRow(reservation: r),
        ],
      ),
    );
  }
}

// ── Messages récents ──────────────────────────────────────────────────────────

class _MessagesCard extends StatelessWidget {
  final List<ConversationModel> conversations;
  final String prefix;
  const _MessagesCard({required this.conversations, required this.prefix});

  @override
  Widget build(BuildContext context) {
    final items = conversations.take(2).toList();

    return KCard(
      child: Column(
        children: [
          KCardHeader(
            title: 'Messages récents',
            action: 'Voir tout',
            onAction: () => context.push('$prefix/messages'),
          ),
          if (items.isEmpty)
            const KEmptyState(emoji: '💬', message: 'Aucune conversation')
          else
            for (final c in items) _ConvRow(conv: c, prefix: prefix),
        ],
      ),
    );
  }
}

// ── Impact écologique ─────────────────────────────────────────────────────────

class _EcoImpactCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _EcoImpactCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final kmRaw = stats['distance_totale'] ?? stats['km_total'];
    final km = kmRaw is num ? kmRaw.toDouble() : 0.0;
    final co2 = km * 0.12; // ~120g CO₂/km économisé en covoiturage
    final fmt = NumberFormat('#,##0', 'fr_FR');

    return KCard(
      child: Column(
        children: [
          const KCardHeader(title: 'Impact écologique'),
          Padding(
            padding: const EdgeInsets.all(KSpacing.xl),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${fmt.format(km)} km',
                        style:
                            KTextStyles.statValue.copyWith(color: KColors.info),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Distance partagée',
                        style: KTextStyles.meta,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: KColors.border),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${co2.toStringAsFixed(1)} kg',
                        style: KTextStyles.statValue
                            .copyWith(color: KColors.successContent),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'CO₂ économisé',
                        style: KTextStyles.meta,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Navigation rapide ─────────────────────────────────────────────────────────

class _ConducteurQuickNav extends StatelessWidget {
  const _ConducteurQuickNav();

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Column(
        children: [
          const KCardHeader(title: 'Navigation rapide'),
          KListTile(
            title: 'Proposer un trajet',
            onTap: () => context.push('/conducteur/create-trajet'),
          ),
          KListTile(
            title: 'Mes trajets',
            onTap: () => context.push('/conducteur/trajets'),
          ),
          KListTile(
            title: 'Réservations reçues',
            onTap: () => context.push('/conducteur/reservations'),
          ),
          KListTile(
            title: 'Vérification du compte',
            onTap: () => context.push('/conducteur/verification'),
          ),
          KListTile(
            title: 'Mes véhicules',
            onTap: () => context.push('/conducteur/vehicules'),
          ),
          KListTile(
            title: 'Économie & revenus',
            onTap: () => context.push('/conducteur/economie'),
          ),
          KListTile(
            title: 'Mes évaluations',
            onTap: () => context.push('/conducteur/evaluations'),
          ),
        ],
      ),
    );
  }
}

// ── Widgets de ligne ──────────────────────────────────────────────────────────

class _TrajetRow extends StatelessWidget {
  final TrajetModel trajet;
  const _TrajetRow({required this.trajet});

  @override
  Widget build(BuildContext context) {
    final dateLabel = _formatDate(trajet.dateHeureDepart);

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
                      TextSpan(text: trajet.depart),
                      TextSpan(
                        text: '  →  ',
                        style: KTextStyles.bodySmBold.copyWith(
                          color: KColors.baseContentLow,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      TextSpan(text: trajet.destination),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateLabel · '
                  '${trajet.placesRestantes} place'
                  '${trajet.placesRestantes > 1 ? 's' : ''}',
                  style: KTextStyles.meta,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          KBadge.fromStatut(trajet.statut),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final today = DateTime.now();
    if (dt.year == today.year &&
        dt.month == today.month &&
        dt.day == today.day) {
      return "Aujourd'hui, ${DateFormat('HH:mm').format(dt)}";
    }
    return DateFormat('d MMM, HH:mm', 'fr_FR').format(dt);
  }
}

class _ReservationRow extends StatelessWidget {
  final ReservationModel reservation;
  const _ReservationRow({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final trajet = reservation.trajet;
    final depart = trajet?.depart ?? '—';
    final dest = trajet?.destination ?? '—';

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
                Text(reservation.passagerNom, style: KTextStyles.bodySmBold),
                const SizedBox(height: 2),
                Text(
                  '$depart → $dest',
                  style: KTextStyles.meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          KBadge.fromStatut(reservation.statut),
        ],
      ),
    );
  }
}

class _ConvRow extends StatelessWidget {
  final ConversationModel conv;
  final String prefix;
  const _ConvRow({required this.conv, required this.prefix});

  @override
  Widget build(BuildContext context) {
    final hasUnread = conv.unreadCount > 0;
    return InkWell(
      onTap: () => context.push(
        '$prefix/messages/${conv.convId}'
        '?name=${Uri.encodeComponent(conv.userName)}'
        '&userId=${conv.userId}',
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: KColors.border)),
        ),
        child: Row(
          children: [
            KAvatar(
              name: conv.userName,
              photoUrl: conv.userPhoto,
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conv.userName,
                    style: KTextStyles.bodySm.copyWith(
                      fontWeight:
                          hasUnread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (conv.lastMessage != null)
                    Text(
                      conv.lastMessage!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KTextStyles.caption.copyWith(
                        color: hasUnread
                            ? KColors.baseContent
                            : KColors.baseContentMid,
                      ),
                    ),
                ],
              ),
            ),
            if (hasUnread)
              Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: KColors.error,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${conv.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Skeletons ─────────────────────────────────────────────────────────────────

class _StatsSkeletonGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: KSpacing.md,
        crossAxisSpacing: KSpacing.md,
        childAspectRatio: 1.5,
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

class _SectionSkeleton extends StatelessWidget {
  final String title;
  final int rows;
  const _SectionSkeleton(this.title, this.rows);

  @override
  Widget build(BuildContext context) => KCard(
        child: Column(
          children: [
            KCardHeader(title: title),
            for (int i = 0; i < rows; i++)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                child: const Row(
                  children: [
                    Expanded(child: KSkeleton(height: 14)),
                    SizedBox(width: 8),
                    KSkeleton(height: 24, width: 64),
                  ],
                ),
              ),
          ],
        ),
      );
}
