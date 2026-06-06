"""
Crée les occurrences du lendemain pour les trajets réguliers (est_regulier=True).
À lancer chaque nuit (ex: 23h) via cron ou tâche planifiée.

Utilisation :
    python manage.py creer_trajets_recurrents
"""
from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta
from apps.modeles.models import Trajet

JOURS_FR = {
    'lundi': 0, 'mardi': 1, 'mercredi': 2, 'jeudi': 3,
    'vendredi': 4, 'samedi': 5, 'dimanche': 6,
}


class Command(BaseCommand):
    help = "Génère les occurrences du lendemain pour les trajets réguliers"

    def handle(self, *args, **options):
        demain     = timezone.now().date() + timedelta(days=1)
        jour_index = demain.weekday()  # 0=lundi … 6=dimanche
        nb_crees   = 0

        reguliers = Trajet.objects.filter(
            est_regulier=True,
            statut__in=['ouvert', 'en_cours'],
            jours_semaine__isnull=False,
        ).select_related('conducteur', 'vehicule')

        for trajet in reguliers:
            jours = trajet.jours_semaine or []
            jours_indexes = [JOURS_FR.get(j.lower(), -1) for j in jours]

            if jour_index not in jours_indexes:
                continue

            # Heure du trajet modèle
            heure_depart = trajet.date_heure_depart.time()
            new_depart   = timezone.make_aware(
                timezone.datetime.combine(demain, heure_depart)
            )

            # Vérifier qu'une occurrence n'existe pas déjà
            existe = Trajet.objects.filter(
                conducteur=trajet.conducteur,
                depart=trajet.depart,
                destination=trajet.destination,
                date_heure_depart__date=demain,
            ).exists()

            if existe:
                continue

            Trajet.objects.create(
                conducteur=trajet.conducteur,
                vehicule=trajet.vehicule,
                depart=trajet.depart,
                depart_lat=trajet.depart_lat,
                depart_lng=trajet.depart_lng,
                destination=trajet.destination,
                destination_lat=trajet.destination_lat,
                destination_lng=trajet.destination_lng,
                distance_km=trajet.distance_km,
                cout_total=trajet.cout_total,
                prix_par_place=trajet.prix_par_place,
                date_heure_depart=new_depart,
                places_disponibles=trajet.places_disponibles,
                description=trajet.description,
                est_regulier=True,
                jours_semaine=trajet.jours_semaine,
                statut='ouvert',
            )

            self.stdout.write(f"  Créé  {trajet.depart} → {trajet.destination} le {demain}")
            nb_crees += 1

        self.stdout.write(self.style.SUCCESS(f"creer_trajets_recurrents : {nb_crees} trajet(s) créé(s) pour le {demain}."))
