import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';

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
        formData.files.add(MapEntry(
          'photo_cni',
          await MultipartFile.fromFile(
            _cniFile!.path,
            filename: 'cni.jpg',
          ),
        ));
      }
      if (_permisFile != null) {
        formData.files.add(MapEntry(
          'photo_permis',
          await MultipartFile.fromFile(
            _permisFile!.path,
            filename: 'permis.jpg',
          ),
        ));
      }

      await DioClient.upload(
        ApiConstants.uploadDocuments,
        formData,
        onSendProgress: (sent, total) {
          setState(() => _progress = sent / total);
        },
      );

      await ref.read(authProvider.notifier).loadProfil();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documents envoyés ! En cours de vérification.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
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
      appBar: AppBar(title: const Text('Mes documents')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Statut global
          Card(
            color: _statutColor(user?.statutValidation).withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                          'Statut de vérification',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _statutLabel(user?.statutValidation ?? 'non_soumis'),
                          style: TextStyle(
                            color: _statutColor(user?.statutValidation),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Carte Nationale d\'Identité (CNI)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _DocumentUploadCard(
            file: _cniFile,
            existingUrl: user?.photoCNI,
            onPick: () => _pickImage('cni'),
            label: 'CNI',
          ),
          const SizedBox(height: 20),

          const Text(
            'Permis de conduire',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _DocumentUploadCard(
            file: _permisFile,
            existingUrl: user?.photoPermis,
            onPick: () => _pickImage('permis'),
            label: 'Permis',
          ),
          const SizedBox(height: 24),

          if (_isUploading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.grey.shade200,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Envoi en cours... ${(_progress * 100).toStringAsFixed(0)}%',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
          ],

          AppButton(
            label: 'Envoyer les documents',
            icon: Icons.upload,
            onPressed: _isUploading ? null : _upload,
            isLoading: _isUploading,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Color _statutColor(String? statut) {
    switch (statut) {
      case 'valide':
        return AppTheme.successColor;
      case 'en_attente':
        return AppTheme.warningColor;
      case 'rejete':
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  IconData _statutIcon(String? statut) {
    switch (statut) {
      case 'valide':
        return Icons.verified;
      case 'en_attente':
        return Icons.hourglass_empty;
      case 'rejete':
        return Icons.cancel;
      default:
        return Icons.upload_file;
    }
  }

  String _statutLabel(String statut) {
    switch (statut) {
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
        height: 140,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null
                ? AppTheme.primaryColor
                : Colors.grey.shade300,
            width: file != null ? 2 : 1,
            style: BorderStyle.solid,
          ),
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(file!, fit: BoxFit.cover),
              )
            : existingUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      existingUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(label),
                    ),
                  )
                : _placeholder(label),
      ),
    );
  }

  Widget _placeholder(String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.grey),
        const SizedBox(height: 8),
        Text(
          'Appuyez pour ajouter votre $label',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ],
    );
  }
}
