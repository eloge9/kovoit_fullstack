"""Ajout des champs de vérification conducteur sur le modèle Utilisateur."""
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('modeles', '0021_rename_modeles_blo_conduct_idx_modeles_blo_conduct_b4cdc9_idx_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='utilisateur',
            name='is_driver',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='utilisateur',
            name='is_driver_verified',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='utilisateur',
            name='driver_status',
            field=models.CharField(
                blank=True,
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
                default='DOCUMENTS_MISSING',
                max_length=30,
            ),
        ),
    ]
