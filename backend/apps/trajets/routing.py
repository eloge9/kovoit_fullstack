from django.urls import re_path
from . import consumers

websocket_urlpatterns = [
    re_path(r'ws/trajet/(?P<trajet_id>\d+)/$', consumers.GpsConsumer.as_asgi()),
]
