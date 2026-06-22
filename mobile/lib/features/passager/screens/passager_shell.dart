import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_avatar.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';

class PassagerShell extends ConsumerStatefulWidget {
  final Widget child;
  const PassagerShell({super.key, required this.child});

  @override
  ConsumerState<PassagerShell> createState() => _PassagerShellState();
}

class _PassagerShellState extends ConsumerState<PassagerShell> {

  int _indexFromLocation(String location) {
    if (location.startsWith('/passager/trajets') ||
        location.startsWith('/passager/trajet/')) { return 1; }
    if (location.startsWith('/passager/reservation')) { return 2; }
    if (location.startsWith('/passager/messages')) { return 3; }
    return 0;
  }

  void _goToTab(BuildContext ctx, int index) {
    switch (index) {
      case 1: ctx.go('/passager/trajets'); break;
      case 2: ctx.go('/passager/reservations'); break;
      case 3: ctx.go('/passager/messages'); break;
      default: ctx.go('/passager'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _indexFromLocation(location);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: KColors.base200,
        appBar: _KPassagerAppBar(
          user: user,
          onNotificationsTap: () => context.push('/passager/notifications'),
          onAvatarTap: () => _showAccountMenu(context, user),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          child: KeyedSubtree(
            key: ValueKey(currentIndex),
            child: widget.child,
          ),
        ),
        floatingActionButton: _KCentralFab(onTap: () => context.go('/passager/trajets')),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: _KBottomAppBar(
          currentIndex: currentIndex,
          onTap: (i) => _goToTab(context, i),
        ),
      ),
    );
  }

  void _showAccountMenu(BuildContext shellCtx, UserModel? user) {
    showModalBottomSheet(
      context: shellCtx,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _AccountMenuSheet(
        user: user,
        onNavigate: (route) {
          Navigator.of(sheetCtx).pop();
          shellCtx.push(route);
        },
        onSwitchTab: (index) {
          Navigator.of(sheetCtx).pop();
          _goToTab(shellCtx, index);
        },
        onLogout: () {
          Navigator.of(sheetCtx).pop();
          ref.read(authProvider.notifier).deconnexion().then((_) {
            if (shellCtx.mounted) { shellCtx.go('/login'); }
          });
        },
      ),
    );
  }
}

// ── AppBar persistante ────────────────────────────────────────────────────────

