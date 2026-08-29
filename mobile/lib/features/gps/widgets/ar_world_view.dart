import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../../core/services/ar_nav_service.dart';
import '../../../core/services/ar_projector.dart';
import '../../../core/services/ar_sensor_service.dart';
import '../../../core/services/gps_filter.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/navigation_tts_service.dart';
import '../../../core/services/route_step.dart';
import '../../../core/theme/colors.dart';

// ── Widget principal ──────────────────────────────────────────────────────────

/// AR world-anchored pour le conducteur.
/// Les flèches de navigation sont ancrées dans le monde réel (projection perspective)
/// et se déplacent naturellement quand l'utilisateur bouge le téléphone.
class ArWorldView extends StatefulWidget {
  final List<LatLng> routePoints;
  final List<RouteStep> routeSteps;
  final String destination;
  final List<PassagerReservation> passengers;
  final VoidCallback? onBack;

  /// Appelé quand un passager est détecté à <5m et que le conducteur confirme.
  final void Function(PassagerReservation)? onBoardingConfirm;

  const ArWorldView({
    super.key,
    required this.routePoints,
    required this.routeSteps,
    required this.destination,
    required this.passengers,
    this.onBack,
    this.onBoardingConfirm,
  });

  @override
  State<ArWorldView> createState() => _ArWorldViewState();
}

