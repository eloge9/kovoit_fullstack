from django.db import models


class ConversationHistory(models.Model):
    ROLE_USER      = 'user'
    ROLE_ASSISTANT = 'assistant'
    ROLE_CHOICES   = [(ROLE_USER, 'User'), (ROLE_ASSISTANT, 'Assistant')]

    PROVIDER_GEMINI = 'gemini'
    PROVIDER_CLAUDE = 'claude'
    PROVIDER_ERROR  = 'error'
    PROVIDER_CHOICES = [
        (PROVIDER_GEMINI, 'Gemini'),
        (PROVIDER_CLAUDE, 'Claude'),
        (PROVIDER_ERROR,  'Error'),
    ]

    user       = models.ForeignKey(
        'modeles.Utilisateur',
        null=True, blank=True,
        on_delete=models.SET_NULL,
        related_name='chat_history',
    )
    session_id = models.CharField(max_length=64, db_index=True)
    role       = models.CharField(max_length=10, choices=ROLE_CHOICES)
    content    = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    ai_provider_used = models.CharField(
        max_length=10, choices=PROVIDER_CHOICES,
        null=True, blank=True,
    )

    class Meta:
        ordering = ['created_at']
        indexes  = [models.Index(fields=['session_id', 'created_at'])]

    def __str__(self):
        who = self.user.username if self.user else 'invité'
        return f"[{self.role}] {who} — {self.created_at:%Y-%m-%d %H:%M}"
