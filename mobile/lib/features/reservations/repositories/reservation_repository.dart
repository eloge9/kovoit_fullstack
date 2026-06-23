import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_interceptor.dart';
import '../../../core/network/dio_client.dart';
import '../models/reservation_model.dart';
import '../models/paiement_model.dart';

class ReservationRepository {
  Future<ReservationModel> reserver(
    int trajetId, {
    int placesReservees = 1,
    String? priseEnCharge,
    double? priseEnChargeLat,
    double? priseEnChargeLng,
  }) async {
    try {
      final body = <String, dynamic>{
        'trajet_id': trajetId,
        'places_reservees': placesReservees,
      };
      if (priseEnCharge != null) body['prise_en_charge'] = priseEnCharge;
      if (priseEnChargeLat != null) body['prise_en_charge_lat'] = priseEnChargeLat;
      if (priseEnChargeLng != null) body['prise_en_charge_lng'] = priseEnChargeLng;
      final response = await DioClient.post(ApiConstants.reserver, data: body);
      return ReservationModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<ReservationModel>> mesReservations() async {
    try {
      final response = await DioClient.get(ApiConstants.mesReservations);
      final data = response.data;
      debugPrint('[ReservationRepo] mesReservations raw type: ${data.runtimeType}');
      if (data is List) {
        debugPrint('[ReservationRepo] mesReservations: ${data.length} éléments');
        if (data.isNotEmpty) debugPrint('[ReservationRepo] premier élément: ${data.first}');
        return data
            .map((e) => ReservationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (data is Map && data['results'] is List) {
        final list = data['results'] as List;
        debugPrint('[ReservationRepo] mesReservations (paginated): ${list.length} éléments');
        return list
            .map((e) => ReservationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      debugPrint('[ReservationRepo] mesReservations: réponse inattendue: $data');
      return [];
    } on DioException catch (e) {
      debugPrint('[ReservationRepo] mesReservations error: $e');
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<ReservationModel>> reservationsRecues() async {
    try {
      final response = await DioClient.get(ApiConstants.reservationsRecues);
      final data = response.data;
      debugPrint('[ReservationRepo] reservationsRecues raw type: ${data.runtimeType}');
      if (data is List) {
        debugPrint('[ReservationRepo] reservationsRecues: ${data.length} éléments');
        return data
            .map((e) => ReservationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (data is Map && data['results'] is List) {
        final list = data['results'] as List;
        debugPrint('[ReservationRepo] reservationsRecues (paginated): ${list.length} éléments');
        return list
            .map((e) => ReservationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      debugPrint('[ReservationRepo] reservationsRecues: réponse inattendue: $data');
      return [];
    } on DioException catch (e) {
      debugPrint('[ReservationRepo] reservationsRecues error: $e');
      throw ApiException.fromDioException(e);
    }
  }

  Future<ReservationModel> confirmerReservation(int id) async {
    try {
      final response = await DioClient.post('$_basePath$id/confirmer/');
      return ReservationModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<ReservationModel> declinerReservation(int id) async {
    try {
      final response = await DioClient.post('$_basePath$id/decliner/');
      return ReservationModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> annulerReservation(int id) async {
    try {
      await DioClient.post('$_basePath$id/annuler/');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // Paiements
  /// Initie un paiement Mobile Money (FLOOZ = Moov Flooz, YAS = Mixx by Yas)
  Future<PaiementModel> initierPaiement({
    required int reservationId,
    required String phoneNumber,
    required String network,
  }) async {
    try {
      final response = await DioClient.post(
        ApiConstants.initierPaiement,
        data: {
          'reservation_id': reservationId,
          'phone_number': phoneNumber,
          'network': network,
        },
      );
      return PaiementModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Vérifie le statut d'un paiement PayPlus Africa via son token.
  Future<PaiementModel> verifierPaiement(String token) async {
    try {
      final response = await DioClient.post(
        ApiConstants.verifierPaiement,
        data: {'token': token},
      );
      return PaiementModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Initie un paiement en espèces (pas de paiement immédiat).
  Future<PaiementModel> initierPaiementEspeces(int reservationId) async {
    try {
      final response = await DioClient.post(
        ApiConstants.initierEspeces,
        data: {'reservation_id': reservationId},
      );
      return PaiementModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Map<String, dynamic>> getCodeEmbarquement(int reservationId) async {
    try {
      final response = await DioClient.get('/reservations/$reservationId/code-embarquement/');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Map<String, dynamic>> embarquer(String codeEmbarquement) async {
    try {
      final response = await DioClient.post(
        '/reservations/embarquer/',
        data: {'code_embarquement': codeEmbarquement},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> debarquer(int reservationId) async {
    try {
      await DioClient.post('/reservations/$reservationId/debarquer/');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<ReservationModel>> historique({
    String? statut,
    DateTime? dateDebut,
    DateTime? dateFin,
    String? search,
  }) async {
    try {
      final params = <String, String>{};
      if (statut != null && statut != 'tous') params['statut'] = statut;
      if (dateDebut != null) params['date_debut'] = _fmt(dateDebut);
      if (dateFin != null) params['date_fin'] = _fmt(dateFin);
      if (search != null && search.trim().isNotEmpty) params['q'] = search.trim();

      final response = await DioClient.get(
        ApiConstants.historiqueReservations,
        queryParams: params.isEmpty ? null : params,
      );
      final data = response.data;
      if (data is List) {
        return data.map((e) => ReservationModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      if (data is Map && data['results'] is List) {
        return (data['results'] as List)
            .map((e) => ReservationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('[ReservationRepo] historique error: $e');
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<ReservationModel>> conducteurHistorique({
    String? statut,
    DateTime? dateDebut,
    DateTime? dateFin,
    String? search,
  }) async {
    try {
      final params = <String, String>{};
      if (statut != null && statut != 'tous') params['statut'] = statut;
      if (dateDebut != null) params['date_debut'] = _fmt(dateDebut);
      if (dateFin != null) params['date_fin'] = _fmt(dateFin);
      if (search != null && search.trim().isNotEmpty) params['q'] = search.trim();

      final response = await DioClient.get(
        ApiConstants.conducteurHistorique,
        queryParams: params.isEmpty ? null : params,
      );
      final data = response.data;
      if (data is List) {
        return data.map((e) => ReservationModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      if (data is Map && data['results'] is List) {
        return (data['results'] as List)
            .map((e) => ReservationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('[ReservationRepo] conducteurHistorique error: $e');
      throw ApiException.fromDioException(e);
    }
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static const String _basePath = '/reservations/';
}
