# Documentation API Administration KoVoit

## 📋 Vue d'ensemble

L'API d'administration KoVoit fournit un ensemble complet d'endpoints pour gérer la plateforme, y compris:

- Gestion des utilisateurs (suspension, validation, suppression)
- Consultation des trajets et réservations
- Gestion des paiements et revenus
- Gestion des plaintes et signalements
- Statistiques globales

## 🔐 Authentification

Tous les endpoints d'administration nécessitent:

1. Un utilisateur connecté avec le rôle `admin`
2. Un token JWT valide dans le header `Authorization: Bearer <token>`

## 🗂️ Base URL

```
/api/utilisateurs/admin/
```

---

## 📊 UTILISATEURS

### 1. Lister tous les utilisateurs

**GET** `/utilisateurs/`

**Paramètres de requête:**

- `role` (optionnel): `conducteur`, `passager`, ou `admin`
- `actif` (optionnel): `true` ou `false`

**Exemple:**

```bash
GET /api/utilisateurs/admin/utilisateurs/?role=conducteur&actif=true
```

**Réponse:**

```json
[
  {
    "id": "uuid",
    "username": "john_driver",
    "email": "john@example.com",
    "role": "conducteur",
    "numero_telephone": "+237xxx",
    "photo_profil": "url",
    "note": 4.5,
    "is_active": true,
    "date_joined": "2024-01-15T10:00:00Z",
    "profil_conducteur": {
      "id": 1,
      "numero_permis": "PERM123456",
      "experience_annees": 5
    },
    "vehicules": [
      {
        "id": 1,
        "type_vehicule": "voiture",
        "marque": "Toyota",
        "modele": "Corolla",
        "plaque": "AB-123-CD"
      }
    ],
    "nombre_trajets": 45,
    "nombre_reservations": 0,
    "nombre_evaluations_recues": 45,
    "nombre_plaintes": 0
  }
]
```

---

### 2. Voir détails d'un utilisateur

**GET** `/utilisateurs/{user_id}/`

**Réponse:** Même format que lister, mais un seul utilisateur

---

### 3. Valider un conducteur

**POST** `/utilisateurs/{user_id}/valider-conducteur/`

**Conditions:**

- L'utilisateur doit être un conducteur (`role='conducteur'`)
- Doit avoir un permis enregistré
- Doit avoir au moins un véhicule

**Réponse:**

```json
{
  "message": "Conducteur validé et activé",
  "utilisateur": {
    /* détails utilisateur */
  }
}
```

---

### 4. Suspendre un utilisateur

**POST** `/utilisateurs/{user_id}/suspendre/`

**Effet:** Désactive le compte (set `is_active=false`)

**Réponse:**

```json
{
  "message": "Utilisateur john_driver suspendu",
  "utilisateur": {
    /* détails utilisateur */
  }
}
```

---

### 5. Réactiver un utilisateur

**POST** `/utilisateurs/{user_id}/activer/`

**Effet:** Réactive le compte (set `is_active=true`)

---

### 6. Supprimer un utilisateur

**POST** `/utilisateurs/{user_id}/supprimer/`

⚠️ **ATTENTION:** Suppression définitive du compte et de toutes ses données

---

## 🚗 TRAJETS

### Lister tous les trajets

**GET** `/trajets/`

**Paramètres de requête:**

- `statut` (optionnel): `ouvert`, `en_cours`, `termine`, `annule`
- `conducteur_id` (optionnel): UUID du conducteur
- `date_depuis` (optionnel): ISO 8601 format (ex: `2024-01-15T10:00:00`)

**Exemple:**

```bash
GET /api/utilisateurs/admin/trajets/?statut=termine&date_depuis=2024-01-01T00:00:00
```

**Réponse:**

