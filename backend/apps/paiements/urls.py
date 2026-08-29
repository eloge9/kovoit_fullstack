from rest_framework.routers import DefaultRouter
from .views import PaiementViewSet, WalletViewSet

router = DefaultRouter()
router.register(r'', PaiementViewSet, basename='paiements')
router.register(r'wallet', WalletViewSet, basename='wallet')

urlpatterns = router.urls