from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.http import JsonResponse
from django.views.decorators.http import require_GET

admin.site.site_url = getattr(
    settings,
    "ADMIN_FRONTEND_URL",
    "http://localhost:3000/admin/dashboard",
)


@require_GET
def ping(request):
    return JsonResponse({'status': 'ok', 'service': 'backend', 'version': '1.0'})


urlpatterns = [
    path('api/ping/', ping, name='ping'),
    path('admin/', admin.site.urls),
    path('api/utilisateurs/',  include('apps.utilisateurs.urls')),
    path('api/trajets/',       include('apps.trajets.urls')),
    path('api/reservations/',  include('apps.reservations.urls')),
    path('api/paiements/',     include('apps.paiements.urls')),
    path('api/evaluations/',   include('apps.evaluations.urls')),
    path('api/messagerie/',    include('apps.messagerie.urls')),
    path('api/statistiques/',  include('apps.statistiques.urls')),
    path('api/economie/',      include('apps.modeles.urls')),
    path('api/verification/',  include('apps.verification.urls')),
    path('api/chat/',          include('apps.chatbot.urls')),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)