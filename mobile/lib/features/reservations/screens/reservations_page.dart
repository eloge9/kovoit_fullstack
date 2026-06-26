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
import 'reservation_detail_page.dart';

// ── Page principale avec onglets ──────────────────────────────────────────────

class ReservationsPage extends ConsumerStatefulWidget {
  final bool isConducteur;
  final bool hideAppBar;

  const ReservationsPage({
    super.key,
    this.isConducteur = false,
    this.hideAppBar = false,
  });

  @override
  ConsumerState<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends ConsumerState<ReservationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadActives());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadActives() async {
    if (widget.isConducteur) {
      await ref.read(reservationsProvider.notifier).loadReservationsRecues();
    } else {
      await ref.read(reservationsProvider.notifier).loadMesReservations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              backgroundColor: KColors.base100,
              elevation: 0,
              shape: const Border(bottom: BorderSide(color: KColors.border)),
              title: Text(
                widget.isConducteur ? 'Réservations' : 'Mes réservations',
                style: KTextStyles.bodySm.copyWith(
                  fontWeight: FontWeight.w700,
                  color: KColors.baseContent,
                ),
              ),
            ),
      body: Column(
        children: [
          // ── TabBar ────────────────────────────────────────────────────
          Container(
            color: KColors.base100,
            child: TabBar(
              controller: _tabController,
              labelColor: KColors.primary,
              unselectedLabelColor: KColors.baseContentMid,
              indicatorColor: KColors.primary,
              indicatorWeight: 2.5,
              labelStyle: KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
              unselectedLabelStyle: KTextStyles.bodySm,
              tabs: [
                Tab(text: widget.isConducteur ? 'Demandes' : 'Actives'),
                const Tab(text: 'Historique'),
              ],
            ),
          ),
          // ── Contenu onglets ───────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ActivesTab(
                  isConducteur: widget.isConducteur,
                  onRefresh: _loadActives,
                ),
                _HistoriqueTab(isConducteur: widget.isConducteur),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Onglet Actives ─────────────────────────────────────────────────────────────

class _ActivesTab extends ConsumerStatefulWidget {
  final bool isConducteur;
  final Future<void> Function() onRefresh;

  const _ActivesTab({required this.isConducteur, required this.onRefresh});

  @override
  ConsumerState<_ActivesTab> createState() => _ActivesTabState();
}

class _ActivesTabState extends ConsumerState<_ActivesTab> {
  final _confirmingIds = <int>{};
  final _decliningIds = <int>{};

  String get _prefix => widget.isConducteur ? '/conducteur' : '/passager';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reservationsProvider);
    // Filtrer côté client : onglet "Actives" = seulement en_attente et confirmee
    final allList = widget.isConducteur
        ? state.reservationsRecues
        : state.mesReservations;
    final list = allList.where((r) => r.isActive).toList();

    return RefreshIndicator(
      color: KColors.primary,
      onRefresh: widget.onRefresh,
      child: state.isLoading
          ? _Skeleton()
          : list.isEmpty
              ? KEmptyState(
                  emoji: '🎫',
                  message: widget.isConducteur
                      ? 'Aucune demande de réservation en attente.'
                      : 'Vous n\'avez pas de réservation active pour le moment.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    KSpacing.pagePaddingH,
                    KSpacing.lg,
                    KSpacing.pagePaddingH,
                    KSpacing.pagePaddingH,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final r = list[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: KSpacing.md),
                      child: _ReservationCard(
                        reservation: r,
                        isConducteur: widget.isConducteur,
                        prefix: _prefix,
                        isConfirming: _confirmingIds.contains(r.id),
                        isDeclining: _decliningIds.contains(r.id),
                        onConfirmer: () => _confirmer(r),
                        onDecliner: () => _decliner(r),
                        onAnnuler: () => _annuler(r),
                      ),
                    );
                  },
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
    if (ok) NotificationService.reservationRefusee(r.passagerNom);
  }

  Future<void> _annuler(ReservationModel r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    if (confirm == true) {
      await ref.read(reservationsProvider.notifier).annuler(r.id);
    }
  }
}

