"""Models centralisés pour les utilisateurs"""
import uuid
import random
import string
from django.db import models
from django.contrib.auth.models import AbstractUser
from django.utils import timezone
from django.core.exceptions import ValidationError


def _generer_code_embarquement():
    """Génère un code PIN unique de type KVT-XXXX."""
    return "KVT-" + "".join(random.choices(string.digits, k=4))
from .validators import (
    validate_positive_number, validate_rating,
    validate_gps_latitude, validate_gps_coordinate,
    valider_image_profil, valider_image_document,
)


def chemin_photo(instance, filename):
    ext = filename.split('.')[-1]
    return f"profils/{instance.pk}/{instance.pk}.{ext}"


STATUT_VALIDATION_CHOICES = (
    ('non_soumis', 'Non soumis'),
    ('en_attente', 'En attente de validation'),
    ('valide',     'Validé'),
    ('rejete',     'Rejeté'),
)


# ----------------- Utilisateur -----------------
class Utilisateur(AbstractUser):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    class Role(models.TextChoices):
        CONDUCTEUR = 'conducteur', 'Conducteur'
        PASSAGER   = 'passager',   'Passager'
        ADMIN      = 'admin',      'Admin'

    # Gardé pour la compatibilité des vieux imports
    ROLE_CHOICES = Role.choices

    email            = models.EmailField(unique=True)
    role             = models.CharField(max_length=20, choices=Role.choices)
    numero_telephone = models.CharField(max_length=20, blank=True, null=True)
    photo_profil     = models.ImageField(
        upload_to=chemin_photo, blank=True, null=True,
        validators=[valider_image_profil],
    )
    note             = models.FloatField(default=0)

    # --- Documents d'identité (CNI / Permis) ---
    photo_cni    = models.ImageField(
        upload_to='documents/cni/', blank=True, null=True,
        validators=[valider_image_document],
    )
    photo_permis = models.ImageField(
        upload_to='documents/permis/', blank=True, null=True,
        validators=[valider_image_document],
    )
    statut_validation = models.CharField(
        max_length=20, choices=STATUT_VALIDATION_CHOICES, default='non_soumis'
    )

    # --- Double rôle ---
    # True quand l'admin a validé les documents conducteur.
    # Permet à un passager de basculer en mode conducteur sans re-soumettre.
    peut_conduire = models.BooleanField(default=False)

    # --- Système de vérification conducteur ---
    is_driver          = models.BooleanField(default=False)
    is_driver_verified = models.BooleanField(default=False)
    driver_status      = models.CharField(
        max_length=30,
        choices=(
            ('DRAFT',                'Brouillon'),
            ('DOCUMENTS_MISSING',    'Documents manquants'),
            ('PENDING_AI_REVIEW',    'En cours de vérification IA'),
            ('AI_APPROVED',          'Approuvé par IA'),
            ('AI_REJECTED',          'Rejeté par IA'),
            ('PENDING_ADMIN_REVIEW', 'En attente validation admin'),
            ('ACTIVE',               'Actif'),
            ('SUSPENDED',            'Suspendu'),
            ('BLOCKED',              'Bloqué'),
            ('REJECTED',             'Rejeté'),
        ),
        default='DOCUMENTS_MISSING',
        blank=True,
    )

    # --- Contact d'urgence (obligatoire pour le bouton SOS) ---
    contact_urgence_nom       = models.CharField(max_length=100, blank=True, default='')
    contact_urgence_telephone = models.CharField(max_length=20,  blank=True, default='')

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
    conducteur        = models.ForeignKey(Conducteur, on_delete=models.CASCADE, related_name='vehicules')
    type_vehicule     = models.CharField(max_length=20, choices=TYPE_VEHICULE_CHOICES)
    marque            = models.CharField(max_length=100)
    modele            = models.CharField(max_length=100)
    couleur           = models.CharField(max_length=50)
    plaque            = models.CharField(max_length=20, unique=True)
    places_max        = models.IntegerField(validators=[validate_positive_number])
    est_actif         = models.BooleanField(default=True)
    photo_carte_grise = models.ImageField(
        upload_to='documents/carte_grise/', blank=True, null=True,
        validators=[valider_image_document],
    )
    created_at        = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.marque} {self.modele} ({self.plaque})"
    
    class Meta:
        indexes = [
            models.Index(fields=['conducteur', 'est_actif']),
        ]


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
    depart_lat      = models.FloatField(null=True, blank=True, validators=[validate_gps_latitude])
    depart_lng      = models.FloatField(null=True, blank=True, validators=[validate_gps_coordinate])
    destination_lat = models.FloatField(null=True, blank=True, validators=[validate_gps_latitude])
    destination_lng = models.FloatField(null=True, blank=True, validators=[validate_gps_coordinate])

    distance_km    = models.FloatField(null=True, blank=True, validators=[validate_positive_number])
    cout_total     = models.FloatField(null=True, blank=True, validators=[validate_positive_number])
    prix_par_place = models.DecimalField(max_digits=10, decimal_places=2, validators=[validate_positive_number])

    date_heure_depart  = models.DateTimeField()
    places_disponibles = models.IntegerField(validators=[validate_positive_number])
    description        = models.TextField(blank=True)

    est_regulier  = models.BooleanField(default=False)
    jours_semaine = models.JSONField(null=True, blank=True)

    # Itinéraire encodé (polyline OSRM) pour le matching géographique
    polyline            = models.TextField(blank=True, default='')
    polyline_stored     = models.BooleanField(default=False, db_index=True)
    # Détour maximum accepté pour embarquer un passager hors route (km)
    tolerance_detour_km = models.FloatField(default=2.0)

    statut = models.CharField(max_length=20, choices=(
        ('ouvert',   'Ouvert'),
        ('en_cours', 'En cours'),
        ('termine',  'Terminé'),
        ('annule',   'Annulé'),
    ), default='ouvert', db_index=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def clean(self):
        """Validations additionnelles"""
        if self.date_heure_depart <= timezone.now():
            raise ValidationError("Le départ doit être dans le futur.")
        if self.date_heure_depart > timezone.now() + timezone.timedelta(days=180):
            raise ValidationError("Le départ ne peut pas être plus de 6 mois à l'avance.")

    def save(self, *args, **kwargs):
        # Valider avant de sauvegarder
        self.full_clean()
        
        # Vérifier si le statut change
        old_statut = None
        if self.pk:
            old_instance = Trajet.objects.get(pk=self.pk)
            old_statut = old_instance.statut
        
        super().save(*args, **kwargs)
        
        # Mettre à jour les réservations si le trajet est terminé
        if self.statut == 'termine' and old_statut != 'termine':
            self.reservations.filter(statut='confirmee').update(statut='terminee')
        elif self.statut == 'annule' and old_statut != 'annule':
            # Si le trajet est annulé, annuler aussi les réservations en attente/confirmées
            self.reservations.filter(statut__in=['en_attente', 'confirmee']).update(statut='declinee')

    class Meta:
        ordering = ['-date_heure_depart']
        indexes = [
            models.Index(fields=['conducteur', '-date_heure_depart']),
            models.Index(fields=['statut', '-date_heure_depart']),
            models.Index(fields=['-date_heure_depart']),
            models.Index(fields=['statut', 'polyline_stored'], name='trajet_statut_poly_idx'),
        ]

    def __str__(self):
        return f"{self.depart} → {self.destination} ({self.conducteur.username})"


# ----------------- Escale (TripStop) -----------------
class TripStop(models.Model):
    """Escale intermédiaire d'un trajet (ex: Lomé → Tsévié → Kpalimé)."""
    STATUT_CHOICES = [
        ('en_attente', 'En attente'),
        ('arrive',     'Arrivé'),
        ('parti',      'Parti'),
    ]

    trajet       = models.ForeignKey(Trajet, on_delete=models.CASCADE, related_name='escales')
    nom          = models.CharField(max_length=200)
    lat          = models.FloatField()
    lng          = models.FloatField()
    ordre        = models.IntegerField(help_text="0=départ, 1,2…=escales, dernier=destination")
    heure_prevue = models.DateTimeField(null=True, blank=True)
    heure_reelle = models.DateTimeField(null=True, blank=True)
    statut       = models.CharField(max_length=20, choices=STATUT_CHOICES, default='en_attente')

    class Meta:
        ordering = ['ordre']
        unique_together = [['trajet', 'ordre']]

    def __str__(self):
        return f"{self.nom} — étape {self.ordre} de {self.trajet}"


# ----------------- Réservation -----------------
class Reservation(models.Model):
    trajet           = models.ForeignKey(Trajet, on_delete=models.CASCADE, related_name='reservations')
    passager         = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='reservations')
    places_reservees = models.IntegerField(default=1, validators=[validate_positive_number])
    statut           = models.CharField(max_length=20, choices=(
        ('en_attente', 'En attente'),
        ('confirmee',  'Confirmée'),
        ('declinee',   'Déclinée'),
        ('terminee',   'Terminée'),
    ), default='en_attente')
    date_reservation = models.DateTimeField(auto_now_add=True)

    # ── Boarding intermédiaire ────────────────────────────────────────────────
    # Le passager peut monter/descendre à des points différents du départ/destination du trajet
    point_prise_en_charge = models.CharField(max_length=200, blank=True, default='')
    prise_en_charge_lat   = models.FloatField(null=True, blank=True)
    prise_en_charge_lng   = models.FloatField(null=True, blank=True)

    point_depose = models.CharField(max_length=200, blank=True, default='')
    depose_lat   = models.FloatField(null=True, blank=True)
    depose_lng   = models.FloatField(null=True, blank=True)

    # ── Tarification proportionnelle ─────────────────────────────────────────
    distance_passager = models.FloatField(null=True, blank=True)            # km réels du passager
    prix_passager     = models.DecimalField(max_digits=10, decimal_places=0, null=True, blank=True)

    # ── Code d'embarquement (QR + PIN) ───────────────────────────────────────
    code_embarquement = models.CharField(max_length=10, unique=True, null=True, blank=True)
    qr_token          = models.UUIDField(default=uuid.uuid4, null=True, blank=True)

    # ── Suivi embarquement ───────────────────────────────────────────────────
    statut_embarquement = models.CharField(max_length=20, choices=[
        ('en_attente', 'En attente'),
        ('embarque',   'Embarqué'),
        ('depose',     'Déposé'),
    ], default='en_attente')
    heure_embarquement = models.DateTimeField(null=True, blank=True)
    heure_depose       = models.DateTimeField(null=True, blank=True)

    # ── Pénalité annulation tardive (<2h avant départ) ───────────────────────
    penalite_annulation = models.DecimalField(max_digits=10, decimal_places=0, default=0)

    def clean(self):
        """Valider que le passager ne réserve pas 2x le même trajet"""
        if Reservation.objects.filter(
            trajet=self.trajet,
            passager=self.passager,
            statut__in=['en_attente', 'confirmee']
        ).exclude(pk=self.pk).exists():
            raise ValidationError("Vous avez déjà réservé ce trajet.")
        if self.places_reservees > self.trajet.places_disponibles:
            raise ValidationError(f"Seulement {self.trajet.places_disponibles} places disponibles.")

    def save(self, *args, **kwargs):
        # Générer le code d'embarquement unique à la première sauvegarde
        if not self.code_embarquement:
            code = _generer_code_embarquement()
            while Reservation.objects.filter(code_embarquement=code).exists():
                code = _generer_code_embarquement()
            self.code_embarquement = code
        self.full_clean()
        super().save(*args, **kwargs)

    class Meta:
        unique_together = [['trajet', 'passager']]
        indexes = [
            models.Index(fields=['passager', '-date_reservation']),
            models.Index(fields=['statut']),
        ]

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
    
    montant          = models.DecimalField(max_digits=10, decimal_places=2, validators=[validate_positive_number])
    moyen_paiement   = models.CharField(max_length=20, default="ESPECE")
    reference_mobile = models.CharField(max_length=100, blank=True, null=True)
    
    statut = models.CharField(
        max_length=30,
        choices=Statut.choices,
        default=Statut.EN_ATTENTE_CONFIRMATION,
        db_index=True
    )
    
    date_creation = models.DateTimeField(auto_now_add=True, null=True, blank=True)
    date_confirmation = models.DateTimeField(null=True, blank=True)
    date_payement = models.DateTimeField(null=True, blank=True)  # Pour compatibilité mobile money

    def clean(self):
        """Valider le paiement"""
        if self.reservation:
            res = self.reservation
            # Utilise prix_passager si défini (boarding intermédiaire), sinon prix_par_place
            prix_unitaire = res.prix_passager if res.prix_passager else res.trajet.prix_par_place
            prix_total = res.places_reservees * prix_unitaire
            if self.montant != prix_total:
                raise ValidationError(f"Montant doit être {prix_total} FCFA pour {res.places_reservees} place(s)")

    def save(self, *args, **kwargs):
        from django.db import transaction
        self.full_clean()
        # Utiliser une transaction atomique pour éviter les double-paiements
        with transaction.atomic():
            super().save(*args, **kwargs)

    class Meta:
        indexes = [
            models.Index(fields=['reservation']),
            models.Index(fields=['statut', '-date_creation']),
        ]

    def __str__(self):
        return f"{self.reservation} → {self.statut}"


