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
    conversation = models.ForeignKey(
        Conversation, on_delete=models.CASCADE,
        related_name='messages',
    )
    auteur    = models.ForeignKey(
        'modeles.Utilisateur', on_delete=models.CASCADE,
        related_name='messages_conv',
    )
    contenu    = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['created_at']
        indexes = [
            models.Index(fields=['conversation', '-created_at']),
        ]

    def __str__(self):
        return f"Msg#{self.pk} [Conv#{self.conversation_id}] {self.auteur.username}"
