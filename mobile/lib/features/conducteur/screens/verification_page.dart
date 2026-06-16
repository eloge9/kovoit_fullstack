import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';

class VerificationPage extends ConsumerWidget {
  const VerificationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final statut = user?.statutValidation ?? 'non_soumis';

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
          'Vérification du compte',
          style: KTextStyles.bodySm.copyWith(
            fontWeight: FontWeight.w700,
            color: KColors.baseContent,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: KColors.primary,
        onRefresh: () => ref.read(authProvider.notifier).loadProfil(),
        child: ListView(
          padding: const EdgeInsets.all(KSpacing.pagePaddingH),
          children: [
            const SizedBox(height: KSpacing.lg),

            // ── Bannière statut ────────────────────────────────────────
            _StatusBanner(statut: statut),
            const SizedBox(height: KSpacing.xl),

            // ── Étapes de vérification ─────────────────────────────────
            KCard(
              child: Column(
                children: [
                  const KCardHeader(title: 'Étapes de vérification'),
                  Padding(
                    padding: const EdgeInsets.all(KSpacing.xl),
                    child: Column(
                      children: [
                        _EtapeRow(
                          num: 1,
                          label: 'Profil conducteur créé',
                          desc: 'Numéro de permis et véhicule enregistrés.',
                          done: true,
                        ),
                        _EtapeRow(
                          num: 2,
                          label: 'Documents soumis',
                          desc: 'CNI et permis de conduire uploadés.',
                          done: statut != 'non_soumis',
                        ),
                        _EtapeRow(
                          num: 3,
                          label: 'Vérification IA',
                          desc: 'Analyse automatique des documents.',
                          done: statut == 'en_attente' || statut == 'valide',
                        ),
                        _EtapeRow(
                          num: 4,
                          label: 'Validation finale',
                          desc: 'Revue par notre équipe de modération.',
                          done: statut == 'valide',
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KSpacing.xl),

            // ── Documents actuels ──────────────────────────────────────
            KCard(
              child: Column(
                children: [
                  const KCardHeader(title: 'Mes documents'),
                  Padding(
                    padding: const EdgeInsets.all(KSpacing.xl),
                    child: Column(
                      children: [
                        _DocRow(
                          icon: Icons.badge_outlined,
                          label: "Carte Nationale d'Identité",
                          uploaded: user?.photoCNI != null,
                        ),
                        const SizedBox(height: KSpacing.md),
                        _DocRow(
                          icon: Icons.card_membership_outlined,
                          label: 'Permis de conduire',
                          uploaded: user?.photoPermis != null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KSpacing.xl),

            // ── Actions selon statut ───────────────────────────────────
            if (statut == 'non_soumis' || statut == 'rejete') ...[
              if (statut == 'rejete')
                Container(
                  padding: const EdgeInsets.all(KSpacing.md),
                  margin: const EdgeInsets.only(bottom: KSpacing.lg),
                  decoration: BoxDecoration(
                    color: KColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: KColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: KColors.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Vos documents ont été rejetés. '
                          'Veuillez les renvoyer en vous assurant qu\'ils sont lisibles.',
                          style: KTextStyles.bodySm.copyWith(
                            color: KColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              KButton(
                label: 'Soumettre mes documents',
                icon: Icons.upload_file_rounded,
                onPressed: () => context.push('/conducteur/documents'),
              ),
            ],

            if (statut == 'en_attente')
              KCard(
                child: Padding(
                  padding: const EdgeInsets.all(KSpacing.xl),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: KColors.warning.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.hourglass_bottom_rounded,
                          color: KColors.warning,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: KSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'En cours de vérification',
                              style: KTextStyles.bodySm.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Nos agents examinent vos documents. '
                              'Vous serez notifié dès que la vérification est terminée (24-48h).',
                              style: KTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (statut == 'valide')
              KCard(
                child: Padding(
                  padding: const EdgeInsets.all(KSpacing.xl),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: KColors.success.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          color: KColors.success,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: KSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Compte vérifié ✓',
                              style: KTextStyles.bodySm.copyWith(
                                fontWeight: FontWeight.w700,
                                color: KColors.success,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Votre profil conducteur est validé. '
                              'Vous pouvez maintenant proposer des trajets.',
                              style: KTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: KSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

// ── Bannière statut ────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final String statut;
  const _StatusBanner({required this.statut});

  Color get _color {
    switch (statut) {
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

  IconData get _icon {
    switch (statut) {
      case 'valide':
        return Icons.verified_rounded;
      case 'en_attente':
        return Icons.hourglass_empty_rounded;
      case 'rejete':
        return Icons.cancel_outlined;
      default:
        return Icons.upload_file_outlined;
    }
  }

  String get _label {
    switch (statut) {
      case 'valide':
        return 'Compte vérifié';
      case 'en_attente':
        return 'Vérification en cours';
      case 'rejete':
        return 'Documents rejetés';
      default:
        return 'Documents non soumis';
    }
  }

  String get _desc {
    switch (statut) {
      case 'valide':
        return 'Votre profil est validé et actif.';
      case 'en_attente':
        return 'Vos documents sont en cours d\'analyse.';
      case 'rejete':
        return 'Renvoyez vos documents pour relancer la vérification.';
      default:
        return 'Soumettez votre CNI et permis pour commencer.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KSpacing.xl),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, color: _color, size: 26),
          ),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label,
                  style: KTextStyles.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(_desc, style: KTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Étape de vérification ─────────────────────────────────────────────────────

class _EtapeRow extends StatelessWidget {
  final int num;
  final String label, desc;
  final bool done, isLast;
  const _EtapeRow({
    required this.num,
    required this.label,
    required this.desc,
    required this.done,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: done ? KColors.success : KColors.base200,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : Text(
                        '$num',
                        style: KTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: KColors.baseContentMid,
                        ),
                      ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: done
                    ? KColors.success.withValues(alpha: 0.3)
                    : KColors.base300,
                margin: const EdgeInsets.symmetric(vertical: 2),
              ),
          ],
        ),
        const SizedBox(width: KSpacing.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: KTextStyles.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                    color: done ? KColors.baseContent : KColors.baseContentMid,
                  ),
                ),
                Text(desc, style: KTextStyles.meta),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Ligne document ─────────────────────────────────────────────────────────────

class _DocRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool uploaded;
  const _DocRow({
    required this.icon,
    required this.label,
    required this.uploaded,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: (uploaded ? KColors.success : KColors.baseContentMid)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: uploaded ? KColors.success : KColors.baseContentMid,
            size: 18,
          ),
        ),
        const SizedBox(width: KSpacing.md),
        Expanded(child: Text(label, style: KTextStyles.bodySm)),
        Icon(
          uploaded ? Icons.check_circle_outline : Icons.radio_button_unchecked,
          color: uploaded ? KColors.success : KColors.base300,
          size: 20,
        ),
      ],
    );
  }
}
