from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ('modeles', '0001_initial'),
    ]

    operations = [
        migrations.CreateModel(
            name='ConversationHistory',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('session_id', models.CharField(db_index=True, max_length=64)),
                ('role', models.CharField(choices=[('user', 'User'), ('assistant', 'Assistant')], max_length=10)),
                ('content', models.TextField()),
                ('created_at', models.DateTimeField(auto_now_add=True, db_index=True)),
                ('ai_provider_used', models.CharField(
                    blank=True, null=True,
                    choices=[('gemini', 'Gemini'), ('claude', 'Claude'), ('error', 'Error')],
                    max_length=10,
                )),
                ('user', models.ForeignKey(
                    blank=True, null=True,
                    on_delete=django.db.models.deletion.SET_NULL,
                    related_name='chat_history',
                    to='modeles.utilisateur',
                )),
            ],
            options={'ordering': ['created_at']},
        ),
        migrations.AddIndex(
            model_name='conversationhistory',
            index=models.Index(fields=['session_id', 'created_at'], name='chatbot_session_idx'),
        ),
    ]
