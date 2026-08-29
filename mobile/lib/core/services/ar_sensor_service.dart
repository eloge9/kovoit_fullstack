import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Orientation 3D du téléphone, fusionnée depuis boussole + accéléromètre + gyroscope.
class ArDeviceOrientation {
  /// Cap (degrés, 0=Nord, sens horaire) — sortie du filtre complémentaire.
  final double heading;

  /// Inclinaison verticale de la caméra au-dessus de l'horizon (degrés).
  final double pitch;

  /// Roulis gauche-droite (degrés).
  final double roll;

  /// Précision de la boussole (degrés). >30° = peu fiable.
  final double accuracy;

  const ArDeviceOrientation({
    required this.heading,
    required this.pitch,
    required this.roll,
    required this.accuracy,
  });
}

// ── Filtre complémentaire cap ────────────────────────────────────────────────
//
// Combine gyroscope (haute fréquence, précis à court terme) et boussole
// (absolue mais bruitée) pour un cap fluide et non-dérivant.
//
// α = 0.98 : 98% gyro (fluidité), 2% boussole (recalage absolu).
// Un α plus bas donne plus de poids à la boussole (moins fluide mais recalé
// plus vite). 0.95-0.98 est le bon range pour la RA mobile.

class ComplementaryHeadingFilter {
  double _heading;

  // α = 0.98 : seuil choisi empiriquement pour navigation AR sur mobile.
  // En dessous de 0.95 : la boussole prend trop de poids, l'AR tremble.
  // Au-dessus de 0.99 : dérive visible après ~30s sans recalage.
  final double alpha;

  ComplementaryHeadingFilter({this.alpha = 0.98, double initial = 0})
      : _heading = initial;

  double update({
    required double gyroRateZ, // rad/s (axe Z = rotation autour de la verticale)
    required double compassHeading, // degrés, absolu
    required double dt, // secondes depuis le dernier appel
  }) {
    // Intégration gyro : heading_gyro = heading_prev + gyro_z_deg × dt
    final gyroHeading = _heading + (gyroRateZ * 180 / pi) * dt;

    // Fusion complémentaire — gestion du passage 359°→1°
    final diff = ((compassHeading - gyroHeading + 540) % 360) - 180;
    _heading = (gyroHeading + (1 - alpha) * diff + 360) % 360;
    return _heading;
  }

  double get value => _heading;
  void resetTo(double deg) => _heading = deg;
}

// ── Service principal ────────────────────────────────────────────────────────

/// Fusionne boussole + accéléromètre + gyroscope → [ArDeviceOrientation].
///
/// Pipeline :
///   1. Kalman 1-D sur la boussole (réduit le bruit magnétique).
///   2. Filtre complémentaire gyro+boussole pour le cap AR (30-60 Hz).
///   3. Filtre passe-bas sur pitch/roll (accéléromètre).
class ArSensorService {
  StreamSubscription? _compassSub;
  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;
  final _controller = StreamController<ArDeviceOrientation>.broadcast();

  // ── Kalman cap (boussole brute → cap lissé) ───────────────────────────────
  double _kfState = 0;
  double _kfError = 180.0;
  static const _kfQ = 1.0;
  static const _kfR = 8.0;

  // ── Filtre complémentaire (gyro + boussole filtrée) ───────────────────────
  final _compFilter = ComplementaryHeadingFilter(alpha: 0.98);
  DateTime? _lastGyroTime;

  // ── Filtre passe-bas pitch/roll ────────────────────────────────────────────
  double _pitchFilt = 30.0;
  double _rollFilt  = 0.0;

  // ── Dernières valeurs boussole ────────────────────────────────────────────
  double _compassHeading = 0;
  double _accuracy = 25;
  bool _compassReady = false;

  Stream<ArDeviceOrientation> get stream => _controller.stream;

  void start() {
    // ── Boussole : recalage absolu du filtre complémentaire ──────────────────
    _compassSub = FlutterCompass.events?.listen((e) {
      if (e.heading == null) return;
      _compassHeading = _kalmanUpdate(e.heading!);
      _accuracy = e.accuracy ?? 25;
      if (!_compassReady) {
        // Premier fix : initialiser le filtre complémentaire avec la boussole
        _compFilter.resetTo(_compassHeading);
        _compassReady = true;
      }
      _emit();
    });

    // ── Gyroscope : cap haute fréquence entre deux fixes boussole ────────────
    _gyroSub = gyroscopeEventStream().listen((e) {
      if (!_compassReady) return;
      final now = DateTime.now();
      final dt = _lastGyroTime != null
          ? now.difference(_lastGyroTime!).inMicroseconds / 1e6
          : 0.02; // fallback : 50 Hz
      _lastGyroTime = now;

      // e.z = rotation autour de l'axe Z (vertical) en rad/s.
      // Signe Android : positif = rotation antihoraire = heading décroît.
      // On inverse pour que le heading augmente dans le sens horaire.
      _compFilter.update(
        gyroRateZ: -e.z,
        compassHeading: _compassHeading,
        dt: dt.clamp(0.001, 0.1), // clamp : évite dt aberrant au démarrage
      );
      _emit();
    });

    // ── Accéléromètre : pitch + roll ─────────────────────────────────────────
    _accelSub = accelerometerEventStream().listen((e) {
      final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      if (mag < 1) return;
      final rawPitch = atan2(-e.z / mag, e.y / mag) * 180 / pi;
      final rawRoll  = atan2( e.x / mag, e.y / mag) * 180 / pi;
      // α=0.15 : lissage fort — évite les à-coups accéléromètre sur les bosses
      _pitchFilt = _pitchFilt * 0.85 + rawPitch * 0.15;
      _rollFilt  = _rollFilt  * 0.85 + rawRoll  * 0.15;
      _emit();
    });
  }

  void _emit() {
    if (_controller.isClosed) return;
    // Heading final = sortie du filtre complémentaire (gyro+boussole)
    _controller.add(ArDeviceOrientation(
      heading:  _compFilter.value,
      pitch:    _pitchFilt.clamp(-90, 90),
      roll:     _rollFilt.clamp(-90, 90),
      accuracy: _accuracy,
    ));
  }

  // ── Kalman 1-D boussole (gestion passage 359°→1°) ────────────────────────
  double _kalmanUpdate(double measurement) {
    final diff   = ((measurement - _kfState + 540) % 360) - 180;
    final mNorm  = _kfState + diff;
    final pError = _kfError + _kfQ;
    final k      = pError / (pError + _kfR);
    _kfState     = (_kfState + k * (mNorm - _kfState) + 360) % 360;
    _kfError     = (1 - k) * pError;
    return _kfState;
  }

  void dispose() {
    _compassSub?.cancel();
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _controller.close();
    debugPrint('[ArSensor] disposed');
  }
}