class _KPassagerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final UserModel? user;
  final VoidCallback onNotificationsTap;
  final VoidCallback onAvatarTap;

  const _KPassagerAppBar({
    required this.user,
    required this.onNotificationsTap,
    required this.onAvatarTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: KColors.base100,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      shape: const Border(bottom: BorderSide(color: KColors.border, width: 0.5)),
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              'assets/logos/logo1.png',
              width: 28,
              height: 28,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'KoVoit',
            style: KTextStyles.h3.copyWith(
              color: KColors.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
      actions: [
        // Icône notifications
        IconButton(
          icon: const Icon(
            Icons.notifications_outlined,
            color: KColors.baseContentMid,
            size: 24,
          ),
          onPressed: onNotificationsTap,
          tooltip: 'Notifications',
        ),
        const SizedBox(width: 2),
        // Avatar utilisateur
        GestureDetector(
          onTap: onAvatarTap,
          child: Container(
            margin: const EdgeInsets.only(right: 16, left: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: KColors.primary.withValues(alpha: 0.35),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: KColors.primary.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: KAvatar(
              photoUrl: user?.photoProfile,
              name: user?.displayName ?? user?.username,
              size: 34,
            ),
          ),
        ),
      ],
    );
  }
}

// ── FAB central ───────────────────────────────────────────────────────────────

class _KCentralFab extends StatelessWidget {
  final VoidCallback onTap;
  const _KCentralFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onTap,
      backgroundColor: KColors.primary,
      elevation: 6,
      focusElevation: 8,
      hoverElevation: 8,
      shape: const CircleBorder(),
      tooltip: 'Trouver un trajet',
      child: const Icon(
        Icons.directions_car_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }
}

// ── Bottom Navigation ─────────────────────────────────────────────────────────

class _KBottomAppBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const _KBottomAppBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: KColors.base100,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      padding: EdgeInsets.zero,
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            index: 0,
            current: currentIndex,
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Accueil',
            onTap: onTap,
          ),
          _NavItem(
            index: 1,
            current: currentIndex,
            icon: Icons.search_outlined,
            activeIcon: Icons.search_rounded,
            label: 'Rechercher',
            onTap: onTap,
          ),
          const SizedBox(width: 72), // Espace pour le FAB
          _NavItem(
            index: 2,
            current: currentIndex,
            icon: Icons.calendar_today_outlined,
            activeIcon: Icons.calendar_today_rounded,
            label: 'Réservations',
            onTap: onTap,
          ),
          _NavItem(
            index: 3,
            current: currentIndex,
            icon: Icons.chat_bubble_outline_rounded,
            activeIcon: Icons.chat_bubble_rounded,
            label: 'Messages',
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final int current;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final void Function(int) onTap;

  const _NavItem({
    required this.index,
    required this.current,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = index == current;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? KColors.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Icon(
                  selected ? activeIcon : icon,
                  size: 22,
                  color: selected ? KColors.primary : KColors.baseContentMid,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? KColors.primary : KColors.baseContentMid,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Menu compte (BottomSheet) ─────────────────────────────────────────────────

class _AccountMenuSheet extends StatelessWidget {
  final UserModel? user;
  final void Function(String) onNavigate;
  final void Function(int) onSwitchTab;
  final VoidCallback onLogout;

  const _AccountMenuSheet({
    required this.user,
    required this.onNavigate,
    required this.onSwitchTab,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final canBecomeDriver = !(user?.peutConduire ?? false);

    return Container(
      decoration: const BoxDecoration(
        color: KColors.base100,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: KColors.base300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // En-tête utilisateur
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(
              children: [
                KAvatar(
                  photoUrl: user?.photoProfile,
                  name: user?.displayName ?? user?.username,
                  size: 52,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'Mon compte',
                        style: KTextStyles.h3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        style: KTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((user?.note ?? 0) > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: Color(0xFFFFB800),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              user!.note.toStringAsFixed(1),
                              style: KTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: KColors.baseContent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: KColors.border, height: 1),
          const SizedBox(height: 6),

          // Items de navigation
          _MenuItem(
            icon: Icons.person_outline_rounded,
            label: 'Mon profil',
            onTap: () => onNavigate('/passager/profile'),
          ),
          _MenuItem(
            icon: Icons.settings_outlined,
            label: 'Paramètres',
            onTap: () => onNavigate('/passager/profile/edit'),
          ),
          _MenuItem(
            icon: Icons.history_rounded,
            label: 'Historique des réservations',
            onTap: () => onSwitchTab(2),
          ),
          _MenuItem(
            icon: Icons.eco_outlined,
            label: 'Économie réalisée',
            onTap: () => onNavigate('/passager/economie'),
          ),
          _MenuItem(
            icon: Icons.star_outline_rounded,
            label: 'Mes évaluations',
            onTap: () => onNavigate('/passager/evaluations'),
          ),
          if (canBecomeDriver)
            _MenuItem(
              icon: Icons.drive_eta_outlined,
              label: 'Devenir conducteur',
              onTap: () => onNavigate('/passager/devenir-conducteur'),
              highlight: true,
            ),

          const SizedBox(height: 6),
          const Divider(color: KColors.border, height: 1),
          const SizedBox(height: 4),

          _MenuItem(
            icon: Icons.logout_rounded,
            label: 'Déconnexion',
            onTap: onLogout,
            isDestructive: true,
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool highlight;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.highlight = false,
  });

  Color get _color => isDestructive
      ? KColors.error
      : highlight
          ? KColors.primary
          : KColors.baseContent;

  Color get _bgColor => isDestructive
      ? KColors.errorLight
      : highlight
          ? KColors.primary.withValues(alpha: 0.08)
          : KColors.base200;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: _color),
      ),
      title: Text(
        label,
        style: KTextStyles.bodySm.copyWith(
          color: _color,
          fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: KSpacing.xl,
        vertical: 2,
      ),
    );
  }
}
