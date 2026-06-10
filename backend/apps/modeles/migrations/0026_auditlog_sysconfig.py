from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('modeles', '0025_evaluation_v2'),
    ]

    operations = [
        # ── AuditLog ──────────────────────────────────────────────────────
        migrations.CreateModel(
            name='AuditLog',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ('action', models.CharField(
                    choices=[
                        ('user_suspend',    'Suspension utilisateur'),
                        ('user_activate',   'Activation utilisateur'),
                        ('user_ban',        'Bannissement utilisateur'),
                        ('user_delete',     'Suppression utilisateur'),
                        ('user_role',       'Changement de rôle'),
                        ('doc_validate',    'Validation documents'),
                        ('doc_reject',      'Rejet documents'),
                        ('trip_cancel',     'Annulation trajet'),
                        ('trip_delete',     'Suppression trajet'),
                        ('trip_modify',     'Modification trajet'),
                        ('resa_cancel',     'Annulation réservation'),
                        ('resa_force',      'Forçage réservation'),
                        ('payment_refund',  'Remboursement'),
                        ('eval_hide',       'Masquage évaluation'),
                        ('eval_restore',    'Restauration évaluation'),
                        ('complaint_assign','Assignation plainte'),
                        ('complaint_close', 'Fermeture plainte'),
                        ('complaint_reject','Rejet plainte'),
                        ('msg_read',        'Lecture messages admin'),
                        ('config_update',   'Mise à jour configuration'),
                        ('notif_send',      'Envoi notification'),
                        ('admin_login',     'Connexion admin'),
                    ],
                    db_index=True, max_length=30
                )),
                ('cible_type', models.CharField(blank=True, max_length=30)),
                ('cible_id', models.CharField(blank=True, max_length=50)),
                ('description', models.TextField()),
                ('ip_adresse', models.GenericIPAddressField(blank=True, null=True)),
                ('user_agent', models.CharField(blank=True, max_length=255)),
                ('date_action', models.DateTimeField(auto_now_add=True, db_index=True)),
                ('admin', models.ForeignKey(
                    null=True, on_delete=django.db.models.deletion.SET_NULL,
                    related_name='audit_logs',
                    limit_choices_to={'role': 'admin'},
                    to=settings.AUTH_USER_MODEL,
                )),
            ],
            options={'ordering': ['-date_action']},
        ),
        migrations.AddIndex(
            model_name='auditlog',
            index=models.Index(fields=['admin', '-date_action'], name='auditlog_admin_date_idx'),
        ),
        migrations.AddIndex(
            model_name='auditlog',
            index=models.Index(fields=['action', '-date_action'], name='auditlog_action_date_idx'),
        ),
        migrations.AddIndex(
            model_name='auditlog',
            index=models.Index(fields=['cible_type', 'cible_id'], name='auditlog_cible_idx'),
        ),

        # ── SysConfig ─────────────────────────────────────────────────────
        migrations.CreateModel(
            name='SysConfig',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ('cle', models.CharField(db_index=True, max_length=60, unique=True)),
                ('valeur', models.TextField()),
                ('description', models.CharField(blank=True, max_length=255)),
                ('date_modification', models.DateTimeField(auto_now=True)),
                ('modifie_par', models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='configs_modifiees',
                    to=settings.AUTH_USER_MODEL,
                )),
            ],
            options={
                'verbose_name': 'Configuration système',
                'verbose_name_plural': 'Configurations système',
                'ordering': ['cle'],
            },
        ),
    ]
