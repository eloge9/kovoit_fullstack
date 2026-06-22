import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/osrm_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/k_button.dart';
import '../../trajets/providers/trajet_provider.dart';

class ConducteurGpsPage extends ConsumerStatefulWidget {
  final int trajetId;
  final String depart;
  final String destination;
  final double? departLat;
  final double? departLng;
  final double? destinationLat;
  final double? destinationLng;

  const ConducteurGpsPage({
    super.key,
    required this.trajetId,
    required this.depart,
    required this.destination,
    this.departLat,
    this.departLng,
    this.destinationLat,
    this.destinationLng,
  });

  @override
  ConsumerState<ConducteurGpsPage> createState() => _ConducteurGpsPageState();
}

class _ConducteurGpsPageState extends ConsumerState<ConducteurGpsPage> {
  final _locationService = LocationService();
  final _mapController = MapController();
  Position? _currentPosition;
  List<LatLng> _routePoints = [];
  bool _isTracking = false;
  bool _isEnding = false;

  @override
  void initState() {
    super.initState();
    _startTracking();
    if (widget.departLat != null &&
        widget.departLng != null &&
        widget.destinationLat != null &&
        widget.destinationLng != null) {
      _chargerRoute();
    }
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
    if (_currentPosition == null && _routePoints.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(_routePoints);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
      );
    }
  }

  Future<void> _startTracking() async {
    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;

    setState(() {
      _currentPosition = pos;
      _isTracking = true;
    });

    if (pos != null) {
      _mapController.move(LatLng(pos.latitude, pos.longitude), 14);
    }

    await _locationService.startSendingLocation(widget.trajetId);

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).listen((position) {
      if (!mounted) return;
      setState(() => _currentPosition = position);
      _mapController.move(LatLng(position.latitude, position.longitude), 14);
    });
  }

  Future<void> _terminerTrajet() async {
    setState(() => _isEnding = true);
    final ok = await ref
        .read(trajetsProvider.notifier)
        .terminerTrajet(widget.trajetId);
    if (!mounted) return;
    setState(() => _isEnding = false);

    if (ok) {
      _locationService.dispose();
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de la fin du trajet'),
          backgroundColor: KColors.error,
        ),
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
    final hasPosition = _currentPosition != null;
    final center = hasPosition
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(6.1375, 1.2123);
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
              'Trajet en cours',
              style: KTextStyles.bodySm.copyWith(
                fontWeight: FontWeight.w700,
                color: KColors.baseContent,
              ),
            ),
            Text(
              '${widget.depart} → ${widget.destination}',
              style: KTextStyles.caption,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (_isTracking)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: KColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: KColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'En direct',
                    style: KTextStyles.caption.copyWith(
                      color: KColors.success,
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
            options: MapOptions(
              initialCenter: center,
              initialZoom: hasPosition ? 14 : 10,
            ),
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
              // Markers départ, destination, position conducteur
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
                  if (hasPosition)
                    Marker(
                      point: center,
                      width: 48,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          color: KColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: KColors.primary.withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_car_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ── Panneau infos en bas ──────────────────────────────────────────
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
                  if (hasPosition) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.my_location,
                          color: KColors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, '
                            'Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}',
                            style: KTextStyles.caption,
                          ),
                        ),
                        Text(
                          '${(_currentPosition!.speed * 3.6).toStringAsFixed(0)} km/h',
                          style: KTextStyles.bodySm.copyWith(
                            fontWeight: FontWeight.w700,
                            color: KColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: KSpacing.lg),
                    const Divider(color: KColors.border),
                    const SizedBox(height: KSpacing.lg),
                  ],
                  KButton(
                    label: 'Terminer le trajet',
                    icon: Icons.flag_rounded,
                    isLoading: _isEnding,
                    variant: KButtonVariant.success,
                    onPressed: _isEnding
                        ? null
                        : () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Terminer le trajet ?'),
                                content: const Text(
                                  'Confirmez-vous la fin du trajet ? '
                                  'Les passagers seront notifiés.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Annuler'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: KColors.success,
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Terminer'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) _terminerTrajet();
                          },
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
