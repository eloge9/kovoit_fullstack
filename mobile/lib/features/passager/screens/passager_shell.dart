import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import 'passager_dashboard_page.dart';
import '../../trajets/screens/trajets_list_page.dart';
import '../../reservations/screens/reservations_page.dart';
import '../../messagerie/screens/messagerie_page.dart';
import '../../profile/screens/profile_page.dart';

/// Shell Passager — adapte la navbar horizontale Web en Bottom Navigation Bar mobile
class PassagerShell extends ConsumerStatefulWidget {
  const PassagerShell({super.key});

  @override
  ConsumerState<PassagerShell> createState() => _PassagerShellState();
}

class _PassagerShellState extends ConsumerState<PassagerShell> {
  int _currentIndex = 0;

  static const _tabs = [
    _TabItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Accueil',
    ),
    _TabItem(
      icon: Icons.search_outlined,
      activeIcon: Icons.search,
      label: 'Trajets',
    ),
    _TabItem(
      icon: Icons.bookmark_border,
      activeIcon: Icons.bookmark,
      label: 'Réservations',
    ),
    _TabItem(
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      label: 'Messages',
    ),
    _TabItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profil',
    ),
  ];

  Widget get _currentPage {
    switch (_currentIndex) {
      case 0:
        return const PassagerDashboardPage();
      case 1:
        return const TrajetsListPage(isMesTrajets: false);
      case 2:
        return const ReservationsPage(isConducteur: false);
      case 3:
        return const MessageriePage();
      case 4:
        return const ProfilePage();
      default:
        return const PassagerDashboardPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.base200,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _currentPage,
      ),
      bottomNavigationBar: _KBottomNav(
        currentIndex: _currentIndex,
        tabs: _tabs,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _KBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_TabItem> tabs;
  final void Function(int) onTap;

  const _KBottomNav({
    required this.currentIndex,
    required this.tabs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: KColors.base100,
        border: Border(top: BorderSide(color: KColors.border)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: tabs.asMap().entries.map((entry) {
              final i = entry.key;
              final tab = entry.value;
              final selected = i == currentIndex;

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? KColors.primary.withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Icon(
                            selected ? tab.activeIcon : tab.icon,
                            size: 22,
                            color: selected
                                ? KColors.primary
                                : KColors.baseContentMid,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tab.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: selected
                                ? KColors.primary
                                : KColors.baseContentMid,
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
    );
  }
}