```json
[
  {
    "id": 1,
    "conducteur": "uuid",
    "conducteur_details": {
      /* infos conducteur */
    },
    "vehicule": 1,
    "depart": "Douala",
    "destination": "Yaoundé",
    "distance_km": 250,
    "cout_total": 25000,
    "prix_par_place": 5000,
    "date_heure_depart": "2024-01-15T08:00:00Z",
    "places_disponibles": 0,
    "statut": "termine",
    "est_regulier": false,
    "created_at": "2024-01-14T15:00:00Z",
    "updated_at": "2024-01-15T18:00:00Z",
    "reservations_count": 5,
    "revenus_total": 25000,
    "commission_kovoit": 2500
  }
]
```

---

## 💰 PAIEMENTS

### 1. Lister tous les paiements

**GET** `/paiements/`

**Paramètres:**

- `statut` (optionnel): `EN_ATTENTE_CONFIRMATION`, `CONFIRME`, `ANNULE`
- `moyen` (optionnel): `ESPECE`, `FLOOZ`, `TMONEY`, etc
- `date_depuis` (optionnel): ISO 8601 format

**Exemple:**

```bash
GET /api/utilisateurs/admin/paiements/?statut=CONFIRME&moyen=FLOOZ
```

**Réponse:**

```json
[
  {
    "id": 1,
    "reservation": 1,
    "passager": "uuid",
    "passager_details": {
      /* infos passager */
    },
    "conducteur": "uuid",
    "conducteur_details": {
      /* infos conducteur */
    },
    "montant": 5000,
    "moyen_paiement": "FLOOZ",
    "statut": "CONFIRME",
    "date_creation": "2024-01-15T08:30:00Z",
    "date_confirmation": "2024-01-15T08:45:00Z",
    "date_payement": null,
    "trajet_details": {
      /* infos trajet */
    }
  }
]
```

---

### 2. Statistiques des paiements

**GET** `/paiements/statistiques/`

**Paramètres:**

- `date_depuis` (optionnel): ISO 8601 format

**Réponse:**

```json
{
  "periode_depuis": "2024-01-01T00:00:00",
  "total_revenus": 500000,
  "commission_kovoit_10percent": 50000,
  "montant_aux_conducteurs": 450000,
  "nombre_transactions": 100,
  "montant_moyen_transaction": 5000,
  "repartition_par_moyen": [
    {
      "moyen_paiement": "FLOOZ",
      "count": 60,
      "total": 300000
    },
    {
      "moyen_paiement": "TMONEY",
      "count": 40,
      "total": 200000
    }
  ]
}
```

---

## ⚠️ PLAINTES & SIGNALEMENTS

### 1. Lister les plaintes

**GET** `/plaintes/`

**Paramètres:**

- `statut` (optionnel): `en_attente`, `en_cours`, `resolue`, `rejetee`, `suspendue`
- `type` (optionnel): `conducteur`, `passager`, `comportement`, `vehicule`, `autre`

**Exemple:**

```bash
GET /api/utilisateurs/admin/plaintes/?statut=en_attente
```

**Réponse:**

```json
[
  {
    "id": "uuid",
    "titre": "Conducteur agressif",
    "description": "Le conducteur a eu un comportement agressif...",
    "type_plainte": "comportement",
    "statut": "en_attente",
    "signalataire": "uuid",
    "signalataire_details": {
      /* infos signalataire */
    },
    "utilisateur_signale": "uuid",
    "utilisateur_signale_details": {
      /* infos utilisateur signalé */
    },
    "trajet": 1,
    "evaluation": null,
    "admin_assigne": null,
    "admin_assigne_details": null,
    "note_admin": "",
    "date_creation": "2024-01-15T10:00:00Z",
    "date_modification": "2024-01-15T10:00:00Z",
    "date_resolution": null
  }
]
```

---

### 2. Assigner une plainte

**POST** `/plaintes/{plainte_id}/assigner/`

**Effet:**

- Assigne la plainte à l'admin connecté
- Change le statut à `en_cours`

