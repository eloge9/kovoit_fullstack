from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.utils import timezone
from ..modeles.models import Trajet
from .serializers import TrajetSerializer, TrajetCreateSerializer


class TrajetViewSet(viewsets.ModelViewSet):
    queryset = Trajet.objects.all()

    def get_permissions(self):
        if self.action in ['list', 'retrieve', 'rechercher']:
            return [AllowAny()]
        return [IsAuthenticated()]

    def get_serializer_class(self):
        if self.action in ['create', 'update', 'partial_update']:
            return TrajetCreateSerializer
        return TrajetSerializer

    def get_queryset(self):
        # Pour l'action list, retourner les trajets du conducteur connecté (pour /conducteur/trajets)
        if self.action == 'list':
            if hasattr(self.request, 'user') and self.request.user.is_authenticated:
                return Trajet.objects.filter(conducteur=self.request.user).select_related('conducteur')
            else:
                return Trajet.objects.none()
        # Pour l'action retrieve, autoriser l'accès public aux trajets ouverts
        elif self.action == 'retrieve':
            return Trajet.objects.filter(statut='ouvert').select_related('conducteur')
        # Pour les autres actions (create, update, etc), filtrer uniquement les trajets ouverts
        return Trajet.objects.filter(statut='ouvert').select_related('conducteur')

    def list(self, request):
        queryset = self.get_queryset().filter(
            date_heure_depart__gte=timezone.now()
        )
        serializer = TrajetSerializer(queryset, many=True)
        return Response(serializer.data)

    def create(self, request):
        if request.user.role != 'conducteur':
            return Response(
                {"error": "Seuls les conducteurs peuvent proposer des trajets."},
                status=status.HTTP_403_FORBIDDEN
            )
        serializer = TrajetCreateSerializer(
            data=request.data,
            context={'request': request}
        )
        if serializer.is_valid():
            trajet = serializer.save()
            return Response(
                TrajetSerializer(trajet).data,
                status=status.HTTP_201_CREATED
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=False, methods=['get'], permission_classes=[IsAuthenticated])
    def mes_trajets(self, request):
        trajets = Trajet.objects.filter(
            conducteur=request.user
        ).order_by('-date_heure_depart')
        serializer = TrajetSerializer(trajets, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
    def commencer(self, request, pk=None):
        trajet = self.get_object()
        if trajet.conducteur != request.user:
            return Response(
                {"error": "Vous n'êtes pas le conducteur de ce trajet."},
                status=status.HTTP_403_FORBIDDEN
            )
        if trajet.statut != 'ouvert':
            return Response({"error": "Seuls les trajets ouverts peuvent être commencés."}, status=400)
        trajet.statut = 'en_cours'
        trajet.save()
        return Response({"message": "Trajet commencé avec succès."})

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
    def terminer(self, request, pk=None):
        trajet = self.get_object()
        if trajet.conducteur != request.user:
            return Response(
                {"error": "Vous n'êtes pas le conducteur de ce trajet."},
                status=status.HTTP_403_FORBIDDEN
            )
        if trajet.statut != 'en_cours':
            return Response({"error": "Seuls les trajets en cours peuvent être terminés."}, status=400)
        
        # Mettre le trajet à terminé
        trajet.statut = 'termine'
        trajet.save()
        
        # Mettre toutes les réservations confirmées à "terminee"
        reservations_confirmees = trajet.reservations.filter(statut='confirmee')
        reservations_confirmees.update(statut='terminee')
        
        return Response({
            "message": "Trajet terminé avec succès.",
            "reservations_terminees": reservations_confirmees.count()
        })

    @action(detail=True, methods=['post'], permission_classes=[IsAuthenticated])
    def annuler(self, request, pk=None):
        trajet = self.get_object()
        if trajet.conducteur != request.user:
            return Response(
                {"error": "Vous n'êtes pas le conducteur de ce trajet."},
                status=status.HTTP_403_FORBIDDEN
            )
        if trajet.statut == 'annule':
            return Response({"error": "Ce trajet est déjà annulé."}, status=400)
        trajet.statut = 'annule'
        trajet.save()
        return Response({"message": "Trajet annulé avec succès."})

    @action(detail=False, methods=['get'])
    def rechercher(self, request):
        queryset = Trajet.objects.filter(
            statut='ouvert',
        ).select_related('conducteur', 'conducteur__profil_conducteur')

        depart        = request.query_params.get('depart')
        destination   = request.query_params.get('destination')
        date          = request.query_params.get('date')
        places        = request.query_params.get('places')
        type_vehicule = request.query_params.get('type_vehicule')

        if depart:
            queryset = queryset.filter(depart__icontains=depart)
        if destination:
            queryset = queryset.filter(destination__icontains=destination)
        if date:
            queryset = queryset.filter(date_heure_depart__date=date)
        if places:
            queryset = queryset.filter(places_disponibles__gte=int(places))
        if type_vehicule:
            queryset = queryset.filter(
                conducteur__profil_conducteur__type_vehicule__icontains=type_vehicule
            )

        serializer = TrajetSerializer(queryset, many=True)
        return Response(serializer.data)