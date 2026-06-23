import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../providers/verification_provider.dart';
import '../models/verification_model.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_button.dart';

// ── Provider local pour la map docType → fichier sélectionné ──────────────────

final _selectedFilesProvider =
    StateProvider.autoDispose<Map<String, XFile>>((ref) => {});

class DocumentUploadPage extends ConsumerWidget {
  const DocumentUploadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(verificationDocumentsProvider);

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: KColors.baseContent),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Soumettre mes documents',
          style: KTextStyles.bodySm
              .copyWith(fontWeight: FontWeight.w700, color: KColors.baseContent),
        ),
      ),
      body: docsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: KColors.primary)),
        error: (e, _) => Center(
          child: Text('Erreur: $e', style: KTextStyles.bodySm.copyWith(color: KColors.error)),
        ),
        data: (existingDocs) => _UploadBody(existingDocs: existingDocs),
      ),
    );
  }
}

class _UploadBody extends ConsumerStatefulWidget {
  final List<DriverDocumentModel> existingDocs;
  const _UploadBody({required this.existingDocs});

  @override
  ConsumerState<_UploadBody> createState() => _UploadBodyState();
}

class _UploadBodyState extends ConsumerState<_UploadBody> {
  final Map<String, bool> _uploading = {};
  final Map<String, String?> _errors = {};

  late final Map<String, DriverDocumentModel?> _existingMap;

  @override
  void initState() {
    super.initState();
    _existingMap = {
      for (final d in widget.existingDocs) d.documentType: d,
    };
  }

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

    // Pré-visualisation locale immédiate
    ref.read(_selectedFilesProvider.notifier).update((map) {
      final copy = Map<String, XFile>.from(map);
      copy[docType] = file!;
      return copy;
    });

    // Upload vers le backend
    setState(() {
      _uploading[docType] = true;
      _errors[docType] = null;
    });

