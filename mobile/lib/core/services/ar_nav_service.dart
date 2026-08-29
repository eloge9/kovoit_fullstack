import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'location_service.dart';
import 'route_step.dart';

// ── État AR (résultat de chaque calcul) ───────────────────────────────────────

class ArNavState {
  /// Cap à suivre le long de la route (degrés, 0=Nord, sens horaire).
  final double routeBearing;

  /// Cap boussole lissé par filtre de Kalman (degrés, 0=Nord, sens horaire).
  final double filteredHeading;

  /// Angle de rotation de la flèche AR = routeBearing - filteredHeading,
  /// normalisé dans [-180, 180]. Positif → flèche à droite.
  final double arrowAngleDeg;

  /// Prochaine manœuvre OSRM.
  final RouteStep? upcomingStep;

  /// Distance en mètres jusqu'à la prochaine manœuvre.
  final double distanceToStep;

  /// Vrai si l'utilisateur est aligné (flèche ≈ 0°).
  final bool aligned;

  /// Vrai si l'utilisateur est à plus de 50 m de la polyligne.
  final bool offRoute;

  const ArNavState({
    required this.routeBearing,
    required this.filteredHeading,
    required this.arrowAngleDeg,
    this.upcomingStep,
    required this.distanceToStep,
    required this.aligned,
    required this.offRoute,
  });

  /// Instruction à afficher dans l'overlay AR.
  String get instruction {
    if (upcomingStep == null) return '⬆ Suivez la route';
    final step = upcomingStep!;
    if (distanceToStep.isInfinite || distanceToStep > 9999) return '${step.icon} ${step.label}';
    if (distanceToStep < 15) return '${step.icon} ${step.label} maintenant';
    final distStr = distanceToStep >= 1000
        ? '${(distanceToStep / 1000).toStringAsFixed(1)} km'
        : '${distanceToStep.round()} m';
    return '${step.icon} ${step.label}  ·  $distStr';
  }

  /// Instruction courte pour l'overlay (sans distance).
  String get shortInstruction => upcomingStep?.label ?? 'Suivez la route';
}

// ── Service principal ─────────────────────────────────────────────────────────

/// Navigation AR basée sur la polyligne OSRM.
/// Source de vérité unique : le trajet calculé sur la carte.
///
/// Algorithme :
/// 1. Filtre de Kalman sur le cap boussole (lissage, anti-tremblements).
/// 2. Projection de la position GPS sur la polyligne (closest point on segment).
/// 3. Bearing lookahead 30 m en avant sur la route (direction réelle à suivre).
/// 4. Angle flèche = routeBearing − compassHeading.
/// 5. Avancement automatique des étapes OSRM.
class ArNavService {
  final List<LatLng> routePoints;
  final List<RouteStep> steps;

  // ── Filtre de Kalman 1-D pour le cap ──────────────────────────────────────
  double _kfState = 0;
  double _kfError = 180.0; // incertitude initiale élevée
  static const double _kfQ = 1.0; // bruit de processus (°)
  static const double _kfR = 8.0; // bruit de mesure (°)

  // ── Progression sur la route ──────────────────────────────────────────────
  int _nearestSegIdx = 0;
  int _stepIdx = 0;

  ArNavService({required this.routePoints, required this.steps}) {
    // Sauter l'étape de départ si elle est la première
    if (steps.isNotEmpty && steps.first.isDeparture) {
      _stepIdx = 1;
    }
  }

  // ── Point d'entrée principal ──────────────────────────────────────────────

  /// Appeler à chaque tick GPS + boussole.
  ArNavState update({
    required double lat,
    required double lng,
    required double rawHeading,
    double? gpsAccuracy,
  }) {
    // 1. Kalman filter
    final heading = _kalmanUpdate(rawHeading);

    if (routePoints.length < 2) {
      return ArNavState(
        routeBearing:   heading,
        filteredHeading: heading,
        arrowAngleDeg:  0,
        distanceToStep: double.infinity,
        aligned:        true,
        offRoute:       false,
      );
    }

    // 2. Projection sur la polyligne
    final proj = _projectOnRoute(lat, lng);

    // 3. Hors-route ?
    final distFromRouteM = LocationService.distanceKm(
      lat, lng, proj.lat, proj.lng,
    ) * 1000;
    final offRoute = distFromRouteM > 50;

    // 4. Bearing lookahead 30 m en avant
    final routeBearing = _lookaheadBearing(proj.lat, proj.lng, _nearestSegIdx);

    // 5. Angle flèche AR
    final arrowDeg = _normAngle(routeBearing - heading);

    // 6. Prochaine manœuvre
    _advanceStepIfNeeded(lat, lng);
    final upcoming = _stepIdx < steps.length ? steps[_stepIdx] : null;
    final distToStep = upcoming != null
        ? LocationService.distanceKm(
              lat, lng,
              upcoming.location.latitude,
              upcoming.location.longitude,
            ) *
            1000
        : double.infinity;

    return ArNavState(
      routeBearing:   routeBearing,
      filteredHeading: heading,
      arrowAngleDeg:  arrowDeg,
      upcomingStep:   upcoming,
      distanceToStep: distToStep,
      aligned:        arrowDeg.abs() < 20,
      offRoute:       offRoute,
    );
  }

  // ── Filtre de Kalman ──────────────────────────────────────────────────────

