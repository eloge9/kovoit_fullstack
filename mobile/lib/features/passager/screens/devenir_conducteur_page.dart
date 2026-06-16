import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';

const _vehiculeTypes = [
  {'value': 'voiture', 'label': 'Voiture', 'places': '4 places'},
  {'value': 'moto', 'label': 'Moto', 'places': '1 place'},
  {'value': 'minibus', 'label': 'Minibus', 'places': '12 places'},
  {'value': 'camion', 'label': 'Camion', 'places': '3 places'},
];

class DevenirConducteurPage extends ConsumerStatefulWidget {
  const DevenirConducteurPage({super.key});

  @override
  ConsumerState<DevenirConducteurPage> createState() =>
      _DevenirConducteurPageState();
}

class _DevenirConducteurPageState extends ConsumerState<DevenirConducteurPage> {
  int _step = 1;
  bool _loading = false;
  String? _error;

  // Step 1
  final _permisCtrl = TextEditingController();
  int _experience = 0;

  // Step 2
  String _typeVehicule = 'voiture';
  final _marqueCtrl = TextEditingController();
  final _modeleCtrl = TextEditingController();
  final _couleurCtrl = TextEditingController();
  final _plaqueCtrl = TextEditingController();

  @override
  void dispose() {
    _permisCtrl.dispose();
    _marqueCtrl.dispose();
    _modeleCtrl.dispose();
    _couleurCtrl.dispose();
    _plaqueCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    setState(() => _error = null);
    if (_step == 1 && _permisCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Le numéro de permis est requis.');
      return;
    }
    setState(() => _step++);
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final marque = _marqueCtrl.text.trim();
    final modele = _modeleCtrl.text.trim();
    final couleur = _couleurCtrl.text.trim();
    final plaque = _plaqueCtrl.text.trim().toUpperCase();

    if ([marque, modele, couleur, plaque].any((v) => v.isEmpty)) {
      setState(() => _error = 'Tous les champs du véhicule sont requis.');
      return;
    }

    setState(() => _loading = true);
    try {
      await DioClient.post(
        ApiConstants.basculerRole,
        data: {
          'numero_permis': _permisCtrl.text.trim(),
          'experience_annees': _experience,
          'type_vehicule': _typeVehicule,
          'marque': marque,
          'modele': modele,
          'couleur': couleur,
          'plaque': plaque,
        },
      );
      setState(() => _step = 3);
    } catch (e) {
      setState(
        () => _error = 'Une erreur est survenue. Vérifiez vos informations.',
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: KColors.baseContent),
          onPressed: () =>
              _step > 1 && _step < 3 ? setState(() => _step--) : context.pop(),
        ),
        title: Text(
          'Devenir conducteur',
          style: KTextStyles.bodySm.copyWith(
            fontWeight: FontWeight.w700,
            color: KColors.baseContent,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(KSpacing.pagePaddingH),
        children: [
          const SizedBox(height: KSpacing.lg),

          // ── Stepper ─────────────────────────────────────────────────────
          KCard(
            child: Padding(
              padding: const EdgeInsets.all(KSpacing.lg),
              child: Row(
                children: [
                  _StepIndicator(current: _step, total: 3),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Étape ${_step.clamp(1, 3)} sur 3',
                        style: KTextStyles.meta,
                      ),
                      Text(
                        [
                          'Votre permis',
                          'Votre véhicule',
                          'Documents',
                        ][_step.clamp(1, 3) - 1],
                        style: KTextStyles.bodySm.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: KSpacing.xl),

          // ── Erreur ──────────────────────────────────────────────────────
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(KSpacing.md),
              decoration: BoxDecoration(
                color: KColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: KColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: KColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: KTextStyles.bodySm.copyWith(color: KColors.error),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KSpacing.lg),
          ],

          // ── Step 1 : Permis ─────────────────────────────────────────────
          if (_step == 1)
            _Step1(
              permisCtrl: _permisCtrl,
              experience: _experience,
              onExperienceChanged: (v) => setState(() => _experience = v),
              onNext: _nextStep,
            ),

          // ── Step 2 : Véhicule ───────────────────────────────────────────
          if (_step == 2)
            _Step2(
              typeVehicule: _typeVehicule,
              onTypeChanged: (v) => setState(() => _typeVehicule = v),
              marqueCtrl: _marqueCtrl,
              modeleCtrl: _modeleCtrl,
              couleurCtrl: _couleurCtrl,
              plaqueCtrl: _plaqueCtrl,
              loading: _loading,
              onBack: () => setState(() => _step = 1),
              onSubmit: _submit,
            ),

          // ── Step 3 : Confirmation ───────────────────────────────────────
          if (_step == 3)
            _StepConfirmation(
              onGoToDocuments: () => context.go('/conducteur/documents'),
            ),

          const SizedBox(height: KSpacing.xxl),
        ],
      ),
    );
  }
}

// ── Widget: Indicateur d'étapes ───────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current, total;
  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= total; i++) ...[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: i < current
                  ? KColors.success
                  : i == current
                  ? KColors.primary
                  : KColors.base200,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: i < current
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : Text(
                      '$i',
                      style: KTextStyles.caption.copyWith(
                        color: i == current
                            ? Colors.white
                            : KColors.baseContentMid,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          if (i < total)
            Container(
              width: 24,
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              color: i < current ? KColors.success : KColors.base200,
            ),
        ],
      ],
    );
  }
}

