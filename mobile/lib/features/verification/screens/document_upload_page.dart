import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../providers/verification_provider.dart';
import '../models/verification_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../../trajets/providers/trajet_provider.dart';
import '../../trajets/models/vehicule_model.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_text_field.dart';

/// Taille minimale (octets) en dessous de laquelle une photo est considérée
/// trop dégradée pour être exploitable (capture ratée, fichier vide/corrompu).
/// La détection de netteté réelle est déléguée aux agents IA côté backend.
const _kMinPhotoBytes = 15 * 1024;

// ── Provider local pour la map docType → fichier sélectionné (aperçu) ─────────

final _selectedFilesProvider =
    StateProvider.autoDispose<Map<String, XFile>>((ref) => {});

/// Assistant de soumission des documents conducteur, étape par étape.
/// Chaque document est uploadé dès sa capture — rien n'est perdu si
/// l'utilisateur ferme l'app en cours de route (reprise automatique).
class DocumentUploadPage extends ConsumerWidget {
  const DocumentUploadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(verificationDocumentsProvider);
    final user = ref.watch(currentUserProvider);
    final vehiculesAsync = ref.watch(vehiculesProvider);

    return Scaffold(
      backgroundColor: KColors.base200,
      body: docsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: KColors.primary)),
        error: (e, _) => Center(
          child: Text('Erreur: $e', style: KTextStyles.bodySm.copyWith(color: KColors.error)),
        ),
        data: (existingDocs) => _WizardBody(
          existingDocs: existingDocs,
          user: user,
          vehicules: vehiculesAsync.valueOrNull ?? const [],
        ),
      ),
    );
  }
}

class _WizardBody extends ConsumerStatefulWidget {
  final List<DriverDocumentModel> existingDocs;
  final UserModel? user;
  final List<VehiculeModel> vehicules;

  const _WizardBody({
    required this.existingDocs,
    required this.user,
    required this.vehicules,
  });

  @override
  ConsumerState<_WizardBody> createState() => _WizardBodyState();
}

class _WizardBodyState extends ConsumerState<_WizardBody> {
  static const _totalSteps = 5; // Infos + 4 étapes documents

  late int _step; // 0 = infos, 1..4 = kDocSteps, 5 = récapitulatif
  final Map<String, bool> _uploading = {};
  final Map<String, String?> _errors = {};
  late Map<String, DriverDocumentModel?> _existingMap;

  @override
  void initState() {
    super.initState();
    _existingMap = {for (final d in widget.existingDocs) d.documentType: d};
    _step = _computeResumeStep();
  }

  bool _docStepComplete(DocStep s) => s.docTypes.every((t) {
        final d = _existingMap[t];
        return d != null && !d.isRejected;
      });

  int _computeResumeStep() {
    final u = widget.user;
    final infosOk = u != null &&
        (u.firstName?.isNotEmpty ?? false) &&
        (u.lastName?.isNotEmpty ?? false) &&
        (u.phoneNumber?.isNotEmpty ?? false) &&
        widget.vehicules.isNotEmpty;
    if (!infosOk) return 0;
    for (var i = 0; i < kDocSteps.length; i++) {
      if (!_docStepComplete(kDocSteps[i])) return i + 1;
    }
    return kDocSteps.length + 1;
  }

  void _goNext() => setState(() => _step = (_step + 1).clamp(0, kDocSteps.length + 1));
  void _goBack() {
    if (_step == 0) {
      context.pop();
    } else {
      setState(() => _step -= 1);
    }
  }

  // ── Upload d'un document ────────────────────────────────────────────────
  Future<void> _pickAndUpload(String docType) async {
    final source = await _showSourcePicker();
    if (source == null) return;

    final picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 88,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Impossible d'accéder à la caméra ou la galerie."),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    if (file == null) return;

    // Validation basique avant upload — fichier vide/trop petit = capture ratée.
    final size = await file.length();
    if (size < _kMinPhotoBytes) {
      if (!mounted) return;
      setState(() => _errors[docType] =
          'Photo illisible ou trop petite — reprenez la photo dans de bonnes conditions de lumière.');
      return;
    }

    ref.read(_selectedFilesProvider.notifier).update((map) {
      final copy = Map<String, XFile>.from(map);
      copy[docType] = file!;
      return copy;
    });

    setState(() {
      _uploading[docType] = true;
      _errors[docType] = null;
    });

    try {
      final repo = ref.read(verificationRepositoryProvider);
      final doc = await repo.uploadDocument(docType, file.path, file.name);
      if (!mounted) return;
      setState(() => _existingMap[docType] = doc);
      ref.invalidate(verificationDocumentsProvider);
      ref.invalidate(verificationStatusProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errors[docType] = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _uploading[docType] = false);
    }
  }

