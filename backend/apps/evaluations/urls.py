from django.urls import path, re_path
from . import views

_vs = views.EvaluationViewSet

urlpatterns = [
    path('evaluer/',        _vs.as_view({'post': 'evaluer'}),        name='evaluer'),
    path('terminer_trajet/',_vs.as_view({'post': 'terminer_trajet'}),name='terminer_trajet'),
    path('mes_evaluations/',_vs.as_view({'get':  'mes_evaluations'}),name='mes_evaluations'),
    path('a_evaluer/',      _vs.as_view({'get':  'a_evaluer'}),      name='a_evaluer'),
    # Priorité 3
    path('signaler/',       _vs.as_view({'post': 'signaler'}),       name='signaler'),
    path('bloquer/',        _vs.as_view({'post': 'bloquer'}),        name='bloquer'),
    path('mes_blocages/',   _vs.as_view({'get':  'mes_blocages'}),   name='mes_blocages'),
    re_path(
        r'^debloquer/(?P<passager_id>[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/$',
        _vs.as_view({'delete': 'debloquer'}),
        name='debloquer',
    ),
]
