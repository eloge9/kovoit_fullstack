"""
Annule automatiquement les réservations en attente dont le trajet
démarre dans moins de 2 heures et applique une pénalité de -0.5 note
au passager (pour les no-shows répétés).

Utilisation :
    python manage.py auto_annuler_reservations
    # ou via cron : */30 * * * * python manage.py auto_annuler_reservations
"""
from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta
from apps.modeles.models import Reservation, Utilisateur


class Command(BaseCommand):
    help = "Annule les réservations en attente dont le trajet part dans < 2h"

    def handle(self, *args, **options):
        seuil = timezone.now() + timedelta(hours=2)

        en_attente = Reservation.objects.filter(
            statut='en_attente',
            trajet__date_heure_depart__lte=seuil,
            trajet__statut='ouvert',
        ).select_related('passager', 'trajet')

        nb = 0
        for resa in en_attente:
            resa.statut = 'declinee'
            resa.save(update_fields=['statut'])

            # Pénalité légère : -0.5 note (plancher 0)
            passager = resa.passager
            passager.note = max(0.0, round(passager.note - 0.5, 2))
            passager.save(update_fields=['note'])

            self.stdout.write(
                f"  Annulé  {resa.passager.username} → {resa.trajet}  "
                f"(note passager : {passager.note})"
            )
            nb += 1

        self.stdout.write(self.style.SUCCESS(f"auto_annuler_reservations : {nb} réservation(s) annulée(s)."))
