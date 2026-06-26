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

// ── Providers ──────────────────────────────────────────────────────────────────

final _recuesProvider = FutureProvider<List<EvaluationModel>>(
  (ref) => EvaluationRepository().mesEvaluations(),
);

final _envoyeesProvider = FutureProvider<List<EvaluationModel>>(
  (ref) => EvaluationRepository().mesEvaluationsEnvoyees(),
);

// ── Page principale ────────────────────────────────────────────────────────────

class EvaluationListPage extends ConsumerWidget {
  const EvaluationListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          bottom: const TabBar(
            indicatorColor: KColors.primary,
            indicatorWeight: 2.5,
            labelColor: KColors.primary,
            unselectedLabelColor: KColors.baseContentMid,
            labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: [
              Tab(text: 'Reçues'),
              Tab(text: 'Envoyées'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RecuesTab(ref: ref),
            _EnvoyeesTab(ref: ref),
          ],
        ),
      ),
    );
  }
}

// ── Onglet "Reçues" ────────────────────────────────────────────────────────────

class _RecuesTab extends ConsumerWidget {
  const _RecuesTab({required this.ref});
  // ignore: unused_field
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_recuesProvider);

    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: KColors.primary)),
      error: (_, _) => KEmptyState(
        icon: Icons.error_outline,
        message: 'Impossible de charger les évaluations',
        actionLabel: 'Réessayer',
        onAction: () => ref.refresh(_recuesProvider),
      ),
      data: (evals) {
        if (evals.isEmpty) {
          return const KEmptyState(
            emoji: '⭐',
            message: 'Aucune évaluation reçue pour l\'instant.\nComplétez des trajets pour en recevoir.',
          );
        }

        final moyenne = evals.map((e) => e.note).reduce((a, b) => a + b) / evals.length;

        return RefreshIndicator(
          color: KColors.primary,
          onRefresh: () async => ref.refresh(_recuesProvider),
          child: ListView(
            padding: const EdgeInsets.all(KSpacing.pagePaddingH),
            children: [
              const SizedBox(height: KSpacing.lg),
              _SummaryCard(moyenne: moyenne, count: evals.length),
              const SizedBox(height: KSpacing.xl),
              Text('${evals.length} évaluation${evals.length > 1 ? 's' : ''} reçue${evals.length > 1 ? 's' : ''}',
                  style: KTextStyles.label),
              const SizedBox(height: KSpacing.md),
              ...evals.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.md),
                child: _EvalCard(
                  eval: e,
                  mode: _CardMode.recue,
                ),
              )),
              const SizedBox(height: KSpacing.xxl),
            ],
          ),
        );
      },
    );
  }
}

// ── Onglet "Envoyées" ──────────────────────────────────────────────────────────

class _EnvoyeesTab extends ConsumerWidget {
  const _EnvoyeesTab({required this.ref});
  // ignore: unused_field
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_envoyeesProvider);

    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: KColors.primary)),
      error: (_, _) => KEmptyState(
        icon: Icons.error_outline,
        message: 'Impossible de charger les évaluations',
        actionLabel: 'Réessayer',
        onAction: () => ref.refresh(_envoyeesProvider),
      ),
      data: (evals) {
        if (evals.isEmpty) {
          return const KEmptyState(
            emoji: '✍️',
            message: 'Vous n\'avez pas encore envoyé d\'évaluation.\nÉvaluez vos conducteurs après vos trajets.',
          );
        }

        return RefreshIndicator(
          color: KColors.primary,
          onRefresh: () async => ref.refresh(_envoyeesProvider),
          child: ListView(
            padding: const EdgeInsets.all(KSpacing.pagePaddingH),
            children: [
              const SizedBox(height: KSpacing.lg),
              Text('${evals.length} évaluation${evals.length > 1 ? 's' : ''} envoyée${evals.length > 1 ? 's' : ''}',
                  style: KTextStyles.label),
              const SizedBox(height: KSpacing.md),
              ...evals.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.md),
                child: _EvalCard(
                  eval: e,
                  mode: _CardMode.envoyee,
                ),
              )),
              const SizedBox(height: KSpacing.xxl),
            ],
          ),
        );
      },
    );
  }
}

// ── Carte résumé (note moyenne) ────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double moyenne;
  final int count;
  const _SummaryCard({required this.moyenne, required this.count});

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Votre note moyenne', style: KTextStyles.label),
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
                      const Icon(Icons.star_rounded, color: KColors.warning, size: 28),
                    ],
                  ),
                  Text(
                    '$count évaluation${count > 1 ? 's' : ''} reçue${count > 1 ? 's' : ''}',
                    style: KTextStyles.caption,
                  ),
                ],
              ),
            ),
            _MiniStars(note: moyenne.round()),
          ],
        ),
      ),
    );
  }
}

// ── Mode de carte ──────────────────────────────────────────────────────────────

enum _CardMode { recue, envoyee }

// ── Carte évaluation ───────────────────────────────────────────────────────────

class _EvalCard extends StatelessWidget {
  final EvaluationModel eval;
  final _CardMode mode;
  const _EvalCard({required this.eval, required this.mode});

  @override
  Widget build(BuildContext context) {
    final isRecue = mode == _CardMode.recue;
    final personNom = isRecue ? eval.auteurNom : eval.cibleNom;
    final personPhoto = isRecue ? eval.auteurPhoto : eval.ciblePhoto;
    final roleLabel = isRecue ? 'De' : 'Pour';

    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête : personne + note ──────────────────────────────
            Row(
              children: [
                KAvatar(name: personNom, photoUrl: personPhoto, size: 36),
                const SizedBox(width: KSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$roleLabel ',
                            style: KTextStyles.meta.copyWith(
                              color: KColors.baseContentMid,
                            ),
                          ),
                          Text(
                            personNom.isEmpty ? '—' : personNom,
                            style: KTextStyles.bodySm.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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

            // ── Trajet ─────────────────────────────────────────────────
            if (eval.trajetLabel.isNotEmpty) ...[
              const SizedBox(height: KSpacing.sm),
              Row(
                children: [
                  const Icon(Icons.route_rounded, size: 12, color: KColors.baseContentMid),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      eval.trajetLabel,
                      style: KTextStyles.meta.copyWith(color: KColors.baseContentMid),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // ── Commentaire ────────────────────────────────────────────
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

            // ── Signalement (pour les reçues) ──────────────────────────
            if (isRecue && eval.signalement) ...[
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

// ── Étoiles ────────────────────────────────────────────────────────────────────

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

class _MiniStars extends StatelessWidget {
  final int note;
  const _MiniStars({required this.note});

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
              Icon(
                starNote <= note ? Icons.star_rounded : Icons.star_border_outlined,
                color: starNote <= note ? KColors.warning : KColors.base300,
                size: 12,
              ),
            ],
          ),
        );
      }),
    );
  }
}
