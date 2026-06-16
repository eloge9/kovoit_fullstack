import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../repositories/messagerie_repository.dart';
import '../models/message_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/k_avatar.dart';
import '../../../core/widgets/k_empty_state.dart';

final _conversationsProvider = FutureProvider<List<ConversationModel>>((
  ref,
) async {
  return MessagerieRepository().getConversations();
});

class MessageriePage extends ConsumerWidget {
  const MessageriePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(_conversationsProvider);
    final user = ref.watch(currentUserProvider);
    final prefix = user?.role == 'conducteur' ? '/conducteur' : '/passager';

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        title: Row(
          children: [
            Image.asset('assets/logos/logo1.png', width: 22, height: 22),
            const SizedBox(width: 8),
            Text(
              'Messages',
              style: KTextStyles.bodySm.copyWith(
                fontWeight: FontWeight.w700,
                color: KColors.baseContent,
              ),
            ),
          ],
        ),
      ),
      body: conversationsAsync.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(KSpacing.pagePaddingH),
          itemCount: 5,
          itemBuilder: (_, _) => _ConvSkeleton(),
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
                onPressed: () => ref.invalidate(_conversationsProvider),
                child: Text(
                  'Réessayer',
                  style: KTextStyles.bodySm.copyWith(color: KColors.primary),
                ),
              ),
            ],
          ),
        ),
        data: (conversations) {
          if (conversations.isEmpty) {
            return const KEmptyState(
              emoji: '💬',
              message: 'Aucune conversation\nRéservez un trajet pour discuter',
            );
          }
          return RefreshIndicator(
            color: KColors.primary,
            onRefresh: () async => ref.invalidate(_conversationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: KSpacing.lg),
              itemCount: conversations.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: KColors.border, height: 0, indent: 72),
              itemBuilder: (context, i) {
                final conv = conversations[i];
                return _ConvTile(
                  conv: conv,
                  onTap: () => context.push(
                    '$prefix/messages/${conv.convId}'
                    '?name=${Uri.encodeComponent(conv.userName)}'
                    '&userId=${conv.userId}',
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

class _ConvTile extends StatelessWidget {
  final ConversationModel conv;
  final VoidCallback onTap;

  const _ConvTile({required this.conv, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasUnread = conv.unreadCount > 0;
    return Material(
      color: KColors.base100,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KSpacing.pagePaddingH,
            vertical: KSpacing.md,
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  KAvatar(
                    name: conv.userName,
                    photoUrl: conv.userPhoto,
                    size: 44,
                  ),
                  if (hasUnread)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: KColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          conv.unreadCount.toString(),
                          style: KTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
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
                            conv.userName,
                            style: KTextStyles.bodySm.copyWith(
                              fontWeight: hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: KColors.baseContent,
                            ),
                          ),
                        ),
                        if (conv.lastMessageTime != null)
                          Text(
                            Formatters.relativeTime(conv.lastMessageTime!),
                            style: KTextStyles.caption.copyWith(
                              color: hasUnread
                                  ? KColors.primary
                                  : KColors.baseContentMid,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      conv.lastMessage ?? 'Démarrez la conversation',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KTextStyles.caption.copyWith(
                        color: hasUnread
                            ? KColors.baseContent
                            : KColors.baseContentMid,
                        fontWeight: hasUnread
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConvSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.pagePaddingH,
        vertical: KSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: KColors.base300,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: KSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: 120,
                  color: KColors.base300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  color: KColors.base300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
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
