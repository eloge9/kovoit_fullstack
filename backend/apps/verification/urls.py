"""URLs du module de vérification conducteurs."""
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import DriverVerificationViewSet, AdminDriverViewSet, DriverSignalViewSet

router = DefaultRouter()
router.register(r"driver/verification", DriverVerificationViewSet, basename="driver-verification")
router.register(r"admin/drivers",       AdminDriverViewSet,        basename="admin-drivers")
router.register(r"drivers",             DriverSignalViewSet,       basename="driver-signals")

urlpatterns = [
    path("", include(router.urls)),
]
