import os
import django

# Configuration Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from django.utils.timezone import now
from apps.modeles.models import Utilisateur, Reservation

# Récupérer l'utilisateur
utilisateur = Utilisateur.objects.get(email='gominaeloge@gmail.com')

print(f"=== DEBUG RÉSERVATIONS POUR {utilisateur.username} ===")

# Toutes ses réservations
all_reservations = Reservation.objects.filter(passager=utilisateur)
print(f"Total réservations: {all_reservations.count()}")

for res in all_reservations:
    print(f"  - ID: {res.id}")
    print(f"    Trajet: {res.trajet.depart} → {res.trajet.destination}")
    print(f"    Statut: {res.statut}")
    print(f"    Date: {res.date_reservation}")
    print(f"    Distance: {res.trajet.distance_km} km")
    print(f"    Prix: {res.trajet.prix_par_place} FCFA")
    print(f"    Places: {res.places_reservees}")
    print(f"    Véhicule: {res.trajet.vehicule}")
    print(f"    Type véhicule: {res.trajet.vehicule.type_vehicule if res.trajet.vehicule else 'N/A'}")
    print("---")

# Réservations pour la période actuelle (mois de mai 2026)
from datetime import date
debut = date(2026, 5, 1)
fin = date(2026, 5, 31)

valid_reservations = Reservation.objects.filter(
    passager=utilisateur,
    statut__in=['en_attente', 'confirmee', 'terminee'],
    date_reservation__gte=debut,
    date_reservation__lte=fin
)

print(f"\n=== RÉSERVATIONS VALIDES POUR MAI 2026 ===")
print(f"Total valides: {valid_reservations.count()}")

for res in valid_reservations:
    print(f"  - ID: {res.id}")
    print(f"    Trajet: {res.trajet.depart} → {res.trajet.destination}")
    print(f"    Date: {res.date_reservation}")
    print("---")
