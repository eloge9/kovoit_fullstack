import 'package:flutter/material.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/k_button.dart';

/// Panneau bas conducteur — liste de tous les passagers (GPS ou non) avec statut d'embarquement.
class PassengersBottomPanel extends StatefulWidget {
  final List<PassagerReservation> passengers;
  final double? driverLat;
  final double? driverLng;
  final double speedKmh;
  final bool isEnding;
  final VoidCallback onTerminer;
  final void Function(PassagerReservation) onNavigate;
  final void Function(PassagerReservation) onArView;
  final void Function(PassagerReservation) onTap;
  final void Function(PassagerReservation) onScan;

  const PassengersBottomPanel({
    super.key,
    required this.passengers,
    required this.speedKmh,
    required this.isEnding,
    required this.onTerminer,
    required this.onNavigate,
    required this.onArView,
    required this.onTap,
    required this.onScan,
    this.driverLat,
    this.driverLng,
  });

  @override
  State<PassengersBottomPanel> createState() => _PassengersBottomPanelState();
}

class _PassengersBottomPanelState extends State<PassengersBottomPanel> {
  bool _expanded = true;

  int get _boardedCount =>
      widget.passengers.where((p) => p.statutEmbarquement == 'embarque').length;

  bool get _allAboard =>
      widget.passengers.isNotEmpty &&
      widget.passengers.every((p) => p.statutEmbarquement == 'embarque');

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
          // ── Handle + résumé ───────────────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Column(
                children: [
                  Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: KColors.base300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _allAboard
                              ? KColors.success.withValues(alpha: 0.12)
                              : KColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _allAboard ? Icons.check_circle_rounded : Icons.people_rounded,
                              size: 14,
                              color: _allAboard ? KColors.success : KColors.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$_boardedCount/${widget.passengers.length} à bord',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _allAboard ? KColors.success : KColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        _expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                        size: 20,
                        color: KColors.baseContentMid,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Tous à bord — bannière ────────────────────────────────────────
          if (_allAboard && _expanded)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: KColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: KColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.emoji_people_rounded, color: KColors.success, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tous les passagers sont à bord !',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: KColors.success,
                            fontSize: 14,
                          )),
                      Text('Vous pouvez démarrer le trajet.',
                          style: TextStyle(fontSize: 12, color: KColors.baseContentMid)),
                    ],
                  ),
                ),
              ]),
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
                  onTap:      () => widget.onTap(widget.passengers[i]),
                  onNavigate: () => widget.onNavigate(widget.passengers[i]),
                  onArView:   () => widget.onArView(widget.passengers[i]),
                  onScan:     () => widget.onScan(widget.passengers[i]),
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
                        'Confirmez-vous la fin du trajet ?\nLes passagers seront notifiés.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Annuler')),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: KColors.success),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Terminer',
                              style: TextStyle(color: Colors.white))),
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

// ── Carte passager ─────────────────────────────────────────────────────────────

class _PassengerCard extends StatelessWidget {
  final PassagerReservation passenger;
  final double? driverLat;
  final double? driverLng;
  final double speedKmh;
  final VoidCallback onTap;
  final VoidCallback onNavigate;
  final VoidCallback onArView;
  final VoidCallback onScan;

  const _PassengerCard({
    required this.passenger,
    required this.speedKmh,
    required this.onTap,
    required this.onNavigate,
    required this.onArView,
    required this.onScan,
    this.driverLat,
    this.driverLng,
  });

  Color get _statusColor => switch (passenger.statutEmbarquement) {
        'embarque' => KColors.success,
        'absent'   => KColors.error,
        _          => const Color(0xFFFF8C00),
      };

  @override
  Widget build(BuildContext context) {
    double? distKm;
    int? etaMin;
    if (driverLat != null && passenger.hasGps) {
      distKm = LocationService.distanceKm(
        driverLat!, driverLng!,
        passenger.latitude!, passenger.longitude!,
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KColors.base100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: passenger.estEmbarque
                ? KColors.success.withValues(alpha: 0.3)
                : KColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: passenger.photoUrl != null
                        ? ClipOval(child: Image.network(passenger.photoUrl!, fit: BoxFit.cover))
                        : Icon(Icons.person_rounded, color: _statusColor, size: 22),
                  ),
                  // Point GPS
                  if (passenger.hasGps)
                    Positioned(
                      right: 0, bottom: 0,
                      child: Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: KColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(passenger.nom,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: KColors.baseContent,
                        )),
                    Row(children: [
                      _MiniStatusBadge(statut: passenger.statutEmbarquement),
                      if (distLabel != null) ...[
                        const SizedBox(width: 6),
                        Text(distLabel,
                            style: const TextStyle(fontSize: 11, color: KColors.baseContentMid)),
                        if (etaMin != null && etaMin > 0) ...[
                          const Text(' · ',
                              style: TextStyle(color: KColors.baseContentMid, fontSize: 11)),
                          Text('$etaMin min',
                              style: const TextStyle(
                                fontSize: 11,
                                color: KColors.primary,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ],
                    ]),
                  ],
                ),
              ),
              // Actions rapides
              if (!passenger.estEmbarque && !passenger.estAbsent)
                _SmallBtn(
                  icon: Icons.qr_code_scanner_rounded,
                  color: KColors.primary,
                  onTap: onScan,
                ),
              if (passenger.estEmbarque)
                const Icon(Icons.check_circle_rounded, color: KColors.success, size: 22),
              if (passenger.estAbsent)
                const Icon(Icons.person_off_rounded, color: KColors.error, size: 22),
            ]),

            if (!passenger.estEmbarque) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    onPressed: onNavigate,
                    icon: const Icon(Icons.alt_route_rounded, size: 15),
                    label: const Text('Aller récupérer', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: KColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _SmallBtn(
                  icon: Icons.view_in_ar_rounded,
                  color: const Color(0xFF7C3AED),
                  onTap: onArView,
                ),
                const SizedBox(width: 8),
                _SmallBtn(
                  icon: Icons.touch_app_rounded,
                  color: KColors.baseContentMid,
                  onTap: onTap,
                  tooltip: 'Détails',
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStatusBadge extends StatelessWidget {
  final String statut;
  const _MiniStatusBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    final (Color c, String label) = switch (statut) {
      'embarque' => (KColors.success, '✓ À bord'),
      'absent'   => (KColors.error,   '✗ Absent'),
      _          => (const Color(0xFFE65100), '⏳ En attente'),
    };
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: c,
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;

  const _SmallBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip ?? '',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 38, height: 38,
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
