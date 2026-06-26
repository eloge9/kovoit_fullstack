import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../trajets/models/escale_model.dart';
import '../../trajets/providers/trajet_provider.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/osrm_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';

class PassagerSuiviPage extends ConsumerStatefulWidget {
  final int trajetId;
  final String depart;
  final String destination;
  final String conducteurNom;
  final double? departLat;
  final double? departLng;
  final double? destinationLat;
  final double? destinationLng;

  const PassagerSuiviPage({
    super.key,
    required this.trajetId,
    required this.depart,
    required this.destination,
    required this.conducteurNom,
    this.departLat,
    this.departLng,
    this.destinationLat,
    this.destinationLng,
  });

  @override
  ConsumerState<PassagerSuiviPage> createState() => _PassagerSuiviPageState();
}

class _PassagerSuiviPageState extends ConsumerState<PassagerSuiviPage>
    with TickerProviderStateMixin {
  final _locationService = LocationService();
  final _mapController = MapController();

  LocationData? _conducteurData;
  LatLng? _conducteurPosition;
  List<LatLng> _routePoints = [];
  List<EscaleModel> _escales = [];
  bool _showPanel = true;

  // Métriques
  double _distanceRestanteKm = 0;
  int _etaMinutes = 0;
  String _statusText = 'Connexion en cours…';

  // Animation marqueur conducteur (pulse)
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Animation mouvement fluide du marqueur
  late AnimationController _moveCtrl;
  Animation<LatLng>? _posAnimation;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _moveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addListener(_onMoveUpdate);

    _connect();
    _chargerRoute();
    _chargerEscales();
  }

  Future<void> _connect() async {
    await _locationService.startReceivingLocation(widget.trajetId);
    if (!mounted) return;
    setState(() => _statusText = 'Connecté');

    _locationService.locationStream?.listen(
      (data) {
        if (!mounted) return;
        final newPos = LatLng(data.latitude, data.longitude);
        _animateMarker(_conducteurPosition, newPos);

        setState(() {
          _conducteurData = data;
          _conducteurPosition = newPos;
          _statusText = _buildStatusText(data);
        });

        _updateEta(data);
        _mapController.move(newPos, 15);
      },
      onError: (e) {
        if (mounted) setState(() => _statusText = 'Reconnexion…');
      },
    );
  }

  void _onMoveUpdate() {
    if (mounted) setState(() {});
  }

  void _animateMarker(LatLng? from, LatLng to) {
    if (from == null) return;
    _posAnimation = LatLngTween(begin: from, end: to).animate(
      CurvedAnimation(parent: _moveCtrl, curve: Curves.easeOut),
    );
    _moveCtrl
      ..reset()
      ..forward();
  }

  String _buildStatusText(LocationData data) {
    if (_distanceRestanteKm > 0 && _etaMinutes > 0) {
      return 'Arrive dans $_etaMinutes min • ${data.speedKmh.toStringAsFixed(0)} km/h';
    }
    return '${data.speedKmh.toStringAsFixed(0)} km/h';
  }

  void _updateEta(LocationData data) {
    if (widget.destinationLat == null) return;
    final dist = LocationService.distanceKm(
      data.latitude, data.longitude,
      widget.destinationLat!, widget.destinationLng!,
    );
    final eta = data.speedKmh > 2
        ? LocationService.etaMinutes(dist, data.speedKmh)
        : _etaMinutes;
    if (!mounted) return;
    setState(() {
      _distanceRestanteKm = dist;
      if (eta > 0) _etaMinutes = eta;
    });
  }

  Future<void> _chargerRoute() async {
    if (widget.departLat == null || widget.destinationLat == null) return;
    final route = await OsrmService.getRoute(
      widget.departLat!, widget.departLng!,
      widget.destinationLat!, widget.destinationLng!,
    );
    if (!mounted || route == null) return;
    setState(() {
      _routePoints = route.points;
      _distanceRestanteKm = route.distanceKm;
      _etaMinutes = route.durationMin;
    });
    if (_conducteurPosition == null && _routePoints.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(_routePoints);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
      );
    }
  }

  Future<void> _chargerEscales() async {
    try {
      final escales =
          await ref.read(trajetRepositoryProvider).getEscales(widget.trajetId);
      if (!mounted) return;
      setState(() => _escales = escales);
    } catch (e) {
      debugPrint('[PassagerSuivi] chargerEscales error: $e');
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _moveCtrl.dispose();
    _locationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = _conducteurPosition ?? const LatLng(6.1375, 1.2123);
    final hasDepart = widget.departLat != null;
    final hasDest = widget.destinationLat != null;
    final hasDriver = _conducteurPosition != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Carte plein écran ─────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13,
              onTap: (_, _) =>
                  setState(() => _showPanel = !_showPanel),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.kovoit.mobile',
                retinaMode: true,
              ),
              // Route
              if (_routePoints.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 5,
                    color: KColors.primary,
                  ),
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 10,
                    color: KColors.primary.withValues(alpha: 0.15),
                  ),
                ]),
              MarkerLayer(markers: [
                // Départ
                if (hasDepart)
                  Marker(
                    point: LatLng(widget.departLat!, widget.departLng!),
                    width: 36, height: 36,
                    child: _buildPin(KColors.primary, Icons.trip_origin),
                  ),
                // Destination
                if (hasDest)
                  Marker(
                    point: LatLng(widget.destinationLat!, widget.destinationLng!),
                    width: 36, height: 36,
                    child: _buildPin(KColors.error, Icons.location_on),
                  ),
                // Conducteur animé — position interpolée
                if (hasDriver)
                  Marker(
                    point: _posAnimation?.value ?? _conducteurPosition!,
                    width: 60, height: 60,
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, _) => Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 55 * _pulseAnim.value,
                            height: 55 * _pulseAnim.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: KColors.success.withValues(
                                  alpha: 0.25 * (1 - _pulseAnim.value + 0.5)),
                            ),
                          ),
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: KColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [BoxShadow(
                                color: KColors.success.withValues(alpha: 0.5),
                                blurRadius: 12,
                                spreadRadius: 2,
                              )],
                            ),
                            child: const Icon(
                              Icons.directions_car_rounded,
                              color: Colors.white, size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Escales
                for (final e in _escales)
                  if (e.lat != null && e.lng != null)
                    Marker(
                      point: LatLng(e.lat!, e.lng!),
                      width: 30, height: 30,
                      child: Tooltip(
                        message: e.nom,
                        child: Container(
                          decoration: BoxDecoration(
                            color: e.isParti
                                ? KColors.success
                                : e.isArrive
                                    ? KColors.warning
                                    : const Color(0xFFFF8C00),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            e.isParti ? Icons.check : Icons.stop_circle_outlined,
                            color: Colors.white, size: 13,
                          ),
                        ),
                      ),
                    ),
              ]),
            ],
          ),

          // ── Barre supérieure ──────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                _MapButton(
                  icon: Icons.arrow_back,
                  onTap: () => context.pop(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                      )],
                    ),
                    child: Row(children: [
                      // Indicateur connexion
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasDriver ? KColors.success : KColors.warning,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.conducteurNom,
                              style: KTextStyles.bodySm.copyWith(
                                  fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              hasDriver ? _statusText : 'En attente de position…',
                              style: KTextStyles.caption,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          ),

          // ── ETA banner si conducteur positionné ───────────────────────────
          if (hasDriver && _etaMinutes > 0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 12, right: 12,
              child: _EtaBanner(
                etaMinutes: _etaMinutes,
                distanceKm: _distanceRestanteKm,
                speedKmh: _conducteurData?.speedKmh ?? 0,
              ),
            ),

          // ── Attente de la position du conducteur ──────────────────────────
          if (!hasDriver)
            Center(
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 16,
                  )],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(color: KColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    'En attente de la position\nde ${widget.conducteurNom}…',
                    textAlign: TextAlign.center,
                    style: KTextStyles.bodySm.copyWith(
                        color: KColors.baseContentMid),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Le conducteur doit avoir démarré le trajet.',
                    textAlign: TextAlign.center,
                    style: KTextStyles.caption,
                  ),
                ]),
              ),
            ),

          // ── Panneau bas ───────────────────────────────────────────────────
          if (_showPanel)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _BottomInfoPanel(
                depart: widget.depart,
                destination: widget.destination,
                escales: _escales,
                onClose: () => setState(() => _showPanel = false),
              ),
            )
          else
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              right: 16,
              child: _MapButton(
                icon: Icons.info_outline,
                onTap: () => setState(() => _showPanel = true),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPin(Color color, IconData icon) => Container(
        decoration: BoxDecoration(
          color: color, shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [BoxShadow(
            color: color.withValues(alpha: 0.4), blurRadius: 6)],
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      );
}

// ── Tween d'interpolation de position ────────────────────────────────────────

class LatLngTween extends Tween<LatLng> {
  LatLngTween({required super.begin, required super.end});

  @override
  LatLng lerp(double t) => LatLng(
        begin!.latitude + (end!.latitude - begin!.latitude) * t,
        begin!.longitude + (end!.longitude - begin!.longitude) * t,
      );
}

// ── Widgets locaux ────────────────────────────────────────────────────────────

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
            )],
          ),
          child: Icon(icon, size: 22, color: KColors.baseContent),
        ),
      );
}

