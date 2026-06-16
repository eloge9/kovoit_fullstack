import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../providers/notifications_provider.dart';
import '../models/notification_model.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);
    final notifications = state.notifications;

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        title: Text(
          'Notifications',
          style: KTextStyles.bodySm.copyWith(
            fontWeight: FontWeight.w700,
            color: KColors.baseContent,
          ),
        ),
        actions: [
          if (state.nonLus > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).marquerToutLu(),
              child: Text(
                'Tout lire',
                style: KTextStyles.bodySm.copyWith(color: KColors.primary),
              ),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? const KEmptyState(
              emoji: '🔔',
              message: 'Aucune notification pour le moment',
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: KSpacing.lg),
              itemCount: notifications.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: KColors.border, height: 0, indent: 68),
              itemBuilder: (context, i) {
                final notif = notifications[i];
                return _NotifTile(
                  notif: notif,
                  index: i,
                  onTap: () => ref
                      .read(notificationsProvider.notifier)
                      .marquerCommeLu(i),
                  onDismiss: () => ref
                      .read(notificationsProvider.notifier)
                      .supprimerNotification(i),
                );
              },
            ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final NotificationModel notif;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotifTile({
    required this.notif,
    required this.index,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('notif_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: KSpacing.xl),
        color: KColors.errorLight,
        child: const Icon(Icons.delete_outline, color: KColors.error),
      ),
      onDismissed: (_) => onDismiss(),
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: notif.isRead
              ? KColors.base100
              : KColors.primary.withValues(alpha: 0.04),
          padding: const EdgeInsets.symmetric(
            horizontal: KSpacing.pagePaddingH,
            vertical: KSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: notif.couleur.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(notif.icone, color: notif.couleur, size: 20),
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
                            notif.titre,
                            style: KTextStyles.bodySm.copyWith(
                              fontWeight: notif.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              color: KColors.baseContent,
                            ),
                          ),
                        ),
                        Text(
                          _heureRelative(notif.timestamp),
                          style: KTextStyles.meta,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notif.message,
                      style: KTextStyles.caption.copyWith(
                        color: notif.isRead
                            ? KColors.baseContentMid
                            : KColors.baseContent,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!notif.isRead) ...[
                const SizedBox(width: KSpacing.sm),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: KColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _heureRelative(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return '${date.day}/${date.month}/${date.year}';
  }
}
