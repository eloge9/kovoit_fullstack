from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('modeles', '0023_tripstop_boarding_fields'),
    ]

    operations = [
        migrations.AddField(
            model_name='trajet',
            name='polyline_stored',
            field=models.BooleanField(db_index=True, default=False),
        ),
        migrations.AddIndex(
            model_name='trajet',
            index=models.Index(
                fields=['statut', 'polyline_stored'],
                name='trajet_statut_poly_idx',
            ),
        ),
    ]