class _ArWorldViewState extends State<ArWorldView>
    with WidgetsBindingObserver {
  // ── Caméra ────────────────────────────────────────────────────────────────
  CameraController? _camera;
  bool _cameraReady = false;

  // ── Capteurs ──────────────────────────────────────────────────────────────
  final _sensorService = ArSensorService();
  final _gpsFilter = GpsFilter();
  StreamSubscription? _sensorSub;
  ArDeviceOrientation _orient = const ArDeviceOrientation(
    heading: 0, pitch: 30, roll: 0, accuracy: 25,
  );

  // ── GPS ───────────────────────────────────────────────────────────────────
  StreamSubscription<Position>? _posSub;
  double? _lat, _lng;
  double _speedKmh = 0;
  double _lastAccuracy = 0;
  DateTime _lastGpsTime = DateTime.now();
  bool _gpsInitialized = false;
  // Compteur de lectures consécutives avec bon signal (accuracy < 15m)
  // pour réactiver l'AR progressivement (Tâche 5 : 3 lectures stables requises)
  int _stableGpsCount = 0;
  bool _arDisabled = false; // désactivé si GPS trop faible 3 lectures de suite

  // Perdu seulement si on a déjà eu un fix ET que ça fait 10s de silence
  bool get _gpsLost =>
      _gpsInitialized &&
      DateTime.now().difference(_lastGpsTime).inSeconds > 10;

  // Qualité GPS pour affichage progressif (Tâche 5)
  // Seuil 15m (bon) / 20m (faible) choisis par Google Maps et Apple Maps.
  _GpsQuality get _gpsQuality {
    if (!_gpsInitialized) return _GpsQuality.unknown;
    if (_lastAccuracy <= 10) return _GpsQuality.excellent;
    if (_lastAccuracy <= 15) return _GpsQuality.good;
    if (_lastAccuracy <= 25) return _GpsQuality.weak;
    return _GpsQuality.poor;
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  ArNavService? _arNav;
  ArNavState? _navState;
  final _tts = NavigationTtsService();

  // ── Détections avec debounce (Tâche 6) ────────────────────────────────────
  // Seuil 120° + 3 lectures consécutives pour éviter faux positifs dans virages.
  // 3 lectures ≈ 3 secondes (distanceFilter=2m ≈ 1 Hz en navigation).
  int _wrongDirCount = 0;
  int _wrongWayCount = 0;
  bool _wrongDirection = false;
  bool _wrongWay = false;

  PassagerReservation? _boardingCandidate;
  PassagerReservation? _arrivalPassenger;
  bool _needsCalibration = false;

  // ── Tâche 7 : boucle capteurs séparée (ValueNotifier, pas setState) ───────
  // Les capteurs tournent à ~50 Hz. On NE fait PAS de setState à cette fréquence
  // (coûteux). À la place, un ValueNotifier notifie uniquement les widgets AR.
  late final ValueNotifier<ArDeviceOrientation> _orientNotifier;

  // ── Nuit ──────────────────────────────────────────────────────────────────
  bool _nightMode = false;
  bool _nightForced = false; // override manuel

  bool get _isNight {
    if (_nightForced) return _nightMode;
    final h = DateTime.now().hour;
    return h >= 19 || h < 6;
  }

  // ── Couleurs du thème AR ──────────────────────────────────────────────────
  Color get _arrowColor =>
      _isNight ? const Color(0xFF64B5F6) : KColors.primary;
  Color get _hudBg =>
      _isNight ? Colors.black87 : Colors.black54;

  // ── Distances des flèches sur la route ───────────────────────────────────
  static const _arrowDistances = [8.0, 20.0, 40.0, 70.0];

  @override
  void initState() {
    super.initState();
    _orientNotifier = ValueNotifier(const ArDeviceOrientation(
      heading: 0, pitch: 30, roll: 0, accuracy: 25,
    ));
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _initGps();
    _initSensors();
    _tts.init();
    _tts.resetManeuverTracking();
    _buildArNav();
    _nightMode = _isNight;
  }

  @override
  void didUpdateWidget(ArWorldView old) {
    super.didUpdateWidget(old);
    if (old.routePoints != widget.routePoints ||
        old.routeSteps != widget.routeSteps) {
      _buildArNav();
      _tts.resetManeuverTracking();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _camera?.dispose();
      _cameraReady = false;
    } else if (state == AppLifecycleState.resumed && !_cameraReady) {
      _initCamera();
    }
  }

  void _buildArNav() {
    if (widget.routePoints.length >= 2) {
      _arNav = ArNavService(
        routePoints: widget.routePoints,
        steps: widget.routeSteps,
      );
    } else {
      _arNav = null;
    }
  }

  // ── Initialisation caméra ─────────────────────────────────────────────────
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _camera = ctrl;
        _cameraReady = true;
      });
    } catch (e) {
      debugPrint('[ArWorld] camera init error: $e');
    }
  }

  // ── GPS ───────────────────────────────────────────────────────────────────
  Future<void> _initGps() async {
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      ),
    ).listen((rawPos) {
      if (!mounted) return;
      // Rejet des sauts GPS + Kalman lat/lng
      final pos = _gpsFilter.update(rawPos) ?? rawPos;
      _lastGpsTime = DateTime.now();
      _gpsInitialized = true;
      final speed = pos.speed * 3.6;
      _lat = pos.latitude;
      _lng = pos.longitude;
      _speedKmh = speed;
      _lastAccuracy = pos.accuracy;

      _updateNavState();
      _checkDetections();
    });
  }

  // ── Capteurs (Tâche 7 : boucle ~50 Hz via ValueNotifier, PAS setState) ──────
  void _initSensors() {
    _sensorService.start();
    _sensorSub = _sensorService.stream.listen((orient) {
      if (!mounted) return;
      _orient = orient;
      _needsCalibration = orient.accuracy > 30;
      // Met à jour le notifier → reconstruit UNIQUEMENT les widgets AR
      // (flèches route + flèche direction) sans reconstruire toute la page.
      _orientNotifier.value = orient;
      // Pas de setState ici — la boucle GPS (1 Hz) s'en charge.
    });
  }

  // ── Mise à jour état AR (appelé depuis le flux GPS, ~1 Hz) ─────────────────
  void _updateNavState() {
    final lat = _lat, lng = _lng;

    // ── Tâche 5 : gestion qualité GPS ────────────────────────────────────────
    _updateGpsQuality();

    if (lat == null || lng == null || _arNav == null) {
      if (mounted) setState(() {});
      return;
    }
    final state = _arNav!.update(
      lat: lat,
      lng: lng,
      rawHeading: _orient.heading,
      gpsAccuracy: _lastAccuracy,
    );
    _tts.announceManeuverIfNeeded(
      step: state.upcomingStep,
      distanceM: state.distanceToStep,
    );

    // ── Tâche 6 : debounce mauvaise direction (3 lectures = ~3 secondes) ─────
    // 120° et 150° : seuils empiriques. En dessous de 120°, un simple virage
    // serré peut déclencher un faux positif. 3 lectures consécutives éliminent
    // les artefacts de rotation instantanée.
    if (state.arrowAngleDeg.abs() > 120 && _speedKmh < 5) {
      _wrongDirCount = (_wrongDirCount + 1).clamp(0, 5);
    } else {
      _wrongDirCount = 0;
    }

    if (_speedKmh > 15 &&
        _normAngle(state.routeBearing - _orient.heading).abs() > 150) {
      _wrongWayCount = (_wrongWayCount + 1).clamp(0, 5);
    } else {
      _wrongWayCount = 0;
    }

    if (mounted) {
      setState(() {
        _navState = state;
        _wrongDirection = _wrongDirCount >= 3;
        _wrongWay       = _wrongWayCount >= 3;
      });
    }
  }

  // ── Tâche 5 : gestion progressive de la qualité GPS ──────────────────────
  void _updateGpsQuality() {
    // Seuil 15m : en dessous, la précision GPS est suffisante pour l'AR.
    // 3 lectures stables consécutives avant de réactiver — évite un flip-flop
    // si le signal oscille autour du seuil.
    if (_lastAccuracy > 0 && _lastAccuracy <= 15) {
      _stableGpsCount = (_stableGpsCount + 1).clamp(0, 5);
      if (_stableGpsCount >= 3) _arDisabled = false;
    } else if (_lastAccuracy > 25) {
      _stableGpsCount = 0;
      _arDisabled = true;
    }
  }

  // ── Détection de passagers proches ────────────────────────────────────────
  void _checkDetections() {
    final lat = _lat, lng = _lng;
    if (lat == null || lng == null) return;

    PassagerReservation? boarding;
    PassagerReservation? arrival;

    for (final p in widget.passengers) {
      if (!p.hasGps || p.estEmbarque || p.estAbsent) continue;
      final dist = LocationService.distanceKm(
            lat, lng, p.latitude!, p.longitude!) *
          1000;
      if (dist < 5 && _speedKmh < 5) {
        boarding ??= p;
      } else if (dist < 20) {
        arrival ??= p;
      }
    }

    setState(() {
      _boardingCandidate = boarding;
      _arrivalPassenger  = arrival;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Fond caméra
          _buildCameraBackground(),

          // 2. Overlay nuit
          if (_isNight)
            Container(color: Colors.black.withValues(alpha: 0.2)),

          // 3+4. Flèches route + marqueurs passagers (boucle 50 Hz via ValueNotifier)
          // ValueListenableBuilder reconstruit UNIQUEMENT ce sous-arbre quand
          // les capteurs changent — le reste de la page ne rebuild pas à 50 Hz.
          ValueListenableBuilder<ArDeviceOrientation>(
            valueListenable: _orientNotifier,
            builder: (_, orient, _) {
              if (_arDisabled) return const SizedBox.shrink();
              return Stack(children: [
                ..._buildRouteArrows(size, orient),
                ..._buildPassengerMarkers(size, orient),
              ]);
            },
          ),

          // 5. Panneau de navigation haut (HUD non world-ancré)
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            left: 12,
            right: 12,
            child: _buildManeuverHud(),
          ),

          // 5b. Flèche de navigation permanente — toujours visible, centre bas
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 160,
            left: 0,
            right: 0,
            child: Center(child: _buildNavArrow()),
          ),

          // 6. HUD bas (vitesse + distance)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 90,
            left: 12,
            right: 12,
            child: _buildBottomHud(),
          ),

          // 7. Bannière mauvaise direction
          if (_wrongDirection || _wrongWay)
            Positioned(
              top: MediaQuery.of(context).padding.top + 150,
              left: 16,
              right: 16,
              child: _buildDirectionWarning(),
            ),

          // 8. GPS perdu
          if (_gpsLost)
            Positioned.fill(child: _buildGpsLostOverlay()),

          // 9. Badge signal GPS faible (Tâche 5 — dégradation progressive)
          if (_gpsQuality == _GpsQuality.weak || _gpsQuality == _GpsQuality.poor)
            Positioned(
              top: MediaQuery.of(context).padding.top + 56 + 64,
              left: 12,
              right: 12,
              child: _buildGpsWeakBadge(),
            ),

          // 9b. Calibration boussole
          if (_needsCalibration && !_gpsLost)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 170,
              left: 16,
              right: 16,
              child: _buildCalibrationBadge(),
            ),

          // 10. Popup embarquement (<5m)
          if (_boardingCandidate != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBoardingPopup(_boardingCandidate!),
            ),

          // 11. Badge arrivée (<20m)
          if (_boardingCandidate == null && _arrivalPassenger != null)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 16,
              right: 16,
              child: _buildArrivalBadge(_arrivalPassenger!),
            ),

          // 12. Barre de contrôles supérieure
          _buildTopBar(context),
        ],
      ),
    );
  }

  // ── Fond caméra ───────────────────────────────────────────────────────────
  Widget _buildCameraBackground() {
    if (!_cameraReady || _camera == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
        ),
      );
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _camera!.value.previewSize?.height ?? 1,
          height: _camera!.value.previewSize?.width ?? 1,
          child: CameraPreview(_camera!),
        ),
      ),
    );
  }

  // ── Flèches sur la route (world-anchored) ─────────────────────────────────
  List<Widget> _buildRouteArrows(Size size, ArDeviceOrientation orient) {
    final lat = _lat, lng = _lng;
    if (lat == null || lng == null || _arNav == null) return [];

    final widgets = <Widget>[];

    for (int i = 0; i < _arrowDistances.length; i++) {
      final dist = _arrowDistances[i];

      final point = _arNav!.pointAtDistance(dist);
      if (point == null) continue;

      final proj = ArProjector.project(
        userLat: lat,
        userLng: lng,
        pointLat: point.latitude,
        pointLng: point.longitude,
        altitudeM: 0.05,
        orientation: orient,
        screenSize: size,
      );

      if (proj == null || !proj.visible) continue;

      final roadBearing = _arNav!.bearingAtDistance(dist);
      final screenAngle = _normAngle(roadBearing - orient.heading) * pi / 180;

      final opacity = (1.0 - (dist - 6) / 75).clamp(0.25, 0.9);
      final arrowSize = (38.0 * proj.scale).clamp(14.0, 60.0);

      widgets.add(Positioned(
        left: proj.screenPos.dx - arrowSize / 2,
        top:  proj.screenPos.dy - arrowSize / 2,
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: screenAngle,
              child: _RoadChevron(
                size: arrowSize,
                color: _arrowColor,
                isNight: _isNight,
              ),
            ),
          ),
        ),
      ));
    }

    return widgets;
  }

  // ── Marqueurs passagers (world-anchored) ──────────────────────────────────
  List<Widget> _buildPassengerMarkers(Size size, ArDeviceOrientation orient) {
    final lat = _lat, lng = _lng;
    if (lat == null || lng == null) return [];

    final widgets = <Widget>[];

    for (final p in widget.passengers
        .where((p) => p.hasGps && !p.estEmbarque && !p.estAbsent)) {
      final proj = ArProjector.project(
        userLat: lat,
        userLng: lng,
        pointLat: p.latitude!,
        pointLng: p.longitude!,
        altitudeM: 1.6,
        orientation: orient,
        screenSize: size,
      );

      if (proj == null || !proj.visible || proj.distanceM > 200) continue;

      final distM = proj.distanceM;
      final distLabel = distM < 1000
          ? '${distM.round()} m'
          : '${(distM / 1000).toStringAsFixed(1)} km';
      final pinScale = proj.scale.clamp(0.4, 1.8);
      final pinW = 90.0 * pinScale;

      widgets.add(Positioned(
        left: proj.screenPos.dx - pinW / 2,
        top:  proj.screenPos.dy - 70.0 * pinScale,
        child: IgnorePointer(
          child: _PassengerArPin(
            name: p.nom.split(' ').first,
            distance: distLabel,
            scale: pinScale,
            arrived: distM < 20,
            isNight: _isNight,
          ),
        ),
      ));
    }

    return widgets;
  }

  // ── HUD manœuvre ──────────────────────────────────────────────────────────
  Widget _buildManeuverHud() {
    final ns = _navState;
    final hasStep = ns?.upcomingStep != null;
    final icon = ns?.upcomingStep?.icon ?? '⬆';
    final label = ns?.upcomingStep?.label ?? 'Suivez la route';
    final dist = ns != null && !ns.distanceToStep.isInfinite
        ? ns.distanceToStep >= 1000
            ? '${(ns.distanceToStep / 1000).toStringAsFixed(1)} km'
            : '${ns.distanceToStep.round()} m'
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _hudBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasStep ? label : 'Suivez la route',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (dist.isNotEmpty)
                Text(dist,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    )),
            ],
          ),
        ),
        if (ns?.offRoute == true)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Hors route',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }

  // ── HUD bas ───────────────────────────────────────────────────────────────
  Widget _buildBottomHud() {
    final ns = _navState;
    final speedStr = '${_speedKmh.toStringAsFixed(0)} km/h';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: _hudBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _HudMetric(
              icon: Icons.speed_rounded,
              value: speedStr,
              color: _speedKmh > 90 ? Colors.redAccent : Colors.white),
          const _HudDivider(),
          _HudMetric(
              icon: Icons.near_me_rounded,
              value: widget.destination,
              maxLen: 14),
          const _HudDivider(),
          _HudMetric(
              icon: ns?.aligned == true
                  ? Icons.check_circle_rounded
                  : Icons.navigation_rounded,
              value: ns?.aligned == true ? 'Aligné' : 'Direction',
              color: ns?.aligned == true ? Colors.greenAccent : Colors.white70),
        ],
      ),
    );
  }

  // ── Flèche de navigation permanente (toujours visible) ────────────────────
  Widget _buildNavArrow() {
    final ns = _navState;
    final angleDeg = ns?.arrowAngleDeg ?? 0.0;
    final aligned  = ns?.aligned ?? false;

    final Color arrowC;
    final absAngle = angleDeg.abs();
    if (absAngle < 20) {
      arrowC = const Color(0xFF4CAF50);
    } else if (absAngle < 60) {
      arrowC = const Color(0xFFFF9800);
    } else if (absAngle < 120) {
      arrowC = const Color(0xFFFF5722);
    } else {
      arrowC = const Color(0xFFF44336);
    }

    final String label;
    if (ns == null || _lat == null) {
      label = 'Localisation…';
    } else if (widget.routePoints.isEmpty) {
      label = 'Calcul du trajet…';
    } else if (aligned) {
      label = 'Bonne direction';
    } else {
      final side = angleDeg > 0 ? 'droite' : 'gauche';
      label = 'Tournez à $side';
    }

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
          border: Border.all(color: arrowC.withValues(alpha: 0.6), width: 2),
        ),
        child: Center(
          child: AnimatedRotation(
            turns: angleDeg / 360,
            duration: const Duration(milliseconds: 300),
            child: Icon(Icons.navigation_rounded, color: arrowC, size: 36),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(label,
            style: TextStyle(
                color: arrowC, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    ]);
  }

  // ── Bannière direction erronée ─────────────────────────────────────────────
  Widget _buildDirectionWarning() {
    final isWrongWay = _wrongWay;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isWrongWay ? Colors.red.shade700 : Colors.orange.shade700,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isWrongWay ? Colors.red : Colors.orange).withValues(alpha: 0.5),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(children: [
        Icon(
          isWrongWay ? Icons.do_not_disturb_alt_rounded : Icons.u_turn_right_rounded,
          color: Colors.white,
          size: 28,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isWrongWay ? 'SENS INTERDIT' : 'MAUVAISE DIRECTION',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                isWrongWay
                    ? 'Vous allez dans le mauvais sens'
                    : 'Demi-tour si possible',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ── GPS perdu ─────────────────────────────────────────────────────────────
  Widget _buildGpsLostOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gps_off_rounded, color: Colors.white54, size: 56),
            SizedBox(height: 12),
            Text('Signal GPS perdu',
                style: TextStyle(color: Colors.white, fontSize: 18)),
            SizedBox(height: 6),
            Text('Recherche en cours…',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ── Badge signal GPS faible (Tâche 5) ────────────────────────────────────
  Widget _buildGpsWeakBadge() {
    final isPoor = _gpsQuality == _GpsQuality.poor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: (isPoor ? Colors.red : Colors.orange).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          isPoor ? Icons.gps_not_fixed : Icons.gps_fixed,
          color: Colors.white,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          isPoor
              ? 'Signal GPS faible — position approximative'
              : 'Signal GPS moyen (${_lastAccuracy.toStringAsFixed(0)} m)',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ]),
    );
  }

  // ── Badge calibration boussole ────────────────────────────────────────────
  Widget _buildCalibrationBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade800.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.explore_off_rounded, color: Colors.white, size: 20),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Boussole peu fiable – faire un mouvement en ∞',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ]),
    );
  }

  // ── Popup embarquement (<5m) ──────────────────────────────────────────────
  Widget _buildBoardingPopup(PassagerReservation p) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: KColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_pin_circle_rounded,
                color: KColors.success, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nom,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                Text('Passager à moins de 5 m',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _boardingCandidate = null),
              style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('Ignorer'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: () {
                setState(() => _boardingCandidate = null);
                widget.onBoardingConfirm?.call(p);
              },
              style: FilledButton.styleFrom(
                backgroundColor: KColors.success,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Scanner / Confirmer',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ]),
    );
  }

  // ── Badge arrivée (<20m) ──────────────────────────────────────────────────
  Widget _buildArrivalBadge(PassagerReservation p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KColors.success.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: KColors.success.withValues(alpha: 0.3),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(children: [
        const Icon(Icons.where_to_vote_rounded, color: KColors.success, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Arrivé chez ${p.nom.split(' ').first}',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14),
          ),
        ),
      ]),
    );
  }

  // ── Barre supérieure ──────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          _ArButton(
            icon: Icons.arrow_back_rounded,
            onTap: widget.onBack ?? () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),
          // Badge "RA active"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.view_in_ar_rounded,
                  color: _arrowColor, size: 14),
              const SizedBox(width: 5),
              Text('RA',
                  style: TextStyle(
                      color: _arrowColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(width: 8),
          // Bascule nuit / jour
          _ArButton(
            icon: _isNight ? Icons.wb_sunny_rounded : Icons.nightlight_round,
            color: _isNight ? Colors.amber : Colors.blueGrey,
            onTap: () => setState(() {
              _nightForced = true;
              _nightMode = !_nightMode;
            }),
          ),
        ]),
      ),
    );
  }

  // ── Utilitaires ───────────────────────────────────────────────────────────
  static double _normAngle(double d) => ((d + 180) % 360) - 180;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sensorSub?.cancel();
    _sensorService.dispose();
    _posSub?.cancel();
    _camera?.dispose();
    _tts.dispose();
    _orientNotifier.dispose();
    super.dispose();
  }
}

