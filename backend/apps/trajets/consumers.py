import json

from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser

# Cache en mémoire de la dernière position connue par trajet.
# Limitation : non partagé entre workers. Phase 2 : migrer vers Redis cache.
_derniere_position: dict = {}

# Codes WebSocket personnalisés (4000-4999 = codes applicatifs)
WS_FORBIDDEN   = 4003
WS_BAD_REQUEST = 4400


class GpsConsumer(AsyncWebsocketConsumer):
    """
    WebSocket de suivi GPS temps réel.

    Conducteur  → seul à pouvoir envoyer des positions (receive).
    Passager    → lecture seule ; doit avoir une réservation confirmée sur le trajet.
    Condition   → le trajet doit être au statut 'en_cours'.
    """

    # ------------------------------------------------------------------
    # Helpers DB (exécutés en thread via database_sync_to_async)
    # ------------------------------------------------------------------

    @database_sync_to_async
    def _verifier_acces(self, user, trajet_id: str):
        """
        Retourne ('conducteur', trajet) ou ('passager', trajet) selon le rôle,
        (None, None) si l'accès est refusé.
        """
        from apps.modeles.models import Trajet, Reservation

        if not user or isinstance(user, AnonymousUser) or not user.is_authenticated:
            return None, None

        try:
            trajet = Trajet.objects.select_related("conducteur").get(pk=trajet_id)
        except (Trajet.DoesNotExist, ValueError):
            return None, None

        if trajet.statut != "en_cours":
            return None, None

        if trajet.conducteur_id == user.pk:
            return "conducteur", trajet

        est_passager = Reservation.objects.filter(
            trajet=trajet,
            passager=user,
            statut="confirmee",
        ).exists()

        if est_passager:
            return "passager", trajet

        return None, None

    # ------------------------------------------------------------------
    # Validation GPS statique
    # ------------------------------------------------------------------

    @staticmethod
    def _coords_valides(lat, lng) -> tuple[float, float] | None:
        try:
            lat, lng = float(lat), float(lng)
        except (TypeError, ValueError):
            return None
        if not (-90 <= lat <= 90) or not (-180 <= lng <= 180):
            return None
        return lat, lng

    # ------------------------------------------------------------------
    # Cycle de vie WebSocket
    # ------------------------------------------------------------------

    async def connect(self):
        self.trajet_id = self.scope["url_route"]["kwargs"].get("trajet_id")
        self.user      = self.scope.get("user")
        self.role_ws   = None  # 'conducteur' | 'passager'

        role, _trajet = await self._verifier_acces(self.user, self.trajet_id)
        if role is None:
            await self.close(code=WS_FORBIDDEN)
            return

        self.role_ws = role
        self.room    = f"trajet_{self.trajet_id}"

        await self.channel_layer.group_add(self.room, self.channel_name)
        await self.accept()

        # Envoyer la dernière position connue immédiatement au passager qui rejoint
        if self.trajet_id in _derniere_position:
            await self.send(text_data=json.dumps(_derniere_position[self.trajet_id]))

    async def disconnect(self, close_code):
        if hasattr(self, "room"):
            await self.channel_layer.group_discard(self.room, self.channel_name)

    async def receive(self, text_data):
        # Seul le conducteur est autorisé à envoyer des positions
        if self.role_ws != "conducteur":
            return

        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            await self.close(code=WS_BAD_REQUEST)
            return

        if data.get("type") != "position":
            return

        coords = self._coords_valides(data.get("latitude"), data.get("longitude"))
        if coords is None:
            return
        lat, lng = coords

        vitesse = None
        if data.get("vitesse_kmh") is not None:
            try:
                v = float(data["vitesse_kmh"])
                vitesse = v if v >= 0 else None
            except (TypeError, ValueError):
                pass

        payload = {
            "type":        "position_update",
            "latitude":    lat,
            "longitude":   lng,
            "vitesse_kmh": vitesse,
            "timestamp":   data.get("timestamp"),
        }

        _derniere_position[self.trajet_id] = payload
        await self.channel_layer.group_send(self.room, payload)

    # Appelé par group_send sur chaque membre de la room
    async def position_update(self, event):
        await self.send(text_data=json.dumps(event))
