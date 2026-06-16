import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_badge.dart';
import '../../../core/widgets/k_avatar.dart';
import '../../../core/widgets/k_empty_state.dart';

final _plaintesProvider = FutureProvider<List<dynamic>>((ref) async {
  try {
    final res = await DioClient.get('/plaintes/');
    final data = res.data;
    if (data is List) return data;
    if (data is Map && data['results'] is List) return data['results'] as List;
    return [];
  } catch (_) {
    try {
      final res = await DioClient.get('/evaluations/signaler/');
      final data = res.data;
      if (data is List) return data;
      if (data is Map && data['results'] is List) {
        return data['results'] as List;
      }
      return [];
    } catch (_) {
      return [];
    }
  }
});

class AdminPlaintesPage extends ConsumerStatefulWidget {
  const AdminPlaintesPage({super.key});

  @override
  ConsumerState<AdminPlaintesPage> createState() => _AdminPlaintesPageState();
}

class _AdminPlaintesPageState extends ConsumerState<AdminPlaintesPage> {
  String _filter = 'tous';

  @override
  Widget build(BuildContext context) {
    final plaintesAsync = ref.watch(_plaintesProvider);

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        title: Text(
          'Plaintes',
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
                for (final (val, label) in [
                  ('tous', 'Toutes'),
                  ('en_attente', 'En attente'),
                  ('resolue', 'Résolues'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: label,
                      selected: _filter == val,
                      onTap: () => setState(() => _filter = val),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: plaintesAsync.when(
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
                onPressed: () => ref.refresh(_plaintesProvider),
                child: Text(
                  'Réessayer',
                  style: KTextStyles.bodySm.copyWith(color: KColors.primary),
                ),
              ),
            ],
          ),
        ),
        data: (plaintes) {
          if (plaintes.isEmpty) {
            return const KEmptyState(
              emoji: '🏳️',
              message: 'Aucune plainte enregistrée',
            );
          }

          final filtered = _filter == 'tous'
              ? plaintes
              : plaintes.where((p) {
                  final statut =
                      (p as Map<String, dynamic>)['statut']?.toString() ?? '';
                  return statut == _filter;
                }).toList();

          if (filtered.isEmpty) {
            return KEmptyState(
              emoji: '✅',
              message: 'Aucune plainte "$_filter"',
            );
          }

          return RefreshIndicator(
            color: KColors.primary,
            onRefresh: () async => ref.refresh(_plaintesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: KSpacing.lg),
              itemCount: filtered.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: KColors.border, height: 0, indent: 68),
              itemBuilder: (context, i) {
                final p = filtered[i] as Map<String, dynamic>;
                final auteur =
                    p['auteur']?['username']?.toString() ??
                    p['signaleur']?.toString() ??
                    '?';
                final type =
                    p['type']?.toString() ??
                    p['signal_type']?.toString() ??
                    'autre';
                final description =
                    p['description']?.toString() ??
                    p['message']?.toString() ??
                    '';
                final statut = p['statut']?.toString() ?? 'en_attente';
                final date = p['created_at']?.toString().substring(0, 10) ?? '';

                return Container(
                  color: KColors.base100,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.pagePaddingH,
                      vertical: KSpacing.md,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        KAvatar(name: auteur, size: 40),
                        const SizedBox(width: KSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      auteur,
                                      style: KTextStyles.bodySm.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  KBadge.fromStatut(statut),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _labelType(type),
                                style: KTextStyles.caption.copyWith(
                                  color: KColors.error,
                                ),
                              ),
                              if (description.isNotEmpty)
                                Text(
                                  description,
                                  style: KTextStyles.caption,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (date.isNotEmpty)
                                Text(date, style: KTextStyles.meta),
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

  String _labelType(String type) {
    switch (type) {
      case 'comportement':
        return '⚠️ Comportement inapproprié';
      case 'fraude':
        return '🚨 Fraude';
      case 'securite':
        return '🔒 Problème de sécurité';
      case 'retard':
        return '⏱️ Retard';
      case 'autre':
        return '📋 Autre';
      default:
        return type;
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
