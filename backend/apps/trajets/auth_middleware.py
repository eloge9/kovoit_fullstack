from urllib.parse import parse_qs

from channels.middleware import BaseMiddleware
from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser
from rest_framework_simplejwt.tokens import AccessToken
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError


@database_sync_to_async
def _get_user_from_token(raw_token: str):
    from apps.modeles.models import Utilisateur
    try:
        token = AccessToken(raw_token)
        return Utilisateur.objects.get(pk=token["user_id"])
    except (InvalidToken, TokenError, KeyError):
        return AnonymousUser()
    except Exception:
        return AnonymousUser()


class JWTAuthMiddleware(BaseMiddleware):
    """
    Injecte scope['user'] depuis le JWT passé en query string.
    Utilisation côté client : new WebSocket(`ws://host/ws/trajet/1/?token=${accessToken}`)
    """

    async def __call__(self, scope, receive, send):
        qs = parse_qs(scope.get("query_string", b"").decode())
        tokens = qs.get("token", [])
        scope["user"] = (
            await _get_user_from_token(tokens[0]) if tokens else AnonymousUser()
        )
        return await super().__call__(scope, receive, send)
