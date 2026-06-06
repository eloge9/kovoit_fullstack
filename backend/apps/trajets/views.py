import logging
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.utils import timezone
from django.db.models import Q
from ..modeles.models import Trajet
from .serializers import TrajetSerializer, TrajetCreateSerializer

logger = logging.getLogger(__name__)

# Cache GPS partagé avec le consumer WebSocket
# Importé ici pour éviter l'import dans le corps de la classe
try:
    from .consumers import _derniere_position as _gps_cache
except ImportError:
    # Fallback si Django Channels n'est pas installé
    _gps_cache: dict = {}


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
        # et aux conducteurs pour voir leurs propres trajets (quel que soit le statut)
        elif self.action == 'retrieve':
            if hasattr(self.request, 'user') and self.request.user.is_authenticated:
                # Le conducteur peut voir tous ses trajets
                return Trajet.objects.filter(
                    Q(conducteur=self.request.user) | Q(statut='ouvert')
                ).select_related('conducteur')
            else:
                # Les utilisateurs non connectés ne voient que les trajets ouverts
                return Trajet.objects.filter(statut='ouvert').select_related('conducteur')
        # Pour les actions commencer et terminer, autoriser l'accès aux trajets du conducteur
        elif self.action in ['commencer', 'terminer', 'annuler']:
            if hasattr(self.request, 'user') and self.request.user.is_authenticated:
                return Trajet.objects.filter(conducteur=self.request.user).select_related('conducteur')
            else:
                return Trajet.objects.none()
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
        try:
            trajet = self.get_object()
            
            # Vérifications
            if trajet.conducteur != request.user:
                return Response(
                    {"error": "Vous n'êtes pas le conducteur de ce trajet."},
                    status=status.HTTP_403_FORBIDDEN
                )
            
            if trajet.statut != 'en_cours':
                return Response({
                    "error": f"Impossible de terminer le trajet: statut actuel='{trajet.statut}'. Seuls les trajets en cours peuvent être terminés."
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Mettre le trajet à terminé
            ancien_statut = trajet.statut
            trajet.statut = 'termine'
            trajet.save()
            
            # Mettre toutes les réservations confirmées à "terminee"
            reservations_confirmees = trajet.reservations.filter(statut='confirmee')
            count_reservations = reservations_confirmees.count()
            reservations_confirmees.update(statut='terminee')
            
            return Response({
                "message": "Trajet terminé avec succès.",
                "reservations_terminees": count_reservations,
                "ancien_statut": ancien_statut
            })
            
        except Exception as e:
            logger.error("Erreur lors de la terminaison du trajet %s: %s", pk, str(e))
            
            return Response({
                "error": f"Erreur serveur lors de la terminaison du trajet: {str(e)}"
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

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

    # ── Aliases utilisés par trajet-api.ts (frontend) ─────────────────────

    @action(detail=True, methods=['post'], url_path='commencer_trajet', permission_classes=[IsAuthenticated])
    def commencer_trajet(self, request, pk=None):
        """Démarre un trajet et retourne l'objet trajet mis à jour."""
        try:
            trajet = Trajet.objects.get(pk=pk)
        except Trajet.DoesNotExist:
            return Response({"error": "Trajet introuvable."}, status=404)

        if trajet.conducteur != request.user:
            return Response({"error": "Non autorisé."}, status=403)
        if trajet.statut != 'ouvert':
            return Response({"error": "Seuls les trajets ouverts peuvent être commencés."}, status=400)

        trajet.statut = 'en_cours'
        trajet.save()
        return Response({
            "message": "Trajet commencé avec succès.",
            "trajet": TrajetSerializer(trajet).data,
        })

    @action(detail=True, methods=['post'], url_path='terminer_trajet', permission_classes=[IsAuthenticated])
    def terminer_trajet(self, request, pk=None):
        """Termine un trajet et retourne l'objet trajet mis à jour."""
        try:
            trajet = Trajet.objects.get(pk=pk)
        except Trajet.DoesNotExist:
            return Response({"error": "Trajet introuvable."}, status=404)

        if trajet.conducteur != request.user:
            return Response({"error": "Non autorisé."}, status=403)
        if trajet.statut != 'en_cours':
            return Response({"error": "Seuls les trajets en cours peuvent être terminés."}, status=400)

        trajet.statut = 'termine'
        trajet.save()
        trajet.reservations.filter(statut='confirmee').update(statut='terminee')
        return Response({
            "message": "Trajet terminé avec succès.",
            "trajet": TrajetSerializer(trajet).data,
        })

    # ── GPS REST (fallback si WebSocket indisponible) ──────────────────────

    @action(detail=True, methods=['post'], url_path='mettre_a_jour_position', permission_classes=[IsAuthenticated])
    def mettre_a_jour_position(self, request, pk=None):
        """Le conducteur pousse sa position GPS (fallback REST)."""
        try:
            trajet = Trajet.objects.get(pk=pk)
        except Trajet.DoesNotExist:
            return Response({"error": "Trajet introuvable."}, status=404)

        if trajet.conducteur != request.user:
            return Response({"error": "Non autorisé."}, status=403)
        if trajet.statut != 'en_cours':
            return Response({"error": "Le trajet n'est pas en cours."}, status=400)

        lat = request.data.get('latitude')
        lng = request.data.get('longitude')
        if lat is None or lng is None:
            return Response({"error": "latitude et longitude requis."}, status=400)

        _gps_cache[str(pk)] = {
            'type':        'position_update',
            'latitude':    float(lat),
            'longitude':   float(lng),
            'vitesse_kmh': request.data.get('vitesse_kmh'),
            'direction':   request.data.get('direction'),
            'timestamp':   timezone.now().isoformat(),
        }
        return Response({"message": "Position mise à jour.", **_gps_cache[str(pk)]})

    @action(detail=True, methods=['get'], url_path='position_actuelle', permission_classes=[IsAuthenticated])
    def position_actuelle(self, request, pk=None):
        """Retourne la dernière position GPS connue (passager + conducteur)."""
        try:
            trajet = Trajet.objects.get(pk=pk)
        except Trajet.DoesNotExist:
            return Response({"error": "Trajet introuvable."}, status=404)

        if trajet.statut != 'en_cours':
            return Response({"error": "Le trajet n'est pas en cours."}, status=400)

        pos = _gps_cache.get(str(pk))
        if not pos:
            return Response({"error": "Aucune position GPS disponible pour l'instant."}, status=404)

        return Response(pos)

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