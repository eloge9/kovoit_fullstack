from django.urls import re_path
from . import consumers

websocket_urlpatterns = [
    re_path(r'^ws/conv/(?P<conv_id>[0-9]+)/$',  consumers.ConversationConsumer.as_asgi()),
    re_path(r'^ws/notifications/$',              consumers.NotificationConsumer.as_asgi()),
]
