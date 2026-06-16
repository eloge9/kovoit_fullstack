import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_avatar.dart';
import '../../../core/widgets/k_badge.dart';
import '../../../core/widgets/k_empty_state.dart';

final _utilisateursProvider = FutureProvider<List<dynamic>>((ref) async {
  final res = await DioClient.get('/utilisateurs/admin/utilisateurs/');
  final data = res.data;
  if (data is List) return data;
  if (data is Map && data['results'] is List) return data['results'] as List;
  return [];
});

class AdminUtilisateursPage extends ConsumerWidget {
  const AdminUtilisateursPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(_utilisateursProvider);

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        title: Text(
          'Utilisateurs',
          style: KTextStyles.bodySm.copyWith(
            fontWeight: FontWeight.w700,
            color: KColors.baseContent,
          ),
        ),
      ),
      body: usersAsync.when(
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
                onPressed: () => ref.refresh(_utilisateursProvider),
                child: Text(
                  'Réessayer',
                  style: KTextStyles.bodySm.copyWith(color: KColors.primary),
                ),
              ),
            ],
          ),
        ),
        data: (users) {
          if (users.isEmpty) {
            return const KEmptyState(
              emoji: '👥',
              message: 'Aucun utilisateur trouvé',
            );
          }
          return RefreshIndicator(
            color: KColors.primary,
            onRefresh: () async => ref.refresh(_utilisateursProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: KSpacing.lg),
              itemCount: users.length,
              itemBuilder: (context, i) {
                final u = users[i] as Map<String, dynamic>;
                final username =
                    u['username']?.toString() ?? u['email']?.toString() ?? '?';
                final email = u['email']?.toString() ?? '';
                final role = u['role']?.toString() ?? '';
                final actif = u['is_active'] as bool? ?? true;

                return Container(
                  color: KColors.base100,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: KSpacing.pagePaddingH,
                          vertical: KSpacing.md,
                        ),
                        child: Row(
                          children: [
                            KAvatar(name: username, size: 40),
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
                                      KBadge(
                                        label: actif ? 'Actif' : 'Inactif',
                                        color: actif
                                            ? KColors.success
                                            : KColors.baseContentMid,
                                      ),
                                    ],
                                  ),
                                  Text(email, style: KTextStyles.caption),
                                  if (role.isNotEmpty)
                                    Text(
                                      role,
                                      style: KTextStyles.caption.copyWith(
                                        color: KColors.primary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(
                        color: KColors.border,
                        height: 0,
                        indent: 68,
                      ),
                    ],
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
