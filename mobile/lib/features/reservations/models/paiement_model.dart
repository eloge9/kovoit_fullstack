/// Opérateurs Mobile Money disponibles via PayPlus Africa
enum OperateurMobileMoney {
  flooz, // Moov Flooz (Moov Togo)
  yas,   // Mixx by Yas (Yas Togo)
}

extension OperateurMobileMoneyExt on OperateurMobileMoney {
  String get code => switch (this) {
    OperateurMobileMoney.flooz => 'FLOOZ',
    OperateurMobileMoney.yas   => 'YAS',
  };

  String get label => switch (this) {
    OperateurMobileMoney.flooz => 'Moov Flooz',
    OperateurMobileMoney.yas   => 'Mixx by Yas',
  };

  String get prefixes => switch (this) {
    OperateurMobileMoney.flooz => '90 / 91 / 92',
    OperateurMobileMoney.yas   => '70 / 71 / 72',
  };
}

class PaiementModel {
  final int id;
  final int reservationId;
  final double montant;
  final double commission;
  final double montantConducteur;
  final String moyenPaiement;
  final String statut;
  final String? referenceMobile;
  final String? token;       // token PayPlus Africa (remplace paygateTxRef)
  final String? transref;    // référence KOVOIT-{id}-{hash}
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
    this.token,
    this.transref,
    this.datePaiement,
  });

  factory PaiementModel.fromJson(Map<String, dynamic> json) {
    return PaiementModel(
      id: json['id'] as int? ?? 0,
      reservationId: json['reservation_id'] as int? ?? json['reservation'] as int? ?? 0,
      montant: (json['montant'] as num?)?.toDouble() ?? 0.0,
      commission: (json['commission'] as num?)?.toDouble() ?? 0.0,
      montantConducteur: (json['montant_conducteur'] as num?)?.toDouble() ?? 0.0,
      moyenPaiement: json['moyen_paiement'] as String? ?? 'ESPECE',
      statut: json['statut'] as String? ?? 'EN_ATTENTE_CONFIRMATION',
      referenceMobile: json['reference_mobile'] as String?,
      token: json['token'] as String?,
      transref: json['transref'] as String?,
      datePaiement: json['date_paiement'] != null
          ? DateTime.tryParse(json['date_paiement'] as String)
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
    String? token,
    String? transref,
    DateTime? datePaiement,
  }) =>
      PaiementModel(
        id: id ?? this.id,
        reservationId: reservationId ?? this.reservationId,
        montant: montant ?? this.montant,
        commission: commission ?? this.commission,
        montantConducteur: montantConducteur ?? this.montantConducteur,
        moyenPaiement: moyenPaiement ?? this.moyenPaiement,
        statut: statut ?? this.statut,
        referenceMobile: referenceMobile ?? this.referenceMobile,
        token: token ?? this.token,
        transref: transref ?? this.transref,
        datePaiement: datePaiement ?? this.datePaiement,
      );

  bool get isConfirme            => statut == 'CONFIRME';
  bool get isPayee               => statut == 'PAYEE';
  bool get isEnAttente           => statut == 'EN_ATTENTE';
  bool get isEnAttenteConfirm    => statut == 'EN_ATTENTE_CONFIRMATION';
  bool get isEspece              => moyenPaiement == 'ESPECE';
  bool get isMobileMoney         => moyenPaiement == 'FLOOZ' || moyenPaiement == 'YAS';
  bool get isTermine             => isConfirme || isPayee;

  String get moyenLabel => switch (moyenPaiement) {
    'FLOOZ'  => 'Moov Flooz',
    'YAS'    => 'Mixx by Yas',
    'ESPECE' => 'Espèces',
    _        => moyenPaiement,
  };
}