# ----------------- Évaluation -----------------
class Evaluation(models.Model):
    PUBLIEE     = 'publiee'
    VERROUILLEE = 'verrouillee'
    STATUT_CHOICES = [(PUBLIEE, 'Publiée'), (VERROUILLEE, 'Verrouillée')]

    trajet          = models.ForeignKey(Trajet, on_delete=models.CASCADE, related_name='evaluations')
    reservation     = models.ForeignKey('Reservation', on_delete=models.SET_NULL, null=True, blank=True, related_name='evaluations')
    auteur          = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='evaluations_donnees')
    cible           = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='evaluations_recues')
    note            = models.IntegerField(validators=[validate_rating])
    commentaire     = models.TextField(blank=True)
    date_evaluation = models.DateTimeField(auto_now_add=True)
    date_limite     = models.DateTimeField(null=True, blank=True)
    statut          = models.CharField(max_length=12, choices=STATUT_CHOICES, default=PUBLIEE, db_index=True)

    # Critères détaillés passager → conducteur
    ponctualite     = models.SmallIntegerField(null=True, blank=True, validators=[validate_rating])
    courtoisie      = models.SmallIntegerField(null=True, blank=True, validators=[validate_rating])
    conduite        = models.SmallIntegerField(null=True, blank=True, validators=[validate_rating])
    respect_trajet  = models.SmallIntegerField(null=True, blank=True, validators=[validate_rating])

    # Critères détaillés conducteur → passager
    respect_conducteur = models.SmallIntegerField(null=True, blank=True, validators=[validate_rating])
    respect_vehicule   = models.SmallIntegerField(null=True, blank=True, validators=[validate_rating])
    communication      = models.SmallIntegerField(null=True, blank=True, validators=[validate_rating])

    signale            = models.BooleanField(default=False)
    motif_signalement  = models.TextField(blank=True, default='')
    date_signalement   = models.DateTimeField(null=True, blank=True)

    class Meta:
        unique_together = [['trajet', 'auteur', 'cible']]
        indexes = [
            models.Index(fields=['cible', '-date_evaluation']),
            models.Index(fields=['auteur', '-date_evaluation']),
            models.Index(fields=['statut', '-date_evaluation']),
        ]

    def __str__(self):
        return f"{self.auteur} → {self.cible}: {self.note}/5"