  Future<ImageSource?> _showSourcePicker() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: KColors.base300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text('Choisir la source',
                  style: KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: KColors.primary),
                title: const Text('Prendre une photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: KColors.primary),
                title: const Text('Choisir depuis la galerie'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Soumission finale + lancement automatique de l'analyse IA ───────────
  bool _submitting = false;

  Future<void> _submitAndAnalyze() async {
    setState(() => _submitting = true);
    try {
      final repo = ref.read(verificationRepositoryProvider);
      await repo.startVerification();
      if (!mounted) return;
      ref.invalidate(verificationStatusProvider);
      context.pushReplacement('/conducteur/verification-en-cours');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReview = _step > kDocSteps.length;
    final displayStep = (_step + 1).clamp(1, _totalSteps);
    final title = isReview
        ? 'Récapitulatif'
        : _step == 0
            ? 'Informations personnelles'
            : kDocSteps[_step - 1].title;

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        leading: IconButton(
          icon: Icon(_step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded,
              color: KColors.baseContent),
          onPressed: _goBack,
        ),
        title: Text(
          'Soumettre mes documents',
          style: KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w700, color: KColors.baseContent),
        ),
      ),
      body: Column(
        children: [
          // ── En-tête progression ──────────────────────────────────────────
          Container(
            color: KColors.base100,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isReview ? 'Étape finale' : 'Étape $displayStep/$_totalSteps',
                      style: KTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (isReview ? _totalSteps : displayStep) / _totalSteps,
                    minHeight: 5,
                    backgroundColor: KColors.base300,
                    valueColor: const AlwaysStoppedAnimation<Color>(KColors.primary),
                  ),
                ),
                const SizedBox(height: 10),
                Text(title, style: KTextStyles.h3),
              ],
            ),
          ),
          const Divider(color: KColors.border, height: 1),
          Expanded(child: _buildStepBody()),
        ],
      ),
    );
  }

  Widget _buildStepBody() {
    if (_step == 0) {
      return _InfosStep(
        user: widget.user,
        vehicules: widget.vehicules,
        onDone: _goNext,
      );
    }
    if (_step <= kDocSteps.length) {
      final docStep = kDocSteps[_step - 1];
      return _DocStepView(
        docStep: docStep,
        existingMap: _existingMap,
        uploading: _uploading,
        errors: _errors,
        selectedFiles: ref.watch(_selectedFilesProvider),
        onPick: _pickAndUpload,
        canContinue: _docStepComplete(docStep),
        onNext: _goNext,
      );
    }
    return _ReviewStep(
      existingMap: _existingMap,
      submitting: _submitting,
      onSubmit: _submitAndAnalyze,
    );
  }
}

// ── Étape 1 : informations personnelles ───────────────────────────────────────

class _InfosStep extends ConsumerStatefulWidget {
  final UserModel? user;
  final List<VehiculeModel> vehicules;
  final VoidCallback onDone;

  const _InfosStep({required this.user, required this.vehicules, required this.onDone});

  @override
  ConsumerState<_InfosStep> createState() => _InfosStepState();
}

