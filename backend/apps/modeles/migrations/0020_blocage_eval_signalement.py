from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('modeles', '0019_utilisateur_contact_urgence'),
    ]

    operations = [
        # Champs signalement sur Evaluation
        migrations.AddField(
            model_name='evaluation',
            name='signale',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='evaluation',
            name='motif_signalement',
            field=models.TextField(blank=True, default=''),
        ),
        migrations.AddField(
            model_name='evaluation',
            name='date_signalement',
            field=models.DateTimeField(blank=True, null=True),
        ),
        # Nouveau modèle BlocagePassager
        migrations.CreateModel(
            name='BlocagePassager',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('motif', models.TextField(blank=True, default='')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('conducteur', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='blocages_effectues',
                    to=settings.AUTH_USER_MODEL,
                )),
                ('passager', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='blocages_recus',
                    to=settings.AUTH_USER_MODEL,
                )),
            ],
            options={
                'unique_together': {('conducteur', 'passager')},
            },
        ),
        migrations.AddIndex(
            model_name='blocagepassager',
            index=models.Index(fields=['conducteur'], name='modeles_blo_conduct_idx'),
        ),
        migrations.AddIndex(
            model_name='blocagepassager',
            index=models.Index(fields=['passager'], name='modeles_blo_passager_idx'),
        ),
    ]