# ----------------- Blocage passager -----------------
class BlocagePassager(models.Model):
    """Un conducteur bloque un passager (il ne peut plus réserver ses trajets)."""
    conducteur  = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='blocages_effectues')
    passager    = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='blocages_recus')
    motif       = models.TextField(blank=True, default='')
    created_at  = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = [['conducteur', 'passager']]
        indexes = [
            models.Index(fields=['conducteur']),
            models.Index(fields=['passager']),
        ]

    def __str__(self):
        return f"{self.conducteur.username} bloque {self.passager.username}"


# ----------------- Messagerie -----------------
class Message(models.Model):
    expediteur   = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='messages_envoyes')
    destinataire = models.ForeignKey(Utilisateur, on_delete=models.CASCADE, related_name='messages_recus')
    contenu      = models.TextField()
    trajet       = models.ForeignKey(Trajet, on_delete=models.SET_NULL, null=True, blank=True)
    created_at   = models.DateTimeField(auto_now_add=True)
    lu           = models.BooleanField(default=False)

    class Meta:
        indexes = [
            models.Index(fields=['destinataire', 'lu', '-created_at']),
            models.Index(fields=['expediteur', '-created_at']),
        ]
        ordering = ['-created_at']

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


# ------------------- Plainte/Signalement -----------------
class Plainte(models.Model):
    STATUT_CHOICES = (
        ('en_attente', 'En attente'),
        ('en_cours', 'En cours'),
        ('resolue', 'Résolue'),
        ('rejetee', 'Rejetée'),
        ('suspendue', 'Suspendue'),
    )
    
    TYPE_CHOICES = (
        ('conducteur', 'Conducteur'),
        ('passager', 'Passager'),
        ('comportement', 'Comportement'),
        ('vehicule', 'Véhicule'),
        ('autre', 'Autre'),
    )
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    
    # Qui signale (peut être null pour signalements automatiques)
    signalataire = models.ForeignKey(
        Utilisateur, 
        on_delete=models.CASCADE, 
        related_name='plaintes_deposees',
        null=True,
        blank=True
    )
    
    # Qui est signalé
    utilisateur_signale = models.ForeignKey(
        Utilisateur, 
        on_delete=models.CASCADE, 
        related_name='plaintes_recues'
    )
    
    # Contexte
    trajet = models.ForeignKey(
        Trajet, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True, 
        related_name='plaintes'
    )
    
    evaluation = models.ForeignKey(
        Evaluation, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True, 
        related_name='plaintes'
    )
    
    # Détails
    titre = models.CharField(max_length=255)
    description = models.TextField()
    type_plainte = models.CharField(max_length=20, choices=TYPE_CHOICES)
    statut = models.CharField(max_length=20, choices=STATUT_CHOICES, default='en_attente')
    
    # Admin
    note_admin = models.TextField(blank=True, help_text="Notes de l'administrateur")
    admin_assigne = models.ForeignKey(
        Utilisateur,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='plaintes_assignees',
        limit_choices_to={'role': 'admin'}
    )
    
    # Dates
    date_creation = models.DateTimeField(auto_now_add=True)
    date_modification = models.DateTimeField(auto_now=True)
    date_resolution = models.DateTimeField(null=True, blank=True)
    
    class Meta:
        ordering = ['-date_creation']
    
    def __str__(self):
        return f"Plainte {self.titre} - {self.statut}"


