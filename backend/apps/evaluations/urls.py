from django.urls import path, re_path
from . import views

_vs = views.EvaluationViewSet

urlpatterns = [
    # Création + liste à évaluer
    path('evaluer/',               _vs.as_view({'post': 'evaluer'}),               name='evaluer'),
    path('a_evaluer/',             _vs.as_view({'get':  'a_evaluer'}),             name='a_evaluer'),
    path('passagers_a_evaluer/',   _vs.as_view({'get':  'passagers_a_evaluer'}),   name='passagers_a_evaluer'),

    # Modification dans la fenêtre de 24 h
    re_path(
        r'^modifier/(?P<eval_id>[0-9]+)/$',
        _vs.as_view({'put': 'modifier_evaluation'}),
        name='modifier_evaluation',
    ),

    # Consultation
    path('mes_evaluations/',        _vs.as_view({'get': 'mes_evaluations'}),        name='mes_evaluations'),
    path('mes_evaluations_donnees/',_vs.as_view({'get': 'mes_evaluations_donnees'}),name='mes_evaluations_donnees'),

    # Terminer trajet
    path('terminer_trajet/',        _vs.as_view({'post': 'terminer_trajet'}),       name='terminer_trajet'),

    # Signalement + blocage
    path('signaler/',              _vs.as_view({'post': 'signaler'}),              name='signaler'),
    path('bloquer/',               _vs.as_view({'post': 'bloquer'}),               name='bloquer'),
    path('mes_blocages/',          _vs.as_view({'get':  'mes_blocages'}),          name='mes_blocages'),
    re_path(
        r'^debloquer/(?P<passager_id>[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/$',
        _vs.as_view({'delete': 'debloquer'}),
        name='debloquer',
    ),

    # Admin
    path('admin_stats/',           _vs.as_view({'get': 'admin_stats'}),            name='admin_stats'),
]
