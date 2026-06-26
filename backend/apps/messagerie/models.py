from django.db import models


class Conversation(models.Model):
    OUVERTE       = 'ouverte'
    LECTURE_SEULE = 'lecture_seule'
    FERMEE        = 'fermee'
    STATUT_CHOICES = [
        (OUVERTE,       'Ouverte'),
        (LECTURE_SEULE, 'Lecture seule'),
        (FERMEE,        'Fermée'),
    ]

    reservation = models.OneToOneField(
        'modeles.Reservation',
        null=True, blank=True,
        on_delete=models.SET_NULL,
        related_name='conversation',
    )
    statut     = models.CharField(
        max_length=20, choices=STATUT_CHOICES,
        default=OUVERTE, db_index=True,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True, db_index=True)

    class Meta:
        ordering = ['-updated_at']

    def __str__(self):
        return f"Conversation #{self.pk} [{self.statut}]"


class Participant(models.Model):
    conversation  = models.ForeignKey(
        Conversation, on_delete=models.CASCADE,
        related_name='participants',
    )
    utilisateur   = models.ForeignKey(
        'modeles.Utilisateur', on_delete=models.CASCADE,
        related_name='mes_conversations',
    )
    dernier_lu_at = models.DateTimeField(null=True, blank=True)
    created_at    = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = [['conversation', 'utilisateur']]
        indexes = [
            models.Index(fields=['utilisateur', '-created_at']),
        ]

    def __str__(self):
        return f"{self.utilisateur.username} <-> Conv#{self.conversation_id}"


class MessageConv(models.Model):
    TYPE_TEXT  = 'text'
    TYPE_AUDIO = 'audio'
    TYPE_IMAGE = 'image'
    TYPE_CHOICES = [
        (TYPE_TEXT,  'Texte'),
        (TYPE_AUDIO, 'Audio'),
        (TYPE_IMAGE, 'Image'),
    ]

    conversation         = models.ForeignKey(
        Conversation, on_delete=models.CASCADE,
        related_name='messages',
    )
    auteur               = models.ForeignKey(
        'modeles.Utilisateur', on_delete=models.CASCADE,
        related_name='messages_conv',
    )
    contenu              = models.TextField(blank=True)
    message_type         = models.CharField(
        max_length=10, choices=TYPE_CHOICES,
        default=TYPE_TEXT, db_index=True,
    )
    reply_to             = models.ForeignKey(
        'self', null=True, blank=True,
        on_delete=models.SET_NULL,
        related_name='replies',
    )
    is_edited            = models.BooleanField(default=False)
    edited_at            = models.DateTimeField(null=True, blank=True)
    deleted_for_everyone = models.BooleanField(default=False)
    deleted_for_me       = models.ManyToManyField(
        'modeles.Utilisateur', blank=True,
        related_name='messages_supprimes_pour_moi',
    )
    audio_file           = models.FileField(
        upload_to='messages/audio/',
        null=True, blank=True,
    )
    audio_duration       = models.IntegerField(null=True, blank=True)  # secondes
    created_at           = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['created_at']
        indexes = [
            models.Index(fields=['conversation', '-created_at']),
        ]

    def __str__(self):
        return f"Msg#{self.pk} [Conv#{self.conversation_id}] {self.auteur.username}"

    @property
    def peut_etre_modifie(self):
        from django.utils import timezone
        from datetime import timedelta
        return not self.deleted_for_everyone and (
            timezone.now() - self.created_at
        ) <= timedelta(minutes=15)


class MessageReaction(models.Model):
    message     = models.ForeignKey(
        MessageConv, on_delete=models.CASCADE,
        related_name='reactions',
    )
    utilisateur = models.ForeignKey(
        'modeles.Utilisateur', on_delete=models.CASCADE,
        related_name='reactions_messages',
    )
    emoji       = models.CharField(max_length=10)
    created_at  = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = [['message', 'utilisateur']]

    def __str__(self):
        return f"{self.utilisateur.username} {self.emoji} → Msg#{self.message_id}"
