from django.urls import path
from . import views

urlpatterns = [
    path('conversations/',
         views.liste_conversations,           name='conv-list'),
    path('conversations/<int:conv_id>/',
         views.detail_conversation,           name='conv-detail'),
    path('conversations/<int:conv_id>/messages/',
         views.messages_conversation,         name='conv-messages-get'),
    path('conversations/<int:conv_id>/envoyer/',
         views.envoyer_message,               name='conv-messages-post'),
    path('non-lus/',
         views.non_lus_count,                 name='non-lus'),
]
