import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_interceptor.dart';
import '../../../core/network/dio_client.dart';
import '../models/escale_model.dart';
import '../models/trajet_model.dart';
import '../models/vehicule_model.dart';

class TrajetRepository {
  // ── Trajets disponibles (passager) ──────────────────────────────────────────

  /// Retourne tous les trajets ouverts disponibles.
  /// Appelle /trajets/rechercher/ qui filtre par statut=ouvert.
  Future<List<TrajetModel>> getTrajets({
    String? depart,
    String? destination,
    String? date,
    int? places,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (depart != null && depart.isNotEmpty) params['depart'] = depart;
      if (destination != null && destination.isNotEmpty) params['destination'] = destination;
      if (date != null && date.isNotEmpty) params['date'] = date;
      if (places != null && places > 0) params['places'] = places;

      // Toujours utiliser /rechercher/ pour les passagers (retourne tous les trajets ouverts)
      final response = await DioClient.get(
        ApiConstants.rechercherTrajets,
        queryParams: params.isNotEmpty ? params : null,
        requireAuth: false,
      );
      final data = response.data;
      debugPrint('[TrajetRepo] getTrajets URL: ${ApiConstants.rechercherTrajets} params=$params');
      debugPrint('[TrajetRepo] getTrajets raw type: ${data.runtimeType}');

      if (data is List) {
        debugPrint('[TrajetRepo] getTrajets: ${data.length} trajets');
        return data
            .map((e) => TrajetModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (data is Map && data['results'] is List) {
        final list = data['results'] as List;
        debugPrint('[TrajetRepo] getTrajets (paginated): ${list.length} trajets');
        return list
            .map((e) => TrajetModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      debugPrint('[TrajetRepo] getTrajets: réponse inattendue: $data');
      return [];
    } on DioException catch (e) {
      debugPrint('[TrajetRepo] getTrajets error: $e');
      throw ApiException.fromDioException(e);
    }
  }

  // ── Mes trajets (conducteur) ─────────────────────────────────────────────────

  Future<List<TrajetModel>> mesTrajets() async {
    try {
      final response = await DioClient.get(ApiConstants.mesTrajets);
      final data = response.data;
      debugPrint('[TrajetRepo] mesTrajets raw type: ${data.runtimeType}');
      if (data is List) {
        debugPrint('[TrajetRepo] mesTrajets: ${data.length} trajets');
        if (data.isNotEmpty) {
          debugPrint('[TrajetRepo] premier trajet: ${data.first}');
        }
        return data
            .map((e) => TrajetModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (data is Map && data['results'] is List) {
        final list = data['results'] as List;
        debugPrint('[TrajetRepo] mesTrajets (paginated): ${list.length} trajets');
        return list
            .map((e) => TrajetModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      debugPrint('[TrajetRepo] mesTrajets: réponse inattendue: $data');
      return [];
    } on DioException catch (e) {
      debugPrint('[TrajetRepo] mesTrajets error: $e');
      throw ApiException.fromDioException(e);
    }
  }

  // ── Détail d'un trajet ───────────────────────────────────────────────────────

  Future<TrajetModel> getTrajet(int id) async {
    try {
      final response = await DioClient.get('${ApiConstants.trajets}$id/');
      debugPrint('[TrajetRepo] getTrajet($id) raw: ${response.data}');
      return TrajetModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint('[TrajetRepo] getTrajet error: $e');
      throw ApiException.fromDioException(e);
    }
  }

  // ── Recherche géospatiale par itinéraire ─────────────────────────────────────

  /// Recherche de trajets compatibles via polylines stockées (v2).
  /// Retourne les trajets avec champ `matching` contenant score, prix_passager, etc.
  Future<RechercheItineraireResult> rechercherParItineraire({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    String? date,
    int places = 1,
    double toleranceKm = 1.0,
    int scoreMinimum = 30,
  }) async {
    try {
      final body = <String, dynamic>{
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'dropoff_lat': dropoffLat,
        'dropoff_lng': dropoffLng,
        'tolerance_km': toleranceKm,
        'places': places,
        'score_minimum': scoreMinimum,
      };
      if (date != null && date.isNotEmpty) body['date'] = date;

      debugPrint('[TrajetRepo] rechercherItineraire body: $body');

      final response = await DioClient.post(
        ApiConstants.rechercherParItineraire,
        data: body,
        requireAuth: false,
      );
      final data = response.data;
      debugPrint('[TrajetRepo] rechercherItineraire raw type: ${data.runtimeType}');
      debugPrint('[TrajetRepo] rechercherItineraire raw: $data');

      if (data is Map) {
        final resultats = data['resultats'];
        final count = (data['count'] as num?)?.toInt() ?? 0;
        final algorithm = data['algorithm']?.toString() ?? '';
        final toleranceRetour = (data['tolerance_km'] as num?)?.toDouble() ?? toleranceKm;

        debugPrint('[TrajetRepo] rechercherItineraire: $count résultats, algo=$algorithm');

        final trajets = resultats is List
            ? resultats
                .map((e) => TrajetModel.fromJson(e as Map<String, dynamic>))
                .toList()
            : <TrajetModel>[];

        return RechercheItineraireResult(
          trajets: trajets,
          count: count,
          algorithm: algorithm,
          toleranceKm: toleranceRetour,
        );
      }

      return RechercheItineraireResult(trajets: [], count: 0);
    } on DioException catch (e) {
      debugPrint('[TrajetRepo] rechercherItineraire error: $e');
      throw ApiException.fromDioException(e);
    }
  }

  // ── Création et gestion de trajets ──────────────────────────────────────────

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
      // Backend peut retourner {message, trajet} ou juste le trajet
      if (response.data is Map && response.data['trajet'] is Map) {
        return TrajetModel.fromJson(
            response.data['trajet'] as Map<String, dynamic>);
      }
      return TrajetModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<TrajetModel> terminerTrajet(int id) async {
    try {
      final response = await DioClient.post('${ApiConstants.trajets}$id/terminer/');
      if (response.data is Map && response.data['trajet'] is Map) {
        return TrajetModel.fromJson(
            response.data['trajet'] as Map<String, dynamic>);
      }
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

  // ── Itinéraire OSRM ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getItineraire(int trajetId) async {
    try {
      final response = await DioClient.get(
        '${ApiConstants.trajets}$trajetId/itineraire/',
        requireAuth: false,
      );
      return response.data as Map<String, dynamic>?;
    } on DioException catch (e) {
      debugPrint('[TrajetRepo] getItineraire error: $e');
      throw ApiException.fromDioException(e);
    }
  }

  // ── GPS REST (fallback WebSocket) ────────────────────────────────────────────

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

  // ── Véhicules ────────────────────────────────────────────────────────────────

  Future<List<VehiculeModel>> mesVehicules() async {
    try {
      final response = await DioClient.get(ApiConstants.vehicules);
      final data = response.data;
      if (data is List) {
        return data
            .map((e) => VehiculeModel.fromJson(e as Map<String, dynamic>))
            .toList();
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

  // ── Escales ──────────────────────────────────────────────────────────────────

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
      await DioClient.delete(
          '${ApiConstants.trajets}$trajetId/escales/$escaleId/');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

// ── Résultat de recherche itinéraire ─────────────────────────────────────────

class RechercheItineraireResult {
  final List<TrajetModel> trajets;
  final int count;
  final String algorithm;
  final double toleranceKm;

  const RechercheItineraireResult({
    required this.trajets,
    required this.count,
    this.algorithm = '',
    this.toleranceKm = 1.0,
  });
}