// ── Étape 1 ───────────────────────────────────────────────────────────────────

class _Step1 extends StatelessWidget {
  final TextEditingController permisCtrl;
  final int experience;
  final ValueChanged<int> onExperienceChanged;
  final VoidCallback onNext;
  const _Step1({
    required this.permisCtrl,
    required this.experience,
    required this.onExperienceChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informations du permis',
              style: KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Ces informations seront vérifiées lors de l\'analyse de vos documents.',
              style: KTextStyles.caption,
            ),
            const SizedBox(height: KSpacing.xl),

            // Numéro de permis
            Text('Numéro du permis *', style: KTextStyles.label),
            const SizedBox(height: 6),
            TextField(
              controller: permisCtrl,
              decoration: InputDecoration(
                hintText: 'Ex : TG-123456-2020',
                hintStyle: KTextStyles.bodySm.copyWith(
                  color: KColors.baseContentMid,
                ),
                filled: true,
                fillColor: KColors.base200,
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
            ),
            const SizedBox(height: KSpacing.lg),

            // Expérience
            Text('Années d\'expérience', style: KTextStyles.label),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              initialValue: experience,
              decoration: InputDecoration(
                filled: true,
                fillColor: KColors.base200,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: KColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: KColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              items: [
                const DropdownMenuItem(value: 0, child: Text('Moins d\'1 an')),
                ...List.generate(
                  10,
                  (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text('${i + 1} an${i > 0 ? 's' : ''}'),
                  ),
                ),
                const DropdownMenuItem(
                  value: 15,
                  child: Text('Plus de 10 ans'),
                ),
              ],
              onChanged: (v) => onExperienceChanged(v ?? 0),
            ),
            const SizedBox(height: KSpacing.xl),

            // Info compte unique
            Container(
              padding: const EdgeInsets.all(KSpacing.md),
              decoration: BoxDecoration(
                color: KColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: KColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: KColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: KColors.primary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: KSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Compte unique',
                          style: KTextStyles.bodySm.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Votre compte restera le même. Vous pourrez basculer entre passager et conducteur en 1 clic.',
                          style: KTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KSpacing.xl),

            KButton(label: 'Continuer', onPressed: onNext),
          ],
        ),
      ),
    );
  }
}

// ── Étape 2 ───────────────────────────────────────────────────────────────────

class _Step2 extends StatelessWidget {
  final String typeVehicule;
  final ValueChanged<String> onTypeChanged;
  final TextEditingController marqueCtrl, modeleCtrl, couleurCtrl, plaqueCtrl;
  final bool loading;
  final VoidCallback onBack, onSubmit;

  const _Step2({
    required this.typeVehicule,
    required this.onTypeChanged,
    required this.marqueCtrl,
    required this.modeleCtrl,
    required this.couleurCtrl,
    required this.plaqueCtrl,
    required this.loading,
    required this.onBack,
    required this.onSubmit,
  });

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint, {
    bool upperCase = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: KTextStyles.label),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          textCapitalization: upperCase
              ? TextCapitalization.characters
              : TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: KTextStyles.bodySm.copyWith(
              color: KColors.baseContentMid,
            ),
            filled: true,
            fillColor: KColors.base200,
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
              borderSide: const BorderSide(color: KColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Votre véhicule',
              style: KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Informations sur le véhicule que vous utiliserez pour les trajets.',
              style: KTextStyles.caption,
            ),
            const SizedBox(height: KSpacing.xl),

