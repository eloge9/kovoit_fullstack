from django.urls import re_path
from . import consumers

websocket_urlpatterns = [
    # Chat pair-à-pair : ws/chat/{uuid_autre_utilisateur}/
    re_path(r'ws/chat/(?P<user_id>[0-9a-f-]+)/$', consumers.ChatConsumer.as_asgi()),
    # Notifications temps réel de l'utilisateur connecté
    re_path(r'ws/notifications/$',                 consumers.NotificationConsumer.as_asgi()),
]
