import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/boarding_service.dart';
import '../../../core/services/gps_filter.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/navigation_tts_service.dart';
import '../../../core/services/osrm_service.dart';
import '../../../core/services/route_step.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/k_button.dart';
import '../../trajets/providers/trajet_provider.dart';
import '../widgets/ar_world_view.dart';
import '../widgets/passenger_boarding_sheet.dart';
import '../widgets/passengers_bottom_panel.dart';

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

class _ConducteurGpsPageState extends ConsumerState<ConducteurGpsPage>
    with TickerProviderStateMixin {
  final _locationService = LocationService();
  final _tts = NavigationTtsService();
  final _mapController = MapController();
  final _gpsFilter = GpsFilter();
  StreamSubscription<Position>? _posSub;

  Position? _currentPosition;
  List<LatLng> _routePoints = [];
  List<RouteStep> _routeSteps = [];
  bool _isTracking = false;
  bool _isEnding = false;
  bool _navigationMode = true;

  double _distanceRestanteKm = 0;
  int _etaMinutes = 0;
  double _speedKmh = 0;
  String _heureArrivee = '';

  // Tous les passagers (source : API REST + enrichissement WS)
  final Map<String, PassagerReservation> _allPassengers = {};
  StreamSubscription? _passengerPosSub;
  StreamSubscription? _boardedSub;
  final Set<String> _announcedPassengers = {};

  bool _showArMode = false;

  double _currentHeading = 0;
  StreamSubscription<CompassEvent>? _compassSub;
  Timer? _routeRecalcTimer;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

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
    _startTracking();
    _tts.init();
    _loadPassengers();
    _initEtaEstimate();   // ETA immédiat avant qu'OSRM réponde
    _routeRecalcTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (_currentPosition != null) { _recalcRouteFromCurrentPos(); }
    });
  }

  /// Calcule un ETA approximatif dès l'ouverture de la page, avant la réponse OSRM.
  /// Formule : haversine × 1.35 (facteur routier Afrique de l'Ouest) / 65 km/h moy.
  /// OSRM écrase cette valeur dès qu'il répond avec une durée précise.
  void _initEtaEstimate() {
    if (widget.departLat == null || widget.destinationLat == null) return;
    final distStraight = LocationService.distanceKm(
      widget.departLat!, widget.departLng!,
      widget.destinationLat!, widget.destinationLng!,
    );
    if (distStraight <= 0) return;
    const routeFactor = 1.35; // route sinueuse vs vol d'oiseau
    const avgSpeedKmh = 65.0; // vitesse moy intercité Togo/Bénin
    final estDist  = distStraight * routeFactor;
    final estMin   = (estDist / avgSpeedKmh * 60).round();
    setState(() {
      _distanceRestanteKm = estDist;
      _etaMinutes         = estMin;
      _heureArrivee       = _calcHeureArrivee(estMin);
    });
  }

  Future<void> _loadPassengers() async {
    final list = await BoardingService.getPassagers(widget.trajetId);
    if (!mounted) return;
    setState(() {
      for (final p in list) {
        // Préserver la position GPS déjà reçue par WS pour ce passager.
        final existing = _allPassengers[p.userId];
        _allPassengers[p.userId] = (existing != null && existing.hasGps)
            ? p.copyWithGps(existing.latitude!, existing.longitude!)
            : p;
      }
    });
  }

  Future<void> _chargerRoute() async {
    if (widget.destinationLat == null) return;
    final fromLat = _currentPosition?.latitude ?? widget.departLat;
    final fromLng = _currentPosition?.longitude ?? widget.departLng;
    if (fromLat == null || fromLng == null) return;
    final route = await OsrmService.getRoute(
      fromLat, fromLng,
      widget.destinationLat!, widget.destinationLng!,
    );
    if (!mounted || route == null) return;
    setState(() {
      _routePoints = route.points;
      _routeSteps  = route.steps;
      _distanceRestanteKm = route.distanceKm;
      _etaMinutes = route.durationMin;
      _heureArrivee = _calcHeureArrivee(route.durationMin);
    });
    if (_currentPosition == null && _routePoints.isNotEmpty) {
      _fitBounds(_routePoints);
    }
  }

  Future<void> _recalcRouteFromCurrentPos() async {
    if (_currentPosition == null || widget.destinationLat == null) return;
    final route = await OsrmService.getRoute(
      _currentPosition!.latitude, _currentPosition!.longitude,
      widget.destinationLat!, widget.destinationLng!,
    );
    if (!mounted || route == null) return;
    setState(() {
      _routePoints = route.points;
      _routeSteps  = route.steps;
      _distanceRestanteKm = route.distanceKm;
      if (route.durationMin > 0) {
        _etaMinutes = route.durationMin;
        _heureArrivee = _calcHeureArrivee(route.durationMin);
      }
    });
  }

  Future<void> _startTracking() async {
    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;
    if (pos != null) {
      setState(() {
        _currentPosition = pos;
        _isTracking = true;
        _speedKmh = pos.speed * 3.6;
        _currentHeading = pos.heading;
      });
      _moveCameraToPosition(pos);
    }

    await _locationService.startSendingLocation(widget.trajetId);

    _passengerPosSub = _locationService.passengersStream?.listen(_onPassengerPosition);
    _boardedSub = _locationService.boardedStream?.listen(_onPassengerBoarded);

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((rawPosition) {
      if (!mounted) return;
      // Filtre Kalman + rejet des sauts GPS aberrants (> 250 km/h implicite)
      final position = _gpsFilter.update(rawPosition) ?? rawPosition;
      final speedKmh = position.speed * 3.6;
      setState(() {
        _currentPosition = position;
        _speedKmh = speedKmh;
        // GPS heading fiable uniquement au-dessus de 5 km/h
        if (speedKmh >= 5 && position.heading > 0) {
          _currentHeading = _smoothHeading(_currentHeading, position.heading);
        }
        _isTracking = true;
      });
      _updateNavMetrics(position);
      _checkPassengerProximity(position);
      if (_navigationMode) { _moveCameraToPosition(position); }
    });

    // Boussole magnétique : mise à jour temps réel quand stationnaire ou lent
    _compassSub = FlutterCompass.events?.listen((event) {
      if (!mounted || event.heading == null) return;
      if (_speedKmh < 5) {
        setState(() {
          _currentHeading = _smoothHeading(_currentHeading, event.heading!);
        });
      }
    });

    _chargerRoute();
  }

  void _onPassengerPosition(PassengerPositionData p) {
    if (!mounted) return;
    setState(() {
      final existing = _allPassengers[p.userId];
      if (existing != null) {
        _allPassengers[p.userId] = existing.copyWithGps(p.latitude, p.longitude);
      } else {
        // Passager sans réservation connue (ajout dynamique)
        _allPassengers[p.userId] = PassagerReservation(
          reservationId: 0,
          userId: p.userId,
          nom: p.nom,
          placesReservees: 1,
          statutEmbarquement: 'en_attente',
          latitude: p.latitude,
          longitude: p.longitude,
          lastGps: DateTime.now(),
        );
      }
    });
  }

  void _onPassengerBoarded(PassengerBoardedEvent e) {
    if (!mounted) return;
    setState(() {
      final existing = _allPassengers[e.userId];
      if (existing != null) {
        _allPassengers[e.userId] = existing.copyWithStatut('embarque');
      }
    });
    if (_allPassengers.isNotEmpty &&
        _allPassengers.values.every((p) => p.estEmbarque)) {
      _tts.speak('Tous les passagers sont à bord. Vous pouvez démarrer le trajet.');
    }
  }

  void _checkPassengerProximity(Position pos) {
    for (final p in _allPassengers.values) {
      if (!p.hasGps || p.estEmbarque) continue;
      final dist = LocationService.distanceKm(
        pos.latitude, pos.longitude, p.latitude!, p.longitude!,
      );
      if (dist < 0.15 && !_announcedPassengers.contains(p.userId)) {
        _announcedPassengers.add(p.userId);
        _tts.speak('Vous approchez de ${p.nom.split(' ').first}, à ${(dist * 1000).toInt()} mètres');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Vous approchez de ${p.nom.split(' ').first} (${(dist * 1000).toInt()} m)'),
            backgroundColor: KColors.success,
            duration: const Duration(seconds: 6),
          ));
        }
      }
    }
  }

  void _moveCameraToPosition(Position pos) {
    _mapController.move(LatLng(pos.latitude, pos.longitude), 16);
  }

  void _updateNavMetrics(Position position) {
    if (widget.destinationLat == null) return;
    // Distance haversine × facteur routier 1.35 (route sinueuse vs vol d'oiseau).
    // Donne une meilleure approximation de la distance routière restante.
    final distStraight = LocationService.distanceKm(
      position.latitude, position.longitude,
      widget.destinationLat!, widget.destinationLng!,
    );
    final distRoute = distStraight * 1.35;
    final speed = position.speed * 3.6;

    // Seuil 10 km/h : en dessous, le GPS est trop bruité pour calculer un ETA fiable.
    // On conserve la dernière valeur connue (OSRM ou estimation précédente).
    final eta = speed > 10 ? LocationService.etaMinutes(distRoute, speed) : _etaMinutes;
    if (!mounted) return;
    setState(() {
      // On affiche la distance routière estimée (plus réaliste que la ligne droite)
      _distanceRestanteKm = distRoute;
      if (eta > 0) {
        _etaMinutes = eta;
        _heureArrivee = _calcHeureArrivee(eta);
      }
    });
    _tts.announceIfNeeded(
      distanceKm: distRoute,
      etaMinutes: eta > 0 ? eta : _etaMinutes,
      destination: widget.destination,
    );
  }

  // Filtre passe-bas pour lisser les variations brusques du cap (gère le passage 359°→1°)
  double _smoothHeading(double current, double next) {
    const alpha = 0.15;
    final diff = ((next - current + 540) % 360) - 180;
    return (current + alpha * diff + 360) % 360;
  }

  String _calcHeureArrivee(int minutes) {
    final arrival = DateTime.now().add(Duration(minutes: minutes));
    return '${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}';
  }

  void _fitBounds(List<LatLng> points) {
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
    );
  }

  void _openArToPassenger(PassagerReservation p) {
    setState(() => _showArMode = true);
  }

  void _toggleArMode() {
    setState(() => _showArMode = !_showArMode);
  }

  Future<void> _navigateToPassenger(PassagerReservation p) async {
    if (_currentPosition == null || !p.hasGps) return;
    final route = await OsrmService.getRoute(
      _currentPosition!.latitude, _currentPosition!.longitude,
      p.latitude!, p.longitude!,
    );
    if (!mounted || route == null) return;
    setState(() {
      _routePoints = route.points;
      _distanceRestanteKm = route.distanceKm;
      _etaMinutes = route.durationMin;
      _heureArrivee = _calcHeureArrivee(route.durationMin);
    });
    _mapController.move(LatLng(p.latitude!, p.longitude!), 15);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Navigation vers ${p.nom.split(' ').first}'),
        backgroundColor: KColors.primary,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  void _centerOnPassenger(PassagerReservation p) {
    if (!p.hasGps) return;
    _mapController.move(LatLng(p.latitude!, p.longitude!), 16);
  }

  void _openPassengerSheet(PassagerReservation p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PassengerBoardingSheet(
        passenger: p,
        driverLat: _currentPosition?.latitude,
        driverLng: _currentPosition?.longitude,
        speedKmh: _speedKmh,
        trajetId: widget.trajetId,
        onNavigate: () => _navigateToPassenger(p),
        onCenter: () => _centerOnPassenger(p),
        onArView: () => _openArToPassenger(p),
        onBoarded: (updated) {
          setState(() => _allPassengers[updated.userId] = updated);
        },
        onMarquerAbsent: () {
          setState(() {
            _allPassengers[p.userId] = p.copyWithStatut('absent');
          });
        },
      ),
    );
  }

  void _openScanForPassenger(PassagerReservation p) {
    _openPassengerSheet(p);
  }

  Future<void> _terminerTrajet() async {
    setState(() => _isEnding = true);
    final ok = await ref.read(trajetsProvider.notifier).terminerTrajet(widget.trajetId);
    if (!mounted) return;
    setState(() => _isEnding = false);
    if (ok) {
      _locationService.dispose();
      if (context.mounted) { context.pop(); }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Erreur lors de la fin du trajet'),
        backgroundColor: KColors.error,
      ));
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _posSub?.cancel();
    _compassSub?.cancel();
    _passengerPosSub?.cancel();
    _boardedSub?.cancel();
    _routeRecalcTimer?.cancel();
    _locationService.dispose();
    _tts.dispose();
    super.dispose();
  }

  List<PassagerReservation> get _sortedPassengers {
    final list = _allPassengers.values.toList();
    if (_currentPosition == null) return list;
    list.sort((a, b) {
      // Embarqués à la fin
      if (a.estEmbarque != b.estEmbarque) {
        return a.estEmbarque ? 1 : -1;
      }
      // Avec GPS d'abord
      if (a.hasGps != b.hasGps) {
        return a.hasGps ? -1 : 1;
      }
      if (!a.hasGps || !b.hasGps) return 0;
      final da = LocationService.distanceKm(
        _currentPosition!.latitude, _currentPosition!.longitude,
        a.latitude!, a.longitude!,
      );
      final db = LocationService.distanceKm(
        _currentPosition!.latitude, _currentPosition!.longitude,
        b.latitude!, b.longitude!,
      );
      return da.compareTo(db);
    });
    return list;
  }

  bool get _allAboard =>
      _allPassengers.isNotEmpty &&
      _allPassengers.values.every((p) => p.estEmbarque);

  @override
  Widget build(BuildContext context) {
    final hasPosition = _currentPosition != null;
    final center = hasPosition
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(6.1375, 1.2123);
    final hasDepart = widget.departLat != null;
    final hasDest = widget.destinationLat != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Vue AR monde réel ─────────────────────────────────────────────
          if (_showArMode)
            Positioned.fill(
              child: ArWorldView(
                routePoints:       _routePoints,
                routeSteps:        _routeSteps,
                destination:       widget.destination,
                passengers:        _sortedPassengers,
                onBack:            _toggleArMode,
                onBoardingConfirm: _openPassengerSheet,
              ),
            ),

          // ── Carte ─────────────────────────────────────────────────────────
          if (!_showArMode) FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: hasPosition ? 16 : 12,
              onTap: (_, _) => setState(() => _navigationMode = false),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.kovoit.mobile',
                retinaMode: true,
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 6,
                    color: KColors.primary,
                  ),
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 10,
                    color: KColors.primary.withValues(alpha: 0.2),
                  ),
                ]),
              MarkerLayer(markers: [
                if (hasDepart)
                  Marker(
                    point: LatLng(widget.departLat!, widget.departLng!),
                    width: 40, height: 40,
                    child: _buildMarker(KColors.primary, Icons.trip_origin),
                  ),
                if (hasDest)
                  Marker(
                    point: LatLng(widget.destinationLat!, widget.destinationLng!),
                    width: 40, height: 40,
                    child: _buildMarker(KColors.error, Icons.location_on),
                  ),
                if (hasPosition)
                  Marker(
                    point: center,
                    width: 60, height: 60,
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, child) => Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 60 * _pulseAnim.value,
                            height: 60 * _pulseAnim.value,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: KColors.primary.withValues(
                                  alpha: 0.3 * (1 - _pulseAnim.value + 0.5)),
                            ),
                          ),
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: KColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [BoxShadow(
                                color: KColors.primary.withValues(alpha: 0.5),
                                blurRadius: 12,
                                spreadRadius: 2,
                              )],
                            ),
                            child: Transform.rotate(
                              angle: _currentHeading * math.pi / 180,
                              child: const Icon(
                                Icons.navigation_rounded,
                                color: Colors.white, size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Passagers — seulement ceux avec GPS
                for (final p in _sortedPassengers.where((p) => p.hasGps))
                  Marker(
                    point: LatLng(p.latitude!, p.longitude!),
                    width: 80, height: 72,
                    child: GestureDetector(
                      onTap: () => _openPassengerSheet(p),
                      child: _PassengerMapMarker(
                        passenger: p,
                        driverLat: _currentPosition?.latitude,
                        driverLng: _currentPosition?.longitude,
                      ),
                    ),
                  ),
              ]),
            ],
          ),

          // ── Bouton retour + contrôles (masqués en mode AR) ────────────────
          if (!_showArMode) SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _MapButton(
                    icon: Icons.arrow_back,
                    onTap: () => context.pop(),
                  ),
                  const Spacer(),
                  if (_isTracking)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: KColors.success,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('En direct',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            )),
                      ]),
                    ),
                  const SizedBox(width: 8),
                  _MapButton(
                    icon: _tts.isEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: _tts.isEnabled ? KColors.primary : Colors.grey,
                    onTap: () {
                      setState(() => _tts.toggle());
                      if (_tts.isEnabled) { _tts.speak('Guidage vocal activé'); }
                    },
                  ),
                  const SizedBox(width: 8),
                  _MapButton(
                    icon: _navigationMode
                        ? Icons.navigation_rounded
                        : Icons.navigation_outlined,
                    color: _navigationMode ? KColors.primary : Colors.grey,
                    onTap: () {
                      setState(() => _navigationMode = !_navigationMode);
                      if (_navigationMode && _currentPosition != null) {
                        _moveCameraToPosition(_currentPosition!);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _MapButton(
                    icon: _showArMode ? Icons.map_rounded : Icons.view_in_ar_rounded,
                    color: _showArMode ? KColors.primary : KColors.baseContent,
                    onTap: _toggleArMode,
                  ),
                ],
              ),
            ),
          ),

          // ── Panneau navigation haut ───────────────────────────────────────
          if (!_showArMode && hasPosition)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 12,
              right: 12,
              child: _NavTopPanel(
                distanceKm: _distanceRestanteKm,
                etaMinutes: _etaMinutes,
                heureArrivee: _heureArrivee,
                speedKmh: _speedKmh,
                destination: widget.destination,
              ),
            ),

          // ── Bannière "Tous à bord" (au-dessus du panneau bas) ────────────
          if (!_showArMode && _allAboard && _allPassengers.isNotEmpty)
            Positioned(
              bottom: 140,
              left: 16, right: 16,
              child: _AllAboardBanner(onTerminer: _terminerTrajet, isEnding: _isEnding),
            ),

          // ── Panneau bas passagers ─────────────────────────────────────────
          if (!_showArMode) Positioned(
            left: 0, right: 0, bottom: 0,
            child: _allPassengers.isNotEmpty
                ? PassengersBottomPanel(
                    passengers: _sortedPassengers,
                    driverLat: _currentPosition?.latitude,
                    driverLng: _currentPosition?.longitude,
                    speedKmh: _speedKmh,
                    isEnding: _isEnding,
                    onTerminer: _terminerTrajet,
                    onNavigate: _navigateToPassenger,
                    onArView: _openArToPassenger,
                    onTap: _openPassengerSheet,
                    onScan: _openScanForPassenger,
                  )
                : _BottomPanel(
                    speedKmh: _speedKmh,
                    distanceKm: _distanceRestanteKm,
                    etaMinutes: _etaMinutes,
                    isEnding: _isEnding,
                    onTerminer: _terminerTrajet,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarker(Color color, IconData icon) => Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)],
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      );
}

