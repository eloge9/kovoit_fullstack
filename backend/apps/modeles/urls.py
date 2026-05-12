from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import EconomieViewSet

router = DefaultRouter()
router.register(r'', EconomieViewSet, basename='economie')

urlpatterns = [
    path('', include(router.urls)),
]
