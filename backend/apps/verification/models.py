"""Modèles pour le système de vérification des conducteurs KOVOIT."""
import uuid
from django.db import models
from django.contrib.auth import get_user_model
from django.utils import timezone

User = get_user_model()


class DriverStatus(models.TextChoices):
    DRAFT                = 'DRAFT',                'Brouillon'
    DOCUMENTS_MISSING    = 'DOCUMENTS_MISSING',    'Documents manquants'
    PENDING_AI_REVIEW    = 'PENDING_AI_REVIEW',    'En cours de vérification IA'
    AI_APPROVED          = 'AI_APPROVED',          'Approuvé par IA'
    AI_REJECTED          = 'AI_REJECTED',          'Rejeté par IA'
    PENDING_ADMIN_REVIEW = 'PENDING_ADMIN_REVIEW', 'En attente validation admin'
    ACTIVE               = 'ACTIVE',               'Actif'
    SUSPENDED            = 'SUSPENDED',            'Suspendu'
    BLOCKED              = 'BLOCKED',              'Bloqué'
    REJECTED             = 'REJECTED',             'Rejeté'


class DocumentType(models.TextChoices):
    CNI                    = 'CNI',                    "Carte nationale d'identité"
    PASSPORT               = 'PASSPORT',               'Passeport'
    SELFIE_ID              = 'SELFIE_ID',              "Selfie avec pièce d'identité"
    PORTRAIT               = 'PORTRAIT',               'Photo portrait récente'
    DRIVING_LICENSE        = 'DRIVING_LICENSE',        'Permis de conduire'
    VEHICLE_REGISTRATION   = 'VEHICLE_REGISTRATION',   'Carte grise'
    INSURANCE              = 'INSURANCE',              "Attestation d'assurance"
    TECHNICAL_INSPECTION   = 'TECHNICAL_INSPECTION',   'Contrôle technique'
    VEHICLE_FRONT          = 'VEHICLE_FRONT',          'Photo véhicule — Face avant'
    VEHICLE_REAR           = 'VEHICLE_REAR',           'Photo véhicule — Face arrière'
    VEHICLE_LEFT           = 'VEHICLE_LEFT',           'Photo véhicule — Côté gauche'
    VEHICLE_RIGHT          = 'VEHICLE_RIGHT',          'Photo véhicule — Côté droit'
    VEHICLE_INTERIOR_FRONT = 'VEHICLE_INTERIOR_FRONT', 'Photo véhicule — Intérieur avant'
    VEHICLE_INTERIOR_REAR  = 'VEHICLE_INTERIOR_REAR',  'Photo véhicule — Intérieur arrière'
    PROOF_OF_ADDRESS       = 'PROOF_OF_ADDRESS',       'Justificatif de domicile'
    TRANSFER_CERTIFICATE   = 'TRANSFER_CERTIFICATE',   'Certificat de cession'
    OWNER_AUTHORIZATION    = 'OWNER_AUTHORIZATION',    'Autorisation propriétaire'


# Documents obligatoires pour activer un conducteur
REQUIRED_DOCUMENTS = [
    DocumentType.CNI,
    DocumentType.SELFIE_ID,
    DocumentType.PORTRAIT,
    DocumentType.DRIVING_LICENSE,
    DocumentType.VEHICLE_REGISTRATION,
    DocumentType.INSURANCE,
    DocumentType.TECHNICAL_INSPECTION,
    DocumentType.VEHICLE_FRONT,
    DocumentType.VEHICLE_REAR,
    DocumentType.VEHICLE_LEFT,
    DocumentType.VEHICLE_RIGHT,
    DocumentType.VEHICLE_INTERIOR_FRONT,
    DocumentType.VEHICLE_INTERIOR_REAR,
]

OPTIONAL_DOCUMENTS = [
    DocumentType.PASSPORT,
    DocumentType.PROOF_OF_ADDRESS,
    DocumentType.TRANSFER_CERTIFICATE,
    DocumentType.OWNER_AUTHORIZATION,
]


class DocumentStatus(models.TextChoices):
    PENDING    = 'PENDING',    'En attente'
    PROCESSING = 'PROCESSING', 'En cours de traitement'
    VERIFIED   = 'VERIFIED',   'Vérifié'
    REJECTED   = 'REJECTED',   'Rejeté'
    EXPIRED    = 'EXPIRED',    'Expiré'


