import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../evaluations/repositories/evaluation_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/star_rating.dart';

final _evalRepoProvider =
    Provider<EvaluationRepository>((ref) => EvaluationRepository());

class EvaluationPage extends ConsumerStatefulWidget {
  final int trajetId;
  final String cibleId;

  const EvaluationPage({
    super.key,
    required this.trajetId,
    required this.cibleId,
  });

  @override
  ConsumerState<EvaluationPage> createState() => _EvaluationPageState();
}

class _EvaluationPageState extends ConsumerState<EvaluationPage> {
  int _note = 0;
  final _commentaireCtrl = TextEditingController();
  bool _isLoading = false;
  bool _success = false;
  String? _error;

  @override
  void dispose() {
    _commentaireCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_note == 0) {
      setState(() => _error = 'Veuillez attribuer une note (1 à 5 étoiles)');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(_evalRepoProvider).evaluer(
            trajetId: widget.trajetId,
            cibleId: widget.cibleId,
            note: _note,
            commentaire: _commentaireCtrl.text.trim().isEmpty
                ? null
                : _commentaireCtrl.text.trim(),
          );
      setState(() {
        _isLoading = false;
        _success = true;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_success) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, size: 80, color: AppTheme.secondaryColor),
              const SizedBox(height: 24),
              const Text(
                'Évaluation envoyée !',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                'Merci pour votre retour.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Évaluer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            const Icon(
              Icons.rate_review_outlined,
              size: 60,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'Comment s\'est passé votre trajet ?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Votre évaluation aide les autres utilisateurs',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Étoiles interactives
            InteractiveStarRating(
              onRatingSelected: (rating) => setState(() => _note = rating),
              initialRating: _note,
            ),
            const SizedBox(height: 8),
            Text(
              _note == 0
                  ? 'Appuyez sur une étoile'
                  : _noteLabel(_note),
              style: TextStyle(
                color: _note > 0 ? AppTheme.secondaryColor : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),

            // Commentaire
            TextField(
              controller: _commentaireCtrl,
              maxLines: 4,
              maxLength: 300,
              decoration: InputDecoration(
                labelText: 'Commentaire (optionnel)',
                hintText: 'Partagez votre expérience...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                alignLabelWithHint: true,
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppTheme.errorColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            AppButton(
              label: 'Envoyer l\'évaluation',
              icon: Icons.send,
              onPressed: _isLoading ? null : _submit,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  String _noteLabel(int note) {
    switch (note) {
      case 1:
        return 'Très mauvais';
      case 2:
        return 'Mauvais';
      case 3:
        return 'Correct';
      case 4:
        return 'Bien';
      case 5:
        return 'Excellent !';
      default:
        return '';
    }
  }
}
