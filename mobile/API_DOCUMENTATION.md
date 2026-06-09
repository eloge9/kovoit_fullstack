# KoVoit — Documentation API complète

**Base URL :** `http://localhost:8000/api`  
**Authentification :** Bearer JWT Token  
**Format :** JSON (sauf uploads : multipart/form-data)

---

## 1. AUTHENTIFICATION

### POST `/utilisateurs/auth/inscription/`
Créer un compte.

**Body (JSON) :**
```json
{
  "username": "string",
  "email": "string",
  "password": "string",
  "role": "passager | conducteur",
  "numero_telephone": "string (optionnel)",
  "numero_permis": "string (conducteur)",
  "type_vehicule": "moto | voiture | minibus | camion",
  "marque": "string",
  "modele": "string",
  "plaque": "string"
}
```
**Réponse :** `201 Created` — `{ user: {...}, access: "...", refresh: "..." }`

---

### POST `/utilisateurs/auth/connexion/`
Connexion.

**Body :** `{ email, password }`  
**Réponse :** `{ access, refresh, user: { id, username, email, role, ... } }`  
**Erreurs :** `400` mauvais credentials

---

### POST `/utilisateurs/auth/refresh/`
Rafraîchir l'access token.

**Body :** `{ refresh: "..." }`  
**Réponse :** `{ access: "..." }`

---

### POST `/utilisateurs/auth/deconnexion/`
Blacklister le refresh token.

**Auth :** Bearer  
**Body :** `{ refresh: "..." }`

---

## 2. PROFIL UTILISATEUR

### GET/PUT/PATCH `/utilisateurs/ko/profil/`
Lire ou modifier son profil.

**Auth :** Bearer  
**Réponse :**
```json
{
  "id": "uuid",
  "username": "string",
  "email": "string",
  "role": "passager | conducteur | admin",
  "numero_telephone": "string|null",
  "photo_profile": "url|null",
  "note": 4.5,
  "statut_validation": "non_soumis | en_attente | valide | rejete",
  "peut_conduire": false,
  "contact_urgence_nom": "string|null",
  "contact_urgence_telephone": "string|null",
  "mode_courant": "passager | conducteur"
}
```

---

### POST `/utilisateurs/ko/profil/change-password/`
Changer son mot de passe.

**Body :** `{ ancien_mot_de_passe, nouveau_mot_de_passe }`

---

### POST `/utilisateurs/ko/upload-documents`
Upload documents CNI / permis.

**Auth :** Bearer  
**Content-Type :** multipart/form-data  
**Fields :** `photo_cni` (image), `photo_permis` (image)

---

### POST `/utilisateurs/ko/basculer-role`
Basculer passager → conducteur (si validé).

**Auth :** Bearer

---

### POST `/utilisateurs/ko/changer-mode`
Changer le mode actif.

**Body :** `{ mode: "passager | conducteur" }`

---

### POST `/utilisateurs/ko/sos`
Alerte SOS — envoi SMS au contact d'urgence.

**Body :** `{ latitude, longitude, trajet_id (optionnel) }`  
**Rate limit :** 5/heure

---

## 3. VÉHICULES

### GET `/utilisateurs/ko/vehicules/`
Lister mes véhicules.

**Auth :** Bearer  
**Réponse :** `[ { id, type_vehicule, marque, modele, couleur, plaque, places_max, actif } ]`

---

### POST `/utilisateurs/ko/vehicules/ajouter/`
Ajouter un véhicule.

**Body :** `{ type_vehicule, marque, modele, couleur, plaque, places_max }`

---

### POST `/utilisateurs/ko/vehicules/{id}/desactiver/`
Désactiver un véhicule.

---

## 4. TRAJETS

### GET `/trajets/`
Lister les trajets disponibles (statut=ouvert).

**Auth :** Optionnelle  
**Réponse paginée :** `{ count, results: [ Trajet ] }`

---

### POST `/trajets/`
Créer un trajet (conducteur validé).

**Auth :** Bearer (conducteur)  
**Body :**
```json
{
  "vehicule": 1,
  "depart": "Lomé, Centre",
  "destination": "Kpalimé",
  "depart_lat": 6.137,
  "depart_lng": 1.212,
  "destination_lat": 6.901,
  "destination_lng": 0.624,
  "distance_km": 120.0,
  "cout_total": 7800.0,
  "prix_par_place": 2600.0,
  "date_heure_depart": "2026-06-15T08:00:00",
  "places_disponibles": 3,
  "est_regulier": false
}
```

---

### GET `/trajets/{id}/`
Détail d'un trajet.

---

### GET `/trajets/mes_trajets/`
Trajets créés par le conducteur connecté.

---

### GET `/trajets/rechercher/?depart=&destination=&date=&places=`
Rechercher des trajets.

---

### POST `/trajets/{id}/commencer/`
Démarrer un trajet. Statut `ouvert` → `en_cours`.

**Auth :** Bearer (conducteur propriétaire)

---

### POST `/trajets/{id}/terminer/`
Terminer un trajet. Statut `en_cours` → `termine`.

---

### POST `/trajets/{id}/annuler/`
Annuler un trajet ouvert.

---

## 5. RÉSERVATIONS

### POST `/reservations/reserver/`
Réserver une place.

**Auth :** Bearer (passager)  
**Body :** `{ trajet_id: 1 }`  
**Réponse :** `{ id, trajet, passager, statut: "en_attente", prix_par_place, ... }`  
**Erreurs :**
- `400` : plus de places disponibles
- `400` : déjà réservé sur ce trajet
- `400` : passager bloqué par ce conducteur

