import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';

class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({super.key});

  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage> {
  File? _cniFile;
  File? _permisFile;
  bool _isUploading = false;
  double _progress = 0;

  Future<void> _pickImage(String type) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      if (type == 'cni') {
        _cniFile = File(picked.path);
      } else {
        _permisFile = File(picked.path);
      }
    });
  }

  Future<void> _upload() async {
    if (_cniFile == null && _permisFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins un document')),
      );
      return;
    }
    setState(() {
      _isUploading = true;
      _progress = 0;
    });

    try {
      final formData = FormData();
      if (_cniFile != null) {
        formData.files.add(
          MapEntry(
            'photo_cni',
            await MultipartFile.fromFile(_cniFile!.path, filename: 'cni.jpg'),
          ),
        );
      }
      if (_permisFile != null) {
        formData.files.add(
          MapEntry(
            'photo_permis',
            await MultipartFile.fromFile(
              _permisFile!.path,
              filename: 'permis.jpg',
            ),
          ),
        );
      }
      await DioClient.upload(
        ApiConstants.uploadDocuments,
        formData,
        onSendProgress: (sent, total) =>
            setState(() => _progress = sent / total),
      );
      await ref.read(authProvider.notifier).loadProfil();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documents envoyés ! En cours de vérification.'),
            backgroundColor: KColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: KColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logos/logo1.png', width: 22, height: 22),
            const SizedBox(width: 8),
            Text(
              'Mes documents',
              style: KTextStyles.bodySm.copyWith(
                fontWeight: FontWeight.w700,
                color: KColors.baseContent,
              ),
            ),
          ],
        ),
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        leading: IconButton(
          icon: Icon(context.canPop() ? Icons.arrow_back : Icons.home_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(user?.role == 'conducteur' ? '/conducteur' : '/passager'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(KSpacing.pagePaddingH),
        children: [
          const SizedBox(height: KSpacing.lg),

          // ── Statut global ──────────────────────────────────────────────
          KCard(
            child: Padding(
              padding: const EdgeInsets.all(KSpacing.xl),
              child: Row(
                children: [
                  Icon(
                    _statutIcon(user?.statutValidation),
                    color: _statutColor(user?.statutValidation),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STATUT DE VÉRIFICATION',
                          style: KTextStyles.label,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _statutLabel(user?.statutValidation ?? 'non_soumis'),
                          style: KTextStyles.bodySmBold.copyWith(
                            color: _statutColor(user?.statutValidation),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: KSpacing.xl),

          // ── CNI ────────────────────────────────────────────────────────
          Text(
            "Carte Nationale d'Identité (CNI)",
            style: KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _DocumentUploadCard(
            file: _cniFile,
            existingUrl: user?.photoCNI,
            onPick: () => _pickImage('cni'),
            label: 'CNI',
          ),
          const SizedBox(height: KSpacing.xl),

          // ── Permis ─────────────────────────────────────────────────────
          Text(
            'Permis de conduire',
            style: KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _DocumentUploadCard(
            file: _permisFile,
            existingUrl: user?.photoPermis,
            onPick: () => _pickImage('permis'),
            label: 'Permis',
          ),
          const SizedBox(height: KSpacing.xl),

          if (_isUploading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress,
                color: KColors.primary,
                backgroundColor: KColors.base300,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Envoi en cours… ${(_progress * 100).toStringAsFixed(0)}%',
              textAlign: TextAlign.center,
              style: KTextStyles.caption,
            ),
            const SizedBox(height: 16),
          ],

          KButton(
            label: 'Envoyer les documents',
            icon: Icons.upload_outlined,
            onPressed: _isUploading ? null : _upload,
            isLoading: _isUploading,
          ),
          const SizedBox(height: KSpacing.xxl),
        ],
      ),
    );
  }

  Color _statutColor(String? s) {
    switch (s) {
      case 'valide':
        return KColors.success;
      case 'en_attente':
        return KColors.warning;
      case 'rejete':
        return KColors.error;
      default:
        return KColors.baseContentMid;
    }
  }

  IconData _statutIcon(String? s) {
    switch (s) {
      case 'valide':
        return Icons.verified_outlined;
      case 'en_attente':
        return Icons.hourglass_empty_outlined;
      case 'rejete':
        return Icons.cancel_outlined;
      default:
        return Icons.upload_file_outlined;
    }
  }

  String _statutLabel(String s) {
    switch (s) {
      case 'valide':
        return 'Documents validés ✓';
      case 'en_attente':
        return 'En attente de vérification';
      case 'rejete':
        return 'Documents rejetés — Renvoyez';
      default:
        return 'Documents non encore soumis';
    }
  }
}

class _DocumentUploadCard extends StatelessWidget {
  final File? file;
  final String? existingUrl;
  final VoidCallback onPick;
  final String label;

  const _DocumentUploadCard({
    required this.file,
    required this.existingUrl,
    required this.onPick,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: KColors.base200,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: file != null ? KColors.primary : KColors.border,
            width: file != null ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: file != null
            ? Image.file(file!, fit: BoxFit.cover)
            : existingUrl != null
            ? Image.network(
                existingUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(
        Icons.add_photo_alternate_outlined,
        size: 36,
        color: KColors.baseContentMid,
      ),
      const SizedBox(height: 8),
      Text('Appuyez pour ajouter votre $label', style: KTextStyles.caption),
    ],
  );
}
