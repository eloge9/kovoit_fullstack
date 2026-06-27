import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../reservations/models/reservation_model.dart';
import '../../reservations/repositories/reservation_repository.dart';
import '../../messagerie/models/message_model.dart';
import '../../messagerie/repositories/messagerie_repository.dart';
import '../../trajets/models/trajet_model.dart';
import '../../trajets/repositories/trajet_repository.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/k_avatar.dart';
import '../../../core/widgets/k_badge.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_list_tile.dart';

// ── Données dashboard ─────────────────────────────────────────────────────────

class _DashData {
  final List<ReservationModel> reservations;
  final List<ConversationModel> conversations;
  final Map<String, dynamic> stats;
  final Map<String, dynamic> eco;
  _DashData({
    required this.reservations,
    required this.conversations,
    required this.stats,
    required this.eco,
  });
}

// Provider trajets disponibles (rechargé indépendamment)
final _trajetsDispoProvider = FutureProvider.autoDispose<List<TrajetModel>>((ref) async {
  try {
    final repo = TrajetRepository();
    final trajets = await repo.getTrajets();
    debugPrint('[PassagerDash] ${trajets.length} trajets disponibles chargés');
    return trajets;
  } catch (e) {
    debugPrint('[PassagerDash] trajets error: $e');
    return [];
  }
});

final _passagerDashProvider = FutureProvider.autoDispose<_DashData>((ref) async {
  List<ReservationModel> reservations = [];
  List<ConversationModel> conversations = [];
  Map<String, dynamic> stats = {};
  Map<String, dynamic> eco = {};

  await Future.wait<void>([
    (() async {
      try {
        reservations = await ReservationRepository().mesReservations();
        debugPrint('[PassagerDash] ${reservations.length} réservations chargées');
      } catch (e) {
        debugPrint('[PassagerDash] reservations error: $e');
      }
    })(),
    (() async {
      try {
        conversations = await MessagerieRepository().getConversations();
        debugPrint('[PassagerDash] ${conversations.length} conversations chargées');
      } catch (e) {
        debugPrint('[PassagerDash] conversations error: $e');
      }
    })(),
    (() async {
      try {
        final r = await DioClient.get(ApiConstants.statsPassager);
        debugPrint('[PassagerDash] stats raw: ${r.data}');
        if (r.data is Map) stats = Map<String, dynamic>.from(r.data as Map);
      } catch (e) {
        debugPrint('[PassagerDash] stats error: $e');
      }
    })(),
    (() async {
      try {
        final r = await DioClient.get(ApiConstants.mesEconomies);
        debugPrint('[PassagerDash] eco raw: ${r.data}');
        if (r.data is Map) {
          eco = Map<String, dynamic>.from(r.data as Map);
        }
      } catch (e) {
        debugPrint('[PassagerDash] eco error: $e');
      }
    })(),
  ]);

  // Fusionner le CO2 des statistiques dans l'objet éco si présent
  if (stats.containsKey('co2_total_evite') && !eco.containsKey('co2_economise')) {
    eco['co2_economise'] = stats['co2_total_evite'];
  }

  return _DashData(
    reservations: reservations,
    conversations: conversations,
    stats: stats,
    eco: eco,
  );
});

// ── Page principale ───────────────────────────────────────────────────────────

class PassagerDashboardPage extends ConsumerWidget {
  const PassagerDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final dashAsync = ref.watch(_passagerDashProvider);

    final hour = DateTime.now().hour;
    final salutation =
        hour < 12 ? 'Bonjour' : hour < 18 ? 'Bon après-midi' : 'Bonsoir';
    final dateStr =
        DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(DateTime.now());

    final trajetsAsync = ref.watch(_trajetsDispoProvider);