            // Type véhicule
            Text('Type de véhicule *', style: KTextStyles.label),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.5,
              children: _vehiculeTypes.map((opt) {
                final selected = opt['value'] == typeVehicule;
                return GestureDetector(
                  onTap: () => onTypeChanged(opt['value']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: selected
                          ? KColors.primary.withValues(alpha: 0.1)
                          : KColors.base200,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? KColors.primary : KColors.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            opt['label']!,
                            style: KTextStyles.bodySm.copyWith(
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? KColors.primary
                                  : KColors.baseContent,
                            ),
                          ),
                          Text(opt['places']!, style: KTextStyles.meta),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: KSpacing.lg),

            Row(
              children: [
                Expanded(child: _field(marqueCtrl, 'Marque *', 'Toyota')),
                const SizedBox(width: KSpacing.md),
                Expanded(child: _field(modeleCtrl, 'Modèle *', 'Corolla')),
              ],
            ),
            const SizedBox(height: KSpacing.lg),
            Row(
              children: [
                Expanded(child: _field(couleurCtrl, 'Couleur *', 'Blanc')),
                const SizedBox(width: KSpacing.md),
                Expanded(
                  child: _field(
                    plaqueCtrl,
                    'Plaque *',
                    'AB-1234-TG',
                    upperCase: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KSpacing.xl),

            Row(
              children: [
                Expanded(
                  child: KButton(
                    label: 'Retour',
                    variant: KButtonVariant.outline,
                    onPressed: onBack,
                  ),
                ),
                const SizedBox(width: KSpacing.md),
                Expanded(
                  child: KButton(
                    label: 'Créer mon profil',
                    isLoading: loading,
                    onPressed: loading ? null : onSubmit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Étape 3 : Confirmation ────────────────────────────────────────────────────

class _StepConfirmation extends StatelessWidget {
  final VoidCallback onGoToDocuments;
  const _StepConfirmation({required this.onGoToDocuments});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KColors.base100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: KColors.success.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(KSpacing.xxl),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: KColors.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: KColors.success,
              size: 36,
            ),
          ),
          const SizedBox(height: KSpacing.lg),
          Text(
            'Profil conducteur créé !',
            style: KTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Votre profil et votre véhicule ont été enregistrés. Il reste une dernière étape : déposer vos documents pour que notre équipe puisse les vérifier.',
            textAlign: TextAlign.center,
            style: KTextStyles.bodySm.copyWith(color: KColors.baseContentMid),
          ),
          const SizedBox(height: KSpacing.xl),

          // Étapes restantes
          ...[
            _ProgressItem(
              num: 1,
              done: true,
              label: 'Profil et véhicule enregistrés',
            ),
            _ProgressItem(
              num: 2,
              done: false,
              label: 'Déposer vos documents obligatoires',
            ),
            _ProgressItem(
              num: 3,
              done: false,
              label: 'Vérification automatique par IA',
            ),
            _ProgressItem(
              num: 4,
              done: false,
              label: 'Validation par notre équipe',
            ),
          ],
          const SizedBox(height: KSpacing.xl),

          KButton(
            label: 'Déposer mes documents',
            icon: Icons.upload_file_rounded,
            onPressed: onGoToDocuments,
          ),
        ],
      ),
    );
  }
}

class _ProgressItem extends StatelessWidget {
  final int num;
  final bool done;
  final String label;
  const _ProgressItem({
    required this.num,
    required this.done,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.md),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: done ? KColors.success : KColors.base200,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: done
                  ? const Icon(Icons.check, color: Colors.white, size: 12)
                  : Text(
                      '$num',
                      style: KTextStyles.meta.copyWith(
                        fontWeight: FontWeight.w700,
                        color: KColors.baseContentMid,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: KSpacing.md),
          Text(
            label,
            style: KTextStyles.bodySm.copyWith(
              color: done ? KColors.success : KColors.baseContentMid,
              fontWeight: done ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
