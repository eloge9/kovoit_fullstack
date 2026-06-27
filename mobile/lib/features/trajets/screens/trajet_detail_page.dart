import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../providers/trajet_provider.dart';
import '../models/trajet_model.dart';
import '../../reservations/providers/reservation_provider.dart';
import '../../reservations/models/reservation_model.dart';
import '../../reservations/repositories/reservation_repository.dart';
import '../../../core/network/api_interceptor.dart';
import '../../../core/services/osrm_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_avatar.dart';
import '../../../core/widgets/k_badge.dart';
import '../../messagerie/repositories/messagerie_repository.dart';
import '../../reservations/screens/qr_scanner_page.dart';

final _trajetDetailProvider = FutureProvider.family<TrajetModel, int>(
  (ref, id) => ref.watch(trajetRepositoryProvider).getTrajet(id),
);

class TrajetDetailPage extends ConsumerWidget {
  final int trajetId;
  final bool isConducteur;
  // Matching transmis depuis la liste de recherche (contient prix segment + coords)
  final MatchingInfo? matching;

  const TrajetDetailPage({
    super.key,
    required this.trajetId,
    this.isConducteur = false,
    this.matching,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trajetAsync = ref.watch(_trajetDetailProvider(trajetId));

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: KColors.baseContent),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Détail du trajet',
          style: KTextStyles.bodySm.copyWith(
            fontWeight: FontWeight.w700,
            color: KColors.baseContent,
          ),
        ),
        actions: [
          trajetAsync.maybeWhen(
            data: (t) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: KBadge.fromStatut(t.statut),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: trajetAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: KColors.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: KColors.baseContentMid,
              ),
              const SizedBox(height: 12),
              Text(
                e.toString(),
                style: KTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              KButton(
                label: 'Réessayer',
                variant: KButtonVariant.outline,
                onPressed: () => ref.invalidate(_trajetDetailProvider(trajetId)),
              ),
            ],
          ),
        ),
        data: (trajet) {
          // Injecter le matching de la recherche s'il est disponible
          final t = matching != null
              ? trajet.copyWith(matching: matching)
              : trajet;
          return _Body(
            trajet: t,
            isConducteur: isConducteur,
            onRefresh: () => ref.invalidate(_trajetDetailProvider(trajetId)),
          );
        },
      ),
    );
  }
}

// ── Corps principal ────────────────────────────────────────────────────────────

class _Body extends ConsumerStatefulWidget {
  final TrajetModel trajet;
  final bool isConducteur;
  final VoidCallback onRefresh;

  const _Body({
    required this.trajet,
    required this.isConducteur,
    required this.onRefresh,
  });

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _reserving = false;
  bool _ending = false;
  bool _messaging = false;

  List<ReservationModel>? _passagers;
  bool _loadingPassagers = false;
  String? _codeError;
  bool _validating = false;
  final _codeCtrl = TextEditingController();

  TrajetModel get t => widget.trajet;