# ── Journal d'audit administrateur ──────────────────────────────────────────
class AuditLog(models.Model):
    ACTION_CHOICES = (
        # Utilisateurs
        ('user_suspend',    'Suspension utilisateur'),
        ('user_activate',   'Activation utilisateur'),
        ('user_ban',        'Bannissement utilisateur'),
        ('user_delete',     'Suppression utilisateur'),
        ('user_role',       'Changement de rôle'),
        ('doc_validate',    'Validation documents'),
        ('doc_reject',      'Rejet documents'),
        # Trajets
        ('trip_cancel',     'Annulation trajet'),
        ('trip_delete',     'Suppression trajet'),
        ('trip_modify',     'Modification trajet'),
        # Réservations
        ('resa_cancel',     'Annulation réservation'),
        ('resa_force',      'Forçage réservation'),
        # Paiements
        ('payment_refund',  'Remboursement'),
        # Évaluations
        ('eval_hide',       'Masquage évaluation'),
        ('eval_restore',    'Restauration évaluation'),
        # Plaintes
        ('complaint_assign','Assignation plainte'),
        ('complaint_close', 'Fermeture plainte'),
        ('complaint_reject','Rejet plainte'),
        # Messagerie
        ('msg_read',        'Lecture messages admin'),
        # Config
        ('config_update',   'Mise à jour configuration'),
        # Notifications
        ('notif_send',      'Envoi notification'),
        # Connexion
        ('admin_login',     'Connexion admin'),
    )

    admin       = models.ForeignKey(
        Utilisateur, on_delete=models.SET_NULL, null=True,
        related_name='audit_logs', limit_choices_to={'role': 'admin'}
    )
    action      = models.CharField(max_length=30, choices=ACTION_CHOICES, db_index=True)
    cible_type  = models.CharField(max_length=30, blank=True)
    cible_id    = models.CharField(max_length=50, blank=True)
    description = models.TextField()
    ip_adresse  = models.GenericIPAddressField(null=True, blank=True)
    user_agent  = models.CharField(max_length=255, blank=True)
    date_action = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['-date_action']
        indexes = [
            models.Index(fields=['admin', '-date_action']),
            models.Index(fields=['action', '-date_action']),
            models.Index(fields=['cible_type', 'cible_id']),
        ]

    def __str__(self):
        return f"[{self.date_action.strftime('%d/%m/%Y %H:%M')}] {self.admin} — {self.action}"