class DriverProfile(models.Model):
    """Profil de vérification complet d'un conducteur."""
    id      = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user    = models.OneToOneField(User, on_delete=models.CASCADE, related_name='driver_profile')

    status      = models.CharField(
        max_length=30, choices=DriverStatus.choices,
        default=DriverStatus.DOCUMENTS_MISSING, db_index=True
    )
    is_verified = models.BooleanField(default=False)

    # Infos personnelles conducteur
    date_naissance = models.DateField(null=True, blank=True)
    lieu_naissance = models.CharField(max_length=100, blank=True)
    adresse        = models.TextField(blank=True)
    ville          = models.CharField(max_length=100, blank=True)

    # Permis de conduire
    numero_permis          = models.CharField(max_length=50, blank=True)
    categorie_permis       = models.CharField(max_length=20, blank=True)
    date_emission_permis   = models.DateField(null=True, blank=True)
    date_expiration_permis = models.DateField(null=True, blank=True)
    experience_annees      = models.IntegerField(default=0)

    # Stats conducteur
    note_moyenne      = models.FloatField(default=0.0)
    nombre_trajets    = models.IntegerField(default=0)
    nombre_annulations = models.IntegerField(default=0)

    # Timestamps
    created_at   = models.DateTimeField(auto_now_add=True)
    updated_at   = models.DateTimeField(auto_now=True)
    verified_at  = models.DateTimeField(null=True, blank=True)
    suspended_at = models.DateTimeField(null=True, blank=True)

    # Raisons d'action
    motif_suspension = models.TextField(blank=True)
    motif_rejet      = models.TextField(blank=True)

    class Meta:
        verbose_name         = 'Profil conducteur'
        verbose_name_plural  = 'Profils conducteurs'
        ordering             = ['-created_at']

    def __str__(self):
        return f"DriverProfile({self.user.username}) — {self.status}"

    @property
    def completion_percentage(self):
        uploaded = self.documents.filter(
            document_type__in=REQUIRED_DOCUMENTS,
            status__in=[
                DocumentStatus.VERIFIED,
                DocumentStatus.PENDING,
                DocumentStatus.PROCESSING,
            ]
        ).values_list('document_type', flat=True)
        return int((len(set(uploaded)) / len(REQUIRED_DOCUMENTS)) * 100)

    @property
    def all_required_docs_present(self):
        verified = self.documents.filter(
            document_type__in=REQUIRED_DOCUMENTS,
            status=DocumentStatus.VERIFIED,
        ).values_list('document_type', flat=True)
        return set(REQUIRED_DOCUMENTS).issubset(set(verified))

    @property
    def can_publish_trip(self):
        return self.status == DriverStatus.ACTIVE and self.is_verified


class DriverDocument(models.Model):
    """Document soumis par un conducteur pour vérification."""
    id             = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    driver_profile = models.ForeignKey(DriverProfile, on_delete=models.CASCADE, related_name='documents')
    document_type  = models.CharField(max_length=30, choices=DocumentType.choices)
    status         = models.CharField(
        max_length=20, choices=DocumentStatus.choices, default=DocumentStatus.PENDING
    )

    file      = models.FileField(upload_to='verification/documents/%Y/%m/')
    file_name = models.CharField(max_length=255)
    file_size = models.IntegerField(default=0)
    file_type = models.CharField(max_length=50)

    # Données OCR extraites par l'IA
    ocr_data = models.JSONField(default=dict, blank=True)

    date_emission   = models.DateField(null=True, blank=True)
    date_expiration = models.DateField(null=True, blank=True)

    rejection_reason = models.TextField(blank=True)

    uploaded_at = models.DateTimeField(auto_now_add=True)
    verified_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        verbose_name         = 'Document conducteur'
        verbose_name_plural  = 'Documents conducteurs'
        ordering             = ['-uploaded_at']
        unique_together      = [['driver_profile', 'document_type']]

    def __str__(self):
        return f"{self.driver_profile.user.username} — {self.document_type}"

    @property
    def is_expired(self):
        if self.date_expiration:
            return self.date_expiration < timezone.now().date()
        return False

    @property
    def days_until_expiration(self):
        if self.date_expiration:
            return (self.date_expiration - timezone.now().date()).days
        return None


