import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/verification_provider.dart';
import '../models/verification_model.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_button.dart';

class DriverStatusPage extends ConsumerWidget {
  const DriverStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(verificationStatusProvider);
    final docsAsync = ref.watch(verificationDocumentsProvider);

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: KColors.baseContent),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Mon statut conducteur',
          style: KTextStyles.bodySm
              .copyWith(fontWeight: FontWeight.w700, color: KColors.baseContent),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: KColors.baseContentMid, size: 20),
            onPressed: () {
              ref.invalidate(verificationStatusProvider);
              ref.invalidate(verificationDocumentsProvider);
            },
          ),
        ],
      ),
      body: statusAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: KColors.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: KColors.error, size: 40),
              const SizedBox(height: 12),
              Text('Impossible de charger le statut',
                  style: KTextStyles.bodySm.copyWith(color: KColors.error)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => ref.invalidate(verificationStatusProvider),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (status) => RefreshIndicator(
          color: KColors.primary,
          onRefresh: () async {
            ref.invalidate(verificationStatusProvider);
            ref.invalidate(verificationDocumentsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(KSpacing.pagePaddingH),
            children: [
              const SizedBox(height: KSpacing.lg),

              // ── Hero statut ──────────────────────────────────────────────
              _StatusHeroCard(status: status),
              const SizedBox(height: KSpacing.xl),

              // ── Timeline des étapes ──────────────────────────────────────
              _TimelineCard(status: status),
              const SizedBox(height: KSpacing.xl),

              // ── Motif de refus ───────────────────────────────────────────
              if (status.isRejected && status.motifRejet.isNotEmpty) ...[
                _RejectionBox(motif: status.motifRejet),
                const SizedBox(height: KSpacing.xl),
              ],

              // ── Documents ────────────────────────────────────────────────
              _DocumentsCard(
                status: status,
                docsAsync: docsAsync,
              ),
              const SizedBox(height: KSpacing.xl),

              // ── Bouton d'action ──────────────────────────────────────────
              _ActionButton(status: status),
              const SizedBox(height: KSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hero card statut ───────────────────────────────────────────────────────────

class _StatusHeroCard extends StatelessWidget {
  final DriverVerificationStatus status;
  const _StatusHeroCard({required this.status});

  Color get _primaryColor {
    if (status.isActive)   return const Color(0xFF22C55E);
    if (status.isRejected || status.isBlocked) return const Color(0xFFEF4444);
    if (status.isPending)  return const Color(0xFFF59E0B);
    return const Color(0xFF3B82F6);
  }

  IconData get _icon {
    if (status.isActive)   return Icons.verified_rounded;
    if (status.isRejected) return Icons.cancel_rounded;
    if (status.isBlocked)  return Icons.block_rounded;
    if (status.isPending)  return Icons.hourglass_empty_rounded;
    return Icons.upload_file_rounded;
  }

  String get _label => kDriverStatusLabels[status.status] ?? status.status;

  @override
  Widget build(BuildContext context) {
    final pct = status.completionPercentage;
    final color = _primaryColor;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.08), color.withValues(alpha: 0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          // Cercle de progression
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: CircularProgressIndicator(
                  value: pct / 100,
                  strokeWidth: 6,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, color: color, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Libellé statut
          Text(
            _label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),

          // Pourcentage complétion
          Text(
            'Dossier complété à $pct%',
            style: KTextStyles.caption,
          ),
          const SizedBox(height: 16),

          // Barre de progression linéaire
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),

          if (!status.isActive && !status.isBlocked) ...[
            const SizedBox(height: 12),
            Text(
              '${status.missingDocuments.length} document(s) manquant(s)',
              style: KTextStyles.caption.copyWith(
                color: KColors.baseContentMid,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Timeline ───────────────────────────────────────────────────────────────────

class _TimelineCard extends StatelessWidget {
  final DriverVerificationStatus status;
  const _TimelineCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final st = status.status;

    // Calcul de l'étape active
    final docsSubmitted = st != 'DRAFT' && st != 'DOCUMENTS_MISSING';
    final aiDone = st == 'AI_APPROVED' || st == 'AI_REJECTED' ||
        st == 'PENDING_ADMIN_REVIEW' || st == 'ACTIVE';
    final validated = st == 'ACTIVE';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: KColors.base100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Progression du dossier',
              style: KTextStyles.bodySm
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          _Step(
            icon: Icons.description_rounded,
            label: 'Documents soumis',
            desc: 'Toutes les pièces obligatoires uploadées',
            state: docsSubmitted ? _StepState.done : _StepState.active,
            isLast: false,
          ),
          _Step(
            icon: Icons.smart_toy_rounded,
            label: 'Analyse IA',
            desc: 'Vérification automatique des documents',
            state: aiDone
                ? _StepState.done
                : (status.isAiPending ? _StepState.active : _StepState.pending),
            isLast: false,
          ),
          _Step(
            icon: Icons.admin_panel_settings_rounded,
            label: 'Validation admin',
            desc: 'Revue par l\'équipe Kovoit',
            state: validated
                ? _StepState.done
                : (status.isAdminPending
                    ? _StepState.active
                    : _StepState.pending),
            isLast: false,
          ),
          _Step(
            icon: Icons.verified_rounded,
            label: 'Compte activé',
            desc: 'Toutes les fonctionnalités débloquées',
            state: validated ? _StepState.done : _StepState.pending,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

enum _StepState { done, active, pending }

class _Step extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  final _StepState state;
  final bool isLast;

  const _Step({
    required this.icon,
    required this.label,
    required this.desc,
    required this.state,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final isDone   = state == _StepState.done;
    final isActive = state == _StepState.active;

    final color = isDone
        ? const Color(0xFF22C55E)
        : isActive
            ? const Color(0xFF3B82F6)
            : KColors.base300;

    final textColor = isDone || isActive ? KColors.baseContent : KColors.baseContentMid;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDone || isActive ? 0.12 : 0.05),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: isDone || isActive ? 1.5 : 1),
              ),
              child: isDone
                  ? const Icon(Icons.check_rounded,
                      color: Color(0xFF22C55E), size: 18)
                  : isActive
                      ? Icon(icon, color: const Color(0xFF3B82F6), size: 18)
                      : Icon(icon, color: KColors.base300, size: 18),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                margin: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: isDone
                      ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                      : KColors.base300,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 6, bottom: isLast ? 0 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: KTextStyles.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'En cours',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(desc, style: KTextStyles.meta),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Motif de refus ─────────────────────────────────────────────────────────────

class _RejectionBox extends StatelessWidget {
  final String motif;
  const _RejectionBox({required this.motif});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFFEF4444), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Motif du refus',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  motif,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFEF4444),
                    height: 1.4,
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

// ── Liste documents ────────────────────────────────────────────────────────────

class _DocumentsCard extends StatelessWidget {
  final DriverVerificationStatus status;
  final AsyncValue<List<DriverDocumentModel>> docsAsync;

  const _DocumentsCard({required this.status, required this.docsAsync});

  @override
  Widget build(BuildContext context) {
    final docs = docsAsync.value ?? [];
    final docsMap = {for (final d in docs) d.documentType: d};

    return Container(
      decoration: BoxDecoration(
        color: KColors.base100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  'Documents obligatoires',
                  style: KTextStyles.bodySm
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '${status.uploadedDocuments.length}/${kRequiredDocTypes.length}',
                  style: KTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: KColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: KColors.border, height: 1),
          ...kRequiredDocTypes.map((type) {
            final doc = docsMap[type];
            return _DocRow(type: type, doc: doc);
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  final String type;
  final DriverDocumentModel? doc;
  const _DocRow({required this.type, this.doc});

  @override
  Widget build(BuildContext context) {
    final label = kDocTypeLabels[type] ?? type;
    final hasDoc = doc != null;

    Color chipColor;
    String chipLabel;
    IconData statusIcon;

    if (!hasDoc) {
      chipColor = KColors.baseContentMid;
      chipLabel = 'Manquant';
      statusIcon = Icons.radio_button_unchecked_rounded;
    } else if (doc!.isVerified) {
      chipColor = const Color(0xFF22C55E);
      chipLabel = 'Vérifié';
      statusIcon = Icons.check_circle_rounded;
    } else if (doc!.isRejected) {
      chipColor = const Color(0xFFEF4444);
      chipLabel = 'Rejeté';
      statusIcon = Icons.cancel_rounded;
    } else if (doc!.isProcessing) {
      chipColor = const Color(0xFF3B82F6);
      chipLabel = 'En cours';
      statusIcon = Icons.hourglass_empty_rounded;
    } else {
      chipColor = const Color(0xFFF59E0B);
      chipLabel = 'En attente';
      statusIcon = Icons.schedule_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            statusIcon,
            color: chipColor,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: KTextStyles.caption.copyWith(
                color: hasDoc ? KColors.baseContent : KColors.baseContentMid,
              ),
            ),
          ),
          if (hasDoc && doc!.isRejected)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                chipLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: chipColor,
                ),
              ),
            )
          else if (hasDoc)
            Text(
              chipLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: chipColor,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Bouton d'action principal ─────────────────────────────────────────────────

class _ActionButton extends ConsumerStatefulWidget {
  final DriverVerificationStatus status;
  const _ActionButton({required this.status});

  @override
  ConsumerState<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends ConsumerState<_ActionButton> {
  bool _isStarting = false;

  Future<void> _startVerification() async {
    setState(() => _isStarting = true);
    try {
      final repo = ref.read(verificationRepositoryProvider);
      await repo.startVerification();
      if (!mounted) return;
      ref.invalidate(verificationStatusProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vérification IA lancée ! Vous serez notifié du résultat.'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.status;

    if (st.isActive) {
      return KButton(
        label: 'Compte activé ✓',
        icon: Icons.verified_rounded,
        variant: KButtonVariant.success,
        onPressed: null,
      );
    }

    if (st.isBlocked) {
      return KButton(
        label: 'Compte suspendu — Contacter le support',
        icon: Icons.support_agent_rounded,
        variant: KButtonVariant.error,
        onPressed: () {},
      );
    }

    if (st.isAiPending) {
      return KButton(
        label: 'Vérification IA en cours…',
        icon: Icons.smart_toy_rounded,
        isLoading: true,
        onPressed: null,
      );
    }

    if (st.isAdminPending) {
      return KButton(
        label: 'En attente d\'un administrateur',
        icon: Icons.admin_panel_settings_rounded,
        variant: KButtonVariant.outline,
        onPressed: null,
      );
    }

    if (st.isRejected) {
      return Column(
        children: [
          KButton(
            label: 'Renvoyer mes documents',
            icon: Icons.upload_file_rounded,
            onPressed: () => context.push('/conducteur/dossier'),
          ),
        ],
      );
    }

    // DRAFT / DOCUMENTS_MISSING : soumettre les docs
    if (st.needsDocuments || st.completionPercentage < 100) {
      return KButton(
        label: 'Soumettre mes documents',
        icon: Icons.upload_file_rounded,
        onPressed: () => context.push('/conducteur/dossier'),
      );
    }

    // Tous les docs sont là → lancer la vérification
    return KButton(
      label: 'Lancer la vérification IA',
      icon: Icons.smart_toy_rounded,
      isLoading: _isStarting,
      onPressed: _isStarting ? null : _startVerification,
    );
  }
}
