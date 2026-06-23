import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationSuggestion {
  final String displayName;
  final String shortName;
  final double lat;
  final double lng;
  final bool isCurrentPosition;
  final bool isHistory;

  const LocationSuggestion({
    required this.displayName,
    required this.shortName,
    required this.lat,
    required this.lng,
    this.isCurrentPosition = false,
    this.isHistory = false,
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

  static final LocationSuggestion currentPosition = LocationSuggestion(
    displayName: 'Ma position actuelle',
    shortName: 'Ma position actuelle',
    lat: 0,
    lng: 0,
    isCurrentPosition: true,
  );
}

class NominatimService {
  static final _dio = Dio(BaseOptions(
    baseUrl: 'https://nominatim.openstreetmap.org',
    headers: {'User-Agent': 'KoVoit/1.0 contact@kovoit.app'},
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
  ));

  // Historique local des lieux récents (max 10)
  static final List<LocationSuggestion> _history = [];

  static List<LocationSuggestion> get recentHistory =>
      List.unmodifiable(_history);

  static void addToHistory(LocationSuggestion suggestion) {
    if (suggestion.isCurrentPosition) return;
    _history.removeWhere((h) =>
        h.lat == suggestion.lat && h.lng == suggestion.lng);
    _history.insert(0, suggestion.copyWith(isHistory: true));
    if (_history.length > 8) _history.removeLast();
  }

  /// Recherche avec autocomplétion + position actuelle en premier
  static Future<List<LocationSuggestion>> autocomplete(
    String query, {
    bool includeCurrentPosition = true,
  }) async {
    final results = <LocationSuggestion>[];

    // "Ma position actuelle" toujours en premier si pertinent
    if (includeCurrentPosition &&
        (query.isEmpty || query.length < 2)) {
      results.add(LocationSuggestion.currentPosition);
      // Ajouter l'historique
      results.addAll(_history.take(5));
      return results;
    }

    if (includeCurrentPosition && query.length >= 2) {
      results.add(LocationSuggestion.currentPosition);
    }

    if (query.trim().length < 2) return results;

    try {
      final resp = await _dio.get('/search', queryParameters: {
        'q': query,
        'format': 'json',
        'limit': 5,
        'countrycodes': 'tg,bj,gh,ci,sn,cm,ne,ml',
        'addressdetails': 0,
        'accept-language': 'fr',
      });
      final list = resp.data as List;
      final apiResults = list
          .map((e) => LocationSuggestion.fromJson(e as Map<String, dynamic>))
          .toList();
      results.addAll(apiResults);
    } catch (e) {
      debugPrint('[Nominatim] autocomplete error: $e');
    }

    return results;
  }

  /// Géocode inversé : coordonnées → adresse
  static Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final resp = await _dio.get('/reverse', queryParameters: {
        'lat': lat,
        'lon': lng,
        'format': 'json',
        'accept-language': 'fr',
      });
      final data = resp.data as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;
      if (address != null) {
        // Construire un nom court depuis les composants d'adresse
        final road = address['road'] ?? address['pedestrian'] ?? '';
        final city = address['city'] ??
            address['town'] ??
            address['village'] ??
            address['county'] ??
            '';
        if (road.isNotEmpty && city.isNotEmpty) return '$road, $city';
        if (city.isNotEmpty) return city as String;
      }
      return data['display_name'] as String?;
    } catch (e) {
      debugPrint('[Nominatim] reverseGeocode error: $e');
      return null;
    }
  }

  /// Résout "Ma position actuelle" → coordonnées GPS réelles
  static Future<LocationSuggestion?> resolveCurrentPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final name = await reverseGeocode(pos.latitude, pos.longitude);
      return LocationSuggestion(
        displayName: name ?? 'Ma position actuelle',
        shortName: name ?? 'Position actuelle',
        lat: pos.latitude,
        lng: pos.longitude,
        isCurrentPosition: true,
      );
    } catch (e) {
      debugPrint('[Nominatim] resolveCurrentPosition error: $e');
      return null;
    }
  }
}

extension _LocationSuggestionCopy on LocationSuggestion {
  LocationSuggestion copyWith({
    String? displayName,
    String? shortName,
    double? lat,
    double? lng,
    bool? isCurrentPosition,
    bool? isHistory,
  }) =>
      LocationSuggestion(
        displayName: displayName ?? this.displayName,
        shortName: shortName ?? this.shortName,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        isCurrentPosition: isCurrentPosition ?? this.isCurrentPosition,
        isHistory: isHistory ?? this.isHistory,
      );
}
