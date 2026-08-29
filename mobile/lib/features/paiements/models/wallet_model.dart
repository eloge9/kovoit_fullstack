class MonWalletModel {
  final double soldeDisponible;
  final double soldeDu;
  final bool peutRetirer;

  const MonWalletModel({
    required this.soldeDisponible,
    required this.soldeDu,
    required this.peutRetirer,
  });

  factory MonWalletModel.fromJson(Map<String, dynamic> json) {
    return MonWalletModel(
      soldeDisponible: (json['solde_disponible'] as num?)?.toDouble() ?? 0.0,
      soldeDu: (json['solde_du'] as num?)?.toDouble() ?? 0.0,
      peutRetirer: json['peut_retirer'] as bool? ?? false,
    );
  }
}

class WalletTransactionModel {
  final int id;
  final String type;
  final String sens; // 'CREDIT' | 'DEBIT'
  final double montant;
  final String statut;
  final String description;
  final DateTime? createdAt;

  const WalletTransactionModel({
    required this.id,
    required this.type,
    required this.sens,
    required this.montant,
    required this.statut,
    required this.description,
    this.createdAt,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'] as int? ?? 0,
      type: json['type'] as String? ?? '',
      sens: json['sens'] as String? ?? 'CREDIT',
      montant: (json['montant'] as num?)?.toDouble() ?? 0.0,
      statut: json['statut'] as String? ?? '',
      description: json['description'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  bool get isCredit => sens == 'CREDIT';

  static const Map<String, String> typeLabels = {
    'DEPOSIT':                 'Dépôt',
    'WITHDRAWAL_REQUEST':      'Demande de retrait',
    'WITHDRAWAL_COMPLETED':    'Retrait effectué',
    'WITHDRAWAL_FAILED':       "Retrait échoué (remboursé)",
    'RIDE_PAYMENT_CREDIT':     'Paiement de trajet',
    'COMMISSION_ELECTRONIC':  'Commission KoVoit',
    'COMMISSION_CASH_DUE':     'Commission due (espèces)',
    'COMMISSION_CASH_SETTLED': 'Commission réglée',
    'REFUND':                  'Annulation — reprise',
    'CANCELLATION_PENALTY':    "Pénalité d'annulation",
    'ADJUSTMENT':              'Ajustement (admin)',
  };

  String get typeLabel => typeLabels[type] ?? type;
}

class RetraitModel {
  final int id;
  final double montant;
  final String moyen; // 'FLOOZ' | 'YAS'
  final String numeroDestination;
  final String statut; // EN_ATTENTE, EN_COURS, REUSSI, ECHOUE, ANNULE
  final String motifEchec;
  final DateTime? dateDemande;
  final DateTime? dateTraitement;

  const RetraitModel({
    required this.id,
    required this.montant,
    required this.moyen,
    required this.numeroDestination,
    required this.statut,
    this.motifEchec = '',
    this.dateDemande,
    this.dateTraitement,
  });

  factory RetraitModel.fromJson(Map<String, dynamic> json) {
    return RetraitModel(
      id: json['id'] as int? ?? 0,
      montant: (json['montant'] as num?)?.toDouble() ?? 0.0,
      moyen: json['moyen'] as String? ?? 'FLOOZ',
      numeroDestination: json['numero_destination'] as String? ?? '',
      statut: json['statut'] as String? ?? 'EN_ATTENTE',
      motifEchec: json['motif_echec'] as String? ?? '',
      dateDemande: json['date_demande'] != null
          ? DateTime.tryParse(json['date_demande'] as String)
          : null,
      dateTraitement: json['date_traitement'] != null
          ? DateTime.tryParse(json['date_traitement'] as String)
          : null,
    );
  }

  String get moyenLabel => switch (moyen) {
    'FLOOZ' => 'Moov Flooz',
    'YAS'   => 'Mixx by Yas',
    _       => moyen,
  };

  static const Map<String, String> statutLabels = {
    'EN_ATTENTE': 'En attente',
    'EN_COURS':   'En cours',
    'REUSSI':     'Réussi',
    'ECHOUE':     'Échoué',
    'ANNULE':     'Annulé',
  };

  String get statutLabel => statutLabels[statut] ?? statut;
}
