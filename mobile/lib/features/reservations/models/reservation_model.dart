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
  final String? codeEmbarquement;
  final String statutEmbarquement;
  final int? conversationId;
  final int? groupeConvId;

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
    this.codeEmbarquement,
    this.statutEmbarquement = 'non_embarque',
    this.conversationId,
    this.groupeConvId,
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
      final trajetStatut = json['trajet_statut']?.toString() ?? 'ouvert';
      final conducteurId = json['conducteur_id']?.toString() ?? '';
      debugPrint('[ReservationModel] trajetStatut=$trajetStatut conducteurId=$conducteurId '
          'departLat=${json['depart_lat']} destLat=${json['destination_lat']}');
      trajet = TrajetModel.fromJson({
        'id': json['trajet_id'] ?? 0,
        'depart': json['depart'] ?? '',
        'destination': json['destination'] ?? '',
        'date_heure_depart': json['date_depart'] ?? DateTime.now().toIso8601String(),
        'prix_par_place': json['prix_par_place'] ?? json['prix_passager'] ?? 0,
        'places_disponibles': 0,
        'places_restantes': 0,
        'distance_km': json['trajet_distance'] ?? 0,
        'cout_total': 0,
        'statut': trajetStatut,         // ← statut réel du trajet
        'conducteur_id': conducteurId,  // ← UUID du conducteur
        'conducteur_nom': json['conducteur'] ?? '',
        'conducteur_note': json['conducteur_note'] ?? 0,
        'depart_lat': json['depart_lat'],
        'depart_lng': json['depart_lng'],
        'destination_lat': json['destination_lat'],
        'destination_lng': json['destination_lng'],
      });
    }

    debugPrint('[ReservationModel] id=${json['id']} '
        'resa.statut=${json['statut']} '
        'trajet.statut=${trajet?.statut} '
        'afficherSuivi=${trajet?.statut == 'en_cours'}');

    PaiementModel? paiement;
    if (json['paiement'] is Map) {
      paiement = PaiementModel.fromJson(json['paiement'] as Map<String, dynamic>);
    } else if (json['paiement_statut'] != null) {
      // Le serializer Django renvoie le paiement en champs plats
      paiement = PaiementModel(
        id: 0,
        reservationId: json['id'] as int? ?? 0,
        montant: 0,
        moyenPaiement: json['paiement_moyen']?.toString() ?? 'ESPECE',
        statut: json['paiement_statut']?.toString() ?? 'EN_ATTENTE',
      );
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
      codeEmbarquement: json['code_embarquement']?.toString(),
      statutEmbarquement: json['statut_embarquement']?.toString() ?? 'non_embarque',
      conversationId: json['conversation_id'] as int?,
      groupeConvId: json['groupe_conv_id'] as int?,
    );
  }

  bool get isEmbarque => statutEmbarquement == 'embarque';

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
    String? codeEmbarquement,
    String? statutEmbarquement,
    int? conversationId,
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
      codeEmbarquement: codeEmbarquement ?? this.codeEmbarquement,
      statutEmbarquement: statutEmbarquement ?? this.statutEmbarquement,
      conversationId: conversationId ?? this.conversationId,
    );
  }

  double get montantTotal => prixParPlace * placesReservees;
  bool get isConfirmee  => statut == 'confirmee';
  bool get isEnAttente  => statut == 'en_attente';
  bool get isTerminee   => statut == 'terminee';
  bool get isDeclinee   => statut == 'declinee';
  bool get isAnnulee    => statut == 'annulee';
  bool get isActive     => statut == 'en_attente' || statut == 'confirmee';
  bool get isTerminal   => statut == 'terminee' || statut == 'declinee' || statut == 'annulee';
}
