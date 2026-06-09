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
  });

  factory TrajetModel.fromJson(Map<String, dynamic> json) {
    VehiculeModel? vehicule;
    if (json['vehicule'] is Map) {
      vehicule = VehiculeModel.fromJson(json['vehicule'] as Map<String, dynamic>);
    }

    return TrajetModel(
      id: json['id'] as int,
      conducteurId: json['conducteur_id']?.toString() ?? '',
      conducteurNom: json['conducteur_nom'] ?? json['conducteur']?['username'] ?? '',
      conducteurNote: (json['conducteur_note'] as num?)?.toDouble() ?? 0.0,
      conducteurPhoto: json['conducteur_photo'],
      vehicule: vehicule,
      depart: json['depart'] ?? '',
      destination: json['destination'] ?? '',
      departLat: (json['depart_lat'] as num?)?.toDouble(),
      departLng: (json['depart_lng'] as num?)?.toDouble(),
      destinationLat: (json['destination_lat'] as num?)?.toDouble(),
      destinationLng: (json['destination_lng'] as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      coutTotal: (json['cout_total'] as num?)?.toDouble() ?? 0.0,
      prixParPlace: (json['prix_par_place'] as num?)?.toDouble() ?? 0.0,
      dateHeureDepart: DateTime.parse(json['date_heure_depart'] as String),
      placesDisponibles: json['places_disponibles'] as int? ?? 0,
      placesRestantes: json['places_restantes'] as int? ?? 0,
      statut: json['statut'] ?? 'ouvert',
      estRegulier: json['est_regulier'] ?? false,
      joursSemaine: json['jours_semaine'] != null
          ? List<String>.from(json['jours_semaine'] as List)
          : null,
    );
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
    );
  }

  bool get isAvailable => statut == 'ouvert' && placesRestantes > 0;
}