# ── Configuration système ────────────────────────────────────────────────────
class SysConfig(models.Model):
    cle              = models.CharField(max_length=60, unique=True, db_index=True)
    valeur           = models.TextField()
    description      = models.CharField(max_length=255, blank=True)
    modifie_par      = models.ForeignKey(
        Utilisateur, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='configs_modifiees'
    )
    date_modification = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['cle']
        verbose_name        = "Configuration système"
        verbose_name_plural = "Configurations système"

    def __str__(self):
        return f"{self.cle} = {self.valeur}"

    @classmethod
    def get(cls, cle: str, default=None):
        try:
            return cls.objects.get(cle=cle).valeur
        except cls.DoesNotExist:
            return default

    @classmethod
    def set(cls, cle: str, valeur, description: str = '', admin=None):
        obj, _ = cls.objects.update_or_create(
            cle=cle,
            defaults={'valeur': str(valeur), 'description': description, 'modifie_par': admin}
        )
        return obj


class PasswordResetCode(models.Model):
    email      = models.EmailField(db_index=True)
    code       = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    used       = models.BooleanField(default=False)

    class Meta:
        ordering = ['-created_at']

    def is_valid(self):
        return not self.used and (timezone.now() - self.created_at).total_seconds() < 600

    def __str__(self):
        return f"Reset {self.email} [{self.code}]"
