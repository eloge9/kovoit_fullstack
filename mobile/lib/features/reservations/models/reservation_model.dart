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

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    TrajetModel? trajet;
    if (json['trajet'] is Map) {
      trajet = TrajetModel.fromJson(json['trajet'] as Map<String, dynamic>);
    }

    PaiementModel? paiement;
    if (json['paiement'] is Map) {
      paiement = PaiementModel.fromJson(json['paiement'] as Map<String, dynamic>);
    }

    return ReservationModel(
      id: json['id'] as int,
      trajetId: json['trajet_id'] as int? ?? (trajet?.id ?? 0),
      trajet: trajet,
      passagerId: json['passager_id']?.toString() ?? '',
      passagerNom: json['passager_nom'] ?? json['passager']?['username'] ?? '',
      passagerPhoto: json['passager_photo'],
      statut: json['statut'] ?? 'en_attente',
      prixParPlace: (json['prix_par_place'] as num?)?.toDouble() ?? 0.0,
      placesReservees: json['places_reservees'] as int? ?? 1,
      dateReservation: DateTime.parse(json['date_reservation'] as String),
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
