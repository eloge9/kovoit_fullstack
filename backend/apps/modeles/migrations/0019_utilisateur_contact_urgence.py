from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('modeles', '0018_add_image_validators'),
    ]

    operations = [
        migrations.AddField(
            model_name='utilisateur',
            name='contact_urgence_nom',
            field=models.CharField(blank=True, default='', max_length=100),
        ),
        migrations.AddField(
            model_name='utilisateur',
            name='contact_urgence_telephone',
            field=models.CharField(blank=True, default='', max_length=20),
        ),
    ]
