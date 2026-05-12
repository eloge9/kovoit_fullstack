from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework.exceptions import NotFound
from ..modeles.models import Reservation, Trajet
from .serializers import ReservationSerializer, ReservationCreateSerializer


class ReservationViewSet(viewsets.GenericViewSet):
    permission_classes = [IsAuthenticated]

    def get_object(self):
        """Récupérer une réservation spécifique"""
        pk = self.kwargs.get('pk')
        try:
            return Reservation.objects.select_related('trajet', 'trajet__conducteur', 'passager').get(pk=pk)
        except Reservation.DoesNotExist:
            raise NotFound("Réservation introuvable.")

    def retrieve(self, request, pk=None):
        """Récupérer les détails d'une réservation"""
        reservation = self.get_object()
        
        # Vérifier que l'utilisateur est bien le passager ou le conducteur
        if reservation.passager != request.user and reservation.trajet.conducteur != request.user:
            return Response({"error": "Accès non autorisé."}, status=403)
        
        serializer = ReservationSerializer(reservation)
        return Response(serializer.data)

    @action(detail=False, methods=['post'])
    def reserver(self, request):
        serializer = ReservationCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        trajet_id = serializer.validated_data['trajet_id']

        try:
            trajet = Trajet.objects.get(pk=trajet_id, statut='ouvert')
        except Trajet.DoesNotExist:
            return Response({"error": "Trajet introuvable ou non disponible."}, status=404)

        if trajet.conducteur == request.user:
            return Response({"error": "Vous ne pouvez pas réserver votre propre trajet."}, status=400)

        if Reservation.objects.filter(trajet=trajet, passager=request.user).exists():
            return Response({"error": "Vous avez déjà réservé ce trajet."}, status=400)

        nb_confirmees = trajet.reservations.filter(statut='confirmee').count()
        if nb_confirmees >= trajet.places_disponibles:
            return Response({"error": "Plus de places disponibles."}, status=400)

        reservation = Reservation.objects.create(
            trajet=trajet, passager=request.user, statut='en_attente'
        )

        return Response({
            "message": "Réservation envoyée. En attente de confirmation.",
            "reservation_id": reservation.id,
            "prix_prevu": str(trajet.prix_par_place),
        }, status=201)

    @action(detail=False, methods=['get'])
    def mes_reservations(self, request):
        reservations = Reservation.objects.filter(
            passager=request.user
        ).select_related('trajet', 'trajet__conducteur', 'passager').order_by('-date_reservation')
        return Response(ReservationSerializer(reservations, many=True).data)

    @action(detail=False, methods=['get'])
    def recues(self, request):
        reservations = Reservation.objects.filter(
            trajet__conducteur=request.user
        ).select_related('trajet', 'passager').order_by('-date_reservation')
        return Response(ReservationSerializer(reservations, many=True).data)

    @action(detail=True, methods=['post'])
    def confirmer(self, request, pk=None):
        try:
            reservation = Reservation.objects.select_related('trajet').get(pk=pk)
        except Reservation.DoesNotExist:
            return Response({"error": "Réservation introuvable."}, status=404)

        if reservation.trajet.conducteur != request.user:
            return Response({"error": "Non autorisé."}, status=403)

        if reservation.statut == 'confirmee':
            return Response({"error": "Déjà confirmée."}, status=400)

        reservation.statut = 'confirmee'
        reservation.save()

        # Recalculer le prix si nécessaire
        trajet = reservation.trajet
        nb_passagers = trajet.reservations.filter(statut='confirmee').count()
        if nb_passagers > 0 and trajet.cout_total:
            nouveau_prix = round(float(trajet.cout_total) / nb_passagers)
            trajet.prix_par_place = nouveau_prix
            trajet.save()
        else:
            nouveau_prix = trajet.prix_par_place

        return Response({
            "message": "Réservation confirmée.",
            "nouveau_prix_par_place": nouveau_prix,
            "nb_passagers_confirmes": nb_passagers,
        })

    @action(detail=True, methods=['post'])
    def decliner(self, request, pk=None):
        try:
            reservation = Reservation.objects.select_related('trajet').get(pk=pk)
        except Reservation.DoesNotExist:
            return Response({"error": "Réservation introuvable."}, status=404)

        if reservation.trajet.conducteur != request.user:
            return Response({"error": "Non autorisé."}, status=403)

        if reservation.statut == 'declinee':
            return Response({"error": "Déjà déclinée."}, status=400)

        reservation.statut = 'declinee'
        reservation.save()

        trajet = reservation.trajet
        nb_passagers = trajet.reservations.filter(statut='confirmee').count()
        if nb_passagers > 0 and trajet.cout_total:
            trajet.prix_par_place = round(float(trajet.cout_total) / nb_passagers)
            trajet.save()

        return Response({"message": "Réservation déclinée."})
    
        # ── Passager — annuler sa réservation ────────────────────────────────
    @action(detail=True, methods=['post'])
    def annuler(self, request, pk=None):
        try:
            reservation = Reservation.objects.select_related('trajet').get(pk=pk)
        except Reservation.DoesNotExist:
            return Response({"error": "Réservation introuvable."}, status=404)
 
        # Seul le passager peut annuler sa propre réservation
        if reservation.passager != request.user:
            return Response({"error": "Non autorisé."}, status=403)
 
        # On ne peut annuler que si en attente
        if reservation.statut != 'en_attente':
            return Response(
                {"error": "Seules les réservations en attente peuvent être annulées."},
                status=400
            )
 
        reservation.delete()
 
        return Response({"message": "Réservation annulée avec succès."})
    
    @action(detail=False, methods=['get'])
    def historique(self, request):
        """
        Récupérer l'historique complet des réservations du passager
        Inclut toutes les réservations (confirmées, terminées, annulées, etc.)
        """
        reservations = Reservation.objects.filter(
            passager=request.user
        ).select_related(
            'trajet', 
            'trajet__conducteur', 
            'passager'
        ).prefetch_related(
            'trajet__reservations'
        ).order_by('-date_reservation')
        
        serializer = ReservationSerializer(reservations, many=True)
        return Response(serializer.data)