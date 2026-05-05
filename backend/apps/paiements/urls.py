from rest_framework.routers import DefaultRouter
from .views import PaiementViewSet

router = DefaultRouter()
router.register(r'', PaiementViewSet, basename='paiements')

urlpatterns = router.urls   