  @override
  void initState() {
    super.initState();
    if (widget.isConducteur) _chargerPassagers();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _chargerPassagers() async {
    if (!mounted) return;
    setState(() => _loadingPassagers = true);
    try {
      final list = await ReservationRepository().passagersTrajet(t.id);
      if (mounted) setState(() { _passagers = list; _loadingPassagers = false; });
    } catch (e) {
      if (mounted) setState(() { _passagers = []; _loadingPassagers = false; });
    }
  }

  Future<void> _validerCode() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _codeError = 'Entrez le code KVT du passager.');
      return;
    }
    setState(() { _validating = true; _codeError = null; });
    try {
      await ReservationRepository().embarquer(code);
      _codeCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passager embarqué !'), backgroundColor: KColors.success),
      );
      _chargerPassagers();
    } catch (e) {
      if (mounted) {
        setState(() {
          _codeError = e is ApiException ? e.message : 'Code invalide.';
        });
      }
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: KColors.primary,
      onRefresh: () async => widget.onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(KSpacing.pagePaddingH),
        children: [
          const SizedBox(height: KSpacing.lg),

          // ── Route card ─────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [KColors.primary, KColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(KSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.trip_origin,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Départ',
                            style: KTextStyles.caption.copyWith(
                              color: Colors.white60,
                            ),
                          ),
                          Text(
                            t.depart,
                            style: KTextStyles.bodySm.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 7),
                  child: Container(
                    width: 2,
                    height: 20,
                    color: Colors.white30,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: KColors.warning.withValues(alpha: 0.9),
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Arrivée',
                            style: KTextStyles.caption.copyWith(
                              color: Colors.white60,
                            ),
                          ),
                          Text(
                            t.destination,
                            style: KTextStyles.bodySm.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpacing.xl),

          // ── Carte interactive ──────────────────────────────────────────
          if (t.departLat != null && t.destinationLat != null)
            _TrajetMapCard(trajet: t),

          if (t.departLat != null && t.destinationLat != null)
            const SizedBox(height: KSpacing.xl),

          // ── Infos matching (si résultat de recherche géo) ─────────────
          if (t.matching != null) ...[
            _MatchingCard(matching: t.matching!),
            const SizedBox(height: KSpacing.xl),
          ],

          // ── Infos principales ──────────────────────────────────────────
          KCard(
            child: Column(
              children: [
                const KCardHeader(title: 'Informations'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    KSpacing.xl,
                    0,
                    KSpacing.xl,
                    KSpacing.xl,
                  ),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Date & heure',
                        value: Formatters.dateTime(t.dateHeureDepart),
                      ),
                      _InfoRow(
                        icon: Icons.straighten_rounded,
                        label: 'Distance totale',
                        value: Formatters.distance(t.distanceKm),
                      ),
                      if (t.matching != null && t.matching!.distancePassagerKm > 0)
                        _InfoRow(
                          icon: Icons.route_outlined,
                          label: 'Votre segment',
                          value: Formatters.distance(t.matching!.distancePassagerKm),
                          valueColor: KColors.info,
                        ),
                      _InfoRow(
                        icon: Icons.payments_outlined,
                        label: t.matching != null ? 'Prix votre trajet' : 'Prix par place',
                        value: Formatters.currency(t.prixAffiche),
                        valueColor: KColors.primary,
                      ),
                      if (t.matching != null && t.matching!.prixPassager != t.prixParPlace.toInt())
                        _InfoRow(
                          icon: Icons.info_outline,
                          label: 'Prix conducteur/place',
                          value: Formatters.currency(t.prixParPlace),
                        ),
                      _InfoRow(
                        icon: Icons.people_outline,
                        label: 'Places disponibles',
                        value: '${t.placesRestantes} / ${t.placesDisponibles}',
                        valueColor: t.placesRestantes > 0
                            ? KColors.success
                            : KColors.error,
                      ),
                      if (t.vehicule != null)
                        _InfoRow(
                          icon: Icons.directions_car_outlined,
                          label: 'Véhicule',
                          value: t.vehicule!.displayName,
                        )
                      else if (t.typeVehicule != null)
                        _InfoRow(
                          icon: Icons.directions_car_outlined,
                          label: 'Type véhicule',
                          value: t.typeVehicule!,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpacing.xl),

          // ── Passagers (vue conducteur) ────────────────────────────
          if (widget.isConducteur) ...[
            _PassagersSection(
              passagers: _passagers,
              loading: _loadingPassagers,
              trajetId: t.id,
              codeCtrl: _codeCtrl,
              codeError: _codeError,
              validating: _validating,
              onRefresh: _chargerPassagers,
              onValiderCode: _validerCode,
              onScannerQr: () async {
                final ok = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const QrScannerPage()),
                );
                if (ok == true) _chargerPassagers();
              },
              onMessage: (convId, nom) => context.push(
                '/conducteur/messages/$convId?name=${Uri.encodeComponent(nom)}',
              ),
            ),
            const SizedBox(height: KSpacing.xl),
          ],

          // ── Conducteur (vue passager) ──────────────────────────────────
          if (!widget.isConducteur) ...[
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.xl),
                child: Row(
                  children: [
                    KAvatar(
                      name: t.conducteurNom,
                      photoUrl: t.conducteurPhoto,
                      size: 44,
                    ),
                    const SizedBox(width: KSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.conducteurNom,
                            style: KTextStyles.bodySm.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: KColors.warning,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                t.conducteurNote.toStringAsFixed(1),
                                style: KTextStyles.caption,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: _messaging
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: KColors.primary,
                              ),
                            )
                          : const Icon(
                              Icons.message_outlined,
                              color: KColors.primary,
                            ),
                      onPressed: _messaging
                          ? null
                          : () => _ecrireAuConducteur(context),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: KSpacing.xl),
          ],

          // ── Actions passager ───────────────────────────────────────────
          if (!widget.isConducteur) ...[
            if (t.isAvailable)
              KButton(
                label: 'Réserver cette place',
                icon: Icons.bookmark_add_rounded,
                isLoading: _reserving,
                onPressed: _reserving ? null : () => _reserver(context),
              ),
            if (t.statut == 'en_cours')
              KButton(
                label: 'Suivre le trajet en direct',
                icon: Icons.location_on_rounded,
                onPressed: () => context.push(
                  '/passager/trajet/${t.id}/suivi'
                  '?depart=${Uri.encodeComponent(t.depart)}'
                  '&destination=${Uri.encodeComponent(t.destination)}'
                  '&conducteur=${Uri.encodeComponent(t.conducteurNom)}'
                  '&departLat=${t.departLat ?? ""}'
                  '&departLng=${t.departLng ?? ""}'
                  '&destinationLat=${t.destinationLat ?? ""}'
                  '&destinationLng=${t.destinationLng ?? ""}',
                ),
              ),
          ],

          // ── Actions conducteur ─────────────────────────────────────────
          if (widget.isConducteur) ...[
            if (t.statut == 'ouvert')
              KButton(
                label: 'Commencer le trajet',
                icon: Icons.play_circle_rounded,
                variant: KButtonVariant.success,
                onPressed: () async {
                  await context.push(
                    '/conducteur/trajet/${t.id}/depart'
                    '?depart=${Uri.encodeComponent(t.depart)}'
                    '&destination=${Uri.encodeComponent(t.destination)}'
                    '&departLat=${t.departLat ?? ""}'
                    '&departLng=${t.departLng ?? ""}'
                    '&destinationLat=${t.destinationLat ?? ""}'
                    '&destinationLng=${t.destinationLng ?? ""}',
                  );
                  widget.onRefresh();
                },
              ),
            if (t.statut == 'en_cours') ...[
              KButton(
                label: 'Suivre sur GPS',
                icon: Icons.navigation_rounded,
                variant: KButtonVariant.success,
                onPressed: () async {
                  await context.push(
                    '/conducteur/trajet/${t.id}/gps'
                    '?depart=${Uri.encodeComponent(t.depart)}'
                    '&destination=${Uri.encodeComponent(t.destination)}'
                    '&departLat=${t.departLat ?? ""}'
                    '&departLng=${t.departLng ?? ""}'
                    '&destinationLat=${t.destinationLat ?? ""}'
                    '&destinationLng=${t.destinationLng ?? ""}',
                  );
                  widget.onRefresh();
                },
              ),
              const SizedBox(height: KSpacing.md),
              KButton(
                label: 'Terminer le trajet',
                icon: Icons.flag_rounded,
                variant: KButtonVariant.error,
                isLoading: _ending,
                onPressed: _ending ? null : () => _terminer(context),
              ),
            ],
          ],

          const SizedBox(height: KSpacing.xxl),
        ],
      ),
    );
  }

  Future<void> _ecrireAuConducteur(BuildContext context) async {
    if (_messaging) return;
    setState(() => _messaging = true);
    try {
      debugPrint('[TrajetDetail] Chargement conversations pour conducteur ${t.conducteurId}');
      final conversations = await MessagerieRepository().getConversations();
      debugPrint('[TrajetDetail] ${conversations.length} conversations trouvées');

      // Chercher une conversation avec ce conducteur
      final matching = conversations.where((c) => c.userId == t.conducteurId);

      if (!context.mounted) return;

      if (matching.isNotEmpty) {
        final conv = matching.first;
        debugPrint('[TrajetDetail] Conversation trouvée: ${conv.convId}');
        context.push(
          '/passager/messages/${conv.convId}'
          '?name=${Uri.encodeComponent(conv.userName)}'
          '&userId=${Uri.encodeComponent(conv.userId)}',
        );
      } else {
        debugPrint('[TrajetDetail] Aucune conversation avec ce conducteur');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Réservez ce trajet pour contacter le conducteur.'),
            backgroundColor: KColors.warning,
          ),
        );
      }
    } catch (e) {
      debugPrint('[TrajetDetail] ecrireAuConducteur error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: KColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _messaging = false);
    }
  }

  Future<void> _reserver(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer la réservation'),
        content: Text(
          'Réserver une place sur le trajet\n'
          '${t.matching != null ? "${t.matching!.distancePassagerKm.toStringAsFixed(0)} km — " : ""}'
          '${t.depart} → ${t.destination}\n'
          'pour ${Formatters.currency(t.prixAffiche)} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: KColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Confirmer',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    setState(() => _reserving = true);
    final ok = await ref.read(reservationsProvider.notifier).reserver(
      t.id,
      priseEnChargeLat: t.matching?.pickupLat,
      priseEnChargeLng: t.matching?.pickupLng,
      deposeLat: t.matching?.dropoffLat,
      deposeLng: t.matching?.dropoffLng,
    );
    if (!context.mounted) return;
    setState(() => _reserving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Réservation effectuée ! En attente de confirmation.'
              : ref.read(reservationsProvider).error ??
                    'Erreur lors de la réservation',
        ),
        backgroundColor: ok ? KColors.success : KColors.error,
      ),
    );
    if (ok) context.pop();
  }

  Future<void> _terminer(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Terminer le trajet ?'),
        content: const Text(
          'Confirmez-vous la fin du trajet ? Les passagers seront notifiés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: KColors.success),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Terminer',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    setState(() => _ending = true);
    final ok = await ref.read(trajetsProvider.notifier).terminerTrajet(t.id);
    if (!context.mounted) return;
    setState(() => _ending = false);
    if (ok) {
      widget.onRefresh();
      context.pop();
    }
  }
}