// ── Bannière "Tous à bord" ─────────────────────────────────────────────────────

class _AllAboardBanner extends StatelessWidget {
  final VoidCallback onTerminer;
  final bool isEnding;

  const _AllAboardBanner({required this.onTerminer, required this.isEnding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KColors.success.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: KColors.success.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: KColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, color: KColors.success, size: 26),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tous à bord !',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: KColors.baseContent,
                  )),
              Text('Vous pouvez démarrer le trajet',
                  style: TextStyle(fontSize: 12, color: KColors.baseContentMid)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: isEnding ? null : onTerminer,
          style: FilledButton.styleFrom(
            backgroundColor: KColors.success,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: isEnding
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Démarrer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ── Marqueur passager sur carte ────────────────────────────────────────────────

class _PassengerMapMarker extends StatelessWidget {
  final PassagerReservation passenger;
  final double? driverLat;
  final double? driverLng;

  const _PassengerMapMarker({
    required this.passenger,
    this.driverLat,
    this.driverLng,
  });

  Color get _markerColor => switch (passenger.statutEmbarquement) {
        'embarque' => KColors.success,
        'absent'   => KColors.error,
        _          => const Color(0xFFFF8C00),
      };

  @override
  Widget build(BuildContext context) {
    String distLabel = '';
    if (driverLat != null && passenger.hasGps) {
      final dist = LocationService.distanceKm(
        driverLat!, driverLng!,
        passenger.latitude!, passenger.longitude!,
      );
      distLabel = dist < 1
          ? ' · ${(dist * 1000).toInt()}m'
          : ' · ${dist.toStringAsFixed(1)}km';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(99),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Text(
            '${passenger.nom.split(' ').first}$distLabel',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF333333),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _markerColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: _markerColor.withValues(alpha: 0.5),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: passenger.estEmbarque
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 17)
              : passenger.estAbsent
                  ? const Icon(Icons.person_off_rounded, color: Colors.white, size: 17)
                  : const Icon(Icons.person_rounded, color: Colors.white, size: 17),
        ),
      ],
    );
  }
}

