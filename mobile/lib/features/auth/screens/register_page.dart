import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_text_field.dart';
import '../../../core/widgets/k_alert.dart';
import '../../../core/widgets/k_section_header.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  int _step = 1;
  String _role = 'passager';
  String? _error;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _password2Ctrl = TextEditingController();
  final _permisCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  final _marqueCtrl = TextEditingController();
  final _modeleCtrl = TextEditingController();
  final _couleurCtrl = TextEditingController();
  final _plaqueCtrl = TextEditingController();
  String _typeVehicule = '';

  static const _types = [
    {'value': 'moto', 'label': 'Moto', 'places': '1', 'tarif': '30 FCFA/km'},
    {
      'value': 'voiture',
      'label': 'Voiture',
      'places': '5',
      'tarif': '65 FCFA/km',
    },
    {
      'value': 'minibus',
      'label': 'Minibus',
      'places': '15',
      'tarif': '120 FCFA/km',
    },
    {
      'value': 'camion',
      'label': 'Camion',
      'places': '3',
      'tarif': '200 FCFA/km',
    },
  ];

  @override
  void dispose() {
    for (final c in [
      _firstNameCtrl,
      _lastNameCtrl,
      _usernameCtrl,
      _emailCtrl,
      _phoneCtrl,
      _passwordCtrl,
      _password2Ctrl,
      _permisCtrl,
      _expCtrl,
      _marqueCtrl,
      _modeleCtrl,
      _couleurCtrl,
      _plaqueCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordCtrl.text != _password2Ctrl.text) {
      setState(() => _error = 'Les mots de passe ne correspondent pas.');
      return;
    }
    setState(() {
      _error = null;
      _step = 2;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);

    final data = <String, dynamic>{
      'username': _usernameCtrl.text.trim(),
      'first_name': _firstNameCtrl.text.trim(),
      'last_name': _lastNameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'password': _passwordCtrl.text,
      'password2': _password2Ctrl.text,
      'role': _role,
      if (_phoneCtrl.text.isNotEmpty)
        'numero_telephone': _phoneCtrl.text.trim(),
      if (_role == 'conducteur') ...{
        'numero_permis': _permisCtrl.text.trim(),
        'experience_annees': int.tryParse(_expCtrl.text.trim()) ?? 0,
        'type_vehicule': _typeVehicule,
        'marque': _marqueCtrl.text.trim(),
        'modele': _modeleCtrl.text.trim(),
        'couleur': _couleurCtrl.text.trim(),
        'plaque': _plaqueCtrl.text.trim(),
      },
    };

    final success = await ref.read(authProvider.notifier).inscription(data);
    if (!mounted) return;

    if (success) {
      context.go(_role == 'conducteur' ? '/conducteur' : '/passager');
    } else {
      setState(() {
        _error =
            ref.read(authProvider).error ?? "Erreur lors de l'inscription.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: KColors.baseContent),
          onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
        ),
        shape: const Border(bottom: BorderSide(color: KColors.border)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: KSpacing.pagePaddingH,
            vertical: KSpacing.xl,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: KSpacing.md),

                Image.asset('assets/logos/logo1.png', width: 72, height: 72),
                const SizedBox(height: KSpacing.md),
                Text('Créer un compte', style: KTextStyles.h1),
                const SizedBox(height: 4),
                Text('Rejoignez KoVoit au Togo', style: KTextStyles.caption),
                const SizedBox(height: KSpacing.xl),

                _StepIndicator(currentStep: _step),
                const SizedBox(height: KSpacing.xl),

                Container(
                  decoration: BoxDecoration(
                    color: KColors.base100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: KColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: KColors.neutral.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(KSpacing.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null) ...[
                        KAlert(message: _error!, type: KAlertType.error),
                        const SizedBox(height: KSpacing.lg),
                      ],
                      if (_step == 1) ..._buildStep1(),
                      if (_step == 2) ..._buildStep2(isLoading),
                    ],
                  ),
                ),

                const SizedBox(height: KSpacing.xl),
                const KDividerText(text: 'ou'),
                const SizedBox(height: KSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Déjà un compte ? ', style: KTextStyles.caption),
                    GestureDetector(
                      onTap: () => context.push('/login'),
                      child: Text(
                        'Se connecter',
                        style: KTextStyles.caption.copyWith(
                          color: KColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStep1() => [
    Text(
      'Je suis',
      style: KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 8),
    Row(
      children: [
        Expanded(
          child: _RoleButton(
            label: 'Passager',
            selected: _role == 'passager',
            onTap: () => setState(() => _role = 'passager'),
          ),
        ),
        const SizedBox(width: KSpacing.md),
        Expanded(
          child: _RoleButton(
            label: 'Conducteur',
            selected: _role == 'conducteur',
            onTap: () => setState(() => _role = 'conducteur'),
          ),
        ),
      ],
    ),
    const SizedBox(height: KSpacing.lg),

    Row(
      children: [
        Expanded(
          child: KTextField(
            controller: _firstNameCtrl,
            label: 'Prénom',
            hint: 'Jean',
            textInputAction: TextInputAction.next,
            validator: (v) => v?.isEmpty == true ? 'Requis' : null,
          ),
        ),
        const SizedBox(width: KSpacing.md),
        Expanded(
          child: KTextField(
            controller: _lastNameCtrl,
            label: 'Nom',
            hint: 'Dupont',
            textInputAction: TextInputAction.next,
            validator: (v) => v?.isEmpty == true ? 'Requis' : null,
          ),
        ),
      ],
    ),
    const SizedBox(height: KSpacing.lg),

    KTextField(
      controller: _usernameCtrl,
      label: "Nom d'utilisateur",
      hint: 'jean_dupont',
      textInputAction: TextInputAction.next,
      validator: (v) => v?.isEmpty == true ? 'Requis' : null,
    ),
    const SizedBox(height: KSpacing.lg),

    KTextField(
      controller: _emailCtrl,
      label: 'Email',
      hint: 'exemple@email.com',
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      validator: (v) {
        if (v?.isEmpty == true) return 'Requis';
        if (!v!.contains('@')) return 'Email invalide';
        return null;
      },
    ),
    const SizedBox(height: KSpacing.lg),

    KTextField(
      controller: _phoneCtrl,
      label: 'Téléphone (optionnel)',
      hint: '+228 90 00 00 00',
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
    ),
    const SizedBox(height: KSpacing.lg),

    Row(
      children: [
        Expanded(
          child: KTextField(
            controller: _passwordCtrl,
            label: 'Mot de passe',
            hint: '••••••••',
            obscureText: true,
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Requis';
              if (v.length < 8) return 'Min. 8 caractères';
              return null;
            },
          ),
        ),
        const SizedBox(width: KSpacing.md),
        Expanded(
          child: KTextField(
            controller: _password2Ctrl,
            label: 'Confirmer',
            hint: '••••••••',
            obscureText: true,
            textInputAction: TextInputAction.done,
            validator: (v) => v?.isEmpty == true ? 'Requis' : null,
          ),
        ),
      ],
    ),
    const SizedBox(height: KSpacing.xl),

    KButton(label: 'Continuer →', onPressed: _nextStep),
  ];

  List<Widget> _buildStep2(bool isLoading) {
    if (_role == 'passager') {
      return [
        Container(
          padding: const EdgeInsets.all(KSpacing.xl),
          decoration: BoxDecoration(
            color: KColors.base200,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                'Profil Passager',
                style: KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Votre compte est prêt. Vous pourrez rechercher et réserver des trajets immédiatement.',
                textAlign: TextAlign.center,
                style: KTextStyles.caption,
              ),
            ],
          ),
        ),
        const SizedBox(height: KSpacing.lg),

        Container(
          decoration: BoxDecoration(
            border: Border.all(color: KColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (final item in [
                {'label': 'Prénom', 'value': _firstNameCtrl.text},
                {'label': 'Nom', 'value': _lastNameCtrl.text},
                {'label': 'Email', 'value': _emailCtrl.text},
                {'label': 'Rôle', 'value': 'Passager'},
              ])
                _RecapRow(label: item['label']!, value: item['value']!),
            ],
          ),
        ),
        const SizedBox(height: KSpacing.xl),
        _buildNavButtons(isLoading),
      ];
    }

    return [
      Container(
        padding: const EdgeInsets.all(KSpacing.lg),
        decoration: BoxDecoration(
          border: Border.all(color: KColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('INFORMATIONS CONDUCTEUR', style: KTextStyles.label),
            const SizedBox(height: KSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: KTextField(
                    controller: _permisCtrl,
                    label: 'Numéro de permis',
                    hint: 'TG-123456',
                    validator: (v) => v?.isEmpty == true ? 'Requis' : null,
                  ),
                ),
                const SizedBox(width: KSpacing.md),
                Expanded(
                  child: KTextField(
                    controller: _expCtrl,
                    label: 'Expérience (ans)',
                    hint: '0',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: KSpacing.lg),

      Container(
        padding: const EdgeInsets.all(KSpacing.lg),
        decoration: BoxDecoration(
          border: Border.all(color: KColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('VOTRE VÉHICULE', style: KTextStyles.label),
            const SizedBox(height: KSpacing.lg),
            Text(
              'Type de véhicule',
              style: KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: KSpacing.sm,
              runSpacing: KSpacing.sm,
              children: _types
                  .map(
                    (t) => _VehiculeTypeButton(
                      label: t['label']!,
                      sublabel: '${t['places']} pl. · ${t['tarif']}',
                      selected: _typeVehicule == t['value'],
                      onTap: () => setState(() => _typeVehicule = t['value']!),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: KSpacing.lg),

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
                const SizedBox(width: KSpacing.md),
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
            const SizedBox(height: KSpacing.lg),

            Row(
              children: [
                Expanded(
                  child: KTextField(
                    controller: _couleurCtrl,
                    label: 'Couleur',
                    hint: 'Blanc',
                    validator: (v) => v?.isEmpty == true ? 'Requis' : null,
                  ),
                ),
                const SizedBox(width: KSpacing.md),
                Expanded(
                  child: KTextField(
                    controller: _plaqueCtrl,
                    label: 'Plaque',
                    hint: 'TG 1234 LM',
                    validator: (v) => v?.isEmpty == true ? 'Requis' : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: KSpacing.xl),
      _buildNavButtons(isLoading),
    ];
  }

  Widget _buildNavButtons(bool isLoading) => Row(
    children: [
      Expanded(
        child: KButton(
          label: 'Retour',
          variant: KButtonVariant.outline,
          onPressed: () => setState(() {
            _step = 1;
            _error = null;
          }),
        ),
      ),
      const SizedBox(width: KSpacing.md),
      Expanded(
        child: KButton(
          label: 'Créer mon compte',
          isLoading: isLoading,
          onPressed: (_role == 'conducteur' && _typeVehicule.isEmpty)
              ? null
              : _submit,
        ),
      ),
    ],
  );
}

// ── Widgets locaux ─────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _Step(n: 1, label: 'Informations', active: currentStep >= 1),
      Expanded(
        child: Container(
          height: 2,
          color: currentStep >= 2 ? KColors.primary : KColors.base300,
        ),
      ),
      _Step(n: 2, label: 'Profil', active: currentStep >= 2),
    ],
  );
}

class _Step extends StatelessWidget {
  final int n;
  final String label;
  final bool active;
  const _Step({required this.n, required this.label, required this.active});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? KColors.primary : KColors.base300,
        ),
        child: Center(
          child: Text(
            '$n',
            style: TextStyle(
              color: active ? KColors.white : KColors.baseContentMid,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: active ? KColors.primary : KColors.baseContentMid,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ],
  );
}

class _RoleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RoleButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 44,
      decoration: BoxDecoration(
        color: selected ? KColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: selected ? KColors.primary : KColors.border,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: selected ? KColors.white : KColors.baseContent,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    ),
  );
}

class _VehiculeTypeButton extends StatelessWidget {
  final String label, sublabel;
  final bool selected;
  final VoidCallback onTap;
  const _VehiculeTypeButton({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? KColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? KColors.primary : KColors.border,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: selected ? KColors.white : KColors.baseContent,
            ),
          ),
          Text(
            sublabel,
            style: TextStyle(
              fontSize: 10,
              color: selected
                  ? KColors.white.withValues(alpha: 0.8)
                  : KColors.baseContentMid,
            ),
          ),
        ],
      ),
    ),
  );
}

class _RecapRow extends StatelessWidget {
  final String label, value;
  const _RecapRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: KColors.border)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              color: KColors.baseContentLow,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: KColors.baseContent,
          ),
        ),
      ],
    ),
  );
}
