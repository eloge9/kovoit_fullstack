import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_constants.dart';
import 'storage_service.dart';

/// Service GPS — envoie la position du conducteur via WebSocket
/// et permet au passager de voir la position en temps réel
class LocationService {
  WebSocketChannel? _channel;
  StreamSubscription<Position>? _positionSub;
  StreamController<Map<String, double>>? _locationController;

  Stream<Map<String, double>>? get locationStream =>
      _locationController?.stream;

  /// Demande les permissions de localisation
  static Future<bool> requestPermission() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      return result != LocationPermission.denied &&
             result != LocationPermission.deniedForever;
    }
    return permission != LocationPermission.deniedForever;
  }

  /// Démarre l'envoi de position (côté conducteur) via WebSocket
  Future<void> startSendingLocation(int trajetId) async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return;

    final token = await StorageService.getAccessToken();
    if (token == null) return;

    // Connexion WebSocket GPS
    try {
      final uri = Uri.parse(
        '${ApiConstants.wsBaseUrl}/gps/$trajetId/?token=$token',
      );
      _channel = WebSocketChannel.connect(uri);
    } catch (e) {
      return;
    }

    // Écoute la position GPS toutes les 5 secondes
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // envoi si déplacement de 10m minimum
    );

    _positionSub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((position) {
      _channel?.sink.add(jsonEncode({
        'type': 'location_update',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed': position.speed,
        'heading': position.heading,
        'accuracy': position.accuracy,
        'timestamp': DateTime.now().toIso8601String(),
      }));
    });
  }

  /// Démarre la réception de position (côté passager)
  Future<void> startReceivingLocation(int trajetId) async {
    final token = await StorageService.getAccessToken();
    if (token == null) return;

    _locationController = StreamController<Map<String, double>>.broadcast();

    try {
      final uri = Uri.parse(
        '${ApiConstants.wsBaseUrl}/gps/$trajetId/?token=$token',
      );
      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        (data) {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          if (json['type'] == 'location_update' ||
              json['latitude'] != null) {
            _locationController?.add({
              'latitude': (json['latitude'] as num).toDouble(),
              'longitude': (json['longitude'] as num).toDouble(),
            });
          }
        },
        onError: (_) {},
        onDone: () => _locationController?.close(),
      );
    } catch (e) {
      _locationController?.close();
    }
  }

  /// Obtient la position actuelle une seule fois
  static Future<Position?> getCurrentPosition() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Arrête tous les streams
  void dispose() {
    _positionSub?.cancel();
    _channel?.sink.close();
    _locationController?.close();
    _positionSub = null;
    _channel = null;
    _locationController = null;
  }
}
