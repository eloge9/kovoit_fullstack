import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_constants.dart';
import 'storage_service.dart';

// ── Modèles de données ────────────────────────────────────────────────────────

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
        speedKmh: (json['vitesse_kmh'] as num?)?.toDouble() ??
            ((json['speed'] as num?)?.toDouble() ?? 0) * 3.6,
        heading: (json['heading'] as num?)?.toDouble() ?? 0,
        accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

/// Position d'un passager reçue côté conducteur.
class PassengerPositionData {
  final String userId;
  final String nom;
  final double latitude;
  final double longitude;
  final DateTime? timestamp;

  const PassengerPositionData({
    required this.userId,
    required this.nom,
    required this.latitude,
    required this.longitude,
    this.timestamp,
  });

  factory PassengerPositionData.fromJson(Map<String, dynamic> json) =>
      PassengerPositionData(
        userId: json['user_id']?.toString() ?? '',
        nom: (json['nom'] as String?)?.isNotEmpty == true
            ? json['nom'] as String
            : 'Passager',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String)
            : null,
      );
}

/// Événement reçu quand le conducteur est arrivé chez un passager.
class DriverArrivedEvent {
  final String userId;
  final String nom;
  final int distanceM;

  const DriverArrivedEvent({
    required this.userId,
    required this.nom,
    required this.distanceM,
  });

  factory DriverArrivedEvent.fromJson(Map<String, dynamic> json) =>
      DriverArrivedEvent(
        userId: json['user_id']?.toString() ?? '',
        nom: (json['nom'] as String?) ?? '',
        distanceM: (json['distance_m'] as num?)?.toInt() ?? 0,
      );
}

/// Événement reçu côté passager (et conducteur) quand l'embarquement est validé.
class PassengerBoardedEvent {
  final String userId;
  final String nom;

  const PassengerBoardedEvent({required this.userId, required this.nom});

  factory PassengerBoardedEvent.fromJson(Map<String, dynamic> json) =>
      PassengerBoardedEvent(
        userId: json['user_id']?.toString() ?? '',
        nom: (json['nom'] as String?) ?? '',
      );
}

/// Passager d'un trajet avec statut d'embarquement — source : API REST.
/// Enrichi progressivement avec la position GPS quand disponible via WS.
class PassagerReservation {
  final int reservationId;
  final String userId;
  final String nom;
  final String? photoUrl;
  final int placesReservees;
  final String? phone;
  final int? conversationId;
  String statutEmbarquement;
  double? latitude;
  double? longitude;
  DateTime? lastGps;

  PassagerReservation({
    required this.reservationId,
    required this.userId,
    required this.nom,
    required this.placesReservees,
    required this.statutEmbarquement,
    this.photoUrl,
    this.phone,
    this.conversationId,
    this.latitude,
    this.longitude,
    this.lastGps,
  });

  bool get hasGps => latitude != null && longitude != null;
  bool get estEmbarque => statutEmbarquement == 'embarque';
  bool get estAbsent => statutEmbarquement == 'absent';

  factory PassagerReservation.fromJson(Map<String, dynamic> json) =>
      PassagerReservation(
        reservationId:      (json['reservation_id'] as num).toInt(),
        userId:             json['user_id']?.toString() ?? '',
        nom:                (json['nom'] as String?)?.isNotEmpty == true ? json['nom'] as String : 'Passager',
        photoUrl:           json['photo_url'] as String?,
        placesReservees:    (json['places_reservees'] as num?)?.toInt() ?? 1,
        statutEmbarquement: (json['statut_embarquement'] as String?) ?? 'en_attente',
        phone:              json['phone'] as String?,
        conversationId:     (json['conversation_id'] as num?)?.toInt(),
      );

  PassagerReservation copyWithGps(double lat, double lng) => PassagerReservation(
        reservationId:      reservationId,
        userId:             userId,
        nom:                nom,
        photoUrl:           photoUrl,
        placesReservees:    placesReservees,
        statutEmbarquement: statutEmbarquement,
        phone:              phone,
        conversationId:     conversationId,
        latitude:           lat,
        longitude:          lng,
        lastGps:            DateTime.now(),
      );

  PassagerReservation copyWithStatut(String statut) => PassagerReservation(
        reservationId:      reservationId,
        userId:             userId,
        nom:                nom,
        photoUrl:           photoUrl,
        placesReservees:    placesReservees,
        statutEmbarquement: statut,
        phone:              phone,
        conversationId:     conversationId,
        latitude:           latitude,
        longitude:          longitude,
        lastGps:            lastGps,
      );
}

// ── Service principal ─────────────────────────────────────────────────────────

class LocationService {
  WebSocketChannel? _channel;
  StreamSubscription<Position>? _positionSub;      // conducteur → envoi continu
  StreamSubscription<Position>? _sharePositionSub; // passager → partage opt-in
  Timer? _reconnectTimer;
  Timer? _passengerSendTimer;
  bool _disposed = false;
  String _userNom = '';
  Position? _lastSharedPosition;

