from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('modeles', '0031_utilisateur_google_oauth'),
    ]

    operations = [
        migrations.AddField(
            model_name='utilisateur',
            name='photo_google',
            field=models.URLField(blank=True, max_length=500, null=True),
        ),
        migrations.AddField(
            model_name='utilisateur',
            name='last_login_provider',
            field=models.CharField(
                choices=[('email', 'Email'), ('google', 'Google'), ('passkey', 'Passkey')],
                default='email',
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name='utilisateur',
            name='passkey_enabled',
            field=models.BooleanField(default=False),
        ),
        migrations.AlterField(
            model_name='utilisateur',
            name='auth_provider',
            field=models.CharField(
                choices=[('email', 'Email'), ('google', 'Google'), ('passkey', 'Passkey')],
                default='email',
                max_length=20,
            ),
        ),
    ]
