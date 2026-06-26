import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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

// Modèle léger pour une escale en cours de saisie
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
  final _formKey   = GlobalKey<FormState>();
  final _scrollCtrl = ScrollController();
  final _placesCtrl = TextEditingController(text: '3');

  // Clés pour scroll vers erreur
  final _departKey     = GlobalKey();
  final _destinationKey = GlobalKey();
  final _vehiculeKey    = GlobalKey();
  final _placesKey      = GlobalKey();

  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 2));
  int? _selectedVehiculeId;
  String _typeVehicule = 'voiture';
  bool _isLoading = false;
  bool _isCalculatingRoute = false;

  LocationSuggestion? _departSuggestion;
  LocationSuggestion? _destinationSuggestion;
  OsrmRoute? _route;

  // Erreurs manuelles pour les champs non-Form
  String? _departError;
  String? _destinationError;
  String? _vehiculeError;

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
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _onDepartSelected(LocationSuggestion s) async {
    setState(() {
      _departSuggestion = s;
      _departError = null;
      _route = null;
    });
    debugPrint('[CreateTrajet] Départ sélectionné: ${s.displayName} (${s.lat}, ${s.lng})');
    await _calculerRoute();
  }

  Future<void> _onDestinationSelected(LocationSuggestion s) async {
    setState(() {
      _destinationSuggestion = s;
      _destinationError = null;
      _route = null;
    });
    debugPrint('[CreateTrajet] Destination sélectionnée: ${s.displayName} (${s.lat}, ${s.lng})');
    await _calculerRoute();
  }

  Future<void> _calculerRoute() async {
    if (_departSuggestion == null || _destinationSuggestion == null) return;
    setState(() => _isCalculatingRoute = true);
    debugPrint('[CreateTrajet] Calcul route: '
        '(${_departSuggestion!.lat},${_departSuggestion!.lng}) → '
        '(${_destinationSuggestion!.lat},${_destinationSuggestion!.lng})');
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
    debugPrint('[CreateTrajet] Route: ${route?.distanceKm} km, ${route?.durationMin} min');
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
    setState(() => _selectedDate =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    // 1. Vérification activation compte conducteur
    final canPublish = ref.read(canPublishTripProvider);
    if (!canPublish) {
      showDriverActivationDialog(context);
      return;
    }

    // 2. Validation champs Form (places)
    final formOk = _formKey.currentState!.validate();

    // 3. Validation champs manuels
    bool hasError = !formOk;

    if (_departSuggestion == null) {
      setState(() => _departError = 'Veuillez renseigner le lieu de départ.');
      hasError = true;
      debugPrint('[CreateTrajet] Champ invalide: départ');
    }
    if (_destinationSuggestion == null) {
      setState(() => _destinationError = 'Veuillez renseigner la destination.');
      hasError = true;
      debugPrint('[CreateTrajet] Champ invalide: destination');
    }
    if (_selectedVehiculeId == null) {
      setState(() => _vehiculeError = 'Veuillez sélectionner un véhicule.');
      hasError = true;
      debugPrint('[CreateTrajet] Champ invalide: véhicule');
    }

    if (hasError) {
      _scrollToFirstError();
      return;
    }

    if (_route == null) {
      _showSnack('Calcul de la route en cours, veuillez patienter…', error: true);
      return;
    }

    // 4. Logs avant envoi
    debugPrint('[CreateTrajet] ===== SOUMISSION =====');
    debugPrint('[CreateTrajet] Départ    : ${_departSuggestion!.displayName}');
    debugPrint('[CreateTrajet] Arrivée   : ${_destinationSuggestion!.displayName}');
    debugPrint('[CreateTrajet] Lat départ: ${_departSuggestion!.lat}');
    debugPrint('[CreateTrajet] Lng départ: ${_departSuggestion!.lng}');
    debugPrint('[CreateTrajet] Lat dest  : ${_destinationSuggestion!.lat}');
    debugPrint('[CreateTrajet] Lng dest  : ${_destinationSuggestion!.lng}');
    debugPrint('[CreateTrajet] Escales   : ${_escales.map((e) => e.nom).toList()}');
    debugPrint('[CreateTrajet] Date      : ${_selectedDate.toIso8601String()}');
    debugPrint('[CreateTrajet] Places    : ${_placesCtrl.text}');
    debugPrint('[CreateTrajet] vehicule_id: $_selectedVehiculeId');
    debugPrint('[CreateTrajet] Distance  : ${_route!.distanceKm} km');
    debugPrint('[CreateTrajet] Coût total: $_coutTotal FCFA');

    final payload = {
      'vehicule_id': _selectedVehiculeId,      // ← clé attendue par TrajetCreateSerializer
      'depart': _departSuggestion!.displayName,
      'destination': _destinationSuggestion!.displayName,
      'depart_lat': _departSuggestion!.lat,
      'depart_lng': _departSuggestion!.lng,
      'destination_lat': _destinationSuggestion!.lat,
      'destination_lng': _destinationSuggestion!.lng,
      'distance_km': _route!.distanceKm,
      'cout_total': double.parse(_coutTotal.toStringAsFixed(2)),
      'prix_par_place': double.parse(_prixParPlace.toStringAsFixed(2)),
      'date_heure_depart': _selectedDate.toIso8601String(),
      'places_disponibles': int.parse(_placesCtrl.text),
    };
    debugPrint('[CreateTrajet] Payload: $payload');

    setState(() => _isLoading = true);
    final ok = await ref.read(trajetsProvider.notifier).creerTrajet(payload);
    if (!mounted) return;

    // 5. Escales (optionnelles)
    if (ok && _escales.isNotEmpty) {
      final trajetId = ref.read(trajetsProvider).lastCreatedId;
      debugPrint('[CreateTrajet] Ajout escales pour trajet $trajetId');
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
            debugPrint('[CreateTrajet] Escale ${_escales[i].nom} ajoutée');
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
      debugPrint('[CreateTrajet] Erreur création: $error');
      _showSnack(error ?? 'Erreur lors de la création', error: true);
    }
  }

  void _scrollToFirstError() {
    // Scroll vers le premier champ en erreur
    final keys = [
      if (_departSuggestion == null) _departKey,
      if (_destinationSuggestion == null) _destinationKey,
      if (_selectedVehiculeId == null) _vehiculeKey,
    ];
    if (keys.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = keys.first.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              alignment: 0.1);
        }
      });
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
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(KSpacing.pagePaddingH),
          children: [
            const SizedBox(height: KSpacing.lg),

            // ── Itinéraire ──────────────────────────────────────────────
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel(icon: Icons.route_outlined, label: 'Itinéraire'),
                    const SizedBox(height: KSpacing.lg),

                    // Départ (validation manuelle via _departError, pas via Form)
                    _LocationField(
                      key: _departKey,
                      label: 'Ville de départ',
                      hint: 'Ex : Lomé, Quartier Adéwui',
                      prefixIconData: Icons.trip_origin,
                      prefixIconColor: KColors.primary,
                      onSelected: _onDepartSelected,
                      optional: true,
                      externalError: _departError,
                      errorLabel: 'lieu de départ',
                    ),
                    const SizedBox(height: KSpacing.md),

                    // Destination (validation manuelle via _destinationError, pas via Form)
                    _LocationField(
                      key: _destinationKey,
                      label: 'Destination',
                      hint: 'Ex : Kpalimé, Marché central',
                      prefixIconData: Icons.location_on,
                      prefixIconColor: KColors.error,
                      onSelected: _onDestinationSelected,
                      optional: true,
                      externalError: _destinationError,
                      errorLabel: 'destination',
                    ),

                    // Calcul route
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

                    // Résumé route
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

            // ── Escales (optionnelles) ──────────────────────────────────
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _SectionLabel(
                          icon: Icons.alt_route_outlined,
                          label: 'Étapes intermédiaires',
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: KColors.base300,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Optionnel',
                              style: KTextStyles.meta.copyWith(
                                  color: KColors.baseContentMid,
                                  fontSize: 10)),
                        ),
                      ],
                    ),
                    const SizedBox(height: KSpacing.lg),

                    // Chips des escales ajoutées
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

                    // Champ escale (optionnel — ne bloque pas la soumission)
                    _LocationField(
                      key: ValueKey(_escaleFieldKey),
                      label: 'Ajouter une étape',
                      hint: 'Ex : Tsévié, Gare routière',
                      prefixIconData: Icons.add_location_alt_outlined,
                      prefixIconColor: const Color(0xFFFF8C00),
                      onSelected: (s) =>
                          setState(() => _pendingEscale = s),
                      optional: true,
                      showCurrentPositionButton: false,
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
                            style: KTextStyles.bodySm
                                .copyWith(color: const Color(0xFFFF8C00)),
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

            // ── Date & heure ────────────────────────────────────────────
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
                                  DateFormat(
                                          "EEE d MMM yyyy 'à' HH:mm", 'fr_FR')
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

            // ── Véhicule & places ───────────────────────────────────────
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

                    // Dropdown véhicule
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
                        return Column(
                          key: _vehiculeKey,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<int>(
                              initialValue: _selectedVehiculeId,
                              decoration: _dropdownDecoration(
                                  'Sélectionner un véhicule',
                                  error: _vehiculeError),
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
                                _vehiculeError = null;
                                final v =
                                    actifs.firstWhere((v) => v.id == id);
                                _typeVehicule = v.typeVehicule;
                                _placesCtrl.text =
                                    (v.placesMax - 1).toString();
                              }),
                            ),
                            if (_vehiculeError != null) ...[
                              const SizedBox(height: 4),
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 12),
                                child: Text(_vehiculeError!,
                                    style: KTextStyles.caption.copyWith(
                                        color: KColors.error)),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: KSpacing.md),

                    // Nombre de places
                    TextFormField(
                      key: _placesKey,
                      controller: _placesCtrl,
                      keyboardType: TextInputType.number,
                      style: KTextStyles.bodyLg,
                      decoration: _inputDecoration(
                          'Places disponibles', '3',
                          icon: Icons.people_outline),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          debugPrint('[CreateTrajet] Champ invalide: places (vide)');
                          return 'Veuillez saisir le nombre de places.';
                        }
                        final n = int.tryParse(v.trim());
                        if (n == null || n < 1) {
                          debugPrint('[CreateTrajet] Champ invalide: places ($v)');
                          return 'Minimum 1 place disponible.';
                        }
                        if (n > 20) return 'Maximum 20 places.';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: KSpacing.xl),

            // ── Résumé tarifaire ────────────────────────────────────────
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

            // ── Indicateurs manquants ───────────────────────────────────
            if (_departSuggestion == null ||
                _destinationSuggestion == null ||
                _selectedVehiculeId == null ||
                _route == null) ...[
              _MissingFieldsHint(
                departOk: _departSuggestion != null,
                destinationOk: _destinationSuggestion != null,
                vehiculeOk: _selectedVehiculeId != null,
                routeOk: _route != null,
                isCalculating: _isCalculatingRoute,
              ),
              const SizedBox(height: KSpacing.lg),
            ],

            // ── Bouton publier ──────────────────────────────────────────
            KButton(
              label: 'Publier le trajet',
              icon: Icons.publish_rounded,
              isLoading: _isLoading || _isCalculatingRoute,
              onPressed: (_isLoading || _isCalculatingRoute) ? null : _submit,
            ),
            const SizedBox(height: KSpacing.xxl),
          ],
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label, {String? error}) =>
      InputDecoration(
        labelText: label,
        labelStyle: KTextStyles.caption.copyWith(
            color: error != null ? KColors.error : null),
        prefixIcon: Icon(Icons.directions_car_outlined,
            color: error != null
                ? KColors.error
                : KColors.baseContentMid,
            size: 18),
        filled: true,
        fillColor: KColors.base200,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: error != null ? KColors.error : KColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: error != null ? KColors.error : KColors.border,
                width: error != null ? 1.5 : 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: KColors.primary, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  InputDecoration _inputDecoration(String label, String hint,
          {required IconData icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: KTextStyles.caption,
        hintStyle:
            KTextStyles.caption.copyWith(color: KColors.baseContentLow),
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
            borderSide:
                const BorderSide(color: KColors.primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: KColors.error, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: KColors.error, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}

// ── Hint : champs manquants ───────────────────────────────────────────────────

class _MissingFieldsHint extends StatelessWidget {
  final bool departOk, destinationOk, vehiculeOk, routeOk, isCalculating;
  const _MissingFieldsHint({
    required this.departOk,
    required this.destinationOk,
    required this.vehiculeOk,
    required this.routeOk,
    required this.isCalculating,
  });

  @override
  Widget build(BuildContext context) {
    final missing = <String>[
      if (!departOk) 'Lieu de départ',
      if (!destinationOk) 'Destination',
      if (!vehiculeOk) 'Véhicule',
      if (!routeOk && !isCalculating && departOk && destinationOk)
        'Calcul de route échoué — vérifiez la connexion',
    ];
    if (missing.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: KColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: KColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.info_outline,
                color: KColors.warning, size: 16),
            const SizedBox(width: 6),
            Text('Champs manquants :',
                style: KTextStyles.bodySm.copyWith(
                    color: KColors.warning,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          ...missing.map((m) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  const SizedBox(width: 22),
                  const Text('• ',
                      style: TextStyle(color: KColors.warning)),
                  Text(m,
                      style: KTextStyles.caption.copyWith(
                          color: KColors.warning)),
                ]),
              )),
        ],
      ),
    );
  }
}

