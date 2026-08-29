import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
// 'hide Path' évite le conflit avec dart:ui.Path utilisé dans CustomPainter
import 'package:latlong2/latlong.dart' hide Path;
import 'package:permission_handler/permission_handler.dart';
import '../../../core/services/ar_nav_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/navigation_tts_service.dart';
import '../../../core/services/route_step.dart';
import '../../../core/theme/colors.dart';

enum _ArState { loading, permissionDenied, error, active }

/// Vue AR avec vrai flux caméra en arrière-plan + guidage directionnel.
///
/// Mode ROUTE : si [routePoints] est non vide, utilise [ArNavService] pour
/// suivre la polyligne OSRM — identique à la carte → Google Maps Live View.
///
/// Mode DIRECT : si [routePoints] est vide, calcule un bearing direct vers
/// [targetLat]/[targetLng] (ancien comportement — utile passager→conducteur).
class InlineArView extends StatefulWidget {
  final double targetLat;
  final double targetLng;
  final String targetName;
  final String targetType; // 'conducteur' | 'passager' | 'destination'
  final bool targetAvailable;

  /// Polyligne OSRM (même que celle affichée sur la carte).
  final List<LatLng> routePoints;

  /// Étapes OSRM avec manœuvres (même source que les indications sur la carte).
  final List<RouteStep> routeSteps;

  final VoidCallback? onBack;

  const InlineArView({
    super.key,
    required this.targetLat,
    required this.targetLng,
    required this.targetName,
    required this.targetType,
    this.targetAvailable = true,
    this.routePoints = const [],
    this.routeSteps = const [],
    this.onBack,
  });

  @override
  State<InlineArView> createState() => _InlineArViewState();
}

class _InlineArViewState extends State<InlineArView>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {

  _ArState _state = _ArState.loading;
  String?  _errorMsg;

  CameraController? _camera;

  // ── Capteurs ──────────────────────────────────────────────────────────────
  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<Position>?     _posSub;

  double  _rawHeading       = 0;
  double? _compassAccDeg;   // précision boussole en degrés (null = inconnue)
  double? _currentLat;
  double? _currentLng;
  double? _gpsAccuracy;
  bool    _gpsLost          = false;
  DateTime? _lastGpsTime;

  // ── Mode ROUTE ────────────────────────────────────────────────────────────
  ArNavService?  _arNav;
  ArNavState?    _navState;

  // ── Mode DIRECT (fallback) ────────────────────────────────────────────────
  double  _directBearing  = 0;
  double  _distanceKm     = 0;

  // ── TTS interne ───────────────────────────────────────────────────────────
  final _tts = NavigationTtsService();

  // ── Animation flèche ──────────────────────────────────────────────────────
  late AnimationController _arrowCtrl;
  late Animation<double>   _arrowAnim;
  double _prevArrow = 0;

