import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/reservation_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

class ReservationsPage extends ConsumerStatefulWidget {
  final bool isConducteur;

  const ReservationsPage({super.key, this.isConducteur = false});

  @override
  ConsumerState<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends ConsumerState<ReservationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isConducteur) {
        ref.read(reservationsProvider.notifier).loadReservationsRecues();
      } else {
        ref.read(reservationsProvider.notifier).loadMesReservations();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reservationsProvider);
    final reservations = widget.isConducteur
        ? state.reservationsRecues
        : state.mesReservations;
    final prefix = widget.isConducteur ? '/conducteur' : '/passager';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isConducteur ? 'Demandes reçues' : 'Mes réservations'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (widget.isConducteur) {
            await ref.read(reservationsProvider.notifier).loadReservationsRecues();
          } else {
            await ref.read(reservationsProvider.notifier).loadMesReservations();
          }
        },
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : reservations.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bookmark_outline, size: 80, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('Aucune réservation', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: reservations.length,
                    itemBuilder: (context, i) {
                      final r = reservations[i];
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
                                      '${r.trajet?.depart ?? '?'} → ${r.trajet?.destination ?? '?'}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  _StatusBadge(statut: r.statut),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (r.trajet != null)
                                Text(
                                  Formatters.dateTime(r.trajet!.dateHeureDepart),
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 13),
                                ),
                              Text(
                                'Montant: ${Formatters.currency(r.montantTotal)}',
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              // Nom conducteur/passager
                              if (widget.isConducteur)
                                Text('Passager: ${r.passagerNom}',
                                    style: const TextStyle(color: Colors.grey)),
                              const SizedBox(height: 12),

                              // Actions
                              if (widget.isConducteur && r.isEnAttente)
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
                                          side: const BorderSide(
                                              color: AppTheme.errorColor),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                              if (!widget.isConducteur && r.isConfirmee)
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => context.push(
                                            '$prefix/paiement/${r.id}'),
                                        icon: const Icon(Icons.payments, size: 16),
                                        label: const Text('Payer'),
                                      ),
                                    ),
                                  ],
                                ),

                              if (!widget.isConducteur && r.isEnAttente)
                                OutlinedButton(
                                  onPressed: () async {
                                    await ref
                                        .read(reservationsProvider.notifier)
                                        .annuler(r.id);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.errorColor,
                                    side: const BorderSide(color: AppTheme.errorColor),
                                    minimumSize: const Size(double.infinity, 40),
                                  ),
                                  child: const Text('Annuler la réservation'),
                                ),

                              if (r.isTerminee && !widget.isConducteur)
                                OutlinedButton.icon(
                                  onPressed: () => context.push(
                                    '$prefix/evaluation/${r.trajetId}/${r.trajet?.conducteurId ?? ''}',
                                  ),
                                  icon: const Icon(Icons.star, size: 16),
                                  label: const Text('Évaluer le conducteur'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 40),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
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
