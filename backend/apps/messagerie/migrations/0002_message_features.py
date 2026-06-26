from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('messagerie', '0001_initial_conversation'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        # Rendre contenu optionnel (messages audio n'ont pas de texte)
        migrations.AlterField(
            model_name='messageconv',
            name='contenu',
            field=models.TextField(blank=True),
        ),

        # Type de message
        migrations.AddField(
            model_name='messageconv',
            name='message_type',
            field=models.CharField(
                choices=[('text', 'Texte'), ('audio', 'Audio'), ('image', 'Image')],
                default='text', db_index=True, max_length=10,
            ),
        ),

        # Réponse à un message
        migrations.AddField(
            model_name='messageconv',
            name='reply_to',
            field=models.ForeignKey(
                blank=True, null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name='replies',
                to='messagerie.messageconv',
            ),
        ),

        # Modification
        migrations.AddField(
            model_name='messageconv',
            name='is_edited',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='messageconv',
            name='edited_at',
            field=models.DateTimeField(blank=True, null=True),
        ),

        # Suppression
        migrations.AddField(
            model_name='messageconv',
            name='deleted_for_everyone',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='messageconv',
            name='deleted_for_me',
            field=models.ManyToManyField(
                blank=True,
                related_name='messages_supprimes_pour_moi',
                to=settings.AUTH_USER_MODEL,
            ),
        ),

        # Audio
        migrations.AddField(
            model_name='messageconv',
            name='audio_file',
            field=models.FileField(blank=True, null=True, upload_to='messages/audio/'),
        ),
        migrations.AddField(
            model_name='messageconv',
            name='audio_duration',
            field=models.IntegerField(blank=True, null=True),
        ),

        # Réactions
        migrations.CreateModel(
            name='MessageReaction',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('emoji', models.CharField(max_length=10)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('message', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='reactions',
                    to='messagerie.messageconv',
                )),
                ('utilisateur', models.ForeignKey(
                    on_delete=django.db.models.deletion.CASCADE,
                    related_name='reactions_messages',
                    to=settings.AUTH_USER_MODEL,
                )),
            ],
            options={
                'unique_together': {('message', 'utilisateur')},
            },
        ),
    ]
