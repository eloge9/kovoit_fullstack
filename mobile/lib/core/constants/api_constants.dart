class ApiConstants {
  // Pour emulateur Android: 10.0.2.2 = localhost machine hôte
  // Pour device réel: mettre l'IP de votre machine (ex: 192.168.1.x)
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  // WebSocket
  static const String wsBaseUrl = 'ws://10.0.2.2:8000/ws';

  // Auth
  static const String inscription = '/utilisateurs/auth/inscription/';
  static const String connexion = '/utilisateurs/auth/connexion/';
  static const String deconnexion = '/utilisateurs/auth/deconnexion/';
  static const String refreshToken = '/utilisateurs/auth/refresh/';

  // Profil
  static const String profil = '/utilisateurs/ko/profil/';
  static const String changePassword = '/utilisateurs/ko/profil/change-password/';
  static const String uploadDocuments = '/utilisateurs/ko/upload-documents';
  static const String basculerRole = '/utilisateurs/ko/basculer-role';
  static const String changerMode = '/utilisateurs/ko/changer-mode';
  static const String sos = '/utilisateurs/ko/sos';

  // Véhicules
  static const String vehicules = '/utilisateurs/ko/vehicules/';
  static const String ajouterVehicule = '/utilisateurs/ko/vehicules/ajouter/';

  // Trajets
  static const String trajets = '/trajets/';
  static const String mesTrajets = '/trajets/mes_trajets/';
  static const String rechercherTrajets = '/trajets/rechercher/';

  // Réservations
  static const String reserver = '/reservations/reserver/';
  static const String mesReservations = '/reservations/mes_reservations/';
  static const String reservationsRecues = '/reservations/recues/';

  // Paiements
  static const String initierPaiement = '/paiements/initier/';
  static const String verifierPaiement = '/paiements/verifier/';
  static const String initierEspeces = '/paiements/initier_especes/';
  static const String confirmerEspeces = '/paiements/confirmer_especes/';
  static const String soumettreReference = '/paiements/soumettre_reference_mobile/';
  static const String confirmerMobile = '/paiements/confirmer_mobile/';
  static const String statutReservation = '/paiements/statut_reservation/';
  static const String mesPaiements = '/paiements/mes_paiements/';

  // Évaluations
  static const String evaluer = '/evaluations/evaluer/';
  static const String mesEvaluations = '/evaluations/mes_evaluations/';
  static const String aEvaluer = '/evaluations/a_evaluer/';
  static const String signaler = '/evaluations/signaler/';
  static const String bloquer = '/evaluations/bloquer/';
  static const String mesBlocages = '/evaluations/mes_blocages/';

  // Messagerie
  static const String conversations = '/messagerie/conversations/';
  static const String nonLus = '/messagerie/non-lus/';

  // Statistiques / Économie
  static const String statsConducteur = '/statistiques/conducteur/';
  static const String statsPassager = '/statistiques/passager/';
  static const String statsResume = '/statistiques/resume/';
  static const String mesEconomies = '/economie/mes_economies/';
  static const String calculerEconomie = '/economie/calculer_economie_trajet/';
}
