import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../trajets/providers/trajet_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_text_field.dart';

class VehiculesPage extends ConsumerWidget {
  const VehiculesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiculesState = ref.watch(vehiculesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes véhicules')),
      body: vehiculesState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (vehicules) {
          return vehicules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.directions_car_outlined,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Aucun véhicule enregistré',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showAddVehiculeDialog(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un véhicule'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: vehicules.length + 1,
                  itemBuilder: (context, i) {
                    if (i == vehicules.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton.icon(
                          onPressed: () => _showAddVehiculeDialog(context, ref),
                          icon: const Icon(Icons.add),
                          label: const Text('Ajouter un véhicule'),
                        ),
                      );
                    }
                    final v = vehicules[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: KColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _vehiculeIcon(v.typeVehicule),
                            color: KColors.primary,
                          ),
                        ),
                        title: Text(
                          v.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${Formatters.vehiculeLabel(v.typeVehicule)} • ${v.placesMax} places',
                            ),
                            Text(
                              v.actif ? 'Actif' : 'Inactif',
                              style: TextStyle(
                                color: v.actif ? KColors.success : Colors.grey,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        trailing: v.actif
                            ? PopupMenuButton<String>(
                                onSelected: (action) async {
                                  if (action == 'desactiver') {
                                    await ref
                                        .read(vehiculesProvider.notifier)
                                        .desactiver(v.id);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'desactiver',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.block,
                                          size: 16,
                                          color: KColors.error,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Désactiver',
                                          style: TextStyle(
                                            color: KColors.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    );
                  },
                );
        },
      ),
    );
  }

  IconData _vehiculeIcon(String type) {
    switch (type) {
      case 'moto':
        return Icons.two_wheeler;
      case 'minibus':
        return Icons.airport_shuttle;
      case 'camion':
        return Icons.local_shipping;
      default:
        return Icons.directions_car;
    }
  }

  void _showAddVehiculeDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AddVehiculeSheet(
        onSave: (data) async {
          final ok = await ref.read(vehiculesProvider.notifier).ajouter(data);
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  ok ? 'Véhicule ajouté !' : 'Erreur lors de l\'ajout',
                ),
                backgroundColor: ok ? KColors.success : KColors.error,
              ),
            );
          }
        },
      ),
    );
  }
}

class _AddVehiculeSheet extends StatefulWidget {
  final Future<void> Function(Map<String, dynamic>) onSave;
  const _AddVehiculeSheet({required this.onSave});

  @override
  State<_AddVehiculeSheet> createState() => _AddVehiculeSheetState();
}

class _AddVehiculeSheetState extends State<_AddVehiculeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _marqueCtrl = TextEditingController();
  final _modeleCtrl = TextEditingController();
  final _couleurCtrl = TextEditingController();
  final _plaqueCtrl = TextEditingController();
  String _type = 'voiture';
  int _places = 4;
  bool _isSaving = false;

  @override
  void dispose() {
    _marqueCtrl.dispose();
    _modeleCtrl.dispose();
    _couleurCtrl.dispose();
    _plaqueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Ajouter un véhicule',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'moto', child: Text('Moto')),
                DropdownMenuItem(value: 'voiture', child: Text('Voiture')),
                DropdownMenuItem(value: 'minibus', child: Text('Minibus')),
                DropdownMenuItem(value: 'camion', child: Text('Camion')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: KTextField(
                    controller: _marqueCtrl,
                    label: 'Marque',
                    hint: 'Toyota',
                    validator: (v) => v?.isEmpty == true ? 'Requis' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KTextField(
                    controller: _modeleCtrl,
                    label: 'Modèle',
                    hint: 'Corolla',
                    validator: (v) => v?.isEmpty == true ? 'Requis' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: KTextField(
                    controller: _couleurCtrl,
                    label: 'Couleur',
                    hint: 'Blanc',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KTextField(
                    controller: _plaqueCtrl,
                    label: 'Plaque',
                    hint: 'TG-XXXX-XX',
                    validator: (v) => v?.isEmpty == true ? 'Requis' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Places max:'),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () =>
                      setState(() => _places = (_places - 1).clamp(1, 15)),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_places',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      setState(() => _places = (_places + 1).clamp(1, 15)),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 16),
            KButton(
              label: 'Enregistrer',
              isLoading: _isSaving,
              onPressed: _isSaving
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) return;
                      setState(() => _isSaving = true);
                      await widget.onSave({
                        'type_vehicule': _type,
                        'marque': _marqueCtrl.text.trim(),
                        'modele': _modeleCtrl.text.trim(),
                        'couleur': _couleurCtrl.text.trim(),
                        'plaque': _plaqueCtrl.text.trim(),
                        'places_max': _places,
                      });
                    },
            ),
          ],
        ),
      ),
    );
  }
}
