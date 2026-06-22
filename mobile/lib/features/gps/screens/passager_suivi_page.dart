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
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_button.dart';

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

class _PassagerSuiviPageState extends ConsumerState<PassagerSuiviPage> {
  final _locationService = LocationService();
  final _mapController = MapController();
  LatLng? _conducteurPosition;
  List<LatLng> _routePoints = [];
  List<EscaleModel> _escales = [];
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _connect();
    if (widget.departLat != null &&
        widget.departLng != null &&
        widget.destinationLat != null &&
        widget.destinationLng != null) {
      _chargerRoute();
    }
    _chargerEscales();
  }

  Future<void> _chargerEscales() async {
    try {
      final escales = await ref
          .read(trajetRepositoryProvider)
          .getEscales(widget.trajetId);
      if (!mounted) return;
      setState(() => _escales = escales);
    } catch (e) {
      debugPrint('[PassagerSuivi] chargerEscales error: $e');
    }
  }

  Future<void> _connect() async {
    await _locationService.startReceivingLocation(widget.trajetId);
    setState(() => _isConnected = true);

    _locationService.locationStream?.listen((loc) {
      if (!mounted) return;
      final pos = LatLng(loc['latitude']!, loc['longitude']!);
      setState(() => _conducteurPosition = pos);
      _mapController.move(pos, 14);
    });
  }

  Future<void> _chargerRoute() async {
    final route = await OsrmService.getRoute(
      widget.departLat!,
      widget.departLng!,
      widget.destinationLat!,
      widget.destinationLng!,
    );
    if (!mounted || route == null) return;
    setState(() => _routePoints = route.points);
    if (_conducteurPosition == null && _routePoints.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(_routePoints);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
      );
    }
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = _conducteurPosition ?? const LatLng(6.1375, 1.2123);
    final hasDepart = widget.departLat != null && widget.departLng != null;
    final hasDest = widget.destinationLat != null && widget.destinationLng != null;

    return Scaffold(
      backgroundColor: KColors.base200,
      appBar: AppBar(
        backgroundColor: KColors.base100,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: KColors.border)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: KColors.baseContent),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suivi en direct',
              style: KTextStyles.bodySm.copyWith(
                fontWeight: FontWeight.w700,
                color: KColors.baseContent,
              ),
            ),
            Text(widget.conducteurNom, style: KTextStyles.caption),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (_isConnected && _conducteurPosition != null
                      ? KColors.success
                      : KColors.warning)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isConnected && _conducteurPosition != null
                        ? KColors.success
                        : KColors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _conducteurPosition != null ? 'En direct' : 'Connexion…',
                  style: KTextStyles.caption.copyWith(
                    color: _conducteurPosition != null
                        ? KColors.success
                        : KColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Carte ────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: center, initialZoom: 13),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.kovoit.mobile',
              ),
              // Polyline route OSRM
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4,
                      color: KColors.primary.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              // Markers départ, destination, conducteur
              MarkerLayer(
                markers: [
                  if (hasDepart)
                    Marker(
                      point: LatLng(widget.departLat!, widget.departLng!),
                      width: 36,
                      height: 36,
                      child: Container(
                        decoration: BoxDecoration(
                          color: KColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.trip_origin,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  if (hasDest)
                    Marker(
                      point: LatLng(widget.destinationLat!, widget.destinationLng!),
                      width: 36,
                      height: 36,
                      child: Container(
                        decoration: BoxDecoration(
                          color: KColors.error,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  if (_conducteurPosition != null)
                    Marker(
                      point: _conducteurPosition!,
                      width: 52,
                      height: 52,
                      child: Container(
                        decoration: BoxDecoration(
                          color: KColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: KColors.primary.withValues(alpha: 0.4),
                              blurRadius: 16,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_car_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  // Marqueurs escales (orange)
                  for (final e in _escales)
                    if (e.lat != null && e.lng != null)
                      Marker(
                        point: LatLng(e.lat!, e.lng!),
                        width: 32,
                        height: 32,
                        child: Tooltip(
                          message: e.nom,
                          child: Container(
                            decoration: BoxDecoration(
                              color: e.isParti
                                  ? Colors.green
                                  : e.isArrive
                                      ? Colors.orange
                                      : const Color(0xFFFF8C00),
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              e.isParti
                                  ? Icons.check
                                  : Icons.location_on_outlined,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ],
          ),

          // ── Attente position ──────────────────────────────────────────────
          if (_conducteurPosition == null)
            Center(
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: KColors.base100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: KColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      'En attente de la position\nde ${widget.conducteurNom}…',
                      textAlign: TextAlign.center,
                      style: KTextStyles.bodySm.copyWith(
                        color: KColors.baseContentMid,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Info route en bas ─────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: KColors.base100,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                KSpacing.xl,
                KSpacing.xl,
                KSpacing.xl,
                MediaQuery.of(context).padding.bottom + KSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: KSpacing.xl),
                    decoration: BoxDecoration(
                      color: KColors.base300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ITINÉRAIRE', style: KTextStyles.label),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.trip_origin,
                                  color: KColors.primary,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    widget.depart,
                                    style: KTextStyles.bodySm,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: KColors.error,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    widget.destination,
                                    style: KTextStyles.bodySm,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // ── Liste escales ──────────────────────────────────────
                  if (_escales.isNotEmpty) ...[
                    const SizedBox(height: KSpacing.lg),
                    const Divider(color: KColors.border),
                    const SizedBox(height: KSpacing.md),
                    Text('ÉTAPES (${_escales.length})',
                        style: KTextStyles.label),
                    const SizedBox(height: KSpacing.sm),
                    ...(_escales.map((e) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: KSpacing.sm),
                          child: Row(children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: e.isParti
                                    ? Colors.green
                                    : e.isArrive
                                        ? Colors.orange
                                        : const Color(0xFFFF8C00),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                e.isParti
                                    ? Icons.check
                                    : e.isArrive
                                        ? Icons.pause_circle_outline
                                        : Icons.radio_button_unchecked,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(e.nom,
                                    style: KTextStyles.bodySm)),
                            Text(
                              e.isParti
                                  ? 'Parti'
                                  : e.isArrive
                                      ? 'À l\'étape'
                                      : 'En attente',
                              style: KTextStyles.caption.copyWith(
                                color: e.isParti
                                    ? Colors.green
                                    : e.isArrive
                                        ? Colors.orange
                                        : KColors.baseContentMid,
                              ),
                            ),
                          ]),
                        ))),
                  ],
                  const SizedBox(height: KSpacing.lg),
                  KButton(
                    label: 'Retour',
                    variant: KButtonVariant.outline,
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