class _InfosStepState extends ConsumerState<_InfosStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _phoneCtrl;

  // Formulaire véhicule (affiché seulement si aucun véhicule actif)
  final _marqueCtrl = TextEditingController();
  final _modeleCtrl = TextEditingController();
  final _plaqueCtrl = TextEditingController();
  String _typeVehicule = 'voiture';
  bool _saving = false;

  bool get _hasVehicule => widget.vehicules.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController(text: widget.user?.firstName);
    _lastNameCtrl  = TextEditingController(text: widget.user?.lastName);
    _phoneCtrl     = TextEditingController(text: widget.user?.phoneNumber);
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _marqueCtrl.dispose();
    _modeleCtrl.dispose();
    _plaqueCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final ok = await ref.read(authProvider.notifier).updateProfil({
        'first_name': _firstNameCtrl.text.trim(),
        'last_name':  _lastNameCtrl.text.trim(),
        'numero_telephone': _phoneCtrl.text.trim(),
      });
      if (!ok) throw Exception(ref.read(authProvider).error ?? 'Erreur de mise à jour du profil.');

      if (!_hasVehicule) {
        final vOk = await ref.read(vehiculesProvider.notifier).ajouter({
          'type_vehicule': _typeVehicule,
          'marque':  _marqueCtrl.text.trim(),
          'modele':  _modeleCtrl.text.trim(),
          'couleur': '',
          'plaque':  _plaqueCtrl.text.trim(),
          'places_max': _typeVehicule == 'moto' ? 1 : _typeVehicule == 'camion' ? 3 : _typeVehicule == 'minibus' ? 15 : 4,
        });
        if (!vOk) throw Exception("Erreur lors de l'enregistrement du véhicule.");
      }

      if (!mounted) return;
      widget.onDone();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: KColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(KSpacing.pagePaddingH),
              children: [
                KTextField(
                  controller: _firstNameCtrl,
                  label: 'Prénom',
                  prefixIcon: const Icon(Icons.person_outline),
                  validator: (v) => v?.trim().isEmpty == true ? 'Champ requis' : null,
                ),
                const SizedBox(height: 12),
                KTextField(
                  controller: _lastNameCtrl,
                  label: 'Nom',
                  prefixIcon: const Icon(Icons.person_outline),
                  validator: (v) => v?.trim().isEmpty == true ? 'Champ requis' : null,
                ),
                const SizedBox(height: 12),
                KTextField(
                  controller: _phoneCtrl,
                  label: 'Téléphone',
                  hint: '+228 XX XX XX XX',
                  keyboardType: TextInputType.phone,
                  prefixIcon: const Icon(Icons.phone_outlined),
                  validator: (v) => v?.trim().isEmpty == true ? 'Champ requis' : null,
                ),
                const SizedBox(height: 24),
                Text('Véhicule', style: KTextStyles.h3),
                const SizedBox(height: 12),
                if (_hasVehicule)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: KColors.base100,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: KColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_car_rounded, color: KColors.primary),
                        const SizedBox(width: 12),
                        Expanded(child: Text(widget.vehicules.first.displayName, style: KTextStyles.bodySm)),
                        TextButton(
                          onPressed: () => context.push('/conducteur/vehicules'),
                          child: const Text('Modifier'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: _typeVehicule,
                    decoration: InputDecoration(
                      labelText: 'Type de véhicule',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'moto', child: Text('Moto')),
                      DropdownMenuItem(value: 'voiture', child: Text('Voiture')),
                      DropdownMenuItem(value: 'minibus', child: Text('Minibus')),
                      DropdownMenuItem(value: 'camion', child: Text('Camion')),
                    ],
                    onChanged: (v) => setState(() => _typeVehicule = v!),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: KTextField(
                          controller: _marqueCtrl,
                          label: 'Marque',
                          hint: 'Toyota',
                          validator: (v) => v?.trim().isEmpty == true ? 'Requis' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: KTextField(
                          controller: _modeleCtrl,
                          label: 'Modèle',
                          hint: 'Corolla',
                          validator: (v) => v?.trim().isEmpty == true ? 'Requis' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  KTextField(
                    controller: _plaqueCtrl,
                    label: 'Plaque',
                    hint: 'TG-XXXX-XX',
                    validator: (v) => v?.trim().isEmpty == true ? 'Requis' : null,
                  ),
                ],
              ],
            ),
          ),
        ),
        _BottomBar(
          child: KButton(
            label: 'Suivant',
            isLoading: _saving,
            onPressed: _saving ? null : _submit,
          ),
        ),
      ],
    );
  }
}

// ── Étapes 2 à 5 : capture des documents ──────────────────────────────────────

