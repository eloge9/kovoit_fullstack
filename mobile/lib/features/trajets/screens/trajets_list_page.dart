import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/trajet_provider.dart';
import '../models/trajet_model.dart';
import '../../../core/services/nominatim_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_avatar.dart';
import '../../../core/widgets/k_badge.dart';

// ── Page principale ───────────────────────────────────────────────────────────

class TrajetsListPage extends ConsumerStatefulWidget {
  final bool isMesTrajets;
  final bool hideAppBar;

  const TrajetsListPage({
    super.key,
    this.isMesTrajets = false,
    this.hideAppBar = false,
  });

  @override
  ConsumerState<TrajetsListPage> createState() => _TrajetsListPageState();
}

class _TrajetsListPageState extends ConsumerState<TrajetsListPage> {
  final _departCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _scrollController = ScrollController();

  LocationSuggestion? _pickupSuggestion;
  LocationSuggestion? _dropoffSuggestion;
  DateTime? _selectedDate;
  int _places = 1;
  double _toleranceKm = 1.0;
  bool _searchExpanded = true;

  static const _toleranceOptions = [
    (0.5, '500 m'),
    (1.0, '1 km'),
    (2.0, '2 km'),
    (3.0, '3 km'),
    (5.0, '5 km'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isMesTrajets) {
        ref.read(trajetsProvider.notifier).loadMesTrajets();
      } else {
        // Auto-charger tous les trajets disponibles au démarrage
        ref.read(trajetsProvider.notifier).loadTrajets();
      }
    });
  }

  @override
  void dispose() {
    _departCtrl.dispose();
    _destinationCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _rechercher() async {
    FocusScope.of(context).unfocus();
    final dateStr = _selectedDate != null
        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
        : null;

    if (_pickupSuggestion != null && _dropoffSuggestion != null) {
      // Recherche géospatiale par itinéraire
      await ref.read(trajetsProvider.notifier).rechercherItineraire(
            pickupLat: _pickupSuggestion!.lat,
            pickupLng: _pickupSuggestion!.lng,
            dropoffLat: _dropoffSuggestion!.lat,
            dropoffLng: _dropoffSuggestion!.lng,
            date: dateStr,
            places: _places,
            toleranceKm: _toleranceKm,
          );
    } else {
      // Recherche par texte (fallback)
      await ref.read(trajetsProvider.notifier).loadTrajets(
            depart: _departCtrl.text.trim().isNotEmpty
                ? _departCtrl.text.trim()
                : null,
            destination: _destinationCtrl.text.trim().isNotEmpty
                ? _destinationCtrl.text.trim()
                : null,
            date: dateStr,
            places: _places > 1 ? _places : null,
          );
    }
    if (mounted) setState(() => _searchExpanded = false);
  }

  void _resetSearch() {
    setState(() {
      _departCtrl.clear();
      _destinationCtrl.clear();
      _pickupSuggestion = null;
      _dropoffSuggestion = null;
      _selectedDate = null;
      _places = 1;
      _toleranceKm = 1.0;
      _searchExpanded = true;
    });
    ref.read(trajetsProvider.notifier).loadTrajets();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: KColors.primary),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  bool get _hasActiveSearch =>
      _pickupSuggestion != null ||
      _dropoffSuggestion != null ||
      _departCtrl.text.isNotEmpty ||
      _destinationCtrl.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trajetsProvider);
    final prefix = widget.isMesTrajets ? '/conducteur' : '/passager';

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              backgroundColor: KColors.base100,
              elevation: 0,
              shape: const Border(bottom: BorderSide(color: KColors.border)),
              title: Text(
                widget.isMesTrajets
                    ? 'Mes trajets'
                    : 'Recherche de trajets',
                style: KTextStyles.bodySm.copyWith(
                    fontWeight: FontWeight.w700, color: KColors.baseContent),
              ),
              actions: [
                if (!widget.isMesTrajets && _hasActiveSearch)
                  TextButton(
                    onPressed: _resetSearch,
                    child: Text('Réinitialiser',
                        style: KTextStyles.caption
                            .copyWith(color: KColors.primary)),
                  ),
              ],
            ),
      body: RefreshIndicator(
        color: KColors.primary,
        onRefresh: () async {
          if (widget.isMesTrajets) {
            await ref.read(trajetsProvider.notifier).loadMesTrajets();
          } else {
            await _rechercher();
          }
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // ── Panneau de recherche (passager) ──────────────────────────
            if (!widget.isMesTrajets)
              SliverToBoxAdapter(
                child: _SearchPanel(
                  departCtrl: _departCtrl,
                  destinationCtrl: _destinationCtrl,
                  pickupSuggestion: _pickupSuggestion,
                  dropoffSuggestion: _dropoffSuggestion,
                  selectedDate: _selectedDate,
                  places: _places,
                  toleranceKm: _toleranceKm,
                  toleranceOptions: _toleranceOptions,
                  isExpanded: _searchExpanded,
                  isGeoSearch: state.isGeoSearch,
                  onToggleExpand: () =>
                      setState(() => _searchExpanded = !_searchExpanded),
                  onPickupSelected: (s) => setState(() {
                    _pickupSuggestion = s;
                    _departCtrl.text = s.shortName;
                  }),
                  onDropoffSelected: (s) => setState(() {
                    _dropoffSuggestion = s;
                    _destinationCtrl.text = s.shortName;
                  }),
                  onSelectDate: _selectDate,
                  onPlacesChanged: (v) => setState(() => _places = v),
                  onToleranceChanged: (v) => setState(() => _toleranceKm = v),
                  onSearch: _rechercher,
                ),
              ),

            // ── En-tête résultats ─────────────────────────────────────────
            if (!widget.isMesTrajets && !state.isLoading)
              SliverToBoxAdapter(
                child: _ResultsHeader(
                  count: state.trajets.length,
                  isGeoSearch: state.isGeoSearch,
                  toleranceKm: state.toleranceKm,
                  algorithm: state.algorithm,
                ),
              ),

            // ── Chargement ────────────────────────────────────────────────
            if (state.isLoading)
              SliverPadding(
                padding: const EdgeInsets.all(KSpacing.pagePaddingH),
                sliver: SliverList.builder(
                  itemCount: 4,
                  itemBuilder: (_, _) => const _TrajetCardSkeleton(),
                ),
              )

            // ── Erreur ────────────────────────────────────────────────────
            else if (state.error != null)
              SliverFillRemaining(
                child: _ErrorState(
                  message: state.error!,
                  onRetry: widget.isMesTrajets
                      ? () => ref
                          .read(trajetsProvider.notifier)
                          .loadMesTrajets()
                      : _rechercher,
                ),
              )

            // ── Vide ──────────────────────────────────────────────────────
            else if (state.trajets.isEmpty)
              SliverFillRemaining(
                child: _EmptyState(
                  isMesTrajets: widget.isMesTrajets,
                  isGeoSearch: state.isGeoSearch,
                  hasSearch: _hasActiveSearch,
                  onReset: _resetSearch,
                ),
              )

            // ── Liste ─────────────────────────────────────────────────────
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    KSpacing.pagePaddingH, 4, KSpacing.pagePaddingH, 80),
                sliver: SliverList.builder(
                  itemCount: state.trajets.length,
                  itemBuilder: (context, i) {
                    final t = state.trajets[i];
                    return _TrajetCard(
                      trajet: t,
                      showActions: widget.isMesTrajets,
                      onTap: () => context.push('$prefix/trajet/${t.id}'),
                      onCommencer: widget.isMesTrajets && t.statut == 'ouvert'
                          ? () async => ref
                              .read(trajetsProvider.notifier)
                              .commencerTrajet(t.id)
                          : null,
                      onTerminer: widget.isMesTrajets && t.statut == 'en_cours'
                          ? () async => ref
                              .read(trajetsProvider.notifier)
                              .terminerTrajet(t.id)
                          : null,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: widget.isMesTrajets
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/conducteur/create-trajet'),
              backgroundColor: KColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Proposer',
                  style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }
}

// ── Panneau de recherche ──────────────────────────────────────────────────────

class _SearchPanel extends StatelessWidget {
  final TextEditingController departCtrl;
  final TextEditingController destinationCtrl;
  final LocationSuggestion? pickupSuggestion;
  final LocationSuggestion? dropoffSuggestion;
  final DateTime? selectedDate;
  final int places;
  final double toleranceKm;
  final List<(double, String)> toleranceOptions;
  final bool isExpanded;
  final bool isGeoSearch;
  final VoidCallback onToggleExpand;
  final ValueChanged<LocationSuggestion> onPickupSelected;
  final ValueChanged<LocationSuggestion> onDropoffSelected;
  final VoidCallback onSelectDate;
  final ValueChanged<int> onPlacesChanged;
  final ValueChanged<double> onToleranceChanged;
  final VoidCallback onSearch;

  const _SearchPanel({
    required this.departCtrl,
    required this.destinationCtrl,
    required this.pickupSuggestion,
    required this.dropoffSuggestion,
    required this.selectedDate,
    required this.places,
    required this.toleranceKm,
    required this.toleranceOptions,
    required this.isExpanded,
    required this.isGeoSearch,
    required this.onToggleExpand,
    required this.onPickupSelected,
    required this.onDropoffSelected,
    required this.onSelectDate,
    required this.onPlacesChanged,
    required this.onToleranceChanged,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: KColors.base100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // En-tête collapsible
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                const Icon(Icons.search, color: KColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isExpanded ? 'Où allez-vous ?' : _searchSummary(),
                    style: KTextStyles.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                        color: KColors.baseContent),
                  ),
                ),
                if (isGeoSearch && !isExpanded)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: KColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('GPS',
                        style: KTextStyles.meta
                            .copyWith(color: KColors.success)),
                  ),
                const SizedBox(width: 4),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: KColors.baseContentMid,
                ),
              ]),
            ),
          ),

          if (isExpanded) ...[
            const Divider(height: 1, color: KColors.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // Départ
                _AutocompleteField(
                  controller: departCtrl,
                  hint: 'Point de départ',
                  icon: Icons.trip_origin,
                  iconColor: KColors.primary,
                  onSelected: onPickupSelected,
                ),
                const SizedBox(height: 10),
                // Arrivée
                _AutocompleteField(
                  controller: destinationCtrl,
                  hint: 'Point d\'arrivée',
                  icon: Icons.location_on,
                  iconColor: KColors.error,
                  onSelected: onDropoffSelected,
                ),
                const SizedBox(height: 10),

                // Date + Places
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onSelectDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: KColors.base200,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: KColors.border),
                        ),
                        child: Row(children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 15, color: KColors.baseContentMid),
                          const SizedBox(width: 6),
                          Text(
                            selectedDate != null
                                ? DateFormat('dd/MM/yy').format(selectedDate!)
                                : 'Date',
                            style: KTextStyles.caption.copyWith(
                              color: selectedDate != null
                                  ? KColors.baseContent
                                  : KColors.baseContentMid,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Places
                  Container(
                    decoration: BoxDecoration(
                      color: KColors.base200,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: KColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: places > 1
                              ? () => onPlacesChanged(places - 1)
                              : null,
                          icon: const Icon(Icons.remove, size: 16),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          color: KColors.baseContentMid,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '$places place${places > 1 ? 's' : ''}',
                            style: KTextStyles.caption.copyWith(
                                color: KColors.baseContent),
                          ),
                        ),
                        IconButton(
                          onPressed: places < 8
                              ? () => onPlacesChanged(places + 1)
                              : null,
                          icon: const Icon(Icons.add, size: 16),
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          color: KColors.primary,
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 10),

                // Tolérance (visible si départ et arrivée sélectionnés par GPS)
                if (pickupSuggestion != null || dropoffSuggestion != null) ...[
                  Row(children: [
                    const Icon(Icons.radar, size: 15, color: KColors.primary),
                    const SizedBox(width: 6),
                    Text('Rayon autour du trajet :',
                        style: KTextStyles.caption),
                    const Spacer(),
                    DropdownButton<double>(
                      value: toleranceKm,
                      isDense: true,
                      underline: const SizedBox.shrink(),
                      style: KTextStyles.caption
                          .copyWith(color: KColors.baseContent),
                      items: toleranceOptions
                          .map((opt) => DropdownMenuItem(
                                value: opt.$1,
                                child: Text(opt.$2),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) onToleranceChanged(v);
                      },
                    ),
                  ]),
                  const SizedBox(height: 10),
                ],

                // Bouton recherche
                KButton(
                  label: 'Rechercher',
                  icon: Icons.search,
                  onPressed: onSearch,
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  String _searchSummary() {
    if (pickupSuggestion != null && dropoffSuggestion != null) {
      return '${pickupSuggestion!.shortName} → ${dropoffSuggestion!.shortName}';
    }
    if (departCtrl.text.isNotEmpty || destinationCtrl.text.isNotEmpty) {
      return '${departCtrl.text} → ${destinationCtrl.text}';
    }
    return 'Tous les trajets disponibles';
  }
}

// ── En-tête des résultats ─────────────────────────────────────────────────────

class _ResultsHeader extends StatelessWidget {
  final int count;
  final bool isGeoSearch;
  final double toleranceKm;
  final String? algorithm;

  const _ResultsHeader({
    required this.count,
    required this.isGeoSearch,
    required this.toleranceKm,
    this.algorithm,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    final toleranceLabel = toleranceKm < 1
        ? '${(toleranceKm * 1000).toInt()} m'
        : '${toleranceKm % 1 == 0 ? toleranceKm.toInt() : toleranceKm} km';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Text(
            '$count trajet${count > 1 ? 's' : ''} trouvé${count > 1 ? 's' : ''}',
            style: KTextStyles.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: KColors.baseContent,
            ),
          ),
          if (isGeoSearch) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: KColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'GPS • $toleranceLabel',
                style: KTextStyles.meta
                    .copyWith(color: KColors.primary),
              ),
            ),
          ],
          const Spacer(),
          if (isGeoSearch)
            Text('Trié par pertinence',
                style: KTextStyles.meta),
        ],
      ),
    );
  }
}