    try {
      final repo = ref.read(verificationRepositoryProvider);
      await repo.uploadDocument(
        docType,
        file.path,
        file.name,
      );
      if (!mounted) return;
      ref.invalidate(verificationDocumentsProvider);
      ref.invalidate(verificationStatusProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${kDocTypeLabels[docType] ?? docType} uploadé avec succès !'),
          backgroundColor: const Color(0xFF22C55E),
        ),
      );
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
              Text(
                'Choisir la source',
                style: KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w700),
              ),
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

  Future<void> _deleteDocument(DriverDocumentModel doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer ce document ?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        content: Text(
          'Vous pourrez en uploader un nouveau après.',
          style: KTextStyles.caption,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final repo = ref.read(verificationRepositoryProvider);
      await repo.deleteDocument(doc.id);
      if (!mounted) return;
      ref.invalidate(verificationDocumentsProvider);
      ref.invalidate(verificationStatusProvider);
      setState(() {
        _existingMap.remove(doc.documentType);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedFiles = ref.watch(_selectedFilesProvider);
    final totalRequired = kRequiredDocTypes.length;
    final uploaded = _existingMap.values.where((d) => d != null).length;

    return Column(
      children: [
        // ── Header progression ─────────────────────────────────────────────
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
                    'Documents obligatoires',
                    style: KTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$uploaded / $totalRequired',
                    style: KTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: KColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: totalRequired > 0 ? uploaded / totalRequired : 0,
                  minHeight: 5,
                  backgroundColor: KColors.base300,
                  valueColor: const AlwaysStoppedAnimation<Color>(KColors.primary),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Uploadez chaque document en prenant une photo claire.',
                style: KTextStyles.meta,
              ),
            ],
          ),
        ),
        const Divider(color: KColors.border, height: 1),

        // ── Liste des documents ────────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(KSpacing.pagePaddingH),
            itemCount: kRequiredDocTypes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final type = kRequiredDocTypes[i];
              final existing = _existingMap[type];
              final previewFile = selectedFiles[type];
              final isUploading = _uploading[type] == true;
              final error = _errors[type];

              return _DocumentTile(
                type: type,
                existing: existing,
                previewFile: previewFile,
                isUploading: isUploading,
                error: error,
                onPick: () => _pickAndUpload(type),
                onDelete: existing != null ? () => _deleteDocument(existing) : null,
              );
            },
          ),
        ),

        // ── Bouton Terminer ─────────────────────────────────────────────────
        Container(
          color: KColors.base100,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: SafeArea(
            top: false,
            child: KButton(
              label: uploaded == totalRequired
                  ? 'Finaliser mon dossier'
                  : 'Enregistrer et continuer ($uploaded/$totalRequired)',
              icon: Icons.check_rounded,
              onPressed: () {
                context.pop();
                context.push('/conducteur/statut');
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tuile document ─────────────────────────────────────────────────────────────

class _DocumentTile extends StatelessWidget {
  final String type;
  final DriverDocumentModel? existing;
  final XFile? previewFile;
  final bool isUploading;
  final String? error;
  final VoidCallback onPick;
  final VoidCallback? onDelete;

  const _DocumentTile({
    required this.type,
    this.existing,
    this.previewFile,
    required this.isUploading,
    this.error,
    required this.onPick,
    this.onDelete,
  });

  bool get hasDoc => existing != null;

  Color get _statusColor {
    if (existing == null) return KColors.baseContentMid;
    if (existing!.isVerified) return const Color(0xFF22C55E);
    if (existing!.isRejected) return const Color(0xFFEF4444);
    if (existing!.isProcessing) return const Color(0xFF3B82F6);
    return const Color(0xFFF59E0B);
  }

  String get _statusLabel {
    if (existing == null) return 'Non soumis';
    if (existing!.isVerified) return 'Vérifié';
    if (existing!.isRejected) return 'Rejeté';
    if (existing!.isProcessing) return 'En traitement';
    return 'En attente';
  }

  IconData get _statusIcon {
    if (existing == null) return Icons.upload_rounded;
    if (existing!.isVerified) return Icons.check_circle_rounded;
    if (existing!.isRejected) return Icons.cancel_rounded;
    if (existing!.isProcessing) return Icons.hourglass_empty_rounded;
    return Icons.schedule_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final label = kDocTypeLabels[type] ?? type;
    final isVehicle = type.startsWith('VEHICLE_');
    final isIdentity = type == 'CNI' || type == 'PASSPORT' || type == 'SELFIE_ID' || type == 'PORTRAIT';

    return Container(
      decoration: BoxDecoration(
        color: KColors.base100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: error != null
              ? const Color(0xFFFCA5A5)
              : hasDoc
                  ? _statusColor.withValues(alpha: 0.25)
                  : KColors.border,
        ),
      ),
      child: Column(
        children: [
          // ── En-tête ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                // Icône catégorie
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isVehicle
                        ? Icons.directions_car_rounded
                        : isIdentity
                            ? Icons.badge_rounded
                            : Icons.article_rounded,
                    color: _statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: KTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(_statusIcon, size: 11, color: _statusColor),
                          const SizedBox(width: 4),
                          Text(
                            _statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Boutons action
                if (isUploading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: KColors.primary,
                    ),
                  )
                else if (hasDoc && (existing!.isVerified || existing!.isPending))
                  // Document validé ou en attente — on peut remplacer
                  InkWell(
                    onTap: onPick,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.refresh_rounded,
                          size: 18, color: KColors.baseContentMid),
                    ),
                  )
                else
                  InkWell(
                    onTap: onPick,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: KColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        hasDoc ? 'Remplacer' : 'Uploader',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: KColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Prévisualisation ────────────────────────────────────────────
          if (previewFile != null || (hasDoc && existing!.fileUrl != null))
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: KColors.base200,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(13)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (previewFile != null)
                    Image.file(
                      File(previewFile!.path),
                      fit: BoxFit.cover,
                    )
                  else if (existing!.fileUrl != null)
                    Image.network(
                      existing!.fileUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_rounded,
                        color: KColors.baseContentMid,
                      ),
                    ),
                  // Overlay supprimer
                  if (onDelete != null && !isUploading)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: InkWell(
                        onTap: onDelete,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.delete_rounded,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // ── Message d'erreur ────────────────────────────────────────────
          if (error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
              ),
              child: Text(
                error!,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFEF4444),
                ),
              ),
            ),

          // ── Motif de rejet ──────────────────────────────────────────────
          if (existing != null && existing!.isRejected && existing!.rejectionReason.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 12, color: Color(0xFFEF4444)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      existing!.rejectionReason,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFEF4444),
                      ),
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
