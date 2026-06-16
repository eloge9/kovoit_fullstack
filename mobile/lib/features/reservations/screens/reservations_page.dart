import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/reservation_provider.dart';
import '../models/reservation_model.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_badge.dart';
import '../../../core/widgets/k_avatar.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/services/notification_service.dart';

class ReservationsPage extends ConsumerStatefulWidget {
  final bool isConducteur;
  const ReservationsPage({super.key, this.isConducteur = false});

  @override
  ConsumerState<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends ConsumerState<ReservationsPage> {
  final _confirmingIds = <int>{};
  final _decliningIds = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (widget.isConducteur) {
      await ref.read(reservationsProvider.notifier).loadReservationsRecues();
    } else {
      await ref.read(reservationsProvider.notifier).loadMesReservations();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reservationsProvider);
    final list = widget.isConducteur
        ? state.reservationsRecues
        : state.mesReservations;
    final prefix = widget.isConducteur ? '/conducteur' : '/passager';

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        title: Row(children: [
          Image.asset('assets/logos/logo1.png', width: 22, height: 22),
          const SizedBox(width: 8),
          Text(
            widget.isConducteur ? 'Demandes reçues' : 'Mes réservations',
            style: KTextStyles.bodySm.copyWith(
              fontWeight: FontWeight.w700, color: KColors.baseContent,
            ),
          ),
        ]),
      ),
      body: RefreshIndicator(
        color: KColors.primary,
        onRefresh: _load,
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator(color: KColors.primary))
            : list.isEmpty
                ? KEmptyState(
                    emoji: '🎫',
                    message: widget.isConducteur
                        ? 'Aucune demande de réservation reçue.'
                        : 'Vous n\'avez pas encore de réservation.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(KSpacing.pagePaddingH),
                    itemCount: list.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: KSpacing.md),
                      child: _ReservationCard(
                        reservation: list[i],
                        isConducteur: widget.isConducteur,
                        prefix: prefix,
                        isConfirming: _confirmingIds.contains(list[i].id),
                        isDeclining: _decliningIds.contains(list[i].id),
                        onConfirmer: () => _confirmer(list[i]),
                        onDecliner: () => _decliner(list[i]),
                        onAnnuler: () => _annuler(list[i]),
                      ),
                    ),
                  ),
      ),
    );
  }

  Future<void> _confirmer(ReservationModel r) async {
    setState(() => _confirmingIds.add(r.id));
    final ok = await ref.read(reservationsProvider.notifier).confirmer(r.id);
    if (!mounted) return;
    setState(() => _confirmingIds.remove(r.id));
    if (ok) {
      NotificationService.reservationConfirmee(r.passagerNom);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Réservation confirmée !'),
        backgroundColor: KColors.success,
      ));
    }
  }

  Future<void> _decliner(ReservationModel r) async {
    setState(() => _decliningIds.add(r.id));
    final ok = await ref.read(reservationsProvider.notifier).decliner(r.id);
    if (!mounted) return;
    setState(() => _decliningIds.remove(r.id));
    if (ok) {
      NotificationService.reservationRefusee(r.passagerNom);
    }
  }

  Future<void> _annuler(ReservationModel r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler la réservation ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oui, annuler', style: TextStyle(color: KColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(reservationsProvider.notifier).annuler(r.id);
    }
  }
}

// ── Carte réservation ─────────────────────────────────────────────────────────

class _ReservationCard extends StatelessWidget {
  final ReservationModel reservation;
  final bool isConducteur;
  final String prefix;
  final bool isConfirming, isDeclining;
  final VoidCallback onConfirmer, onDecliner, onAnnuler;

  const _ReservationCard({
    required this.reservation,
    required this.isConducteur,
    required this.prefix,
    required this.isConfirming,
    required this.isDeclining,
    required this.onConfirmer,
    required this.onDecliner,
    required this.onAnnuler,
  });

