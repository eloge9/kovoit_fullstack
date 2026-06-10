"""
Management command to backfill OSRM polylines for existing trips.
Usage: python manage.py backfill_polylines [--limit N]
"""
import time
from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = "Backfill OSRM polylines for trips that have coordinates but no stored polyline"

    def add_arguments(self, parser):
        parser.add_argument(
            '--limit', type=int, default=0,
            help='Maximum number of trips to process (0 = all)',
        )
        parser.add_argument(
            '--delay', type=float, default=0.3,
            help='Delay in seconds between OSRM calls (default: 0.3)',
        )

    def handle(self, *args, **options):
        from apps.modeles.models import Trajet
        from apps.trajets.matching import fetch_and_store_polyline

        qs = Trajet.objects.filter(
            polyline_stored=False,
            depart_lat__isnull=False,
            destination_lat__isnull=False,
        ).exclude(statut='annule').order_by('-date_heure_depart')

        limit = options['limit']
        if limit > 0:
            qs = qs[:limit]

        total = qs.count() if not limit else min(limit, Trajet.objects.filter(
            polyline_stored=False,
            depart_lat__isnull=False,
            destination_lat__isnull=False,
        ).count())

        self.stdout.write(f"Backfilling {total} trips...")
        ok = fail = 0

        for trajet in qs.iterator(chunk_size=50):
            success = fetch_and_store_polyline(trajet)
            if success:
                ok += 1
                self.stdout.write(f"  OK {trajet.depart} -> {trajet.destination}")
            else:
                fail += 1
                self.stdout.write(
                    self.style.WARNING(f"  FAIL {trajet.depart} -> {trajet.destination} (OSRM indisponible)")
                )
            time.sleep(options['delay'])

        self.stdout.write(
            self.style.SUCCESS(f"\nTermine : {ok} succes, {fail} echecs")
        )