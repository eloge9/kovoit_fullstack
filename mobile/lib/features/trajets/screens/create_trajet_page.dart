import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/trajet_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../verification/providers/verification_provider.dart';
import '../../verification/widgets/driver_activation_guard.dart';
import '../../../core/services/nominatim_service.dart';
import '../../../core/services/osrm_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';

// Modèle léger pour une escale en cours de saisie (avant création)
class _EscaleInput {
  final String nom;
  final double lat;
  final double lng;
  const _EscaleInput({required this.nom, required this.lat, required this.lng});
}

class CreateTrajetPage extends ConsumerStatefulWidget {
  const CreateTrajetPage({super.key});

  @override
  ConsumerState<CreateTrajetPage> createState() => _CreateTrajetPageState();
}

class _CreateTrajetPageState extends ConsumerState<CreateTrajetPage> {
  final _formKey = GlobalKey<FormState>();
  final _placesCtrl = TextEditingController(text: '3');

  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 2));
  int? _selectedVehiculeId;
  String _typeVehicule = 'voiture';
  bool _isLoading = false;
  bool _isCalculatingRoute = false;

  LocationSuggestion? _departSuggestion;
  LocationSuggestion? _destinationSuggestion;
  OsrmRoute? _route;

  final List<_EscaleInput> _escales = [];
  LocationSuggestion? _pendingEscale;
  int _escaleFieldKey = 0;

  double get _coutTotal {
    final dist = _route?.distanceKm ?? 0;
    return dist * (AppConstants.tarifCarburant[_typeVehicule] ?? 65);
  }

  double get _prixParPlace {
    final places = int.tryParse(_placesCtrl.text) ?? 1;
    return places == 0 ? _coutTotal : _coutTotal / places;
  }

  bool get _canSubmit =>
      _departSuggestion != null &&
      _destinationSuggestion != null &&
      _route != null &&
      _selectedVehiculeId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vehiculesProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _placesCtrl.dispose();
    super.dispose();
  }

  Future<void> _onDepartSelected(LocationSuggestion s) async {
    setState(() {
      _departSuggestion = s;
      _route = null;
    });
    await _calculerRoute();
  }

  Future<void> _onDestinationSelected(LocationSuggestion s) async {
    setState(() {
      _destinationSuggestion = s;
      _route = null;
    });
    await _calculerRoute();
  }

  Future<void> _calculerRoute() async {
    if (_departSuggestion == null || _destinationSuggestion == null) return;
    setState(() => _isCalculatingRoute = true);
    final route = await OsrmService.getRoute(
      _departSuggestion!.lat,
      _departSuggestion!.lng,
      _destinationSuggestion!.lat,
      _destinationSuggestion!.lng,
    );
    if (!mounted) return;
    setState(() {
      _route = route;
      _isCalculatingRoute = false;
    });
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: KColors.primary),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: KColors.primary),
        ),
        child: child!,
      ),
    );
    if (time == null) return;
    setState(() => _selectedDate = DateTime(
          date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    // Vérification activation compte conducteur
    final canPublish = ref.read(canPublishTripProvider);
    if (!canPublish) {
      showDriverActivationDialog(context);
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_departSuggestion == null || _destinationSuggestion == null) {
      _showSnack('Veuillez sélectionner le départ et la destination', error: true);
      return;
    }
    if (_route == null) {
      _showSnack('Calcul de la route en cours…', error: true);
      return;
    }
    if (_selectedVehiculeId == null) {
      _showSnack('Veuillez sélectionner un véhicule', error: true);
      return;
    }

    setState(() => _isLoading = true);
    final ok = await ref.read(trajetsProvider.notifier).creerTrajet({
      'vehicule': _selectedVehiculeId,
      'depart': _departSuggestion!.displayName,
      'destination': _destinationSuggestion!.displayName,
      'depart_lat': _departSuggestion!.lat,
      'depart_lng': _departSuggestion!.lng,
      'destination_lat': _destinationSuggestion!.lat,
      'destination_lng': _destinationSuggestion!.lng,
      'distance_km': _route!.distanceKm,
      'cout_total': _coutTotal,
      'prix_par_place': _prixParPlace,
      'date_heure_depart': _selectedDate.toIso8601String(),
      'places_disponibles': int.parse(_placesCtrl.text),
      'polyline_osrm': _route!.encodedPolyline,
    });
    if (!mounted) return;

    if (ok && _escales.isNotEmpty) {
      final trajetId = ref.read(trajetsProvider).lastCreatedId;
      if (trajetId != null) {
        final repo = ref.read(trajetRepositoryProvider);
        for (int i = 0; i < _escales.length; i++) {
          try {
            await repo.ajouterEscale(trajetId, {
              'nom': _escales[i].nom,
              'lat': _escales[i].lat,
              'lng': _escales[i].lng,
              'ordre': i,
            });
          } catch (e) {
            debugPrint('[CreateTrajet] ajouterEscale[${_escales[i].nom}] error: $e');
          }
        }
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      _showSnack('Trajet publié avec succès !');
      context.pop();
    } else {
      final error = ref.read(trajetsProvider).error;
      _showSnack(error ?? 'Erreur lors de la création', error: true);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? KColors.error : KColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final vehiculesState = ref.watch(vehiculesProvider);

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
          'Proposer un trajet',
          style: KTextStyles.bodySm.copyWith(
            fontWeight: FontWeight.w700,
            color: KColors.baseContent,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(KSpacing.pagePaddingH),
          children: [
            const SizedBox(height: KSpacing.lg),

            // ── Itinéraire ────────────────────────────────────────────────
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel(icon: Icons.route_outlined, label: 'Itinéraire'),
                    const SizedBox(height: KSpacing.lg),
                    _LocationField(
                      label: 'Ville de départ',
                      hint: 'Ex : Lomé, Quartier Adéwui',
                      prefixIconData: Icons.trip_origin,
                      prefixIconColor: KColors.primary,
                      onSelected: _onDepartSelected,
                    ),
                    const SizedBox(height: KSpacing.md),
                    _LocationField(
                      label: 'Destination',
                      hint: 'Ex : Kpalimé, Marché central',
                      prefixIconData: Icons.location_on,
                      prefixIconColor: KColors.error,
                      onSelected: _onDestinationSelected,
                    ),
                    if (_isCalculatingRoute) ...[
                      const SizedBox(height: KSpacing.md),
                      const Row(children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: KColors.primary, strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Calcul de la route…',
                            style: TextStyle(
                                color: KColors.baseContentMid, fontSize: 13)),
                      ]),
                    ],
                    if (_route != null) ...[
                      const SizedBox(height: KSpacing.md),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: KColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: KColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.straighten_rounded,
                                color: KColors.primary, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              '${_route!.distanceKm.toStringAsFixed(1)} km  •  '
                              '${_route!.durationMin.toStringAsFixed(0)} min',
                              style: KTextStyles.bodySm.copyWith(
                                color: KColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: KSpacing.xl),

            // ── Escales intermédiaires ────────────────────────────────────
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel(
                      icon: Icons.alt_route_outlined,
                      label: 'Étapes intermédiaires (optionnel)',
                    ),
                    const SizedBox(height: KSpacing.lg),
                    if (_escales.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _escales.map((e) {
                          return Chip(
                            label: Text(e.nom, style: KTextStyles.caption),
                            deleteIcon:
                                const Icon(Icons.close_rounded, size: 14),
                            onDeleted: () =>
                                setState(() => _escales.remove(e)),
                            backgroundColor:
                                const Color(0xFFFF8C00).withValues(alpha: 0.1),
                            labelStyle: KTextStyles.caption.copyWith(
                                color: const Color(0xFFFF8C00)),
                            deleteIconColor: const Color(0xFFFF8C00),
                            side: const BorderSide(
                                color: Color(0xFFFF8C00), width: 0.5),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: KSpacing.md),
                    ],
                    _LocationField(
                      key: ValueKey(_escaleFieldKey),
                      label: 'Ajouter une étape',
                      hint: 'Ex : Tsévié, Gare routière',
                      prefixIconData: Icons.add_location_alt_outlined,
                      prefixIconColor: const Color(0xFFFF8C00),
                      onSelected: (s) =>
                          setState(() => _pendingEscale = s),
                      optional: true,
                    ),
                    if (_pendingEscale != null) ...[
                      const SizedBox(height: KSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(Icons.add_circle_outline,
                              size: 18, color: Color(0xFFFF8C00)),
                          label: Text(
                            'Ajouter cette étape',
                            style: KTextStyles.bodySm.copyWith(
                                color: const Color(0xFFFF8C00)),
                          ),
                          onPressed: () => setState(() {
                            _escales.add(_EscaleInput(
                              nom: _pendingEscale!.shortName,
                              lat: _pendingEscale!.lat,
                              lng: _pendingEscale!.lng,
                            ));
                            _pendingEscale = null;
                            _escaleFieldKey++;
                          }),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: KSpacing.xl),

            // ── Date & heure ──────────────────────────────────────────────
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel(
                        icon: Icons.schedule_rounded,
                        label: 'Date et heure de départ'),
                    const SizedBox(height: KSpacing.lg),
                    GestureDetector(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: KColors.base200,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: KColors.border),
                        ),
                        child: Row(children: [
                          const Icon(Icons.calendar_today_outlined,
                              color: KColors.primary, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Date de départ', style: KTextStyles.meta),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat("EEE d MMM yyyy 'à' HH:mm", 'fr_FR')
                                      .format(_selectedDate),
                                  style: KTextStyles.bodySm.copyWith(
                                      color: KColors.primary,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.edit_outlined,
                              color: KColors.baseContentMid, size: 16),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: KSpacing.xl),

            // ── Véhicule & places ─────────────────────────────────────────
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel(
                        icon: Icons.directions_car_outlined,
                        label: 'Véhicule et places'),
                    const SizedBox(height: KSpacing.lg),
                    vehiculesState.when(
                      loading: () => const Center(
                          child: CircularProgressIndicator(
                              color: KColors.primary)),
                      error: (e, _) =>
                          Text('Erreur: $e', style: KTextStyles.caption),
                      data: (vehicules) {
                        final actifs =
                            vehicules.where((v) => v.actif).toList();
                        if (actifs.isEmpty) {
                          return Column(children: [
                            Text('Aucun véhicule enregistré',
                                style: KTextStyles.caption),
                            const SizedBox(height: 8),
                            KButton(
                              label: 'Ajouter un véhicule',
                              variant: KButtonVariant.outline,
                              onPressed: () =>
                                  context.push('/conducteur/vehicules'),
                            ),
                          ]);
                        }
                        return DropdownButtonFormField<int>(
                          initialValue: _selectedVehiculeId,
                          decoration: _dropdownDecoration('Sélectionner un véhicule'),
                          style: KTextStyles.bodySm
                              .copyWith(color: KColors.baseContent),
                          items: actifs
                              .map((v) => DropdownMenuItem(
                                    value: v.id,
                                    child: Text(v.displayName,
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (id) => setState(() {
                            _selectedVehiculeId = id;
                            final v = actifs.firstWhere((v) => v.id == id);
                            _typeVehicule = v.typeVehicule;
                            _placesCtrl.text =
                                (v.placesMax - 1).toString();
                          }),
                        );
                      },
                    ),
                    const SizedBox(height: KSpacing.md),
                    TextFormField(
                      controller: _placesCtrl,
                      keyboardType: TextInputType.number,
                      style: KTextStyles.bodyLg,
                      decoration: _inputDecoration(
                          'Places disponibles', '3',
                          icon: Icons.people_outline),
                      validator: (v) {
                        if (v?.isEmpty == true) return 'Champ requis';
                        final n = int.tryParse(v!);
                        if (n == null || n < 1) return 'Minimum 1 place';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: KSpacing.xl),

            // ── Résumé tarifaire ──────────────────────────────────────────
            if (_route != null && _selectedVehiculeId != null) ...[
              KCard(
                child: Padding(
                  padding: const EdgeInsets.all(KSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel(
                          icon: Icons.payments_outlined,
                          label: 'Résumé tarifaire'),
                      const SizedBox(height: KSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(KSpacing.md),
                        decoration: BoxDecoration(
                          color: KColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: KColors.primary.withValues(alpha: 0.15)),
                        ),
                        child: Column(children: [
                          _TarifRow(
                              label: 'Coût total du trajet',
                              value:
                                  '${_coutTotal.toStringAsFixed(0)} FCFA'),
                          const Divider(color: KColors.border, height: 16),
                          _TarifRow(
                              label: 'Prix par place',
                              value:
                                  '${_prixParPlace.toStringAsFixed(0)} FCFA',
                              isBold: true,
                              color: KColors.primary),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tarif ${AppConstants.vehiculeLabel(_typeVehicule)} : '
                        '${AppConstants.tarifCarburant[_typeVehicule]} FCFA/km',
                        style: KTextStyles.meta,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: KSpacing.xl),
            ],

            KButton(
              label: 'Publier le trajet',
              icon: Icons.publish_rounded,
              isLoading: _isLoading || _isCalculatingRoute,
              onPressed: (_isLoading || _isCalculatingRoute || !_canSubmit)
                  ? null
                  : _submit,
            ),
            const SizedBox(height: KSpacing.xxl),
          ],
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: KTextStyles.caption,
        prefixIcon: const Icon(Icons.directions_car_outlined,
            color: KColors.baseContentMid, size: 18),
        filled: true,
        fillColor: KColors.base200,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: KColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: KColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: KColors.primary, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  InputDecoration _inputDecoration(String label, String hint,
          {required IconData icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: KTextStyles.caption,
        hintStyle: KTextStyles.caption
            .copyWith(color: KColors.baseContentLow),
        prefixIcon: Icon(icon, color: KColors.baseContentMid, size: 18),
        filled: true,
        fillColor: KColors.base200,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: KColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: KColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: KColors.primary, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}

// ── Autocomplete field ────────────────────────────────────────────────────────

class _LocationField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData prefixIconData;
  final Color prefixIconColor;
  final ValueChanged<LocationSuggestion> onSelected;
  final bool optional;

  const _LocationField({
    super.key,
    required this.label,
    required this.hint,
    required this.prefixIconData,
    required this.prefixIconColor,
    required this.onSelected,
    this.optional = false,
  });

  @override
  State<_LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends State<_LocationField> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<LocationSuggestion> _suggestions = [];
  bool _isSearching = false;
  bool _selected = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String query) {
    _selected = false;
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      final results = await NominatimService.autocomplete(query);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    });
  }

  void _select(LocationSuggestion s) {
    _selected = true;
    _ctrl.text = s.shortName;
    setState(() => _suggestions = []);
    _focus.unfocus();
    widget.onSelected(s);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _ctrl,
          focusNode: _focus,
          style: KTextStyles.bodyLg,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            labelStyle: KTextStyles.caption,
            hintStyle:
                KTextStyles.caption.copyWith(color: KColors.baseContentLow),
            prefixIcon: Icon(widget.prefixIconData,
                color: widget.prefixIconColor, size: 18),
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: KColors.primary),
                    ),
                  )
                : null,
            filled: true,
            fillColor: KColors.base200,
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: _onChanged,
          validator: (v) => widget.optional
              ? null
              : (v?.isEmpty == true || !_selected)
                  ? 'Sélectionnez un lieu'
                  : null,
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: KColors.base100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
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

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: KColors.primary),
        const SizedBox(width: 8),
        Text(label,
            style: KTextStyles.bodySm.copyWith(
                fontWeight: FontWeight.w700, color: KColors.baseContent)),
      ]);
}

class _TarifRow extends StatelessWidget {
  final String label, value;
  final bool isBold;
  final Color? color;
  const _TarifRow(
      {required this.label,
      required this.value,
      this.isBold = false,
      this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: KTextStyles.caption),
          Text(value,
              style: KTextStyles.bodySm.copyWith(
                  fontWeight:
                      isBold ? FontWeight.w700 : FontWeight.w500,
                  color: color ?? KColors.baseContent,
                  fontSize: isBold ? 16 : null)),
        ],
      );
}
