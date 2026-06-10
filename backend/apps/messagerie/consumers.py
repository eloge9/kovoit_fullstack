import json
import logging

from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser
from django.utils import timezone

logger = logging.getLogger(__name__)

WS_FORBIDDEN = 4003
WS_NOT_FOUND = 4404


class ConversationConsumer(AsyncWebsocketConsumer):
    """
    WebSocket de conversation par ID.
    URL  : ws/conv/{conv_id}/?token={jwt}
    Room : conv_{conv_id}

    Client → serveur :
        {"type": "message", "contenu": "..."}
        {"type": "typing"}
        {"type": "lire"}

    Serveur → client :
        {"type": "message",  "id", "conv_id", "contenu", "auteur_id", "username", "timestamp"}
        {"type": "typing",   "user_id", "username"}
        {"type": "lu",       "user_id"}
        {"type": "error",    "reason"}
    """

    @database_sync_to_async
    def _verifier_participant(self, conv_id: int, user):
        from .models import Conversation, Participant
        try:
            conv = Conversation.objects.get(pk=conv_id)
        except Conversation.DoesNotExist:
            return None
        if not Participant.objects.filter(conversation=conv, utilisateur=user).exists():
            return None
        return conv

    @database_sync_to_async
    def _sauvegarder_message(self, conv_id: int, auteur, contenu: str):
        from .models import Conversation, MessageConv
        from django.utils import timezone as tz
        try:
            conv = Conversation.objects.get(pk=conv_id)
        except Conversation.DoesNotExist:
            return None, 'introuvable'
        if conv.statut != Conversation.OUVERTE:
            return None, conv.statut
        msg = MessageConv.objects.create(
            conversation=conv,
            auteur=auteur,
            contenu=contenu,
        )
        Conversation.objects.filter(pk=conv_id).update(updated_at=tz.now())
        return msg, 'ok'

    @database_sync_to_async
    def _marquer_lu(self, conv_id: int, user):
        from .models import Participant
        Participant.objects.filter(
            conversation_id=conv_id,
            utilisateur=user,
        ).update(dernier_lu_at=timezone.now())

    @database_sync_to_async
    def _autres_participants_ids(self, conv_id: int, user):
        from .models import Participant
        return list(
            Participant.objects
            .filter(conversation_id=conv_id)
            .exclude(utilisateur=user)
            .values_list('utilisateur_id', flat=True)
        )

    # ── Cycle de vie ──────────────────────────────────────────────────────────

    async def connect(self):
        self.user = self.scope.get("user")
        if not self.user or isinstance(self.user, AnonymousUser):
            await self.close(code=WS_FORBIDDEN)
            return

        try:
            self.conv_id = int(self.scope["url_route"]["kwargs"]["conv_id"])
        except (KeyError, TypeError, ValueError):
            await self.close(code=WS_NOT_FOUND)
            return

        conv = await self._verifier_participant(self.conv_id, self.user)
        if conv is None:
            await self.close(code=WS_FORBIDDEN)
            return

        self.conv_statut = conv.statut
        self.room = f"conv_{self.conv_id}"
        await self.channel_layer.group_add(self.room, self.channel_name)
        await self.accept()
        await self._marquer_lu(self.conv_id, self.user)
        logger.debug("ConversationConsumer %s → conv %s", self.user.username, self.conv_id)

    async def disconnect(self, close_code):
        if hasattr(self, "room"):
            await self.channel_layer.group_discard(self.room, self.channel_name)

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            return

        kind = data.get("type")

        if kind == "typing":
            if self.conv_statut == "ouverte":
                await self.channel_layer.group_send(self.room, {
                    "type":     "chat.typing",
                    "user_id":  str(self.user.id),
                    "username": self.user.username,
                })

        elif kind == "message":
            contenu = str(data.get("contenu", "")).strip()
            if not contenu:
                return

            msg, result = await self._sauvegarder_message(self.conv_id, self.user, contenu)
            if msg is None:
                await self.send(text_data=json.dumps({
                    "type":   "error",
                    "reason": f"conversation_{result}",
                }))
                return

            payload = {
                "type":      "chat.message",
                "id":        msg.id,
                "conv_id":   self.conv_id,
                "contenu":   msg.contenu,
                "auteur_id": str(self.user.id),
                "username":  self.user.username,
                "timestamp": msg.created_at.isoformat(),
            }
            await self.channel_layer.group_send(self.room, payload)

            # Notification push pour les autres participants
            for uid in await self._autres_participants_ids(self.conv_id, self.user):
                await self.channel_layer.group_send(f"notif_{uid}", {
                    "type":       "notification",
                    "notif_type": "nouveau_message",
                    "data": {
                        "conv_id":    self.conv_id,
                        "auteur":     self.user.username,
                        "contenu":    msg.contenu[:80],
                        "message_id": msg.id,
                    },
                })

        elif kind == "lire":
            await self._marquer_lu(self.conv_id, self.user)
            await self.channel_layer.group_send(self.room, {
                "type":    "chat.lu",
                "user_id": str(self.user.id),
            })

    # ── Handlers group_send ───────────────────────────────────────────────────

    async def chat_message(self, event):
        await self.send(text_data=json.dumps({
            "type":      "message",
            "id":        event["id"],
            "conv_id":   event["conv_id"],
            "contenu":   event["contenu"],
            "auteur_id": event["auteur_id"],
            "username":  event["username"],
            "timestamp": event["timestamp"],
        }))

    async def chat_typing(self, event):
        if event["user_id"] != str(self.user.id):
            await self.send(text_data=json.dumps({
                "type":     "typing",
                "user_id":  event["user_id"],
                "username": event["username"],
            }))

    async def chat_lu(self, event):
        await self.send(text_data=json.dumps({
            "type":    "lu",
            "user_id": event["user_id"],
        }))


class NotificationConsumer(AsyncWebsocketConsumer):
    """
    Canal WebSocket dédié aux notifications temps réel.
    Room : notif_{user_id} — lecture seule côté client.
    """

    async def connect(self):
        self.user = self.scope.get("user")
        if not self.user or isinstance(self.user, AnonymousUser):
            await self.close(code=WS_FORBIDDEN)
            return
        self.room = f"notif_{self.user.id}"
        await self.channel_layer.group_add(self.room, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, "room"):
            await self.channel_layer.group_discard(self.room, self.channel_name)

    async def receive(self, text_data):
        pass

    async def notification(self, event):
        await self.send(text_data=json.dumps({
            "type":      event["notif_type"],
            "data":      event.get("data", {}),
            "timestamp": timezone.now().isoformat(),
        }))
