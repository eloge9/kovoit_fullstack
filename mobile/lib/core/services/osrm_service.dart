import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class OsrmRoute {
  final double distanceKm;
  final int durationMin;
  final String encodedPolyline;
  final List<LatLng> points;

  const OsrmRoute({
    required this.distanceKm,
    required this.durationMin,
    required this.encodedPolyline,
    required this.points,
  });
}

class OsrmService {
  static final _dio = Dio(BaseOptions(
    baseUrl: 'https://router.project-osrm.org',
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

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
          'overview': 'full',
          'geometries': 'polyline',
          'steps': 'false',
        },
      );
      final data = resp.data as Map<String, dynamic>;
      if (data['code'] != 'Ok') return null;
      final routes = data['routes'] as List;
      if (routes.isEmpty) return null;
      final route = routes.first as Map<String, dynamic>;
      final encoded = route['geometry'] as String;
      final distance = ((route['distance'] as num) / 1000).toDouble();
      final duration = ((route['duration'] as num) / 60).round();
      return OsrmRoute(
        distanceKm: distance,
        durationMin: duration,
        encodedPolyline: encoded,
        points: decodePolyline(encoded),
      );
    } catch (_) {
      return null;
    }
  }

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
    for (int i = 0; i < exp; i++) { r *= 10; }
    return r;
  }
}
