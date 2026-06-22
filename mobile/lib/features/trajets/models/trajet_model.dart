import 'package:flutter/foundation.dart';
import 'vehicule_model.dart';

// ── Matching info (retourné par /trajets/rechercher-itineraire/) ──────────────

class MatchingInfo {
  final int score;
  final double distancePassagerKm;
  final double? distancePickupKm;
  final double? distanceDropoffKm;
  final double detourKm;
  final bool directionOk;
  final int prixPassager;
  final String raison;

  const MatchingInfo({
    required this.score,
    required this.distancePassagerKm,
    this.distancePickupKm,
    this.distanceDropoffKm,
    required this.detourKm,
    required this.directionOk,
    required this.prixPassager,
    required this.raison,
  });

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  factory MatchingInfo.fromJson(Map<String, dynamic> json) {
    return MatchingInfo(
      score: (json['score'] as num?)?.toInt() ?? 0,
      distancePassagerKm: _toDouble(json['distance_passager_km']),
      distancePickupKm: json['distance_pickup_km'] != null
          ? _toDouble(json['distance_pickup_km'])
          : null,
      distanceDropoffKm: json['distance_dropoff_km'] != null
          ? _toDouble(json['distance_dropoff_km'])
          : null,
      detourKm: _toDouble(json['detour_km']),
      directionOk: json['direction_ok'] as bool? ?? true,
      prixPassager: (json['prix_passager'] as num?)?.toInt() ?? 0,
      raison: json['raison']?.toString() ?? '',
    );
  }
}

// ── Modèle principal ──────────────────────────────────────────────────────────

class TrajetModel {
  final int id;
  final String conducteurId;
  final String conducteurNom;
  final double conducteurNote;
  final String? conducteurPhoto;
  final VehiculeModel? vehicule;
  final String? typeVehicule;
  final String depart;
  final String destination;
  final double? departLat;
  final double? departLng;
  final double? destinationLat;
  final double? destinationLng;
  final double distanceKm;
  final double coutTotal;
  final double prixParPlace;
  final DateTime dateHeureDepart;
  final int placesDisponibles;
  final int placesRestantes;
  final String statut;
  final bool estRegulier;
  final List<String>? joursSemaine;
  final String? polylineOsrm;
  final bool polylineStored;
  final String? description;
  final double? toleranceDetourKm;

  // Données matching géo (présentes uniquement après recherche itinéraire)
  final MatchingInfo? matching;

  const TrajetModel({
    required this.id,
    required this.conducteurId,
    required this.conducteurNom,
    required this.conducteurNote,
    this.conducteurPhoto,
    this.vehicule,
    this.typeVehicule,
    required this.depart,
    required this.destination,
    this.departLat,
    this.departLng,
    this.destinationLat,
    this.destinationLng,
    required this.distanceKm,
    required this.coutTotal,
    required this.prixParPlace,
    required this.dateHeureDepart,
    required this.placesDisponibles,
    required this.placesRestantes,
    required this.statut,
    this.estRegulier = false,
    this.joursSemaine,
    this.polylineOsrm,
    this.polylineStored = false,
    this.description,
    this.toleranceDetourKm,
    this.matching,
  });

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  factory TrajetModel.fromJson(Map<String, dynamic> json) {
    // Véhicule : backend peut retourner 'vehicule_info' (objet complet) ou 'vehicule' (int)
    VehiculeModel? vehicule;
    final vehiculeInfo = json['vehicule_info'];
    if (vehiculeInfo is Map) {
      vehicule = VehiculeModel.fromJson(vehiculeInfo as Map<String, dynamic>);
    } else if (json['vehicule'] is Map) {
      vehicule = VehiculeModel.fromJson(json['vehicule'] as Map<String, dynamic>);
    }

    // Conducteur : backend retourne UUID dans 'conducteur', pas 'conducteur_id'
    final conducteurId = json['conducteur_id']?.toString()
        ?? json['conducteur']?.toString()
        ?? '';

    // conducteur_nom : string ou objet selon le serializer
    String conducteurNom = '';
    if (json['conducteur_nom'] is String) {
      conducteurNom = json['conducteur_nom'] as String;
    } else if (json['conducteur'] is Map) {
      final c = json['conducteur'] as Map;
      final first = c['first_name']?.toString() ?? '';
      final last = c['last_name']?.toString() ?? '';
      conducteurNom = '$first $last'.trim().isNotEmpty
          ? '$first $last'.trim()
          : c['username']?.toString() ?? '';
    }

    // Photo conducteur : backend ne l'inclut pas toujours dans TrajetSerializer
    final conducteurPhoto = json['conducteur_photo']?.toString()
        ?? (json['conducteur'] is Map
            ? (json['conducteur'] as Map)['photo_profile']?.toString()
            : null);

    // Polyline : backend stocke dans 'polyline', flag 'polyline_stored'
    final polyline = json['polyline_osrm']?.toString()
        ?? json['polyline']?.toString();

    // Matching info (présent seulement en résultat de recherche itinéraire)
    MatchingInfo? matching;
    if (json['matching'] is Map) {
      try {
        matching = MatchingInfo.fromJson(
            Map<String, dynamic>.from(json['matching'] as Map));
      } catch (e) {
        debugPrint('[TrajetModel] matching parse error: $e');
      }
    }

    final trajet = TrajetModel(
      id: json['id'] as int,
      conducteurId: conducteurId,
      conducteurNom: conducteurNom,
      conducteurNote: _toDouble(json['conducteur_note']),
      conducteurPhoto: conducteurPhoto,
      vehicule: vehicule,
      typeVehicule: json['type_vehicule']?.toString(),
      depart: json['depart']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      departLat: json['depart_lat'] != null ? _toDouble(json['depart_lat']) : null,
      departLng: json['depart_lng'] != null ? _toDouble(json['depart_lng']) : null,
      destinationLat: json['destination_lat'] != null
          ? _toDouble(json['destination_lat'])
          : null,
      destinationLng: json['destination_lng'] != null
          ? _toDouble(json['destination_lng'])
          : null,
      distanceKm: _toDouble(json['distance_km']),
      coutTotal: _toDouble(json['cout_total']),
      prixParPlace: _toDouble(json['prix_par_place']),
      dateHeureDepart: DateTime.tryParse(
              json['date_heure_depart']?.toString() ?? '') ??
          DateTime.now(),
      placesDisponibles: (json['places_disponibles'] as num?)?.toInt() ?? 0,
      placesRestantes: (json['places_restantes'] as num?)?.toInt() ?? 0,
      statut: json['statut']?.toString() ?? 'ouvert',
      estRegulier: json['est_regulier'] as bool? ?? false,
      joursSemaine: json['jours_semaine'] != null
          ? List<String>.from(json['jours_semaine'] as List)
          : null,
      polylineOsrm: polyline,
      polylineStored: json['polyline_stored'] as bool? ?? false,
      description: json['description']?.toString(),
      toleranceDetourKm: json['tolerance_detour_km'] != null
          ? _toDouble(json['tolerance_detour_km'])
          : null,
      matching: matching,
    );

    debugPrint(
      '[TrajetModel] parsed id=${trajet.id} '
      '${trajet.depart}→${trajet.destination} '
      'prix=${trajet.prixParPlace} '
      'statut=${trajet.statut}'
      '${matching != null ? " score=${matching.score}" : ""}',
    );
    return trajet;
  }

