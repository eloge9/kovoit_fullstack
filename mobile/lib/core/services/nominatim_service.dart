import 'package:dio/dio.dart';

class LocationSuggestion {
  final String displayName;
  final String shortName;
  final double lat;
  final double lng;

  const LocationSuggestion({
    required this.displayName,
    required this.shortName,
    required this.lat,
    required this.lng,
  });

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    final display = json['display_name'] as String? ?? '';
    final parts = display.split(',');
    final short = parts.take(2).join(',').trim();
    return LocationSuggestion(
      displayName: display,
      shortName: short,
      lat: double.tryParse(json['lat']?.toString() ?? '') ?? 0,
      lng: double.tryParse(json['lon']?.toString() ?? '') ?? 0,
    );
  }
}

class NominatimService {
  static final _dio = Dio(BaseOptions(
    baseUrl: 'https://nominatim.openstreetmap.org',
    headers: {'User-Agent': 'KoVoit/1.0'},
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  static Future<List<LocationSuggestion>> autocomplete(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final resp = await _dio.get('/search', queryParameters: {
        'q': query,
        'format': 'json',
        'limit': 5,
        'countrycodes': 'tg,bj,gh,ci',
        'addressdetails': 0,
      });
      final list = resp.data as List;
      return list
          .map((e) => LocationSuggestion.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final resp = await _dio.get('/reverse', queryParameters: {
        'lat': lat,
        'lon': lng,
        'format': 'json',
      });
      final data = resp.data as Map<String, dynamic>;
      return data['display_name'] as String?;
    } catch (_) {
      return null;
    }
  }
}
