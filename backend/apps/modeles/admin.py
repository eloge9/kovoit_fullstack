from django.contrib import admin
from django.utils.html import format_html
from .models import *


# =====================================================
# PERSONNALISATION DU SITE ADMIN
# =====================================================

admin.site.site_header = "KoVoit — Administration"
admin.site.site_title  = "KoVoit Admin"
admin.site.index_title = "Tableau de bord administrateur"


# =====================================================
# ACTIONS ADMIN PERSONNALISÉES
# =====================================================

@admin.action(description='Valider les documents selectionnes')
def valider_documents(modeladmin, request, queryset):
    queryset.update(statut_validation='valide', is_active=True, peut_conduire=True)

@admin.action(description='Rejeter les documents selectionnes')
def rejeter_documents(modeladmin, request, queryset):
    queryset.update(statut_validation='rejete', peut_conduire=False)


# =====================================================
# UTILISATEUR & PROFILS
# =====================================================

class UtilisateurAdmin(admin.ModelAdmin):
    list_display  = ['username', 'email', 'role', 'peut_conduire', 'statut_validation',
                     'apercu_cni', 'apercu_permis', 'is_active', 'note', 'date_joined']
    list_filter   = ['role', 'is_active', 'statut_validation', 'peut_conduire', 'date_joined']
    search_fields = ['username', 'email', 'numero_telephone']
    readonly_fields = ['id', 'date_joined', 'apercu_cni', 'apercu_permis']
    actions = [valider_documents, rejeter_documents]

    fieldsets = (
        ('Compte', {
            'fields': ('id', 'username', 'email', 'role', 'is_active', 'note', 'date_joined')
        }),
        ('Coordonnees', {
            'fields': ('first_name', 'last_name', 'numero_telephone', 'photo_profil')
        }),
        ('Documents identite et validation conducteur', {
            'fields': ('photo_cni', 'apercu_cni', 'photo_permis', 'apercu_permis',
                       'statut_validation', 'peut_conduire'),
            'description': 'Documents soumis pour validation. Utilisez les actions ci-dessus.',
        }),
    )

    @admin.display(description='CNI')
    def apercu_cni(self, obj):
        if obj.photo_cni:
            return format_html(
                '<a href="{}" target="_blank">'
                '<img src="{}" style="max-height:60px;max-width:100px;border-radius:4px;" />'
                '</a>',
                obj.photo_cni.url, obj.photo_cni.url
            )
        return "—"

    @admin.display(description='Permis')
    def apercu_permis(self, obj):
        if obj.photo_permis:
            return format_html(
                '<a href="{}" target="_blank">'
                '<img src="{}" style="max-height:60px;max-width:100px;border-radius:4px;" />'
                '</a>',
                obj.photo_permis.url, obj.photo_permis.url
            )
        return "—"


class AdminInline(admin.StackedInline):
    model = Admin
    extra = 0


class ConducteurInline(admin.StackedInline):
    model = Conducteur
    extra = 0
    fields = ['numero_permis', 'experience_annees']


class PassagerInline(admin.StackedInline):
    model = Passager
    extra = 0


class ConducteurAdmin(admin.ModelAdmin):
    list_display = ['utilisateur', 'numero_permis', 'experience_annees']
    search_fields = ['utilisateur__username', 'numero_permis']


class PassagerAdmin(admin.ModelAdmin):
    list_display = ['utilisateur', 'historique_points']


# =====================================================
# VÉHICULE
# =====================================================

class VehiculeAdmin(admin.ModelAdmin):
    list_display = ['marque', 'modele', 'plaque', 'conducteur', 'type_vehicule', 'places_max', 'est_actif']
    list_filter = ['type_vehicule', 'est_actif']
    search_fields = ['marque', 'modele', 'plaque', 'conducteur__utilisateur__username']


# =====================================================
# TRAJETS & RÉSERVATIONS
# =====================================================

class TrajetAdmin(admin.ModelAdmin):
    list_display = ['depart', 'destination', 'conducteur', 'distance_km', 'cout_total', 'statut', 'date_heure_depart']
    list_filter = ['statut', 'est_regulier', 'date_heure_depart']
    search_fields = ['depart', 'destination', 'conducteur__username']
    readonly_fields = ['id', 'created_at', 'updated_at']


class ReservationAdmin(admin.ModelAdmin):
    list_display = ['passager', 'trajet', 'places_reservees', 'statut', 'date_reservation']
    list_filter = ['statut', 'date_reservation']
    search_fields = ['passager__username', 'trajet__depart']


# =====================================================
# PAIEMENTS
# =====================================================