**Réponse:**

```json
{
  "message": "Plainte assignée à cet administrateur",
  "plainte": {
    /* détails plainte */
  }
}
```

---

### 3. Résoudre une plainte

**POST** `/plaintes/{plainte_id}/resoudre/`

**Body:**

```json
{
  "note_admin": "Conducteur averti et suspendu pour 7 jours"
}
```

**Effet:**

- Change le statut à `resolue`
- Enregistre la date de résolution
- Sauvegarde la note d'admin

**Réponse:**

```json
{
  "message": "Plainte marquée comme résolue",
  "plainte": {
    /* détails plainte */
  }
}
```

---

## 📈 STATISTIQUES GLOBALES

### Voir les statistiques générales

**GET** `/statistiques/`

**Réponse:**

```json
{
  "nombre_utilisateurs_total": 1250,
  "nombre_conducteurs": 320,
  "nombre_passagers": 920,
  "nombre_admins": 10,

  "nombre_trajets_total": 4500,
  "nombre_trajets_ouverts": 125,
  "nombre_trajets_termines": 4200,
  "nombre_trajets_annules": 175,

  "nombre_reservations_total": 15000,
  "nombre_reservations_confirmees": 12000,
  "nombre_reservations_terminees": 12000,

  "nombre_paiements_total": 12000,
  "nombre_paiements_confirmes": 11800,

  "revenu_total_kovoit": 125000,
  "revenu_total_conducteurs": 1125000,

  "nombre_evaluations": 11800,
  "note_moyenne_conducteurs": 4.3,
  "note_moyenne_passagers": 4.1,

  "nombre_plaintes": 45,
  "nombre_plaintes_en_attente": 12,
  "nombre_plaintes_resolues": 25
}
```

---

## 🛠️ EXEMPLES D'UTILISATION

### Exemple 1: Valider un conducteur

```bash
# Étape 1: Récupérer l'ID du conducteur
GET /api/utilisateurs/admin/utilisateurs/?role=conducteur

# Étape 2: Valider le conducteur
POST /api/utilisateurs/admin/utilisateurs/{conducteur_id}/valider-conducteur/

# Réponse: Le conducteur est maintenant actif et peut créer des trajets
```

### Exemple 2: Gérer une plainte

```bash
# Étape 1: Voir les plaintes en attente
GET /api/utilisateurs/admin/plaintes/?statut=en_attente

# Étape 2: Assigner la plainte
POST /api/utilisateurs/admin/plaintes/{plainte_id}/assigner/

# Étape 3: Résoudre la plainte après investigation
POST /api/utilisateurs/admin/plaintes/{plainte_id}/resoudre/
Content-Type: application/json

{
  "note_admin": "Utilisateur signalé a fourni une explication satisfaisante. Plainte rejetée."
}
```

### Exemple 3: Analyser les revenus

```bash
# Obtenir les statistiques globales
GET /api/utilisateurs/admin/statistiques/

# Obtenir le détail des paiements confirmés
GET /api/utilisateurs/admin/paiements/?statut=CONFIRME

# Obtenir les statistiques détaillées des paiements
GET /api/utilisateurs/admin/paiements/statistiques/
```

---

## 🔍 Codes d'erreur

| Code | Signification            |
| ---- | ------------------------ |
| 200  | Succès                   |
| 201  | Créé                     |
| 400  | Mauvaise requête         |
| 401  | Non authentifié          |
| 403  | Accès refusé (pas admin) |
| 404  | Ressource non trouvée    |
| 500  | Erreur serveur           |

---

## 📝 Notes

- Toutes les dates sont en UTC/ISO 8601 format
- Les UUIDs sont utilisés pour l'ID des utilisateurs
- Les revenus KoVoit sont calculés à 10% du montant total
- Les plaintes rejetées/suspendues ne peuvent pas être réouvertes
- La suppression d'utilisateur est irréversible
