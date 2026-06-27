import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/reservation_model.dart';
import '../repositories/reservation_repository.dart';
import '../../messagerie/repositories/messagerie_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_avatar.dart';
import '../../../core/widgets/k_badge.dart';

// ── Page détail réservation ───────────────────────────────────────────────────
// Gère tous les états : en_attente, confirmee, en_cours, terminee, annulee.

class ReservationDetailPage extends ConsumerStatefulWidget {
  final int reservationId;
  final ReservationModel? initialData;
  final bool isConducteur;

  const ReservationDetailPage({
    super.key,
    required this.reservationId,
    this.initialData,
    this.isConducteur = false,
  });

  @override
  ConsumerState<ReservationDetailPage> createState() =>
      _ReservationDetailPageState();
}

class _ReservationDetailPageState extends ConsumerState<ReservationDetailPage>
    with SingleTickerProviderStateMixin {
  ReservationModel? _reservation;
  bool _loading = false;
  String? _error;
  bool _annulerLoading = false;
  bool _especeLoading = false;
  bool _ajouterPlacesLoading = false;
  bool _groupeChatLoading = false;

  // Pulsing animation for live tracking banner
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _reservation = widget.initialData;

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Auto-redirect passager to live tracking if trajet is en_cours
    if (!widget.isConducteur && _reservation?.trajet?.statut == 'en_cours') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToSuivi());
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _goToSuivi() {
    final r = _reservation;
    if (r == null || !mounted) return;
    final t = r.trajet;
    var url = '/passager/trajet/${r.trajetId}/suivi'
        '?depart=${Uri.encodeComponent(t?.depart ?? '')}'
        '&destination=${Uri.encodeComponent(t?.destination ?? '')}'
        '&conducteur=${Uri.encodeComponent(t?.conducteurNom ?? '')}';
    if (t?.departLat != null) url += '&departLat=${t!.departLat}';
    if (t?.departLng != null) url += '&departLng=${t!.departLng}';
    if (t?.destinationLat != null) url += '&destinationLat=${t!.destinationLat}';
    if (t?.destinationLng != null) url += '&destinationLng=${t!.destinationLng}';
    debugPrint('[ReservationDetail] _goToSuivi: $url');
    context.pushReplacement(url);
  }

  @override
  Widget build(BuildContext context) {
    final r = _reservation;

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
          'Détail réservation',
          style: KTextStyles.bodySm.copyWith(
            fontWeight: FontWeight.w700,
            color: KColors.baseContent,
          ),
        ),
        actions: [
          if (r != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: KBadge.fromStatut(r.statut)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KColors.primary))
          : _error != null
              ? _buildError()
              : r == null
                  ? const Center(child: CircularProgressIndicator(color: KColors.primary))
                  : _buildBody(context, r),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: KColors.error),
          const SizedBox(height: 12),
          Text(_error!, style: KTextStyles.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, ReservationModel r) {
    final isEnCours = r.trajet?.statut == 'en_cours';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.pagePaddingH, KSpacing.lg,
        KSpacing.pagePaddingH, 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Bannière trajet en cours ──────────────────────────────────
          if (isEnCours && !widget.isConducteur) ...[
            _LiveTrajetBanner(
              reservation: r,
              pulseAnim: _pulseAnim,
              onTap: _goToSuivi,
            ),
            const SizedBox(height: KSpacing.lg),
          ],

          // ── Itinéraire ────────────────────────────────────────────────
          _RouteCard(reservation: r),
          const SizedBox(height: KSpacing.lg),

          // ── Conducteur (vue passager) ─────────────────────────────────
          if (!widget.isConducteur) ...[
            _ConducteurCard(reservation: r),
            const SizedBox(height: KSpacing.lg),
          ],

          // ── Passager (vue conducteur) ─────────────────────────────────
          if (widget.isConducteur) ...[
            _PassagerCard(reservation: r),
            const SizedBox(height: KSpacing.lg),
          ],

          // ── Infos réservation ─────────────────────────────────────────
          _ReservationInfoCard(reservation: r),
          const SizedBox(height: KSpacing.lg),

          // ── Paiement ─────────────────────────────────────────────────
          _PaiementCard(reservation: r),
          const SizedBox(height: KSpacing.lg),

          // ── Résumé si terminé ─────────────────────────────────────────
          if (r.isTerminee) ...[
            _TermineeCard(reservation: r),
            const SizedBox(height: KSpacing.lg),
          ],

          // ── Annulé / Refusé ───────────────────────────────────────────
          if (r.isAnnulee || r.isDeclinee) ...[
            _AnnuleeCard(reservation: r),
            const SizedBox(height: KSpacing.lg),
          ],

          // ── Actions ───────────────────────────────────────────────────
          _buildActions(context, r),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, ReservationModel r) {
    final isEnCours = r.trajet?.statut == 'en_cours';
    final prefix = widget.isConducteur ? '/conducteur' : '/passager';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Passager ─────────────────────────────────────────────────
        if (!widget.isConducteur) ...[
          // Suivi si en_cours
          if (isEnCours) ...[
            KButton(
              label: 'Suivre le conducteur en direct',
              icon: Icons.location_on_rounded,
              onPressed: _goToSuivi,
            ),
            const SizedBox(height: KSpacing.md),
          ],
          // Code embarquement si confirmée
          if (r.isConfirmee) ...[
            KButton(
              label: 'Mon code d\'embarquement',
              icon: Icons.confirmation_number_outlined,
              variant: KButtonVariant.outline,
              onPressed: () => context
                  .push('$prefix/reservation/${r.id}/code-embarquement'),
            ),
            const SizedBox(height: KSpacing.md),
            _buildPaiementButton(context, r, prefix),
            const SizedBox(height: KSpacing.md),
          ],
          // Ajouter des places si en_attente ou confirmée
          if (r.isEnAttente || r.isConfirmee) ...[
            KButton(
              label: 'Ajouter des places',
              icon: Icons.person_add_rounded,
              variant: KButtonVariant.outline,
              isLoading: _ajouterPlacesLoading,
              onPressed: _ajouterPlacesLoading ? null : () => _ajouterPlaces(context, r),
            ),
            const SizedBox(height: KSpacing.md),
          ],
          // Messagerie — conversation privée + groupe trajet
          if (r.isConfirmee || r.isEnAttente) ...[
            // Chat privé avec le conducteur
            if (r.conversationId != null)
              KButton(
                label: 'Message au conducteur',
                icon: Icons.chat_bubble_outline_rounded,
                variant: KButtonVariant.outline,
                onPressed: () => context.push(
                  '$prefix/messages/${r.conversationId}'
                  '?name=${Uri.encodeComponent(r.trajet?.conducteurNom ?? 'Conducteur')}'
                  '&statut=ouverte',
                ),
              ),
            if (r.conversationId != null) const SizedBox(height: KSpacing.md),
            // Chat du trajet (groupe)
            if (r.groupeConvId != null)
              KButton(
                label: 'Chat du trajet',
                icon: Icons.directions_car_rounded,
                variant: KButtonVariant.outline,
                onPressed: () => context.push(
                  '$prefix/messages/${r.groupeConvId}'
                  '?name=${Uri.encodeComponent(r.trajet != null ? "${r.trajet!.depart} → ${r.trajet!.destination}" : "Groupe trajet")}'
                  '&isGroupe=true'
                  '&statut=ouverte',
                ),
              )
            else
              KButton(
                label: 'Chat du trajet',
                icon: Icons.directions_car_rounded,
                variant: KButtonVariant.outline,
                isLoading: _groupeChatLoading,
                onPressed: _groupeChatLoading ? null : () => _ouvrirGroupeTrajet(context, r, prefix),
              ),
            const SizedBox(height: KSpacing.md),
          ],
          // Annuler si en_attente
          if (r.isEnAttente) ...[
            KButton(
              label: 'Annuler la réservation',
              icon: Icons.close_rounded,
              variant: KButtonVariant.error,
              isLoading: _annulerLoading,
              onPressed: _annulerLoading ? null : () => _annuler(context, r),
            ),
            const SizedBox(height: KSpacing.md),
          ],
          // Évaluer si terminée
          if (r.isTerminee && (r.trajet?.conducteurId ?? '').isNotEmpty) ...[
            KButton(
              label: 'Évaluer le conducteur',
              icon: Icons.star_rounded,
              variant: KButtonVariant.outline,
              onPressed: () => context.push(
                '$prefix/evaluation/${r.trajetId}/${r.trajet!.conducteurId}',
              ),
            ),
            const SizedBox(height: KSpacing.md),
          ],
        ],

        // ── Conducteur ────────────────────────────────────────────────
        if (widget.isConducteur) ...[
          if (isEnCours) ...[
            KButton(
              label: 'Embarquer ce passager',
              icon: Icons.how_to_reg_rounded,
              onPressed: () => context.push('/conducteur/embarquement'),
            ),
            const SizedBox(height: KSpacing.md),
          ],
          // Chat privé + groupe trajet pour le conducteur
          if (r.isConfirmee || isEnCours) ...[
            if (r.conversationId != null)
              KButton(
                label: 'Message à ${r.passagerNom}',
                icon: Icons.chat_bubble_outline_rounded,
                variant: KButtonVariant.outline,
                onPressed: () => context.push(
                  '$prefix/messages/${r.conversationId}'
                  '?name=${Uri.encodeComponent(r.passagerNom)}'
                  '&statut=ouverte',
                ),
              ),
            if (r.conversationId != null) const SizedBox(height: KSpacing.md),
            if (r.groupeConvId != null)
              KButton(
                label: 'Chat du trajet',
                icon: Icons.directions_car_rounded,
                variant: KButtonVariant.outline,
                onPressed: () => context.push(
                  '$prefix/messages/${r.groupeConvId}'
                  '?name=${Uri.encodeComponent(r.trajet != null ? "${r.trajet!.depart} → ${r.trajet!.destination}" : "Groupe trajet")}'
                  '&isGroupe=true'
                  '&statut=ouverte',
                ),
              )
            else
              KButton(
                label: 'Créer le chat du trajet',
                icon: Icons.directions_car_rounded,
                variant: KButtonVariant.outline,
                isLoading: _groupeChatLoading,
                onPressed: _groupeChatLoading ? null : () => _ouvrirGroupeTrajet(context, r, prefix),
              ),
            const SizedBox(height: KSpacing.md),
          ],
          // Confirmation paiement espèces
          if (r.paiement != null &&
              r.paiement!.isEspece &&
              r.paiement!.isEnAttenteConfirm) ...[
            KButton(
              label: 'Confirmer le paiement en espèces',
              icon: Icons.handshake_rounded,
              variant: KButtonVariant.success,
              isLoading: _especeLoading,
              onPressed: _especeLoading
                  ? null
                  : () => _confirmerEspeces(context, r),
            ),
            const SizedBox(height: KSpacing.md),
          ],
        ],
      ],
    );
  }

  Future<void> _ouvrirGroupeTrajet(
      BuildContext context, ReservationModel r, String prefix) async {
    setState(() => _groupeChatLoading = true);
    try {
      final conv = await MessagerieRepository().getOrCreateGroupeTrajet(r.trajetId);
      if (!mounted) return;
      final titre = r.trajet != null
          ? '${r.trajet!.depart} → ${r.trajet!.destination}'
          : 'Groupe trajet';
      await context.push(
        '$prefix/messages/${conv.convId}'
        '?name=${Uri.encodeComponent(titre)}'
        '&isGroupe=true'
        '&statut=ouverte',
      );
      // Rafraîchir pour obtenir le nouveau groupeConvId
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d\'ouvrir le chat du trajet.'),
            backgroundColor: KColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _groupeChatLoading = false);
    }
  }

  Widget _buildPaiementButton(
      BuildContext context, ReservationModel r, String prefix) {
    final p = r.paiement;
    if (p == null) {
      return KButton(
        label: 'Payer ma place',
        icon: Icons.payments_rounded,
        onPressed: () => context.push('$prefix/paiement/${r.id}'),
      );
    }
    if (p.isTermine) {
      return _StateBadge(
        icon: Icons.check_circle_rounded,
        label: 'Paiement confirmé',
        color: KColors.successContent,
        bgColor: KColors.success.withValues(alpha: 0.1),
        borderColor: KColors.success.withValues(alpha: 0.3),
      );
    }
    if (p.isEspece) {
      return _StateBadge(
        icon: Icons.handshake_outlined,
        label: 'Paiement en espèces au conducteur',
        color: KColors.primary,
        bgColor: KColors.primary.withValues(alpha: 0.07),
        borderColor: KColors.primary.withValues(alpha: 0.2),
      );
    }
    return KButton(
      label: 'Terminer le paiement',
      icon: Icons.payments_rounded,
      variant: KButtonVariant.warning,
      onPressed: () => context.push('$prefix/paiement/${r.id}'),
    );
  }

  Future<void> _confirmerEspeces(BuildContext context, ReservationModel r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer la réception ?'),
        content: Text(
          'Confirmez-vous avoir reçu ${Formatters.currency(r.montantTotal)} en espèces de ${r.passagerNom} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Oui, confirmer',
              style: TextStyle(color: KColors.successContent),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _especeLoading = true);
    try {
      await ReservationRepository().confirmerPaiementEspeces(r.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Paiement en espèces confirmé !'),
        backgroundColor: KColors.successContent,
      ));
      // Mettre à jour le paiement localement pour rafraîchir l'UI
      if (_reservation?.paiement != null) {
        setState(() {
          _reservation = _reservation!.copyWith(
            paiement: _reservation!.paiement!.copyWith(statut: 'CONFIRME'),
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: KColors.error,
      ));
    } finally {
      if (mounted) setState(() => _especeLoading = false);
    }
  }

  Future<void> _ajouterPlaces(BuildContext context, ReservationModel r) async {
    int placesSupp = 1;
    final prixUnitaire = r.prixParPlace;
    final maxSupp = (8 - r.placesReservees).clamp(0, 7);

    if (maxSupp <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vous avez déjà le maximum de 8 places.'),
        backgroundColor: KColors.warning,
      ));
      return;
    }

    final confirmed = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Ajouter des places'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Vous avez actuellement ${r.placesReservees} place(s). '
                'Combien souhaitez-vous en ajouter ?',
                style: KTextStyles.caption,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: placesSupp > 1
                        ? () => setDlg(() => placesSupp--)
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '+$placesSupp',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: placesSupp < maxSupp
                        ? () => setDlg(() => placesSupp++)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Supplément : ${Formatters.currency(prixUnitaire * placesSupp)} FCFA',
                style: TextStyle(
                    color: KColors.primary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: KColors.primary),
              onPressed: () => Navigator.pop(ctx, placesSupp),
              child: const Text('Confirmer',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (confirmed == null || !mounted) return;

    setState(() => _ajouterPlacesLoading = true);
    try {
      final result = await ReservationRepository().ajouterPlaces(r.id, confirmed);
      if (!mounted) return;
      final nouvellesPlaces = result['places_reservees'] as int? ?? r.placesReservees + confirmed;
      setState(() {
        _reservation = _reservation?.copyWith(placesReservees: nouvellesPlaces);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$confirmed place(s) ajoutée(s) ! Total : $nouvellesPlaces places.'),
        backgroundColor: KColors.successContent,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: KColors.error,
      ));
    } finally {
      if (mounted) setState(() => _ajouterPlacesLoading = false);
    }
  }

  Future<void> _annuler(BuildContext context, ReservationModel r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler la réservation ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Non')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oui, annuler',
                style: TextStyle(color: KColors.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _annulerLoading = true);
    try {
      await ReservationRepository().annulerReservation(r.id);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur: $e'),
        backgroundColor: KColors.error,
      ));
    } finally {
      if (mounted) setState(() => _annulerLoading = false);
    }
  }
}