  Map<String, dynamic> toJson() => {
        'vehicule': vehicule?.id,
        'depart': depart,
        'destination': destination,
        'depart_lat': departLat,
        'depart_lng': departLng,
        'destination_lat': destinationLat,
        'destination_lng': destinationLng,
        'distance_km': distanceKm,
        'cout_total': coutTotal,
        'prix_par_place': prixParPlace,
        'date_heure_depart': dateHeureDepart.toIso8601String(),
        'places_disponibles': placesDisponibles,
        'est_regulier': estRegulier,
        'jours_semaine': joursSemaine,
        'description': description,
      };

  TrajetModel copyWith({
    int? id,
    String? conducteurId,
    String? conducteurNom,
    double? conducteurNote,
    String? conducteurPhoto,
    VehiculeModel? vehicule,
    String? typeVehicule,
    String? depart,
    String? destination,
    double? departLat,
    double? departLng,
    double? destinationLat,
    double? destinationLng,
    double? distanceKm,
    double? coutTotal,
    double? prixParPlace,
    DateTime? dateHeureDepart,
    int? placesDisponibles,
    int? placesRestantes,
    String? statut,
    bool? estRegulier,
    List<String>? joursSemaine,
    String? polylineOsrm,
    bool? polylineStored,
    String? description,
    double? toleranceDetourKm,
    MatchingInfo? matching,
  }) {
    return TrajetModel(
      id: id ?? this.id,
      conducteurId: conducteurId ?? this.conducteurId,
      conducteurNom: conducteurNom ?? this.conducteurNom,
      conducteurNote: conducteurNote ?? this.conducteurNote,
      conducteurPhoto: conducteurPhoto ?? this.conducteurPhoto,
      vehicule: vehicule ?? this.vehicule,
      typeVehicule: typeVehicule ?? this.typeVehicule,
      depart: depart ?? this.depart,
      destination: destination ?? this.destination,
      departLat: departLat ?? this.departLat,
      departLng: departLng ?? this.departLng,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      distanceKm: distanceKm ?? this.distanceKm,
      coutTotal: coutTotal ?? this.coutTotal,
      prixParPlace: prixParPlace ?? this.prixParPlace,
      dateHeureDepart: dateHeureDepart ?? this.dateHeureDepart,
      placesDisponibles: placesDisponibles ?? this.placesDisponibles,
      placesRestantes: placesRestantes ?? this.placesRestantes,
      statut: statut ?? this.statut,
      estRegulier: estRegulier ?? this.estRegulier,
      joursSemaine: joursSemaine ?? this.joursSemaine,
      polylineOsrm: polylineOsrm ?? this.polylineOsrm,
      polylineStored: polylineStored ?? this.polylineStored,
      description: description ?? this.description,
      toleranceDetourKm: toleranceDetourKm ?? this.toleranceDetourKm,
      matching: matching ?? this.matching,
    );
  }

  bool get isAvailable => statut == 'ouvert' && placesRestantes > 0;

  // Prix à afficher : prix_passager du matching si disponible, sinon prix_par_place
  double get prixAffiche =>
      matching != null ? matching!.prixPassager.toDouble() : prixParPlace;
}
