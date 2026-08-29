import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/boarding_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/colors.dart';

class PassengerBoardingSheet extends StatefulWidget {
  final PassagerReservation passenger;
  final double? driverLat;
  final double? driverLng;
  final double speedKmh;
  final VoidCallback onNavigate;
  final VoidCallback onCenter;
  final VoidCallback onArView;
  final void Function(PassagerReservation updated) onBoarded;
  final VoidCallback onMarquerAbsent;
  final int trajetId;

  const PassengerBoardingSheet({
    super.key,
    required this.passenger,
    required this.onNavigate,
    required this.onCenter,
    required this.onArView,
    required this.onBoarded,
    required this.onMarquerAbsent,
    required this.trajetId,
    this.driverLat,
    this.driverLng,
    this.speedKmh = 0,
  });

  @override
  State<PassengerBoardingSheet> createState() => _PassengerBoardingSheetState();
}

class _PassengerBoardingSheetState extends State<PassengerBoardingSheet> {
  late PassagerReservation _passenger;
  bool _scanning = false;
  bool _loading = false;
  String? _feedback;
  bool _feedbackOk = false;
  bool _cantFind = false;

  @override
  void initState() {
    super.initState();
    _passenger = widget.passenger;
  }

  String get _distLabel {
    if (widget.driverLat == null || !_passenger.hasGps) return '';
    final dist = LocationService.distanceKm(
      widget.driverLat!, widget.driverLng!,
      _passenger.latitude!, _passenger.longitude!,
    );
    if (dist < 1) return '${(dist * 1000).toInt()} m';
    return '${dist.toStringAsFixed(1)} km';
  }

  String get _etaLabel {
    if (widget.driverLat == null || !_passenger.hasGps || widget.speedKmh < 2) return '';
    final dist = LocationService.distanceKm(
      widget.driverLat!, widget.driverLng!,
      _passenger.latitude!, _passenger.longitude!,
    );
    final eta = LocationService.etaMinutes(dist, widget.speedKmh);
    if (eta <= 0) return '';
    return '$eta min';
  }

  Future<void> _handleQrResult(String raw) async {
    if (_loading) return;
    setState(() { _scanning = false; _loading = true; });

    final trimmed = raw.trim();
    late BoardingResult result;

    // Format 1 (passager mobile) : code KVT-XXXX affiché en QR
    // Format 2 (optionnel futur) : KOVOIT:{reservationId}:{token}
    if (trimmed.toUpperCase().startsWith('KVT-') ||
        RegExp(r'^[A-Z0-9]{3}-[A-Z0-9]{4,}$', caseSensitive: false).hasMatch(trimmed)) {
      result = await BoardingService.embarquerParCode(trimmed);
    } else {
      final parts = trimmed.split(':');
      if (parts.length >= 3 && parts[0].toUpperCase() == 'KOVOIT') {
        final resId = int.tryParse(parts[1]);
        final token = parts.sublist(2).join(':');
        if (resId != null) {
          result = await BoardingService.validerQR(resId, token);
        } else {
          result = (ok: false, message: 'QR corrompu.', passager: null);
        }
      } else {
        // Tenter quand même comme code brut (cas où le QR encode juste le code)
        result = await BoardingService.embarquerParCode(trimmed);
      }
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _feedbackOk = result.ok;
      _feedback = result.message;
      if (result.ok) {
        _passenger = _passenger.copyWithStatut('embarque');
      }
    });

