import logging
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.utils import timezone
from django.db.models import Q
from django.shortcuts import get_object_or_404
from ..modeles.models import Trajet, Reservation, Utilisateur, TripStop
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
                # Le conducteur voit ses propres trajets, et les passagers voient
                # les trajets sur lesquels ils ont une réservation (peu importe le statut)
                return Trajet.objects.filter(
                    Q(conducteur=self.request.user) |
                    Q(statut='ouvert') |
                    Q(reservations__passager=self.request.user)
                ).select_related('conducteur').distinct()
            else:
                # Les utilisateurs non connectés ne voient que les trajets ouverts
                return Trajet.objects.filter(statut='ouvert').select_related('conducteur')
        # Pour les actions commencer et terminer, autoriser l'accès aux trajets du conducteur
        elif self.action in ['commencer', 'terminer', 'annuler']:
            if hasattr(self.request, 'user') and self.request.user.is_authenticated:
                return Trajet.objects.filter(conducteur=self.request.user).select_related('conducteur')
            else:
                return Trajet.objects.none()
        # update / partial_update / destroy : uniquement les trajets du conducteur connecté
        elif self.action in ['update', 'partial_update', 'destroy']:
            if hasattr(self.request, 'user') and self.request.user.is_authenticated:
                return Trajet.objects.filter(conducteur=self.request.user).select_related('conducteur')
            return Trajet.objects.none()
        # create et autres : trajets ouverts uniquement
        return Trajet.objects.filter(statut='ouvert').select_related('conducteur')

    def list(self, request):
        queryset = self.get_queryset().filter(
            date_heure_depart__gte=timezone.now()
        )
        serializer = TrajetSerializer(queryset, many=True)
        return Response(serializer.data)

    def create(self, request):
        if request.user.role != Utilisateur.Role.CONDUCTEUR:
            return Response(
                {"error": "Seuls les conducteurs peuvent proposer des trajets."},
                status=status.HTTP_403_FORBIDDEN
            )
        # Vérifier que le conducteur est validé
        try:
            from apps.verification.models import DriverProfile, DriverStatus
            dp = DriverProfile.objects.get(user=request.user)
            if dp.status != DriverStatus.ACTIVE:
                return Response(
                    {
                        "error": "Votre compte conducteur n'est pas encore activé.",
                        "driver_status": dp.status,
                        "redirect": "/conducteur/verification",
                    },
                    status=status.HTTP_403_FORBIDDEN
                )
        except Exception:
            pass  # Si le module vérification n'est pas utilisé, autoriser quand même
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

    @action(detail=False, methods=['get'], url_path='calculer-prix', permission_classes=[IsAuthenticated])
    def calculer_prix_action(self, request):
        """
        Prévisualisation du prix pour un trajet avant création.
        GET /api/trajets/calculer-prix/?vehicule_id=X&distance_km=Y
        """
        from .tarification import calculer_prix, capacite_vehicule, type_vehicule_str
        from ..modeles.models import Vehicule as VehiculeModel

        vehicule_id = request.query_params.get('vehicule_id')
        distance_km = request.query_params.get('distance_km')

        if not vehicule_id or not distance_km:
            return Response({'error': 'vehicule_id et distance_km requis.'}, status=400)

        try:
            vehicule = VehiculeModel.objects.get(pk=vehicule_id)
        except VehiculeModel.DoesNotExist:
            return Response({'error': 'Véhicule introuvable.'}, status=404)

        try:
            distance = float(distance_km)
            if distance <= 0:
                return Response({'error': 'distance_km doit être supérieure à 0.'}, status=400)
        except (TypeError, ValueError):
            return Response({'error': 'distance_km invalide.'}, status=400)

        tarif = calculer_prix(distance, type_vehicule_str(vehicule), capacite_vehicule(vehicule))
        return Response(tarif)

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
        return Response({
            "message": "Trajet commencé avec succès.",
            "trajet": TrajetSerializer(trajet).data,
        })

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
                "trajet": TrajetSerializer(trajet).data,
                "reservations_terminees": count_reservations,
            })
            
        except Exception as e:
            logger.error("Erreur lors de la terminaison du trajet %s: %s", pk, str(e), exc_info=True)
            return Response(
                {"error": "Erreur serveur. Veuillez réessayer."},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

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
        # get_object_or_404 avec filtre conducteur : même 404 si inexistant ou non propriétaire
        trajet = get_object_or_404(Trajet, pk=pk, conducteur=request.user)
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
        trajet = get_object_or_404(Trajet, pk=pk, conducteur=request.user)
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
        trajet = get_object_or_404(Trajet, pk=pk, conducteur=request.user)
        if trajet.statut != 'en_cours':
            return Response({"error": "Le trajet n'est pas en cours."}, status=400)

        lat = request.data.get('latitude')
        lng = request.data.get('longitude')
        if lat is None or lng is None:
            return Response({"error": "latitude et longitude requis."}, status=400)

        try:
            lat, lng = float(lat), float(lng)
        except (TypeError, ValueError):
            return Response({"error": "latitude et longitude doivent être des nombres."}, status=400)

        if not (-90 <= lat <= 90) or not (-180 <= lng <= 180):
            return Response({"error": "Coordonnées GPS hors limites."}, status=400)

        _gps_cache[str(pk)] = {
            'type':        'position_update',
            'latitude':    lat,
            'longitude':   lng,
            'vitesse_kmh': request.data.get('vitesse_kmh'),
            'direction':   request.data.get('direction'),
            'timestamp':   timezone.now().isoformat(),
        }
        return Response({"message": "Position mise à jour.", **_gps_cache[str(pk)]})

    @action(detail=True, methods=['get'], url_path='position_actuelle', permission_classes=[IsAuthenticated])
    def position_actuelle(self, request, pk=None):
        """Retourne la dernière position GPS connue (passager + conducteur)."""
        trajet = get_object_or_404(Trajet, pk=pk)

        if trajet.statut != 'en_cours':
            return Response({"error": "Le trajet n'est pas en cours."}, status=400)

        # Seuls le conducteur et les passagers confirmés peuvent consulter la position
        est_conducteur = trajet.conducteur == request.user
        est_passager = (
            not est_conducteur and
            Reservation.objects.filter(
                trajet=trajet, passager=request.user, statut='confirmee'
            ).exists()
        )
        if not est_conducteur and not est_passager:
            return Response({"error": "Accès non autorisé."}, status=403)

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
            try:
                queryset = queryset.filter(places_disponibles__gte=int(places))
            except (ValueError, TypeError):
                return Response({"error": "Le paramètre 'places' doit être un entier."}, status=400)
        if type_vehicule:
            queryset = queryset.filter(
                vehicule__type_vehicule__icontains=type_vehicule
            ).distinct()

        serializer = TrajetSerializer(queryset, many=True)
        return Response(serializer.data)

    # ── Itinéraire OSRM (principal + alternatifs) ─────────────────────────
    @action(detail=True, methods=['get'], url_path='itineraire', permission_classes=[AllowAny])
    def itineraire(self, request, pk=None):
        """
        Retourne les itinéraires d'un trajet via OSRM (gratuit, sans clé).
        GET /api/trajets/{id}/itineraire/?alternatives=true
        """
        trajet = get_object_or_404(Trajet, pk=pk)

        if not all([trajet.depart_lat, trajet.depart_lng,
                    trajet.destination_lat, trajet.destination_lng]):
            return Response({"error": "Coordonnées GPS manquantes pour ce trajet."}, status=400)

        alternatives = request.query_params.get('alternatives', 'false').lower() == 'true'
        coords = (
            f"{trajet.depart_lng},{trajet.depart_lat};"
            f"{trajet.destination_lng},{trajet.destination_lat}"
        )
        url = (
            f"http://router.project-osrm.org/route/v1/driving/{coords}"
            f"?overview=full&geometries=geojson&steps=true"
            f"&alternatives={'true' if alternatives else 'false'}"
        )

        try:
            resp = requests.get(url, timeout=10, headers={"User-Agent": "KoVoit-App/1.0"})
            data = resp.json()
        except Exception:
            return Response({"error": "Service de routage temporairement indisponible."}, status=503)

        if data.get('code') != 'Ok' or not data.get('routes'):
            return Response({"error": "Aucun itinéraire trouvé."}, status=404)

        routes = []
        for route in data['routes']:
            steps = [
                {
                    'instruction': step.get('maneuver', {}).get('type', ''),
                    'distance_m':  round(step.get('distance', 0)),
                    'duree_s':     round(step.get('duration', 0)),
                    'nom_rue':     step.get('name', ''),
                }
                for leg in route.get('legs', [])
                for step in leg.get('steps', [])
                if step.get('distance', 0) > 50
            ]
            routes.append({
                'distance_km': round(route['distance'] / 1000, 1),
                'duree_min':   round(route['duration'] / 60),
                'geometry':    route['geometry'],
                'steps':       steps,
            })

        return Response({
            'trajet_id':   str(pk),
            'depart':      trajet.depart,
            'destination': trajet.destination,
            'routes':      routes,
        })

    # ── Alertes routes (Overpass API) ─────────────────────────────────────
    @action(detail=False, methods=['get'], url_path='alertes-routes', permission_classes=[AllowAny])
    def alertes_routes(self, request):
        """
        Routes bloquées, inondables ou impraticables à Lomé via Overpass API.
        GET /api/trajets/alertes-routes/?type=bloquee|inondable|impraticable
        """
        type_filtre = request.query_params.get('type', '')

        overpass_query = """
[out:json][timeout:25];
(
  way["access"="no"](6.0,1.0,6.5,1.5);
  way["flood_prone"="yes"](6.0,1.0,6.5,1.5);
  way["surface"~"unpaved|dirt|gravel"]["highway"~"primary|secondary|tertiary"](6.0,1.0,6.5,1.5);
  way["construction"]["highway"](6.0,1.0,6.5,1.5);
);
out geom;
"""
        try:
            resp = requests.post(
                "https://overpass-api.de/api/interpreter",
                data={"data": overpass_query},
                timeout=20,
                headers={"User-Agent": "KoVoit-App/1.0"},
            )
            elements = resp.json().get('elements', [])
        except Exception:
            return Response({'type': 'FeatureCollection', 'features': [], 'source': 'overpass_indisponible'})

        features = []
        for el in elements:
            if el.get('type') != 'way' or not el.get('geometry'):
                continue
            tags   = el.get('tags', {})
            coords = [[p['lon'], p['lat']] for p in el['geometry']]

            if tags.get('access') == 'no' or tags.get('construction'):
                type_alerte = 'bloquee'
            elif tags.get('flood_prone') == 'yes':
                type_alerte = 'inondable'
            else:
                type_alerte = 'impraticable'

            if type_filtre and type_alerte != type_filtre:
                continue

            features.append({
                'type': 'Feature',
                'geometry': {'type': 'LineString', 'coordinates': coords},
                'properties': {'type_alerte': type_alerte, 'nom': tags.get('name', 'Route'), 'ref': tags.get('ref', '')},
            })

        return Response({'type': 'FeatureCollection', 'features': features, 'count': len(features)})

    # ── Autocomplétion villes togolaises (Nominatim) ──────────────────────
    @action(detail=False, methods=['get'], url_path='autocomplete', permission_classes=[AllowAny])
    def autocomplete(self, request):
        """
        Suggestions de villes/lieux au Togo via Nominatim (sans clé API).
        GET /api/trajets/autocomplete/?q=Lomé
        """
        q = request.query_params.get('q', '').strip()
        if len(q) < 2:
            return Response([])

        try:
            resp = requests.get(
                "https://nominatim.openstreetmap.org/search",
                params={"q": q, "countrycodes": "tg", "format": "json", "limit": 6, "addressdetails": 1},
                headers={"User-Agent": "KoVoit-App/1.0", "Accept-Language": "fr"},
                timeout=5,
            )
            results = resp.json()
        except Exception:
            return Response([])

        return Response([
            {'nom': r.get('display_name', '').split(',')[0].strip(), 'display': r.get('display_name', ''), 'lat': float(r['lat']), 'lng': float(r['lon'])}
            for r in results if r.get('lat') and r.get('lon')
        ])

    # ── Escales (TripStop) ────────────────────────────────────────────────────

    @action(detail=True, methods=['get', 'post'], url_path='escales', permission_classes=[IsAuthenticated])
    def escales(self, request, pk=None):
        """
        GET  /api/trajets/{id}/escales/  → liste les escales
        POST /api/trajets/{id}/escales/  → ajoute une escale
        """
        trajet = get_object_or_404(Trajet, pk=pk)

        if request.method == 'GET':
            stops = trajet.escales.all()
            return Response([{
                'id': s.id, 'nom': s.nom, 'lat': s.lat, 'lng': s.lng,
                'ordre': s.ordre, 'heure_prevue': s.heure_prevue,
                'heure_reelle': s.heure_reelle, 'statut': s.statut,
            } for s in stops])

        # POST — seul le conducteur peut ajouter des escales
        if trajet.conducteur != request.user:
            return Response({"error": "Action réservée au conducteur."}, status=403)

        data = request.data
        try:
            lat = float(data.get('lat', 0))
            lng = float(data.get('lng', 0))
        except (TypeError, ValueError):
            return Response({"error": "lat/lng invalides."}, status=400)
        if not (-90 <= lat <= 90) or not (-180 <= lng <= 180):
            return Response({"error": "Coordonnées GPS hors limites."}, status=400)
        nom = str(data.get('nom', ''))[:100]
        stop = TripStop.objects.create(
            trajet=trajet,
            nom=nom,
            lat=lat,
            lng=lng,
            ordre=data.get('ordre', trajet.escales.count()),
            heure_prevue=data.get('heure_prevue'),
        )
        return Response({
            'id': stop.id, 'nom': stop.nom, 'lat': stop.lat, 'lng': stop.lng,
            'ordre': stop.ordre, 'statut': stop.statut,
        }, status=201)

    @action(detail=True, methods=['patch', 'delete'], url_path=r'escales/(?P<stop_id>\d+)', permission_classes=[IsAuthenticated])
    def escale_detail(self, request, pk=None, stop_id=None):
        """
        PATCH  /api/trajets/{id}/escales/{stop_id}/  → met à jour statut/heure réelle
        DELETE /api/trajets/{id}/escales/{stop_id}/  → supprime l'escale
        """
        trajet = get_object_or_404(Trajet, pk=pk, conducteur=request.user)
        stop = get_object_or_404(TripStop, pk=stop_id, trajet=trajet)

        if request.method == 'DELETE':
            stop.delete()
            return Response(status=204)

        # PATCH
        for field in ['statut', 'heure_reelle', 'nom', 'heure_prevue']:
            if field in request.data:
                setattr(stop, field, request.data[field])
        stop.save()
        return Response({'id': stop.id, 'statut': stop.statut, 'heure_reelle': stop.heure_reelle})

    # ── Recherche par itinéraire (matching géographique) ─────────────────────

    @action(detail=False, methods=['post'], url_path='rechercher-itineraire', permission_classes=[AllowAny])
    def rechercher_par_itineraire(self, request):
        """
        Recherche de trajets compatibles avec l'itinéraire passager.
        Utilise les polylines OSRM stockées en base (v2 — aucun appel OSRM pendant la recherche).

        Body JSON :
        {
            "pickup_lat": 6.137,  "pickup_lng": 1.212,
            "dropoff_lat": 6.890, "dropoff_lng": 1.102,
            "date": "2026-06-15",       (optionnel)
            "places": 1,                (optionnel, défaut 1)
            "tolerance_km": 2.0,        (optionnel, défaut 2.0 — valeurs: 0.5/1/2/3/5)
            "score_minimum": 50         (optionnel, défaut 50)
        }
        """
        from .matching import rechercher_trajets_compatibles_v2, VALID_TOLERANCES, SHAPELY_AVAILABLE

        pickup_lat  = request.data.get('pickup_lat')
        pickup_lng  = request.data.get('pickup_lng')
        dropoff_lat = request.data.get('dropoff_lat')
        dropoff_lng = request.data.get('dropoff_lng')
        date         = request.data.get('date')
        try:
            places       = max(1, int(request.data.get('places', 1)))
            tolerance_km = float(request.data.get('tolerance_km', 2.0))
            score_min    = int(request.data.get('score_minimum', 50))
        except (TypeError, ValueError):
            return Response({"error": "Paramètres numériques invalides."}, status=400)

        if not all([pickup_lat, pickup_lng, dropoff_lat, dropoff_lng]):
            return Response(
                {"error": "pickup_lat, pickup_lng, dropoff_lat, dropoff_lng requis."},
                status=400,
            )

        # Clamper la tolérance aux valeurs supportées
        tolerance_km = min(VALID_TOLERANCES, key=lambda t: abs(t - tolerance_km))

        qs = Trajet.objects.filter(
            statut='ouvert',
            places_disponibles__gte=places,
        )
        if date:
            qs = qs.filter(date_heure_depart__date=date)
        qs = qs.select_related('conducteur', 'vehicule').prefetch_related('escales')

        resultats = rechercher_trajets_compatibles_v2(
            qs,
            float(pickup_lat), float(pickup_lng),
            float(dropoff_lat), float(dropoff_lng),
            tolerance_km=tolerance_km,
            score_minimum=score_min,
        )

        from .serializers import TrajetSerializer
        data = []
        for r in resultats:
            t = TrajetSerializer(r['trajet']).data
            t['matching'] = {
                'score':                r['score'],
                'distance_passager_km': r['distance_passager_km'],
                'distance_pickup_km':   r.get('distance_pickup_km'),
                'distance_dropoff_km':  r.get('distance_dropoff_km'),
                'detour_km':            r['detour_km'],
                'direction_ok':         r.get('direction_ok', True),
                'prix_passager':        r['prix_passager'],
                'raison':               r['raison'],
            }
            data.append(t)

        return Response({
            'count':        len(data),
            'tolerance_km': tolerance_km,
            'algorithm':    'polyline_shapely' if SHAPELY_AVAILABLE else 'haversine_fallback',
            'resultats':    data,
        })

    @action(detail=True, methods=['post'], url_path='matching-score', permission_classes=[AllowAny])
    def matching_score(self, request, pk=None):
        """
        Calcule le score de compatibilité entre ce trajet et une demande passager.
        Body : { pickup_lat, pickup_lng, dropoff_lat, dropoff_lng }
        """
        from .matching import calculer_score_matching, calculer_prix_passager

        trajet = get_object_or_404(Trajet, pk=pk)
        try:
            pickup_lat  = float(request.data['pickup_lat'])
            pickup_lng  = float(request.data['pickup_lng'])
            dropoff_lat = float(request.data['dropoff_lat'])
            dropoff_lng = float(request.data['dropoff_lng'])
        except (KeyError, TypeError, ValueError):
            return Response({"error": "pickup_lat, pickup_lng, dropoff_lat, dropoff_lng requis."}, status=400)

        match = calculer_score_matching(trajet, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng)

        if match['compatible']:
            prix = calculer_prix_passager(
                match['distance_passager_km'],
                trajet.distance_km or 1,
                float(trajet.cout_total or trajet.prix_par_place),
            )
            match['prix_passager'] = prix

        return Response(match)

    @action(detail=True, methods=['get'], url_path='passagers-embarquement')
    def passagers_embarquement(self, request, pk=None):
        """
        Conducteur : liste complète des passagers confirmés avec leur statut d'embarquement.
        Utilisé par l'app conducteur pour pré-charger les passagers avant qu'ils partagent leur GPS.
        """
        trajet = get_object_or_404(Trajet, pk=pk)
        if trajet.conducteur_id != request.user.pk:
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied("Vous n'êtes pas le conducteur de ce trajet.")

        reservations = (
            Reservation.objects
            .filter(trajet=trajet, statut='confirmee')
            .select_related('passager')
        )

        data = []
        for r in reservations:
            u = r.passager
            # La photo est sur Utilisateur.photo_profil (upload local) ou photo_url (Google OAuth)
            photo = None
            if u.photo_profil:
                photo = request.build_absolute_uri(u.photo_profil.url)
            elif u.photo_url:
                photo = u.photo_url

            data.append({
                'reservation_id':       r.pk,
                'user_id':              str(u.pk),
                'nom':                  u.get_full_name() or u.username,
                'photo_url':            photo,
                'places_reservees':     r.places_reservees,
                'statut_embarquement':  r.statut_embarquement,
                'phone':                getattr(u, 'numero_telephone', None),
                'conversation_id':      r.conversation_id if hasattr(r, 'conversation_id') else None,
            })

        return Response({'passagers': data})