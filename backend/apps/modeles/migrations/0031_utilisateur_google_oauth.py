from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('modeles', '0030_utilisateur_mode_courant'),
    ]

    operations = [
        migrations.AddField(
            model_name='utilisateur',
            name='google_id',
            field=models.CharField(blank=True, max_length=128, null=True, unique=True),
        ),
        migrations.AddField(
            model_name='utilisateur',
            name='auth_provider',
            field=models.CharField(
                choices=[('email', 'Email'), ('google', 'Google')],
                default='email',
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name='utilisateur',
            name='photo_url',
            field=models.URLField(blank=True, max_length=500, null=True),
        ),
    ]
