import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_interceptor.dart';
import '../../../core/network/dio_client.dart';
import '../models/escale_model.dart';
import '../models/trajet_model.dart';
import '../models/vehicule_model.dart';

class TrajetRepository {
  Future<List<TrajetModel>> getTrajets({
    String? depart,
    String? destination,
    String? date,
    int? places,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (depart != null) params['depart'] = depart;
      if (destination != null) params['destination'] = destination;
      if (date != null) params['date'] = date;
      if (places != null) params['places'] = places;

      final path = params.isEmpty ? ApiConstants.trajets : ApiConstants.rechercherTrajets;
      final response = await DioClient.get(path, queryParams: params.isEmpty ? null : params);
      final data = response.data;
      debugPrint('[TrajetRepo] getTrajets raw type: ${data.runtimeType}');

      if (data is List) {
        debugPrint('[TrajetRepo] getTrajets: ${data.length} trajets');
        return data.map((e) => TrajetModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      if (data is Map && data['results'] is List) {
        final list = data['results'] as List;
        debugPrint('[TrajetRepo] getTrajets (paginated): ${list.length} trajets');
        return list.map((e) => TrajetModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      debugPrint('[TrajetRepo] getTrajets: réponse inattendue: $data');
      return [];
    } on DioException catch (e) {
      debugPrint('[TrajetRepo] getTrajets error: $e');
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<TrajetModel>> mesTrajets() async {
    try {
      final response = await DioClient.get(ApiConstants.mesTrajets);
      final data = response.data;
      debugPrint('[TrajetRepo] mesTrajets raw type: ${data.runtimeType}');
      if (data is List) {
        debugPrint('[TrajetRepo] mesTrajets: ${data.length} trajets');
        if (data.isNotEmpty) debugPrint('[TrajetRepo] premier trajet: ${data.first}');
        return data.map((e) => TrajetModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      if (data is Map && data['results'] is List) {
        final list = data['results'] as List;
        debugPrint('[TrajetRepo] mesTrajets (paginated): ${list.length} trajets');
        return list.map((e) => TrajetModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      debugPrint('[TrajetRepo] mesTrajets: réponse inattendue: $data');
      return [];
    } on DioException catch (e) {
      debugPrint('[TrajetRepo] mesTrajets error: $e');
      throw ApiException.fromDioException(e);
    }
  }

  Future<TrajetModel> getTrajet(int id) async {
    try {
      final response = await DioClient.get('${ApiConstants.trajets}$id/');
      return TrajetModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<TrajetModel> creerTrajet(Map<String, dynamic> data) async {
    try {
      final response = await DioClient.post(ApiConstants.trajets, data: data);
      return TrajetModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<TrajetModel> commencerTrajet(int id) async {
    try {
      final response = await DioClient.post('${ApiConstants.trajets}$id/commencer/');
      return TrajetModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<TrajetModel> terminerTrajet(int id) async {
    try {
      final response = await DioClient.post('${ApiConstants.trajets}$id/terminer/');
      return TrajetModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> annulerTrajet(int id) async {
    try {
      await DioClient.post('${ApiConstants.trajets}$id/annuler/');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // Véhicules
  Future<List<VehiculeModel>> mesVehicules() async {
    try {
      final response = await DioClient.get(ApiConstants.vehicules);
      final data = response.data;
      if (data is List) {
        return data.map((e) => VehiculeModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<VehiculeModel> ajouterVehicule(Map<String, dynamic> data) async {
    try {
      final response = await DioClient.post(ApiConstants.ajouterVehicule, data: data);
      return VehiculeModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> desactiverVehicule(int id) async {
    try {
      await DioClient.post('${ApiConstants.vehicules}$id/desactiver/');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<TrajetModel>> rechercherParItineraire({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    String? date,
    int? places,
    double toleranceKm = 2.0,
  }) async {
    try {
      final body = <String, dynamic>{
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
        'tolerance_km': toleranceKm,
        'score_minimum': 0.3,
      };
      if (date != null) body['date'] = date;
      if (places != null) body['places'] = places;
      final response = await DioClient.post(
        ApiConstants.rechercherParItineraire,
        data: body,
        requireAuth: false,
      );
      final data = response.data;
      final resultats = (data is Map ? data['resultats'] : data) as List?;
      return (resultats ?? [])
          .map((e) => TrajetModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Map<String, dynamic>?> getItineraire(int trajetId) async {
    try {
      final response = await DioClient.get(
        '${ApiConstants.trajets}$trajetId/itineraire/',
        requireAuth: false,
      );
      return response.data as Map<String, dynamic>?;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Map<String, dynamic>?> getPositionActuelle(int trajetId) async {
    try {
      final response = await DioClient.get(
        '${ApiConstants.trajets}$trajetId/position_actuelle/',
      );
      return response.data as Map<String, dynamic>?;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> mettreAJourPosition(
    int trajetId, {
    required double latitude,
    required double longitude,
    double? vitesseKmh,
  }) async {
    try {
      final body = <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
      };
      if (vitesseKmh != null) body['vitesse_kmh'] = vitesseKmh;
      await DioClient.post(
        '${ApiConstants.trajets}$trajetId/mettre_a_jour_position/',
        data: body,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  // ── Escales ────────────────────────────────────────────────────────────────

  Future<List<EscaleModel>> getEscales(int trajetId) async {
    try {
      final response = await DioClient.get(
        '${ApiConstants.trajets}$trajetId/escales/',
        requireAuth: false,
      );
      final data = response.data;
      if (data is List) {
        return data
            .map((e) => EscaleModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<EscaleModel> ajouterEscale(
      int trajetId, Map<String, dynamic> data) async {
    try {
      final response = await DioClient.post(
        '${ApiConstants.trajets}$trajetId/escales/',
        data: data,
      );
      return EscaleModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> mettreAJourEscale(
      int trajetId, int escaleId, Map<String, dynamic> data) async {
    try {
      await DioClient.patch(
        '${ApiConstants.trajets}$trajetId/escales/$escaleId/',
        data: data,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> supprimerEscale(int trajetId, int escaleId) async {
    try {
      await DioClient.delete('${ApiConstants.trajets}$trajetId/escales/$escaleId/');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
