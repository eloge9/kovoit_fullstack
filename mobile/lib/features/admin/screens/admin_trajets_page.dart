import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_badge.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/utils/formatters.dart';

final _adminTrajetsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, statut) async {
      try {
        final res = await DioClient.get(
          '/utilisateurs/admin/trajets/',
          queryParams: statut.isEmpty ? null : {'statut': statut},
        );
        final data = res.data;
        if (data is Map) return Map<String, dynamic>.from(data);
        return {'resultats': [], 'total': 0};
      } catch (_) {
        return {'resultats': [], 'total': 0};
      }
    });

const _filtres = [
  {'value': '', 'label': 'Tous'},
  {'value': 'ouvert', 'label': 'Ouverts'},
  {'value': 'en_cours', 'label': 'En cours'},
  {'value': 'termine', 'label': 'Terminés'},
  {'value': 'annule', 'label': 'Annulés'},
];

class AdminTrajetsPage extends ConsumerStatefulWidget {
  const AdminTrajetsPage({super.key});

  @override
  ConsumerState<AdminTrajetsPage> createState() => _AdminTrajetsPageState();
}

class _AdminTrajetsPageState extends ConsumerState<AdminTrajetsPage> {
  String _statut = '';

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(_adminTrajetsProvider(_statut));

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        title: Text(
          'Gestion des trajets',
          style: KTextStyles.bodySm.copyWith(
            fontWeight: FontWeight.w700,
            color: KColors.baseContent,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Filtres ────────────────────────────────────────────────────
          Container(
            color: KColors.base100,
            padding: const EdgeInsets.fromLTRB(
              KSpacing.pagePaddingH,
              0,
              KSpacing.pagePaddingH,
              KSpacing.md,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filtres.map((f) {
                  final selected = f['value'] == _statut;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f['label']!),
                      selected: selected,
                      onSelected: (_) => setState(() => _statut = f['value']!),
                      selectedColor: KColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: KColors.primary,
                      labelStyle: KTextStyles.caption.copyWith(
                        color: selected
                            ? KColors.primary
                            : KColors.baseContentMid,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: selected ? KColors.primary : KColors.border,
                      ),
                      backgroundColor: KColors.base200,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Liste ──────────────────────────────────────────────────────
          Expanded(
            child: dataAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: KColors.primary),
              ),
              error: (_, _) => KEmptyState(
                icon: Icons.error_outline,
                message: 'Impossible de charger les trajets',
                actionLabel: 'Réessayer',
                onAction: () => ref.refresh(_adminTrajetsProvider(_statut)),
              ),
              data: (data) {
                final list = (data['resultats'] as List? ?? [])
                    .cast<Map<String, dynamic>>();
                final total = data['total'] as int? ?? list.length;

                if (list.isEmpty) {
                  return const KEmptyState(
                    emoji: '🚗',
                    message: 'Aucun trajet trouvé.',
                  );
                }

                return RefreshIndicator(
                  color: KColors.primary,
                  onRefresh: () async =>
                      ref.refresh(_adminTrajetsProvider(_statut)),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(KSpacing.pagePaddingH),
                    itemCount: list.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: KSpacing.md),
                          child: Text(
                            '$total trajet${total > 1 ? 's' : ''}',
                            style: KTextStyles.label,
                          ),
                        );
                      }
                      final t = list[i - 1];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: KSpacing.md),
                        child: _TrajetAdminCard(
                          t: t,
                          onAnnuler: () => _annuler(
                            context,
                            t['id'] as int,
                            '${t['depart']} → ${t['destination']}',
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _annuler(BuildContext context, int id, String label) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler ce trajet ?'),
        content: Text('$label\n\nCette action notifiera les passagers.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Oui, annuler',
              style: TextStyle(color: KColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    try {
      await DioClient.post('/utilisateurs/admin/trajets/$id/annuler/');
      ref.invalidate(_adminTrajetsProvider(_statut));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trajet annulé.'),
            backgroundColor: KColors.success,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'annulation'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }
}

class _TrajetAdminCard extends StatelessWidget {
  final Map<String, dynamic> t;
  final VoidCallback onAnnuler;
  const _TrajetAdminCard({required this.t, required this.onAnnuler});

  @override
  Widget build(BuildContext context) {
    final statut = t['statut'] as String? ?? '';
    final dateStr = t['date_depart'] as String? ?? '';
    DateTime? date;
    try {
      date = DateTime.parse(dateStr);
    } catch (_) {}

    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${t['depart']} → ${t['destination']}',
                        style: KTextStyles.bodySm.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (date != null)
                        Text(
                          Formatters.dateTime(date),
                          style: KTextStyles.meta,
                        ),
                    ],
                  ),
                ),
                KBadge.fromStatut(statut),
              ],
            ),
            const SizedBox(height: KSpacing.md),
            Wrap(
              spacing: KSpacing.xl,
              children: [
                _InfoChip(
                  icon: Icons.person_outline,
                  label: t['conducteur']?.toString() ?? '?',
                ),
                _InfoChip(
                  icon: Icons.directions_car_outlined,
                  label: t['vehicule']?.toString() ?? '—',
                ),
                _InfoChip(
                  icon: Icons.payments_outlined,
                  label:
                      '${(t['prix_par_place'] as num?)?.toStringAsFixed(0) ?? '?'} FCFA',
                ),
                _InfoChip(
                  icon: Icons.people_outline,
                  label: '${t['places_disponibles'] ?? '?'} places',
                ),
                _InfoChip(
                  icon: Icons.bookmark_outline,
                  label: '${t['nb_reservations'] ?? 0} rés.',
                ),
              ],
            ),
            if (statut != 'annule' && statut != 'termine') ...[
              const SizedBox(height: KSpacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onAnnuler,
                  icon: const Icon(
                    Icons.cancel_outlined,
                    size: 16,
                    color: KColors.error,
                  ),
                  label: const Text(
                    'Annuler',
                    style: TextStyle(color: KColors.error),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: KColors.baseContentMid),
        const SizedBox(width: 4),
        Text(label, style: KTextStyles.meta),
      ],
    );
  }
}