  bool get _routeMode => widget.routePoints.length >= 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _arrowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _arrowAnim = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _arrowCtrl, curve: Curves.easeOut),
    );

    if (_routeMode) {
      _arNav = ArNavService(
        routePoints: widget.routePoints,
        steps: widget.routeSteps,
      );
    }

    _tts.init();
    _init();
  }

  @override
  void didUpdateWidget(InlineArView old) {
    super.didUpdateWidget(old);
    // Reconstruire ArNavService si la route change
    if (widget.routePoints != old.routePoints) {
      if (_routeMode) {
        _arNav = ArNavService(
          routePoints: widget.routePoints,
          steps: widget.routeSteps,
        );
        _tts.resetManeuverTracking();
      } else {
        _arNav = null;
      }
    }
    // Recalculer si la cible change (mode direct)
    if (!_routeMode &&
        (widget.targetLat != old.targetLat || widget.targetLng != old.targetLng) &&
        _currentLat != null) {
      _recalcDirect();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      cam.dispose();
      _camera = null;
    } else if (state == AppLifecycleState.resumed && _state == _ArState.active) {
      _initCamera();
    }
  }

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> _init() async {
    if (!mounted) return;
    setState(() { _state = _ArState.loading; _errorMsg = null; });

    final camPerm = await Permission.camera.request();
    final locPerm = await Permission.locationWhenInUse.request();
    if (!mounted) return;

    if (camPerm.isDenied || camPerm.isPermanentlyDenied) {
      setState(() => _state = _ArState.permissionDenied);
      return;
    }

    final ok = await _initCamera();
    if (!ok || !mounted) return;

    setState(() => _state = _ArState.active);
    _startCompass();
    if (locPerm.isGranted || locPerm.isLimited) _startGps();
  }

  Future<bool> _initCamera() async {
    try {
      await _camera?.dispose();
      _camera = null;
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('Aucune caméra disponible');
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(back, ResolutionPreset.medium,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await ctrl.initialize();
      if (!mounted) { ctrl.dispose(); return false; }
      _camera = ctrl;
      return true;
    } on CameraException catch (e) {
      if (mounted) setState(() { _state = _ArState.error; _errorMsg = '${e.code}: ${e.description}'; });
      return false;
    } catch (e) {
      if (mounted) setState(() { _state = _ArState.error; _errorMsg = e.toString(); });
      return false;
    }
  }

  // ── Capteurs ──────────────────────────────────────────────────────────────

  void _startCompass() {
    _compassSub?.cancel();
    _compassSub = FlutterCompass.events?.listen((e) {
      if (!mounted || e.heading == null) return;
      _rawHeading = e.heading!;
      _compassAccDeg = e.accuracy;
      _update();
    });
  }

  Future<void> _startGps() async {
    _posSub?.cancel();
    final init = await LocationService.getCurrentPosition();
    if (init != null && mounted) _onPosition(init);

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2,
      ),
    ).listen((p) { if (mounted) _onPosition(p); });

    // Détecteur de perte GPS (pas de mise à jour depuis 6s)
    Timer.periodic(const Duration(seconds: 3), (t) {
      if (!mounted) { t.cancel(); return; }
      final last = _lastGpsTime;
      final lost = last == null || DateTime.now().difference(last).inSeconds > 6;
      if (lost != _gpsLost) setState(() => _gpsLost = lost);
    });
  }

  void _onPosition(Position pos) {
    _currentLat  = pos.latitude;
    _currentLng  = pos.longitude;
    _gpsAccuracy = pos.accuracy;
    _lastGpsTime = DateTime.now();
    if (_gpsLost && mounted) setState(() => _gpsLost = false);
    _update();
  }

  // ── Calcul principal ──────────────────────────────────────────────────────

  void _update() {
    if (!mounted) return;
    final lat = _currentLat;
    final lng = _currentLng;

    if (_routeMode && _arNav != null && lat != null) {
      // Mode ROUTE : ArNavService est la source de vérité
      final state = _arNav!.update(
        lat:        lat,
        lng:        lng!,
        rawHeading: _rawHeading,
        gpsAccuracy: _gpsAccuracy,
      );
      _navState = state;
      _animateTo(state.arrowAngleDeg);

      // Guidage vocal de manœuvre
      _tts.announceManeuverIfNeeded(
        step: state.upcomingStep,
        distanceM: state.distanceToStep,
      );
    } else if (!_routeMode && lat != null && widget.targetAvailable) {
      // Mode DIRECT : bearing vers la cible
      _recalcDirect();
    }

    if (mounted) setState(() {});
  }

  void _recalcDirect() {
    final lat = _currentLat;
    final lng = _currentLng;
    if (lat == null || !widget.targetAvailable) return;
    _directBearing = LocationService.bearingTo(
      lat, lng!, widget.targetLat, widget.targetLng,
    );
    _distanceKm = LocationService.distanceKm(
      lat, lng, widget.targetLat, widget.targetLng,
    );
    // Angle flèche : d > 0 → cible à droite, d < 0 → cible à gauche
    final arrowDeg = _normAngle(_directBearing - _rawHeading);
    _animateTo(arrowDeg);
    if (mounted) setState(() {});
  }

  void _animateTo(double targetDeg) {
    // Trajet le plus court en passant par ±180°
    double delta = ((targetDeg - _prevArrow + 540) % 360) - 180;
    final newEnd = _prevArrow + delta;
    _arrowAnim = Tween<double>(begin: _prevArrow, end: newEnd).animate(
      CurvedAnimation(parent: _arrowCtrl, curve: Curves.easeOut),
    );
    _arrowCtrl..reset()..forward();
    _prevArrow = newEnd;
  }

  // d > 0 → cible à droite ; d < 0 → cible à gauche
  double _normAngle(double d) => ((d + 180) % 360) - 180;

  // ── Texte d'instruction ───────────────────────────────────────────────────

  String _buildInstruction(double arrowDeg) {
    if (_routeMode) {
      return _navState?.instruction ?? '⬆ Suivez la route';
    }
    if (!widget.targetAvailable) return 'En attente de la position…';
    if (_currentLat == null) return 'Acquisition GPS…';
    return _fallbackInstruction(arrowDeg);
  }

  // Mode direct : instructions relatives gauche/droite
  // d > 0 → cible à DROITE ; d < 0 → cible à GAUCHE
  String _fallbackInstruction(double d) {
    final abs = d.abs();
    if (abs < 15)  return 'Face à la cible ✓';
    if (abs < 45)  return d > 0 ? '↱ Légèrement à droite' : '↰ Légèrement à gauche';
    if (d > 90)    return '↪ Derrière vous (droite)';
    if (d < -90)   return '↩ Derrière vous (gauche)';
    if (d > 0)     return '↱ Tournez à droite · ${abs.toInt()}°';
    return '↰ Tournez à gauche · ${abs.toInt()}°';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    _compassSub?.cancel();
    _posSub?.cancel();
    _arrowCtrl.dispose();
    _tts.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return switch (_state) {
      _ArState.loading          => _buildLoading(),
      _ArState.permissionDenied => _buildPermissionDenied(),
      _ArState.error            => _buildError(),
      _ArState.active           => _buildActive(),
    };
  }

  // ── États de chargement ───────────────────────────────────────────────────

  Widget _buildLoading() => ColoredBox(
    color: Colors.black,
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(
          width: 48, height: 48,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
        const SizedBox(height: 20),
        const Text('Ouverture de la caméra AR…',
            style: TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 40),
        TextButton.icon(
          onPressed: widget.onBack,
          icon: const Icon(Icons.map_rounded, color: Colors.white54),
          label: const Text('Annuler', style: TextStyle(color: Colors.white54)),
        ),
      ]),
    ),
  );

  Widget _buildPermissionDenied() => _ArMessageScreen(
    icon: Icons.no_photography_outlined, iconColor: Colors.white54,
    title: 'Accès caméra requis',
    message: 'La réalité augmentée nécessite l\'accès à la caméra.\n'
        'Autorisez-le dans les paramètres de l\'application.',
    actions: [
      _ArButton(label: 'Paramètres', icon: Icons.settings_rounded,
          color: KColors.primary, onPressed: () async {
        await openAppSettings();
        await Future.delayed(const Duration(seconds: 1));
        _init();
      }),
      _ArButton.outline(label: 'Retour carte', icon: Icons.map_rounded,
          onPressed: widget.onBack),
    ],
  );

  Widget _buildError() => _ArMessageScreen(
    icon: Icons.videocam_off_rounded, iconColor: Colors.orange,
    title: 'Caméra AR indisponible',
    message: _errorMsg ?? 'Une erreur est survenue lors de l\'ouverture de la caméra.',
    actions: [
      _ArButton(label: 'Réessayer', icon: Icons.refresh_rounded,
          color: KColors.primary, onPressed: _init),
      _ArButton.outline(label: 'Retour carte', icon: Icons.map_rounded,
          onPressed: widget.onBack),
    ],
  );

  // ── Vue principale AR ─────────────────────────────────────────────────────

  Widget _buildActive() {
    final Color accentColor = switch (widget.targetType) {
      'conducteur'  => KColors.success,
      'destination' => const Color(0xFF2563EB),
      _             => const Color(0xFFFF8C00),
    };
    final cam = _camera;

    // Précision boussole dégradée ?
    final compassUnreliable = _compassAccDeg == null || _compassAccDeg! > 25;
    // Hors route ?
    final offRoute = _routeMode && (_navState?.offRoute ?? false);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack?.call();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Flux caméra
          if (cam != null && cam.value.isInitialized)
            _FullScreenCamera(controller: cam)
          else
            const ColoredBox(color: Color(0xFF0D1117)),

          // Dégradés
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 280,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.88)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.65), Colors.transparent],
                ),
              ),
            ),
          ),

          // Overlay AR
          SafeArea(
            child: Column(
              children: [
                _ArTopBar(
                  targetName:  widget.targetName,
                  targetType:  widget.targetType,
                  accentColor: accentColor,
                  distanceKm:  _routeMode
                      ? ((_navState?.distanceToStep ?? 0) / 1000)
                      : _distanceKm,
                  hasFix:      _currentLat != null,
                  onBack:      widget.onBack,
                ),
                const Spacer(flex: 2),

                // Avertissements
                if (compassUnreliable)
                  _WarningBadge(
                    icon: Icons.explore_off_rounded,
                    color: Colors.orange,
                    text: 'Calibrez la boussole : tracez un ∞ avec le téléphone',
                  ),
                if (offRoute)
                  _WarningBadge(
                    icon: Icons.warning_rounded,
                    color: Colors.orange,
                    text: 'Hors itinéraire — recalcul en attente',
                  ),
                if (_gpsLost)
                  _WarningBadge(
                    icon: Icons.gps_off_rounded,
                    color: Colors.red,
                    text: 'Signal GPS perdu — dernière position conservée',
                  ),
                const SizedBox(height: 8),

                // Widget flèche + instruction
                AnimatedBuilder(
                  animation: _arrowAnim,
                  builder: (_, _) {
                    final deg     = _arrowAnim.value;
                    final aligned = deg.abs() < 20;
                    final hasFix  = _currentLat != null;
                    final navState = _navState;
                    return _ArDirectionWidget(
                      angleDeg:          deg,
                      aligned:           aligned,
                      accentColor:       accentColor,
                      instruction:       _buildInstruction(deg),
                      hasFix:            hasFix && (widget.targetAvailable || _routeMode),
                      nearManeuver:      _routeMode &&
                          (navState?.distanceToStep ?? double.infinity) < 100,
                      maneuverIcon:      navState?.upcomingStep?.icon,
                      compassUnreliable: compassUnreliable,
                    );
                  },
                ),

                const Spacer(flex: 1),
                _ArBottomBar(
                  accentColor: accentColor,
                  distanceKm:  _routeMode
                      ? ((_navState?.distanceToStep ?? 0) / 1000)
                      : _distanceKm,
                  hasFix:      _currentLat != null,
                  routeMode:   _routeMode,
                  onBack:      widget.onBack,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Caméra plein écran ────────────────────────────────────────────────────────

class _FullScreenCamera extends StatelessWidget {
  final CameraController controller;
  const _FullScreenCamera({required this.controller});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return const SizedBox.expand();
    final scale = size.aspectRatio * (previewSize.width / previewSize.height);
    return Transform.scale(
      scale: scale < 1 ? 1 / scale : scale,
      child: Center(child: CameraPreview(controller)),
    );
  }
}

// ── Barre supérieure ──────────────────────────────────────────────────────────

class _ArTopBar extends StatelessWidget {
  final String       targetName;
  final String       targetType;
  final Color        accentColor;
  final double       distanceKm;
  final bool         hasFix;
  final VoidCallback? onBack;

  const _ArTopBar({
    required this.targetName,
    required this.targetType,
    required this.accentColor,
    required this.distanceKm,
    required this.hasFix,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final distLabel = !hasFix
        ? '…'
        : distanceKm < 1
            ? '${(distanceKm * 1000).toInt()} m'
            : '${distanceKm.toStringAsFixed(1)} km';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(children: [
              Icon(
                switch (targetType) {
                  'conducteur'  => Icons.directions_car_rounded,
                  'destination' => Icons.location_on_rounded,
                  _             => Icons.person_rounded,
                },
                color: accentColor, size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(targetName,
                        style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      switch (targetType) {
                        'conducteur'  => 'Conducteur',
                        'destination' => 'Destination',
                        _             => 'Passager',
                      },
                      style: TextStyle(
                          color: accentColor, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accentColor.withValues(alpha: 0.5)),
          ),
          child: Text(distLabel,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
        ),
      ]),
    );
  }
}

// ── Widget flèche directionnelle ──────────────────────────────────────────────

class _ArDirectionWidget extends StatelessWidget {
  final double  angleDeg;
  final bool    aligned;
  final Color   accentColor;
  final String  instruction;
  final bool    hasFix;
  final bool    nearManeuver;
  final String? maneuverIcon;
  final bool    compassUnreliable;

  const _ArDirectionWidget({
    required this.angleDeg,
    required this.aligned,
    required this.accentColor,
    required this.instruction,
    required this.hasFix,
    this.nearManeuver      = false,
    this.maneuverIcon,
    this.compassUnreliable = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasFix) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(
          width: 48, height: 48,
          child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
        ),
        const SizedBox(height: 14),
        Text(instruction,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
      ]);
    }

    final arrowColor = aligned
        ? accentColor
        : compassUnreliable
            ? Colors.orange
            : Colors.white;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Icône manœuvre proéminente quand < 100 m
      if (nearManeuver && maneuverIcon != null) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withValues(alpha: 0.6)),
          ),
          child: Text(maneuverIcon!,
              style: const TextStyle(fontSize: 36)),
        ),
        const SizedBox(height: 10),
      ],

      // Cercle avec flèche directionnelle
      Container(
        width: 140, height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.35),
          border: Border.all(
            color: arrowColor.withValues(alpha: 0.35), width: 2,
          ),
          boxShadow: aligned
              ? [BoxShadow(
                  color: accentColor.withValues(alpha: 0.45),
                  blurRadius: 32, spreadRadius: 4)]
              : [],
        ),
        child: Transform.rotate(
          angle: angleDeg * pi / 180,
          child: CustomPaint(
            size: const Size(140, 140),
            painter: _ArrowPainter(color: arrowColor),
          ),
        ),
      ),
      const SizedBox(height: 16),

      // Bandeau instruction
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: aligned
              ? accentColor.withValues(alpha: 0.22)
              : Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: aligned
                ? accentColor.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          instruction,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: aligned ? accentColor : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15, height: 1.3,
          ),
        ),
      ),
    ]);
  }
}