// ── Carte matching géo ────────────────────────────────────────────────────────

class _MatchingCard extends StatelessWidget {
  final MatchingInfo matching;
  const _MatchingCard({required this.matching});

  @override
  Widget build(BuildContext context) {
    final score = matching.score;
    final color = score >= 70
        ? KColors.success
        : score >= 50
            ? KColors.warning
            : KColors.error;

    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.radar, size: 16, color: KColors.primary),
              const SizedBox(width: 8),
              const Text('Compatibilité avec votre trajet',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$score%',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: score / 100,
              backgroundColor: KColors.base300,
              color: color,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 12),
            if (matching.distancePickupKm != null)
              _MatchingRow(
                icon: Icons.near_me_outlined,
                label: 'Distance à votre point de départ',
                value: _formatDist(matching.distancePickupKm!),
                color: KColors.info,
              ),
            if (matching.distanceDropoffKm != null)
              _MatchingRow(
                icon: Icons.flag_outlined,
                label: 'Distance à votre point d\'arrivée',
                value: _formatDist(matching.distanceDropoffKm!),
                color: KColors.info,
              ),
            if (matching.distancePassagerKm > 0)
              _MatchingRow(
                icon: Icons.route_outlined,
                label: 'Votre segment de trajet',
                value: '${matching.distancePassagerKm.toStringAsFixed(1)} km',
              ),
            if (matching.prixPassager > 0)
              _MatchingRow(
                icon: Icons.payments_outlined,
                label: 'Prix pour votre trajet',
                value: Formatters.currency(matching.prixPassager.toDouble()),
                color: KColors.primary,
              ),
            if (matching.raison.isNotEmpty && matching.raison != 'Trajet compatible')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(matching.raison,
                    style: KTextStyles.caption
                        .copyWith(color: KColors.baseContentMid)),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDist(double km) {
    if (km < 1) return '${(km * 1000).toInt()} m';
    return '${km.toStringAsFixed(1)} km';
  }
}

