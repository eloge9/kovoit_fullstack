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
import '../../verification/widgets/driver_activation_banner.dart';

class ConducteurShell extends ConsumerStatefulWidget {
  final Widget child;
  const ConducteurShell({super.key, required this.child});

  @override
  ConsumerState<ConducteurShell> createState() => _ConducteurShellState();
}

class _ConducteurShellState extends ConsumerState<ConducteurShell> {

  int _indexFromLocation(String location) {
    if (location.startsWith('/conducteur/trajets') ||
        location.startsWith('/conducteur/trajet/') ||
        location.startsWith('/conducteur/historique')) { return 1; }
    if (location.startsWith('/conducteur/reservation')) { return 2; }
    if (location.startsWith('/conducteur/messages')) { return 3; }
    return 0;
  }

  void _goToTab(BuildContext ctx, int index) {
    switch (index) {
      case 1: ctx.go('/conducteur/trajets'); break;
      case 2: ctx.go('/conducteur/reservations'); break;
      case 3: ctx.go('/conducteur/messages'); break;
      default: ctx.go('/conducteur'); break;
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
        appBar: _KConducteurAppBar(
          user: user,
          onNotificationsTap: () => context.push('/conducteur/notifications'),
          onAvatarTap: () => _showAccountMenu(context, user),
        ),
        body: Column(
          children: [
            const DriverActivationBanner(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                child: KeyedSubtree(
                  key: ValueKey(currentIndex),
                  child: widget.child,
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: _KCentralFab(
          onTap: () => context.push('/conducteur/create-trajet'),
        ),
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
        onPasserEnPassager: () async {
          Navigator.of(sheetCtx).pop();
          final ok = await ref.read(authProvider.notifier).changerMode('passager');
          if (!shellCtx.mounted) return;
          if (ok) {
            debugPrint('[ConducteurShell] Switch → passager OK');
            shellCtx.go('/passager');
          } else {
            final err = ref.read(authProvider).error ?? 'Impossible de passer en mode passager.';
            ScaffoldMessenger.of(shellCtx).showSnackBar(
              SnackBar(content: Text(err), backgroundColor: Colors.red.shade700),
            );
          }
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

class _KConducteurAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final UserModel? user;
  final VoidCallback onNotificationsTap;
  final VoidCallback onAvatarTap;

  const _KConducteurAppBar({
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
      shape:
          const Border(bottom: BorderSide(color: KColors.border, width: 0.5)),
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
      tooltip: 'Proposer un trajet',
      child: const Icon(
        Icons.add_rounded,
        color: Colors.white,
        size: 28,
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
            icon: Icons.directions_car_outlined,
            activeIcon: Icons.directions_car_rounded,
            label: 'Trajets',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
  final Future<void> Function() onPasserEnPassager;
  final VoidCallback onLogout;

  const _AccountMenuSheet({
    required this.user,
    required this.onNavigate,
    required this.onSwitchTab,
    required this.onPasserEnPassager,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: KColors.base100,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: KColors.base300,
                borderRadius: BorderRadius.circular(2),
              ),
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

          // Section Activité
          _SectionLabel('Activité'),
          _MenuItem(
            icon: Icons.history_rounded,
            label: 'Historique des trajets',
            onTap: () => onSwitchTab(1),
          ),
          _MenuItem(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Économie / Revenus',
            onTap: () => onNavigate('/conducteur/economie'),
          ),
          _MenuItem(
            icon: Icons.star_outline_rounded,
            label: 'Mes évaluations',
            onTap: () => onNavigate('/conducteur/evaluations'),
          ),

          const SizedBox(height: 4),
          const Divider(color: KColors.border, height: 1),

          // Section Mon compte
          _SectionLabel('Mon compte'),
          _MenuItem(
            icon: Icons.person_outline_rounded,
            label: 'Mon profil',
            onTap: () => onNavigate('/conducteur/profile'),
          ),
          _MenuItem(
            icon: Icons.settings_outlined,
            label: 'Paramètres',
            onTap: () => onNavigate('/conducteur/profile/edit'),
          ),
          _MenuItem(
            icon: Icons.swap_horiz_rounded,
            label: 'Passer en mode Passager',
            onTap: onPasserEnPassager,
            highlight: true,
          ),

          const SizedBox(height: 4),
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
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 2),
      child: Text(
        label.toUpperCase(),
        style: KTextStyles.caption.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: KColors.baseContentMid,
        ),
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
