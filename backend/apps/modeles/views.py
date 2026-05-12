from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from datetime import datetime, timedelta
from .models import Reservation, Trajet
from .utils import calculer_economie_passager, calculer_economie_mensuelle_passager


class EconomieViewSet(viewsets.GenericViewSet):
    """
    VueSet pour les calculs économiques du passager
    """
    permission_classes = [IsAuthenticated]

    @action(detail=False, methods=['get'])
    def calculer_economie_trajet(self, request):
        """
        Calcule l'économie pour un trajet spécifique
        Paramètres: distance_km, type_vehicule, prix_kovoit_place
        """
        distance_km = request.query_params.get('distance_km')
        type_vehicule = request.query_params.get('type_vehicule')
        prix_kovoit_place = request.query_params.get('prix_kovoit_place')

        if not all([distance_km, type_vehicule, prix_kovoit_place]):
            return Response({
                "error": "Paramètres requis: distance_km, type_vehicule, prix_kovoit_place"
            }, status=400)

        try:
            distance_km = float(distance_km)
            prix_kovoit_place = float(prix_kovoit_place)
        except ValueError:
            return Response({
                "error": "distance_km et prix_kovoit_place doivent être des nombres"
            }, status=400)

        if type_vehicule not in ['moto', 'voiture', 'minibus', 'camion']:
            return Response({
                "error": "type_vehicule doit être: moto, voiture, minibus ou camion"
            }, status=400)

        resultat = calculer_economie_passager(distance_km, type_vehicule, prix_kovoit_place)
        
        return Response(resultat)

    @action(detail=False, methods=['get'])
    def mes_economies(self, request):
        """
        Retourne les économies totales du passager connecté
        Paramètres optionnels: mois, annee pour filtrer par période
        """
        user = request.user
        mois = request.query_params.get('mois')
        annee = request.query_params.get('annee')

        # Filtrer les réservations confirmées du passager
        reservations = Reservation.objects.filter(
            passager=user,
            statut='confirmee'
        ).select_related('trajet', 'trajet__vehicule')

        # Filtrer par période si spécifié
        if mois and annee:
            try:
                mois = int(mois)
                annee = int(annee)
                reservations = reservations.filter(
                    date_reservation__year=annee,
                    date_reservation__month=mois
                )
            except ValueError:
                return Response({
                    "error": "mois et annee doivent être des nombres valides"
                }, status=400)

        # Calculer les économies
        stats = calculer_economie_mensuelle_passager(reservations)
        
        # Ajouter les informations de période
        if mois and annee:
            stats['periode'] = f"{annee}-{mois:02d}"
        else:
            stats['periode'] = "Toutes périodes"

        return Response(stats)

    @action(detail=False, methods=['get'])
    def economie_annuelle(self, request):
        """
        Retourne les économies annuelles du passager
        Paramètre: annee (optionnel, défaut: année en cours)
        """
        user = request.user
        annee = request.query_params.get('annee')

        if not annee:
            annee = timezone.now().year
        else:
            try:
                annee = int(annee)
            except ValueError:
                return Response({
                    "error": "annee doit être un nombre valide"
                }, status=400)

        # Obtenir les réservations de l'année
        reservations = Reservation.objects.filter(
            passager=user,
            statut='confirmee',
            date_reservation__year=annee
        ).select_related('trajet', 'trajet__vehicule')

        # Calculer les économies
        stats = calculer_economie_mensuelle_passager(reservations)
        stats['periode'] = f"Année {annee}"

        return Response(stats)

    @action(detail=False, methods=['get'])
    def comparaison_types_vehicule(self, request):
        """
        Compare les économies par type de véhicule pour le passager
        """
        user = request.user
        
        # Obtenir toutes les réservations confirmées
        reservations = Reservation.objects.filter(
            passager=user,
            statut='confirmee'
        ).select_related('trajet', 'trajet__vehicule')

        # Grouper par type de véhicule
        stats_par_type = {}
        for reservation in reservations:
            if not reservation.trajet.distance_km:
                continue
                
            trajet = reservation.trajet
            type_vehicule = trajet.vehicule.type_vehicule if trajet.vehicule else 'voiture'
            
            if type_vehicule not in stats_par_type:
                stats_par_type[type_vehicule] = {
                    'nombre_reservations': 0,
                    'total_economie': 0,
                    'total_distance': 0,
                    'economie_moyenne': 0
                }
            
            # Calculer l'économie pour cette réservation
            calc = calculer_economie_passager(
                trajet.distance_km,
                type_vehicule,
                float(trajet.prix_par_place)
            )
            
            economie_reservation = calc['economie'] * reservation.places_reservees
            
            stats_par_type[type_vehicule]['nombre_reservations'] += 1
            stats_par_type[type_vehicule]['total_economie'] += economie_reservation
            stats_par_type[type_vehicule]['total_distance'] += trajet.distance_km

        # Calculer les moyennes
        for type_veh in stats_par_type:
            stats = stats_par_type[type_veh]
            if stats['nombre_reservations'] > 0:
                stats['economie_moyenne'] = round(
                    stats['total_economie'] / stats['nombre_reservations'], 2
                )
            stats['total_economie'] = round(stats['total_economie'], 2)

        return Response({
            'periode': 'Toutes périodes',
            'stats_par_type': stats_par_type,
            'total_general': {
                'economie_totale': sum(s['total_economie'] for s in stats_par_type.values()),
                'nombre_total_reservations': sum(s['nombre_reservations'] for s in stats_par_type.values())
            }
        })

    @action(detail=True, methods=['get'])
    def economie_reservation(self, request, pk=None):
        """
        Calcule l'économie pour une réservation spécifique
        """
        try:
            reservation = Reservation.objects.get(
                pk=pk,
                passager=request.user,
                statut='confirmee'
            )
        except Reservation.DoesNotExist:
            return Response({
                "error": "Réservation introuvable ou non confirmée"
            }, status=404)

        trajet = reservation.trajet
        if not trajet.distance_km:
            return Response({
                "error": "Distance non disponible pour ce trajet"
            }, status=400)

        type_vehicule = trajet.vehicule.type_vehicule if trajet.vehicule else 'voiture'
        
        # Calculer l'économie par place
        calc = calculer_economie_passager(
            trajet.distance_km,
            type_vehicule,
            float(trajet.prix_par_place)
        )
        
        # Adapter pour le nombre de places réservées
        economie_totale = calc['economie'] * reservation.places_reservees
        prix_reference_total = calc['prix_reference'] * reservation.places_reservees
        prix_kovoit_total = float(trajet.prix_par_place) * reservation.places_reservees

        return Response({
            'reservation_id': reservation.id,
            'trajet': f"{trajet.depart} → {trajet.destination}",
            'date_reservation': reservation.date_reservation.strftime('%Y-%m-%d %H:%M'),
            'distance_km': trajet.distance_km,
            'type_vehicule': type_vehicule,
            'places_reservees': reservation.places_reservees,
            'prix_kovoit_par_place': float(trajet.prix_par_place),
            'prix_kovoit_total': prix_kovoit_total,
            'prix_reference_par_place': calc['prix_reference'],
            'prix_reference_total': prix_reference_total,
            'economie_par_place': calc['economie'],
            'economie_totale': economie_totale,
            'pourcentage_economie': calc['pourcentage_economie'],
            'reference_type': calc['reference_type']
        })