// ── Onglet Historique ─────────────────────────────────────────────────────────

class _HistoriqueTab extends ConsumerStatefulWidget {
  final bool isConducteur;
  const _HistoriqueTab({required this.isConducteur});

  @override
  ConsumerState<_HistoriqueTab> createState() => _HistoriqueTabState();
}

class _HistoriqueTabState extends ConsumerState<_HistoriqueTab> {
  final _searchCtrl = TextEditingController();
  String _selectedPeriod = 'tous';
  String _selectedStatut = 'tous';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() => _applyFilters();

  AutoDisposeStateProvider<HistoriqueFilters> get _filtersProvider =>
      widget.isConducteur
          ? conducteurHistoriqueFiltersProvider
          : historiqueFiltersProvider;

  AutoDisposeFutureProvider<List<ReservationModel>> get _dataProvider =>
      widget.isConducteur ? conducteurHistoriqueProvider : historiqueProvider;

  void _applyFilters() {
    final (debut, fin) = _periodDates(_selectedPeriod);
    ref.read(_filtersProvider.notifier).state = HistoriqueFilters(
      statut: _selectedStatut == 'tous' ? null : _selectedStatut,
      dateDebut: debut,
      dateFin: fin,
      search: _searchCtrl.text,
    );
  }

  (DateTime?, DateTime?) _periodDates(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'auj':
        final today = DateTime(now.year, now.month, now.day);
        return (today, today);
      case 'hier':
        final yesterday = DateTime(now.year, now.month, now.day - 1);
        return (yesterday, yesterday);
      case 'semaine':
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return (DateTime(monday.year, monday.month, monday.day), now);
      case 'mois':
        return (DateTime(now.year, now.month, 1), now);
      case 'annee':
        return (DateTime(now.year, 1, 1), now);
      default:
        return (null, null);
    }
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      locale: const Locale('fr'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: KColors.primary),
        ),
        child: child!,
      ),
    );
    if (range == null) return;
    setState(() => _selectedPeriod = 'perso');
    ref.read(_filtersProvider.notifier).update((f) => f.copyWith(
          dateDebut: range.start,
          dateFin: range.end,
        ));
  }

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _selectedPeriod = 'tous';
      _selectedStatut = 'tous';
    });
    ref.read(_filtersProvider.notifier).state = const HistoriqueFilters();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(_filtersProvider);
    final data = ref.watch(_dataProvider);

    return Column(
      children: [
        // ── Barre de recherche ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(KSpacing.pagePaddingH, KSpacing.lg,
              KSpacing.pagePaddingH, KSpacing.sm),
          child: TextField(
            controller: _searchCtrl,
            style: KTextStyles.bodySm,
            decoration: InputDecoration(
              hintText: 'Ville, conducteur, nº réservation…',
              hintStyle:
                  KTextStyles.bodySm.copyWith(color: KColors.baseContentMid),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: KColors.baseContentMid, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 18, color: KColors.baseContentMid),
                      onPressed: () {
                        _searchCtrl.clear();
                        _applyFilters();
                      },
                    )
                  : null,
              filled: true,
              fillColor: KColors.base100,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.lg, vertical: KSpacing.sm),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: KColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: KColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: KColors.primary, width: 1.5),
              ),
            ),
          ),
        ),

        // ── Filtres période ─────────────────────────────────────────────
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.pagePaddingH),
            children: [
              _PeriodChip(
                label: 'Tous',
                value: 'tous',
                selected: _selectedPeriod == 'tous',
                onTap: () {
                  setState(() => _selectedPeriod = 'tous');
                  _applyFilters();
                },
              ),
              _PeriodChip(
                label: "Auj.",
                value: 'auj',
                selected: _selectedPeriod == 'auj',
                onTap: () {
                  setState(() => _selectedPeriod = 'auj');
                  _applyFilters();
                },
              ),
              _PeriodChip(
                label: 'Hier',
                value: 'hier',
                selected: _selectedPeriod == 'hier',
                onTap: () {
                  setState(() => _selectedPeriod = 'hier');
                  _applyFilters();
                },
              ),
              _PeriodChip(
                label: 'Cette semaine',
                value: 'semaine',
                selected: _selectedPeriod == 'semaine',
                onTap: () {
                  setState(() => _selectedPeriod = 'semaine');
                  _applyFilters();
                },
              ),
              _PeriodChip(
                label: 'Ce mois',
                value: 'mois',
                selected: _selectedPeriod == 'mois',
                onTap: () {
                  setState(() => _selectedPeriod = 'mois');
                  _applyFilters();
                },
              ),
              _PeriodChip(
                label: 'Cette année',
                value: 'annee',
                selected: _selectedPeriod == 'annee',
                onTap: () {
                  setState(() => _selectedPeriod = 'annee');
                  _applyFilters();
                },
              ),
              _PeriodChip(
                label: 'Personnalisé',
                value: 'perso',
                selected: _selectedPeriod == 'perso',
                icon: Icons.date_range_rounded,
                onTap: _pickCustomRange,
              ),
            ],
          ),
        ),

        const SizedBox(height: KSpacing.sm),

        // ── Filtres statut ──────────────────────────────────────────────
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.pagePaddingH),
            children: [
              _StatutChip(
                label: 'Tous',
                value: 'tous',
                color: KColors.baseContentMid,
                selected: _selectedStatut == 'tous',
                onTap: () {
                  setState(() => _selectedStatut = 'tous');
                  _applyFilters();
                },
              ),
              _StatutChip(
                label: 'Terminés',
                value: 'terminee',
                color: KColors.success,
                selected: _selectedStatut == 'terminee',
                onTap: () {
                  setState(() => _selectedStatut = 'terminee');
                  _applyFilters();
                },
              ),
              _StatutChip(
                label: 'Annulés',
                value: 'annulee',
                color: KColors.warning,
                selected: _selectedStatut == 'annulee',
                onTap: () {
                  setState(() => _selectedStatut = 'annulee');
                  _applyFilters();
                },
              ),
              _StatutChip(
                label: 'Refusés',
                value: 'declinee',
                color: KColors.error,
                selected: _selectedStatut == 'declinee',
                onTap: () {
                  setState(() => _selectedStatut = 'declinee');
                  _applyFilters();
                },
              ),
            ],
          ),
        ),

        // ── Indicateur filtres actifs ───────────────────────────────────
        if (filters.hasActiveFilters)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                KSpacing.pagePaddingH, KSpacing.sm, KSpacing.pagePaddingH, 0),
            child: Row(
              children: [
                Text(
                  'Filtres actifs',
                  style: KTextStyles.caption.copyWith(color: KColors.primary),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _clearFilters,
                  child: Text(
                    'Tout effacer',
                    style: KTextStyles.caption.copyWith(
                      color: KColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: KSpacing.sm),

        // ── Liste historique ────────────────────────────────────────────
        Expanded(
          child: data.when(
            loading: () => _Skeleton(),
            error: (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: KColors.error, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Impossible de charger l\'historique',
                    style: KTextStyles.bodySm.copyWith(color: KColors.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => ref.invalidate(_dataProvider),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
            data: (list) => list.isEmpty
                ? KEmptyState(
                    emoji: '📋',
                    message: filters.hasActiveFilters
                        ? 'Aucun résultat pour ces filtres.'
                        : 'Votre historique est vide.',
                  )
                : RefreshIndicator(
                    color: KColors.primary,
                    onRefresh: () async => ref.invalidate(_dataProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        KSpacing.pagePaddingH,
                        0,
                        KSpacing.pagePaddingH,
                        KSpacing.pagePaddingH,
                      ),
                      itemCount: list.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: KSpacing.md),
                        child: _HistoriqueCard(
                          reservation: list[i],
                          isConducteur: widget.isConducteur,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Chip période ──────────────────────────────────────────────────────────────

class _PeriodChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _PeriodChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:
                selected ? KColors.primary : KColors.base100,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? KColors.primary : KColors.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 13,
                    color: selected ? Colors.white : KColors.baseContentMid),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                  color:
                      selected ? Colors.white : KColors.baseContentMid,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chip statut ───────────────────────────────────────────────────────────────

class _StatutChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatutChip({
    required this.label,
    required this.value,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : KColors.base100,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? color : KColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.check_rounded, size: 12, color: color),
                ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? color : KColors.baseContentMid,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Carte réservation active ──────────────────────────────────────────────────

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

  void _onCardTap(BuildContext context) {
    if (!isConducteur && r.trajet?.statut == 'en_cours') {
      context.push(_suiviUrl(prefix));
    } else {
      context.push(
        '$prefix/reservation/${r.id}/detail',
        extra: r,
      );
    }
  }

  String _suiviUrl(String prefix) {
    final t = r.trajet;
    var url = '$prefix/trajet/${r.trajetId}/suivi'
        '?depart=${Uri.encodeComponent(t?.depart ?? '')}'
        '&destination=${Uri.encodeComponent(t?.destination ?? '')}'
        '&conducteur=${Uri.encodeComponent(t?.conducteurNom ?? '')}';
    if (t?.departLat != null) url += '&departLat=${t!.departLat}';
    if (t?.departLng != null) url += '&departLng=${t!.departLng}';
    if (t?.destinationLat != null) url += '&destinationLat=${t!.destinationLat}';
    if (t?.destinationLng != null) url += '&destinationLng=${t!.destinationLng}';
    debugPrint('[ReservationCard] navigation suivi: $url');
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return KCard(
      onTap: () => _onCardTap(context),
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête ─────────────────────────────────────────────
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.trajet?.depart ?? '?'} → ${r.trajet?.destination ?? '?'}',
                      style: KTextStyles.bodySm
                          .copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (r.trajet != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        Formatters.dateTime(r.trajet!.dateHeureDepart),
                        style: KTextStyles.meta,
                      ),
                    ],
                  ],
                ),
              ),
              KBadge.fromStatut(r.statut),
            ]),
            const SizedBox(height: KSpacing.md),

            // ── Détails ─────────────────────────────────────────────
            Row(children: [
              if (isConducteur) ...[
                KAvatar(name: r.passagerNom, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(r.passagerNom, style: KTextStyles.caption),
                ),
              ] else
                const Spacer(),
              Text(
                Formatters.currency(r.montantTotal),
                style: KTextStyles.bodySm.copyWith(
                  color: KColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),

            // ── Actions ─────────────────────────────────────────────
            if (_hasActions) ...[
              const SizedBox(height: KSpacing.lg),
              const Divider(color: KColors.border),
              const SizedBox(height: KSpacing.lg),
              _buildActions(context),
            ],
          ],
        ),
      ),
    );
  }

  bool get _hasActions {
    if (isConducteur && r.isEnAttente) return true;
    if (isConducteur && r.trajet?.statut == 'en_cours') return true;
    if (!isConducteur && r.isConfirmee) return true;
    if (!isConducteur && r.isEnAttente) return true;
    if (!isConducteur && r.isTerminee) return true;
    if (!isConducteur && r.trajet?.statut == 'en_cours') return true;
    return false;
  }

  Widget _buildPaiementAction(BuildContext context) {
    final p = r.paiement;
    if (p == null) {
      return KButton(
        label: 'Payer ma place',
        icon: Icons.payments_rounded,
        variant: KButtonVariant.outline,
        onPressed: () => context.push('$prefix/paiement/${r.id}'),
      );
    }
    if (p.isTermine) {
      return _PaiementStateBadge(
        icon: Icons.check_circle_rounded,
        label: 'Paiement confirmé',
        color: KColors.successContent,
        bgColor: KColors.success.withValues(alpha: 0.1),
        borderColor: KColors.success.withValues(alpha: 0.3),
      );
    }
    if (p.isEspece) {
      return _PaiementStateBadge(
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

  Widget _buildActions(BuildContext context) {
    if (isConducteur && r.isEnAttente) {
      return Row(children: [
        Expanded(
          child: KButton(
            label: 'Confirmer',
            icon: Icons.check_rounded,
            variant: KButtonVariant.success,
            isLoading: isConfirming,
            onPressed: isConfirming ? null : onConfirmer,
          ),
        ),
        const SizedBox(width: KSpacing.md),
        Expanded(
          child: KButton(
            label: 'Décliner',
            icon: Icons.close_rounded,
            variant: KButtonVariant.error,
            isLoading: isDeclining,
            onPressed: isDeclining ? null : onDecliner,
          ),
        ),
      ]);
    }

    if (isConducteur && r.trajet?.statut == 'en_cours') {
      return KButton(
        label: 'Embarquer un passager',
        icon: Icons.how_to_reg_rounded,
        onPressed: () => context.push('/conducteur/embarquement'),
      );
    }

    if (!isConducteur && r.isConfirmee) {
      return Column(children: [
        KButton(
          label: 'Mon code d\'embarquement',
          icon: Icons.confirmation_number_outlined,
          onPressed: () => context.push(
              '$prefix/reservation/${r.id}/code-embarquement'),
        ),
        const SizedBox(height: KSpacing.md),
        _buildPaiementAction(context),
        if (r.trajet?.statut == 'en_cours') ...[
          const SizedBox(height: KSpacing.md),
          KButton(
            label: 'Suivre le trajet en direct',
            icon: Icons.location_on_rounded,
            variant: KButtonVariant.ghost,
            onPressed: () => context.push(_suiviUrl(prefix)),
          ),
        ],
      ]);
    }

    if (!isConducteur && r.isEnAttente) {
      return KButton(
        label: 'Annuler la réservation',
        variant: KButtonVariant.error,
        onPressed: onAnnuler,
      );
    }

    if (!isConducteur && r.isTerminee && (r.trajet?.conducteurId ?? '').isNotEmpty) {
      return KButton(
        label: 'Évaluer le conducteur',
        icon: Icons.star_rounded,
        variant: KButtonVariant.outline,
        onPressed: () => context.push(
          '$prefix/evaluation/${r.trajetId}/${r.trajet!.conducteurId}',
        ),
      );
    }

    if (!isConducteur && r.trajet?.statut == 'en_cours') {
      return KButton(
        label: 'Suivre le trajet en direct',
        icon: Icons.location_on_rounded,
        onPressed: () => context.push(_suiviUrl(prefix)),
      );
    }

    return const SizedBox.shrink();
  }
}

// ── Carte historique (cliquable) ──────────────────────────────────────────────

class _HistoriqueCard extends StatelessWidget {
  final ReservationModel reservation;
  final bool isConducteur;

  const _HistoriqueCard({required this.reservation, required this.isConducteur});

  ReservationModel get r => reservation;

  Color get _statutColor {
    if (r.isTerminee) return KColors.success;
    if (r.isAnnulee) return KColors.warning;
    if (r.isDeclinee) return KColors.error;
    return KColors.baseContentMid;
  }

  IconData get _statutIcon {
    if (r.isTerminee) return Icons.check_circle_rounded;
    if (r.isAnnulee) return Icons.cancel_rounded;
    if (r.isDeclinee) return Icons.block_rounded;
    return Icons.info_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final prefix = isConducteur ? '/conducteur' : '/passager';
    return GestureDetector(
      onTap: () => context.push(
        '$prefix/reservation/${r.id}/detail',
        extra: r,
      ),
      child: Container(
      decoration: BoxDecoration(
        color: KColors.base100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Route ─────────────────────────────────────────────
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r.trajet?.depart ?? '?'} → ${r.trajet?.destination ?? '?'}',
                      style: KTextStyles.bodySm
                          .copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.trajet != null
                          ? Formatters.dateTime(r.trajet!.dateHeureDepart)
                          : Formatters.date(r.dateReservation),
                      style: KTextStyles.meta,
                    ),
                  ],
                ),
              ),
              // Statut badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statutColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statutIcon, size: 12, color: _statutColor),
                    const SizedBox(width: 4),
                    Text(
                      Formatters.reservationStatutLabel(r.statut),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statutColor,
                      ),
                    ),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: KSpacing.md),
            const Divider(color: KColors.border, height: 1),
            const SizedBox(height: KSpacing.md),

            // ── Détails ─────────────────────────────────────────────
            Row(children: [
              if (isConducteur) ...[
                KAvatar(
                    name: r.passagerNom,
                    photoUrl: r.passagerPhoto,
                    size: 26),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.passagerNom,
                          style: KTextStyles.caption
                              .copyWith(fontWeight: FontWeight.w600)),
                      Text('${r.placesReservees} place(s)',
                          style: KTextStyles.meta),
                    ],
                  ),
                ),
              ] else ...[
                if (r.trajet != null && r.trajet!.conducteurNom.isNotEmpty) ...[
                  KAvatar(name: r.trajet!.conducteurNom, size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.trajet!.conducteurNom,
                            style: KTextStyles.caption
                                .copyWith(fontWeight: FontWeight.w600)),
                        Text('Conducteur', style: KTextStyles.meta),
                      ],
                    ),
                  ),
                ] else
                  const Spacer(),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.currency(r.montantTotal),
                    style: KTextStyles.bodySm.copyWith(
                      color: KColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Rés. #${r.id}',
                    style: KTextStyles.meta,
                  ),
                ],
              ),
            ]),

            // ── Bouton évaluation ────────────────────────────────────
            if (r.isTerminee) ...[
              const SizedBox(height: KSpacing.md),
              const Divider(color: KColors.border, height: 1),
              const SizedBox(height: KSpacing.md),
              if (isConducteur && r.passagerId.isNotEmpty)
                KButton(
                  label: 'Évaluer ${r.passagerNom}',
                  icon: Icons.star_rounded,
                  variant: KButtonVariant.outline,
                  onPressed: () => context.push(
                    '$prefix/evaluation/${r.trajetId}/${r.passagerId}',
                  ),
                )
              else if (!isConducteur &&
                  (r.trajet?.conducteurId ?? '').isNotEmpty)
                KButton(
                  label: 'Évaluer le conducteur',
                  icon: Icons.star_rounded,
                  variant: KButtonVariant.outline,
                  onPressed: () => context.push(
                    '$prefix/evaluation/${r.trajetId}/${r.trajet!.conducteurId}',
                  ),
                ),
            ],
          ],
        ),
      ),
    )); // GestureDetector
  }
}

// ── Badge état paiement (lecture seule) ──────────────────────────────────────

class _PaiementStateBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final Color borderColor;

  const _PaiementStateBadge({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton loading ──────────────────────────────────────────────────────────

class _Skeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(KSpacing.pagePaddingH),
      itemCount: 5,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: KSpacing.md),
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            color: KColors.base100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: KColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Bar(width: 180, height: 12),
                        const SizedBox(height: 6),
                        _Bar(width: 100, height: 10),
                      ],
                    ),
                  ),
                  _Bar(width: 70, height: 24),
                ]),
                const Spacer(),
                Row(children: [
                  _Bar(width: 80, height: 10),
                  const Spacer(),
                  _Bar(width: 60, height: 14),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double width;
  final double height;
  const _Bar({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: KColors.base300,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