class _EtaBanner extends StatelessWidget {
  final int etaMinutes;
  final double distanceKm;
  final double speedKmh;

  const _EtaBanner({
    required this.etaMinutes,
    required this.distanceKm,
    required this.speedKmh,
  });

  @override
  Widget build(BuildContext context) {
    final distLabel = distanceKm >= 1
        ? '${distanceKm.toStringAsFixed(1)} km'
        : '${(distanceKm * 1000).toInt()} m';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: KColors.success,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color: KColors.success.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        )],
      ),
      child: Row(children: [
        const Icon(Icons.directions_car_rounded, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(
          'Conducteur à $etaMinutes min ($distLabel)',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        )),
        if (speedKmh > 1)
          Text(
            '${speedKmh.toStringAsFixed(0)} km/h',
            style: const TextStyle(
              color: Colors.white70, fontSize: 12,
            ),
          ),
      ]),
    );
  }
}

class _BottomInfoPanel extends StatelessWidget {
  final String depart;
  final String destination;
  final List<EscaleModel> escales;
  final VoidCallback onClose;

  const _BottomInfoPanel({
    required this.depart,
    required this.destination,
    required this.escales,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 20,
          offset: const Offset(0, -4),
        )],
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20, 12, 20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle + close
        Row(children: [
          const Spacer(),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: KColors.base300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.keyboard_arrow_down,
                color: KColors.baseContentMid),
          ),
        ]),
        const SizedBox(height: 12),

        // Route
        Text('ITINÉRAIRE', style: KTextStyles.label),
        const SizedBox(height: 8),
        _RouteRow(icon: Icons.trip_origin, color: KColors.primary, text: depart),
        const SizedBox(height: 4),
        _RouteRow(icon: Icons.location_on, color: KColors.error, text: destination),

        // Escales
        if (escales.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(color: KColors.border),
          const SizedBox(height: 8),
          Text('ÉTAPES (${escales.length})', style: KTextStyles.label),
          const SizedBox(height: 8),
          ...escales.map((e) => _EscaleRow(escale: e)),
        ],

        const SizedBox(height: 8),
      ]),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _RouteRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 8),
        Expanded(child: Text(text,
            style: KTextStyles.bodySm,
            overflow: TextOverflow.ellipsis)),
      ]);
}

class _EscaleRow extends StatelessWidget {
  final EscaleModel escale;
  const _EscaleRow({required this.escale});

  @override
  Widget build(BuildContext context) {
    final color = escale.isParti
        ? KColors.success
        : escale.isArrive
            ? KColors.warning
            : KColors.baseContentMid;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(
            escale.isParti
                ? Icons.check
                : escale.isArrive
                    ? Icons.pause_circle_outline
                    : Icons.radio_button_unchecked,
            color: Colors.white, size: 12,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(escale.nom, style: KTextStyles.bodySm)),
        Text(
          escale.isParti
              ? 'Parti'
              : escale.isArrive
                  ? 'À l\'étape'
                  : 'En attente',
          style: KTextStyles.caption.copyWith(color: color),
        ),
      ]),
    );
  }
}