class _DocStepView extends StatelessWidget {
  final DocStep docStep;
  final Map<String, DriverDocumentModel?> existingMap;
  final Map<String, bool> uploading;
  final Map<String, String?> errors;
  final Map<String, XFile> selectedFiles;
  final void Function(String) onPick;
  final bool canContinue;
  final VoidCallback onNext;

  const _DocStepView({
    required this.docStep,
    required this.existingMap,
    required this.uploading,
    required this.errors,
    required this.selectedFiles,
    required this.onPick,
    required this.canContinue,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(KSpacing.pagePaddingH),
            itemCount: docStep.docTypes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final type = docStep.docTypes[i];
              return _DocumentTile(
                type: type,
                existing: existingMap[type],
                previewFile: selectedFiles[type],
                isUploading: uploading[type] == true,
                error: errors[type],
                onPick: () => onPick(type),
              );
            },
          ),
        ),
        _BottomBar(
          child: KButton(
            label: 'Suivant',
            icon: Icons.arrow_forward_rounded,
            onPressed: canContinue ? onNext : null,
          ),
        ),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final String type;
  final DriverDocumentModel? existing;
  final XFile? previewFile;
  final bool isUploading;
  final String? error;
  final VoidCallback onPick;

  const _DocumentTile({
    required this.type,
    this.existing,
    this.previewFile,
    required this.isUploading,
    this.error,
    required this.onPick,
  });

  bool get hasDoc => existing != null && !existing!.isRejected;

  @override
  Widget build(BuildContext context) {
    final label = kDocTypeLabels[type] ?? type;
    final rejected = existing?.isRejected == true;

    return Container(
      decoration: BoxDecoration(
        color: KColors.base100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: error != null || rejected
              ? const Color(0xFFFCA5A5)
              : hasDoc
                  ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                  : KColors.border,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (hasDoc ? const Color(0xFF22C55E) : KColors.primary).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    hasDoc ? Icons.check_circle_rounded : Icons.upload_rounded,
                    color: hasDoc ? const Color(0xFF22C55E) : KColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: KTextStyles.caption.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (isUploading)
                  const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: KColors.primary),
                  )
                else
                  InkWell(
                    onTap: onPick,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: KColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        hasDoc ? 'Reprendre la photo' : 'Prendre / Choisir',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: KColors.primary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (previewFile != null || (hasDoc && existing?.fileUrl != null))
            Container(
              height: 130,
              decoration: const BoxDecoration(
                color: KColors.base200,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
              ),
              clipBehavior: Clip.antiAlias,
              child: previewFile != null
                  ? Image.file(File(previewFile!.path), fit: BoxFit.cover, width: double.infinity)
                  : Image.network(
                      existing!.fileUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_rounded, color: KColors.baseContentMid),
                    ),
            ),
          if (error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
              ),
              child: Text(error!, style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
            )
          else if (rejected && existing!.rejectionReason.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 12, color: Color(0xFFEF4444)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Document rejeté : ${existing!.rejectionReason}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Étape finale : récapitulatif + soumission ─────────────────────────────────

class _ReviewStep extends StatelessWidget {
  final Map<String, DriverDocumentModel?> existingMap;
  final bool submitting;
  final VoidCallback onSubmit;

  const _ReviewStep({
    required this.existingMap,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(KSpacing.pagePaddingH),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Tous vos documents sont prêts.',
                        style: KTextStyles.h3.copyWith(color: const Color(0xFF15803D)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KSpacing.xl),
              Text('Documents fournis', style: KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ...kRequiredDocTypes.map((type) {
                final doc = existingMap[type];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        doc != null ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        size: 18,
                        color: doc != null ? const Color(0xFF22C55E) : KColors.baseContentMid,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(kDocTypeLabels[type] ?? type, style: KTextStyles.caption)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        _BottomBar(
          child: KButton(
            label: 'Soumettre mes documents',
            icon: Icons.smart_toy_rounded,
            isLoading: submitting,
            onPressed: submitting ? null : onSubmit,
          ),
        ),
      ],
    );
  }
}

// ── Barre basse commune ────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final Widget child;
  const _BottomBar({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: KColors.base100,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SafeArea(top: false, child: child),
    );
  }
}
