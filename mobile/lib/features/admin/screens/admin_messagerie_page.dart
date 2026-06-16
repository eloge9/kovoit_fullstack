import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_avatar.dart';
import '../../../core/widgets/k_empty_state.dart';

final _adminConversationsProvider = FutureProvider<List<dynamic>>((ref) async {
  final res = await DioClient.get('/messagerie/conversations/');
  final data = res.data;
  if (data is List) return data;
  if (data is Map && data['results'] is List) return data['results'] as List;
  return [];
});

class AdminMessageriePage extends ConsumerWidget {
  const AdminMessageriePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convsAsync = ref.watch(_adminConversationsProvider);

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        title: Text('Messagerie', style: KTextStyles.bodySm.copyWith(
          fontWeight: FontWeight.w700, color: KColors.baseContent,
        )),
      ),
      body: convsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: KColors.primary)),
        error: (e, _) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 48, color: KColors.baseContentLow),
            const SizedBox(height: 8),
            Text(e.toString(), style: KTextStyles.caption),
            TextButton(
              onPressed: () => ref.refresh(_adminConversationsProvider),
              child: Text('Réessayer', style: KTextStyles.bodySm.copyWith(color: KColors.primary)),
            ),
          ]),
        ),
        data: (convs) {
          if (convs.isEmpty) {
            return const KEmptyState(emoji: '💬', message: 'Aucune conversation');
          }

          return RefreshIndicator(
            color: KColors.primary,
            onRefresh: () async => ref.refresh(_adminConversationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: KSpacing.lg),
              itemCount: convs.length,
              separatorBuilder: (_, _) => const Divider(color: KColors.border, height: 0, indent: 68),
              itemBuilder: (context, i) {
                final conv = convs[i] as Map<String, dynamic>;
                final convId = conv['id']?.toString() ?? '';
                final participants = conv['participants'] as List<dynamic>? ?? [];
                final dernierMsg = conv['dernier_message']?['contenu']?.toString()
                    ?? conv['last_message']?.toString()
                    ?? 'Aucun message';
                final nonLus = (conv['non_lus'] as num?)?.toInt() ?? 0;
                final date = conv['updated_at']?.toString().substring(0, 10)
                    ?? conv['date']?.toString()
                    ?? '';

                final noms = participants
                    .map((p) => (p as Map<String, dynamic>)['username']?.toString() ?? '?')
                    .join(' & ');

                return InkWell(
                  onTap: () {
                    if (convId.isNotEmpty && participants.isNotEmpty) {
                      final otherId = (participants.first as Map<String, dynamic>)['id']?.toString() ?? '';
                      context.go('/admin/messagerie/$otherId?name=$noms');
                    }
                  },
                  child: Container(
                    color: KColors.base100,
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.pagePaddingH, vertical: KSpacing.md,
                    ),
                    child: Row(children: [
                      KAvatar(name: noms, size: 44),
                      const SizedBox(width: KSpacing.md),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(child: Text(noms,
                              style: KTextStyles.bodySm.copyWith(
                                fontWeight: FontWeight.w600,
                                color: KColors.baseContent,
                              ),
                              overflow: TextOverflow.ellipsis,
                            )),
                            if (date.isNotEmpty)
                              Text(date, style: KTextStyles.meta),
                          ]),
                          const SizedBox(height: 2),
                          Row(children: [
                            Expanded(child: Text(
                              dernierMsg,
                              style: KTextStyles.caption.copyWith(
                                fontWeight: nonLus > 0 ? FontWeight.w600 : FontWeight.w400,
                                color: nonLus > 0 ? KColors.baseContent : KColors.baseContentMid,
                              ),
                              overflow: TextOverflow.ellipsis,
                            )),
                            if (nonLus > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: KColors.primary,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text('$nonLus',
                                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                              ),
                          ]),
                        ],
                      )),
                    ]),
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