// ── Flèche chevron (marquage routier) ────────────────────────────────────────

class _RoadChevron extends StatelessWidget {
  final double size;
  final Color color;
  final bool isNight;

  const _RoadChevron({
    required this.size,
    required this.color,
    required this.isNight,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size * 1.2),
        painter: _ChevronPainter(color: color, isNight: isNight),
      );
}

class _ChevronPainter extends CustomPainter {
  final Color color;
  final bool isNight;

  const _ChevronPainter({required this.color, required this.isNight});

  @override
  void paint(Canvas canvas, Size sz) {
    final w = sz.width, h = sz.height;

    // Flèche en V pointant vers le haut (direction de navigation)
    final path = Path()
      ..moveTo(w * 0.5, 0)                      // pointe haute
      ..lineTo(w,       h * 0.6)                 // coin bas droit
      ..lineTo(w * 0.73, h * 0.45)              // entaille droite
      ..lineTo(w * 0.5, h)                       // base du V
      ..lineTo(w * 0.27, h * 0.45)              // entaille gauche
      ..lineTo(0,       h * 0.6)                 // coin bas gauche
      ..close();

    // Remplissage
    canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..style = PaintingStyle.fill);

    // Contour blanc pour lisibilité sur tout fond
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: isNight ? 0.9 : 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sz.width * 0.06
          ..strokeJoin = StrokeJoin.round);

    // Halo lumineux (nuit)
    if (isNight) {
      canvas.drawPath(
          path,
          Paint()
            ..color = color.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = sz.width * 0.18
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }
  }

  @override
  bool shouldRepaint(_ChevronPainter old) =>
      old.color != color || old.isNight != isNight;
}

