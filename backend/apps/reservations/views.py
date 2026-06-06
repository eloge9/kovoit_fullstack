from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.exceptions import NotFound, PermissionDenied
from django.db import transaction
from django.db.models import Q
from ..modeles.models import Reservation, Trajet
from .serializers import ReservationSerializer, ReservationCreateSerializer


class ReservationViewSet(viewsets.GenericViewSet):
    permission_classes = [IsAuthenticated]

    def get_object(self):
        pk = self.kwargs.get('pk')
        try:
            # Filtre propriétaire dans la même requête DB :
            # même réponse 404 que la réservation n'existe pas ou n'appartienne pas à l'user.
            # Évite le timing-leak qui révèle l'existence d'une ressource (IDOR).
            return Reservation.objects.select_related(
                'trajet', 'trajet__conducteur', 'passager'
            ).get(
                Q(passager=self.request.user) | Q(trajet__conducteur=self.request.user),
                pk=pk,
            )
        except Reservation.DoesNotExist:
            raise NotFound("Réservation introuvable.")

    def retrieve(self, request, pk=None):
        reservation = self.get_object()
        serializer = ReservationSerializer(reservation)
        return Response(serializer.data)

    @action(detail=False, methods=['post'])
    def reserver(self, request):
        serializer = ReservationCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        trajet_id = serializer.validated_data['trajet_id']

        # CORRECTION RACE CONDITION : Verrouillage de la ligne en base pour la durée de la transaction
        with transaction.atomic():
            try:
                trajet = Trajet.objects.select_for_update().get(pk=trajet_id, statut='ouvert')
            except Trajet.DoesNotExist:
                return Response({"error": "Trajet introuvable ou non disponible."}, status=404)

            if trajet.conducteur == request.user:
                return Response({"error": "Vous ne pouvez pas réserver votre propre trajet."}, status=400)

            if Reservation.objects.filter(trajet=trajet, passager=request.user, statut__in=['en_attente', 'confirmee']).exists():
                return Response({"error": "Vous avez déjà une réservation active pour ce trajet."}, status=400)

            # Recalculer le nombre de places confirmées DANS la transaction verrouillée
            nb_confirmees = trajet.reservations.filter(statut='confirmee').count()
            if nb_confirmees >= trajet.places_disponibles:
                return Response({"error": "Plus de places disponibles."}, status=400)

            reservation = Reservation.objects.create(
                trajet=trajet, passager=request.user, statut='en_attente'
            )

            # CORRECTION TYPEERROR : Gestion sécurisée si prix_par_place est None
            prix_prevu = float(trajet.prix_par_place) if trajet.prix_par_place is not None else 0.0

            return Response({
                "message": "Réservation envoyée. En attente de confirmation.",
                "reservation_id": reservation.id,
                "prix_prevu": str(prix_prevu),
            }, status=201)

    @action(detail=False, methods=['get'])
    def mes_reservations(self, request):
        reservations = Reservation.objects.filter(
            passager=request.user
        ).select_related(
            'trajet', 'trajet__conducteur', 'passager', 'paiement'
        ).order_by('-date_reservation')[:100]
        return Response(ReservationSerializer(reservations, many=True).data)

    @action(detail=False, methods=['get'])
    def recues(self, request):
        reservations = Reservation.objects.filter(
            trajet__conducteur=request.user
        ).select_related(
            'trajet', 'passager', 'paiement'
        ).order_by('-date_reservation')[:100]
        return Response(ReservationSerializer(reservations, many=True).data)

    @action(detail=True, methods=['post'])
    def confirmer(self, request, pk=None):
        with transaction.atomic():
            try:
                reservation = Reservation.objects.select_related('trajet').get(
                    pk=pk, trajet__conducteur=request.user
                )
            except Reservation.DoesNotExist:
                raise PermissionDenied("Réservation introuvable ou accès non autorisé.")

            if reservation.statut == 'confirmee':
                return Response({"error": "Déjà confirmée."}, status=400)

            # Verrouiller le trajet pour sérialiser les confirmations concurrentes.
            # Sans ce verrou, deux clics simultanés du conducteur peuvent confirmer
            # plus de passagers que le nombre de places disponibles.
            trajet = Trajet.objects.select_for_update().get(pk=reservation.trajet_id)

            nb_confirmees = trajet.reservations.filter(statut='confirmee').count()
            if nb_confirmees >= trajet.places_disponibles:
                return Response(
                    {"error": f"Capacité atteinte : {trajet.places_disponibles} place(s) maximum."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            reservation.statut = 'confirmee'
            reservation.save()

        prix_par_place = float(trajet.prix_par_place) if trajet.prix_par_place is not None else 0.0

        return Response({
            "message": "Réservation confirmée.",
            "prix_par_place": prix_par_place,
            "nb_passagers_confirmes": nb_confirmees + 1,
        })

    @action(detail=True, methods=['post'])
    def decliner(self, request, pk=None):
        # CORRECTION IDOR : Filtrage direct par conducteur
        try:
            reservation = Reservation.objects.select_related('trajet').get(pk=pk, trajet__conducteur=request.user)
        except Reservation.DoesNotExist:
            raise PermissionDenied("Réservation introuvable ou accès non autorisé.")

        if reservation.statut == 'declinee':
            return Response({"error": "Déjà déclinée."}, status=400)

        reservation.statut = 'declinee'
        reservation.save()

        return Response({"message": "Réservation déclinée."})
    
    @action(detail=True, methods=['post'])
    def annuler(self, request, pk=None):
        # CORRECTION IDOR : Filtrage direct par passager
        try:
            reservation = Reservation.objects.select_related('trajet').get(pk=pk, passager=request.user)
        except Reservation.DoesNotExist:
            raise PermissionDenied("Réservation introuvable ou accès non autorisé.")
 
        if reservation.statut != 'en_attente':
            return Response(
                {"error": "Seules les réservations en attente peuvent être annulées."},
                status=400
            )
 
        reservation.delete()
        return Response({"message": "Réservation annulée avec succès."})
    
    @action(detail=False, methods=['get'])
    def historique(self, request):
        reservations = Reservation.objects.filter(
            passager=request.user
        ).select_related(
            'trajet', 'trajet__conducteur', 'passager', 'paiement'
        ).order_by('-date_reservation')[:100]

        serializer = ReservationSerializer(reservations, many=True)
        return Response(serializer.data)