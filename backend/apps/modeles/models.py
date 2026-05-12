"""Models centralisés pour les utilisateurs"""
import uuid
from django.db import models
from django.contrib.auth.models import AbstractUser


def chemin_photo(instance, filename):
    ext = filename.split('.')[-1]
    return f"profils/{instance.pk}/{instance.pk}.{ext}"


# ----------------- Utilisateur -----------------
class Utilisateur(AbstractUser):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    ROLE_CHOICES = (
        ('conducteur', 'Conducteur'),
        ('passager',   'Passager'),
        ('admin',      'Admin'),
    )
    email            = models.EmailField(unique=True)
    role             = models.CharField(max_length=20, choices=ROLE_CHOICES)
    numero_telephone = models.CharField(max_length=20, blank=True, null=True)
    photo_profil     = models.ImageField(upload_to=chemin_photo, blank=True, null=True)
    note             = models.FloatField(default=0)

    REQUIRED_FIELDS = ['email', 'role']

    def __str__(self):
        return f"{self.username} ({self.role})"


# ----------------- Profils -----------------
class Admin(models.Model):
    utilisateur             = models.OneToOneField(Utilisateur, on_delete=models.CASCADE, related_name='profil_admin')
    permissions_specifiques = models.TextField(blank=True)

    def __str__(self):
        return f"Profil Admin: {self.utilisateur.username}"


class Conducteur(models.Model):
    utilisateur       = models.OneToOneField(Utilisateur, on_delete=models.CASCADE, related_name='profil_conducteur')
    numero_permis     = models.CharField(max_length=50)
    experience_annees = models.IntegerField(default=0)

    def __str__(self):
        return f"Profil Conducteur: {self.utilisateur.username}"


# ----------------- Véhicule -----------------
TYPE_VEHICULE_CHOICES = (
    ('moto',    'Moto'),
    ('voiture', 'Voiture'),
    ('minibus', 'Minibus'),
    ('camion',  'Camion'),
)

# Tarif carburant par km selon type (FCFA/km)
TARIF_PAR_TYPE = {
    'moto':    30,
    'voiture': 65,
    'minibus': 120,
    'camion':  200,
}

# Places maximum par type
PLACES_MAX_PAR_TYPE = {
    'moto':    1,
    'voiture': 5,
    'minibus': 15,
    'camion':  3,
}


class Vehicule(models.Model):
    conducteur    = models.ForeignKey(Conducteur, on_delete=models.CASCADE, related_name='vehicules')
    type_vehicule = models.CharField(max_length=20, choices=TYPE_VEHICULE_CHOICES)
    marque        = models.CharField(max_length=100)
    modele        = models.CharField(max_length=100)
    couleur       = models.CharField(max_length=50)
    plaque        = models.CharField(max_length=20, unique=True)
    places_max    = models.IntegerField()
    est_actif     = models.BooleanField(default=True)
    created_at    = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.marque} {self.modele} ({self.plaque})"


class Passager(models.Model):
    utilisateur       = models.OneToOneField(Utilisateur, on_delete=models.CASCADE, related_name='profil_passager')
    historique_points = models.IntegerField(default=0)

    def __str__(self):
        return f"Profil Passager: {self.utilisateur.username}"


# ----------------- Trajet -----------------
class Trajet(models.Model):
    conducteur = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='trajets')
    vehicule   = models.ForeignKey(
        Vehicule, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='trajets'
    )

    depart          = models.CharField(max_length=255)
    destination     = models.CharField(max_length=255)
    depart_lat      = models.FloatField(null=True, blank=True)
    depart_lng      = models.FloatField(null=True, blank=True)
    destination_lat = models.FloatField(null=True, blank=True)
    destination_lng = models.FloatField(null=True, blank=True)

    distance_km    = models.FloatField(null=True, blank=True)
    cout_total     = models.FloatField(null=True, blank=True)
    prix_par_place = models.DecimalField(max_digits=10, decimal_places=2)

    date_heure_depart  = models.DateTimeField()
    places_disponibles = models.IntegerField()
    description        = models.TextField(blank=True)

    est_regulier  = models.BooleanField(default=False)
    jours_semaine = models.JSONField(null=True, blank=True)

    statut = models.CharField(max_length=20, choices=(
        ('ouvert',   'Ouvert'),
        ('en_cours', 'En cours'),
        ('termine',  'Terminé'),
        ('annule',   'Annulé'),
    ), default='ouvert')

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-date_heure_depart']

    def __str__(self):
        return f"{self.depart} → {self.destination} ({self.conducteur.username})"


# ----------------- Réservation -----------------
class Reservation(models.Model):
    trajet           = models.ForeignKey(Trajet, on_delete=models.CASCADE, related_name='reservations')
    passager         = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='reservations')
    places_reservees = models.IntegerField(default=1)
    statut           = models.CharField(max_length=20, choices=(
        ('en_attente', 'En attente'),
        ('confirmee',  'Confirmée'),
        ('declinee',   'Déclinée'),
        ('terminee',   'Terminée'),
    ), default='en_attente')
    date_reservation = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.passager.username} → {self.trajet}"


