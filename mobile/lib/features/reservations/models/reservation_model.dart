import 'package:flutter/foundation.dart';
import '../../trajets/models/trajet_model.dart';
import 'paiement_model.dart';

class ReservationModel {
  final int id;
  final int trajetId;
  final TrajetModel? trajet;
  final String passagerId;
  final String passagerNom;
  final String? passagerPhoto;
  final String statut;
  final double prixParPlace;
  final int placesReservees;
  final DateTime dateReservation;
  final PaiementModel? paiement;

  const ReservationModel({
    required this.id,
    required this.trajetId,
    this.trajet,
    required this.passagerId,
    required this.passagerNom,
    this.passagerPhoto,
    required this.statut,
    required this.prixParPlace,
    this.placesReservees = 1,
    required this.dateReservation,
    this.paiement,
  });

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    debugPrint('[ReservationModel] fromJson id=${json['id']} statut=${json['statut']} depart=${json['depart']}');

    TrajetModel? trajet;

    if (json['trajet'] is Map) {
      // Objet trajet imbriqué (ancienne réponse)
      trajet = TrajetModel.fromJson(json['trajet'] as Map<String, dynamic>);
    } else if (json['depart'] != null || json['date_depart'] != null) {
      // L'API renvoie les champs trajet à plat (ReservationSerializer actuel)
      trajet = TrajetModel.fromJson({
        'id': json['trajet_id'] ?? 0,
        'depart': json['depart'] ?? '',
        'destination': json['destination'] ?? '',
        'date_heure_depart': json['date_depart'] ?? DateTime.now().toIso8601String(),
        'prix_par_place': json['prix_par_place'] ?? json['prix_passager'] ?? 0,
        'places_disponibles': 0,
        'places_restantes': 0,
        'distance_km': 0,
        'cout_total': 0,
        'statut': 'ouvert',
        'conducteur_id': '',
        'conducteur_nom': json['conducteur'] ?? '',
        'conducteur_note': json['conducteur_note'] ?? 0,
      });
    }

    PaiementModel? paiement;
    if (json['paiement'] is Map) {
      paiement = PaiementModel.fromJson(json['paiement'] as Map<String, dynamic>);
    }

    // Django retourne les Decimal en string — utiliser _toDouble() pour tout champ prix
    final prix = _toDouble(json['prix_passager'] ?? json['prix_par_place']);

    return ReservationModel(
      id: json['id'] as int,
      trajetId: json['trajet_id'] as int? ?? (trajet?.id ?? 0),
      trajet: trajet,
      passagerId: json['passager_id']?.toString() ?? '',
      passagerNom: json['passager_nom']?.toString() ?? json['passager']?['username']?.toString() ?? '',
      passagerPhoto: json['passager_photo'] as String?,
      statut: json['statut']?.toString() ?? 'en_attente',
      prixParPlace: prix,
      placesReservees: json['places_reservees'] as int? ?? 1,
      dateReservation: DateTime.tryParse(json['date_reservation']?.toString() ?? '')
          ?? DateTime.now(),
      paiement: paiement,
    );
  }

  ReservationModel copyWith({
    int? id,
    int? trajetId,
    TrajetModel? trajet,
    String? passagerId,
    String? passagerNom,
    String? passagerPhoto,
    String? statut,
    double? prixParPlace,
    int? placesReservees,
    DateTime? dateReservation,
    PaiementModel? paiement,
  }) {
    return ReservationModel(
      id: id ?? this.id,
      trajetId: trajetId ?? this.trajetId,
      trajet: trajet ?? this.trajet,
      passagerId: passagerId ?? this.passagerId,
      passagerNom: passagerNom ?? this.passagerNom,
      passagerPhoto: passagerPhoto ?? this.passagerPhoto,
      statut: statut ?? this.statut,
      prixParPlace: prixParPlace ?? this.prixParPlace,
      placesReservees: placesReservees ?? this.placesReservees,
      dateReservation: dateReservation ?? this.dateReservation,
      paiement: paiement ?? this.paiement,
    );
  }

  double get montantTotal => prixParPlace * placesReservees;
  bool get isConfirmee => statut == 'confirmee';
  bool get isEnAttente => statut == 'en_attente';
  bool get isTerminee => statut == 'terminee';
}
