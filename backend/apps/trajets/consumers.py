import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from ..modeles.models import Trajet

# NOTE ARCHITECTURE : Ce cache en mémoire est vulnérable aux pertes de données 
# et ne scale pas. Pour la production, migrez vers un Channel Layer Redis.
_derniere_position: dict = {}


class GpsConsumer(AsyncWebsocketConsumer):
    """
    Consumer WebSocket pour le suivi GPS en temps réel.
    SÉCURISÉ : Vérifie l'authentification et que l'utilisateur est bien le conducteur du trajet.
    """

    @database_sync_to_async
    def _verifier_conducteur(self, user, trajet_id):
        """Vérifie de manière asynchrone si l'utilisateur est authentifié et conducteur du trajet."""
        if not user or not user.is_authenticated:
            return False
        try:
            trajet = Trajet.objects.get(pk=trajet_id)
            return trajet.conducteur == user
        except Trajet.DoesNotExist:
            return False

    async def connect(self):
        self.trajet_id = self.scope['url_route']['kwargs'].get('trajet_id')
        self.user = self.scope.get("user")

        # 1. Vérification stricte : Authentification + Rôle Conducteur + Existence du trajet
        is_conducteur = await self._verifier_conducteur(self.user, self.trajet_id)
        if not is_conducteur:
            await self.close(code=4003)  # 4003 = Forbidden / Non autorisé
            return

        self.room = f"trajet_{self.trajet_id}"

        # Rejoindre la room
        await self.channel_layer.group_add(self.room, self.channel_name)
        await self.accept()

        # Envoyer la dernière position connue au nouvel abonné (ex: un passager qui se connecte)
        if self.trajet_id in _derniere_position:
            await self.send(text_data=json.dumps({
                'type': 'position_update',
                **_derniere_position[self.trajet_id],
            }))

    async def disconnect(self, close_code):
        if hasattr(self, 'room'):
            await self.channel_layer.group_discard(self.room, self.channel_name)

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            return

        if data.get('type') != 'position':
            return

        lat = data.get('latitude')
        lng = data.get('longitude')
        
        # Validation stricte pour éviter les injections ou crashs (TypeError)
        if lat is None or lng is None:
            return

        try:
            lat = float(lat)
            lng = float(lng)
        except (ValueError, TypeError):
            return

        payload = {
            'type': 'position_update',
            'latitude': lat,
            'longitude': lng,
            'vitesse_kmh': data.get('vitesse_kmh'),
            'direction': data.get('direction'),
            'timestamp': data.get('timestamp'),
        }

        # Mettre à jour le cache
        _derniere_position[self.trajet_id] = payload

        # Diffuser à tous les membres de la room
        await self.channel_layer.group_send(self.room, payload)

    async def position_update(self, event):
        await self.send(text_data=json.dumps(event))