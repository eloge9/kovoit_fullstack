from django.contrib import admin
from django.urls import path,include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/utilisateurs/', include('apps.utilisateurs.urls')),
    path('api/trajets/', include('apps.trajets.urls')),
    path('api/reservations/', include('apps.reservations.urls')),
    path('api/paiements/', include('apps.paiements.urls')),
    path('api/evaluations/', include('apps.evaluations.urls')),
    path('api/messagerie/', include('apps.messagerie.urls')),
    path('api/statistiques/', include('apps.statistiques.urls')),
]
