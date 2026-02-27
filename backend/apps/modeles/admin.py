from django.contrib import admin
from .models import *

admin.site.register(Utilisateur)
admin.site.register(Admin)
admin.site.register(Conducteur)
admin.site.register(Passager)
admin.site.register(Trajet)
admin.site.register(Reservation)
admin.site.register(Paiement)
admin.site.register(Evaluation)
admin.site.register(Message)
admin.site.register(Appel)
admin.site.register(Notification)
admin.site.register(Statistique)