    return Scaffold(
      backgroundColor: KColors.base200,
      body: RefreshIndicator(
        color: KColors.primary,
        onRefresh: () async {
          ref.invalidate(_passagerDashProvider);
          ref.invalidate(_trajetsDispoProvider);
        },
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
                    roleLabel: 'Passager',
                  ),
                  // Bannière trajet en cours
                  dashAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (d) {
                      ReservationModel? activeRes;
                      for (final r in d.reservations) {
                        if (r.trajet?.statut == 'en_cours') {
                          activeRes = r;
                          break;
                        }
                      }
                      if (activeRes == null) return const SizedBox.shrink();
                      return _ActiveTrajetBanner(reservation: activeRes);
                    },
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
                        // Statistiques
                        dashAsync.when(
                          loading: () => _StatsSkeletonGrid(),
                          error: (e, _) => _DashboardErrorCard(message: e.toString()),
                          data: (d) => _PassagerStatsGrid(
                            data: d,
                            userNote: user?.note ?? 0,
                          ),
                        ),
                        const SizedBox(height: KSpacing.xl),

                        // Trajets disponibles (chargés automatiquement)
                        _TrajetsDispoSection(trajetsAsync: trajetsAsync),
                        const SizedBox(height: KSpacing.xl),

                        // Prochains trajets
                        dashAsync.when(
                          loading: () => _SectionSkeleton('Mes réservations', 3),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (d) => _UpcomingCard(reservations: d.reservations),
                        ),
                        const SizedBox(height: KSpacing.xl),

                        // Messages récents
                        dashAsync.when(
                          loading: () => _SectionSkeleton('Messages récents', 2),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (d) => _MessagesCard(
                            conversations: d.conversations,
                            prefix: '/passager',
                            onReturn: () => ref.invalidate(_passagerDashProvider),
                          ),
                        ),
                        const SizedBox(height: KSpacing.xl),

                        // Économies & impact
                        dashAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (d) {
                            if (d.eco.isEmpty) return const SizedBox.shrink();
                            return Column(
                              children: [
                                _EcoCard(eco: d.eco),
                                const SizedBox(height: KSpacing.xl),
                              ],
                            );
                          },
                        ),

                        // Navigation rapide
                        _PassagerQuickNav(),
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

// ── Grille de statistiques ────────────────────────────────────────────────────

class _PassagerStatsGrid extends StatelessWidget {
  final _DashData data;
  final double userNote;

  const _PassagerStatsGrid({required this.data, required this.userNote});

