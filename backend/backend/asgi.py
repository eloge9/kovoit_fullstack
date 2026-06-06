"""
ASGI config — HTTP + WebSockets (Django Channels)
"""

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from django.core.asgi import get_asgi_application
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack

from apps.trajets.routing import websocket_urlpatterns

application = ProtocolTypeRouter({
    # Requêtes HTTP standard (Django)
    'http': get_asgi_application(),

    # Connexions WebSocket (Channels)
    'websocket': AuthMiddlewareStack(
        URLRouter(websocket_urlpatterns)
    ),
})
