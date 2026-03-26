""" Models centraliser pour les utilisateur"""
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
        ('passager', 'Passager'),
        ('admin', 'Admin'),
    )
    email = models.EmailField(unique=True)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES)
    numero_telephone = models.CharField(max_length=20, blank=True, null=True)
    photo_profil = models.ImageField(upload_to='profils/', blank=True, null=True)
    note = models.FloatField(default=0)  # Moyenne des évaluations

    REQUIRED_FIELDS = ['email', 'role']

    def __str__(self):
        return f"{self.username} ({self.role})"


# ----------------- Profils -----------------
class Admin(models.Model):
    utilisateur = models.OneToOneField(Utilisateur, on_delete=models.CASCADE, related_name='profil_admin')
    # Champs spécifiques admin
    permissions_specifiques = models.TextField(blank=True)

    def __str__(self):
        return f"Profil Admin: {self.utilisateur.username}"


class Conducteur(models.Model):
    utilisateur = models.OneToOneField(Utilisateur, on_delete=models.CASCADE, related_name='profil_conducteur')
    numero_permis = models.CharField(max_length=50)
    vehicule = models.CharField(max_length=100)
    couleur_vehicule = models.CharField(max_length=50)
    type_vehicule = models.CharField(max_length=50)
    plaque = models.CharField(max_length=20)
    experience_annees = models.IntegerField(default=0)

    def __str__(self):
        return f"Profil Conducteur: {self.utilisateur.username}"


class Passager(models.Model):
    utilisateur = models.OneToOneField(Utilisateur, on_delete=models.CASCADE, related_name='profil_passager')
    historique_points = models.IntegerField(default=0)

    def __str__(self):
        return f"Profil Passager: {self.utilisateur.username}"


# ----------------- Trajet -----------------
class Trajet(models.Model):
    conducteur = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='trajets')
    depart = models.CharField(max_length=255)
    destination = models.CharField(max_length=255)

    # Coordonnées GPS (alignées avec les migrations et serializer)
    depart_lat = models.FloatField()
    depart_lng = models.FloatField()
    destination_lat = models.FloatField()
    destination_lng = models.FloatField()

    # Champs supplémentaires ajoutés par migrations
    distance_km = models.FloatField(null=True, blank=True)
    cout_total = models.FloatField(null=True, blank=True)
    escales = models.JSONField(default=list, blank=True)
    est_regulier = models.BooleanField(default=False)
    jours_semaine = models.JSONField(blank=True, null=True)

    date_heure_depart = models.DateTimeField()
    places_disponibles = models.IntegerField()
    prix_par_place = models.DecimalField(max_digits=10, decimal_places=2)
    description = models.TextField(blank=True)
    statut = models.CharField(
        max_length=20,
        choices=(
            ('ouvert', 'Ouvert'),
            ('termine', 'Terminé'),
            ('annule', 'Annulé')
        ),
        default='ouvert'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-date_heure_depart']

    def __str__(self):
        return f"{self.depart} → {self.destination} ({self.conducteur.username})"




# ----------------- Réservation -----------------
class Reservation(models.Model):
    trajet = models.ForeignKey(Trajet, on_delete=models.CASCADE, related_name='reservations')
    passager = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='reservations')
    places_reservees = models.IntegerField(default=1)
    statut = models.CharField(max_length=20, choices=(
        ('en_attente', 'En attente'),
        ('confirmee', 'Confirmée'),
        ('declinee', 'Déclinée')
    ), default='en_attente')
    date_reservation = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.passager.username} → {self.trajet}"


# ----------------- Paiement -----------------
class Paiement(models.Model):
    reservation = models.OneToOneField(Reservation, on_delete=models.CASCADE, related_name='paiement')
    montant = models.DecimalField(max_digits=10, decimal_places=2)
    moyen_paiement = models.CharField(max_length=50)  # ex: carte, paypal
    statut = models.CharField(max_length=20, choices=(
        ('en_attente', 'En attente'),
        ('payee', 'Payée'),
        ('echouee', 'Échouée')
    ), default='en_attente')
    date_payement = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return f"{self.reservation} → {self.statut}"


# ----------------- Évaluation -----------------
class Evaluation(models.Model):
    trajet = models.ForeignKey(Trajet, on_delete=models.CASCADE, related_name='evaluations')
    auteur = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='evaluations_donnees')
    cible = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='evaluations_recues')
    note = models.IntegerField()  # 1 à 5
    commentaire = models.TextField(blank=True)
    date_evaluation = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.auteur} → {self.cible}: {self.note}/5"


# ----------------- Messagerie -----------------
class Message(models.Model):
    expediteur = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='messages_envoyes')
    destinataire = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='messages_reçus')
    contenu = models.TextField()
    trajet = models.ForeignKey(Trajet, on_delete=models.SET_NULL, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    lu = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.expediteur} → {self.destinataire}"


class Appel(models.Model):
    appelant = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='appels_faits')
    destinataire = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='appels_recus')
    trajet = models.ForeignKey(Trajet, on_delete=models.SET_NULL, null=True, blank=True)
    date_appel = models.DateTimeField(auto_now_add=True)
    duree_secondes = models.IntegerField(null=True, blank=True)


# ----------------- Notification -----------------
class Notification(models.Model):
    utilisateur = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='notifications')
    contenu = models.TextField()
    lu = models.BooleanField(default=False)
    date_notification = models.DateTimeField(auto_now_add=True)


# ----------------- Statistiques -----------------
class Statistique(models.Model):
    trajet = models.OneToOneField(Trajet, on_delete=models.CASCADE, related_name='statistique')
    total_reservations = models.IntegerField(default=0)
    revenu_total = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    note_moyenne = models.FloatField(default=0)