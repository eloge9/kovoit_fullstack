import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/trajet_provider.dart';
import '../models/trajet_model.dart';
import '../../reservations/providers/reservation_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_avatar.dart';
import '../../../core/widgets/k_badge.dart';

final _trajetDetailProvider = FutureProvider.family<TrajetModel, int>(
  (ref, id) => ref.watch(trajetRepositoryProvider).getTrajet(id),
);

class TrajetDetailPage extends ConsumerWidget {
  final int trajetId;
  final bool isConducteur;

  const TrajetDetailPage({
    super.key,
    required this.trajetId,
    this.isConducteur = false,
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
        data: (trajet) => _Body(
          trajet: trajet,
          isConducteur: isConducteur,
          onRefresh: () => ref.invalidate(_trajetDetailProvider(trajetId)),
        ),
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
  bool _starting = false;
  bool _ending = false;

  TrajetModel get t => widget.trajet;

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
                        label: 'Distance',
                        value: Formatters.distance(t.distanceKm),
                      ),
                      _InfoRow(
                        icon: Icons.payments_outlined,
                        label: 'Prix par place',
                        value: Formatters.currency(t.prixParPlace),
                        valueColor: KColors.primary,
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
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KSpacing.xl),

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
                      icon: const Icon(
                        Icons.message_outlined,
                        color: KColors.primary,
                      ),
                      // Navigate to conversations list; conv_id is available after reserving
                      onPressed: () => context.push('/passager/messages'),
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
                  '&conducteur=${Uri.encodeComponent(t.conducteurNom)}',
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
                isLoading: _starting,
                onPressed: _starting ? null : () => _commencer(context),
              ),
            if (t.statut == 'en_cours') ...[
              KButton(
                label: 'GPS — Position en direct',
                icon: Icons.my_location_rounded,
                onPressed: () => context.push(
                  '/conducteur/trajet/${t.id}/gps'
                  '?depart=${Uri.encodeComponent(t.depart)}'
                  '&destination=${Uri.encodeComponent(t.destination)}',
                ),
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

  Future<void> _reserver(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer la réservation'),
        content: Text(
          'Réserver une place sur le trajet\n'
          '${t.depart} → ${t.destination}\n'
          'pour ${Formatters.currency(t.prixParPlace)} ?',
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
    final ok = await ref.read(reservationsProvider.notifier).reserver(t.id);
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

  Future<void> _commencer(BuildContext context) async {
    setState(() => _starting = true);
    final ok = await ref.read(trajetsProvider.notifier).commencerTrajet(t.id);
    if (!context.mounted) return;
    setState(() => _starting = false);
    if (ok) {
      widget.onRefresh();
      context.push(
        '/conducteur/trajet/${t.id}/gps'
        '?depart=${Uri.encodeComponent(t.depart)}'
        '&destination=${Uri.encodeComponent(t.destination)}',
      );
    }
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