class _MatchingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _MatchingRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: color ?? KColors.baseContentMid),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: KTextStyles.caption)),
        Text(value,
            style: KTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: color ?? KColors.baseContent,
            )),
      ]),
    );
  }
}

// ── Widgets locaux ────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: KColors.baseContentMid),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: KTextStyles.caption)),
          Text(
            value,
            style: KTextStyles.bodySm.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor ?? KColors.baseContent,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carte interactive trajet ──────────────────────────────────────────────────

class _TrajetMapCard extends StatefulWidget {
  final TrajetModel trajet;
  const _TrajetMapCard({required this.trajet});

  @override
  State<_TrajetMapCard> createState() => _TrajetMapCardState();
}

class _TrajetMapCardState extends State<_TrajetMapCard> {
  final _mapController = MapController();
  List<LatLng> _routePoints = [];
  bool _loaded = false;

  TrajetModel get t => widget.trajet;

  @override
  void initState() {
    super.initState();
    _chargerRoute();
  }

  Future<void> _chargerRoute() async {
    if (t.polylineOsrm != null && t.polylineOsrm!.isNotEmpty) {
      try {
        final points = OsrmService.decodePolyline(t.polylineOsrm!);
        if (!mounted) return;
        setState(() { _routePoints = points; _loaded = true; });
        _fitRoute();
        return;
      } catch (_) {}
    }
    if (t.departLat == null || t.destinationLat == null) return;
    final route = await OsrmService.getRoute(
      t.departLat!, t.departLng!,
      t.destinationLat!, t.destinationLng!,
    );
    if (!mounted) return;
    if (route != null) {
      setState(() { _routePoints = route.points; _loaded = true; });
      _fitRoute();
    }
  }

  void _fitRoute() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _routePoints.isEmpty) return;
      _mapController.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(_routePoints),
        padding: const EdgeInsets.all(40),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final departPoint = t.departLat != null
        ? LatLng(t.departLat!, t.departLng!)
        : null;
    final destPoint = t.destinationLat != null
        ? LatLng(t.destinationLat!, t.destinationLng!)
        : null;
    final center = departPoint ?? const LatLng(6.1375, 1.2123);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(color: KColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 11,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.kovoit.mobile',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(points: _routePoints, strokeWidth: 4,
                      color: KColors.primary),
                ]),
              MarkerLayer(markers: [
                if (departPoint != null)
                  Marker(point: departPoint, width: 30, height: 30,
                      child: _Pin(color: KColors.primary,
                          icon: Icons.trip_origin)),
                if (destPoint != null)
                  Marker(point: destPoint, width: 30, height: 30,
                      child: _Pin(color: KColors.error,
                          icon: Icons.location_on)),
              ]),
            ],
          ),
          if (!_loaded)
            Container(
              color: KColors.base200,
              child: const Center(child: CircularProgressIndicator(
                  color: KColors.primary, strokeWidth: 2)),
            ),
          Positioned(
            top: 8, left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.map_outlined, size: 12, color: KColors.primary),
                const SizedBox(width: 4),
                Text('Itinéraire',
                    style: KTextStyles.meta.copyWith(
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Section passagers conducteur ──────────────────────────────────────────────

class _PassagersSection extends StatelessWidget {
  final List<ReservationModel>? passagers;
  final bool loading;
  final int trajetId;
  final TextEditingController codeCtrl;
  final String? codeError;
  final bool validating;
  final VoidCallback onRefresh;
  final VoidCallback onValiderCode;
  final VoidCallback onScannerQr;
  final void Function(int convId, String nom) onMessage;

  const _PassagersSection({
    required this.passagers,
    required this.loading,
    required this.trajetId,
    required this.codeCtrl,
    required this.codeError,
    required this.validating,
    required this.onRefresh,
    required this.onValiderCode,
    required this.onScannerQr,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    final list = passagers ?? [];
    final nbEmbarques = list.where((r) => r.isEmbarque).length;
    final nbTotal = list.where((r) => r.isConfirmee).length;

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(KSpacing.xl, KSpacing.xl, KSpacing.sm, 0),
            child: Row(
              children: [
                const Icon(Icons.people_rounded, size: 16, color: KColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loading
                        ? 'Passagers'
                        : list.isEmpty
                            ? 'Passagers (aucun)'
                            : 'Passagers (${list.length})',
                    style: KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (nbTotal > 0)
                  _EmbarqueProgress(embarques: nbEmbarques, total: nbTotal),
                // Bouton scanner QR
                if (nbTotal > 0 && nbEmbarques < nbTotal)
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: KColors.primary),
                    tooltip: 'Scanner QR passager',
                    onPressed: onScannerQr,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                IconButton(
                  icon: loading
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: KColors.primary),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18, color: KColors.baseContentMid),
                  onPressed: loading ? null : onRefresh,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          // ── Contenu ─────────────────────────────────────────────────
          if (loading && passagers == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: KColors.primary, strokeWidth: 2)),
            )
          else if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(KSpacing.xl),
              child: Text(
                'Aucune réservation pour ce trajet.',
                style: KTextStyles.caption.copyWith(color: KColors.baseContentMid),
              ),
            )
          else ...[
            const Divider(height: 1, color: KColors.border),
            ...list.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              return Column(
                children: [
                  _PassagerRow(
                    reservation: r,
                    onMessage: r.conversationId != null
                        ? () => onMessage(r.conversationId!, r.passagerNom)
                        : null,
                    onScanOrValider: onScannerQr,
                  ),
                  if (i < list.length - 1)
                    const Divider(height: 1, color: KColors.border, indent: 16, endIndent: 16),
                ],
              );
            }),
          ],

          // ── Valider un embarquement ─────────────────────────────────
          if (list.any((r) => r.isConfirmee)) ...[
            const Divider(height: 1, color: KColors.border),
            Padding(
              padding: const EdgeInsets.all(KSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.confirmation_number_outlined, size: 15, color: KColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Valider un embarquement',
                        style: KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(
                            letterSpacing: 2,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            hintText: 'KVT-XXXX',
                            errorText: codeError,
                            isDense: true,
                            prefixIcon: const Icon(Icons.qr_code_rounded, size: 18, color: KColors.primary),
                            filled: true,
                            fillColor: KColors.base200,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: KColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: KColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: KColors.primary, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: KColors.error),
                            ),
                          ),
                          onSubmitted: (_) => onValiderCode(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: KColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onPressed: validating ? null : onValiderCode,
                          child: validating
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Badge progression embarquement ────────────────────────────────────────────

class _EmbarqueProgress extends StatelessWidget {
  final int embarques;
  final int total;
  const _EmbarqueProgress({required this.embarques, required this.total});

  @override
  Widget build(BuildContext context) {
    final allDone = embarques >= total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: allDone
            ? KColors.success.withValues(alpha: 0.12)
            : KColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$embarques/$total embarqué${embarques > 1 ? 's' : ''}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: allDone ? KColors.success : KColors.warning,
        ),
      ),
    );
  }
}

