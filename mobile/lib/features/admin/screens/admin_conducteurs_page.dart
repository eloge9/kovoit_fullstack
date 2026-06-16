import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_avatar.dart';
import '../../../core/widgets/k_badge.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_empty_state.dart';

final _conducteursProvider = FutureProvider<List<dynamic>>((ref) async {
  final res = await DioClient.get('/utilisateurs/admin/conducteurs/');
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
                  label: 'Rejetés',
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
              const Icon(
                Icons.error_outline,
                size: 48,
                color: KColors.baseContentLow,
              ),
              const SizedBox(height: 8),
              Text(e.toString(), style: KTextStyles.caption),
              TextButton(
                onPressed: () => ref.refresh(_conducteursProvider),
                child: Text(
                  'Réessayer',
                  style: KTextStyles.bodySm.copyWith(color: KColors.primary),
                ),
              ),
            ],
          ),
        ),
        data: (conducteurs) {
          final filtered = _filter == 'tous'
              ? conducteurs
              : conducteurs.where((c) {
                  final statut =
                      (c as Map<String, dynamic>)['statut_validation']
                          ?.toString() ??
                      '';
                  return statut == _filter;
                }).toList();

          if (filtered.isEmpty) {
            return KEmptyState(
              emoji: '🚗',
              message: _filter == 'tous'
                  ? 'Aucun conducteur'
                  : 'Aucun conducteur $_filter',
            );
          }

          return RefreshIndicator(
            color: KColors.primary,
            onRefresh: () async => ref.refresh(_conducteursProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: KSpacing.lg),
              itemCount: filtered.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: KColors.border, height: 0, indent: 68),
              itemBuilder: (context, i) {
                final c = filtered[i] as Map<String, dynamic>;
                final username = c['username']?.toString() ?? '?';
                final statut =
                    c['statut_validation']?.toString() ?? 'non_soumis';
                final note = (c['note_moyenne'] as num?)?.toDouble() ?? 0.0;
                final nbTrajets = c['nombre_trajets']?.toString() ?? '0';

                return Container(
                  color: KColors.base100,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.pagePaddingH,
                      vertical: KSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            KAvatar(name: username, size: 44),
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
                                          style: KTextStyles.bodySm.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: KColors.baseContent,
                                          ),
                                        ),
                                      ),
                                      KBadge.fromStatut(statut),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: KColors.warning,
                                        size: 14,
                                      ),
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
                          ],
                        ),
                        if (statut == 'en_attente') ...[
                          const SizedBox(height: KSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: KButton(
                                  label: 'Valider',
                                  size: KButtonSize.sm,
                                  variant: KButtonVariant.success,
                                  onPressed: () =>
                                      _valider(c['id'].toString(), ref),
                                ),
                              ),
                              const SizedBox(width: KSpacing.sm),
                              Expanded(
                                child: KButton(
                                  label: 'Rejeter',
                                  size: KButtonSize.sm,
                                  variant: KButtonVariant.error,
                                  onPressed: () =>
                                      _rejeter(c['id'].toString(), ref),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _valider(String id, WidgetRef ref) async {
    try {
      await DioClient.post(
        '/verification/admin/valider/',
        data: {'conducteur_id': id},
      );
      ref.invalidate(_conducteursProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: KColors.error),
        );
      }
    }
  }

  Future<void> _rejeter(String id, WidgetRef ref) async {
    try {
      await DioClient.post(
        '/verification/admin/rejeter/',
        data: {'conducteur_id': id},
      );
      ref.invalidate(_conducteursProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: KColors.error),
        );
      }
    }
  }
}

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
