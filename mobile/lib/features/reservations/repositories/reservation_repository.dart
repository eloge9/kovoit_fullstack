import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_interceptor.dart';
import '../../../core/network/dio_client.dart';
import '../models/reservation_model.dart';
import '../models/paiement_model.dart';

class ReservationRepository {
  Future<ReservationModel> reserver(int trajetId) async {
    try {
      final response = await DioClient.post(
        ApiConstants.reserver,
        data: {'trajet_id': trajetId},
      );
      return ReservationModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<ReservationModel>> mesReservations() async {
    try {
      final response = await DioClient.get(ApiConstants.mesReservations);
      final data = response.data;
      if (data is List) {
        return data
            .map((e) => ReservationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (data is Map && data['results'] is List) {
        return (data['results'] as List)
            .map((e) => ReservationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<ReservationModel>> reservationsRecues() async {
    try {
      final response = await DioClient.get(ApiConstants.reservationsRecues);
      final data = response.data;
      if (data is List) {
        return data
            .map((e) => ReservationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (data is Map && data['results'] is List) {
        return (data['results'] as List)
            .map((e) => ReservationModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
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

  static const String _basePath = '/reservations/';
}