  // Streams exposés
  StreamController<LocationData>? _locationController;
  StreamController<PassengerPositionData>? _passengersController;
  StreamController<DriverArrivedEvent>? _driverArrivedController;
  StreamController<PassengerBoardedEvent>? _boardedController;

  Stream<LocationData>? get locationStream => _locationController?.stream;
  Stream<PassengerPositionData>? get passengersStream => _passengersController?.stream;
  Stream<DriverArrivedEvent>? get driverArrivedStream => _driverArrivedController?.stream;
  Stream<PassengerBoardedEvent>? get boardedStream => _boardedController?.stream;

  bool get isSharingPosition =>
      _sharePositionSub != null || _passengerSendTimer != null;

  // ── Permissions ───────────────────────────────────────────────────────────

  static Future<bool> requestPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever;
  }

  // ── Conducteur : envoi de position + réception positions passagers ─────────

  Future<void> startSendingLocation(int trajetId) async {
    _passengersController = StreamController<PassengerPositionData>.broadcast();
    _driverArrivedController = StreamController<DriverArrivedEvent>.broadcast();
    _boardedController = StreamController<PassengerBoardedEvent>.broadcast();

    final hasPermission = await requestPermission();
    if (!hasPermission) {
      debugPrint('[LocationService] permission GPS refusée');
      return;
    }
    await _connectWsConducteur(trajetId);
    _startPositionStream();
  }

  Future<void> _connectWsConducteur(int trajetId) async {
    if (_disposed) return;
    final token = await StorageService.getAccessToken();
    if (token == null) return;

    try {
      final uri = Uri.parse('${ApiConstants.wsBaseUrl}/gps/$trajetId/?token=$token');
      _channel = WebSocketChannel.connect(uri);
      debugPrint('[LocationService] conducteur WS connecté trajet=$trajetId');

      _channel!.stream.listen(
        (rawData) {
          try {
            final json = jsonDecode(rawData as String) as Map<String, dynamic>;
            final type = json['type'] as String?;
            if (type == 'passenger_position') {
              _passengersController?.add(PassengerPositionData.fromJson(json));
            } else if (type == 'driver_arrived') {
              _driverArrivedController?.add(DriverArrivedEvent.fromJson(json));
            } else if (type == 'passenger_boarded') {
              _boardedController?.add(PassengerBoardedEvent.fromJson(json));
            }
          } catch (e) {
            debugPrint('[LocationService] parse error: $e');
          }
        },
        onError: (e) {
          debugPrint('[LocationService] conducteur WS error: $e');
          _scheduleReconnect(() => _connectWsConducteur(trajetId));
        },
        onDone: () {
          if (!_disposed) _scheduleReconnect(() => _connectWsConducteur(trajetId));
        },
      );
    } catch (e) {
      debugPrint('[LocationService] WS connexion échouée: $e');
      _scheduleReconnect(() => _connectWsConducteur(trajetId));
    }
  }

  void _startPositionStream() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      final data = LocationData.fromPosition(position);
      _sendConducteurPosition(data);
    });
  }

  void _sendConducteurPosition(LocationData data) {
    try {
      _channel?.sink.add(jsonEncode({
        'type': 'position',
        'latitude': data.latitude,
        'longitude': data.longitude,
        'vitesse_kmh': data.speedKmh,
        'heading': data.heading,
        'accuracy': data.accuracy,
        'timestamp': data.timestamp.toIso8601String(),
      }));
    } catch (e) {
      debugPrint('[LocationService] sendConducteurPosition error: $e');
    }
  }

  // ── Passager : réception position conducteur (SANS envoi auto) ────────────

  Future<void> startReceivingLocation(int trajetId, {String nom = ''}) async {
    _userNom = nom;
    _locationController = StreamController<LocationData>.broadcast();
    _driverArrivedController = StreamController<DriverArrivedEvent>.broadcast();
    _boardedController = StreamController<PassengerBoardedEvent>.broadcast();
    await _connectWsPassager(trajetId);
    // L'envoi de position est opt-in via startSharingPosition()
  }

  Future<void> _connectWsPassager(int trajetId) async {
    if (_disposed) return;
    final token = await StorageService.getAccessToken();
    if (token == null) return;

    try {
      final uri = Uri.parse('${ApiConstants.wsBaseUrl}/gps/$trajetId/?token=$token');
      _channel = WebSocketChannel.connect(uri);
      debugPrint('[LocationService] passager WS connecté trajet=$trajetId');

      _channel!.stream.listen(
        (rawData) {
          try {
            final json = jsonDecode(rawData as String) as Map<String, dynamic>;
            final type = json['type'] as String?;
            if (type == 'position_update' ||
                (json['latitude'] != null &&
                    type != 'passenger_position' &&
                    type != 'driver_arrived' &&
                    type != 'passenger_boarded')) {
              _locationController?.add(LocationData.fromJson(json));
            } else if (type == 'driver_arrived') {
              _driverArrivedController?.add(DriverArrivedEvent.fromJson(json));
            } else if (type == 'passenger_boarded') {
              stopSharingPosition();
              _boardedController?.add(PassengerBoardedEvent.fromJson(json));
            }
          } catch (e) {
            debugPrint('[LocationService] passager parse error: $e');
          }
        },
        onError: (e) {
          debugPrint('[LocationService] passager WS error: $e');
          _scheduleReconnect(() => _connectWsPassager(trajetId));
        },
        onDone: () {
          if (!_disposed) _scheduleReconnect(() => _connectWsPassager(trajetId));
        },
      );
    } catch (e) {
      debugPrint('[LocationService] passager WS connexion échouée: $e');
      _scheduleReconnect(() => _connectWsPassager(trajetId));
    }
  }

  // ── Passager : partage de position opt-in (économie batterie) ────────────

  /// Démarre l'envoi de la position du passager vers le conducteur.
  /// Économie batterie : stream déclenché si déplacement > 20m OU timer 5s max.
  /// Appeler uniquement après consentement explicite.
  Future<void> startSharingPosition({String nom = ''}) async {
    if (nom.isNotEmpty) _userNom = nom;
    final hasPermission = await requestPermission();
    if (!hasPermission || _disposed) return;

    // Envoi immédiat
    await _sendSharePosition();

    // Stream GPS déclenché à chaque 20m de déplacement (économie batterie)
    _sharePositionSub?.cancel();
    _sharePositionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((pos) {
      if (_disposed) return;
      _lastSharedPosition = pos;
      _sendSharePositionFromPos(pos);
    });

    // Fallback : envoyer au moins toutes les 5s même si immobile
    _passengerSendTimer?.cancel();
    _passengerSendTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_disposed) return;
      if (_lastSharedPosition != null) {
        _sendSharePositionFromPos(_lastSharedPosition!);
      } else {
        await _sendSharePosition();
      }
    });

    debugPrint('[LocationService] partage position passager démarré');
  }

  /// Arrête l'envoi de position du passager (garde le WS ouvert pour recevoir).
  void stopSharingPosition() {
    _sharePositionSub?.cancel();
    _sharePositionSub = null;
    _passengerSendTimer?.cancel();
    _passengerSendTimer = null;
    _lastSharedPosition = null;
    debugPrint('[LocationService] partage position passager arrêté');
  }

  void _sendSharePositionFromPos(Position pos) {
    try {
      _channel?.sink.add(jsonEncode({
        'type': 'passenger_position',
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'nom': _userNom,
        'timestamp': DateTime.now().toIso8601String(),
      }));
    } catch (e) {
      debugPrint('[LocationService] sendSharePosition error: $e');
    }
  }

  Future<void> _sendSharePosition() async {
    if (_disposed) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (_disposed) return;
      _lastSharedPosition = pos;
      _sendSharePositionFromPos(pos);
    } catch (e) {
      debugPrint('[LocationService] _sendSharePosition error: $e');
    }
  }

  void _scheduleReconnect(Future<void> Function() reconnectFn) {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      if (_disposed) return;
      debugPrint('[LocationService] Reconnexion WS...');
      await reconnectFn();
    });
  }

  // ── Utilitaires statiques ─────────────────────────────────────────────────

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

  /// Azimut (bearing) en degrés de (lat1,lng1) vers (lat2,lng2). 0=N, 90=E.
  static double bearingTo(
    double lat1, double lng1,
    double lat2, double lng2,
  ) {
    final dLng = _rad(lng2 - lng1);
    final lat1r = _rad(lat1);
    final lat2r = _rad(lat2);
    final y = sin(dLng) * cos(lat2r);
    final x = cos(lat1r) * sin(lat2r) - sin(lat1r) * cos(lat2r) * cos(dLng);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  static double _rad(double deg) => deg * pi / 180;

  static int etaMinutes(double distanceKm, double speedKmh) {
    if (speedKmh < 2) return -1;
    return (distanceKm / speedKmh * 60).round();
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _passengerSendTimer?.cancel();
    _positionSub?.cancel();
    _sharePositionSub?.cancel();
    _channel?.sink.close();
    _locationController?.close();
    _passengersController?.close();
    _driverArrivedController?.close();
    _boardedController?.close();
    _boardedController = null;
    _reconnectTimer = null;
    _passengerSendTimer = null;
    _positionSub = null;
    _sharePositionSub = null;
    _channel = null;
    _locationController = null;
    _passengersController = null;
    _driverArrivedController = null;
    _lastSharedPosition = null;
  }
}
