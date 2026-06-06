import json
import logging

from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser
from django.utils import timezone

logger = logging.getLogger(__name__)

# Codes WebSocket personnalisés (cohérent avec trajets/consumers.py)
WS_FORBIDDEN   = 4003
WS_BAD_REQUEST = 4400


class ChatConsumer(AsyncWebsocketConsumer):
    """
    WebSocket de messagerie pair-à-pair.

    Room déterministe : chat_{min(u1,u2)}_{max(u1,u2)}
    Peu importe qui initie, les deux utilisateurs rejoignent la même room.

    Messages supportés (client → serveur) :
        { "type": "message",  "contenu": "..." }
        { "type": "typing" }
        { "type": "lu" }

    Messages envoyés (serveur → client) :
        { "type": "message",  "id", "contenu", "expediteur_id", "username", "timestamp" }
        { "type": "typing",   "user_id", "username" }
    """

    # ── Helpers DB ────────────────────────────────────────────────────────

    @database_sync_to_async
    def _sauvegarder_message(self, expediteur, destinataire_id: str, contenu: str):
        from apps.modeles.models import Message, Utilisateur
        try:
            destinataire = Utilisateur.objects.get(pk=destinataire_id)
        except Utilisateur.DoesNotExist:
            return None
        msg = Message.objects.create(
            expediteur=expediteur,
            destinataire=destinataire,
            contenu=contenu,
        )
        return msg

    @database_sync_to_async
    def _marquer_lu(self, destinataire_id: str, expediteur_id: str):
        from apps.modeles.models import Message
        Message.objects.filter(
            destinataire_id=destinataire_id,
            expediteur_id=expediteur_id,
            lu=False,
        ).update(lu=True)

    # ── Cycle de vie WebSocket ────────────────────────────────────────────

    async def connect(self):
        self.user = self.scope.get("user")

        if not self.user or isinstance(self.user, AnonymousUser) or not self.user.is_authenticated:
            await self.close(code=WS_FORBIDDEN)
            return

        other_id    = self.scope["url_route"]["kwargs"].get("user_id", "")
        u1, u2      = sorted([str(self.user.id), str(other_id)])
        self.room     = f"chat_{u1}_{u2}"
        self.other_id = other_id

        await self.channel_layer.group_add(self.room, self.channel_name)
        await self.accept()
        logger.debug("ChatConsumer connecté : %s → room %s", self.user.username, self.room)

    async def disconnect(self, close_code):
        if hasattr(self, "room"):
            await self.channel_layer.group_discard(self.room, self.channel_name)

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            await self.close(code=WS_BAD_REQUEST)
            return

        msg_type = data.get("type")

        if msg_type == "typing":
            await self.channel_layer.group_send(self.room, {
                "type":     "typing",
                "user_id":  str(self.user.id),
                "username": self.user.username,
            })

        elif msg_type == "message":
            contenu = str(data.get("contenu", "")).strip()
            if not contenu:
                return

            message = await self._sauvegarder_message(self.user, self.other_id, contenu)
            if message is None:
                return

            await self.channel_layer.group_send(self.room, {
                "type":          "message",
                "id":            message.id,
                "contenu":       message.contenu,
                "expediteur_id": str(self.user.id),
                "username":      self.user.username,
                "timestamp":     message.created_at.isoformat(),
            })

        elif msg_type == "lu":
            await self._marquer_lu(str(self.user.id), self.other_id)

    # Handlers appelés par group_send
    async def message(self, event):
        await self.send(text_data=json.dumps(event))

    async def typing(self, event):
        await self.send(text_data=json.dumps(event))


class NotificationConsumer(AsyncWebsocketConsumer):
    """
    Canal WebSocket dédié aux notifications temps réel de l'utilisateur connecté.
    Room : notif_{user_id}

    Lecture seule côté client — le serveur envoie via envoyer_notification().
    Appeler : from apps.modeles.notifs import envoyer_notification
    """

    async def connect(self):
        self.user = self.scope.get("user")

        if not self.user or isinstance(self.user, AnonymousUser) or not self.user.is_authenticated:
            await self.close(code=WS_FORBIDDEN)
            return

        self.room = f"notif_{self.user.id}"
        await self.channel_layer.group_add(self.room, self.channel_name)
        await self.accept()
        logger.debug("NotificationConsumer connecté : %s", self.user.username)

    async def disconnect(self, close_code):
        if hasattr(self, "room"):
            await self.channel_layer.group_discard(self.room, self.channel_name)

    async def receive(self, text_data):
        # Connexion en lecture seule — le client n'envoie rien
        pass

    async def notification(self, event):
        await self.send(text_data=json.dumps({
            "type":      event["notif_type"],
            "data":      event.get("data", {}),
            "timestamp": timezone.now().isoformat(),
        }))