// ── Bannière suivi temps réel ─────────────────────────────────────────────────

class _LiveTrajetBanner extends StatelessWidget {
  final ReservationModel reservation;
  final Animation<double> pulseAnim;
  final VoidCallback onTap;

  const _LiveTrajetBanner({
    required this.reservation,
    required this.pulseAnim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [KColors.successContent, KColors.success],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
              animation: pulseAnim,
              builder: (_, child) =>
                  Opacity(opacity: pulseAnim.value, child: child),
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
                    'Trajet en cours !',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
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
                  Icon(Icons.navigation_rounded,
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

// ── Carte itinéraire ──────────────────────────────────────────────────────────

class _RouteCard extends StatelessWidget {
  final ReservationModel reservation;
  const _RouteCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final trajet = r.trajet;

    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Départ
            Row(children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: KColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  trajet?.depart ?? '—',
                  style:
                      KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (trajet != null)
                Text(
                  DateFormat('HH:mm').format(trajet.dateHeureDepart),
                  style: KTextStyles.bodySm.copyWith(
                    color: KColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
              child: Column(
                children: [
                  for (int i = 0; i < 3; i++)
                    Container(
                      width: 2,
                      height: 6,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: KColors.border,
                    ),
                ],
              ),
            ),
            // Destination
            Row(children: [
              const Icon(Icons.location_on_rounded,
                  color: KColors.error, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  trajet?.destination ?? '—',
                  style:
                      KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ]),
            if (trajet != null) ...[
              const SizedBox(height: KSpacing.lg),
              const Divider(color: KColors.border),
              const SizedBox(height: KSpacing.sm),
              Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 13, color: KColors.baseContentMid),
                const SizedBox(width: 6),
                Text(
                  DateFormat('EEEE d MMMM yyyy', 'fr_FR')
                      .format(trajet.dateHeureDepart),
                  style: KTextStyles.caption,
                ),
                const Spacer(),
                if (trajet.distanceKm > 0) ...[
                  const Icon(Icons.straighten,
                      size: 13, color: KColors.baseContentMid),
                  const SizedBox(width: 4),
                  Text(
                    '${trajet.distanceKm.toStringAsFixed(0)} km',
                    style: KTextStyles.caption,
                  ),
                ],
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Carte conducteur ──────────────────────────────────────────────────────────

class _ConducteurCard extends StatelessWidget {
  final ReservationModel reservation;
  const _ConducteurCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final trajet = reservation.trajet;
    final nom = trajet?.conducteurNom ?? '—';
    final note = trajet?.conducteurNote ?? 0.0;
    final photo = trajet?.conducteurPhoto;

    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Row(
          children: [
            KAvatar(name: nom, photoUrl: photo, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Conducteur',
                      style: KTextStyles.meta
                          .copyWith(color: KColors.baseContentMid)),
                  const SizedBox(height: 2),
                  Text(nom,
                      style: KTextStyles.bodySm
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Row(children: [
                    for (int i = 1; i <= 5; i++)
                      Icon(
                        i <= note.round()
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 14,
                        color: const Color(0xFFFFB800),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      note > 0
                          ? note.toStringAsFixed(1)
                          : 'Non encore noté',
                      style: KTextStyles.caption,
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Carte passager (vue conducteur) ───────────────────────────────────────────

class _PassagerCard extends StatelessWidget {
  final ReservationModel reservation;
  const _PassagerCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Row(
          children: [
            KAvatar(
                name: r.passagerNom,
                photoUrl: r.passagerPhoto,
                size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Passager',
                      style: KTextStyles.meta
                          .copyWith(color: KColors.baseContentMid)),
                  const SizedBox(height: 2),
                  Text(r.passagerNom,
                      style: KTextStyles.bodySm
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    '${r.placesReservees} place(s) réservée(s)',
                    style: KTextStyles.caption,
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

// ── Infos réservation ─────────────────────────────────────────────────────────

class _ReservationInfoCard extends StatelessWidget {
  final ReservationModel reservation;
  const _ReservationInfoCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Column(
          children: [
            _InfoRow(
              label: 'Réservation nº',
              value: '#${r.id}',
            ),
            _InfoRow(
              label: 'Statut',
              value: Formatters.reservationStatutLabel(r.statut),
            ),
            _InfoRow(
              label: 'Places réservées',
              value: '${r.placesReservees} place(s)',
            ),
            _InfoRow(
              label: 'Date réservation',
              value: DateFormat('d MMM yyyy', 'fr_FR').format(r.dateReservation),
            ),
            _InfoRow(
              label: 'Montant total',
              value: Formatters.currency(r.montantTotal),
              valueColor: KColors.primary,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Paiement ──────────────────────────────────────────────────────────────────

class _PaiementCard extends StatelessWidget {
  final ReservationModel reservation;
  const _PaiementCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final p = reservation.paiement;

    Color statutColor;
    String statutLabel;
    IconData statutIcon;

    if (p == null) {
      statutColor = KColors.baseContentMid;
      statutLabel = 'Aucun paiement';
      statutIcon = Icons.payments_outlined;
    } else if (p.isTermine) {
      statutColor = KColors.successContent;
      statutLabel = 'Paiement confirmé';
      statutIcon = Icons.check_circle_rounded;
    } else if (p.isEspece) {
      statutColor = KColors.primary;
      statutLabel = 'En espèces';
      statutIcon = Icons.handshake_outlined;
    } else {
      statutColor = KColors.warning;
      statutLabel = 'En attente';
      statutIcon = Icons.pending_rounded;
    }

    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.receipt_long_outlined,
                  size: 16, color: KColors.baseContentMid),
              const SizedBox(width: 8),
              Text('Paiement',
                  style: KTextStyles.bodySm
                      .copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statutColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(statutIcon, size: 12, color: statutColor),
                  const SizedBox(width: 4),
                  Text(
                    statutLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: statutColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]),
              ),
            ]),
            if (p != null) ...[
              const SizedBox(height: KSpacing.md),
              const Divider(color: KColors.border),
              const SizedBox(height: KSpacing.sm),
              _InfoRow(label: 'Mode', value: p.moyenLabel),
              _InfoRow(
                label: 'Montant',
                value: p.montant > 0
                    ? Formatters.currency(p.montant)
                    : Formatters.currency(reservation.montantTotal),
                valueColor: KColors.primary,
                bold: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Résumé trajet terminé ─────────────────────────────────────────────────────

class _TermineeCard extends StatelessWidget {
  final ReservationModel reservation;
  const _TermineeCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Column(
          children: [
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: KColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: KColors.successContent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Trajet terminé avec succès',
                style: KTextStyles.bodySm.copyWith(
                  fontWeight: FontWeight.w700,
                  color: KColors.successContent,
                ),
              ),
            ]),
            const SizedBox(height: KSpacing.lg),
            const Divider(color: KColors.border),
            const SizedBox(height: KSpacing.sm),
            if (r.trajet != null && r.trajet!.distanceKm > 0)
              _InfoRow(
                label: 'Distance parcourue',
                value: '${r.trajet!.distanceKm.toStringAsFixed(0)} km',
              ),
            _InfoRow(
              label: 'Montant réglé',
              value: Formatters.currency(r.montantTotal),
              valueColor: KColors.primary,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Résumé annulé / refusé ────────────────────────────────────────────────────

class _AnnuleeCard extends StatelessWidget {
  final ReservationModel reservation;
  const _AnnuleeCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final r = reservation;
    final isDeclinee = r.isDeclinee;
    final color = isDeclinee ? KColors.error : KColors.warning;

    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDeclinee ? Icons.block_rounded : Icons.cancel_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDeclinee
                      ? 'Réservation refusée'
                      : 'Réservation annulée',
                  style: KTextStyles.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isDeclinee
                      ? 'Le conducteur n\'a pas accepté votre réservation.'
                      : 'Cette réservation a été annulée.',
                  style: KTextStyles.meta,
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Widgets utilitaires ───────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: KTextStyles.caption),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: KTextStyles.bodySm.copyWith(
                color: valueColor,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final Color borderColor;

  const _StateBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
