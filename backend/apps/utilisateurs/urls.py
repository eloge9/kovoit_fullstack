from rest_framework.routers import DefaultRouter
from .views import AuthViewSet, UtilisateurViewSet

router = DefaultRouter()
router.register(r'auth', AuthViewSet, basename='auth')
router.register(r'ko', UtilisateurViewSet, basename='utilisateurs')

urlpatterns = router.urls