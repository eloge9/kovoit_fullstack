import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../repositories/evaluation_repository.dart';
import '../../../core/network/api_interceptor.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';

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
    if (widget.cibleId.isEmpty) {
      setState(() => _error = 'Identifiant du conducteur manquant. Veuillez relancer l\'application.');
      return;
    }
    if (_note == 0) {
      setState(() => _error = 'Veuillez attribuer une note (1 à 5 étoiles)');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await EvaluationRepository().evaluer(
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
        _error = e is ApiException ? e.message : 'Impossible d\'envoyer l\'évaluation.';
        _isLoading = false;
      });
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
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Évaluation',
          style: KTextStyles.bodySm.copyWith(
            fontWeight: FontWeight.w700,
            color: KColors.baseContent,
          ),
        ),
      ),
      body: _success
          ? _SuccessView(onBack: () => context.pop())
          : _FormView(
              note: _note,
              error: _error,
              isLoading: _isLoading,
              commentaireCtrl: _commentaireCtrl,
              onNoteChanged: (n) => setState(() {
                _note = n;
                _error = null;
              }),
              onSubmit: _submit,
            ),
    );
  }
}

// ── Vue succès ─────────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final VoidCallback onBack;
  const _SuccessView({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.pagePaddingH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: KColors.warning.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.star_rounded,
                size: 48,
                color: KColors.warning,
              ),
            ),
            const SizedBox(height: KSpacing.xl),
            Text(
              'Évaluation envoyée !',
              style: KTextStyles.h2.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Merci pour votre retour.\nVotre avis aide la communauté KoVoit.',
              textAlign: TextAlign.center,
              style: KTextStyles.bodySm.copyWith(color: KColors.baseContentMid),
            ),
            const SizedBox(height: KSpacing.xxl),
            KButton(
              label: 'Retour',
              variant: KButtonVariant.outline,
              onPressed: onBack,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Vue formulaire ─────────────────────────────────────────────────────────────

class _FormView extends StatelessWidget {
  final int note;
  final String? error;
  final bool isLoading;
  final TextEditingController commentaireCtrl;
  final ValueChanged<int> onNoteChanged;
  final VoidCallback onSubmit;

  const _FormView({
    required this.note,
    required this.error,
    required this.isLoading,
    required this.commentaireCtrl,
    required this.onNoteChanged,
    required this.onSubmit,
  });

  String get _noteLabel {
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
        return 'Appuyez sur une étoile';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(KSpacing.pagePaddingH),
      children: [
        const SizedBox(height: KSpacing.xl),

        // ── Intro ──────────────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: KColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.rate_review_outlined,
                  size: 32,
                  color: KColors.primary,
                ),
              ),
              const SizedBox(height: KSpacing.lg),
              Text(
                'Comment s\'est passé votre trajet ?',
                style: KTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Votre évaluation aide les autres utilisateurs',
                style: KTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: KSpacing.xxl),

        // ── Étoiles ────────────────────────────────────────────────────
        KCard(
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.xl),
            child: Column(
              children: [
                const Text(
                  'NOTE GLOBALE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: KColors.baseContentMid,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: KSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    return GestureDetector(
                      onTap: () => onNoteChanged(star),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          star <= note
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 44,
                          color: star <= note
                              ? KColors.warning
                              : KColors.base300,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: KSpacing.md),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _noteLabel,
                    key: ValueKey(note),
                    style: KTextStyles.bodySm.copyWith(
                      color: note > 0
                          ? KColors.warning
                          : KColors.baseContentMid,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: KSpacing.xl),

        // ── Commentaire ────────────────────────────────────────────────
        KCard(
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COMMENTAIRE (OPTIONNEL)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: KColors.baseContentMid,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: KSpacing.md),
                TextField(
                  controller: commentaireCtrl,
                  maxLines: 4,
                  maxLength: 300,
                  style: KTextStyles.bodySm,
                  decoration: InputDecoration(
                    hintText: 'Partagez votre expérience…',
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
                    contentPadding: const EdgeInsets.all(14),
                    counterStyle: KTextStyles.meta,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Erreur ────────────────────────────────────────────────────
        if (error != null) ...[
          const SizedBox(height: KSpacing.lg),
          Container(
            padding: const EdgeInsets.all(KSpacing.md),
            decoration: BoxDecoration(
              color: KColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: KColors.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    style: KTextStyles.bodySm.copyWith(color: KColors.error),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: KSpacing.xl),
        KButton(
          label: 'Envoyer l\'évaluation',
          icon: Icons.send_rounded,
          isLoading: isLoading,
          onPressed: isLoading ? null : onSubmit,
        ),
        const SizedBox(height: KSpacing.xxl),
      ],
    );
  }
}