  ReservationModel get r => reservation;

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── En-tête ──────────────────────────────────────────────────
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '${r.trajet?.depart ?? '?'} → ${r.trajet?.destination ?? '?'}',
                style: KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
              if (r.trajet != null) ...[
                const SizedBox(height: 2),
                Text(Formatters.dateTime(r.trajet!.dateHeureDepart),
                    style: KTextStyles.meta),
              ],
            ])),
            KBadge.fromStatut(r.statut),
          ]),
          const SizedBox(height: KSpacing.md),

          // ── Détails ──────────────────────────────────────────────────
          Row(children: [
            if (isConducteur) ...[
              KAvatar(name: r.passagerNom, size: 28),
              const SizedBox(width: 8),
              Text(r.passagerNom, style: KTextStyles.caption),
              const Spacer(),
            ],
            Text(
              Formatters.currency(r.montantTotal),
              style: KTextStyles.bodySm.copyWith(
                color: KColors.primary, fontWeight: FontWeight.w700,
              ),
            ),
          ]),

          // ── Actions ───────────────────────────────────────────────────
          if (_hasActions) ...[
            const SizedBox(height: KSpacing.lg),
            const Divider(color: KColors.border),
            const SizedBox(height: KSpacing.lg),
            _buildActions(context),
          ],
        ]),
      ),
    );
  }

  bool get _hasActions {
    if (isConducteur && r.isEnAttente) return true;
    if (!isConducteur && r.isConfirmee) return true;
    if (!isConducteur && r.isEnAttente) return true;
    if (!isConducteur && r.isTerminee) return true;
    if (!isConducteur && r.trajet?.statut == 'en_cours') return true;
    return false;
  }

  Widget _buildActions(BuildContext context) {
    // Conducteur : confirmer / décliner
    if (isConducteur && r.isEnAttente) {
      return Row(children: [
        Expanded(child: KButton(
          label: 'Confirmer',
          icon: Icons.check_rounded,
          variant: KButtonVariant.success,
          isLoading: isConfirming,
          onPressed: isConfirming ? null : onConfirmer,
        )),
        const SizedBox(width: KSpacing.md),
        Expanded(child: KButton(
          label: 'Décliner',
          icon: Icons.close_rounded,
          variant: KButtonVariant.error,
          isLoading: isDeclining,
          onPressed: isDeclining ? null : onDecliner,
        )),
      ]);
    }

    // Passager : payer
    if (!isConducteur && r.isConfirmee) {
      return Column(children: [
        KButton(
          label: 'Payer ma place',
          icon: Icons.payments_rounded,
          onPressed: () => context.push('$prefix/paiement/${r.id}'),
        ),
        if (r.trajet?.statut == 'en_cours') ...[
          const SizedBox(height: KSpacing.md),
          KButton(
            label: 'Suivre le trajet en direct',
            icon: Icons.location_on_rounded,
            variant: KButtonVariant.outline,
            onPressed: () => context.push(
              '$prefix/trajet/${r.trajetId}/suivi'
              '?depart=${Uri.encodeComponent(r.trajet?.depart ?? '')}'
              '&destination=${Uri.encodeComponent(r.trajet?.destination ?? '')}'
              '&conducteur=${Uri.encodeComponent(r.trajet?.conducteurNom ?? '')}',
            ),
          ),
        ],
      ]);
    }

    // Passager : annuler si en attente
    if (!isConducteur && r.isEnAttente) {
      return KButton(
        label: 'Annuler la réservation',
        variant: KButtonVariant.error,
        onPressed: onAnnuler,
      );
    }

    // Passager : évaluer si terminée
    if (!isConducteur && r.isTerminee) {
      return KButton(
        label: 'Évaluer le conducteur',
        icon: Icons.star_rounded,
        variant: KButtonVariant.outline,
        onPressed: () => context.push(
          '$prefix/evaluation/${r.trajetId}/${r.trajet?.conducteurId ?? ''}',
        ),
      );
    }

    // Passager : suivi si trajet en cours (hors statut confirmée)
    if (!isConducteur && r.trajet?.statut == 'en_cours') {
      return KButton(
        label: 'Suivre le trajet en direct',
        icon: Icons.location_on_rounded,
        onPressed: () => context.push(
          '$prefix/trajet/${r.trajetId}/suivi'
          '?depart=${Uri.encodeComponent(r.trajet?.depart ?? '')}'
          '&destination=${Uri.encodeComponent(r.trajet?.destination ?? '')}'
          '&conducteur=${Uri.encodeComponent(r.trajet?.conducteurNom ?? '')}',
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
