import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_interceptor.dart';
import '../../../core/network/dio_client.dart';
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

      if (data is List) {
        return data.map((e) => TrajetModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      if (data is Map && data['results'] is List) {
        return (data['results'] as List)
            .map((e) => TrajetModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<TrajetModel>> mesTrajets() async {
    try {
      final response = await DioClient.get(ApiConstants.mesTrajets);
      final data = response.data;
      if (data is List) {
        return data.map((e) => TrajetModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      if (data is Map && data['results'] is List) {
        return (data['results'] as List)
            .map((e) => TrajetModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
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
}
