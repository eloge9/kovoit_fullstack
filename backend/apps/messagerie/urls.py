from django.urls import path
from . import views

urlpatterns = [
    # Conversations
    path('conversations/',                       views.liste_conversations,  name='conv-list'),
    path('conversations/<int:conv_id>/',         views.detail_conversation,  name='conv-detail'),
    # Messages d'une conversation
    path('conversations/<int:conv_id>/messages/', views.messages_conversation, name='conv-messages'),
    path('conversations/<int:conv_id>/envoyer/',  views.envoyer_message,       name='conv-envoyer'),
    path('conversations/<int:conv_id>/audio/',    views.envoyer_audio,         name='conv-audio'),
    # Actions sur un message
    path('messages/<int:msg_id>/',               views.modifier_message,     name='msg-modifier'),
    path('messages/<int:msg_id>/supprimer/',      views.supprimer_message,    name='msg-supprimer'),
    path('messages/<int:msg_id>/reagir/',         views.reagir_message,       name='msg-reagir'),
    # Non lus
    path('non-lus/',                             views.non_lus_count,        name='non-lus'),
]
