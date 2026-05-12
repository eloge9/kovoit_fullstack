# Gestion des Incohérences de Statuts

## Description

Ce document décrit comment gérer les incohérences entre les statuts des trajets et des réservations dans Kovoit.

## Problématique

Il peut y avoir des incohérences dans la base de données où :
- Un trajet est marqué comme `termine` mais ses réservations ont un statut différent de `confirmee`
- Un trajet est `ouvert` mais a des réservations `confirmee`

Ces incohérences affectent le calcul des économies des passagers.

## Statuts Attendus

### Trajets
- `ouvert`: Le trajet est disponible pour réservation
- `en_cours`: Le trajet est en cours de réalisation
- `termine`: Le trajet est terminé
- `annule`: Le trajet a été annulé

### Réservations
- `en_attente`: Réservation en attente de confirmation
- `confirmee`: Réservation confirmée (utilisée pour les calculs d'économies)
- `annulee`: Réservation annulée

## Règles de Cohérence

1. **Trajet terminé** → Réservations doivent être `confirmee`
2. **Trajet ouvert** → Réservations ne doivent pas être `confirmee`
3. **Trajet annulé** → Réservations doivent être `annulee`

## Script de Vérification

Un script automatique est disponible pour vérifier et corriger ces incohérences :

```bash
# Vérifier seulement
python manage_statuts.py

# Vérifier et corriger automatiquement
python manage_statuts.py --auto-correct
```

## Résolution Manuelle

Si vous préférez corriger manuellement :

```python
# Lancer le shell Django
python manage.py shell

# Voir les incohérences
from apps.modeles.models import Trajet, Reservation

# Trajets terminés avec réservations non confirmées
trajets_termines = Trajet.objects.filter(statut='termine')
for trajet in trajets_termines:
    reservations_non_confirmees = Reservation.objects.filter(
        trajet=trajet
    ).exclude(statut='confirmee')
    if reservations_non_confirmees.exists():
        print(f"Trajet {trajet.id}: {trajet.depart} → {trajet.destination}")
        for res in reservations_non_confirmees:
            print(f"  Réservation {res.id}: {res.statut} -> confirmee")
            res.statut = 'confirmee'
            res.save()
```

## Automatisation Suggérée

Pour éviter ces problèmes à l'avenir :

1. **Trigger sur changement de statut de trajet** : Mettre à jour automatiquement les réservations
2. **Validation dans les vues** : Vérifier la cohérence avant de sauvegarder
3. **Tâche planifiée** : Exécuter le script de vérification régulièrement

## Impact sur les Économies

Les calculs d'économies ne considèrent que les réservations avec le statut `confirmee`. Une incohérence peut donc :
- **Sous-estimer** les économies si des réservations valides ont un autre statut
- **Surestimer** si des réservations invalides sont marquées `confirmee`

## Monitoring

Surveillez régulièrement :
- Le nombre total de réservations `confirmee`
- Le ratio trajets terminés / réservations confirmées
- Les logs d'erreurs dans les calculs d'économies

## Contact

En cas de problème ou question, contactez l'équipe de développement.