// ── Champ de localisation avec GPS intégré ────────────────────────────────────

class _LocationField extends StatefulWidget {
  final String label;
  final String hint;
  final String errorLabel;
  final IconData prefixIconData;
  final Color prefixIconColor;
  final ValueChanged<LocationSuggestion> onSelected;
  final bool optional;
  final bool showCurrentPositionButton;
  final String? externalError;

  const _LocationField({
    super.key,
    required this.label,
    required this.hint,
    required this.prefixIconData,
    required this.prefixIconColor,
    required this.onSelected,
    this.optional = false,
    this.showCurrentPositionButton = true,
    this.externalError,
    this.errorLabel = 'ce champ',
  });

  @override
  State<_LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends State<_LocationField> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<LocationSuggestion> _suggestions = [];
  bool _isSearching = false;
  bool _isResolvingGps = false;
  bool _selected = false;
  String? _gpsError;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Autocomplétion texte ──────────────────────────────────────────────────

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
      final results = await NominatimService.autocomplete(query,
          includeCurrentPosition: widget.showCurrentPositionButton);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    });
  }

  // ── Sélection d'une suggestion ────────────────────────────────────────────

  void _select(LocationSuggestion s) {
    if (s.isCurrentPosition) {
      _useCurrentPosition();
      return;
    }
    _selected = true;
    _ctrl.text = s.shortName;
    setState(() {
      _suggestions = [];
      _gpsError = null;
    });
    _focus.unfocus();
    NominatimService.addToHistory(s);
    widget.onSelected(s);
  }

  // ── Bouton "Ma position actuelle" ─────────────────────────────────────────

  Future<void> _useCurrentPosition() async {
    setState(() {
      _isResolvingGps = true;
      _gpsError = null;
      _suggestions = [];
      _ctrl.text = 'Localisation en cours…';
    });
    _focus.unfocus();

    try {
      // 1. GPS activé ?
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        setState(() {
          _isResolvingGps = false;
          _ctrl.text = '';
          _gpsError = 'GPS désactivé. Veuillez activer votre GPS.';
        });
        _showGpsDisabledDialog();
        return;
      }

      // 2. Permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isResolvingGps = false;
          _ctrl.text = '';
          _gpsError =
              'Accès GPS refusé définitivement. Ouvrez les paramètres.';
        });
        await Geolocator.openAppSettings();
        return;
      }
      if (permission == LocationPermission.denied) {
        setState(() {
          _isResolvingGps = false;
          _ctrl.text = '';
          _gpsError = 'Veuillez autoriser l\'accès à votre position.';
        });
        return;
      }

      // 3. Obtenir position
      debugPrint('[LocationField] GPS: récupération position…');
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;

      debugPrint('[LocationField] GPS: position (${pos.latitude}, ${pos.longitude})');

      // 4. Reverse geocoding
      final name =
          await NominatimService.reverseGeocode(pos.latitude, pos.longitude);
      if (!mounted) return;

      final resolved = LocationSuggestion(
        displayName: name ?? 'Ma position actuelle',
        shortName: name ?? 'Position actuelle',
        lat: pos.latitude,
        lng: pos.longitude,
        isCurrentPosition: true,
      );

      debugPrint('[LocationField] GPS: adresse résolue "${resolved.displayName}"');

      _selected = true;
      _ctrl.text = resolved.shortName;
      setState(() {
        _isResolvingGps = false;
        _gpsError = null;
      });
      widget.onSelected(resolved);
    } on LocationServiceDisabledException {
      if (!mounted) return;
      setState(() {
        _isResolvingGps = false;
        _ctrl.text = '';
        _gpsError = 'GPS désactivé. Veuillez activer votre GPS.';
      });
      _showGpsDisabledDialog();
    } catch (e) {
      debugPrint('[LocationField] GPS erreur: $e');
      if (!mounted) return;
      setState(() {
        _isResolvingGps = false;
        _ctrl.text = '';
        _gpsError =
            'Impossible de récupérer votre position. Réessayez.';
      });
    }
  }

  void _showGpsDisabledDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.location_off_rounded,
              color: KColors.warning, size: 20),
          SizedBox(width: 8),
          Text('GPS désactivé'),
        ]),
        content: const Text(
            'Votre GPS est désactivé.\nActivez-le pour utiliser votre position actuelle.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler',
                style: TextStyle(color: KColors.baseContentMid)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await Geolocator.openLocationSettings();
            },
            child: const Text('Ouvrir les paramètres',
                style: TextStyle(color: KColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasError = (widget.externalError != null) ||
        (_gpsError != null);
    final errorMsg = _gpsError ?? widget.externalError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Champ texte ──────────────────────────────────────────────
        TextFormField(
          controller: _ctrl,
          focusNode: _focus,
          style: KTextStyles.bodyLg,
          readOnly: _isResolvingGps,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            labelStyle: KTextStyles.caption.copyWith(
                color: hasError ? KColors.error : null),
            hintStyle: KTextStyles.caption
                .copyWith(color: KColors.baseContentLow),
            prefixIcon: Icon(widget.prefixIconData,
                color: hasError
                    ? KColors.error
                    : widget.prefixIconColor,
                size: 18),
            suffixIcon: _isResolvingGps
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: KColors.primary),
                    ),
                  )
                : _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: KColors.primary),
                        ),
                      )
                    : (_selected && !hasError)
                        ? const Icon(Icons.check_circle_rounded,
                            color: KColors.success, size: 20)
                        : null,
            filled: true,
            fillColor: KColors.base200,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: hasError ? KColors.error : KColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: hasError ? KColors.error : KColors.border,
                    width: hasError ? 1.5 : 1)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: hasError ? KColors.error : KColors.primary,
                    width: 2)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: KColors.error, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onChanged: _onChanged,
          validator: (v) {
            if (widget.optional) return null;
            if (!_selected || v == null || v.trim().isEmpty) {
              return 'Veuillez renseigner le ${widget.errorLabel}.';
            }
            return null;
          },
        ),

        // ── Message d'erreur GPS ou externe ─────────────────────────
        if (errorMsg != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(children: [
              const Icon(Icons.error_outline,
                  color: KColors.error, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(errorMsg,
                    style: KTextStyles.caption
                        .copyWith(color: KColors.error)),
              ),
            ]),
          ),
        ],

        // ── Bouton "Ma position actuelle" dédié ──────────────────────
        if (widget.showCurrentPositionButton && !_isResolvingGps) ...[
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _useCurrentPosition,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 4, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.my_location_rounded,
                      size: 15,
                      color: _gpsError != null
                          ? KColors.baseContentMid
                          : KColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Utiliser ma position actuelle',
                    style: KTextStyles.caption.copyWith(
                      color: _gpsError != null
                          ? KColors.baseContentMid
                          : KColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        if (_isResolvingGps) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: KColors.primary),
                ),
                const SizedBox(width: 8),
                Text('Récupération de votre position…',
                    style: KTextStyles.caption
                        .copyWith(color: KColors.primary)),
              ],
            ),
          ),
        ],

        // ── Dropdown de suggestions ───────────────────────────────────
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
              itemCount: _suggestions.length.clamp(0, 6),
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: KColors.border),
              itemBuilder: (_, i) {
                final s = _suggestions[i];
                if (s.isCurrentPosition) {
                  return ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: KColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.my_location_rounded,
                          color: KColors.primary, size: 16),
                    ),
                    title: Text('Ma position actuelle',
                        style: KTextStyles.bodySm.copyWith(
                            fontWeight: FontWeight.w600,
                            color: KColors.primary)),
                    subtitle: const Text('GPS',
                        style: TextStyle(
                            color: KColors.baseContentMid,
                            fontSize: 11)),
                    onTap: () => _select(s),
                  );
                }
                if (s.isHistory) {
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.history_rounded,
                        color: KColors.baseContentMid, size: 18),
                    title: Text(s.shortName,
                        style: KTextStyles.bodySm
                            .copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text(s.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: KTextStyles.caption),
                    onTap: () => _select(s),
                  );
                }
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
