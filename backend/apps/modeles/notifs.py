"""
Helper partagé pour envoyer une notification WebSocket à un utilisateur.
Appelable depuis n'importe quelle vue Django synchrone.
"""
import logging
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync

logger = logging.getLogger(__name__)


def envoyer_notification(user, type_notif: str, data: dict = {}):
    """
    Pousse une notification temps réel à l'utilisateur via son canal WebSocket.
    Si l'utilisateur n'est pas connecté (WebSocket fermé), la notification est ignorée.

    Args:
        user        : instance Utilisateur
        type_notif  : ex. 'nouvelle_reservation', 'reservation_confirmee', ...
        data        : payload complémentaire (dict JSON-sérialisable)
    """
    channel_layer = get_channel_layer()
    if channel_layer is None:
        return
    try:
        async_to_sync(channel_layer.group_send)(
            f"notif_{user.id}",
            {
                "type":       "notification",
                "notif_type": type_notif,
                "data":       data,
            },
        )
    except Exception as exc:
        # Redis indisponible ou consumer non connecté → silencieux
        logger.debug("envoyer_notification ignoré pour %s : %s", user.id, exc)
