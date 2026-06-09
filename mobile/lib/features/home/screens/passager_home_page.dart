import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../trajets/providers/trajet_provider.dart';
import '../../reservations/providers/reservation_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/trajet_card.dart';

class PassagerHomePage extends ConsumerStatefulWidget {
  const PassagerHomePage({super.key});

  @override
  ConsumerState<PassagerHomePage> createState() => _PassagerHomePageState();
}

class _PassagerHomePageState extends ConsumerState<PassagerHomePage> {
  int _selectedIndex = 0;
  final _departCtrl = TextEditingController();
  final _destCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(trajetsProvider.notifier).loadTrajets();
      ref.read(reservationsProvider.notifier).loadMesReservations();
    });
  }

  @override
  void dispose() {
    _departCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  void _search() {
    ref.read(trajetsProvider.notifier).loadTrajets(
          depart: _departCtrl.text.trim().isEmpty ? null : _departCtrl.text.trim(),
          destination: _destCtrl.text.trim().isEmpty ? null : _destCtrl.text.trim(),
        );
    setState(() => _selectedIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final pages = [
      _buildHome(context),
      _buildTrajets(context),
      _buildReservations(context),
      _buildProfile(context),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search),
            label: 'Trajets',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_outline),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Réservations',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildHome(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final reservations = ref.watch(reservationsProvider).mesReservations;
    final actives = reservations.where((r) => r.isEnAttente || r.isConfirmee).length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primaryColor, Color(0xFF2E7D32)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bonjour ${user?.username ?? ''} 👋',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Où voulez-vous aller aujourd\'hui ?',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              title: const Text('KoVoit', style: TextStyle(color: Colors.white)),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recherche rapide
                  _SearchCard(
                    departCtrl: _departCtrl,
                    destCtrl: _destCtrl,
                    onSearch: _search,
                  ),
                  const SizedBox(height: 20),

                  // Stats
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Réservations actives',
                          value: actives.toString(),
                          icon: Icons.bookmark,
                          color: AppTheme.primaryColor,
                          onTap: () => setState(() => _selectedIndex = 2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Note moyenne',
                          value: user?.note.toStringAsFixed(1) ?? '—',
                          icon: Icons.star,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Basculer en mode conducteur (si éligible)
                  if (user?.peutConduire == true)
                    Card(
                      color: AppTheme.primaryColor,
                      child: ListTile(
                        leading: const Icon(Icons.drive_eta, color: Colors.white),
                        title: const Text(
                          'Passer en mode conducteur',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                        onTap: () async {
                          await ref.read(authProvider.notifier).changerMode('conducteur');
                          if (mounted) context.go('/conducteur');
                        },
                      ),
                    ),

                  const SizedBox(height: 20),
                  // Trajets récents
                  const Text(
                    'Trajets disponibles',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          _buildTrajetsList(),
        ],
      ),
    );
  }

  Widget _buildTrajetsList() {
    final state = ref.watch(trajetsProvider);

    if (state.isLoading) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (state.error != null) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 8),
                Text(state.error!, textAlign: TextAlign.center),
                TextButton(
                  onPressed: () => ref.read(trajetsProvider.notifier).loadTrajets(),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (state.trajets.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text(
                  'Aucun trajet disponible',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final trajet = state.trajets[i];
            return TrajetCard(
              trajet: trajet,
              onTap: () => context.push('/passager/trajet/${trajet.id}'),
            );
          },
          childCount: state.trajets.length,
        ),
      ),
    );
  }

  Widget _buildTrajets(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rechercher un trajet')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _SearchCard(
              departCtrl: _departCtrl,
              destCtrl: _destCtrl,
              onSearch: _search,
            ),
          ),
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final state = ref.watch(trajetsProvider);
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: state.trajets.length,
                  itemBuilder: (context, i) {
                    final trajet = state.trajets[i];
                    return TrajetCard(
                      trajet: trajet,
                      onTap: () => context.push('/passager/trajet/${trajet.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReservations(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes réservations')),
      body: Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(reservationsProvider);
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.mesReservations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Aucune réservation', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(reservationsProvider.notifier).loadMesReservations(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.mesReservations.length,
              itemBuilder: (context, i) {
                final r = state.mesReservations[i];
                return _ReservationCard(
                  reservation: r,
                  onPayer: r.isConfirmee
                      ? () => context.push('/passager/paiement/${r.id}')
                      : null,
                  onAnnuler: r.isEnAttente
                      ? () async {
                          await ref.read(reservationsProvider.notifier).annuler(r.id);
                        }
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfile(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/passager/profile/edit'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    user?.username.substring(0, 1).toUpperCase() ?? '?',
                    style: const TextStyle(
                      fontSize: 36,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.username ?? '',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                Text(
                  user?.email ?? '',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, color: AppTheme.secondaryColor, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      user?.note.toStringAsFixed(1) ?? '0.0',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _ProfileMenuItem(
            icon: Icons.edit,
            label: 'Modifier le profil',
            onTap: () => context.push('/passager/profile/edit'),
          ),
          _ProfileMenuItem(
            icon: Icons.badge_outlined,
            label: 'Mes documents',
            onTap: () => context.push('/passager/profile/documents'),
          ),
          _ProfileMenuItem(
            icon: Icons.message_outlined,
            label: 'Messages',
            onTap: () => context.push('/passager/messages'),
          ),
          const Divider(),
          _ProfileMenuItem(
            icon: Icons.logout,
            label: 'Se déconnecter',
            color: AppTheme.errorColor,
            onTap: () async {
              await ref.read(authProvider.notifier).deconnexion();
              if (mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  final TextEditingController departCtrl;
  final TextEditingController destCtrl;
  final VoidCallback onSearch;

  const _SearchCard({
    required this.departCtrl,
    required this.destCtrl,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: departCtrl,
              decoration: const InputDecoration(
                hintText: 'Ville de départ',
                prefixIcon: Icon(Icons.trip_origin, color: AppTheme.primaryColor, size: 18),
                border: InputBorder.none,
              ),
            ),
            const Divider(height: 1),
            TextField(
              controller: destCtrl,
              decoration: const InputDecoration(
                hintText: 'Destination',
                prefixIcon: Icon(Icons.location_on, color: AppTheme.errorColor, size: 18),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: onSearch,
              icon: const Icon(Icons.search),
              label: const Text('Rechercher'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  final dynamic reservation;
  final VoidCallback? onPayer;
  final VoidCallback? onAnnuler;

  const _ReservationCard({
    required this.reservation,
    this.onPayer,
    this.onAnnuler,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${reservation.trajet?.depart ?? '?'} → ${reservation.trajet?.destination ?? '?'}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusBadge(statut: reservation.statut),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Montant: ${Formatters.currency(reservation.montantTotal)}',
              style: const TextStyle(color: Colors.grey),
            ),
            if (onPayer != null || onAnnuler != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onPayer != null)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onPayer,
                        child: const Text('Payer'),
                      ),
                    ),
                  if (onAnnuler != null) ...[
                    if (onPayer != null) const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: onAnnuler,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: const BorderSide(color: AppTheme.errorColor),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String statut;
  const _StatusBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (statut) {
      case 'en_attente':
        color = AppTheme.warningColor;
        break;
      case 'confirmee':
        color = AppTheme.primaryColor;
        break;
      case 'declinee':
        color = AppTheme.errorColor;
        break;
      case 'terminee':
        color = Colors.grey;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        Formatters.reservationStatutLabel(statut),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: color != null ? TextStyle(color: color) : null),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }
}
