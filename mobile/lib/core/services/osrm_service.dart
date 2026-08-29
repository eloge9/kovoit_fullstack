import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'route_step.dart';

// ── Modèle de route ───────────────────────────────────────────────────────────

class OsrmRoute {
  final double distanceKm;
  final int durationMin;
  final String encodedPolyline;
  final List<LatLng> points;
  final List<RouteStep> steps;

  const OsrmRoute({
    required this.distanceKm,
    required this.durationMin,
    required this.encodedPolyline,
    required this.points,
    this.steps = const [],
  });
}

// ── Service OSRM ──────────────────────────────────────────────────────────────

class OsrmService {
  static final _dio = Dio(BaseOptions(
    baseUrl: 'https://router.project-osrm.org',
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  /// Calcule un itinéraire avec polyligne complète + étapes de navigation.
  static Future<OsrmRoute?> getRoute(
    double fromLat,
    double fromLng,
    double toLat,
    double toLng,
  ) async {
    try {
      final resp = await _dio.get(
        '/route/v1/driving/$fromLng,$fromLat;$toLng,$toLat',
        queryParameters: {
          'overview':   'full',
          'geometries': 'polyline',
          'steps':      'true',  // étapes de navigation OSRM
        },
      );

      final data = resp.data as Map<String, dynamic>;
      if (data['code'] != 'Ok') return null;

      final routes = data['routes'] as List;
      if (routes.isEmpty) return null;

      final route   = routes.first as Map<String, dynamic>;
      final encoded = route['geometry'] as String;
      final points  = decodePolyline(encoded);

      final distanceKm = ((route['distance'] as num) / 1000).toDouble();
      final durationMin = ((route['duration'] as num) / 60).round();

      // Extraire les étapes depuis les legs OSRM
      final steps = _parseSteps(route);

      return OsrmRoute(
        distanceKm:      distanceKm,
        durationMin:     durationMin,
        encodedPolyline: encoded,
        points:          points,
        steps:           steps,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Parsing des étapes ────────────────────────────────────────────────────

  static List<RouteStep> _parseSteps(Map<String, dynamic> route) {
    final steps = <RouteStep>[];
    final legs = route['legs'] as List? ?? [];
    for (final leg in legs) {
      final legMap = leg as Map<String, dynamic>;
      final legSteps = legMap['steps'] as List? ?? [];
      for (final step in legSteps) {
        final stepMap = step as Map<String, dynamic>;
        try {
          steps.add(RouteStep.fromJson(stepMap));
        } catch (_) {
          // Ignorer les étapes malformées
        }
      }
    }
    return steps;
  }

  // ── Décodage polyligne Google ─────────────────────────────────────────────

  static List<LatLng> decodePolyline(String encoded, {int precision = 5}) {
    final result = <LatLng>[];
    int index = 0, lat = 0, lng = 0;
    final factor = _pow10(precision);
    while (index < encoded.length) {
      int b, shift = 0, result2 = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result2 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result2 & 1) != 0 ? ~(result2 >> 1) : result2 >> 1;
      lat += dlat;
      shift = 0;
      result2 = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result2 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result2 & 1) != 0 ? ~(result2 >> 1) : result2 >> 1;
      lng += dlng;
      result.add(LatLng(lat / factor, lng / factor));
    }
    return result;
  }

  static int _pow10(int exp) {
    int r = 1;
    for (int i = 0; i < exp; i++) {
      r *= 10;
    }
    return r;
  }
}