// ── Carte trajet enrichie ─────────────────────────────────────────────────────

class _TrajetCard extends StatelessWidget {
  final TrajetModel trajet;
  final bool showActions;
  final VoidCallback? onTap;
  final VoidCallback? onCommencer;
  final VoidCallback? onTerminer;

  const _TrajetCard({
    required this.trajet,
    this.showActions = false,
    this.onTap,
    this.onCommencer,
    this.onTerminer,
  });

  @override
  Widget build(BuildContext context) {
    final t = trajet;
    final m = t.matching;
    final prixAffiche = t.prixAffiche;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: KColors.base100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: m != null && m.score >= 70
              ? KColors.success.withValues(alpha: 0.3)
              : KColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Score matching (si disponible) ───────────────────────
              if (m != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      _ScoreBar(score: m.score),
                      const SizedBox(width: 8),
                      Text(
                        '${m.score}% de compatibilité',
                        style: KTextStyles.meta.copyWith(
                          color: _scoreColor(m.score),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Route + statut ───────────────────────────────────────
              Row(children: [
                Expanded(
                  child: Column(children: [
                    _LocationRow(
                      icon: Icons.trip_origin,
                      color: KColors.primary,
                      text: t.depart,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Container(
                          width: 2,
                          height: 14,
                          color: KColors.base300,
                          margin: const EdgeInsets.symmetric(vertical: 3)),
                    ),
                    _LocationRow(
                      icon: Icons.location_on,
                      color: KColors.error,
                      text: t.destination,
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                KBadge.fromStatut(t.statut),
              ]),

              const SizedBox(height: 10),
              const Divider(color: KColors.border, height: 1),
              const SizedBox(height: 10),

              // ── Méta-infos ───────────────────────────────────────────
              Wrap(spacing: 14, runSpacing: 4, children: [
                _InfoChip(
                  icon: Icons.calendar_today_outlined,
                  label: Formatters.dateTime(t.dateHeureDepart),
                ),
                _InfoChip(
                  icon: Icons.payments_outlined,
                  label: Formatters.currency(prixAffiche),
                  color: KColors.primary,
                  isBold: true,
                ),
                _InfoChip(
                  icon: Icons.people_outline,
                  label:
                      '${t.placesRestantes} place${t.placesRestantes > 1 ? 's' : ''}',
                  color: t.placesRestantes > 0 ? KColors.success : KColors.error,
                ),
                if (t.distanceKm > 0)
                  _InfoChip(
                    icon: Icons.straighten_rounded,
                    label: Formatters.distance(t.distanceKm),
                  ),
              ]),

              // ── Distances passager (matching) ─────────────────────────
              if (m != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  if (m.distancePickupKm != null) ...[
                    const Icon(Icons.near_me_outlined,
                        size: 13, color: KColors.info),
                    const SizedBox(width: 4),
                    Text(
                      '${(m.distancePickupKm! * 1000).toInt()} m de votre départ',
                      style:
                          KTextStyles.meta.copyWith(color: KColors.info),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (m.distanceDropoffKm != null) ...[
                    const Icon(Icons.flag_outlined,
                        size: 13, color: KColors.info),
                    const SizedBox(width: 4),
                    Text(
                      '${(m.distanceDropoffKm! * 1000).toInt()} m de votre arrivée',
                      style:
                          KTextStyles.meta.copyWith(color: KColors.info),
                    ),
                  ],
                ]),
                if (m.distancePassagerKm > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Votre trajet : ${m.distancePassagerKm.toStringAsFixed(1)} km',
                    style: KTextStyles.meta,
                  ),
                ],
              ],

              // ── Conducteur ───────────────────────────────────────────
              if (t.conducteurNom.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(children: [
                  KAvatar(
                      name: t.conducteurNom,
                      photoUrl: t.conducteurPhoto,
                      size: 22),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(t.conducteurNom,
                        style: KTextStyles.meta,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (t.conducteurNote > 0) ...[
                    const Icon(Icons.star_rounded,
                        size: 12, color: KColors.warning),
                    Text(t.conducteurNote.toStringAsFixed(1),
                        style: KTextStyles.meta
                            .copyWith(fontWeight: FontWeight.w600)),
                  ],
                  if (t.typeVehicule != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: KColors.base200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(t.typeVehicule!,
                          style: KTextStyles.meta),
                    ),
                  ],
                ]),
              ],

              // ── Actions conducteur ────────────────────────────────────
              if (showActions) ...[
                const SizedBox(height: 12),
                Row(children: [
                  if (t.statut == 'ouvert' && onCommencer != null)
                    Expanded(
                      child: KButton(
                        label: 'Commencer',
                        icon: Icons.play_circle_rounded,
                        variant: KButtonVariant.success,
                        onPressed: onCommencer,
                      ),
                    ),
                  if (t.statut == 'en_cours' && onTerminer != null)
                    Expanded(
                      child: KButton(
                        label: 'Terminer',
                        icon: Icons.flag_rounded,
                        variant: KButtonVariant.primary,
                        onPressed: onTerminer,
                      ),
                    ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 70) return KColors.success;
    if (score >= 50) return KColors.warning;
    return KColors.error;
  }
}

// ── Score bar ─────────────────────────────────────────────────────────────────

class _ScoreBar extends StatelessWidget {
  final int score;
  const _ScoreBar({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 70
        ? KColors.success
        : score >= 50
            ? KColors.warning
            : KColors.error;
    return SizedBox(
      width: 40,
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: score / 100,
          backgroundColor: KColors.base300,
          color: color,
        ),
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _TrajetCardSkeleton extends StatelessWidget {
  const _TrajetCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 130,
      decoration: BoxDecoration(
        color: KColors.base100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonLine(width: 200),
            const SizedBox(height: 8),
            _SkeletonLine(width: 160),
            const SizedBox(height: 12),
            const Divider(color: KColors.border, height: 1),
            const SizedBox(height: 12),
            Row(children: [
              _SkeletonLine(width: 100),
              const SizedBox(width: 16),
              _SkeletonLine(width: 80),
            ]),
          ],
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double width;
  const _SkeletonLine({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: KColors.base300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ── États vide / erreur ───────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isMesTrajets;
  final bool isGeoSearch;
  final bool hasSearch;
  final VoidCallback onReset;

  const _EmptyState({
    required this.isMesTrajets,
    required this.isGeoSearch,
    required this.hasSearch,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_car_outlined,
                size: 72, color: KColors.baseContentLow),
            const SizedBox(height: 16),
            Text(
              isMesTrajets
                  ? 'Aucun trajet proposé'
                  : isGeoSearch
                      ? 'Aucun trajet ne passe par ce corridor'
                      : 'Aucun trajet disponible',
              style: KTextStyles.bodySm
                  .copyWith(color: KColors.baseContentMid),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isMesTrajets
                  ? 'Proposez votre premier trajet !'
                  : isGeoSearch
                      ? 'Essayez d\'augmenter le rayon de recherche'
                      : 'Revenez plus tard',
              style: KTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            if (hasSearch) ...[
              const SizedBox(height: 16),
              KButton(
                label: 'Voir tous les trajets',
                variant: KButtonVariant.outline,
                onPressed: onReset,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_outlined,
                size: 48, color: KColors.baseContentMid),
            const SizedBox(height: 12),
            Text(
              message.contains('Connection') || message.contains('SocketException')
                  ? 'Vérifiez votre connexion réseau'
                  : message,
              style: KTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            KButton(
              label: 'Réessayer',
              variant: KButtonVariant.outline,
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Champ autocomplete ────────────────────────────────────────────────────────

class _AutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color iconColor;
  final ValueChanged<LocationSuggestion> onSelected;

  const _AutocompleteField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.iconColor,
    required this.onSelected,
  });

  @override
  State<_AutocompleteField> createState() => _AutocompleteFieldState();
}

class _AutocompleteFieldState extends State<_AutocompleteField> {
  Timer? _debounce;
  List<LocationSuggestion> _suggestions = [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      if (mounted) setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _loading = true);
      final results = await NominatimService.autocomplete(q);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _loading = false;
      });
    });
  }

  void _select(LocationSuggestion s) {
    widget.controller.text = s.shortName;
    setState(() => _suggestions = []);
    widget.onSelected(s);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          style: KTextStyles.bodySm,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle:
                KTextStyles.caption.copyWith(color: KColors.baseContentLow),
            prefixIcon:
                Icon(widget.icon, color: widget.iconColor, size: 18),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: KColors.primary),
                    ),
                  )
                : widget.controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            size: 16, color: KColors.baseContentMid),
                        onPressed: () {
                          widget.controller.clear();
                          setState(() => _suggestions = []);
                        },
                      )
                    : null,
            filled: true,
            fillColor: KColors.base200,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: KColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: KColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: KColors.primary, width: 2)),
          ),
          onChanged: _onChanged,
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: KColors.base100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _suggestions.length.clamp(0, 5),
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: KColors.border),
              itemBuilder: (_, i) {
                final s = _suggestions[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on_outlined,
                      color: KColors.primary, size: 18),
                  title: Text(s.shortName,
                      style: KTextStyles.bodySm
                          .copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text(s.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KTextStyles.caption),
                  onTap: () => _select(s),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ── Widgets locaux ────────────────────────────────────────────────────────────

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _LocationRow(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 8),
      Expanded(
          child: Text(text,
              style: KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis)),
    ]);
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isBold;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.isBold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color ?? KColors.baseContentMid),
      const SizedBox(width: 4),
      Text(label,
          style: KTextStyles.meta.copyWith(
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            color: color ?? KColors.baseContentMid,
          )),
    ]);
  }
}
