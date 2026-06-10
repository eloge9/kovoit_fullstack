"""Migration initiale — module vérification conducteurs KOVOIT."""
import django.db.models.deletion
import django.utils.timezone
import uuid
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ('modeles', '0022_utilisateur_driver_verification_fields'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='DriverProfile',
            fields=[
                ('id',                   models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True)),
                ('status',               models.CharField(
                    choices=[
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
                    ],
                    db_index=True, default='DOCUMENTS_MISSING', max_length=30
                )),
                ('is_verified',          models.BooleanField(default=False)),
                ('date_naissance',       models.DateField(blank=True, null=True)),
                ('lieu_naissance',       models.CharField(blank=True, max_length=100)),
                ('adresse',              models.TextField(blank=True)),
                ('ville',                models.CharField(blank=True, max_length=100)),
                ('numero_permis',        models.CharField(blank=True, max_length=50)),
                ('categorie_permis',     models.CharField(blank=True, max_length=20)),
                ('date_emission_permis', models.DateField(blank=True, null=True)),
                ('date_expiration_permis', models.DateField(blank=True, null=True)),
                ('experience_annees',    models.IntegerField(default=0)),
                ('note_moyenne',         models.FloatField(default=0.0)),
                ('nombre_trajets',       models.IntegerField(default=0)),
                ('nombre_annulations',   models.IntegerField(default=0)),
                ('created_at',           models.DateTimeField(auto_now_add=True)),
                ('updated_at',           models.DateTimeField(auto_now=True)),
                ('verified_at',          models.DateTimeField(blank=True, null=True)),
                ('suspended_at',         models.DateTimeField(blank=True, null=True)),
                ('motif_suspension',     models.TextField(blank=True)),
                ('motif_rejet',          models.TextField(blank=True)),
                ('user',                 models.OneToOneField(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='driver_profile',
                    to=settings.AUTH_USER_MODEL,
                )),
            ],
            options={'verbose_name': 'Profil conducteur', 'verbose_name_plural': 'Profils conducteurs', 'ordering': ['-created_at']},
        ),
        migrations.CreateModel(
            name='DriverDocument',
            fields=[
                ('id',               models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True)),
                ('document_type',    models.CharField(
                    choices=[
                        ('CNI', "Carte nationale d'identité"),
                        ('PASSPORT', 'Passeport'),
                        ('SELFIE_ID', "Selfie avec pièce d'identité"),
                        ('PORTRAIT', 'Photo portrait récente'),
                        ('DRIVING_LICENSE', 'Permis de conduire'),
                        ('VEHICLE_REGISTRATION', 'Carte grise'),
                        ('INSURANCE', "Attestation d'assurance"),
                        ('TECHNICAL_INSPECTION', 'Contrôle technique'),
                        ('VEHICLE_FRONT', 'Photo véhicule — Face avant'),
                        ('VEHICLE_REAR', 'Photo véhicule — Face arrière'),
                        ('VEHICLE_LEFT', 'Photo véhicule — Côté gauche'),
                        ('VEHICLE_RIGHT', 'Photo véhicule — Côté droit'),
                        ('VEHICLE_INTERIOR_FRONT', 'Photo véhicule — Intérieur avant'),
                        ('VEHICLE_INTERIOR_REAR', 'Photo véhicule — Intérieur arrière'),
                        ('PROOF_OF_ADDRESS', 'Justificatif de domicile'),
                        ('TRANSFER_CERTIFICATE', 'Certificat de cession'),
                        ('OWNER_AUTHORIZATION', 'Autorisation propriétaire'),
                    ],
                    max_length=30
                )),
                ('status',           models.CharField(
                    choices=[
                        ('PENDING', 'En attente'),
                        ('PROCESSING', 'En cours de traitement'),
                        ('VERIFIED', 'Vérifié'),
                        ('REJECTED', 'Rejeté'),
                        ('EXPIRED', 'Expiré'),
                    ],
                    default='PENDING', max_length=20
                )),
                ('file',             models.FileField(upload_to='verification/documents/%Y/%m/')),
                ('file_name',        models.CharField(max_length=255)),
                ('file_size',        models.IntegerField(default=0)),
                ('file_type',        models.CharField(max_length=50)),
                ('ocr_data',         models.JSONField(blank=True, default=dict)),
                ('date_emission',    models.DateField(blank=True, null=True)),
                ('date_expiration',  models.DateField(blank=True, null=True)),
                ('rejection_reason', models.TextField(blank=True)),
                ('uploaded_at',      models.DateTimeField(auto_now_add=True)),
                ('verified_at',      models.DateTimeField(blank=True, null=True)),
                ('driver_profile',   models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='documents', to='verification.driverprofile',
                )),
            ],
            options={'verbose_name': 'Document conducteur', 'verbose_name_plural': 'Documents conducteurs', 'ordering': ['-uploaded_at']},
        ),
        migrations.AddConstraint(
            model_name='driverdocument',
            constraint=models.UniqueConstraint(fields=['driver_profile', 'document_type'], name='unique_driver_document_type'),
        ),
        migrations.CreateModel(
            name='VerificationReport',
            fields=[
                ('id',                      models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True)),
                ('ocr_report',              models.JSONField(blank=True, default=dict)),
                ('identity_report',         models.JSONField(blank=True, default=dict)),
                ('vehicle_report',          models.JSONField(blank=True, default=dict)),
                ('insurance_report',        models.JSONField(blank=True, default=dict)),
                ('technical_report',        models.JSONField(blank=True, default=dict)),
                ('fraud_report',            models.JSONField(blank=True, default=dict)),
                ('compliance_report',       models.JSONField(blank=True, default=dict)),
                ('decision',                models.CharField(
                    blank=True, max_length=20, null=True,
                    choices=[
                        ('APPROVED', 'Approuvé'),
                        ('REJECTED', 'Rejeté'),
                        ('MANUAL_REVIEW', 'Révision manuelle requise'),
                    ]
                )),
                ('overall_score',           models.FloatField(default=0)),
                ('fraud_score',             models.FloatField(default=0)),
                ('confidence_score',        models.FloatField(default=0)),
                ('summary',                 models.TextField(blank=True)),
                ('started_at',              models.DateTimeField(blank=True, null=True)),
                ('completed_at',            models.DateTimeField(blank=True, null=True)),
                ('processing_time_seconds', models.FloatField(blank=True, null=True)),
                ('created_at',              models.DateTimeField(auto_now_add=True)),
                ('driver_profile',          models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='verification_reports', to='verification.driverprofile',
                )),
            ],
            options={'ordering': ['-created_at']},
        ),
        migrations.CreateModel(
            name='AdminReview',
            fields=[
                ('id',         models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True)),
                ('action',     models.CharField(
                    choices=[
                        ('APPROVE', 'Approuver'),
                        ('REJECT', 'Rejeter'),
                        ('SUSPEND', 'Suspendre'),
                        ('BLOCK', 'Bloquer'),
                        ('REACTIVATE', 'Réactiver'),
                    ],
                    max_length=20
                )),
                ('motif',      models.TextField(blank=True)),
                ('notes',      models.TextField(blank=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('admin',      models.ForeignKey(
                    null=True, on_delete=django.db.models.deletion.SET_NULL,
                    related_name='driver_reviews_done', to=settings.AUTH_USER_MODEL,
                )),
                ('driver_profile', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='admin_reviews', to='verification.driverprofile',
                )),
                ('verification_report', models.ForeignKey(
                    blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL,
                    to='verification.verificationreport',
                )),
            ],
            options={'ordering': ['-created_at']},
        ),
        migrations.CreateModel(
            name='VerificationHistory',
            fields=[
                ('id',           models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True)),
                ('old_status',   models.CharField(blank=True, max_length=30)),
                ('new_status',   models.CharField(max_length=30)),
                ('reason',       models.TextField(blank=True)),
                ('is_automatic', models.BooleanField(default=False)),
                ('created_at',   models.DateTimeField(auto_now_add=True)),
                ('changed_by',   models.ForeignKey(
                    blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL,
                    to=settings.AUTH_USER_MODEL,
                )),
                ('driver_profile', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='history', to='verification.driverprofile',
                )),
            ],
            options={'ordering': ['-created_at']},
        ),
        migrations.CreateModel(
            name='DriverSignal',
            fields=[
                ('id',           models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True)),
                ('signal_type',  models.CharField(
                    choices=[
                        ('DANGEROUS_DRIVING', 'Conduite dangereuse'),
                        ('FAKE_DOCUMENTS', 'Faux documents'),
                        ('SCAM', 'Arnaque'),
                        ('INAPPROPRIATE_BEHAVIOR', 'Comportement inapproprié'),
                        ('OTHER', 'Autre'),
                    ],
                    max_length=30
                )),
                ('description',  models.TextField()),
                ('is_processed', models.BooleanField(default=False)),
                ('admin_notes',  models.TextField(blank=True)),
                ('created_at',   models.DateTimeField(auto_now_add=True)),
                ('processed_at', models.DateTimeField(blank=True, null=True)),
                ('driver_profile', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='signals', to='verification.driverprofile',
                )),
                ('reporter', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='signals_made', to=settings.AUTH_USER_MODEL,
                )),
                ('trajet', models.ForeignKey(
                    blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL,
                    related_name='driver_signals', to='modeles.trajet',
                )),
            ],
            options={'ordering': ['-created_at']},
        ),
    ]
