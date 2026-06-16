import 'package:flutter/material.dart';
import '../../features/trajets/models/trajet_model.dart';
import '../utils/formatters.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'k_badge.dart';
import 'k_avatar.dart';
import 'k_button.dart';

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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: KColors.base100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Route + statut ───────────────────────────────────────
            Row(children: [
              Expanded(child: Column(children: [
                _LocationRow(icon: Icons.trip_origin,
                    color: KColors.primary, text: trajet.depart),
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Container(width: 2, height: 14, color: KColors.base300,
                      margin: const EdgeInsets.symmetric(vertical: 3)),
                ),
                _LocationRow(icon: Icons.location_on,
                    color: KColors.error, text: trajet.destination),
              ])),
              const SizedBox(width: 8),
              KBadge.fromStatut(trajet.statut),
            ]),
            const SizedBox(height: 12),
            const Divider(color: KColors.border, height: 1),
            const SizedBox(height: 12),

            // ── Méta-infos ───────────────────────────────────────────
            Wrap(spacing: 16, runSpacing: 4, children: [
              _InfoChip(icon: Icons.calendar_today_outlined,
                  label: Formatters.dateTime(trajet.dateHeureDepart)),
              _InfoChip(icon: Icons.payments_outlined,
                  label: Formatters.currency(trajet.prixParPlace),
                  color: KColors.primary, isBold: true),
              _InfoChip(
                icon: Icons.people_outline,
                label: '${trajet.placesRestantes} place${trajet.placesRestantes > 1 ? 's' : ''}',
                color: trajet.placesRestantes > 0 ? KColors.success : KColors.error,
              ),
            ]),

            // ── Conducteur ───────────────────────────────────────────
            if (trajet.conducteurNom.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                KAvatar(name: trajet.conducteurNom,
                    photoUrl: trajet.conducteurPhoto, size: 22),
                const SizedBox(width: 6),
                Text(trajet.conducteurNom, style: KTextStyles.meta),
                const SizedBox(width: 6),
                const Icon(Icons.star_rounded, size: 12, color: KColors.warning),
                Text(trajet.conducteurNote.toStringAsFixed(1),
                    style: KTextStyles.meta.copyWith(fontWeight: FontWeight.w600)),
              ]),
            ],

            // ── Actions conducteur ────────────────────────────────────
            if (showActions) ...[
              const SizedBox(height: 12),
              Row(children: [
                if (trajet.statut == 'ouvert' && onCommencer != null)
                  Expanded(child: KButton(
                    label: 'Commencer',
                    icon: Icons.play_circle_rounded,
                    variant: KButtonVariant.success,
                    onPressed: onCommencer,
                  )),
                if (trajet.statut == 'en_cours' && onTerminer != null)
                  Expanded(child: KButton(
                    label: 'Terminer',
                    icon: Icons.flag_rounded,
                    variant: KButtonVariant.primary,
                    onPressed: onTerminer,
                  )),
                if (trajet.statut == 'ouvert' && onAnnuler != null) ...[
                  const SizedBox(width: 8),
                  KButton(
                    label: 'Annuler',
                    variant: KButtonVariant.error,
                    onPressed: onAnnuler,
                  ),
                ],
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _LocationRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(text,
          style: KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis)),
    ]);
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isBold;
  final Color? color;
  const _InfoChip({required this.icon, required this.label,
      this.isBold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color ?? KColors.baseContentMid),
      const SizedBox(width: 4),
      Text(label, style: KTextStyles.meta.copyWith(
        fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
        color: color ?? KColors.baseContentMid,
      )),
    ]);
  }
}
