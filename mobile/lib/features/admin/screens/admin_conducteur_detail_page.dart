import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_avatar.dart';
import '../../../core/widgets/k_badge.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';

final _conducteurDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final res = await DioClient.get('/verification/admin/drivers/$id/');
  if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
  return {};
});

class AdminConducteurDetailPage extends ConsumerStatefulWidget {
  final String conducteurId;
  const AdminConducteurDetailPage({super.key, required this.conducteurId});

  @override
  ConsumerState<AdminConducteurDetailPage> createState() =>
      _AdminConducteurDetailPageState();
}

class _AdminConducteurDetailPageState
    extends ConsumerState<AdminConducteurDetailPage> {
  bool _actionLoading = false;

  @override
  Widget build(BuildContext context) {
    final detailAsync =
        ref.watch(_conducteurDetailProvider(widget.conducteurId));

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
          'Dossier conducteur',
          style: KTextStyles.bodySm.copyWith(
            fontWeight: FontWeight.w700,
            color: KColors.baseContent,
          ),
        ),
        actions: [
          detailAsync.maybeWhen(
            data: (d) {
              final statut =
                  d['driver_status']?.toString() ?? d['statut']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: KBadge.fromStatut(statut),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: KColors.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: KColors.baseContentMid),
              const SizedBox(height: 12),
              Text(e.toString(),
                  style: KTextStyles.caption, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              KButton(
                label: 'Réessayer',
                variant: KButtonVariant.outline,
                onPressed: () =>
                    ref.invalidate(_conducteurDetailProvider(widget.conducteurId)),
              ),
            ],
          ),
        ),
        data: (d) => _buildBody(context, d),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic> d) {
    final user = d['user'] as Map<String, dynamic>? ?? d;
    final username = user['username']?.toString() ?? d['username']?.toString() ?? '?';
    final email = user['email']?.toString() ?? d['email']?.toString() ?? '';
    final photo = user['photo_profil']?.toString() ?? user['photo_profile']?.toString();
    final statut = d['driver_status']?.toString() ?? d['statut_validation']?.toString() ?? '';
    final note = (d['note_moyenne'] as num?)?.toDouble() ?? 0.0;
    final nbTrajets = d['nombre_trajets']?.toString() ?? '0';
    final completion = d['completion_percentage'] as num? ?? 0;
    final rapport = d['rapport_ia'] as Map<String, dynamic>?;
    final documents = d['documents'] as List<dynamic>? ?? [];
    final historique = d['historique_actions'] as List<dynamic>? ?? [];

    return RefreshIndicator(
      color: KColors.primary,
      onRefresh: () async =>
          ref.invalidate(_conducteurDetailProvider(widget.conducteurId)),
      child: ListView(
        padding: const EdgeInsets.all(KSpacing.pagePaddingH),
        children: [
          const SizedBox(height: KSpacing.lg),

          // ── Profil conducteur ──────────────────────────────────────────
          KCard(
            child: Padding(
              padding: const EdgeInsets.all(KSpacing.xl),
              child: Column(children: [
                Row(children: [
                  KAvatar(name: username, photoUrl: photo, size: 56),
                  const SizedBox(width: KSpacing.md),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(username,
                              style: KTextStyles.bodySm
                                  .copyWith(fontWeight: FontWeight.w700)),
                          Text(email, style: KTextStyles.caption),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.star_rounded,
                                color: KColors.warning, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${note.toStringAsFixed(1)} • $nbTrajets trajets',
                              style: KTextStyles.caption,
                            ),
                          ]),
                        ]),
                  ),
                ]),
                const SizedBox(height: KSpacing.lg),
                const Divider(color: KColors.border),
                const SizedBox(height: KSpacing.md),

                // Progression documents
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Documents soumis', style: KTextStyles.bodySm),
                    Text('$completion%',
                        style: KTextStyles.bodySm.copyWith(
                            color: KColors.primary,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: completion / 100,
                    backgroundColor: KColors.base200,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(KColors.primary),
                    minHeight: 8,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: KSpacing.xl),

          // ── Actions selon statut ───────────────────────────────────────
          _buildActions(statut, d),
          const SizedBox(height: KSpacing.xl),

          // ── Rapport IA ─────────────────────────────────────────────────
          if (rapport != null) ...[
            _RapportIaCard(rapport: rapport),
            const SizedBox(height: KSpacing.xl),
          ],

          // ── Documents ─────────────────────────────────────────────────
          if (documents.isNotEmpty) ...[
            _DocumentsCard(documents: documents),
            const SizedBox(height: KSpacing.xl),
          ],

          // ── Historique ────────────────────────────────────────────────
          if (historique.isNotEmpty) ...[
            _HistoriqueCard(historique: historique),
            const SizedBox(height: KSpacing.xl),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildActions(String statut, Map<String, dynamic> d) {
    final id = widget.conducteurId;
    final isPendingAdmin = statut == 'PENDING_ADMIN_REVIEW' ||
        statut == 'AI_APPROVED' ||
        statut == 'en_attente';
    final isActive = statut == 'ACTIVE' || statut == 'valide';
    final isSuspended = statut == 'SUSPENDED';

    if (!isPendingAdmin && !isActive && !isSuspended) {
      return const SizedBox.shrink();
    }

    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Actions',
                style: KTextStyles.bodySm
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: KSpacing.lg),
            if (isPendingAdmin) ...[
              KButton(
                label: 'Approuver le conducteur',
                icon: Icons.verified_user_rounded,
                variant: KButtonVariant.success,
                isLoading: _actionLoading,
                onPressed: _actionLoading ? null : () => _approuver(id),
              ),
              const SizedBox(height: KSpacing.md),
              KButton(
                label: 'Rejeter',
                icon: Icons.cancel_rounded,
                variant: KButtonVariant.error,
                isLoading: _actionLoading,
                onPressed: _actionLoading ? null : () => _rejeter(id),
              ),
            ],
            if (isActive) ...[
              KButton(
                label: 'Suspendre le compte',
                icon: Icons.pause_circle_rounded,
                variant: KButtonVariant.warning,
                isLoading: _actionLoading,
                onPressed: _actionLoading ? null : () => _suspendre(id),
              ),
              const SizedBox(height: KSpacing.md),
              KButton(
                label: 'Bloquer définitivement',
                icon: Icons.block_rounded,
                variant: KButtonVariant.error,
                isLoading: _actionLoading,
                onPressed: _actionLoading ? null : () => _bloquer(id),
              ),
            ],
            if (isSuspended) ...[
              KButton(
                label: 'Réactiver le compte',
                icon: Icons.play_circle_rounded,
                variant: KButtonVariant.success,
                isLoading: _actionLoading,
                onPressed: _actionLoading ? null : () => _reactiver(id),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _approuver(String id) async {
    setState(() => _actionLoading = true);
    try {
      await DioClient.post('/verification/admin/drivers/$id/approve/');
      ref.invalidate(_conducteurDetailProvider(id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Conducteur approuvé avec succès'),
          backgroundColor: KColors.primary,
        ));
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _rejeter(String id) async {
    final motif = await _demanderMotif('Motif de rejet');
    if (motif == null || !mounted) return;
    setState(() => _actionLoading = true);
    try {
      await DioClient.post('/verification/admin/drivers/$id/reject/',
          data: {'motif': motif});
      ref.invalidate(_conducteurDetailProvider(id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Conducteur rejeté'),
          backgroundColor: KColors.error,
        ));
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _suspendre(String id) async {
    final motif = await _demanderMotif('Motif de suspension');
    if (motif == null || !mounted) return;
    setState(() => _actionLoading = true);
    try {
      await DioClient.post('/verification/admin/drivers/$id/suspend/',
          data: {'motif': motif});
      ref.invalidate(_conducteurDetailProvider(id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Compte suspendu'),
          backgroundColor: KColors.warning,
        ));
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _bloquer(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bloquer définitivement ?'),
        content: const Text(
            'Cette action est irréversible. Le conducteur ne pourra plus utiliser KoVoit.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: KColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Bloquer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _actionLoading = true);
    try {
      await DioClient.post('/verification/admin/drivers/$id/block/');
      ref.invalidate(_conducteurDetailProvider(id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Compte bloqué'),
          backgroundColor: KColors.error,
        ));
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _reactiver(String id) async {
    setState(() => _actionLoading = true);
    try {
      await DioClient.post('/verification/admin/drivers/$id/reactivate/');
      ref.invalidate(_conducteurDetailProvider(id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Compte réactivé'),
          backgroundColor: KColors.primary,
        ));
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<String?> _demanderMotif(String title) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Saisissez le motif...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result?.isEmpty == true ? null : result;
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Erreur : $msg'),
      backgroundColor: KColors.error,
    ));
  }
}

// ── Rapport IA ────────────────────────────────────────────────────────────────

class _RapportIaCard extends StatefulWidget {
  final Map<String, dynamic> rapport;
  const _RapportIaCard({required this.rapport});

  @override
  State<_RapportIaCard> createState() => _RapportIaCardState();
}

class _RapportIaCardState extends State<_RapportIaCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final score = (widget.rapport['overall_score'] as num?)?.toDouble() ?? 0.0;
    final fraude = (widget.rapport['fraud_score'] as num?)?.toDouble() ?? 0.0;
    final confiance =
        (widget.rapport['confidence_score'] as num?)?.toDouble() ?? 0.0;
    final summary = widget.rapport['summary']?.toString() ?? '';
    final decision = widget.rapport['decision']?.toString() ?? '';

    return KCard(
      child: Column(
        children: [
          // En-tête cliquable
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(KSpacing.xl),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: KColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.psychology,
                      color: KColors.primary, size: 20),
                ),
                const SizedBox(width: KSpacing.md),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rapport IA',
                            style: KTextStyles.bodySm
                                .copyWith(fontWeight: FontWeight.w700)),
                        Text(
                          'Score global : ${score.toStringAsFixed(0)}/100',
                          style: KTextStyles.caption.copyWith(
                            color: score > 70
                                ? KColors.successContent
                                : score > 50
                                    ? KColors.warningContent
                                    : KColors.error,
                          ),
                        ),
                      ]),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: KColors.baseContentMid,
                ),
              ]),
            ),
          ),
          if (_expanded) ...[
            const Divider(color: KColors.border, height: 0),
            Padding(
              padding: const EdgeInsets.all(KSpacing.xl),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ScoreRow('Score global', score, max: 100),
                    _ScoreRow('Score fraude (bas = bien)',
                        100 - fraude,
                        max: 100),
                    _ScoreRow('Confiance', confiance, max: 100),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: KSpacing.md),
                      Text('Résumé :', style: KTextStyles.caption),
                      const SizedBox(height: 4),
                      Text(summary, style: KTextStyles.bodySm),
                    ],
                    if (decision.isNotEmpty) ...[
                      const SizedBox(height: KSpacing.md),
                      Row(children: [
                        Text('Décision : ',
                            style: KTextStyles.caption),
                        _decisionBadge(decision),
                      ]),
                    ],
                  ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _decisionBadge(String decision) {
    Color bg, fg;
    switch (decision.toUpperCase()) {
      case 'APPROVED':
        bg = KColors.successLight;
        fg = KColors.successContent;
        break;
      case 'REJECTED':
        bg = KColors.errorLight;
        fg = KColors.error;
        break;
      default:
        bg = KColors.infoLight;
        fg = KColors.infoContent;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(decision,
          style: KTextStyles.caption
              .copyWith(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final double value;
  final double max;

  const _ScoreRow(this.label, this.value, {this.max = 100});

  @override
  Widget build(BuildContext context) {
    final percent = (value / max).clamp(0.0, 1.0);
    final color = percent > 0.7
        ? KColors.successContent
        : percent > 0.5
            ? KColors.warningContent
            : KColors.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: KTextStyles.caption),
            Text('${value.toStringAsFixed(0)}/$max',
                style:
                    KTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: KColors.base200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ]),
    );
  }
}

// ── Documents ──────────────────────────────────────────────────────────────────

class _DocumentsCard extends StatelessWidget {
  final List<dynamic> documents;
  const _DocumentsCard({required this.documents});

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KCardHeader(title: 'Documents soumis'),
          ...documents.map((doc) {
            final d = doc as Map<String, dynamic>;
            final type =
                d['document_type']?.toString() ?? d['type']?.toString() ?? '';
            final statut = d['statut']?.toString() ?? 'en_attente';
            final fileUrl = d['fichier']?.toString() ?? d['file']?.toString();

            return Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: KColors.border)),
              ),
              child: ListTile(
                dense: true,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: KColors.base200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.description_outlined,
                      color: KColors.primary, size: 18),
                ),
                title: Text(_typeLabel(type), style: KTextStyles.bodySm),
                subtitle: Text(
                  _statutLabel(statut),
                  style: KTextStyles.caption.copyWith(
                    color: _statutColor(statut),
                  ),
                ),
                trailing: fileUrl != null
                    ? const Icon(Icons.open_in_new,
                        size: 16, color: KColors.primary)
                    : null,
              ),
            );
          }),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    const labels = {
      'CNI': 'Carte Nationale d\'Identité',
      'PERMIS': 'Permis de conduire',
      'CARTE_GRISE': 'Carte grise',
      'ASSURANCE': 'Assurance véhicule',
      'PHOTO_PROFIL': 'Photo de profil',
    };
    return labels[type.toUpperCase()] ?? type;
  }

  String _statutLabel(String s) {
    switch (s) {
      case 'valide':
        return 'Validé';
      case 'rejete':
        return 'Rejeté';
      case 'en_attente':
        return 'En attente';
      default:
        return s;
    }
  }

  Color _statutColor(String s) {
    switch (s) {
      case 'valide':
        return KColors.successContent;
      case 'rejete':
        return KColors.error;
      default:
        return KColors.baseContentMid;
    }
  }
}

// ── Historique ─────────────────────────────────────────────────────────────────

class _HistoriqueCard extends StatelessWidget {
  final List<dynamic> historique;
  const _HistoriqueCard({required this.historique});

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KCardHeader(title: 'Historique des actions'),
          ...historique.take(5).map((h) {
            final item = h as Map<String, dynamic>;
            final action = item['action']?.toString() ?? '';
            final admin =
                item['admin']?.toString() ?? item['by']?.toString() ?? '?';
            final date = item['date']?.toString() ?? item['timestamp']?.toString() ?? '';
            final motif = item['motif']?.toString();

            return Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: KColors.border)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: KSpacing.xl, vertical: KSpacing.md),
                child: Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: KColors.infoLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.history,
                        color: KColors.infoContent, size: 16),
                  ),
                  const SizedBox(width: KSpacing.md),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(action,
                              style: KTextStyles.bodySm
                                  .copyWith(fontWeight: FontWeight.w600)),
                          Text('Par $admin',
                              style: KTextStyles.meta),
                          if (motif != null && motif.isNotEmpty)
                            Text(motif, style: KTextStyles.meta),
                        ]),
                  ),
                  Text(date.length > 10 ? date.substring(0, 10) : date,
                      style: KTextStyles.meta),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}