class PaiementAdmin(admin.ModelAdmin):
    list_display = ['id', 'passager', 'conducteur', 'montant', 'moyen_paiement', 'statut', 'date_creation']
    list_filter = ['statut', 'moyen_paiement', 'date_creation']
    search_fields = ['passager__username', 'conducteur__username']
    readonly_fields = ['id', 'date_creation', 'date_confirmation']


# =====================================================
# WALLET / PORTEFEUILLE
# =====================================================

class WalletAdmin(admin.ModelAdmin):
    list_display = ['id', 'proprietaire', 'type', 'solde_disponible', 'solde_du', 'date_maj']
    list_filter = ['type']
    search_fields = ['proprietaire__username']
    readonly_fields = ['date_creation', 'date_maj']


class WalletTransactionAdmin(admin.ModelAdmin):
    list_display = ['id', 'wallet', 'type', 'sens', 'montant', 'statut', 'reference', 'created_at']
    list_filter = ['type', 'sens', 'statut', 'created_at']
    search_fields = ['reference', 'wallet__proprietaire__username', 'description']
    readonly_fields = [f.name for f in WalletTransaction._meta.fields]

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


class WithdrawalAdmin(admin.ModelAdmin):
    list_display = ['id', 'wallet', 'montant', 'moyen', 'numero_destination', 'statut', 'date_demande']
    list_filter = ['statut', 'moyen']
    search_fields = ['wallet__proprietaire__username', 'numero_destination', 'reference_agregateur']
    readonly_fields = ['date_demande']


class DepotWalletAdmin(admin.ModelAdmin):
    list_display = ['id', 'wallet', 'montant', 'statut', 'token', 'date_creation']
    list_filter = ['statut']
    search_fields = ['wallet__proprietaire__username', 'token', 'transref']
    readonly_fields = ['date_creation']


# =====================================================
# ÉVALUATIONS & MESSAGES
# =====================================================

class EvaluationAdmin(admin.ModelAdmin):
    list_display = ['auteur', 'cible', 'note', 'date_evaluation']
    list_filter = ['note', 'date_evaluation']
    search_fields = ['auteur__username', 'cible__username']


class MessageAdmin(admin.ModelAdmin):
    list_display = ['expediteur', 'destinataire', 'trajet', 'lu', 'created_at']
    list_filter = ['lu', 'created_at']
    search_fields = ['expediteur__username', 'destinataire__username']


# =====================================================
# NOTIFICATIONS & STATISTIQUES
# =====================================================

class NotificationAdmin(admin.ModelAdmin):
    list_display = ['utilisateur', 'lu', 'date_notification']
    list_filter = ['lu', 'date_notification']
    search_fields = ['utilisateur__username']


class StatistiqueAdmin(admin.ModelAdmin):
    list_display = ['trajet', 'total_reservations', 'revenu_total', 'note_moyenne']
    readonly_fields = ['trajet']


# =====================================================
# PLAINTES
# =====================================================

class PlainteAdmin(admin.ModelAdmin):
    list_display = ['titre', 'utilisateur_signale', 'type_plainte', 'statut', 'admin_assigne', 'date_creation']
    list_filter = ['statut', 'type_plainte', 'date_creation']
    search_fields = ['titre', 'utilisateur_signale__username', 'admin_assigne__username']
    readonly_fields = ['id', 'date_creation', 'date_modification', 'date_resolution']
    fieldsets = (
        ('Informations générales', {
            'fields': ('id', 'titre', 'description', 'type_plainte', 'date_creation', 'date_modification')
        }),
        ('Parties', {
            'fields': ('signalataire', 'utilisateur_signale', 'trajet', 'evaluation')
        }),
        ('Traitement', {
            'fields': ('statut', 'admin_assigne', 'note_admin', 'date_resolution')
        }),
    )


# =====================================================
# ENREGISTREMENT
# =====================================================

admin.site.register(Utilisateur, UtilisateurAdmin)
admin.site.register(Admin)
admin.site.register(Conducteur, ConducteurAdmin)
admin.site.register(Passager, PassagerAdmin)
admin.site.register(Vehicule, VehiculeAdmin)

admin.site.register(Trajet, TrajetAdmin)
admin.site.register(Reservation, ReservationAdmin)

admin.site.register(Paiement, PaiementAdmin)

admin.site.register(Wallet, WalletAdmin)
admin.site.register(WalletTransaction, WalletTransactionAdmin)
admin.site.register(Withdrawal, WithdrawalAdmin)
admin.site.register(DepotWallet, DepotWalletAdmin)

admin.site.register(Evaluation, EvaluationAdmin)
admin.site.register(Message, MessageAdmin)
admin.site.register(Appel)
admin.site.register(Notification, NotificationAdmin)

admin.site.register(Statistique, StatistiqueAdmin)

admin.site.register(Plainte, PlainteAdmin)

