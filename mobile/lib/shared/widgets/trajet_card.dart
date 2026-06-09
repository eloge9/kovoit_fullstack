import 'package:flutter/material.dart';
import '../../features/trajets/models/trajet_model.dart';
import '../../core/utils/formatters.dart';
import '../../core/theme/app_theme.dart';

class TrajetCard extends StatelessWidget {
  final TrajetModel trajet;
  final VoidCallback? onTap;
  final bool showActions;
  final VoidCallback? onCommencer;
  final VoidCallback? onTerminer;
  final VoidCallback? onAnnuler;

  const TrajetCard({
    super.key,
    required this.trajet,
    this.onTap,
    this.showActions = false,
    this.onCommencer,
    this.onTerminer,
    this.onAnnuler,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête: trajet + statut
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LocationRow(
                          icon: Icons.trip_origin,
                          color: AppTheme.primaryColor,
                          text: trajet.depart,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 11),
                          child: Container(
                            width: 2,
                            height: 16,
                            color: Colors.grey.shade300,
                          ),
                        ),
                        _LocationRow(
                          icon: Icons.location_on,
                          color: AppTheme.errorColor,
                          text: trajet.destination,
                        ),
                      ],
                    ),
                  ),
                  _StatutBadge(statut: trajet.statut),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Infos: date, prix, places
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.calendar_today,
                    label: Formatters.dateTime(trajet.dateHeureDepart),
                  ),
                  const Spacer(),
                  _InfoChip(
                    icon: Icons.payments_outlined,
                    label: Formatters.currency(trajet.prixParPlace),
                    isBold: true,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.people_outline,
                    label: '${trajet.placesRestantes} places',
                    color: trajet.placesRestantes > 0
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                  ),
                ],
              ),

              // Conducteur (si passager voit le trajet)
              if (trajet.conducteurNom.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.grey.shade200,
                      child: Text(
                        trajet.conducteurNom[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      trajet.conducteurNom,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.star, size: 12, color: AppTheme.secondaryColor),
                    Text(
                      trajet.conducteurNote.toStringAsFixed(1),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],

              // Actions conducteur
              if (showActions) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (trajet.statut == 'ouvert' && onCommencer != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onCommencer,
                          icon: const Icon(Icons.play_arrow, size: 16),
                          label: const Text('Commencer'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    if (trajet.statut == 'en_cours' && onTerminer != null)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onTerminer,
                          icon: const Icon(Icons.flag, size: 16),
                          label: const Text('Terminer'),
                        ),
                      ),
                    if (trajet.statut == 'ouvert' && onAnnuler != null) ...[
                      const SizedBox(width: 8),
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
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _LocationRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isBold;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.isBold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            color: color ?? Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

class _StatutBadge extends StatelessWidget {
  final String statut;

  const _StatutBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (statut) {
      case 'ouvert':
        color = AppTheme.primaryColor;
        label = 'Disponible';
        break;
      case 'en_cours':
        color = AppTheme.warningColor;
        label = 'En cours';
        break;
      case 'termine':
        color = Colors.grey;
        label = 'Terminé';
        break;
      case 'annule':
        color = AppTheme.errorColor;
        label = 'Annulé';
        break;
      default:
        color = Colors.grey;
        label = statut;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
