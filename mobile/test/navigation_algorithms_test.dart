import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile/core/services/gps_filter.dart';
import 'package:mobile/core/services/ar_sensor_service.dart';
import 'package:mobile/core/services/location_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

double _normBearing(double d) => ((d % 360) + 360) % 360;

Position _fakePos({
  required double lat,
  required double lng,
  DateTime? time,
  double accuracy = 5.0,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
    timestamp: time ?? DateTime(2024, 1, 1, 12, 0, 0),
    isMocked: false,
  );
}

// ── Tests bearingTo ───────────────────────────────────────────────────────────

void main() {
  group('LocationService.bearingTo', () {
    test('Nord : A→B même longitude, B plus au nord', () {
      final b = LocationService.bearingTo(48.0, 2.0, 49.0, 2.0);
      expect(_normBearing(b), closeTo(0.0, 0.5));
    });

    test('Sud : A→B même longitude, B plus au sud', () {
      final b = LocationService.bearingTo(49.0, 2.0, 48.0, 2.0);
      expect(_normBearing(b), closeTo(180.0, 0.5));
    });

    test('Est : A→B même latitude, B plus à l\'est', () {
      final b = LocationService.bearingTo(48.0, 2.0, 48.0, 3.0);
      expect(_normBearing(b), closeTo(90.0, 1.0));
    });

    test('Ouest : A→B même latitude, B plus à l\'ouest', () {
      final b = LocationService.bearingTo(48.0, 3.0, 48.0, 2.0);
      expect(_normBearing(b), closeTo(270.0, 1.0));
    });

    test('Paris → Londres (~330°)', () {
      final b = LocationService.bearingTo(48.8566, 2.3522, 51.5074, -0.1278);
      expect(_normBearing(b), closeTo(330.0, 3.0));
    });

    test('Points identiques → valeur finie (pas de division par zéro)', () {
      final b = LocationService.bearingTo(48.0, 2.0, 48.0, 2.0);
      expect(b.isFinite, isTrue);
    });
  });

  // ── Tests SimpleKalmanFilter ─────────────────────────────────────────────────

  group('SimpleKalmanFilter', () {
    test('converge vers une valeur constante après 50 itérations', () {
      final kf = SimpleKalmanFilter(initialEstimate: 0);
      double result = 0;
      for (int i = 0; i < 50; i++) {
        result = kf.update(100.0);
      }
      expect(result, greaterThan(95.0));
    });

    test('premier update se rapproche de la mesure', () {
      final kf = SimpleKalmanFilter(initialEstimate: 0);
      final r = kf.update(50.0);
      expect(r, greaterThan(20.0));
    });

    test('accuracy élevée = convergence plus lente qu\'accuracy faible', () {
      final kfFaible = SimpleKalmanFilter(initialEstimate: 0);
      final kfPrecis = SimpleKalmanFilter(initialEstimate: 0);
      double rFaible = 0, rPrecis = 0;
      for (int i = 0; i < 10; i++) {
        rFaible = kfFaible.update(100.0, accuracy: 30.0);
        rPrecis = kfPrecis.update(100.0, accuracy: 3.0);
      }
      expect(rPrecis, greaterThan(rFaible));
    });

    test('bruit gaussien ±10 — sortie reste proche de la vraie valeur', () {
      final rng = Random(42);
      final kf = SimpleKalmanFilter(initialEstimate: 10.0);
      double last = 10.0;
      for (int i = 0; i < 100; i++) {
        final noisy = 10.0 + (rng.nextDouble() - 0.5) * 20;
        last = kf.update(noisy);
      }
      expect(last, closeTo(10.0, 3.0));
    });
  });

  // ── Tests ComplementaryHeadingFilter ─────────────────────────────────────────

  group('ComplementaryHeadingFilter', () {
    test('valeur initiale correcte', () {
      final f = ComplementaryHeadingFilter(initial: 90.0);
      expect(f.value, closeTo(90.0, 0.01));
    });

    test('α=1 (gyro pur) : intègre 90°/s pendant 1s → +90°', () {
      final f = ComplementaryHeadingFilter(initial: 0.0, alpha: 1.0);
      final result = f.update(gyroRateZ: pi / 2, compassHeading: 0, dt: 1.0);
      expect(result, closeTo(90.0, 0.5));
    });

    test('α=0 (boussole pure) : suit immédiatement la boussole', () {
      final f = ComplementaryHeadingFilter(initial: 0.0, alpha: 0.0);
      final result = f.update(gyroRateZ: 0, compassHeading: 180, dt: 0.02);
      expect(result, closeTo(180.0, 0.5));
    });

    test('passage 359°→0° sans saut négatif', () {
      final f = ComplementaryHeadingFilter(initial: 359.0, alpha: 0.98);
      double heading = 359.0;
      for (int i = 0; i < 5; i++) {
        heading = f.update(
          gyroRateZ: pi / 180, // 1°/s dans le sens horaire
          compassHeading: (359.0 + i + 1) % 360,
          dt: 1.0,
        );
      }
      final normalized = ((heading % 360) + 360) % 360;
      // Après 5s à 1°/s depuis 359°, on doit être ~4° et NON ~354° (saut)
      expect(normalized, lessThan(20.0));
    });

    test('resetTo() repart du cap demandé', () {
      final f = ComplementaryHeadingFilter(initial: 0.0);
      f.update(gyroRateZ: pi, compassHeading: 90, dt: 1.0);
      f.resetTo(270.0);
      expect(f.value, closeTo(270.0, 0.01));
    });

    test('α=0.98 : saut boussole de 20° produit <2° de changement immédiat', () {
      final f = ComplementaryHeadingFilter(initial: 0.0, alpha: 0.98);
      final r = f.update(gyroRateZ: 0, compassHeading: 20, dt: 0.02);
      expect(r, lessThan(2.0));
    });
  });

  // ── Tests GpsFilter (rejet aberrants) ────────────────────────────────────────

  group('GpsFilter', () {
    test('point normal (déplacement ~40 km/h) accepté', () {
      final gf = GpsFilter();
      gf.update(_fakePos(lat: 48.0, lng: 2.0, time: DateTime(2024, 1, 1, 12, 0, 0)));
      // ~11m en 1 seconde ≈ 40 km/h — bien en dessous du seuil de 250 km/h
      final result = gf.update(
          _fakePos(lat: 48.0001, lng: 2.0001, time: DateTime(2024, 1, 1, 12, 0, 1)));
      expect(result, isNotNull);
    });

    test('saut >250 km/h rejeté (GPS glitch)', () {
      final gf = GpsFilter();
      gf.update(_fakePos(lat: 48.0, lng: 2.0, time: DateTime(2024, 1, 1, 12, 0, 0)));
      // +0.9° de latitude ≈ 100 km en 1 seconde = ~360 000 km/h
      final result = gf.update(
          _fakePos(lat: 48.9, lng: 2.0, time: DateTime(2024, 1, 1, 12, 0, 1)));
      expect(result, isNull);
    });

    test('kalman lisse les coordonnées filtrées (lat/lng != raw)', () {
      final gf = GpsFilter();
      final raw = _fakePos(lat: 48.5, lng: 2.5, accuracy: 15.0);
      final filtered = gf.update(raw);
      // Premier point = init du filtre → coordonnées proches du raw
      expect(filtered, isNotNull);
      expect(filtered!.latitude, closeTo(48.5, 0.0001));
    });

    test('reset() accepte un grand saut ensuite', () {
      final gf = GpsFilter();
      gf.update(_fakePos(lat: 48.0, lng: 2.0, time: DateTime(2024, 1, 1, 12, 0, 0)));
      gf.reset();
      final result = gf.update(
          _fakePos(lat: 49.0, lng: 2.0, time: DateTime(2024, 1, 1, 12, 0, 1)));
      // Après reset, plus de référence précédente → saut accepté
      expect(result, isNotNull);
    });
  });
}
