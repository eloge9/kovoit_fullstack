import 'package:flutter/material.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/k_button.dart';

/// Panneau bas conducteur — liste complète des passagers avec actions.
/// Distance, ETA, bouton "Aller récupérer", bouton AR, bouton message.
class PassengersBottomPanel extends StatefulWidget {
  final List<PassengerPositionData> passengers;
  final double? driverLat;
  final double? driverLng;
  final double speedKmh;
  final bool isEnding;
  final VoidCallback onTerminer;
  final void Function(PassengerPositionData) onNavigate;
  final void Function(PassengerPositionData) onArView;
  final void Function(PassengerPositionData) onMessage;

  const PassengersBottomPanel({
    super.key,
    required this.passengers,
    required this.speedKmh,
    required this.isEnding,
    required this.onTerminer,
    required this.onNavigate,
    required this.onArView,
    required this.onMessage,
    this.driverLat,
    this.driverLng,
  });

  @override
  State<PassengersBottomPanel> createState() => _PassengersBottomPanelState();
}

class _PassengersBottomPanelState extends State<PassengersBottomPanel> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ────────────────────────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: KColors.base300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_rounded, size: 15,
                          color: KColors.baseContentMid),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.passengers.length} passager'
                        '${widget.passengers.length > 1 ? 's' : ''} en attente',
                        style: KTextStyles.label,
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        size: 16,
                        color: KColors.baseContentMid,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Liste passagers ───────────────────────────────────────────────
          if (_expanded) ...[
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.38,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                itemCount: widget.passengers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _PassengerCard(
                  passenger: widget.passengers[i],
                  driverLat: widget.driverLat,
                  driverLng: widget.driverLng,
                  speedKmh: widget.speedKmh,
                  onNavigate: () => widget.onNavigate(widget.passengers[i]),
                  onArView:   () => widget.onArView(widget.passengers[i]),
                  onMessage:  () => widget.onMessage(widget.passengers[i]),
                ),
              ),
            ),
          ],

          // ── Bouton terminer ───────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              16, 8, 16,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            child: KButton(
              label: 'Terminer le trajet',
              icon: Icons.flag_rounded,
              variant: KButtonVariant.error,
              isLoading: widget.isEnding,
              onPressed: widget.isEnding ? null : () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: const Text('Terminer le trajet ?'),
                    content: const Text(
                      'Confirmez-vous la fin du trajet ?\nLes passagers seront notifiés.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Annuler'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: KColors.success),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Terminer',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) widget.onTerminer();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carte passager ────────────────────────────────────────────────────────────

class _PassengerCard extends StatelessWidget {
  final PassengerPositionData passenger;
  final double? driverLat;
  final double? driverLng;
  final double speedKmh;
  final VoidCallback onNavigate;
  final VoidCallback onArView;
  final VoidCallback onMessage;

  const _PassengerCard({
    required this.passenger,
    required this.speedKmh,
    required this.onNavigate,
    required this.onArView,
    required this.onMessage,
    this.driverLat,
    this.driverLng,
  });

  @override
  Widget build(BuildContext context) {
    double? distKm;
    int? etaMin;
    if (driverLat != null && driverLng != null) {
      distKm = LocationService.distanceKm(
        driverLat!, driverLng!, passenger.latitude, passenger.longitude,
      );
      if (speedKmh > 2) {
        etaMin = LocationService.etaMinutes(distKm, speedKmh);
      }
    }

    final distLabel = distKm == null
        ? null
        : distKm < 1
            ? '${(distKm * 1000).toInt()} m'
            : '${distKm.toStringAsFixed(1)} km';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KColors.base100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête ──────────────────────────────────────────────────────
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFFF8C00),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    passenger.nom,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: KColors.baseContent,
                    ),
                  ),
                  if (distLabel != null)
                    Row(children: [
                      Text(distLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: KColors.baseContentMid,
                          )),
                      if (etaMin != null && etaMin > 0) ...[
                        const Text(' · ',
                            style: TextStyle(
                                color: KColors.baseContentMid, fontSize: 12)),
                        Text('$etaMin min',
                            style: const TextStyle(
                              fontSize: 12,
                              color: KColors.primary,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ]),
                ],
              ),
            ),
            // GPS dot (position en direct)
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: KColors.success,
                shape: BoxShape.circle,
              ),
            ),
          ]),

          const SizedBox(height: 12),

          // ── Actions ──────────────────────────────────────────────────────
          Row(children: [
            // Aller récupérer (action principale)
            Expanded(
              flex: 3,
              child: FilledButton.icon(
                onPressed: onNavigate,
                icon: const Icon(Icons.alt_route_rounded, size: 16),
                label: const Text('Aller récupérer',
                    style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: KColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Mode AR
            _ActionBtn(
              icon: Icons.view_in_ar_rounded,
              color: const Color(0xFF7C3AED),
              tooltip: 'Mode AR',
              onTap: onArView,
            ),
            const SizedBox(width: 8),
            // Message
            _ActionBtn(
              icon: Icons.chat_bubble_outline_rounded,
              color: KColors.primary,
              tooltip: 'Message',
              onTap: onMessage,
            ),
          ]),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
      );
}