class VerificationReport(models.Model):
    """Rapport complet de vérification IA pour un conducteur."""
    id             = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    driver_profile = models.ForeignKey(DriverProfile, on_delete=models.CASCADE, related_name='verification_reports')

    # Rapports de chaque agent IA
    ocr_report         = models.JSONField(default=dict, blank=True)
    identity_report    = models.JSONField(default=dict, blank=True)
    vehicle_report     = models.JSONField(default=dict, blank=True)
    insurance_report   = models.JSONField(default=dict, blank=True)
    technical_report   = models.JSONField(default=dict, blank=True)
    fraud_report       = models.JSONField(default=dict, blank=True)
    compliance_report  = models.JSONField(default=dict, blank=True)

    decision = models.CharField(max_length=20, choices=(
        ('APPROVED',       'Approuvé'),
        ('REJECTED',       'Rejeté'),
        ('MANUAL_REVIEW',  'Révision manuelle requise'),
    ), null=True, blank=True)

    overall_score    = models.FloatField(default=0)
    fraud_score      = models.FloatField(default=0)
    confidence_score = models.FloatField(default=0)

    summary = models.TextField(blank=True)

    started_at              = models.DateTimeField(null=True, blank=True)
    completed_at            = models.DateTimeField(null=True, blank=True)
    processing_time_seconds = models.FloatField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Report({self.driver_profile.user.username}) — {self.decision}"


class AdminReview(models.Model):
    """Action d'un admin sur le dossier d'un conducteur."""
    id             = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    driver_profile = models.ForeignKey(DriverProfile, on_delete=models.CASCADE, related_name='admin_reviews')
    admin          = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, related_name='driver_reviews_done'
    )
    verification_report = models.ForeignKey(
        VerificationReport, on_delete=models.SET_NULL, null=True, blank=True
    )

    ACTION_CHOICES = (
        ('APPROVE',     'Approuver'),
        ('REJECT',      'Rejeter'),
        ('SUSPEND',     'Suspendre'),
        ('BLOCK',       'Bloquer'),
        ('REACTIVATE',  'Réactiver'),
    )
    action = models.CharField(max_length=20, choices=ACTION_CHOICES)
    motif  = models.TextField(blank=True)
    notes  = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"AdminReview({self.driver_profile.user.username}) — {self.action} by {self.admin}"


class VerificationHistory(models.Model):
    """Audit trail des changements de statut d'un conducteur."""
    id             = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    driver_profile = models.ForeignKey(DriverProfile, on_delete=models.CASCADE, related_name='history')
    changed_by     = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)

    old_status = models.CharField(max_length=30, blank=True)
    new_status = models.CharField(max_length=30)
    reason     = models.TextField(blank=True)

    is_automatic = models.BooleanField(default=False)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.driver_profile.user.username}: {self.old_status} → {self.new_status}"


class DriverSignal(models.Model):
    """Signalement d'un conducteur par un passager."""
    id             = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    driver_profile = models.ForeignKey(DriverProfile, on_delete=models.CASCADE, related_name='signals')
    reporter       = models.ForeignKey(User, on_delete=models.CASCADE, related_name='signals_made')

    TYPE_CHOICES = (
        ('DANGEROUS_DRIVING',       'Conduite dangereuse'),
        ('FAKE_DOCUMENTS',          'Faux documents'),
        ('SCAM',                    'Arnaque'),
        ('INAPPROPRIATE_BEHAVIOR',  'Comportement inapproprié'),
        ('OTHER',                   'Autre'),
    )
    signal_type = models.CharField(max_length=30, choices=TYPE_CHOICES)
    description = models.TextField()

    trajet = models.ForeignKey(
        'modeles.Trajet', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='driver_signals'
    )

    is_processed = models.BooleanField(default=False)
    admin_notes  = models.TextField(blank=True)

    created_at   = models.DateTimeField(auto_now_add=True)
    processed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Signal({self.driver_profile.user.username}) — {self.signal_type}"
