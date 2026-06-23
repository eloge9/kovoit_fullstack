import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_constants.dart';
import 'storage_service.dart';

/// Données de position temps réel enrichies
class LocationData {
  final double latitude;
  final double longitude;
  final double speedKmh;
  final double heading;
  final double accuracy;
  final DateTime timestamp;

  const LocationData({
    required this.latitude,
    required this.longitude,
    this.speedKmh = 0,
    this.heading = 0,
    this.accuracy = 0,
    required this.timestamp,
  });

  factory LocationData.fromPosition(Position p) => LocationData(
        latitude: p.latitude,
        longitude: p.longitude,
        speedKmh: p.speed * 3.6,
        heading: p.heading,
        accuracy: p.accuracy,
        timestamp: DateTime.now(),
      );

  factory LocationData.fromJson(Map<String, dynamic> json) => LocationData(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        speedKmh: ((json['speed'] as num?)?.toDouble() ?? 0) * 3.6,
        heading: (json['heading'] as num?)?.toDouble() ?? 0,
        accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

class LocationService {
  WebSocketChannel? _channel;
  StreamSubscription<Position>? _positionSub;
  StreamController<LocationData>? _locationController;
  Timer? _reconnectTimer;
  bool _disposed = false;
  int _trajetId = 0;
  bool _isSending = false;

  Stream<LocationData>? get locationStream => _locationController?.stream;

  // ── Permissions ──────────────────────────────────────────────────────────────

  static Future<bool> requestPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  // ── Conducteur : envoi de position ──────────────────────────────────────────

  Future<void> startSendingLocation(int trajetId) async {
    _trajetId = trajetId;
    _isSending = true;
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      debugPrint('[LocationService] permission GPS refusée');
      return;
    }

    await _connectWs(trajetId);
    _startPositionStream();
  }

  Future<void> _connectWs(int trajetId) async {
    if (_disposed) return;
    final token = await StorageService.getAccessToken();
    if (token == null) return;

    try {
      final uri = Uri.parse('${ApiConstants.wsBaseUrl}/gps/$trajetId/?token=$token');
      _channel = WebSocketChannel.connect(uri);
      debugPrint('[LocationService] WS connecté trajet=$trajetId');

      // Surveiller la déconnexion pour reconnexion auto
      _channel!.stream.listen(
        (_) {},
        onError: (e) {
          debugPrint('[LocationService] WS error: $e');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[LocationService] WS fermé');
          if (!_disposed) _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('[LocationService] WS connexion échouée: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      if (_disposed) return;
      debugPrint('[LocationService] Reconnexion WS...');
      await _connectWs(_trajetId);
    });
  }

  void _startPositionStream() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // envoi si déplacement de 5m minimum
      ),
    ).listen((position) {
      final data = LocationData.fromPosition(position);
      _sendPosition(data);
      if (!_isSending) {
        _locationController?.add(data);
      }
    });
  }

  void _sendPosition(LocationData data) {
    try {
      _channel?.sink.add(jsonEncode({
        'type': 'location_update',
        'latitude': data.latitude,
        'longitude': data.longitude,
        'speed': data.speedKmh / 3.6,
        'heading': data.heading,
        'accuracy': data.accuracy,
        'timestamp': data.timestamp.toIso8601String(),
      }));
    } catch (e) {
      debugPrint('[LocationService] sendPosition error: $e');
    }
  }

  // ── Passager : réception de position ────────────────────────────────────────

  Future<void> startReceivingLocation(int trajetId) async {
    _trajetId = trajetId;
    _isSending = false;
    _locationController = StreamController<LocationData>.broadcast();
    await _connectWsReceiver(trajetId);
  }

  Future<void> _connectWsReceiver(int trajetId) async {
    if (_disposed) return;
    final token = await StorageService.getAccessToken();
    if (token == null) return;

    try {
      final uri = Uri.parse('${ApiConstants.wsBaseUrl}/gps/$trajetId/?token=$token');
      _channel = WebSocketChannel.connect(uri);
      debugPrint('[LocationService] WS passager connecté trajet=$trajetId');

      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            if (json['type'] == 'location_update' || json['latitude'] != null) {
              _locationController?.add(LocationData.fromJson(json));
            }
          } catch (e) {
            debugPrint('[LocationService] parse error: $e');
          }
        },
        onError: (e) {
          debugPrint('[LocationService] WS passager error: $e');
          _scheduleReconnectReceiver(trajetId);
        },
        onDone: () {
          debugPrint('[LocationService] WS passager fermé');
          if (!_disposed) _scheduleReconnectReceiver(trajetId);
        },
      );
    } catch (e) {
      debugPrint('[LocationService] WS passager connexion échouée: $e');
      _scheduleReconnectReceiver(trajetId);
    }
  }

  void _scheduleReconnectReceiver(int trajetId) {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      if (_disposed) return;
      debugPrint('[LocationService] Reconnexion passager WS...');
      await _connectWsReceiver(trajetId);
    });
  }

  // ── Utilitaires statiques ────────────────────────────────────────────────────

  static Future<Position?> getCurrentPosition() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('[LocationService] getCurrentPosition error: $e');
      return null;
    }
  }

  /// Calcule la distance en km entre deux points (formule Haversine)
  static double distanceKm(
    double lat1, double lng1,
    double lat2, double lng2,
  ) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) *
            sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _rad(double deg) => deg * pi / 180;

  /// ETA en minutes depuis la vitesse actuelle et la distance restante
  static int etaMinutes(double distanceKm, double speedKmh) {
    if (speedKmh < 2) return -1;
    return (distanceKm / speedKmh * 60).round();
  }

  // ── Dispose ──────────────────────────────────────────────────────────────────

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _positionSub?.cancel();
    _channel?.sink.close();
    _locationController?.close();
    _reconnectTimer = null;
    _positionSub = null;
    _channel = null;
    _locationController = null;
  }
}