---

### GET `/reservations/mes_reservations/`
Réservations du passager connecté.

---

### GET `/reservations/recues/`
Réservations reçues (conducteur).

---

### POST `/reservations/{id}/confirmer/`
Confirmer une réservation. Décrément `places_restantes`.

**Auth :** Bearer (conducteur propriétaire du trajet)

---

### POST `/reservations/{id}/decliner/`
Décliner une réservation.

---

### POST `/reservations/{id}/annuler/`
Annuler une réservation (passager).

---

### GET `/reservations/{id}/qr-code/`
Obtenir le QR code d'une réservation confirmée.

---

## 6. PAIEMENTS

### POST `/paiements/initier/`
Initier un paiement mobile (FLOOZ/TMONEY via PayGate).

**Body :**
```json
{
  "reservation_id": 1,
  "phone_number": "+22890000000",
  "network": "FLOOZ"
}
```
**Réponse :** `{ id, paygate_tx_ref, statut: "EN_ATTENTE_CONFIRMATION" }`

---

### POST `/paiements/verifier/`
Vérifier le statut d'un paiement.

**Body :** `{ identifier: "paygate_tx_ref" }`  
**Réponse :** `{ statut: "CONFIRME | EN_ATTENTE_CONFIRMATION | ANNULE" }`

---

### POST `/paiements/initier_especes/`
Initier un paiement en espèces.

**Body :** `{ reservation_id: 1 }`

---

### POST `/paiements/confirmer_especes/`
Confirmer la réception des espèces (conducteur).

**Body :** `{ reservation_id: 1 }`

---

### POST `/paiements/soumettre_reference_mobile/`
Soumettre une référence de paiement mobile manuellement.

**Body :** `{ reservation_id, reference_mobile, network }`

---

### GET `/paiements/mes_paiements/`
Historique des paiements.

---

## 7. ÉVALUATIONS

### POST `/evaluations/evaluer/`
Évaluer un utilisateur après un trajet.

**Body :** `{ trajet_id, cible_id: "uuid", note: 1-5, commentaire: "..." }`  
**Règle :** Unique par trajet/auteur/cible

---

### GET `/evaluations/mes_evaluations/`
Évaluations reçues.

---

### GET `/evaluations/a_evaluer/`
Trajets terminés en attente d'évaluation.

---

### POST `/evaluations/signaler/`
Signaler un utilisateur.

**Body :** `{ user_id, motif }`

---

### POST `/evaluations/bloquer/`
Bloquer un passager (conducteur uniquement).

**Body :** `{ passager_id: "uuid" }`

---

### DELETE `/evaluations/debloquer/{passager_id}/`
Débloquer un passager.

---

## 8. MESSAGERIE

### GET `/messagerie/conversations/`
Lister toutes les conversations.

**Réponse :** `[ { user_id, username, dernier_message, non_lus } ]`

---

### GET `/messagerie/messages/{user_id}/`
Historique des messages avec un utilisateur.

---

### POST `/messagerie/messages/{user_id}/envoyer/`
Envoyer un message.

**Body :** `{ contenu: "..." }`

---

### GET `/messagerie/non-lus/`
Nombre de messages non lus.

**Réponse :** `{ count: 5 }`

---

### WebSocket `/ws/chat/{mon_id}/{autre_id}/?token={access_token}`
Chat temps réel.

**Message entrant :** `{ type: "message", contenu: "..." }`  
**Message sortant :** `{ type: "message", message: { id, expediteur_id, contenu, timestamp } }`

---

## 9. STATISTIQUES & ÉCONOMIE

### GET `/statistiques/conducteur/`
Stats du conducteur : revenus, trajets, km.

### GET `/statistiques/passager/`
Stats du passager : économies, trajets, CO2.

### GET `/statistiques/resume/`
Résumé général.

### GET `/economie/mes_economies/?mois=6&annee=2026`
Économies mensuelles du passager.

### GET `/economie/calculer_economie_trajet/?distance_km=120&type_vehicule=voiture`
Calcul d'économie pour un trajet hypothétique.

---

## 10. RÈGLES MÉTIER IMPORTANTES

| Règle | Détail |
|-------|--------|
| Tarif carburant Moto | 30 FCFA/km |
| Tarif carburant Voiture | 65 FCFA/km |
| Tarif carburant Minibus | 120 FCFA/km |
| Tarif carburant Camion | 200 FCFA/km |
| Commission KoVoit | 10% du montant |
| CO2 évité | 0.2 kg/km |
| Access Token | Expire en 15 min |
| Refresh Token | Expire en 7 jours + rotation |
| Throttling anonyme | 30 req/min |
| Throttling authentifié | 200 req/min |
| Throttling auth | 5 req/min |
| SOS | 5 alertes max/heure |
| Évaluation | Unique par trajet/auteur/cible |

---

## 11. CODES D'ERREUR COURANTS

| Code | Signification |
|------|--------------|
| `400` | Données invalides (voir champ `detail` ou `errors`) |
| `401` | Token expiré ou invalide → rafraîchir |
| `403` | Accès refusé (rôle insuffisant) |
| `404` | Ressource non trouvée |
| `429` | Trop de requêtes (throttling) |
| `500` | Erreur serveur |

---

*Généré automatiquement à partir de l'analyse du backend Django KoVoit.*
