import 'package:flutter/foundation.dart';
import '../network/dio_client.dart';
import 'location_service.dart';

typedef BoardingResult = ({bool ok, String? message, String? passager});

class BoardingService {
  /// Récupère la liste de tous les passagers confirmés du trajet avec leur statut d'embarquement.
  static Future<List<PassagerReservation>> getPassagers(int trajetId) async {
    try {
      final response = await DioClient.get('/trajets/$trajetId/passagers-embarquement/');
      final list = (response.data['passagers'] as List<dynamic>?) ?? [];
      return list
          .map((e) => PassagerReservation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[BoardingService] getPassagers error: $e');
      return [];
    }
  }

  /// Conducteur valide l'embarquement via code PIN KVT-XXXX.
  static Future<BoardingResult> embarquerParCode(String code) async {
    try {
      final response = await DioClient.post(
        '/reservations/embarquer/',
        data: {'code_embarquement': code.trim().toUpperCase()},
      );
      return (
        ok: true,
        message: response.data['message'] as String? ?? 'Embarquement validé.',
        passager: response.data['passager'] as String?,
      );
    } catch (e) {
      final msg = _extractError(e);
      debugPrint('[BoardingService] embarquerParCode error: $e');
      return (ok: false, message: msg, passager: null);
    }
  }

  /// Conducteur valide l'embarquement via token HMAC scanné depuis le QR passager.
  /// Format QR : KOVOIT:{reservationId}:{token}
  static Future<BoardingResult> validerQR(int reservationId, String token) async {
    try {
      final response = await DioClient.post(
        '/reservations/$reservationId/scanner-qr/',
        data: {'token': token.trim().toUpperCase()},
      );
      return (
        ok: true,
        message: response.data['deja_embarque'] == true
            ? 'Ce passager est déjà à bord.'
            : 'Embarquement validé.',
        passager: response.data['passager'] as String?,
      );
    } catch (e) {
      final msg = _extractError(e);
      debugPrint('[BoardingService] validerQR error: $e');
      return (ok: false, message: msg, passager: null);
    }
  }

  static String _extractError(Object e) {
    try {
      // ignore: avoid_dynamic_calls
      final data = (e as dynamic).response?.data;
      if (data is Map) {
        return (data['error'] ?? data['detail'] ?? 'Erreur inconnue').toString();
      }
    } catch (_) {}
    return 'Erreur réseau. Vérifiez votre connexion.';
  }
}