// ── Widgets locaux ─────────────────────────────────────────────────────────────

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _MapButton({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
  });

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
          child: Icon(icon, color: color, size: 22),
        ),
      );
}

class _NavTopPanel extends StatelessWidget {
  final double distanceKm;
  final int etaMinutes;
  final String heureArrivee;
  final double speedKmh;
  final String destination;

  const _NavTopPanel({
    required this.distanceKm,
    required this.etaMinutes,
    required this.heureArrivee,
    required this.speedKmh,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    final distLabel = distanceKm >= 1
        ? '${distanceKm.toStringAsFixed(1)} km'
        : '${(distanceKm * 1000).toInt()} m';
    final etaLabel = etaMinutes > 0 ? '$etaMinutes min' : '—';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 16,
          offset: const Offset(0, 4),
        )],
      ),
      child: Row(children: [
        const Icon(Icons.location_on, color: KColors.error, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(destination,
                style: KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('$distLabel • arrivée $heureArrivee',
                style: KTextStyles.caption),
          ],
        )),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(etaLabel,
              style: KTextStyles.statValue.copyWith(
                  color: KColors.primary, fontSize: 20)),
          if (speedKmh > 1)
            Text('${speedKmh.toStringAsFixed(0)} km/h',
                style: KTextStyles.meta),
        ]),
      ]),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final double speedKmh;
  final double distanceKm;
  final int etaMinutes;
  final bool isEnding;
  final VoidCallback onTerminer;

  const _BottomPanel({
    required this.speedKmh,
    required this.distanceKm,
    required this.etaMinutes,
    required this.isEnding,
    required this.onTerminer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 20,
          offset: const Offset(0, -4),
        )],
      ),
      padding: EdgeInsets.fromLTRB(
        20, 16, 20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36, height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: KColors.base300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Row(children: [
          _Metric(
            value: speedKmh > 0 ? speedKmh.toStringAsFixed(0) : '0',
            unit: 'km/h',
            icon: Icons.speed_rounded,
            color: speedKmh > 90 ? KColors.error : KColors.primary,
          ),
          const _MetricDivider(),
          _Metric(
            value: distanceKm >= 1
                ? distanceKm.toStringAsFixed(1)
                : '${(distanceKm * 1000).toInt()}',
            unit: distanceKm >= 1 ? 'km' : 'm',
            icon: Icons.straighten_rounded,
          ),
          const _MetricDivider(),
          _Metric(
            value: etaMinutes > 0 ? '$etaMinutes' : '—',
            unit: 'min',
            icon: Icons.timer_rounded,
            color: KColors.success,
          ),
        ]),
        const SizedBox(height: 16),
        KButton(
          label: 'Terminer le trajet',
          icon: Icons.flag_rounded,
          variant: KButtonVariant.error,
          isLoading: isEnding,
          onPressed: isEnding ? null : () async {
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
            if (confirm == true) { onTerminer(); }
          },
        ),
      ]),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String unit;
  final IconData icon;
  final Color? color;

  const _Metric({
    required this.value,
    required this.unit,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Icon(icon, size: 18, color: color ?? KColors.baseContentMid),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color ?? KColors.baseContent,
              )),
          Text(unit, style: KTextStyles.meta),
        ]),
      );
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 40, color: KColors.border);
}