    if (result.ok) {
      widget.onBoarded(_passenger);
    }
  }

  Future<void> _showCodeDialog() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Code d\'embarquement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Demandez au passager son code KVT-XXXX',
              style: TextStyle(fontSize: 13, color: KColors.baseContentMid),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'KVT-XXXX',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.tag_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (ok != true || ctrl.text.isEmpty) return;

    setState(() => _loading = true);
    final result = await BoardingService.embarquerParCode(ctrl.text);
    if (!mounted) return;

    setState(() {
      _loading = false;
      _feedbackOk = result.ok;
      _feedback = result.message;
      if (result.ok) {
        _passenger = _passenger.copyWithStatut('embarque');
      }
    });

    if (result.ok) {
      widget.onBoarded(_passenger);
    }
  }

  void _showCantFindOptions() {
    setState(() { _cantFind = true; _feedback = null; });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: KColors.base300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          if (_scanning) _buildScanner() else _buildContent(),
        ],
      ),
    );
  }

  Widget _buildScanner() {
    return SizedBox(
      height: 340,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: MobileScanner(
              onDetect: (capture) {
                final barcode = capture.barcodes.firstOrNull;
                if (barcode?.rawValue != null) {
                  _handleQrResult(barcode!.rawValue!);
                }
              },
            ),
          ),
          Positioned(
            top: 12, left: 12,
            child: GestureDetector(
              onTap: () => setState(() => _scanning = false),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text(
                  'Pointez la caméra sur le QR du passager',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20, 8, 20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildQuickActions(),
          const SizedBox(height: 16),
          if (_feedback != null) _buildFeedback(),
          if (_cantFind)
            _buildCantFindOptions()
          else ...[
            _buildBoardingSection(),
            const SizedBox(height: 12),
            if (!_passenger.estEmbarque)
              _buildCantFindBtn(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        _Avatar(passenger: _passenger),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _passenger.nom,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: KColors.baseContent,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  _StatusBadge(statut: _passenger.statutEmbarquement),
                  if (_distLabel.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      _distLabel,
                      style: const TextStyle(fontSize: 12, color: KColors.baseContentMid),
                    ),
                  ],
                  if (_etaLabel.isNotEmpty) ...[
                    const Text(' · ', style: TextStyle(fontSize: 12, color: KColors.baseContentMid)),
                    Text(
                      _etaLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: KColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        _QuickBtn(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Message',
          onTap: () {
            Navigator.pop(context);
          },
        ),
        const SizedBox(width: 8),
        _QuickBtn(
          icon: Icons.phone_rounded,
          label: 'Appeler',
          enabled: _passenger.phone != null,
          onTap: _passenger.phone == null
              ? null
              : () async {
                  await launchUrl(Uri(scheme: 'tel', path: _passenger.phone!));
                },
        ),
        const SizedBox(width: 8),
        _QuickBtn(
          icon: Icons.alt_route_rounded,
          label: 'Naviguer',
          onTap: () {
            Navigator.pop(context);
            widget.onNavigate();
          },
        ),
        const SizedBox(width: 8),
        _QuickBtn(
          icon: Icons.my_location_rounded,
          label: 'Centrer',
          enabled: _passenger.hasGps,
          onTap: _passenger.hasGps
              ? () {
                  Navigator.pop(context);
                  widget.onCenter();
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildBoardingSection() {
    if (_passenger.estEmbarque) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: KColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KColors.success.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: KColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: KColors.success, size: 22),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('À bord',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: KColors.success,
                      fontSize: 15,
                    )),
                Text('Embarquement confirmé',
                    style: TextStyle(fontSize: 12, color: KColors.baseContentMid)),
              ],
            ),
          ],
        ),
      );
    }

    if (_passenger.estAbsent) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: KColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KColors.error.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          const Icon(Icons.person_off_rounded, color: KColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Marqué absent',
                  style: TextStyle(fontWeight: FontWeight.w700, color: KColors.error)),
              const SizedBox(height: 4),
              Row(children: [
                _AbsentBtn(label: 'Appeler', icon: Icons.phone_rounded, onTap: _passenger.phone == null
                    ? null
                    : () async { await launchUrl(Uri(scheme: 'tel', path: _passenger.phone!)); }),
                const SizedBox(width: 8),
                _AbsentBtn(label: 'Message', icon: Icons.chat_bubble_outline_rounded, onTap: () {
                  Navigator.pop(context);
                }),
                const SizedBox(width: 8),
                _AbsentBtn(label: 'Continuer', icon: Icons.arrow_forward_rounded, onTap: () {
                  Navigator.pop(context);
                }),
              ]),
            ]),
          ),
        ]),
      );
    }

    // En attente → boutons scan + code
    return Column(
      children: [
        const Text(
          'Valider l\'embarquement',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: KColors.baseContentMid,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ))
                  : FilledButton.icon(
                      onPressed: () => setState(() => _scanning = true),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                      label: const Text('Scanner QR'),
                      style: FilledButton.styleFrom(
                        backgroundColor: KColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _showCodeDialog,
                icon: const Icon(Icons.keyboard_rounded, size: 18),
                label: const Text('Saisir le code'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: const BorderSide(color: KColors.border),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeedback() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (_feedbackOk ? KColors.success : KColors.error).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (_feedbackOk ? KColors.success : KColors.error).withValues(alpha: 0.25),
        ),
      ),
      child: Row(children: [
        Icon(
          _feedbackOk ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
          color: _feedbackOk ? KColors.success : KColors.error,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _feedback!,
            style: TextStyle(
              fontSize: 13,
              color: _feedbackOk ? KColors.success : KColors.error,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildCantFindBtn() {
    return GestureDetector(
      onTap: _showCantFindOptions,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Text(
            'Je ne trouve pas ce passager',
            style: TextStyle(
              fontSize: 13,
              color: KColors.baseContentMid,
              decoration: TextDecoration.underline,
              decorationColor: KColors.baseContentMid,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCantFindOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KColors.base100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Que souhaitez-vous faire ?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: KColors.baseContent),
          ),
          const SizedBox(height: 12),
          _CantFindOption(
            icon: Icons.phone_rounded,
            label: 'Appeler le passager',
            enabled: _passenger.phone != null,
            onTap: _passenger.phone == null
                ? null
                : () async { await launchUrl(Uri(scheme: 'tel', path: _passenger.phone!)); },
          ),
          _CantFindOption(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Lui envoyer un message',
            onTap: () { Navigator.pop(context); },
          ),
          _CantFindOption(
            icon: Icons.person_off_rounded,
            label: 'Marquer comme absent',
            color: KColors.error,
            onTap: () {
              Navigator.pop(context);
              widget.onMarquerAbsent();
            },
          ),
          _CantFindOption(
            icon: Icons.arrow_forward_rounded,
            label: 'Continuer sans ce passager',
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

// ── Widgets locaux ─────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final PassagerReservation passenger;
  const _Avatar({required this.passenger});

  @override
  Widget build(BuildContext context) {
    final color = passenger.estEmbarque
        ? KColors.success
        : passenger.estAbsent
            ? KColors.error
            : const Color(0xFFFF8C00);

    if (passenger.photoUrl != null && passenger.photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: color.withValues(alpha: 0.15),
        backgroundImage: NetworkImage(passenger.photoUrl!),
      );
    }
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person_rounded, color: color, size: 28),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String statut;
  const _StatusBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (statut) {
      'embarque' => (KColors.success.withValues(alpha: 0.12), KColors.success, '🟢 À bord'),
      'absent'   => (KColors.error.withValues(alpha: 0.12),   KColors.error,   '🔴 Absent'),
      _          => (const Color(0xFFFFF3E0),                  const Color(0xFFE65100), '🟡 En attente'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  const _QuickBtn({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && onTap != null;
    return Expanded(
      child: GestureDetector(
        onTap: active ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? KColors.primary.withValues(alpha: 0.08) : KColors.base200,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? KColors.primary.withValues(alpha: 0.2) : KColors.border,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: active ? KColors.primary : KColors.baseContentMid),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: active ? KColors.primary : KColors.baseContentMid,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AbsentBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _AbsentBtn({required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: onTap != null ? KColors.error.withValues(alpha: 0.08) : KColors.base200,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: onTap != null ? KColors.error.withValues(alpha: 0.25) : KColors.border,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: onTap != null ? KColors.error : KColors.baseContentMid),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  color: onTap != null ? KColors.error : KColors.baseContentMid,
                  fontWeight: FontWeight.w600,
                )),
          ]),
        ),
      );
}

class _CantFindOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final bool enabled;

  const _CantFindOption({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && onTap != null;
    final c = color ?? (active ? KColors.baseContent : KColors.baseContentMid);
    return GestureDetector(
      onTap: active ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 14, color: c, fontWeight: FontWeight.w500)),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, size: 18, color: KColors.baseContentMid),
        ]),
      ),
    );
  }
}
