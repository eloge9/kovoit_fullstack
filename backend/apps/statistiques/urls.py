from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views
from .viewsets import StatistiqueEconomieViewSet

# Router pour les viewsets
router = DefaultRouter()
router.register(r'economies', StatistiqueEconomieViewSet, basename='economies')

urlpatterns = [
    # Endpoints du router
    path('', include(router.urls)),
    
    # Résumé économique rapide tableau de bord
    path('resume/', views.ResumeEconomieView.as_view(), name='resume_economie'),
    
    # Statistiques détaillées conducteur
    path('conducteur/', views.StatistiqueConducteurView.as_view(), name='statistiques_conducteur'),
    path('conducteur/<uuid:conducteur_id>/', views.StatistiqueConducteurView.as_view(), name='statistiques_conducteur_detail'),
    
    # Statistiques détaillées passager
    path('passager/', views.StatistiquePassagerView.as_view(), name='statistiques_passager'),
    path('passager/<uuid:passager_id>/', views.StatistiquePassagerView.as_view(), name='statistiques_passager_detail'),
    
    # Statistiques globales (admin)
    path('globales/', views.statistiques_globales, name='statistiques_globales'),
]
