import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/trajet_provider.dart';
import '../../../core/services/nominatim_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/trajet_card.dart';

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
  // Champs de recherche passager
  final _departCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  LocationSuggestion? _pickupSuggestion;
  LocationSuggestion? _dropoffSuggestion;
  DateTime? _selectedDate;
  bool _searchExpanded = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isMesTrajets) {
        ref.read(trajetsProvider.notifier).loadMesTrajets();
      } else {
        ref.read(trajetsProvider.notifier).loadTrajets();
      }
    });
  }

  @override
  void dispose() {
    _departCtrl.dispose();
    _destinationCtrl.dispose();
    super.dispose();
  }

  Future<void> _rechercher() async {
    FocusScope.of(context).unfocus();
    if (_pickupSuggestion != null && _dropoffSuggestion != null) {
      await ref.read(trajetsProvider.notifier).rechercherItineraire(
            pickupLat: _pickupSuggestion!.lat,
            pickupLng: _pickupSuggestion!.lng,
            dropoffLat: _dropoffSuggestion!.lat,
            dropoffLng: _dropoffSuggestion!.lng,
            date: _selectedDate != null
                ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                : null,
          );
    } else {
      await ref.read(trajetsProvider.notifier).loadTrajets(
            depart: _departCtrl.text.trim().isNotEmpty
                ? _departCtrl.text.trim()
                : null,
            destination: _destinationCtrl.text.trim().isNotEmpty
                ? _destinationCtrl.text.trim()
                : null,
            date: _selectedDate != null
                ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                : null,
          );
    }
    setState(() => _searchExpanded = false);
  }

  void _resetSearch() {
    setState(() {
      _departCtrl.clear();
      _destinationCtrl.clear();
      _pickupSuggestion = null;
      _dropoffSuggestion = null;
      _selectedDate = null;
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trajetsProvider);
    final prefix = widget.isMesTrajets ? '/conducteur' : '/passager';

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: widget.hideAppBar ? null : AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        title: Text(
          widget.isMesTrajets ? 'Mes trajets' : 'Recherche de trajets',
          style: KTextStyles.bodySm.copyWith(
              fontWeight: FontWeight.w700, color: KColors.baseContent),
        ),
        actions: [
          if (!widget.isMesTrajets &&
              (_pickupSuggestion != null || _dropoffSuggestion != null))
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
          slivers: [
            // ── Panneau de recherche (passager uniquement) ────────────────
            if (!widget.isMesTrajets)
              SliverToBoxAdapter(
                child: _SearchPanel(
                  departCtrl: _departCtrl,
                  destinationCtrl: _destinationCtrl,
                  pickupSuggestion: _pickupSuggestion,
                  dropoffSuggestion: _dropoffSuggestion,
                  selectedDate: _selectedDate,
                  isExpanded: _searchExpanded,
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
                  onSearch: _rechercher,
                ),
              ),

            // ── Indicateur de chargement ──────────────────────────────────
            if (state.isLoading)
              const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(color: KColors.primary)),
              )
            // ── Erreur ────────────────────────────────────────────────────
            else if (state.error != null)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: KColors.baseContentMid),
                      const SizedBox(height: 8),
                      Text(state.error!,
                          textAlign: TextAlign.center,
                          style: KTextStyles.caption),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: widget.isMesTrajets
                            ? () => ref
                                .read(trajetsProvider.notifier)
                                .loadMesTrajets()
                            : _rechercher,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              )
            // ── Vide ──────────────────────────────────────────────────────
            else if (state.trajets.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.directions_car_outlined,
                          size: 72, color: KColors.baseContentLow),
                      const SizedBox(height: 12),
                      Text(
                        widget.isMesTrajets
                            ? 'Aucun trajet proposé'
                            : 'Aucun trajet trouvé',
                        style: KTextStyles.bodySm
                            .copyWith(color: KColors.baseContentMid),
                      ),
                      if (!widget.isMesTrajets && !_searchExpanded) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _resetSearch,
                          child: const Text('Modifier la recherche'),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            // ── Liste ─────────────────────────────────────────────────────
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                sliver: SliverList.builder(
                  itemCount: state.trajets.length,
                  itemBuilder: (context, i) {
                    final t = state.trajets[i];
                    return TrajetCard(
                      trajet: t,
                      onTap: () =>
                          context.push('$prefix/trajet/${t.id}'),
                      showActions: widget.isMesTrajets,
                      onCommencer: widget.isMesTrajets &&
                              t.statut == 'ouvert'
                          ? () async => ref
                              .read(trajetsProvider.notifier)
                              .commencerTrajet(t.id)
                          : null,
                      onTerminer: widget.isMesTrajets &&
                              t.statut == 'en_cours'
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
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<LocationSuggestion> onPickupSelected;
  final ValueChanged<LocationSuggestion> onDropoffSelected;
  final VoidCallback onSelectDate;
  final VoidCallback onSearch;

  const _SearchPanel({
    required this.departCtrl,
    required this.destinationCtrl,
    required this.pickupSuggestion,
    required this.dropoffSuggestion,
    required this.selectedDate,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onPickupSelected,
    required this.onDropoffSelected,
    required this.onSelectDate,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                const Icon(Icons.search, color: KColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isExpanded
                        ? 'Où allez-vous ?'
                        : _searchSummary(),
                    style: KTextStyles.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                        color: KColors.baseContent),
                  ),
                ),
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
                  hint: 'Ville de départ',
                  icon: Icons.trip_origin,
                  iconColor: KColors.primary,
                  onSelected: onPickupSelected,
                ),
                const SizedBox(height: 10),
                // Destination
                _AutocompleteField(
                  controller: destinationCtrl,
                  hint: 'Destination',
                  icon: Icons.location_on,
                  iconColor: KColors.error,
                  onSelected: onDropoffSelected,
                ),
                const SizedBox(height: 10),
                // Date + bouton
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onSelectDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: KColors.base200,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: KColors.border),
                        ),
                        child: Row(children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 16, color: KColors.baseContentMid),
                          const SizedBox(width: 8),
                          Text(
                            selectedDate != null
                                ? DateFormat('dd/MM/yyyy')
                                    .format(selectedDate!)
                                : 'Date (optionnel)',
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
                  const SizedBox(width: 10),
                  KButton(
                    label: 'Rechercher',
                    icon: Icons.search,
                    fullWidth: false,
                    onPressed: onSearch,
                  ),
                ]),
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
    return 'Tous les trajets';
  }
}

// ── Champ autocomplete inline ─────────────────────────────────────────────────

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
      setState(() => _suggestions = []);
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
