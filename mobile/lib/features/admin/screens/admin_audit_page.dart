import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/utils/formatters.dart';

final _auditProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await DioClient.get('/utilisateurs/admin/audit/');
    final data = res.data;
    debugPrint('[AdminAudit] raw type: ${data.runtimeType}');
    if (data is Map && data['resultats'] is List) {
      final list = data['resultats'] as List;
      debugPrint('[AdminAudit] ${list.length} entrées audit');
      return List<Map<String, dynamic>>.from(list);
    }
    debugPrint('[AdminAudit] réponse inattendue: $data');
    return [];
  } catch (e) {
    debugPrint('[AdminAudit] error: $e');
    return [];
  }
});

const _actionColors = <String, Color>{
  'user_ban': KColors.error,
  'user_unban': KColors.success,
  'driver_validate': KColors.success,
  'driver_reject': KColors.error,
  'trip_cancel': KColors.warning,
  'trip_delete': KColors.error,
  'user_role': KColors.info,
};

class AdminAuditPage extends ConsumerWidget {
  const AdminAuditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_auditProvider);

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        title: Text(
          'Journal d\'audit',
          style: KTextStyles.bodySm.copyWith(
            fontWeight: FontWeight.w700,
            color: KColors.baseContent,
          ),
        ),
      ),
      body: dataAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: KColors.primary),
        ),
        error: (_, _) => KEmptyState(
          icon: Icons.error_outline,
          message: 'Impossible de charger le journal',
          actionLabel: 'Réessayer',
          onAction: () => ref.refresh(_auditProvider),
        ),
        data: (logs) {
          if (logs.isEmpty) {
            return const KEmptyState(
              emoji: '📋',
              message: 'Aucune entrée dans le journal d\'audit.',
            );
          }

          return RefreshIndicator(
            color: KColors.primary,
            onRefresh: () async => ref.refresh(_auditProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(KSpacing.pagePaddingH),
              itemCount: logs.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: KSpacing.md),
                    child: Text(
                      '${logs.length} entrée${logs.length > 1 ? 's' : ''}',
                      style: KTextStyles.label,
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: KSpacing.md),
                  child: _AuditCard(log: logs[i - 1]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AuditCard extends StatelessWidget {
  final Map<String, dynamic> log;
  const _AuditCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final action = log['action'] as String? ?? '';
    final label = log['action_label'] as String? ?? action;
    final desc = log['description'] as String? ?? '';
    final admin = log['admin'] as String? ?? '?';
    final ip = log['ip'] as String? ?? '';
    final dateStr = log['date'] as String? ?? '';
    DateTime? date;
    try {
      date = DateTime.parse(dateStr);
    } catch (_) {}

    final color = _actionColors[action] ?? KColors.baseContentMid;

    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_actionIcon(action), color: color, size: 18),
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
                          label,
                          style: KTextStyles.bodySm.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (date != null)
                        Text(Formatters.date(date), style: KTextStyles.meta),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (desc.isNotEmpty)
                    Text(
                      desc,
                      style: KTextStyles.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 12,
                        color: KColors.baseContentMid,
                      ),
                      const SizedBox(width: 4),
                      Text(admin, style: KTextStyles.meta),
                      if (ip.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.router_outlined,
                          size: 12,
                          color: KColors.baseContentMid,
                        ),
                        const SizedBox(width: 4),
                        Text(ip, style: KTextStyles.meta),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'user_ban':
        return Icons.block_rounded;
      case 'user_unban':
        return Icons.check_circle_outline;
      case 'driver_validate':
        return Icons.verified_rounded;
      case 'driver_reject':
        return Icons.cancel_outlined;
      case 'trip_cancel':
        return Icons.directions_car_outlined;
      case 'trip_delete':
        return Icons.delete_outline;
      case 'user_role':
        return Icons.manage_accounts_outlined;
      default:
        return Icons.history_rounded;
    }
  }
}
