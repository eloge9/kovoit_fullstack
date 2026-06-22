import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_badge.dart';
import '../../../core/widgets/k_empty_state.dart';

final _adminReservationsProvider = FutureProvider<List<dynamic>>((ref) async {
  try {
    final res = await DioClient.get('/reservations/admin/');
    final data = res.data;
    debugPrint('[AdminReservations] raw type: ${data.runtimeType}');
    if (data is List) {
      debugPrint('[AdminReservations] ${data.length} réservations');
      return data;
    }
    if (data is Map && data['results'] is List) return data['results'] as List;
    return [];
  } catch (e) {
    debugPrint('[AdminReservations] /reservations/admin/ error: $e');
    try {
      final res = await DioClient.get('/reservations/mes_reservations/');
      final data = res.data;
      if (data is List) return data;
      if (data is Map && data['results'] is List) return data['results'] as List;
    } catch (e2) {
      debugPrint('[AdminReservations] fallback error: $e2');
    }
    return [];
  }
});

class AdminReservationsPage extends ConsumerStatefulWidget {
  const AdminReservationsPage({super.key});

  @override
  ConsumerState<AdminReservationsPage> createState() =>
      _AdminReservationsPageState();
}

class _AdminReservationsPageState extends ConsumerState<AdminReservationsPage> {
  String _filter = 'tous';

  @override
  Widget build(BuildContext context) {
    final reservationsAsync = ref.watch(_adminReservationsProvider);

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        title: Text(
          'Réservations',
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
                for (final f in [
                  ('tous', 'Toutes'),
                  ('en_attente', 'En attente'),
                  ('confirmee', 'Confirmées'),
                  ('annulee', 'Annulées'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: f.$2,
                      selected: _filter == f.$1,
                      onTap: () => setState(() => _filter = f.$1),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: reservationsAsync.when(
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
                onPressed: () => ref.refresh(_adminReservationsProvider),
                child: Text(
                  'Réessayer',
                  style: KTextStyles.bodySm.copyWith(color: KColors.primary),
                ),
              ),
            ],
          ),
        ),
        data: (reservations) {
          final filtered = _filter == 'tous'
              ? reservations
              : reservations.where((r) {
                  final statut =
                      (r as Map<String, dynamic>)['statut']?.toString() ?? '';
                  return statut == _filter;
                }).toList();

          if (filtered.isEmpty) {
            return const KEmptyState(
              emoji: '🎫',
              message: 'Aucune réservation trouvée',
            );
          }

          return RefreshIndicator(
            color: KColors.primary,
            onRefresh: () async => ref.refresh(_adminReservationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: KSpacing.lg),
              itemCount: filtered.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: KColors.border, height: 0),
              itemBuilder: (context, i) {
                final r = filtered[i] as Map<String, dynamic>;
                final statut = r['statut']?.toString() ?? 'en_attente';
                final passager =
                    r['passager']?['username']?.toString() ??
                    r['passager_nom']?.toString() ??
                    '?';
                final trajet =
                    r['trajet']?['depart']?.toString() ??
                    r['depart']?.toString() ??
                    '?';
                final destination =
                    r['trajet']?['destination']?.toString() ??
                    r['destination']?.toString() ??
                    '?';
                final montant =
                    r['montant']?.toString() ?? r['prix']?.toString() ?? '-';
                final date =
                    r['created_at']?.toString().substring(0, 10) ??
                    r['date']?.toString() ??
                    '';

                return Container(
                  color: KColors.base100,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.pagePaddingH,
                      vertical: KSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: KColors.statusBgColor(statut),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.confirmation_number_outlined,
                            color: KColors.statusColor(statut),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: KSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '$trajet → $destination',
                                      style: KTextStyles.bodySm.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  KBadge.fromStatut(statut),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Passager : $passager',
                                style: KTextStyles.caption,
                              ),
                              if (montant != '-')
                                Text(
                                  '$montant FCFA • $date',
                                  style: KTextStyles.meta,
                                ),
                            ],
                          ),
                        ),
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