  @override
  Widget build(BuildContext context) {
    final stats = data.stats;
    final reservations = data.reservations;

    // Total: préférer la liste complète (toutes périodes, tous statuts)
    final statTotal = stats['total_reservations'];
    final statTotalInt = statTotal is num
        ? statTotal.toInt()
        : int.tryParse(statTotal?.toString() ?? '') ?? 0;
    final total = reservations.isNotEmpty ? reservations.length : statTotalInt;

    // À venir: statuts actifs (date ignorée si non disponible)
    final avenir = reservations.where((r) =>
        r.statut == 'en_attente' || r.statut == 'confirmee').length;

    final terminees = reservations.where((r) => r.statut == 'terminee').length;

    // Note: gérer Decimal-as-string du backend
    final noteRaw = stats['note_moyenne'] ?? stats['note'];
    final note = noteRaw is num
        ? noteRaw.toDouble()
        : double.tryParse(noteRaw?.toString() ?? '') ?? userNote;

    final items = [
      {'v': '$total', 'l': 'Trajets effectués', 's': 'au total'},
      {'v': '$avenir', 'l': 'À venir', 's': 'confirmés / en attente'},
      {'v': '$terminees', 'l': 'Terminés', 's': 'avec succès'},
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

// ── Prochains trajets ─────────────────────────────────────────────────────────

class _UpcomingCard extends StatelessWidget {
  final List<ReservationModel> reservations;
  const _UpcomingCard({required this.reservations});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Inclure toutes les réservations actives; trier par date si disponible
    final upcoming = reservations
        .where((r) => r.statut == 'en_attente' || r.statut == 'confirmee')
        .toList()
      ..sort(
        (a, b) => (a.trajet?.dateHeureDepart ?? now)
            .compareTo(b.trajet?.dateHeureDepart ?? now),
      );
    final items = upcoming.take(3).toList();

    return KCard(
      child: Column(
        children: [
          KCardHeader(
            title: 'Prochains trajets',
            action: 'Voir tout',
            onAction: () => context.push('/passager/reservations'),
          ),
          if (items.isEmpty)
            KEmptyState(
              emoji: '🚗',
              message: 'Aucun trajet à venir',
              actionLabel: 'Rechercher un trajet',
              onAction: () => context.push('/passager/trajets'),
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
  final VoidCallback? onReturn;
  const _MessagesCard({required this.conversations, required this.prefix, this.onReturn});

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
            const KEmptyState(
              emoji: '💬',
              message: 'Aucune conversation',
            )
          else
            for (final c in items) _ConvRow(
              conv: c,
              prefix: prefix,
              onReturn: onReturn,
            ),
        ],
      ),
    );
  }
}

// ── Économies & impact ────────────────────────────────────────────────────────

class _EcoCard extends StatelessWidget {
  final Map<String, dynamic> eco;
  const _EcoCard({required this.eco});

  @override
  Widget build(BuildContext context) {
    // L'API /economie/mes_economies/ retourne total_economie et total_depense_kovoit
    final montantRaw = eco['total_economie'] ?? eco['economies_realisees'] ?? eco['montant_economise'];
    final montant = montantRaw is num ? montantRaw.toDouble() : 0.0;
    // CO2 vient de /statistiques/passager/ mais on l'estime ici si absent
    final co2Raw = eco['co2_economise'] ?? eco['co2'];
    final nbRes = eco['nombre_reservations'];
    final co2 = co2Raw is num
        ? co2Raw.toDouble()
        : (nbRes is num ? nbRes.toDouble() * 5 * 0.12 : 0.0);
    final fmt = NumberFormat('#,##0', 'fr_FR');

    return KCard(
      child: Column(
        children: [
          const KCardHeader(title: 'Économies & impact écologique'),
          Padding(
            padding: const EdgeInsets.all(KSpacing.xl),
            child: Row(
              children: [
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
                Container(width: 1, height: 40, color: KColors.border),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${fmt.format(montant)} FCFA',
                        style: KTextStyles.statValue
                            .copyWith(color: KColors.primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Économisé',
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

// ── Section trajets disponibles ───────────────────────────────────────────────

class _TrajetsDispoSection extends StatelessWidget {
  final AsyncValue<List<TrajetModel>> trajetsAsync;
  const _TrajetsDispoSection({required this.trajetsAsync});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Trajets disponibles',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const Spacer(),
            TextButton(
              onPressed: () => context.go('/passager/trajets'),
              child: const Text('Voir tout',
                  style: TextStyle(color: KColors.primary, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        trajetsAsync.when(
          loading: () => SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              itemBuilder: (_, _) => _TrajetCardMiniSkeleton(),
            ),
          ),
          error: (e, _) {
            debugPrint('[PassagerDash] trajets error: $e');
            return const SizedBox.shrink();
          },
          data: (trajets) {
            if (trajets.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: KColors.base100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: KColors.border),
                ),
                child: Row(children: [
                  const Icon(Icons.directions_car_outlined,
                      color: KColors.baseContentLow, size: 24),
                  const SizedBox(width: 12),
                  Text('Aucun trajet disponible en ce moment',
                      style: KTextStyles.caption),
                ]),
              );
            }
            return SizedBox(
              height: 130,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: trajets.length.clamp(0, 8),
                itemBuilder: (_, i) => _TrajetCardMini(
                  trajet: trajets[i],
                  onTap: () =>
                      context.push('/passager/trajet/${trajets[i].id}'),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TrajetCardMini extends StatelessWidget {
  final TrajetModel trajet;
  final VoidCallback onTap;
  const _TrajetCardMini({required this.trajet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: KColors.base100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  '${trajet.depart} → ${trajet.destination}',
                  style: KTextStyles.bodySm
                      .copyWith(fontWeight: FontWeight.w700, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text(
              Formatters.dateTime(trajet.dateHeureDepart),
              style: KTextStyles.meta,
              maxLines: 1,
            ),
            const Spacer(),
            Row(children: [
              Text(
                Formatters.currency(trajet.prixParPlace),
                style: KTextStyles.bodySm.copyWith(
                    color: KColors.primary, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: trajet.placesRestantes > 0
                      ? KColors.success.withValues(alpha: 0.1)
                      : KColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${trajet.placesRestantes} pl.',
                  style: KTextStyles.meta.copyWith(
                      color: trajet.placesRestantes > 0
                          ? KColors.success
                          : KColors.error),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _TrajetCardMiniSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: KColors.base100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KColors.border),
      ),
    );
  }
}

// ── Navigation rapide ─────────────────────────────────────────────────────────

class _PassagerQuickNav extends StatelessWidget {
  const _PassagerQuickNav();

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Column(
        children: [
          const KCardHeader(title: 'Navigation rapide'),
          KListTile(
            title: 'Rechercher un trajet',
            onTap: () => context.push('/passager/trajets'),
          ),
          KListTile(
            title: 'Mes réservations',
            onTap: () => context.push('/passager/reservations'),
          ),
          KListTile(
            title: 'Mes évaluations',
            onTap: () => context.push('/passager/evaluations'),
          ),
          KListTile(
            title: 'Économies & impact',
            onTap: () => context.push('/passager/economie'),
          ),
          KListTile(
            title: 'Profil & Paramètres',
            onTap: () => context.push('/passager/profile'),
          ),
          KListTile(
            title: 'Devenir conducteur',
            onTap: () => context.push('/passager/devenir-conducteur'),
          ),
        ],
      ),
    );
  }
}

// ── Widgets de ligne ──────────────────────────────────────────────────────────

class _ReservationRow extends StatelessWidget {
  final ReservationModel reservation;
  const _ReservationRow({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final trajet = reservation.trajet;
    final depart = trajet?.depart ?? '—';
    final dest = trajet?.destination ?? '—';
    final dateLabel =
        trajet != null ? _formatDate(trajet.dateHeureDepart) : '';

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
                if (dateLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(dateLabel, style: KTextStyles.meta),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          KBadge.fromStatut(reservation.statut),
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

class _ConvRow extends StatelessWidget {
  final ConversationModel conv;
  final String prefix;
  final VoidCallback? onReturn;
  const _ConvRow({required this.conv, required this.prefix, this.onReturn});

  @override
  Widget build(BuildContext context) {
    final hasUnread = conv.unreadCount > 0;
    return InkWell(
      onTap: () async {
        await context.push(
          '$prefix/messages/${conv.convId}'
          '?name=${Uri.encodeComponent(conv.userName)}'
          '&userId=${conv.userId}'
          '&statut=${conv.statut}',
        );
        onReturn?.call();
      },
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

// ── Bannière trajet en cours ──────────────────────────────────────────────────

class _ActiveTrajetBanner extends StatefulWidget {
  final ReservationModel reservation;
  const _ActiveTrajetBanner({required this.reservation});

  @override
  State<_ActiveTrajetBanner> createState() => _ActiveTrajetBannerState();
}

class _ActiveTrajetBannerState extends State<_ActiveTrajetBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opac;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _opac = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reservation;
    return GestureDetector(
      onTap: () {
        final t = r.trajet;
        var url = '/passager/trajet/${r.trajetId}/suivi'
            '?depart=${Uri.encodeComponent(t?.depart ?? '')}'
            '&destination=${Uri.encodeComponent(t?.destination ?? '')}'
            '&conducteur=${Uri.encodeComponent(t?.conducteurNom ?? '')}';
        if (t?.departLat != null) url += '&departLat=${t!.departLat}';
        if (t?.departLng != null) url += '&departLng=${t!.departLng}';
        if (t?.destinationLat != null) url += '&destinationLat=${t!.destinationLat}';
        if (t?.destinationLng != null) url += '&destinationLng=${t!.destinationLng}';
        context.push(url);
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(
            KSpacing.pagePaddingH, KSpacing.lg, KSpacing.pagePaddingH, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [KColors.successContent, KColors.success],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: KColors.success.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _opac,
              builder: (_, child) =>
                  Opacity(opacity: _opac.value, child: child),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_car_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Votre trajet est en cours',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${r.trajet?.depart ?? ''}  →  ${r.trajet?.destination ?? ''}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on_rounded,
                      size: 14, color: KColors.successContent),
                  const SizedBox(width: 4),
                  Text(
                    'Suivre',
                    style: TextStyle(
                      color: KColors.successContent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
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

class _DashboardErrorCard extends StatelessWidget {
  final String message;
  const _DashboardErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Row(children: [
          const Icon(Icons.wifi_off_rounded, color: KColors.baseContentMid, size: 20),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Données indisponibles', style: KTextStyles.bodySm),
              Text(
                'Tirez vers le bas pour réessayer',
                style: KTextStyles.meta,
              ),
            ]),
          ),
        ]),
      ),
    );
  }
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
