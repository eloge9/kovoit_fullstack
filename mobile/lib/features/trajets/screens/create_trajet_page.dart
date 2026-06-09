import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/trajet_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

class CreateTrajetPage extends ConsumerStatefulWidget {
  const CreateTrajetPage({super.key});

  @override
  ConsumerState<CreateTrajetPage> createState() => _CreateTrajetPageState();
}

class _CreateTrajetPageState extends ConsumerState<CreateTrajetPage> {
  final _formKey = GlobalKey<FormState>();
  final _departCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _departLatCtrl = TextEditingController();
  final _departLngCtrl = TextEditingController();
  final _destLatCtrl = TextEditingController();
  final _destLngCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController();
  final _placesCtrl = TextEditingController(text: '3');

  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 2));
  int? _selectedVehiculeId;
  bool _isLoading = false;
  String _typeVehicule = 'voiture';

  double get _coutTotal {
    final dist = double.tryParse(_distanceCtrl.text) ?? 0;
    final tarif = AppConstants.tarifCarburant[_typeVehicule] ?? 65;
    return dist * tarif;
  }

  double get _prixParPlace {
    final places = int.tryParse(_placesCtrl.text) ?? 1;
    if (places == 0) return _coutTotal;
    return _coutTotal / places;
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
    _departCtrl.dispose();
    _destinationCtrl.dispose();
    _departLatCtrl.dispose();
    _departLngCtrl.dispose();
    _destLatCtrl.dispose();
    _destLngCtrl.dispose();
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
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (time == null) return;

    setState(() {
      _selectedDate = DateTime(
        date.year, date.month, date.day, time.hour, time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehiculeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un véhicule'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      'vehicule': _selectedVehiculeId,
      'depart': _departCtrl.text.trim(),
      'destination': _destinationCtrl.text.trim(),
      if (_departLatCtrl.text.isNotEmpty)
        'depart_lat': double.parse(_departLatCtrl.text),
      if (_departLngCtrl.text.isNotEmpty)
        'depart_lng': double.parse(_departLngCtrl.text),
      if (_destLatCtrl.text.isNotEmpty)
        'destination_lat': double.parse(_destLatCtrl.text),
      if (_destLngCtrl.text.isNotEmpty)
        'destination_lng': double.parse(_destLngCtrl.text),
      'distance_km': double.parse(_distanceCtrl.text),
      'cout_total': _coutTotal,
      'prix_par_place': _prixParPlace,
      'date_heure_depart': _selectedDate.toIso8601String(),
      'places_disponibles': int.parse(_placesCtrl.text),
    };

    final ok = await ref.read(trajetsProvider.notifier).creerTrajet(data);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trajet créé avec succès !'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      context.pop();
    } else {
      final error = ref.read(trajetsProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Erreur lors de la création'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehiculesState = ref.watch(vehiculesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Créer un trajet')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Section Itinéraire
            _SectionTitle(title: 'Itinéraire', icon: Icons.route),
            const SizedBox(height: 12),
            AppTextField(
              controller: _departCtrl,
              label: 'Ville de départ',
              hint: 'Ex: Lomé, Quartier Adéwui',
              prefixIcon: const Icon(Icons.trip_origin, color: AppTheme.primaryColor),
              validator: (v) => v?.isEmpty == true ? 'Champ requis' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _destinationCtrl,
              label: 'Destination',
              hint: 'Ex: Kpalimé, Marché central',
              prefixIcon: const Icon(Icons.location_on, color: AppTheme.errorColor),
              validator: (v) => v?.isEmpty == true ? 'Champ requis' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _distanceCtrl,
              label: 'Distance (km)',
              hint: '120',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              prefixIcon: const Icon(Icons.straighten),
              validator: (v) {
                if (v?.isEmpty == true) return 'Champ requis';
                if (double.tryParse(v!) == null) return 'Nombre invalide';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),

            // Section Date
            _SectionTitle(title: 'Date et heure', icon: Icons.schedule),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                title: const Text('Date de départ'),
                subtitle: Text(
                  '${_selectedDate.day.toString().padLeft(2, '0')}/'
                  '${_selectedDate.month.toString().padLeft(2, '0')}/'
                  '${_selectedDate.year} à '
                  '${_selectedDate.hour.toString().padLeft(2, '0')}:'
                  '${_selectedDate.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryColor,
                  ),
                ),
                trailing: const Icon(Icons.edit),
                onTap: _selectDate,
              ),
            ),
            const SizedBox(height: 20),

            // Section Véhicule
            _SectionTitle(title: 'Véhicule', icon: Icons.directions_car),
            const SizedBox(height: 12),
            vehiculesState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Erreur: $e'),
              data: (vehicules) {
                if (vehicules.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text('Aucun véhicule enregistré'),
                          TextButton(
                            onPressed: () => context.push('/conducteur/vehicules'),
                            child: const Text('Ajouter un véhicule'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return DropdownButtonFormField<int>(
                  value: _selectedVehiculeId,
                  decoration: InputDecoration(
                    labelText: 'Sélectionner un véhicule',
                    prefixIcon: const Icon(Icons.directions_car),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: vehicules
                      .where((v) => v.actif)
                      .map((v) => DropdownMenuItem(
                            value: v.id,
                            child: Text(v.displayName, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (id) {
                    setState(() {
                      _selectedVehiculeId = id;
                      final v = vehicules.firstWhere((v) => v.id == id);
                      _typeVehicule = v.typeVehicule;
                      _placesCtrl.text = (v.placesMax - 1).toString();
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _placesCtrl,
              label: 'Places disponibles',
              hint: '3',
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.people),
              validator: (v) {
                if (v?.isEmpty == true) return 'Champ requis';
                final n = int.tryParse(v!);
                if (n == null || n < 1) return 'Minimum 1 place';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),

            // Résumé tarifaire
            if (_distanceCtrl.text.isNotEmpty &&
                double.tryParse(_distanceCtrl.text) != null &&
                _selectedVehiculeId != null) ...[
              Card(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Résumé tarifaire',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      _TarifRow(
                        label: 'Coût total du trajet',
                        value: '${_coutTotal.toStringAsFixed(0)} FCFA',
                      ),
                      _TarifRow(
                        label: 'Prix par place',
                        value: '${_prixParPlace.toStringAsFixed(0)} FCFA',
                        isBold: true,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tarif carburant ${AppConstants.vehiculeLabel(_typeVehicule)} : '
                        '${AppConstants.tarifCarburant[_typeVehicule]} FCFA/km',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            AppButton(
              label: 'Publier le trajet',
              icon: Icons.publish,
              onPressed: _isLoading ? null : _submit,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TarifRow extends StatelessWidget {
  final String label;
  final String value;
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
              color: color,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}
