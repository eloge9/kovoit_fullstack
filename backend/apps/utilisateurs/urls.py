from rest_framework.routers import DefaultRouter
from .views import AuthViewSet, UtilisateurViewSet
from .admin_views import AdminViewSet

router = DefaultRouter()
router.register(r'auth', AuthViewSet, basename='auth')
router.register(r'ko', UtilisateurViewSet, basename='utilisateurs')
router.register(r'admin', AdminViewSet, basename='admin')

urlpatterns = router.urls