  double _kalmanUpdate(double measurement) {
    // Normalise la mesure par rapport à l'état courant (gestion passage 359°→1°)
    final diff = ((measurement - _kfState + 540) % 360) - 180;
    final mNorm = _kfState + diff;

    // Prédiction (modèle de marche aléatoire sans vitesse angulaire)
    final predError = _kfError + _kfQ;

    // Gain de Kalman
    final k = predError / (predError + _kfR);

    // Mise à jour de l'état et de l'incertitude
    _kfState = (_kfState + k * (mNorm - _kfState) + 360) % 360;
    _kfError = (1 - k) * predError;

    return _kfState;
  }

  // ── Projection sur la polyligne ───────────────────────────────────────────

  _Proj _projectOnRoute(double lat, double lng) {
    // Recherche dans une fenêtre glissante autour du dernier index connu
    final iStart = (_nearestSegIdx - 3).clamp(0, routePoints.length - 2);
    final iEnd   = (_nearestSegIdx + 50).clamp(0, routePoints.length - 1);

    double minDist = double.infinity;
    int    bestSeg = _nearestSegIdx;
    double bLat = lat, bLng = lng;

    for (int i = iStart; i < iEnd && i + 1 < routePoints.length; i++) {
      final a = routePoints[i];
      final b = routePoints[i + 1];
      final p = _closestOnSegment(
        lat, lng,
        a.latitude, a.longitude,
        b.latitude, b.longitude,
      );
      final d = LocationService.distanceKm(lat, lng, p.lat, p.lng) * 1000;
      if (d < minDist) {
        minDist = d;
        bestSeg = i;
        bLat = p.lat;
        bLng = p.lng;
      }
    }
    _nearestSegIdx = bestSeg;
    return _Proj(bLat, bLng);
  }

  _Proj _closestOnSegment(
    double px, double py,
    double ax, double ay,
    double bx, double by,
  ) {
    final dx = bx - ax, dy = by - ay;
    if (dx == 0 && dy == 0) return _Proj(ax, ay);
    final t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
    final tc = t.clamp(0.0, 1.0);
    return _Proj(ax + tc * dx, ay + tc * dy);
  }

  // ── Bearing lookahead ─────────────────────────────────────────────────────

  double _lookaheadBearing(double fromLat, double fromLng, int fromSeg) {
    const lookaheadM = 30.0;
    double accum = 0;
    double prevLat = fromLat, prevLng = fromLng;

    for (int i = fromSeg + 1; i < routePoints.length; i++) {
      final p = routePoints[i];
      final d = LocationService.distanceKm(prevLat, prevLng, p.latitude, p.longitude) * 1000;
      accum += d;
      if (accum >= lookaheadM) {
        return LocationService.bearingTo(fromLat, fromLng, p.latitude, p.longitude);
      }
      prevLat = p.latitude;
      prevLng = p.longitude;
    }

    // Route plus courte que le lookahead → bearing vers le dernier point
    final last = routePoints.last;
    return LocationService.bearingTo(fromLat, fromLng, last.latitude, last.longitude);
  }

  // ── Avancement automatique des étapes ────────────────────────────────────

  void _advanceStepIfNeeded(double lat, double lng) {
    if (_stepIdx >= steps.length) return;
    final step = steps[_stepIdx];

    // Sauter départ automatiquement
    if (step.isDeparture) {
      if (_stepIdx < steps.length - 1) _stepIdx++;
      return;
    }

    // Avancer si on est à moins de 20 m de la manœuvre
    final distM = LocationService.distanceKm(
      lat, lng, step.location.latitude, step.location.longitude,
    ) * 1000;

    if (distM < 20 && _stepIdx < steps.length - 1) {
      debugPrint('[ArNav] Étape validée : ${step.label} (${distM.round()} m)');
      _stepIdx++;
    }
  }

  // ── Utilitaires publics pour le world-rendering ──────────────────────────

  /// Retourne le LatLng à [distanceM] mètres en avant sur la route.
  LatLng? pointAtDistance(double distanceM) {
    if (routePoints.isEmpty) return null;
    double acc = 0;
    int startIdx = _nearestSegIdx.clamp(0, routePoints.length - 2);
    for (int i = startIdx; i < routePoints.length - 1; i++) {
      final a = routePoints[i];
      final b = routePoints[i + 1];
      final seg = LocationService.distanceKm(
            a.latitude, a.longitude, b.latitude, b.longitude) *
          1000;
      if (acc + seg >= distanceM) {
        final t = (distanceM - acc) / seg.clamp(0.001, double.infinity);
        return LatLng(
          a.latitude + t * (b.latitude - a.latitude),
          a.longitude + t * (b.longitude - a.longitude),
        );
      }
      acc += seg;
    }
    return routePoints.last;
  }

  /// Bearing de la route à [distanceM] mètres en avant (direction à suivre).
  double bearingAtDistance(double distanceM) {
    final p1 = pointAtDistance((distanceM - 3).clamp(0, double.infinity));
    final p2 = pointAtDistance(distanceM + 3);
    if (p1 == null || p2 == null) return _kfState;
    return LocationService.bearingTo(
        p1.latitude, p1.longitude, p2.latitude, p2.longitude);
  }

  double _normAngle(double d) => ((d + 180) % 360) - 180;
}

// ── Classe interne de projection ──────────────────────────────────────────────

class _Proj {
  final double lat, lng;
  _Proj(this.lat, this.lng);
}
