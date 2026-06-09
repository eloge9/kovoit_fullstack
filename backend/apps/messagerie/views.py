import logging
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db.models import Q, Max, Subquery, OuterRef
from django.utils import timezone

from ..modeles.models import Message, Utilisateur

logger = logging.getLogger(__name__)


class MessagerieViewSet(viewsets.GenericViewSet):
    permission_classes = [IsAuthenticated]

    # ── Liste des conversations ───────────────────────────────────────────
    @action(detail=False, methods=['get'], url_path='conversations')
    def conversations(self, request):
        """
        Retourne la liste des utilisateurs avec qui l'utilisateur a échangé,
        avec le dernier message et le nombre de messages non lus.
        """
        user = request.user

        # IDs de tous les interlocuteurs (expéditeurs ou destinataires)
        envoyes  = Message.objects.filter(expediteur=user).values_list('destinataire_id', flat=True)
        recus    = Message.objects.filter(destinataire=user).values_list('expediteur_id', flat=True)
        ids_tous = set(envoyes) | set(recus)

        conversations = []
        for autre_id in ids_tous:
            # Dernier message du thread
            dernier = (
                Message.objects
                .filter(
                    Q(expediteur=user, destinataire_id=autre_id) |
                    Q(expediteur_id=autre_id, destinataire=user)
                )
                .order_by('-created_at')
                .first()
            )
            if dernier is None:
                continue

            non_lus = Message.objects.filter(
                expediteur_id=autre_id,
                destinataire=user,
                lu=False,
            ).count()

            try:
                autre = Utilisateur.objects.get(pk=autre_id)
            except Utilisateur.DoesNotExist:
                continue

            conversations.append({
                'utilisateur': {
                    'id':          str(autre.id),
                    'username':    autre.username,
                    'nom':         f"{autre.first_name} {autre.last_name}".strip() or autre.username,
                    'photo_profil': autre.photo_profil.url if autre.photo_profil else None,
                    'role':        autre.role,
                },
                'dernier_message': {
                    'id':           dernier.id,
                    'contenu':      dernier.contenu,
                    'expediteur_id': str(dernier.expediteur_id),
                    'timestamp':    dernier.created_at.isoformat(),
                },
                'non_lus': non_lus,
            })

        # Trier par date du dernier message (plus récent en premier)
        conversations.sort(key=lambda c: c['dernier_message']['timestamp'], reverse=True)
        return Response(conversations)

    # ── Historique avec un utilisateur ───────────────────────────────────
    @action(detail=False, methods=['get'], url_path='messages/(?P<user_id>[0-9a-f-]+)')
    def historique(self, request, user_id=None):
        """
        Retourne les 50 derniers messages échangés avec un utilisateur donné.
        Marque automatiquement les messages reçus comme lus.
        """
        user = request.user

        # Vérifier que l'interlocuteur existe (même réponse 404 pour éviter l'énumération d'IDs)
        if not Utilisateur.objects.filter(pk=user_id).exists():
            from rest_framework.exceptions import NotFound
            raise NotFound("Utilisateur introuvable.")

        messages = (
            Message.objects
            .filter(
                Q(expediteur=user, destinataire_id=user_id) |
                Q(expediteur_id=user_id, destinataire=user)
            )
            .select_related('expediteur')
            .order_by('-created_at')[:50]
        )

        # Marquer les messages reçus comme lus
        Message.objects.filter(
            expediteur_id=user_id,
            destinataire=user,
            lu=False,
        ).update(lu=True)

        data = [
            {
                'id':           m.id,
                'contenu':      m.contenu,
                'expediteur_id': str(m.expediteur_id),
                'username':     m.expediteur.username,
                'lu':           m.lu,
                'timestamp':    m.created_at.isoformat(),
                'moi':          m.expediteur_id == user.id,
            }
            for m in reversed(list(messages))
        ]
        return Response(data)

    # ── Envoyer un message REST (fallback WebSocket) ──────────────────────
    @action(detail=False, methods=['post'], url_path='messages/(?P<user_id>[0-9a-f-]+)/envoyer')
    def envoyer(self, request, user_id=None):
        """
        Envoie un message par REST (utilisé quand le WebSocket n'est pas disponible).
        """
        contenu = str(request.data.get('contenu', '')).strip()
        if not contenu:
            return Response({"error": "Le message ne peut pas être vide."}, status=400)

        try:
            destinataire = Utilisateur.objects.get(pk=user_id)
        except Utilisateur.DoesNotExist:
            return Response({"error": "Destinataire introuvable."}, status=404)

        if destinataire.id == request.user.id:
            return Response({"error": "Vous ne pouvez pas vous envoyer un message."}, status=400)

        message = Message.objects.create(
            expediteur=request.user,
            destinataire=destinataire,
            contenu=contenu,
        )

        return Response({
            'id':           message.id,
            'contenu':      message.contenu,
            'expediteur_id': str(message.expediteur_id),
            'timestamp':    message.created_at.isoformat(),
        }, status=status.HTTP_201_CREATED)

    # ── Nombre total de messages non lus ─────────────────────────────────
    @action(detail=False, methods=['get'], url_path='non-lus')
    def non_lus(self, request):
        """Retourne le nombre de messages non lus (pour le badge dans la navbar)."""
        count = Message.objects.filter(destinataire=request.user, lu=False).count()
        return Response({'count': count})

    # ── Infos d'un utilisateur pour démarrer une conversation ────────────
    @action(detail=False, methods=['get'], url_path='utilisateur/(?P<user_id>[0-9a-f-]+)')
    def info_utilisateur(self, request, user_id=None):
        """
        Retourne les infos de base d'un utilisateur pour initier une nouvelle conversation.
        Utilisé quand on navigue vers /communication/messages?avec=<uuid> sans conversation existante.
        """
        try:
            autre = Utilisateur.objects.get(pk=user_id)
        except Utilisateur.DoesNotExist:
            from rest_framework.exceptions import NotFound
            raise NotFound("Utilisateur introuvable.")

        if str(autre.id) == str(request.user.id):
            return Response({"error": "Impossible d'ouvrir une conversation avec vous-même."}, status=400)

        return Response({
            'id':          str(autre.id),
            'username':    autre.username,
            'nom':         f"{autre.first_name} {autre.last_name}".strip() or autre.username,
            'photo_profil': autre.photo_profil.url if autre.photo_profil else None,
            'role':        autre.role,
        })
