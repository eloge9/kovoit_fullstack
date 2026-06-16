import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/evaluation_model.dart';
import '../repositories/evaluation_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_avatar.dart';
import '../../../core/widgets/k_badge.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/utils/formatters.dart';

final _evaluationsProvider = FutureProvider<List<EvaluationModel>>(
  (ref) => EvaluationRepository().mesEvaluations(),
);

class EvaluationListPage extends ConsumerWidget {
  const EvaluationListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_evaluationsProvider);

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        title: Row(
          children: [
            Image.asset('assets/logos/logo1.png', width: 22, height: 22),
            const SizedBox(width: 8),
            Text(
              'Mes évaluations',
              style: KTextStyles.bodySm.copyWith(
                fontWeight: FontWeight.w700,
                color: KColors.baseContent,
              ),
            ),
          ],
        ),
      ),
      body: dataAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: KColors.primary),
        ),
        error: (_, _) => KEmptyState(
          icon: Icons.error_outline,
          message: 'Impossible de charger les évaluations',
          actionLabel: 'Réessayer',
          onAction: () => ref.refresh(_evaluationsProvider),
        ),
        data: (evals) {
          if (evals.isEmpty) {
            return const KEmptyState(
              emoji: '⭐',
              message:
                  'Aucune évaluation reçue pour l\'instant.\nComplétez des trajets pour en recevoir.',
            );
          }

          final moyenne = evals.isEmpty
              ? 0.0
              : evals.map((e) => e.note).reduce((a, b) => a + b) / evals.length;

          return RefreshIndicator(
            color: KColors.primary,
            onRefresh: () async => ref.refresh(_evaluationsProvider),
            child: ListView(
              padding: const EdgeInsets.all(KSpacing.pagePaddingH),
              children: [
                const SizedBox(height: KSpacing.lg),

                // ── Résumé ────────────────────────────────────────────────
                KCard(
                  child: Padding(
                    padding: const EdgeInsets.all(KSpacing.xl),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Note moyenne', style: KTextStyles.label),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    moyenne.toStringAsFixed(1),
                                    style: KTextStyles.statValue.copyWith(
                                      fontSize: 32,
                                      color: KColors.warning,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.star_rounded,
                                    color: KColors.warning,
                                    size: 28,
                                  ),
                                ],
                              ),
                              Text(
                                '${evals.length} évaluation${evals.length > 1 ? 's' : ''}',
                                style: KTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        _StarBar(moyenne: moyenne),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: KSpacing.xl),

                Text('Évaluations reçues', style: KTextStyles.label),
                const SizedBox(height: KSpacing.md),

                ...evals.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: KSpacing.md),
                    child: _EvalCard(eval: e),
                  ),
                ),

                const SizedBox(height: KSpacing.xxl),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EvalCard extends StatelessWidget {
  final EvaluationModel eval;
  const _EvalCard({required this.eval});

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                KAvatar(
                  name: eval.auteurNom,
                  photoUrl: eval.auteurPhoto,
                  size: 36,
                ),
                const SizedBox(width: KSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eval.auteurNom,
                        style: KTextStyles.bodySm.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        Formatters.date(eval.dateEvaluation),
                        style: KTextStyles.meta,
                      ),
                    ],
                  ),
                ),
                _Stars(note: eval.note),
              ],
            ),
            if (eval.commentaire != null && eval.commentaire!.isNotEmpty) ...[
              const SizedBox(height: KSpacing.md),
              Container(
                padding: const EdgeInsets.all(KSpacing.md),
                decoration: BoxDecoration(
                  color: KColors.base200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"${eval.commentaire!}"',
                  style: KTextStyles.bodySm.copyWith(
                    color: KColors.baseContentMid,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            if (eval.signalement) ...[
              const SizedBox(height: KSpacing.md),
              KBadge.error(
                'Signalement: ${eval.motifSignalement ?? "Non précisé"}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final int note;
  const _Stars({required this.note});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < note ? Icons.star_rounded : Icons.star_border_rounded,
          color: KColors.warning,
          size: 18,
        ),
      ),
    );
  }
}

class _StarBar extends StatelessWidget {
  final double moyenne;
  const _StarBar({required this.moyenne});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starNote = 5 - i;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$starNote', style: KTextStyles.meta),
              const SizedBox(width: 4),
              Icon(Icons.star_rounded, color: KColors.warning, size: 12),
            ],
          ),
        );
      }),
    );
  }
}
