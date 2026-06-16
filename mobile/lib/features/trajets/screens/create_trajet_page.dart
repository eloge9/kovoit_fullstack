import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/trajet_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_text_field.dart';

class CreateTrajetPage extends ConsumerStatefulWidget {
  const CreateTrajetPage({super.key});

  @override
  ConsumerState<CreateTrajetPage> createState() => _CreateTrajetPageState();
}

class _CreateTrajetPageState extends ConsumerState<CreateTrajetPage> {
  final _formKey = GlobalKey<FormState>();
  final _departCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController();
  final _placesCtrl = TextEditingController(text: '3');

  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 2));
  int? _selectedVehiculeId;
  String _typeVehicule = 'voiture';
  bool _isLoading = false;

  double get _coutTotal {
    final dist = double.tryParse(_distanceCtrl.text) ?? 0;
    return dist * (AppConstants.tarifCarburant[_typeVehicule] ?? 65);
  }

  double get _prixParPlace {
    final places = int.tryParse(_placesCtrl.text) ?? 1;
    return places == 0 ? _coutTotal : _coutTotal / places;
  }

  bool get _showTarif =>
      _distanceCtrl.text.isNotEmpty &&
      double.tryParse(_distanceCtrl.text) != null &&
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
    _departCtrl.dispose();
    _destinationCtrl.dispose();
    _distanceCtrl.dispose();
    _placesCtrl.dispose();
    super.dispose();
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
    setState(
      () => _selectedDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehiculeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un véhicule'),
          backgroundColor: KColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final ok = await ref.read(trajetsProvider.notifier).creerTrajet({
      'vehicule': _selectedVehiculeId,
      'depart': _departCtrl.text.trim(),
      'destination': _destinationCtrl.text.trim(),
      'distance_km': double.parse(_distanceCtrl.text),
      'cout_total': _coutTotal,
      'prix_par_place': _prixParPlace,
      'date_heure_depart': _selectedDate.toIso8601String(),
      'places_disponibles': int.parse(_placesCtrl.text),
    });
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trajet publié avec succès !'),
          backgroundColor: KColors.success,
        ),
      );
      context.pop();
    } else {
      final error = ref.read(trajetsProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Erreur lors de la création'),
          backgroundColor: KColors.error,
        ),
      );
    }
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

            // ── Itinéraire ─────────────────────────────────────────────
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel(
                      icon: Icons.route_outlined,
                      label: 'Itinéraire',
                    ),
                    const SizedBox(height: KSpacing.lg),
                    KTextField(
                      controller: _departCtrl,
                      label: 'Ville de départ',
                      hint: 'Ex : Lomé, Quartier Adéwui',
                      prefixIcon: const Icon(
                        Icons.trip_origin,
                        color: KColors.primary,
                        size: 18,
                      ),
                      validator: (v) =>
                          v?.isEmpty == true ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: KSpacing.md),
                    KTextField(
                      controller: _destinationCtrl,
                      label: 'Destination',
                      hint: 'Ex : Kpalimé, Marché central',
                      prefixIcon: const Icon(
                        Icons.location_on,
                        color: KColors.error,
                        size: 18,
                      ),
                      validator: (v) =>
                          v?.isEmpty == true ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: KSpacing.md),
                    KTextField(
                      controller: _distanceCtrl,
                      label: 'Distance (km)',
                      hint: '120',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      prefixIcon: const Icon(
                        Icons.straighten_rounded,
                        color: KColors.baseContentMid,
                        size: 18,
                      ),
                      validator: (v) {
                        if (v?.isEmpty == true) return 'Champ requis';
                        if (double.tryParse(v!) == null) {
                          return 'Nombre invalide';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: KSpacing.xl),

            // ── Date & heure ───────────────────────────────────────────
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel(
                      icon: Icons.schedule_rounded,
                      label: 'Date et heure de départ',
                    ),
                    const SizedBox(height: KSpacing.lg),
                    GestureDetector(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: KColors.base200,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: KColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              color: KColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date de départ',
                                    style: KTextStyles.meta,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat(
                                      "EEE d MMM yyyy 'à' HH:mm",
                                      'fr_FR',
                                    ).format(_selectedDate),
                                    style: KTextStyles.bodySm.copyWith(
                                      color: KColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.edit_outlined,
                              color: KColors.baseContentMid,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: KSpacing.xl),

            // ── Véhicule & places ──────────────────────────────────────
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel(
                      icon: Icons.directions_car_outlined,
                      label: 'Véhicule et places',
                    ),
                    const SizedBox(height: KSpacing.lg),
                    vehiculesState.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: KColors.primary,
                        ),
                      ),
                      error: (e, _) =>
                          Text('Erreur: $e', style: KTextStyles.caption),
                      data: (vehicules) {
                        final actifs = vehicules.where((v) => v.actif).toList();
                        if (actifs.isEmpty) {
                          return Column(
                            children: [
                              Text(
                                'Aucun véhicule enregistré',
                                style: KTextStyles.caption,
                              ),
                              const SizedBox(height: 8),
                              KButton(
                                label: 'Ajouter un véhicule',
                                variant: KButtonVariant.outline,
                                onPressed: () =>
                                    context.push('/conducteur/vehicules'),
                              ),
                            ],
                          );
                        }
                        return DropdownButtonFormField<int>(
                          initialValue: _selectedVehiculeId,
                          decoration: InputDecoration(
                            labelText: 'Sélectionner un véhicule',
                            labelStyle: KTextStyles.caption,
                            prefixIcon: const Icon(
                              Icons.directions_car_outlined,
                              color: KColors.baseContentMid,
                              size: 18,
                            ),
                            filled: true,
                            fillColor: KColors.base200,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: KColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: KColors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: KColors.primary,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          style: KTextStyles.bodySm.copyWith(
                            color: KColors.baseContent,
                          ),
                          items: actifs
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v.id,
                                  child: Text(
                                    v.displayName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (id) {
                            setState(() {
                              _selectedVehiculeId = id;
                              final v = actifs.firstWhere((v) => v.id == id);
                              _typeVehicule = v.typeVehicule;
                              _placesCtrl.text = (v.placesMax - 1).toString();
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: KSpacing.md),
                    KTextField(
                      controller: _placesCtrl,
                      label: 'Places disponibles',
                      hint: '3',
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(
                        Icons.people_outline,
                        color: KColors.baseContentMid,
                        size: 18,
                      ),
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

            // ── Résumé tarifaire ───────────────────────────────────────
            if (_showTarif) ...[
              KCard(
                child: Padding(
                  padding: const EdgeInsets.all(KSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel(
                        icon: Icons.payments_outlined,
                        label: 'Résumé tarifaire',
                      ),
                      const SizedBox(height: KSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(KSpacing.md),
                        decoration: BoxDecoration(
                          color: KColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: KColors.primary.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          children: [
                            _TarifRow(
                              label: 'Coût total du trajet',
                              value: '${_coutTotal.toStringAsFixed(0)} FCFA',
                            ),
                            const Divider(color: KColors.border, height: 16),
                            _TarifRow(
                              label: 'Prix par place',
                              value: '${_prixParPlace.toStringAsFixed(0)} FCFA',
                              isBold: true,
                              color: KColors.primary,
                            ),
                          ],
                        ),
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

            // ── Bouton publier ─────────────────────────────────────────
            KButton(
              label: 'Publier le trajet',
              icon: Icons.publish_rounded,
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _submit,
            ),
            const SizedBox(height: KSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

// ── Widgets locaux ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: KColors.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: KTextStyles.bodySm.copyWith(
            fontWeight: FontWeight.w700,
            color: KColors.baseContent,
          ),
        ),
      ],
    );
  }
}

class _TarifRow extends StatelessWidget {
  final String label, value;
  final bool isBold;
  final Color? color;
  const _TarifRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: KTextStyles.caption),
        Text(
          value,
          style: KTextStyles.bodySm.copyWith(
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: color ?? KColors.baseContent,
            fontSize: isBold ? 16 : null,
          ),
        ),
      ],
    );
  }
}
