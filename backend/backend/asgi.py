"""
ASGI config — HTTP + WebSockets (Django Channels)
"""

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from django.core.asgi import get_asgi_application
from channels.routing import ProtocolTypeRouter, URLRouter

from apps.trajets.routing    import websocket_urlpatterns as trajet_ws
from apps.messagerie.routing import websocket_urlpatterns as messagerie_ws
from apps.trajets.auth_middleware import JWTAuthMiddleware

# Toutes les routes WebSocket réunies sous un seul URLRouter
all_ws = trajet_ws + messagerie_ws

application = ProtocolTypeRouter({
    'http': get_asgi_application(),
    'websocket': JWTAuthMiddleware(
        URLRouter(all_ws)
    ),
})
