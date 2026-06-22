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
import '../../../core/widgets/k_empty_state.dart';

final _conducteursProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final res = await DioClient.get('/verification/admin/drivers/');
  final data = res.data;
  if (data is List) return data;
  if (data is Map && data['results'] is List) return data['results'] as List;
  return [];
});

class AdminConducteursPage extends ConsumerStatefulWidget {
  const AdminConducteursPage({super.key});

  @override
  ConsumerState<AdminConducteursPage> createState() =>
      _AdminConducteursPageState();
}

class _AdminConducteursPageState extends ConsumerState<AdminConducteursPage> {
  String _filter = 'tous';

  List<dynamic> _filtered(List<dynamic> all) {
    if (_filter == 'tous') return all;
    return all.where((c) {
      final m = c as Map<String, dynamic>;
      final statut = m['driver_status']?.toString() ??
          m['statut_validation']?.toString() ??
          '';
      // Accepter les deux formats (backend Django et backend vérification)
      if (_filter == 'en_attente') {
        return statut == 'en_attente' ||
            statut == 'PENDING_ADMIN_REVIEW' ||
            statut == 'AI_APPROVED';
      }
      if (_filter == 'valide') {
        return statut == 'valide' || statut == 'ACTIVE';
      }
      if (_filter == 'rejete') {
        return statut == 'rejete' ||
            statut == 'REJECTED' ||
            statut == 'SUSPENDED' ||
            statut == 'BLOCKED';
      }
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final conducteursAsync = ref.watch(_conducteursProvider);

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        title: Text(
          'Conducteurs',
          style: KTextStyles.bodySm.copyWith(
            fontWeight: FontWeight.w700,
            color: KColors.baseContent,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Tous',
                  selected: _filter == 'tous',
                  onTap: () => setState(() => _filter = 'tous'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'En attente',
                  selected: _filter == 'en_attente',
                  onTap: () => setState(() => _filter = 'en_attente'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Validés',
                  selected: _filter == 'valide',
                  onTap: () => setState(() => _filter = 'valide'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Rejetés / Suspendus',
                  selected: _filter == 'rejete',
                  onTap: () => setState(() => _filter = 'rejete'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: conducteursAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: KColors.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: KColors.baseContentLow),
              const SizedBox(height: 8),
              Text(e.toString(),
                  style: KTextStyles.caption, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              KButton(
                label: 'Réessayer',
                variant: KButtonVariant.outline,
                size: KButtonSize.sm,
                onPressed: () => ref.invalidate(_conducteursProvider),
              ),
            ],
          ),
        ),
        data: (conducteurs) {
          final filtered = _filtered(conducteurs);

          if (filtered.isEmpty) {
            return KEmptyState(
              emoji: '🚗',
              message: _filter == 'tous'
                  ? 'Aucun conducteur'
                  : 'Aucun conducteur dans cette catégorie',
            );
          }

          return RefreshIndicator(
            color: KColors.primary,
            onRefresh: () async => ref.invalidate(_conducteursProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: KSpacing.lg),
              itemCount: filtered.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: KColors.border, height: 0, indent: 68),
              itemBuilder: (context, i) {
                final c = filtered[i] as Map<String, dynamic>;
                return _ConducteurListItem(
                  conducteur: c,
                  onTap: () {
                    final id = c['id']?.toString() ??
                        (c['user'] as Map?)?['id']?.toString() ??
                        '';
                    if (id.isNotEmpty) {
                      context.push('/admin/conducteur/$id');
                    }
                  },
                  onApprove: () => _approuver(
                      c['id']?.toString() ??
                          (c['user'] as Map?)?['id']?.toString() ??
                          ''),
                  onReject: () => _rejeter(
                      c['id']?.toString() ??
                          (c['user'] as Map?)?['id']?.toString() ??
                          ''),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _approuver(String id) async {
    if (id.isEmpty) return;
    try {
      await DioClient.post('/verification/admin/drivers/$id/approve/');
      ref.invalidate(_conducteursProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Conducteur approuvé'),
          backgroundColor: KColors.successContent,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: KColors.error,
        ));
      }
    }
  }

  Future<void> _rejeter(String id) async {
    if (id.isEmpty) return;
    final ctrl = TextEditingController();
    final motif = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Motif de rejet'),
        content: TextField(
          controller: ctrl,
          decoration:
              const InputDecoration(hintText: 'Saisissez le motif...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (motif == null || motif.isEmpty || !mounted) return;
    try {
      await DioClient.post(
        '/verification/admin/drivers/$id/reject/',
        data: {'motif': motif},
      );
      ref.invalidate(_conducteursProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Conducteur rejeté'),
          backgroundColor: KColors.error,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: KColors.error,
        ));
      }
    }
  }
}

// ── Item de la liste ───────────────────────────────────────────────────────────

class _ConducteurListItem extends StatelessWidget {
  final Map<String, dynamic> conducteur;
  final VoidCallback onTap;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ConducteurListItem({
    required this.conducteur,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final c = conducteur;
    final user = c['user'] as Map<String, dynamic>? ?? c;
    final username =
        user['username']?.toString() ?? c['username']?.toString() ?? '?';
    final email = user['email']?.toString() ?? c['email']?.toString() ?? '';
    final photo =
        user['photo_profil']?.toString() ?? user['photo_profile']?.toString();
    final statut = c['driver_status']?.toString() ??
        c['statut_validation']?.toString() ??
        'non_soumis';
    final note = (c['note_moyenne'] as num?)?.toDouble() ?? 0.0;
    final nbTrajets = c['nombre_trajets']?.toString() ?? '0';

    final isPending = statut == 'en_attente' ||
        statut == 'PENDING_ADMIN_REVIEW' ||
        statut == 'AI_APPROVED';

    return InkWell(
      onTap: onTap,
      child: Container(
        color: KColors.base100,
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.pagePaddingH,
          vertical: KSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                KAvatar(name: username, photoUrl: photo, size: 44),
                const SizedBox(width: KSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              username,
                              style: KTextStyles.bodySm
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          KBadge.fromStatut(statut),
                        ],
                      ),
                      if (email.isNotEmpty)
                        Text(email, style: KTextStyles.meta),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: KColors.warning, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${note.toStringAsFixed(1)} • $nbTrajets trajets',
                            style: KTextStyles.caption,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: KColors.baseContentLow, size: 20),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: KSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: KButton(
                      label: 'Approuver',
                      size: KButtonSize.sm,
                      variant: KButtonVariant.success,
                      icon: Icons.verified_user_rounded,
                      onPressed: onApprove,
                    ),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  Expanded(
                    child: KButton(
                      label: 'Rejeter',
                      size: KButtonSize.sm,
                      variant: KButtonVariant.error,
                      icon: Icons.cancel_rounded,
                      onPressed: onReject,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Chip filtre ────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? KColors.primary : KColors.base100,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? KColors.primary : KColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : KColors.baseContentMid,
          ),
        ),
      ),
    );
  }
}
