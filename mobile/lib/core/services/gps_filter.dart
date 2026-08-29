import 'dart:math';
import 'package:geolocator/geolocator.dart';

// ── Filtre de Kalman 1D ───────────────────────────────────────────────────────
//
// Utilisé séparément sur la latitude et la longitude.
// Le gain est modulé par la précision GPS (accuracy) : un signal peu précis
// (accuracy = 30 m) contribue moins qu'un signal précis (accuracy = 3 m).
//
// Paramètres conseillés pour GPS piéton/voiture :
//   q = 0.01   — bruit de processus : plus grand = suit mieux les changements
//                 brusques de trajectoire, mais amplifie le bruit.
//   errorMeasure = 1.0 — valeur par défaut si accuracy non fourni.

class SimpleKalmanFilter {
  double _estimate;
  double _errorEstimate;
  final double _errorMeasure;
  final double _q;

  SimpleKalmanFilter({
    required double initialEstimate,
    double errorEstimate = 1.0,
    double errorMeasure = 1.0,
    // q = 0.01 : bon compromis entre réactivité et lissage pour GPS voiture.
    double q = 0.01,
  })  : _estimate = initialEstimate,
        _errorEstimate = errorEstimate,
        _errorMeasure = errorMeasure,
        _q = q;

  /// Met à jour l'estimée avec [measurement].
  /// [accuracy] : précision GPS en mètres (fourni par geolocator) — plus grand
  /// = moins de confiance dans la mesure = filtre plus fort.
  double update(double measurement, {double? accuracy}) {
    final measureError = accuracy ?? _errorMeasure;
    final kalmanGain = _errorEstimate / (_errorEstimate + measureError);
    _estimate = _estimate + kalmanGain * (measurement - _estimate);
    _errorEstimate = (1 - kalmanGain) * _errorEstimate + _q.abs();
    return _estimate;
  }

  double get value => _estimate;
}

// ── Filtre GPS composite ──────────────────────────────────────────────────────
//
// Applique :
//   1. Rejet des points aberrants (saut physiquement impossible > 250 km/h)
//   2. Filtre de Kalman 1D séparé sur lat et lng
//
// Utilisation :
//   final filter = GpsFilter();
//   final filtered = filter.update(rawPosition);
//   if (filtered != null) { // null = point rejeté }

class GpsFilter {
  SimpleKalmanFilter? _latFilter;
  SimpleKalmanFilter? _lngFilter;

  double? _prevLat;
  double? _prevLng;
  DateTime? _prevTime;

  // Seuil de rejet : 250 km/h = 69.4 m/s.
  // Au-delà, le point GPS est considéré comme un artefact (glitch satellite,
  // multipath urbain, switch antenne) et est ignoré.
  static const double _maxSpeedMs = 69.4; // 250 km/h en m/s

  /// Retourne une position filtrée, ou null si le point est rejeté.
  /// La position retournée garde tous les champs d'origine (accuracy, speed,
  /// heading…) mais avec lat/lng filtrées.
  Position? update(Position raw) {
    final now = raw.timestamp;
    final lat = raw.latitude;
    final lng = raw.longitude;

    // ── 1. Rejet des aberrants ────────────────────────────────────────────────
    if (_prevLat != null && _prevTime != null) {
      final dt = now.difference(_prevTime!).inMilliseconds / 1000.0;
      if (dt > 0) {
        final distM = _haversineM(_prevLat!, _prevLng!, lat, lng);
        final impliedSpeed = distM / dt;
        if (impliedSpeed > _maxSpeedMs) {
          // Saut trop important — ignorer ce point (GPS glitch).
          return null;
        }
      }
    }

    // ── 2. Init ou mise à jour des filtres ────────────────────────────────────
    if (_latFilter == null) {
      _latFilter = SimpleKalmanFilter(initialEstimate: lat);
      _lngFilter = SimpleKalmanFilter(initialEstimate: lng);
    }

    final filtLat = _latFilter!.update(lat, accuracy: raw.accuracy);
    final filtLng = _lngFilter!.update(lng, accuracy: raw.accuracy);

    _prevLat  = filtLat;
    _prevLng  = filtLng;
    _prevTime = now;

    // Retourner une Position avec les coordonnées filtrées
    return Position(
      latitude:             filtLat,
      longitude:            filtLng,
      accuracy:             raw.accuracy,
      altitude:             raw.altitude,
      altitudeAccuracy:     raw.altitudeAccuracy,
      heading:              raw.heading,
      headingAccuracy:      raw.headingAccuracy,
      speed:                raw.speed,
      speedAccuracy:        raw.speedAccuracy,
      timestamp:            raw.timestamp,
      isMocked:             raw.isMocked,
    );
  }

  void reset() {
    _latFilter = null;
    _lngFilter = null;
    _prevLat = null;
    _prevLng = null;
    _prevTime = null;
  }

  // Distance haversine en mètres (version légère, sans import LocationService)
  static double _haversineM(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}
