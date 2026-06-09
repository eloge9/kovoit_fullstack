class PaiementModel {
  final int id;
  final int reservationId;
  final double montant;
  final double commission;
  final double montantConducteur;
  final String moyenPaiement;
  final String statut;
  final String? referenceMobile;
  final String? paygateTxRef;
  final DateTime? datePaiement;

  const PaiementModel({
    required this.id,
    required this.reservationId,
    required this.montant,
    this.commission = 0.0,
    this.montantConducteur = 0.0,
    required this.moyenPaiement,
    required this.statut,
    this.referenceMobile,
    this.paygateTxRef,
    this.datePaiement,
  });

  factory PaiementModel.fromJson(Map<String, dynamic> json) {
    return PaiementModel(
      id: json['id'] as int,
      reservationId: json['reservation_id'] as int? ?? json['reservation'] as int? ?? 0,
      montant: (json['montant'] as num?)?.toDouble() ?? 0.0,
      commission: (json['commission'] as num?)?.toDouble() ?? 0.0,
      montantConducteur: (json['montant_conducteur'] as num?)?.toDouble() ?? 0.0,
      moyenPaiement: json['moyen_paiement'] ?? 'ESPECE',
      statut: json['statut'] ?? 'EN_ATTENTE_CONFIRMATION',
      referenceMobile: json['reference_mobile'],
      paygateTxRef: json['paygate_tx_ref'],
      datePaiement: json['date_paiement'] != null
          ? DateTime.parse(json['date_paiement'] as String)
          : null,
    );
  }

  PaiementModel copyWith({
    int? id,
    int? reservationId,
    double? montant,
    double? commission,
    double? montantConducteur,
    String? moyenPaiement,
    String? statut,
    String? referenceMobile,
    String? paygateTxRef,
    DateTime? datePaiement,
  }) {
    return PaiementModel(
      id: id ?? this.id,
      reservationId: reservationId ?? this.reservationId,
      montant: montant ?? this.montant,
      commission: commission ?? this.commission,
      montantConducteur: montantConducteur ?? this.montantConducteur,
      moyenPaiement: moyenPaiement ?? this.moyenPaiement,
      statut: statut ?? this.statut,
      referenceMobile: referenceMobile ?? this.referenceMobile,
      paygateTxRef: paygateTxRef ?? this.paygateTxRef,
      datePaiement: datePaiement ?? this.datePaiement,
    );
  }

  bool get isConfirme => statut == 'CONFIRME';
  bool get isEnAttente => statut == 'EN_ATTENTE_CONFIRMATION';
}
