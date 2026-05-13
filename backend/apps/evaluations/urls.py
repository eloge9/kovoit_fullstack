from django.urls import path
from . import views

urlpatterns = [
    path('evaluer/', views.EvaluationViewSet.as_view({'post': 'evaluer'}), name='evaluer'),
    path('terminer_trajet/', views.EvaluationViewSet.as_view({'post': 'terminer_trajet'}), name='terminer_trajet'),
    path('mes_evaluations/', views.EvaluationViewSet.as_view({'get': 'mes_evaluations'}), name='mes_evaluations'),
    path('a_evaluer/', views.EvaluationViewSet.as_view({'get': 'a_evaluer'}), name='a_evaluer'),
]
