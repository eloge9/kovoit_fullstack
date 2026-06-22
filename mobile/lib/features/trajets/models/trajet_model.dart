import 'package:flutter/foundation.dart';
import 'vehicule_model.dart';

class TrajetModel {
  final int id;
  final String conducteurId;
  final String conducteurNom;
  final double conducteurNote;
  final String? conducteurPhoto;
  final VehiculeModel? vehicule;
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

  const TrajetModel({
    required this.id,
    required this.conducteurId,
    required this.conducteurNom,
    required this.conducteurNote,
    this.conducteurPhoto,
    this.vehicule,
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
  });

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  factory TrajetModel.fromJson(Map<String, dynamic> json) {
    VehiculeModel? vehicule;
    if (json['vehicule'] is Map) {
      vehicule = VehiculeModel.fromJson(json['vehicule'] as Map<String, dynamic>);
    }

    // Backend retourne 'conducteur' (UUID) et non 'conducteur_id'
    // Support des deux formes
    final conducteurId = json['conducteur_id']?.toString()
        ?? json['conducteur']?.toString()
        ?? '';

    // conducteur_nom peut être un objet (ancien) ou une string (nouveau serializer)
    String conducteurNom = '';
    if (json['conducteur_nom'] is String) {
      conducteurNom = json['conducteur_nom'] as String;
    } else if (json['conducteur'] is Map) {
      conducteurNom = (json['conducteur'] as Map)['username']?.toString() ?? '';
    }

    // Backend retourne 'polyline_stored' ou 'polyline', pas 'polyline_osrm'
    final polyline = json['polyline_osrm']?.toString()
        ?? json['polyline_stored']?.toString()
        ?? json['polyline']?.toString();

    final trajet = TrajetModel(
      id: json['id'] as int,
      conducteurId: conducteurId,
      conducteurNom: conducteurNom,
      conducteurNote: _toDouble(json['conducteur_note']),
      conducteurPhoto: json['conducteur_photo']?.toString(),
      vehicule: vehicule,
      depart: json['depart']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      departLat: json['depart_lat'] != null ? _toDouble(json['depart_lat']) : null,
      departLng: json['depart_lng'] != null ? _toDouble(json['depart_lng']) : null,
      destinationLat: json['destination_lat'] != null ? _toDouble(json['destination_lat']) : null,
      destinationLng: json['destination_lng'] != null ? _toDouble(json['destination_lng']) : null,
      distanceKm: _toDouble(json['distance_km']),
      coutTotal: _toDouble(json['cout_total']),
      prixParPlace: _toDouble(json['prix_par_place']),
      dateHeureDepart: DateTime.tryParse(json['date_heure_depart']?.toString() ?? '') ?? DateTime.now(),
      placesDisponibles: json['places_disponibles'] as int? ?? 0,
      placesRestantes: json['places_restantes'] as int? ?? 0,
      statut: json['statut']?.toString() ?? 'ouvert',
      estRegulier: json['est_regulier'] as bool? ?? false,
      joursSemaine: json['jours_semaine'] != null
          ? List<String>.from(json['jours_semaine'] as List)
          : null,
      polylineOsrm: polyline,
    );
    debugPrint('[TrajetModel] parsed id=${trajet.id} conducteurId=$conducteurId ${trajet.depart}→${trajet.destination} prix=${trajet.prixParPlace} statut=${trajet.statut}');
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
      };

  TrajetModel copyWith({
    int? id,
    String? conducteurId,
    String? conducteurNom,
    double? conducteurNote,
    String? conducteurPhoto,
    VehiculeModel? vehicule,
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
  }) {
    return TrajetModel(
      id: id ?? this.id,
      conducteurId: conducteurId ?? this.conducteurId,
      conducteurNom: conducteurNom ?? this.conducteurNom,
      conducteurNote: conducteurNote ?? this.conducteurNote,
      conducteurPhoto: conducteurPhoto ?? this.conducteurPhoto,
      vehicule: vehicule ?? this.vehicule,
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
    );
  }

  bool get isAvailable => statut == 'ouvert' && placesRestantes > 0;
}
