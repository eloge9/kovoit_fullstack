from rest_framework.routers import DefaultRouter
from .views import MessagerieViewSet

router = DefaultRouter()
router.register(r'', MessagerieViewSet, basename='messagerie')

urlpatterns = router.urls
