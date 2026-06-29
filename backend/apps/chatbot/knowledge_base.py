"""
Base de connaissances complète de Kovoit pour le chatbot Kovi.
"""


def get_kovoit_knowledge() -> str:
    return """
=== KOVOIT — BASE DE CONNAISSANCES COMPLÈTE ===

[PRÉSENTATION GÉNÉRALE]
Kovoit est une plateforme intelligente de covoiturage développée pour faciliter les
déplacements urbains et interurbains au Togo et en Afrique de l'Ouest.
Elle met en relation des conducteurs et des passagers effectuant des trajets similaires,
en réduisant les coûts de transport, la congestion routière et l'impact environnemental.

Kovoit se distingue par :
- Géolocalisation en temps réel et suivi GPS des trajets
- Cartographie intelligente (le passager peut monter/descendre à n'importe quel point)
- Paiement mobile sécurisé (Mixx by Yas, Moov Flooz, espèces)
- Intelligence artificielle (vérification documents, assistant Kovi)
- Réalité augmentée pour guider les utilisateurs
- Messagerie instantanée (privée + groupe de trajet)
- Système de confiance et de notation bidirectionnel

Zones couvertes : Togo et Afrique de l'Ouest

[MISSION ET VALEURS]
Mission : rendre le transport plus accessible, sécurisé et économique.
Valeurs : Sécurité, Confiance, Innovation, Accessibilité, Économie,
Respect de l'environnement, Solidarité.

[TYPES D'UTILISATEURS]
1. Passager : recherche et réserve des places dans des trajets proposés par des conducteurs.
2. Conducteur : propose des trajets, accepte des réservations, reçoit des paiements.
3. Un même utilisateur peut être passager ET conducteur — le changement de rôle
   se fait facilement depuis l'application.
4. Administrateur : gère la plateforme, valide les conducteurs, consulte les statistiques.

[COMMENT CRÉER UN COMPTE]
1. Télécharger l'application Kovoit ou aller sur le site web.
2. Cliquer sur "S'inscrire".
3. Renseigner nom, prénom, email, numéro de téléphone et mot de passe.
4. Choisir son rôle : passager, conducteur, ou les deux.
5. Valider son compte.
Pour devenir conducteur, des documents supplémentaires sont requis (voir section Documents).

[COMMENT FAIRE UN TRAJET — PASSAGER]
1. Se connecter à Kovoit.
2. Dans "Rechercher un trajet", indiquer le point de départ et la destination.
3. Choisir la date et le nombre de places souhaitées.
4. Parcourir les trajets disponibles (triés par compatibilité GPS).
5. Cliquer sur un trajet et appuyer sur "Réserver".
6. Payer la réservation (Mobile Money ou espèces).
7. Recevoir le code d'embarquement et le QR Code.
8. Le jour J : présenter le QR Code au conducteur pour valider l'embarquement.
9. Suivre le trajet en temps réel sur la carte.
10. Après le trajet : noter le conducteur.

[COMMENT FAIRE UN TRAJET — CONDUCTEUR]
1. Se connecter à Kovoit en mode conducteur.
2. Aller dans "Proposer un trajet".
3. Définir le point de départ, la destination (et des étapes optionnelles).
4. Choisir la date, l'heure, le véhicule et le nombre de places disponibles.
5. Le prix est calculé automatiquement par le système.
6. Publier le trajet — il devient visible aux passagers.
7. Accepter ou refuser les réservations reçues.
8. Le jour J : démarrer le trajet, scanner les QR Codes des passagers pour l'embarquement.
9. Conduire et suivre l'itinéraire sur la carte.
10. Terminer le trajet — les paiements sont crédités.
11. Après le trajet : noter les passagers.

[RECHERCHE INTELLIGENTE DE TRAJETS]
Kovoit utilise la géolocalisation GPS réelle, pas seulement les noms de villes.
Le système analyse les coordonnées GPS et la géométrie de l'itinéraire.
Un passager peut monter et descendre à n'importe quel point du trajet du conducteur.
Les résultats sont triés par score de compatibilité (%).

[CODE D'EMBARQUEMENT ET QR CODE]
Chaque réservation confirmée génère :
- Un code d'embarquement unique (format KVT-XXXX)
- Un QR Code scannable

Le conducteur valide l'embarquement :
- En scannant le QR Code du passager avec l'application
- Ou en saisissant manuellement le code KVT-XXXX

[TARIFS ET CALCUL DU PRIX]
Le prix est calculé automatiquement selon :
- La distance réelle du trajet (en km)
- Le type de véhicule (Moto, Voiture, Minibus, Camion)
- Le nombre de places réservées

Types de véhicules et tarification :
- Moto : tarif le plus bas (courte distance)
- Voiture : tarif standard
- Minibus : tarif intermédiaire
- Camion : tarif variable selon le chargement

La devise utilisée est le Franc CFA (FCFA).

[PAIEMENTS]
Méthodes acceptées :
1. Mixx by Yas (paiement mobile)
2. Moov Flooz (paiement mobile)
3. Espèces (paiement direct au conducteur)

Pour payer :
1. Sélectionner la méthode de paiement après la réservation.
2. Pour Mobile Money : saisir le numéro de téléphone et confirmer.
3. Le paiement est sécurisé via PayPlus Africa.

[GAINS CONDUCTEUR ET PORTEFEUILLE]
- Chaque utilisateur dispose d'un portefeuille Kovoit.
- Les gains du conducteur sont crédités après chaque trajet terminé.
- Consulter ses gains : aller dans "Mon portefeuille" ou "Économie".
- On peut voir : solde actuel, historique des paiements reçus, historique des dépenses.
# TODO: Ajouter les délais de virement et le processus de retrait d'argent

[INSCRIPTION CONDUCTEUR ET DOCUMENTS]
Pour devenir conducteur sur Kovoit :
# TODO: Préciser la liste exacte des documents requis (permis, assurance, carte grise, etc.)
- Les documents sont vérifiés par intelligence artificielle + validation admin
- Le processus de vérification garantit la sécurité pour tous les passagers
# TODO: Préciser les délais d'approbation

[MESSAGERIE]
Kovoit propose deux types de messagerie :

1. Messagerie privée (WhatsApp-style) :
   - Une conversation permanente entre deux utilisateurs
   - Accessible même sans trajet en commun
   - La même conversation est utilisée pour tous les trajets entre ces deux personnes

2. Chat de groupe de trajet (Uber-style) :
   - Créé automatiquement quand une réservation est confirmée
   - Inclut le conducteur et tous les passagers confirmés du trajet
   - Accessible depuis le détail de la réservation

Fonctionnalités : texte, messages vocaux, réponse à un message, réactions emoji,
modification et suppression de messages, lecture en temps réel (WebSocket).

[SUIVI EN TEMPS RÉEL]
Le passager peut :
- Suivre la position du conducteur sur la carte
- Voir le déplacement du véhicule
- Consulter l'heure d'arrivée estimée
- Voir l'itinéraire complet

Le conducteur peut :
- Voir la position des passagers avant l'embarquement
- Naviguer avec le GPS intégré

[NOTATION ET ÉVALUATIONS]
Après chaque trajet terminé :
- Le passager peut noter le conducteur (1 à 5 étoiles + commentaire)
- Le conducteur peut noter le passager
La note moyenne est visible sur le profil public de chaque utilisateur.
Un bon score de confiance favorise l'acceptation des réservations.

[ANNULATION]
Un passager peut annuler une réservation depuis son historique.
# TODO: Préciser la politique d'annulation et les éventuelles pénalités

[HISTORIQUE]
Les utilisateurs peuvent consulter depuis leur profil :
- Tous leurs trajets passés
- Toutes leurs réservations (en attente, confirmées, terminées, annulées)
- Tous leurs paiements effectués
- Tous leurs gains reçus (conducteur)

[SÉCURITÉ]
Kovoit met en œuvre :
- Authentification sécurisée par JWT (token)
- Vérification des documents conducteur par IA
- Bouton SOS d'urgence avec localisation GPS
- Contact d'urgence personnalisable
- Chiffrement des données sensibles
- Contrôle des accès par rôle
En cas de problème pendant un trajet : utiliser le bouton SOS dans l'application.

[NOTIFICATIONS]
L'application envoie des notifications pour :
- Nouvelle réservation reçue (conducteur)
- Réservation acceptée/refusée (passager)
- Nouveau message
- Début du trajet
- Paiement effectué/reçu
- Rappels

[CONTACT ET SUPPORT]
Pour contacter l'équipe Kovoit :
- Téléphone / WhatsApp : 91 27 10 04
- Email : gominaeloge@gmail.com
# TODO: Préciser les heures de disponibilité du support
# TODO: Ajouter un lien vers le formulaire de contact dans l'application

[ZONES DE SERVICE]
Kovoit est disponible au Togo et couvre l'Afrique de l'Ouest.
# TODO: Lister les villes spécifiques couvertes au Togo (Lomé, Kpalimé, Atakpamé, etc.)

[COMPTE ET PROFIL]
- Modifier son profil : aller dans "Mon profil" > "Modifier"
- Changer sa photo de profil : dans "Mon profil" > icône appareil photo
- Changer de mot de passe : "Mon profil" > "Sécurité" > "Changer le mot de passe"
- Changer de rôle (passager ↔ conducteur) : depuis le tableau de bord
# TODO: Préciser le processus de suppression de compte

[PROBLÈMES FRÉQUENTS ET SOLUTIONS]
- Conducteur n'arrive pas : utiliser la messagerie pour le contacter, sinon appuyer sur SOS
- Paiement échoué : vérifier le solde Mobile Money, réessayer ou choisir espèces
- QR Code non reconnu : demander au conducteur de saisir le code KVT-XXXX manuellement
- Réservation non confirmée : le conducteur a 24h pour accepter, contacter le support si dépassé
- Application lente : vérifier la connexion internet, fermer et relancer l'application
- Mot de passe oublié : sur la page de connexion > "Mot de passe oublié" > email de réinitialisation
# TODO: Compléter avec d'autres cas fréquents

=== FIN DE LA BASE DE CONNAISSANCES ===
"""
