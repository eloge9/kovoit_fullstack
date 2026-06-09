import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _permisCtrl = TextEditingController();
  final _marqueCtrl = TextEditingController();
  final _modeleCtrl = TextEditingController();
  final _plaqueCtrl = TextEditingController();

  String _role = 'passager';
  String _typeVehicule = 'voiture';
  bool _obscurePassword = true;
  int _currentStep = 0;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _permisCtrl.dispose();
    _marqueCtrl.dispose();
    _modeleCtrl.dispose();
    _plaqueCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final data = <String, dynamic>{
      'username': _usernameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'password': _passwordCtrl.text,
      'role': _role,
      if (_phoneCtrl.text.isNotEmpty) 'numero_telephone': _phoneCtrl.text.trim(),
    };

    if (_role == 'conducteur') {
      data['numero_permis'] = _permisCtrl.text.trim();
      data['type_vehicule'] = _typeVehicule;
      data['marque'] = _marqueCtrl.text.trim();
      data['modele'] = _modeleCtrl.text.trim();
      data['plaque'] = _plaqueCtrl.text.trim();
    }

    final success = await ref.read(authProvider.notifier).inscription(data);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compte créé ! Connectez-vous maintenant.'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/login');
    } else {
      final error = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Erreur lors de l\'inscription'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un compte'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < (_role == 'conducteur' ? 2 : 1)) {
              setState(() => _currentStep++);
            } else {
              _submit();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) setState(() => _currentStep--);
          },
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: isLoading ? null : details.onStepContinue,
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _currentStep == (_role == 'conducteur' ? 2 : 1)
                                ? 'Créer le compte'
                                : 'Suivant',
                          ),
                  ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('Précédent'),
                    ),
                  ],
                ],
              ),
            );
          },
          steps: [
            // Étape 1: Informations de base
            Step(
              title: const Text('Informations personnelles'),
              content: Column(
                children: [
                  // Choix du rôle
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _RoleButton(
                            label: 'Passager',
                            icon: Icons.person,
                            isSelected: _role == 'passager',
                            onTap: () => setState(() => _role = 'passager'),
                          ),
                        ),
                        Expanded(
                          child: _RoleButton(
                            label: 'Conducteur',
                            icon: Icons.drive_eta,
                            isSelected: _role == 'conducteur',
                            onTap: () => setState(() => _role = 'conducteur'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _usernameCtrl,
                    label: 'Nom d\'utilisateur',
                    hint: 'JohnDoe',
                    prefixIcon: const Icon(Icons.person_outline),
                    validator: (v) => v?.isEmpty == true ? 'Champ requis' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _emailCtrl,
                    label: 'Email',
                    hint: 'exemple@email.com',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined),
                    validator: (v) {
                      if (v?.isEmpty == true) return 'Email requis';
                      if (!v!.contains('@')) return 'Email invalide';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _passwordCtrl,
                    label: 'Mot de passe',
                    hint: '••••••••',
                    obscureText: _obscurePassword,
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (v) {
                      if (v?.isEmpty == true) return 'Mot de passe requis';
                      if (v!.length < 8) return 'Au moins 8 caractères';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _phoneCtrl,
                    label: 'Téléphone (optionnel)',
                    hint: '+228 XX XX XX XX',
                    keyboardType: TextInputType.phone,
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                ],
              ),
              isActive: _currentStep >= 0,
            ),

            // Étape 2: Conducteur - Permis
            if (_role == 'conducteur')
              Step(
                title: const Text('Informations conducteur'),
                content: Column(
                  children: [
                    AppTextField(
                      controller: _permisCtrl,
                      label: 'Numéro de permis',
                      hint: 'TG-XXXX-XXXX',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      validator: (v) => v?.isEmpty == true ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _typeVehicule,
                      decoration: InputDecoration(
                        labelText: 'Type de véhicule',
                        prefixIcon: const Icon(Icons.directions_car_outlined),
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
                      onChanged: (v) => setState(() => _typeVehicule = v!),
                    ),
                  ],
                ),
                isActive: _currentStep >= 1,
              ),

            // Étape 3: Véhicule
            if (_role == 'conducteur')
              Step(
                title: const Text('Votre véhicule'),
                content: Column(
                  children: [
                    AppTextField(
                      controller: _marqueCtrl,
                      label: 'Marque',
                      hint: 'Toyota',
                      prefixIcon: const Icon(Icons.directions_car_outlined),
                      validator: (v) => v?.isEmpty == true ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _modeleCtrl,
                      label: 'Modèle',
                      hint: 'Corolla',
                      prefixIcon: const Icon(Icons.car_repair),
                      validator: (v) => v?.isEmpty == true ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _plaqueCtrl,
                      label: 'Plaque d\'immatriculation',
                      hint: 'TG-XXXX-XX',
                      prefixIcon: const Icon(Icons.confirmation_number_outlined),
                      validator: (v) => v?.isEmpty == true ? 'Champ requis' : null,
                    ),
                  ],
                ),
                isActive: _currentStep >= 2,
              ),

            // Étape finale passager
            if (_role == 'passager')
              Step(
                title: const Text('Confirmation'),
                content: Column(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tout est prêt !',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Votre compte passager sera créé.\nVous pourrez rechercher et réserver des trajets.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
                isActive: _currentStep >= 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
