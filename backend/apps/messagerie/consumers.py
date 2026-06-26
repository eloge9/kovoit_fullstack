import json
import logging
from datetime import timedelta

from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser
from django.utils import timezone

logger = logging.getLogger(__name__)

WS_FORBIDDEN = 4003
WS_NOT_FOUND = 4404

EMOJIS_AUTORISES = {'👍', '❤️', '😂', '😮', '😢', '🙏'}


# ── Helpers DB ────────────────────────────────────────────────────────────────

def _serialise_reply(msg):
    if msg is None:
        return None
    return {
        'id':       msg.id,
        'contenu':  'Ce message a été supprimé.' if msg.deleted_for_everyone else msg.contenu,
        'username': msg.auteur.username,
        'message_type': msg.message_type,
    }


def _serialise_msg(msg, current_user_id):
    if msg.deleted_for_everyone:
        return {
            'id':         msg.id,
            'deleted':    True,
            'contenu':    'Ce message a été supprimé.',
            'auteur_id':  str(msg.auteur_id),
            'username':   msg.auteur.username,
            'timestamp':  msg.created_at.isoformat(),
            'moi':        msg.auteur_id == current_user_id,
            'message_type': msg.message_type,
        }
    return {
        'id':             msg.id,
        'deleted':        False,
        'contenu':        msg.contenu,
        'message_type':   msg.message_type,
        'audio_url':      msg.audio_file.url if msg.audio_file else None,
        'audio_duration': msg.audio_duration,
        'auteur_id':      str(msg.auteur_id),
        'username':       msg.auteur.username,
        'timestamp':      msg.created_at.isoformat(),
        'moi':            msg.auteur_id == current_user_id,
        'is_edited':      msg.is_edited,
        'edited_at':      msg.edited_at.isoformat() if msg.edited_at else None,
        'reply_to':       _serialise_reply(msg.reply_to) if msg.reply_to_id else None,
    }


