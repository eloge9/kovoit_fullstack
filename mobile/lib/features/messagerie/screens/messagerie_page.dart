import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../repositories/messagerie_repository.dart';
import '../models/message_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

final _conversationsProvider = FutureProvider<List<ConversationModel>>((ref) async {
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
      appBar: AppBar(title: const Text('Messages')),
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text(e.toString()),
              TextButton(
                onPressed: () => ref.refresh(_conversationsProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (conversations) {
          if (conversations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.message_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Aucune conversation', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, i) {
              final conv = conversations[i];
              return ListTile(
                leading: Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.primaryColor,
                      child: Text(
                        conv.userName.isNotEmpty
                            ? conv.userName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    if (conv.unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppTheme.errorColor,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            conv.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  conv.userName,
                  style: TextStyle(
                    fontWeight: conv.unreadCount > 0
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  conv.lastMessage ?? 'Pas de message',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: conv.unreadCount > 0
                        ? Colors.black87
                        : Colors.grey,
                  ),
                ),
                trailing: conv.lastMessageTime != null
                    ? Text(
                        Formatters.relativeTime(conv.lastMessageTime!),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      )
                    : null,
                onTap: () => context.push(
                  '$prefix/messages/${conv.userId}?name=${Uri.encodeComponent(conv.userName)}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