// ── Barre inférieure ──────────────────────────────────────────────────────────

class _ArBottomBar extends StatelessWidget {
  final Color        accentColor;
  final double       distanceKm;
  final bool         hasFix;
  final bool         routeMode;
  final VoidCallback? onBack;

  const _ArBottomBar({
    required this.accentColor,
    required this.distanceKm,
    required this.hasFix,
    required this.routeMode,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final distLabel = !hasFix
        ? 'GPS…'
        : distanceKm < 1
            ? '${(distanceKm * 1000).toInt()} m'
            : '${distanceKm.toStringAsFixed(1)} km';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Vue carte',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: hasFix
                ? accentColor.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasFix
                  ? accentColor.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              routeMode ? Icons.route_rounded : Icons.gps_fixed_rounded,
              color: hasFix ? accentColor : Colors.white54, size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              distLabel,
              style: TextStyle(
                color: hasFix ? Colors.white : Colors.white54,
                fontWeight: FontWeight.w700, fontSize: 13,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Badge d'avertissement ─────────────────────────────────────────────────────

class _WarningBadge extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   text;

  const _WarningBadge({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Flexible(
          child: Text(text,
              style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ── Écran message ─────────────────────────────────────────────────────────────

class _ArMessageScreen extends StatelessWidget {
  final IconData     icon;
  final Color        iconColor;
  final String       title;
  final String       message;
  final List<Widget> actions;

  const _ArMessageScreen({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 38),
            ),
            const SizedBox(height: 24),
            Text(title,
                style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(
                    color: Colors.white60, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
                maxLines: 5, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 32),
            ...actions.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(width: double.infinity, child: a),
            )),
          ],
        ),
      ),
    ),
  );
}

// ── Bouton AR ─────────────────────────────────────────────────────────────────

class _ArButton extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final bool         outlined;
  final VoidCallback? onPressed;

  const _ArButton({
    required this.label,
    required this.icon,
    required this.color,
    this.outlined = false,
    this.onPressed,
  });

  const _ArButton.outline({
    required String label, required IconData icon, VoidCallback? onPressed,
  }) : this(label: label, icon: icon, color: Colors.white70,
            outlined: true, onPressed: onPressed);

  @override
  Widget build(BuildContext context) {
    final child = Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 18),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    ]);
    if (outlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: const BorderSide(color: Colors.white30),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: child,
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: child,
    );
  }
}

// ── Painter flèche ────────────────────────────────────────────────────────────

class _ArrowPainter extends CustomPainter {
  final Color color;
  const _ArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width * 0.30;
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(cx, cy - r * 0.9)
      ..lineTo(cx - r * 0.38, cy - r * 0.2)
      ..lineTo(cx - r * 0.14, cy - r * 0.28)
      ..lineTo(cx - r * 0.14, cy + r * 0.55)
      ..lineTo(cx + r * 0.14, cy + r * 0.55)
      ..lineTo(cx + r * 0.14, cy - r * 0.28)
      ..lineTo(cx + r * 0.38, cy - r * 0.2)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter o) => o.color != color;
}
