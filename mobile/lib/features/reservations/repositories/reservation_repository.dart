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

  Future<PaiementModel> verifierPaiement(String identifier) async {
    try {
      final response = await DioClient.post(
        ApiConstants.verifierPaiement,
        data: {'identifier': identifier},
      );
      return PaiementModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

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

  Future<void> soumettreReference({
    required int reservationId,
    required String reference,
    required String network,
  }) async {
    try {
      await DioClient.post(
        ApiConstants.soumettreReference,
        data: {
          'reservation_id': reservationId,
          'reference_mobile': reference,
          'network': network,
        },
      );
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

  static const String _basePath = '/reservations/';
}
