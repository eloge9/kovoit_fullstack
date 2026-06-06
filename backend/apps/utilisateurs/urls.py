from rest_framework.routers import DefaultRouter
from .views import AuthViewSet, UtilisateurViewSet, ProfilPublicViewSet
from .admin_views import AdminViewSet

router = DefaultRouter()
router.register(r'auth',       AuthViewSet,       basename='auth')
router.register(r'ko',         UtilisateurViewSet, basename='utilisateurs')
router.register(r'admin',      AdminViewSet,      basename='admin')
router.register(r'conducteur', ProfilPublicViewSet, basename='conducteur-public')

urlpatterns = router.urls