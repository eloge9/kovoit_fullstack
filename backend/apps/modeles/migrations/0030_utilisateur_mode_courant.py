from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('modeles', '0029_alter_paiement_statut'),
    ]

    operations = [
        migrations.AddField(
            model_name='utilisateur',
            name='mode_courant',
            field=models.CharField(
                blank=True,
                choices=[('passager', 'Passager'), ('conducteur', 'Conducteur')],
                max_length=20,
                null=True,
            ),
        ),
    ]