# ----------------- Paiement -----------------
class Paiement(models.Model):
    class Statut(models.TextChoices):
        EN_ATTENTE_CONFIRMATION = "EN_ATTENTE_CONFIRMATION"
        CONFIRME = "CONFIRME"
        ANNULE = "ANNULE"
        # Anciens statuts pour compatibilité mobile money
        EN_ATTENTE = "EN_ATTENTE"  # Pour mobile money
        PAYEE = "PAYEE"           # Pour mobile money
        ECHOUEE = "ECHOUEE"       # Pour mobile money
    
    reservation = models.OneToOneField(Reservation, on_delete=models.CASCADE, related_name='paiement')
    passager = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name="paiements", null=True, blank=True)
    conducteur = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name="paiements_conducteur", null=True, blank=True)
    
    montant = models.DecimalField(max_digits=10, decimal_places=2)
    moyen_paiement = models.CharField(max_length=20, default="ESPECE")
    
    statut = models.CharField(
        max_length=30,
        choices=Statut.choices,
        default=Statut.EN_ATTENTE_CONFIRMATION
    )
    
    date_creation = models.DateTimeField(auto_now_add=True, null=True, blank=True)
    date_confirmation = models.DateTimeField(null=True, blank=True)
    date_payement = models.DateTimeField(null=True, blank=True)  # Pour compatibilité mobile money

    def __str__(self):
        return f"{self.reservation} → {self.statut}"


# ----------------- Évaluation -----------------
class Evaluation(models.Model):
    trajet          = models.ForeignKey(Trajet, on_delete=models.CASCADE, related_name='evaluations')
    auteur          = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='evaluations_donnees')
    cible           = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='evaluations_recues')
    note            = models.IntegerField()
    commentaire     = models.TextField(blank=True)
    date_evaluation = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.auteur} → {self.cible}: {self.note}/5"


# ----------------- Messagerie -----------------
class Message(models.Model):
    expediteur   = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='messages_envoyes')
    destinataire = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='messages_recus')
    contenu      = models.TextField()
    trajet       = models.ForeignKey(Trajet, on_delete=models.SET_NULL, null=True, blank=True)
    created_at   = models.DateTimeField(auto_now_add=True)
    lu           = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.expediteur} → {self.destinataire}"


class Appel(models.Model):
    appelant       = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='appels_faits')
    destinataire   = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='appels_recus')
    trajet         = models.ForeignKey(Trajet, on_delete=models.SET_NULL, null=True, blank=True)
    date_appel     = models.DateTimeField(auto_now_add=True)
    duree_secondes = models.IntegerField(null=True, blank=True)


# ----------------- Notification -----------------
class Notification(models.Model):
    utilisateur       = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='notifications')
    contenu           = models.TextField()
    lu                = models.BooleanField(default=False)
    date_notification = models.DateTimeField(auto_now_add=True)


# ----------------- Statistiques -----------------
class Statistique(models.Model):
    trajet             = models.OneToOneField(Trajet, on_delete=models.CASCADE, related_name='statistique')
    total_reservations = models.IntegerField(default=0)
    revenu_total       = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    note_moyenne       = models.FloatField(default=0)


class StatistiqueEconomie(models.Model):
    """Statistiques économiques pour un utilisateur sur une période donnée"""
    utilisateur = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='statistiques_economie')
    periode_debut = models.DateField()
    periode_fin = models.DateField()
    
    # Pour conducteurs
    total_revenus = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    total_trajets = models.IntegerField(default=0)
    total_km = models.FloatField(default=0)
    moyenne_par_trajet = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    
    # Pour passagers  
    total_economies = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    total_reservations = models.IntegerField(default=0)
    moyenne_par_reservation = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    
    # Comparaison avec transport individuel
    economie_carburant = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    co2_evite = models.FloatField(default=0)  # en kg
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        unique_together = ['utilisateur', 'periode_debut', 'periode_fin']
        ordering = ['-periode_debut']
    
    def __str__(self):
        return f"Stats {self.utilisateur.username} {self.periode_debut} - {self.periode_fin}"


class RevenuMensuel(models.Model):
    """Suivi des revenus mensuels pour les conducteurs"""
    conducteur = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='revenus_mensuels')
    annee = models.IntegerField()
    mois = models.IntegerField()
    
    revenu_total = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    nombre_trajets = models.IntegerField(default=0)
    km_parcourus = models.FloatField(default=0)
    revenu_moyen_trajet = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        unique_together = ['conducteur', 'annee', 'mois']
        ordering = ['-annee', '-mois']
    
    def __str__(self):
        return f"{self.conducteur.username} - {self.annee}/{self.mois}: {self.revenu_total}F"


class EconomieMensuelle(models.Model):
    """Suivi des économies mensuelles pour les passagers"""
    passager = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='economies_mensuelles')
    annee = models.IntegerField()
    mois = models.IntegerField()
    
    economie_totale = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    nombre_reservations = models.IntegerField(default=0)
    economie_moyenne_reservation = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    
    # Comparaison avec prix taxi/transport individuel estimé
    cout_transport_individuel = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    cout_covoiturage = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        unique_together = ['passager', 'annee', 'mois']
        ordering = ['-annee', '-mois']
    
    def __str__(self):
        return f"{self.passager.username} - {self.annee}/{self.mois}: {self.economie_totale}F économisés"