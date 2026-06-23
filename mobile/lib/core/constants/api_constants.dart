class ApiConstants {
  // Mis à jour dynamiquement par ServerProvider au démarrage
  static String baseUrl = 'http://192.168.1.1:8000/api';
  static String wsBaseUrl = 'ws://192.168.1.1:8000/ws';

  static const int port = 8000;
  static const String pingPath = '/api/ping/';

  // Sous-réseaux à scanner (dans l'ordre de priorité)
  static const List<String> scanSubnets = [
    '192.168.1',
    '192.168.0',
    '192.168.43',
    '10.0.0',
    '10.0.2',
    '172.16.0',
  ];

  // IPs prioritaires testées en premier (gateway, émulateur Android)
  static const List<String> quickCandidates = [
    '10.0.2.2',      // émulateur Android -> machine hôte
    '192.168.1.1',
    '192.168.0.1',
    '192.168.43.1',
    '10.0.0.1',
    '172.16.0.1',
  ];

  static void updateServerUrl(String serverUrl) {
    // serverUrl ex: 'http://192.168.1.100:8000'
    baseUrl = '$serverUrl/api';
    wsBaseUrl = '${serverUrl.replaceFirst('http://', 'ws://')}/ws';
    _serverBase = serverUrl;
  }

  // Base du serveur sans '/api' (pour construire les URLs media)
  static String _serverBase = 'http://192.168.1.1:8000';

  /// Construit une URL absolue pour un fichier media Django.
  /// Django retourne des chemins relatifs comme /media/photos/xxx.jpg
  static String buildMediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = _serverBase.isEmpty
        ? baseUrl.replaceFirst(RegExp(r'/api$'), '')
        : _serverBase;
    return '$base$path';
  }

  // Auth
  static const String inscription = '/utilisateurs/auth/inscription/';
  static const String connexion = '/utilisateurs/auth/connexion/';
  static const String deconnexion = '/utilisateurs/auth/deconnexion/';
  static const String refreshToken = '/utilisateurs/auth/refresh/';
  static const String demanderCodeReset = '/utilisateurs/auth/demander-code/';
  static const String reinitialisation = '/utilisateurs/auth/reinitialisation/';

  // Profil
  static const String profil = '/utilisateurs/ko/profil/';
  static const String changePassword = '/utilisateurs/ko/profil/change-password/';
  static const String uploadDocuments = '/utilisateurs/ko/upload-documents/';
  static const String basculerRole = '/utilisateurs/ko/basculer-role/';
  static const String changerMode = '/utilisateurs/ko/changer-mode/';
  static const String sos = '/utilisateurs/ko/sos/';

  // Véhicules
  static const String vehicules = '/utilisateurs/ko/vehicules/';
  static const String ajouterVehicule = '/utilisateurs/ko/vehicules/ajouter/';

  // Trajets
  static const String trajets = '/trajets/';
  static const String mesTrajets = '/trajets/mes_trajets/';
  static const String rechercherTrajets = '/trajets/rechercher/';
  static const String rechercherParItineraire = '/trajets/rechercher-itineraire/';

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

  // Admin
  static const String adminUtilisateurs = '/utilisateurs/admin/utilisateurs/';
  static const String adminConducteurs = '/verification/admin/drivers/';
  static const String adminReservations = '/reservations/admin/';
  static const String adminPaiements = '/paiements/admin/';
  static const String adminStats = '/verification/admin/drivers/stats/';
  static const String adminPlaintes = '/plaintes/';

  // Notifications WebSocket
  static const String wsNotifications = '/ws/notifications/';
}
