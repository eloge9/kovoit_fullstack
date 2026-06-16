import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../auth/providers/auth_provider.dart';
import 'admin_dashboard_page.dart';
import 'admin_utilisateurs_page.dart';
import 'admin_conducteurs_page.dart';
import 'admin_trajets_page.dart';
import 'admin_audit_page.dart';
import 'admin_settings_page.dart';
import 'admin_reservations_page.dart';
import 'admin_paiements_page.dart';
import 'admin_statistiques_page.dart';
import 'admin_messagerie_page.dart';
import 'admin_notifications_page.dart';
import 'admin_plaintes_page.dart';

enum _AdminPage {
  dashboard,
  utilisateurs,
  conducteurs,
  trajets,
  reservations,
  paiements,
  statistiques,
  messagerie,
  notifications,
  plaintes,
  audit,
  settings,
}

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  _AdminPage _current = _AdminPage.dashboard;
  int _bottomIndex = 0;

  static const _bottomTabs = [
    _TabItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard,       label: 'Dashboard'),
    _TabItem(icon: Icons.people_outlined,    activeIcon: Icons.people,          label: 'Utilisateurs'),
    _TabItem(icon: Icons.drive_eta_outlined, activeIcon: Icons.drive_eta,       label: 'Conducteurs'),
    _TabItem(icon: Icons.route_outlined,     activeIcon: Icons.route,           label: 'Trajets'),
    _TabItem(icon: Icons.menu,               activeIcon: Icons.menu,            label: 'Plus'),
  ];

  Widget get _currentPage {
    switch (_current) {
      case _AdminPage.dashboard:      return const AdminDashboardPage();
      case _AdminPage.utilisateurs:   return const AdminUtilisateursPage();
      case _AdminPage.conducteurs:    return const AdminConducteursPage();
      case _AdminPage.trajets:        return const AdminTrajetsPage();
      case _AdminPage.reservations:   return const AdminReservationsPage();
      case _AdminPage.paiements:      return const AdminPaiementsPage();
      case _AdminPage.statistiques:   return const AdminStatistiquesPage();
      case _AdminPage.messagerie:     return const AdminMessageriePage();
      case _AdminPage.notifications:  return const AdminNotificationsPage();
      case _AdminPage.plaintes:       return const AdminPlaintesPage();
      case _AdminPage.audit:          return const AdminAuditPage();
      case _AdminPage.settings:       return const AdminSettingsPage();
    }
  }

  void _navigate(_AdminPage page, {int? bottomIndex}) {
    setState(() {
      _current = page;
      if (bottomIndex != null) _bottomIndex = bottomIndex;
    });
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  void _onBottomTap(int index) {
    if (index == 4) {
      Scaffold.of(context).openDrawer();
      return;
    }
    final pages = [
      _AdminPage.dashboard,
      _AdminPage.utilisateurs,
      _AdminPage.conducteurs,
      _AdminPage.trajets,
    ];
    _navigate(pages[index], bottomIndex: index);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: KColors.base200,
      drawer: _buildDrawer(user?.username ?? 'Admin'),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(key: ValueKey(_current), child: _currentPage),
      ),
      bottomNavigationBar: Builder(
        builder: (ctx) => Container(
          decoration: const BoxDecoration(
            color: KColors.base100,
            border: Border(top: BorderSide(color: KColors.border)),
          ),
          child: SafeArea(
            child: SizedBox(
              height: 60,
              child: Row(
                children: _bottomTabs.asMap().entries.map((entry) {
                  final i = entry.key;
                  final tab = entry.value;
                  final selected = i == _bottomIndex && i != 4;

                  return Expanded(
                    child: InkWell(
                      onTap: () {
                        if (i == 4) {
                          Scaffold.of(ctx).openDrawer();
                        } else {
                          _onBottomTap(i);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: selected
                                    ? KColors.primary.withValues(alpha: 0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Icon(
                                selected ? tab.activeIcon : tab.icon,
                                size: 20,
                                color: selected ? KColors.primary : KColors.baseContentMid,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tab.label,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                color: selected ? KColors.primary : KColors.baseContentMid,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(String username) {
    return Drawer(
      backgroundColor: KColors.base100,
      child: SafeArea(
        child: Column(children: [
          // En-tête
          Container(
            padding: const EdgeInsets.all(KSpacing.xl),
            color: KColors.primary,
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
              ),
              const SizedBox(width: KSpacing.md),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Administration',
                    style: KTextStyles.bodySm.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  Text(username, style: KTextStyles.caption.copyWith(color: Colors.white70)),
                ],
              )),
            ]),
          ),

          // Menu
          Expanded(child: ListView(
            padding: const EdgeInsets.symmetric(vertical: KSpacing.md),
            children: [
              _drawerItem(
                icon: Icons.dashboard_outlined, label: 'Tableau de bord',
                page: _AdminPage.dashboard, bottomIndex: 0,
              ),

              _sectionLabel('UTILISATEURS'),
              _drawerItem(icon: Icons.people_outlined, label: 'Utilisateurs', page: _AdminPage.utilisateurs, bottomIndex: 1),
              _drawerItem(icon: Icons.drive_eta_outlined, label: 'Conducteurs', page: _AdminPage.conducteurs, bottomIndex: 2),

              _sectionLabel('ACTIVITÉ'),
              _drawerItem(icon: Icons.route_outlined, label: 'Trajets', page: _AdminPage.trajets, bottomIndex: 3),
              _drawerItem(icon: Icons.confirmation_number_outlined, label: 'Réservations', page: _AdminPage.reservations),
              _drawerItem(icon: Icons.chat_bubble_outline, label: 'Messagerie', page: _AdminPage.messagerie),

              _sectionLabel('FINANCE'),
              _drawerItem(icon: Icons.account_balance_wallet_outlined, label: 'Paiements', page: _AdminPage.paiements),
              _drawerItem(icon: Icons.bar_chart_outlined, label: 'Statistiques', page: _AdminPage.statistiques),

              _sectionLabel('MODÉRATION'),
              _drawerItem(icon: Icons.flag_outlined, label: 'Plaintes', page: _AdminPage.plaintes),

              _sectionLabel('SYSTÈME'),
              _drawerItem(icon: Icons.notifications_outlined, label: 'Notifications', page: _AdminPage.notifications),
              _drawerItem(icon: Icons.manage_search_outlined, label: 'Audit', page: _AdminPage.audit),
              _drawerItem(icon: Icons.settings_outlined, label: 'Paramètres', page: _AdminPage.settings),
            ],
          )),

          // Déconnexion
          const Divider(color: KColors.border, height: 0),
          InkWell(
            onTap: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).deconnexion();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KSpacing.pagePaddingH, vertical: KSpacing.md,
              ),
              child: Row(children: [
                const Icon(Icons.logout_outlined, color: KColors.error, size: 20),
                const SizedBox(width: KSpacing.md),
                Text('Déconnexion', style: KTextStyles.bodySm.copyWith(color: KColors.error)),
              ]),
            ),
          ),
          const SizedBox(height: KSpacing.md),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(KSpacing.pagePaddingH, KSpacing.lg, KSpacing.pagePaddingH, KSpacing.xs),
      child: Text(label, style: KTextStyles.label.copyWith(letterSpacing: 1.5)),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required _AdminPage page,
    int? bottomIndex,
  }) {
    final selected = _current == page;
    return InkWell(
      onTap: () => _navigate(page, bottomIndex: bottomIndex),
      child: Container(
        color: selected ? KColors.primary.withValues(alpha: 0.08) : Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.pagePaddingH, vertical: KSpacing.sm + 2,
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: selected ? KColors.primary : KColors.baseContentMid),
          const SizedBox(width: KSpacing.md),
          Text(label, style: KTextStyles.bodySm.copyWith(
            color: selected ? KColors.primary : KColors.baseContent,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          )),
          if (selected) ...[
            const Spacer(),
            Container(
              width: 4, height: 4,
              decoration: const BoxDecoration(color: KColors.primary, shape: BoxShape.circle),
            ),
          ],
        ]),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabItem({required this.icon, required this.activeIcon, required this.label});
}