// ── Ligne passager ────────────────────────────────────────────────────────────

class _PassagerRow extends StatelessWidget {
  final ReservationModel reservation;
  final VoidCallback? onMessage;
  final VoidCallback? onScanOrValider;
  const _PassagerRow({required this.reservation, this.onMessage, this.onScanOrValider});

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final embarque = r.isEmbarque;
    final confirmee = r.isConfirmee;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.xl, vertical: KSpacing.md),
      child: Row(
        children: [
          // Avatar + pastille
          Stack(
            children: [
              KAvatar(name: r.passagerNom, photoUrl: r.passagerPhoto, size: 40),
              if (confirmee)
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    width: 13, height: 13,
                    decoration: BoxDecoration(
                      color: embarque ? KColors.success : KColors.warning,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),

          // Nom + places + badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.passagerNom.isEmpty ? 'Passager' : r.passagerNom,
                  style: KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Text('${r.placesReservees} place${r.placesReservees > 1 ? 's' : ''}',
                        style: KTextStyles.meta),
                    const SizedBox(width: 6),
                    _StatutBadge(statut: r.statut, embarque: embarque),
                  ],
                ),
              ],
            ),
          ),

          // Bouton scanner (si confirmée et pas encore embarquée)
          if (confirmee && !embarque && onScanOrValider != null)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: KColors.primary),
              tooltip: 'Valider l\'embarquement',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              onPressed: onScanOrValider,
            )
          else
            const SizedBox(width: 34),

          // Bouton message
          if (onMessage != null)
            IconButton(
              icon: const Icon(Icons.message_rounded, size: 19, color: KColors.primary),
              tooltip: 'Écrire au passager',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              onPressed: onMessage,
            )
          else
            const SizedBox(width: 34),
        ],
      ),
    );
  }
}

// ── Badge statut réservation ──────────────────────────────────────────────────

class _StatutBadge extends StatelessWidget {
  final String statut;
  final bool embarque;
  const _StatutBadge({required this.statut, required this.embarque});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (statut) {
      case 'confirmee':
        color = embarque ? KColors.success : KColors.info;
        label = embarque ? 'Embarqué' : 'Confirmé';
        break;
      case 'en_attente':
        color = KColors.warning;
        label = 'En attente';
        break;
      default:
        color = KColors.baseContentMid;
        label = statut;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _Pin({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color, shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 13),
      );
}
