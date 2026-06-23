class AppConstants {
  static const String appName = 'KoVoit';
  static const String appVersion = '1.0.0';

  // Rôles utilisateur
  static const String rolePassager = 'passager';
  static const String roleConducteur = 'conducteur';
  static const String roleAdmin = 'admin';

  // Statuts trajet
  static const String trajetOuvert = 'ouvert';
  static const String trajetEnCours = 'en_cours';
  static const String trajetTermine = 'termine';
  static const String trajetAnnule = 'annule';

  // Statuts réservation
  static const String reservEnAttente = 'en_attente';
  static const String reservConfirmee = 'confirmee';
  static const String reservDeclinee = 'declinee';
  static const String reservTerminee = 'terminee';

  // Statuts paiement
  static const String paiementEnAttente = 'EN_ATTENTE_CONFIRMATION';
  static const String paiementConfirme = 'CONFIRME';
  static const String paiementAnnule = 'ANNULE';

  // Moyens de paiement — PayPlus Africa
  static const String paiementEspeces = 'ESPECE';
  static const String paiementFlooz   = 'FLOOZ';   // Moov Flooz (Moov Togo)
  static const String paiementYas     = 'YAS';     // Mixx by Yas (Yas Togo)

  // Statuts validation documents
  static const String validNonSoumis = 'non_soumis';
  static const String validEnAttente = 'en_attente';
  static const String validValide = 'valide';
  static const String validRejete = 'rejete';

  // Types véhicule et tarifs FCFA/km
  static const String vehiculeMoto = 'moto';
  static const String vehiculeVoiture = 'voiture';
  static const String vehiculeMinibus = 'minibus';
  static const String vehiculeCamion = 'camion';

  static const Map<String, int> tarifCarburant = {
    'moto': 30,
    'voiture': 65,
    'minibus': 120,
    'camion': 200,
  };

  // Commission KoVoit
  static const double commissionRate = 0.10;

  // CO2 évité kg/km
  static const double co2ParKm = 0.2;

  static String vehiculeLabel(String type) {
    switch (type) {
      case 'moto':
        return 'Moto';
      case 'voiture':
        return 'Voiture';
      case 'minibus':
        return 'Minibus';
      case 'camion':
        return 'Camion';
      default:
        return type;
    }
  }

  // Clés de stockage
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String userRoleKey = 'user_role';
}
