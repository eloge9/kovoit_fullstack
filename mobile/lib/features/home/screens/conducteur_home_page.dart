import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../trajets/providers/trajet_provider.dart';
import '../../reservations/providers/reservation_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/trajet_card.dart';

class ConducteurHomePage extends ConsumerStatefulWidget {
  const ConducteurHomePage({super.key});

  @override
  ConsumerState<ConducteurHomePage> createState() => _ConducteurHomePageState();
}

class _ConducteurHomePageState extends ConsumerState<ConducteurHomePage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(trajetsProvider.notifier).loadMesTrajets();
      ref.read(reservationsProvider.notifier).loadReservationsRecues();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildHome(context),
      _buildMesTrajets(context),
      _buildReservationsRecues(context),
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
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Mes trajets',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Passagers',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/conducteur/create-trajet'),
              icon: const Icon(Icons.add),
              label: const Text('Nouveau trajet'),
              backgroundColor: AppTheme.primaryColor,
            )
          : null,
    );
  }

  Widget _buildHome(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final mesTrajets = ref.watch(trajetsProvider).trajets;
    final reservationsRecues = ref.watch(reservationsProvider).reservationsRecues;
    final enAttente = reservationsRecues.where((r) => r.isEnAttente).length;
    final trajetsActifs = mesTrajets.where((t) => t.statut == 'ouvert' || t.statut == 'en_cours').length;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conducteur ${user?.username ?? ''} 🚗',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Gérez vos trajets et passagers',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              title: const Text('KoVoit Conducteur', style: TextStyle(color: Colors.white)),
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
                  // Stats
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Trajets actifs',
                          value: trajetsActifs.toString(),
                          icon: Icons.route,
                          color: const Color(0xFF1565C0),
                          onTap: () => setState(() => _selectedIndex = 1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          label: 'Demandes en attente',
                          value: enAttente.toString(),
                          icon: Icons.people,
                          color: AppTheme.warningColor,
                          onTap: () => setState(() => _selectedIndex = 2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Note moyenne',
                          value: user?.note.toStringAsFixed(1) ?? '—',
                          icon: Icons.star,
                          color: AppTheme.secondaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          color: AppTheme.primaryColor,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => context.push('/conducteur/create-trajet'),
                            child: const Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Icon(Icons.add_circle, color: Colors.white, size: 28),
                                  SizedBox(height: 8),
                                  Text(
                                    'Créer un trajet',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Basculer mode passager
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.person, color: AppTheme.primaryColor),
                      title: const Text('Passer en mode passager'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      onTap: () async {
                        await ref.read(authProvider.notifier).changerMode('passager');
                        if (mounted) context.go('/passager');
                      },
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'Mes derniers trajets',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  // Afficher les 3 derniers trajets
                  ...mesTrajets.take(3).map((t) => TrajetCard(
                        trajet: t,
                        onTap: () => context.push('/conducteur/trajet/${t.id}'),
                        showActions: true,
                        onCommencer: t.statut == 'ouvert'
                            ? () => _commencer(t.id)
                            : null,
                        onTerminer: t.statut == 'en_cours'
                            ? () => _terminer(t.id)
                            : null,
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _commencer(int id) async {
    final ok = await ref.read(trajetsProvider.notifier).commencerTrajet(id);
    if (mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trajet démarré !'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Future<void> _terminer(int id) async {
    final ok = await ref.read(trajetsProvider.notifier).terminerTrajet(id);
    if (mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trajet terminé !'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Widget _buildMesTrajets(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes trajets')),
      body: Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(trajetsProvider);
          if (state.isLoading) return const Center(child: CircularProgressIndicator());
          if (state.trajets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.route, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Aucun trajet créé', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/conducteur/create-trajet'),
                    icon: const Icon(Icons.add),
                    label: const Text('Créer un trajet'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(trajetsProvider.notifier).loadMesTrajets(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.trajets.length,
              itemBuilder: (context, i) {
                final t = state.trajets[i];
                return TrajetCard(
                  trajet: t,
                  onTap: () => context.push('/conducteur/trajet/${t.id}'),
                  showActions: true,
                  onCommencer: t.statut == 'ouvert' ? () => _commencer(t.id) : null,
                  onTerminer: t.statut == 'en_cours' ? () => _terminer(t.id) : null,
                  onAnnuler: t.statut == 'ouvert'
                      ? () async {
                          await ref.read(trajetsProvider.notifier).annulerTrajet(t.id);
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

  Widget _buildReservationsRecues(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demandes de réservation')),
      body: Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(reservationsProvider);
          if (state.isLoading) return const Center(child: CircularProgressIndicator());
          if (state.reservationsRecues.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Aucune demande reçue', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(reservationsProvider.notifier).loadReservationsRecues(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.reservationsRecues.length,
              itemBuilder: (context, i) {
                final r = state.reservationsRecues[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppTheme.primaryColor,
                              child: Text(
                                r.passagerNom.isNotEmpty
                                    ? r.passagerNom[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.passagerNom,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    Formatters.currency(r.montantTotal),
                                    style: const TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (r.isEnAttente)
                              Chip(
                                label: const Text('En attente', style: TextStyle(fontSize: 11)),
                                backgroundColor: AppTheme.warningColor.withValues(alpha: 0.1),
                                labelStyle: const TextStyle(color: AppTheme.warningColor),
                              ),
                          ],
                        ),
                        if (r.isEnAttente) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final ok = await ref
                                        .read(reservationsProvider.notifier)
                                        .confirmer(r.id);
                                    if (mounted && ok) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Réservation confirmée !'),
                                          backgroundColor: AppTheme.successColor,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Confirmer'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    await ref
                                        .read(reservationsProvider.notifier)
                                        .decliner(r.id);
                                  },
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text('Décliner'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.errorColor,
                                    side: const BorderSide(color: AppTheme.errorColor),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        // Bouton message
                        TextButton.icon(
                          onPressed: () => context.push(
                            '/conducteur/messages/${r.passagerId}',
                            extra: {'name': r.passagerNom},
                          ),
                          icon: const Icon(Icons.message_outlined, size: 16),
                          label: const Text('Envoyer un message'),
                        ),
                      ],
                    ),
                  ),
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
            onPressed: () => context.push('/conducteur/profile/edit'),
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
                  backgroundColor: const Color(0xFF1565C0),
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
                Chip(
                  label: const Text('Conducteur'),
                  backgroundColor: const Color(0xFF1565C0).withValues(alpha: 0.1),
                  labelStyle: const TextStyle(color: Color(0xFF1565C0)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.directions_car, color: AppTheme.primaryColor),
            title: const Text('Mes véhicules'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            onTap: () => context.push('/conducteur/vehicules'),
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined, color: AppTheme.primaryColor),
            title: const Text('Documents'),
            subtitle: Text(
              user?.statutValidation == 'valide' ? '✓ Validé' : 'En attente de validation',
              style: TextStyle(
                color: user?.statutValidation == 'valide'
                    ? AppTheme.successColor
                    : AppTheme.warningColor,
                fontSize: 12,
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            onTap: () => context.push('/conducteur/profile/documents'),
          ),
          ListTile(
            leading: const Icon(Icons.message_outlined, color: AppTheme.primaryColor),
            title: const Text('Messages'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            onTap: () => context.push('/conducteur/messages'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.errorColor),
            title: const Text('Se déconnecter', style: TextStyle(color: AppTheme.errorColor)),
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
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
