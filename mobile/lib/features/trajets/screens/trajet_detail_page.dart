import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/trajet_provider.dart';
import '../../reservations/providers/reservation_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/star_rating.dart';

final _trajetDetailProvider = FutureProvider.family<dynamic, int>((ref, id) async {
  return ref.watch(trajetRepositoryProvider).getTrajet(id);
});

class TrajetDetailPage extends ConsumerWidget {
  final int trajetId;
  final bool isConducteur;

  const TrajetDetailPage({
    super.key,
    required this.trajetId,
    this.isConducteur = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trajetAsync = ref.watch(_trajetDetailProvider(trajetId));

    return Scaffold(
      appBar: AppBar(title: const Text('Détail du trajet')),
      body: trajetAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text(e.toString()),
              TextButton(
                onPressed: () => ref.refresh(_trajetDetailProvider(trajetId)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (trajet) => _buildContent(context, ref, trajet),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, dynamic trajet) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Carte itinéraire
          Container(
            color: AppTheme.primaryColor,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _RouteItem(
                  icon: Icons.trip_origin,
                  color: Colors.white,
                  label: 'Départ',
                  value: trajet.depart,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 11),
                  child: Container(
                    width: 2,
                    height: 24,
                    color: Colors.white54,
                  ),
                ),
                _RouteItem(
                  icon: Icons.location_on,
                  color: AppTheme.secondaryColor,
                  label: 'Arrivée',
                  value: trajet.destination,
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Infos principales
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.calendar_today,
                          label: 'Date & heure',
                          value: Formatters.dateTime(trajet.dateHeureDepart),
                        ),
                        _InfoRow(
                          icon: Icons.straighten,
                          label: 'Distance',
                          value: Formatters.distance(trajet.distanceKm),
                        ),
                        _InfoRow(
                          icon: Icons.payments_outlined,
                          label: 'Prix par place',
                          value: Formatters.currency(trajet.prixParPlace),
                          valueColor: AppTheme.primaryColor,
                        ),
                        _InfoRow(
                          icon: Icons.people_outline,
                          label: 'Places disponibles',
                          value: '${trajet.placesRestantes} / ${trajet.placesDisponibles}',
                          valueColor: trajet.placesRestantes > 0
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                        ),
                        if (trajet.vehicule != null)
                          _InfoRow(
                            icon: Icons.directions_car,
                            label: 'Véhicule',
                            value: trajet.vehicule!.displayName,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Conducteur
                if (!isConducteur) ...[
                  const Text(
                    'Votre conducteur',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor,
                        child: Text(
                          trajet.conducteurNom.isNotEmpty
                              ? trajet.conducteurNom[0].toUpperCase()
                              : '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(trajet.conducteurNom),
                      subtitle: Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: AppTheme.secondaryColor),
                          const SizedBox(width: 4),
                          Text(trajet.conducteurNote.toStringAsFixed(1)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.message_outlined),
                        onPressed: () => context.push(
                          '/passager/messages/${trajet.conducteurId}?name=${trajet.conducteurNom}',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Bouton réserver
                if (!isConducteur && trajet.isAvailable)
                  AppButton(
                    label: 'Réserver cette place',
                    icon: Icons.bookmark_add,
                    onPressed: () => _reserver(context, ref, trajet),
                  ),

                // Actions conducteur
                if (isConducteur) ...[
                  if (trajet.statut == 'ouvert')
                    AppButton(
                      label: 'Commencer le trajet',
                      icon: Icons.play_arrow,
                      onPressed: () async {
                        final ok = await ref
                            .read(trajetsProvider.notifier)
                            .commencerTrajet(trajetId);
                        if (ok && context.mounted) {
                          ref.refresh(_trajetDetailProvider(trajetId));
                        }
                      },
                    ),
                  if (trajet.statut == 'en_cours')
                    AppButton(
                      label: 'Terminer le trajet',
                      icon: Icons.flag,
                      onPressed: () async {
                        final ok = await ref
                            .read(trajetsProvider.notifier)
                            .terminerTrajet(trajetId);
                        if (ok && context.mounted) {
                          ref.refresh(_trajetDetailProvider(trajetId));
                        }
                      },
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reserver(BuildContext context, WidgetRef ref, dynamic trajet) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la réservation'),
        content: Text(
          'Réserver une place sur le trajet\n'
          '${trajet.depart} → ${trajet.destination}\n'
          'pour ${Formatters.currency(trajet.prixParPlace)} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final ok = await ref.read(reservationsProvider.notifier).reserver(trajet.id);
    if (!context.mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Réservation effectuée ! En attente de confirmation.'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      context.pop();
    } else {
      final error = ref.read(reservationsProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Erreur lors de la réservation'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}

class _RouteItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _RouteItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
