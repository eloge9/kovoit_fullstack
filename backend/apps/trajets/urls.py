from rest_framework.routers import DefaultRouter
from .views import TrajetViewSet

router = DefaultRouter()
router.register(r'', TrajetViewSet, basename='trajets')

urlpatterns = router.urls