class ConversationConsumer(AsyncWebsocketConsumer):
    """
    WebSocket de conversation.
    URL : ws/conv/{conv_id}/?token={jwt}

    Client → serveur :
        {"type": "message",        "contenu": "...", "reply_to_id": id|null}
        {"type": "edit_message",   "message_id": id, "contenu": "..."}
        {"type": "delete_message", "message_id": id, "pour_tous": bool}
        {"type": "react",          "message_id": id, "emoji": "👍"}
        {"type": "typing"}
        {"type": "lire"}

    Serveur → client :
        {"type": "message",        ...champs complets...}
        {"type": "message_edited", "message_id", "contenu", "edited_at"}
        {"type": "message_deleted","message_id", "pour_tous"}
        {"type": "reaction",       "message_id", "emoji", "user_id", "action"}
        {"type": "typing",         "user_id", "username"}
        {"type": "lu",             "user_id"}
        {"type": "user_online",    "user_id", "online"}
        {"type": "error",          "reason"}
    """

    # ── DB helpers ────────────────────────────────────────────────────────────

    @database_sync_to_async
    def _verifier_participant(self, conv_id, user):
        from .models import Conversation, Participant
        try:
            conv = Conversation.objects.get(pk=conv_id)
        except Conversation.DoesNotExist:
            return None
        if not Participant.objects.filter(conversation=conv, utilisateur=user).exists():
            return None
        return conv

    @database_sync_to_async
    def _sauvegarder_message(self, conv_id, auteur, contenu, reply_to_id=None):
        from .models import Conversation, MessageConv
        try:
            conv = Conversation.objects.get(pk=conv_id)
        except Conversation.DoesNotExist:
            return None, 'introuvable'
        if conv.statut != Conversation.OUVERTE:
            return None, conv.statut
        reply_to = None
        if reply_to_id:
            try:
                reply_to = MessageConv.objects.select_related('auteur').get(
                    pk=reply_to_id, conversation_id=conv_id,
                )
            except MessageConv.DoesNotExist:
                pass
        msg = MessageConv.objects.create(
            conversation=conv,
            auteur=auteur,
            contenu=contenu,
            reply_to=reply_to,
        )
        if reply_to:
            # Re-fetch pour que _serialise_reply fonctionne
            msg = MessageConv.objects.select_related('auteur', 'reply_to__auteur').get(pk=msg.pk)
        Conversation.objects.filter(pk=conv_id).update(updated_at=timezone.now())
        return msg, 'ok'

    @database_sync_to_async
    def _editer_message(self, msg_id, user, nouveau_contenu):
        from .models import MessageConv
        try:
            msg = MessageConv.objects.get(pk=msg_id)
        except MessageConv.DoesNotExist:
            return None, 'introuvable'
        if msg.auteur_id != user.id:
            return None, 'interdit'
        if msg.deleted_for_everyone:
            return None, 'supprime'
        delai = timezone.now() - msg.created_at
        if delai > timedelta(minutes=15):
            return None, 'delai_depasse'
        msg.contenu    = nouveau_contenu.strip()
        msg.is_edited  = True
        msg.edited_at  = timezone.now()
        msg.save(update_fields=['contenu', 'is_edited', 'edited_at'])
        return msg, 'ok'

    @database_sync_to_async
    def _supprimer_message(self, msg_id, user, pour_tous):
        from .models import MessageConv
        try:
            msg = MessageConv.objects.get(pk=msg_id)
        except MessageConv.DoesNotExist:
            return None, 'introuvable'
        if msg.auteur_id != user.id:
            return None, 'interdit'
        if pour_tous:
            msg.deleted_for_everyone = True
            msg.save(update_fields=['deleted_for_everyone'])
        else:
            msg.deleted_for_me.add(user)
        return msg, 'ok'

    @database_sync_to_async
    def _reagir(self, msg_id, user, emoji):
        from .models import MessageConv, MessageReaction
        if emoji not in EMOJIS_AUTORISES:
            return None, 'emoji_invalide'
        try:
            msg = MessageConv.objects.get(pk=msg_id)
        except MessageConv.DoesNotExist:
            return None, 'introuvable'
        existing = MessageReaction.objects.filter(message=msg, utilisateur=user).first()
        if existing:
            if existing.emoji == emoji:
                existing.delete()
                return emoji, 'remove'
            else:
                existing.emoji = emoji
                existing.save(update_fields=['emoji'])
                return emoji, 'add'
        MessageReaction.objects.create(message=msg, utilisateur=user, emoji=emoji)
        return emoji, 'add'

    @database_sync_to_async
    def _marquer_lu(self, conv_id, user):
        from .models import Participant
        Participant.objects.filter(
            conversation_id=conv_id, utilisateur=user,
        ).update(dernier_lu_at=timezone.now())

    @database_sync_to_async
    def _autres_participants_ids(self, conv_id, user):
        from .models import Participant
        return list(
            Participant.objects
            .filter(conversation_id=conv_id)
            .exclude(utilisateur=user)
            .values_list('utilisateur_id', flat=True)
        )

    # ── Cycle de vie ─────────────────────────────────────────────────────────

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

        # Signaler que l'utilisateur est en ligne
        await self.channel_layer.group_send(self.room, {
            "type":    "chat.user_online",
            "user_id": str(self.user.id),
            "online":  True,
        })

    async def disconnect(self, close_code):
        if hasattr(self, "room"):
            await self.channel_layer.group_send(self.room, {
                "type":    "chat.user_online",
                "user_id": str(self.user.id),
                "online":  False,
            })
            await self.channel_layer.group_discard(self.room, self.channel_name)

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            return

        kind = data.get("type")

        # ── Typing ────────────────────────────────────────────────────────────
        if kind == "typing":
            if self.conv_statut == "ouverte":
                await self.channel_layer.group_send(self.room, {
                    "type":     "chat.typing",
                    "user_id":  str(self.user.id),
                    "username": self.user.username,
                })

        # ── Nouveau message texte ─────────────────────────────────────────────
        elif kind == "message":
            contenu = str(data.get("contenu", "")).strip()
            if not contenu:
                return
            reply_to_id = data.get("reply_to_id")

            msg, result = await self._sauvegarder_message(
                self.conv_id, self.user, contenu, reply_to_id,
            )
            if msg is None:
                await self.send(text_data=json.dumps({
                    "type": "error", "reason": f"conversation_{result}",
                }))
                return

            payload = {"type": "chat.message", **_serialise_msg(msg, self.user.id)}
            await self.channel_layer.group_send(self.room, payload)

            # Notification push
            for uid in await self._autres_participants_ids(self.conv_id, self.user):
                await self.channel_layer.group_send(f"notif_{uid}", {
                    "type":       "notification",
                    "notif_type": "nouveau_message",
                    "data": {
                        "conv_id":    self.conv_id,
                        "auteur":     self.user.username,
                        "contenu":    contenu[:80],
                        "message_id": msg.id,
                    },
                })

        # ── Modifier message ──────────────────────────────────────────────────
        elif kind == "edit_message":
            msg_id = data.get("message_id")
            nouveau = str(data.get("contenu", "")).strip()
            if not msg_id or not nouveau:
                return
            msg, result = await self._editer_message(msg_id, self.user, nouveau)
            if msg is None:
                await self.send(text_data=json.dumps({
                    "type": "error", "reason": result,
                }))
                return
            await self.channel_layer.group_send(self.room, {
                "type":       "chat.message_edited",
                "message_id": msg.id,
                "contenu":    msg.contenu,
                "edited_at":  msg.edited_at.isoformat(),
            })

        # ── Supprimer message ─────────────────────────────────────────────────
        elif kind == "delete_message":
            msg_id   = data.get("message_id")
            pour_tous = bool(data.get("pour_tous", False))
            if not msg_id:
                return
            msg, result = await self._supprimer_message(msg_id, self.user, pour_tous)
            if msg is None:
                await self.send(text_data=json.dumps({
                    "type": "error", "reason": result,
                }))
                return
            if pour_tous:
                await self.channel_layer.group_send(self.room, {
                    "type":       "chat.message_deleted",
                    "message_id": msg.id,
                    "pour_tous":  True,
                })
            else:
                # Suppression pour moi uniquement → envoyer seulement à l'expéditeur
                await self.send(text_data=json.dumps({
                    "type":       "message_deleted",
                    "message_id": msg.id,
                    "pour_tous":  False,
                }))

        # ── Réaction ─────────────────────────────────────────────────────────
        elif kind == "react":
            msg_id = data.get("message_id")
            emoji  = str(data.get("emoji", ""))
            if not msg_id or not emoji:
                return
            result_emoji, action = await self._reagir(msg_id, self.user, emoji)
            if action in ('add', 'remove'):
                await self.channel_layer.group_send(self.room, {
                    "type":       "chat.reaction",
                    "message_id": msg_id,
                    "emoji":      result_emoji,
                    "user_id":    str(self.user.id),
                    "action":     action,
                })

        # ── Marquer lu ────────────────────────────────────────────────────────
        elif kind == "lire":
            await self._marquer_lu(self.conv_id, self.user)
            await self.channel_layer.group_send(self.room, {
                "type":    "chat.lu",
                "user_id": str(self.user.id),
            })

    # ── Handlers group_send ───────────────────────────────────────────────────

    async def chat_message(self, event):
        payload = {k: v for k, v in event.items() if k != 'type'}
        payload['type'] = 'message'
        await self.send(text_data=json.dumps(payload))

    async def chat_message_edited(self, event):
        await self.send(text_data=json.dumps({
            "type":       "message_edited",
            "message_id": event["message_id"],
            "contenu":    event["contenu"],
            "edited_at":  event["edited_at"],
        }))

    async def chat_message_deleted(self, event):
        await self.send(text_data=json.dumps({
            "type":       "message_deleted",
            "message_id": event["message_id"],
            "pour_tous":  event["pour_tous"],
        }))

    async def chat_reaction(self, event):
        await self.send(text_data=json.dumps({
            "type":       "reaction",
            "message_id": event["message_id"],
            "emoji":      event["emoji"],
            "user_id":    event["user_id"],
            "action":     event["action"],
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

    async def chat_user_online(self, event):
        await self.send(text_data=json.dumps({
            "type":    "user_online",
            "user_id": event["user_id"],
            "online":  event["online"],
        }))


class NotificationConsumer(AsyncWebsocketConsumer):
    """Canal WebSocket notifications temps réel."""

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
