from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('messagerie', '0002_message_features'),
        ('modeles', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='conversation',
            name='type',
            field=models.CharField(
                choices=[('private', 'Privé'), ('trajet', 'Groupe trajet')],
                default='private',
                db_index=True,
                max_length=10,
            ),
        ),
        migrations.AddField(
            model_name='conversation',
            name='titre',
            field=models.CharField(blank=True, max_length=200, null=True),
        ),
        migrations.AddField(
            model_name='conversation',
            name='trajet',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='groupe_conversations',
                to='modeles.trajet',
            ),
        ),
        migrations.AddIndex(
            model_name='conversation',
            index=models.Index(fields=['trajet', 'type'], name='messagerie_trajet_type_idx'),
        ),
        migrations.AddConstraint(
            model_name='conversation',
            constraint=models.UniqueConstraint(
                condition=models.Q(type='trajet'),
                fields=['trajet'],
                name='unique_groupe_par_trajet',
            ),
        ),
    ]
