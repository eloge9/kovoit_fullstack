import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_constants.dart';
import 'storage_service.dart';
import '../../features/notifications/models/notification_model.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Stream pour diffuser les notifications aux providers
  static final StreamController<NotificationModel> _streamController =
      StreamController<NotificationModel>.broadcast();

  static Stream<NotificationModel> get stream => _streamController.stream;

  // WebSocket état interne
  static WebSocketChannel? _wsChannel;
  static Timer? _reconnectTimer;
  static bool _isConnected = false;
  static String? _currentToken;

  static Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _initialized = true;
  }

  // Connexion WebSocket notifications
  static Future<void> connecter() async {
    final token = await StorageService.getAccessToken();
    if (token == null || token.isEmpty) return;

    _currentToken = token;
    _etablirConnexion();
  }

  static void _etablirConnexion() {
    if (_isConnected || _currentToken == null) return;

    try {
      final wsUrl =
          '${ApiConstants.wsBaseUrl}${ApiConstants.wsNotifications}?token=$_currentToken';
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;

      _wsChannel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            final notif = NotificationModel.fromJson(json);
            _streamController.add(notif);
            _afficherNotificationLocale(notif);
          } catch (e) {
            debugPrint('[NotificationService] Erreur parsing: $e');
          }
        },
        onError: (e) {
          debugPrint('[NotificationService] Erreur WS: $e');
          _isConnected = false;
          _wsChannel = null;
          _planifierReconnexion();
        },
        onDone: () {
          debugPrint('[NotificationService] WS fermé, reconnexion...');
          _isConnected = false;
          _wsChannel = null;
          _planifierReconnexion();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[NotificationService] Connexion échouée: $e');
      _isConnected = false;
      _planifierReconnexion();
    }
  }

  static void _planifierReconnexion() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected) _etablirConnexion();
    });
  }

  static Future<void> deconnecter() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _wsChannel?.sink.close();
    _wsChannel = null;
    _isConnected = false;
    _currentToken = null;
  }

  static Future<void> _afficherNotificationLocale(
    NotificationModel notif,
  ) async {
    await init();
    await _show(
      id: notif.timestamp.millisecondsSinceEpoch ~/ 1000 % 100000,
      title: notif.titre,
      body: notif.message,
      payload: notif.type,
    );
  }

  static Future<void> _show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await init();
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'kovoit_channel',
          'KoVoit',
          channelDescription: 'Notifications KoVoit',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  // Méthodes de notification directe (conservées pour compatibilité)
  static Future<void> reservationConfirmee(String conducteurNom) => _show(
    id: 1001,
    title: 'Réservation confirmée ✅',
    body: '$conducteurNom a accepté votre demande de covoiturage.',
  );

  static Future<void> reservationRefusee(String conducteurNom) => _show(
    id: 1002,
    title: 'Réservation refusée',
    body: '$conducteurNom n\'a pas pu accepter votre réservation.',
  );

  static Future<void> nouveauMessage(String expediteurNom, String apercu) =>
      _show(
        id: 1003,
        title: 'Message de $expediteurNom',
        body: apercu,
        payload: 'message:$expediteurNom',
      );

  static Future<void> trajetEnCours(String depart, String destination) => _show(
    id: 1004,
    title: 'Trajet démarré 🚗',
    body: 'Votre trajet $depart → $destination est en cours.',
  );

  static Future<void> trajetTermine(String destination) => _show(
    id: 1005,
    title: 'Trajet terminé ✅',
    body: 'Vous êtes arrivé à $destination. Pensez à évaluer votre trajet !',
  );

  static Future<void> nouvelleReservation(String passagerNom) => _show(
    id: 1006,
    title: 'Nouvelle demande de réservation',
    body: '$passagerNom souhaite rejoindre votre trajet.',
  );

  static Future<void> paiementRecu(String montant) => _show(
    id: 1007,
    title: 'Paiement reçu 💰',
    body: 'Vous avez reçu $montant FCFA pour votre trajet.',
  );
}