// ── Marqueur passager AR ──────────────────────────────────────────────────────

class _PassengerArPin extends StatelessWidget {
  final String name;
  final String distance;
  final double scale;
  final bool arrived;
  final bool isNight;

  const _PassengerArPin({
    required this.name,
    required this.distance,
    required this.scale,
    required this.arrived,
    required this.isNight,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isNight ? Colors.black87 : Colors.white;
    final fg = isNight ? Colors.white : const Color(0xFF1A1A2E);
    final accentC = arrived ? KColors.success : KColors.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bulle info
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: 10 * scale, vertical: 6 * scale),
          decoration: BoxDecoration(
            color: bg.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12 * scale),
            border: Border.all(color: accentC.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8 * scale),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name,
                  style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      fontSize: 12 * scale)),
              Text(distance,
                  style: TextStyle(
                      color: accentC,
                      fontWeight: FontWeight.w600,
                      fontSize: 10 * scale)),
              if (arrived)
                Text('Scanner QR',
                    style: TextStyle(
                        color: KColors.success,
                        fontWeight: FontWeight.w900,
                        fontSize: 11 * scale)),
            ],
          ),
        ),
        // Ligne vers le sol
        Container(
          width: 2 * scale,
          height: 14 * scale,
          color: accentC.withValues(alpha: 0.6),
        ),
        // Point au sol
        Container(
          width: 8 * scale,
          height: 8 * scale,
          decoration: BoxDecoration(
            color: accentC,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: accentC.withValues(alpha: 0.5),
                  blurRadius: 6 * scale),
            ],
          ),
        ),
      ],
    );
  }
}

// ── HUD widgets ───────────────────────────────────────────────────────────────

class _HudMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color? color;
  final int maxLen;

  const _HudMetric({
    required this.icon,
    required this.value,
    this.color,
    this.maxLen = 8,
  });

  @override
  Widget build(BuildContext context) {
    final label = value.length > maxLen
        ? '${value.substring(0, maxLen - 1)}…'
        : value;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color ?? Colors.white70, size: 16),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    ]);
  }
}

class _HudDivider extends StatelessWidget {
  const _HudDivider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: Colors.white12);
}

// ── Qualité signal GPS (Tâche 5) ─────────────────────────────────────────────
//
// Seuils basés sur la précision horizontale retournée par geolocator (mètres).
// excellent ≤10m : AR fiable, aucun badge.
// good     ≤15m : AR actif, aucun badge.
// weak     ≤25m : badge orange, AR désactivé si stable.
// poor     >25m : badge rouge, AR désactivé.

enum _GpsQuality { unknown, excellent, good, weak, poor }

// ── Bouton AR ─────────────────────────────────────────────────────────────────

class _ArButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _ArButton({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, color: color ?? Colors.white, size: 20),
        ),
      );
}
