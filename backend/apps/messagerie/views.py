import logging
from datetime import timedelta

from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.db import transaction
from django.utils import timezone
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

from .models import Conversation, Participant, MessageConv, MessageReaction
from ..modeles.models import Utilisateur, Trajet, Reservation

logger = logging.getLogger(__name__)


# ── Helpers ───────────────────────────────────────────────────────────────────

def _user_info(u):
    return {
        'id':          str(u.id),
        'username':    u.username,
        'nom':         f"{u.first_name} {u.last_name}".strip() or u.username,
        'photo_profil': u.photo_profil.url if getattr(u, 'photo_profil', None) and u.photo_profil else None,
        'role':        getattr(u, 'role', ''),
    }


def _serialise_reply(msg):
    if msg is None:
        return None
    return {
        'id':           msg.id,
        'contenu':      'Ce message a été supprimé.' if msg.deleted_for_everyone else msg.contenu,
        'username':     msg.auteur.username,
        'message_type': msg.message_type,
    }


def _serialise_message(msg, current_user, interlocuteur_lu_at=None):
    """Sérialise un MessageConv pour l'API REST."""
    if msg.deleted_for_everyone:
        return {
            'id':           msg.id,
            'deleted':      True,
            'contenu':      'Ce message a été supprimé.',
            'message_type': msg.message_type,
            'auteur_id':    str(msg.auteur_id),
            'username':     msg.auteur.username,
            'timestamp':    msg.created_at.isoformat(),
            'moi':          msg.auteur_id == current_user.id,
        }

    # Supprimer pour moi → ne pas renvoyer
    if msg.deleted_for_me.filter(pk=current_user.pk).exists():
        return None

    reactions = {}
    for r in msg.reactions.select_related('utilisateur').all():
        e = r.emoji
        if e not in reactions:
            reactions[e] = {'count': 0, 'moi': False}
        reactions[e]['count'] += 1
        if r.utilisateur_id == current_user.id:
            reactions[e]['moi'] = True

    is_read = False
    if interlocuteur_lu_at and interlocuteur_lu_at > msg.created_at:
        is_read = True

    return {
        'id':             msg.id,
        'deleted':        False,
        'contenu':        msg.contenu,
        'message_type':   msg.message_type,
        'audio_url':      msg.audio_file.url if msg.audio_file else None,
        'audio_duration': msg.audio_duration,
        'auteur_id':      str(msg.auteur_id),
        'username':       msg.auteur.username,
        'timestamp':      msg.created_at.isoformat(),
        'moi':            msg.auteur_id == current_user.id,
        'is_edited':      msg.is_edited,
        'edited_at':      msg.edited_at.isoformat() if msg.edited_at else None,
        'reply_to':       _serialise_reply(msg.reply_to) if msg.reply_to_id else None,
        'reactions':      reactions,
        'is_read':        is_read,
    }


def _non_lus_pour_participant(p: Participant) -> int:
    qs = p.conversation.messages.exclude(auteur=p.utilisateur).filter(
        deleted_for_everyone=False,
    )
    if p.dernier_lu_at:
        return qs.filter(created_at__gt=p.dernier_lu_at).count()
    return qs.count()


def _conv_data(conv: Conversation, current_user) -> dict:
    dernier = conv.messages.filter(
        deleted_for_everyone=False,
    ).exclude(
        deleted_for_me=current_user,
    ).order_by('-created_at').first()

    dernier_data = None
    if dernier:
        contenu_affiché = 'Ce message a été supprimé.' if dernier.deleted_for_everyone else (
            '🎵 Message vocal' if dernier.message_type == 'audio' else dernier.contenu
        )
        dernier_data = {
            'id':        dernier.id,
            'contenu':   contenu_affiché,
            'auteur_id': str(dernier.auteur_id),
            'username':  dernier.auteur.username,
            'timestamp': dernier.created_at.isoformat(),
            'moi':       dernier.auteur_id == current_user.id,
        }

    all_participants = list(conv.participants.select_related('utilisateur'))
    interlocuteurs = [
        _user_info(p.utilisateur)
        for p in all_participants
        if p.utilisateur_id != current_user.id
    ]

    trajet_info = None
    # Trajet via réservation (conv privée existante)
    if conv.reservation_id:
        try:
            res = conv.reservation
            t   = res.trajet
            trajet_info = {
                'id':                 t.id,
                'depart':             t.depart,
                'destination':        t.destination,
                'date':               t.date_heure_depart.isoformat() if t.date_heure_depart else None,
                'statut_reservation': res.statut,
                'reservation_id':     res.id,
            }
        except Exception:
            pass
    # Trajet via conv groupe
    elif conv.trajet_id:
        try:
            t = conv.trajet
            trajet_info = {
                'id':          t.id,
                'depart':      t.depart,
                'destination': t.destination,
                'date':        t.date_heure_depart.isoformat() if t.date_heure_depart else None,
            }
        except Exception:
            pass

    try:
        p_current = next(p for p in all_participants if p.utilisateur_id == current_user.id)
        non_lus   = _non_lus_pour_participant(p_current)
    except StopIteration:
        non_lus = 0

    return {
        'id':                conv.id,
        'type':              conv.type,
        'is_groupe':         conv.type == Conversation.TYPE_TRAJET,
        'titre':             conv.titre,
        'statut':            conv.statut,
        'reservation_id':    conv.reservation_id,
        'trajet_id':         conv.trajet_id,
        'trajet':            trajet_info,
        'interlocuteurs':    interlocuteurs,
        'participants_count': len(all_participants),
        'dernier_message':   dernier_data,
        'non_lus':           non_lus,
        'updated_at':        conv.updated_at.isoformat(),
    }


def _interlocuteur_lu_at(conv_id, current_user):
    """Retourne le dernier_lu_at de l'interlocuteur (pour les accusés de lecture)."""
    try:
        p = Participant.objects.exclude(utilisateur=current_user).get(conversation_id=conv_id)
        return p.dernier_lu_at
    except (Participant.DoesNotExist, Participant.MultipleObjectsReturned):
        return None


# ── Conversations ─────────────────────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def liste_conversations(request):
    participations = (
        Participant.objects
        .filter(utilisateur=request.user)
        .select_related(
            'conversation',
            'conversation__reservation',
            'conversation__reservation__trajet',
        )
        .prefetch_related('conversation__participants__utilisateur', 'conversation__messages')
        .order_by('-conversation__updated_at')
    )
    data = [_conv_data(p.conversation, request.user) for p in participations]
    return Response(data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def detail_conversation(request, conv_id):
    try:
        Participant.objects.get(conversation_id=conv_id, utilisateur=request.user)
    except Participant.DoesNotExist:
        return Response({"error": "Conversation introuvable."}, status=404)
    try:
        conv = (
            Conversation.objects
            .select_related('reservation', 'reservation__trajet')
            .prefetch_related('participants__utilisateur')
            .get(pk=conv_id)
        )
    except Conversation.DoesNotExist:
        return Response({"error": "Conversation introuvable."}, status=404)
    return Response(_conv_data(conv, request.user))


# ── Messages d'une conversation ───────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def messages_conversation(request, conv_id):
    if not Participant.objects.filter(conversation_id=conv_id, utilisateur=request.user).exists():
        return Response({"error": "Conversation introuvable."}, status=404)

    avant_id = request.query_params.get('avant')
    qs = (
        MessageConv.objects
        .filter(conversation_id=conv_id)
        .select_related('auteur', 'reply_to__auteur')
        .prefetch_related('reactions__utilisateur', 'deleted_for_me')
    )
    if avant_id:
        qs = qs.filter(id__lt=avant_id)
    msgs = list(qs.order_by('-created_at')[:50])

    Participant.objects.filter(
        conversation_id=conv_id, utilisateur=request.user,
    ).update(dernier_lu_at=timezone.now())

    interlocuteur_lu = _interlocuteur_lu_at(conv_id, request.user)
    data = []
    for m in reversed(msgs):
        s = _serialise_message(m, request.user, interlocuteur_lu)
        if s is not None:
            data.append(s)
    return Response(data)


# ── Envoyer un message texte (REST fallback) ──────────────────────────────────

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def envoyer_message(request, conv_id):
    if not Participant.objects.filter(conversation_id=conv_id, utilisateur=request.user).exists():
        return Response({"error": "Conversation introuvable."}, status=404)

    try:
        conv = Conversation.objects.get(pk=conv_id)
    except Conversation.DoesNotExist:
        return Response({"error": "Conversation introuvable."}, status=404)

    if conv.statut != Conversation.OUVERTE:
        return Response({"error": f"La conversation est en mode {conv.statut}."}, status=403)

    contenu = str(request.data.get('contenu', '')).strip()
    if not contenu:
        return Response({"error": "Le message ne peut pas être vide."}, status=400)

    reply_to = None
    reply_to_id = request.data.get('reply_to_id')
    if reply_to_id:
        try:
            reply_to = MessageConv.objects.select_related('auteur').get(
                pk=reply_to_id, conversation_id=conv_id,
            )
        except MessageConv.DoesNotExist:
            pass

    msg = MessageConv.objects.create(
        conversation=conv, auteur=request.user, contenu=contenu, reply_to=reply_to,
    )
    Conversation.objects.filter(pk=conv_id).update(updated_at=timezone.now())

    return Response(_serialise_message(msg, request.user), status=201)


# ── Envoyer un message audio ──────────────────────────────────────────────────

@api_view(['POST'])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser])
def envoyer_audio(request, conv_id):
    if not Participant.objects.filter(conversation_id=conv_id, utilisateur=request.user).exists():
        return Response({"error": "Conversation introuvable."}, status=404)

    try:
        conv = Conversation.objects.get(pk=conv_id)
    except Conversation.DoesNotExist:
        return Response({"error": "Conversation introuvable."}, status=404)

    if conv.statut != Conversation.OUVERTE:
        return Response({"error": f"La conversation est en mode {conv.statut}."}, status=403)

    audio = request.FILES.get('audio')
    if not audio:
        return Response({"error": "Fichier audio manquant."}, status=400)

    duration = request.data.get('duration')
    try:
        duration = int(duration) if duration else None
    except (ValueError, TypeError):
        duration = None

    msg = MessageConv.objects.create(
        conversation=conv,
        auteur=request.user,
        contenu='',
        message_type=MessageConv.TYPE_AUDIO,
        audio_file=audio,
        audio_duration=duration,
    )
    Conversation.objects.filter(pk=conv_id).update(updated_at=timezone.now())

    # Diffuser via WebSocket
    serialized = _serialise_message(msg, request.user)
    channel_layer = get_channel_layer()
    async_to_sync(channel_layer.group_send)(
        f"conv_{conv_id}",
        {"type": "chat.message", **serialized},
    )

    # Notification push aux autres participants
    for p in Participant.objects.filter(conversation_id=conv_id).exclude(utilisateur=request.user):
        async_to_sync(channel_layer.group_send)(
            f"notif_{p.utilisateur_id}",
            {
                "type":       "notification",
                "notif_type": "nouveau_message",
                "data": {
                    "conv_id":    conv_id,
                    "auteur":     request.user.username,
                    "contenu":    "🎵 Message vocal",
                    "message_id": msg.id,
                },
            },
        )

    return Response(serialized, status=201)


# ── Modifier un message ────────────────────────────────────────────────────────

@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
def modifier_message(request, msg_id):
    try:
        msg = MessageConv.objects.get(pk=msg_id)
    except MessageConv.DoesNotExist:
        return Response({"error": "Message introuvable."}, status=404)

    if msg.auteur_id != request.user.id:
        return Response({"error": "Interdit."}, status=403)

    if msg.deleted_for_everyone:
        return Response({"error": "Ce message a été supprimé."}, status=403)

    if (timezone.now() - msg.created_at) > timedelta(minutes=15):
        return Response({"error": "La modification n'est plus possible après 15 minutes."}, status=403)

    nouveau = str(request.data.get('contenu', '')).strip()
    if not nouveau:
        return Response({"error": "Le contenu ne peut pas être vide."}, status=400)

    msg.contenu   = nouveau
    msg.is_edited = True
    msg.edited_at = timezone.now()
    msg.save(update_fields=['contenu', 'is_edited', 'edited_at'])

    # Diffuser via WebSocket
    channel_layer = get_channel_layer()
    async_to_sync(channel_layer.group_send)(
        f"conv_{msg.conversation_id}",
        {
            "type":       "chat.message_edited",
            "message_id": msg.id,
            "contenu":    msg.contenu,
            "edited_at":  msg.edited_at.isoformat(),
        },
    )

    return Response({
        "message_id": msg.id,
        "contenu":    msg.contenu,
        "edited_at":  msg.edited_at.isoformat(),
    })


# ── Supprimer un message ──────────────────────────────────────────────────────

@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def supprimer_message(request, msg_id):
    try:
        msg = MessageConv.objects.get(pk=msg_id)
    except MessageConv.DoesNotExist:
        return Response({"error": "Message introuvable."}, status=404)

    if msg.auteur_id != request.user.id:
        return Response({"error": "Interdit."}, status=403)

    pour_tous = request.data.get('pour_tous', False)

    if pour_tous:
        msg.deleted_for_everyone = True
        msg.save(update_fields=['deleted_for_everyone'])
        # Diffuser via WebSocket
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            f"conv_{msg.conversation_id}",
            {"type": "chat.message_deleted", "message_id": msg.id, "pour_tous": True},
        )
    else:
        msg.deleted_for_me.add(request.user)

    return Response({"message_id": msg.id, "pour_tous": pour_tous})


# ── Réactions ────────────────────────────────────────────────────────────────

EMOJIS_AUTORISES = {'👍', '❤️', '😂', '😮', '😢', '🙏'}


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def reagir_message(request, msg_id):
    try:
        msg = MessageConv.objects.get(pk=msg_id)
    except MessageConv.DoesNotExist:
        return Response({"error": "Message introuvable."}, status=404)

    if not Participant.objects.filter(conversation_id=msg.conversation_id, utilisateur=request.user).exists():
        return Response({"error": "Interdit."}, status=403)

    emoji = str(request.data.get('emoji', '')).strip()
    if emoji not in EMOJIS_AUTORISES:
        return Response({"error": f"Emoji non autorisé. Choisissez parmi : {', '.join(EMOJIS_AUTORISES)}"}, status=400)

    existing = MessageReaction.objects.filter(message=msg, utilisateur=request.user).first()
    if existing:
        if existing.emoji == emoji:
            existing.delete()
            action = 'remove'
        else:
            existing.emoji = emoji
            existing.save(update_fields=['emoji'])
            action = 'add'
    else:
        MessageReaction.objects.create(message=msg, utilisateur=request.user, emoji=emoji)
        action = 'add'

    # Diffuser via WebSocket
    channel_layer = get_channel_layer()
    async_to_sync(channel_layer.group_send)(
        f"conv_{msg.conversation_id}",
        {
            "type":       "chat.reaction",
            "message_id": msg.id,
            "emoji":      emoji,
            "user_id":    str(request.user.id),
            "action":     action,
        },
    )

    return Response({"message_id": msg.id, "emoji": emoji, "action": action})


# ── Nombre de messages non lus ────────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def non_lus_count(request):
    total = 0
    for p in Participant.objects.filter(utilisateur=request.user).prefetch_related('conversation__messages'):
        total += _non_lus_pour_participant(p)
    return Response({'count': total})


# ── Conversation privée permanente (WhatsApp-style) ───────────────────────────

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def get_or_create_private(request, user_id):
    """Retourne ou crée la conversation privée permanente entre l'utilisateur courant et user_id."""
    try:
        cible = Utilisateur.objects.get(pk=user_id)
    except Utilisateur.DoesNotExist:
        return Response({"error": "Utilisateur introuvable."}, status=404)

    if cible.pk == request.user.pk:
        return Response({"error": "Vous ne pouvez pas vous écrire à vous-même."}, status=400)

    # Chercher une conv privée existante entre les deux users
    conv = (
        Conversation.objects
        .filter(type=Conversation.TYPE_PRIVATE, participants__utilisateur=request.user)
        .filter(participants__utilisateur=cible)
        .prefetch_related('participants__utilisateur', 'messages')
        .first()
    )

    created = False
    if conv is None:
        with transaction.atomic():
            conv = Conversation.objects.create(type=Conversation.TYPE_PRIVATE)
            Participant.objects.create(conversation=conv, utilisateur=request.user)
            Participant.objects.create(conversation=conv, utilisateur=cible)
            created = True

    data = _conv_data(conv, request.user)
    data['created'] = created
    return Response(data, status=201 if created else 200)


# ── Conversation groupe trajet (Uber-style) ───────────────────────────────────

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def get_or_create_groupe_trajet(request, trajet_id):
    """Retourne ou crée la conversation de groupe pour un trajet."""
    try:
        trajet = Trajet.objects.select_related('conducteur').get(pk=trajet_id)
    except Trajet.DoesNotExist:
        return Response({"error": "Trajet introuvable."}, status=404)

    # Vérifier l'accès : conducteur ou passager confirmé
    is_conducteur = trajet.conducteur_id == request.user.pk
    is_passager = Reservation.objects.filter(
        trajet=trajet, passager=request.user,
        statut__in=['confirmee', 'terminee'],
    ).exists()

    if not is_conducteur and not is_passager:
        return Response({"error": "Accès non autorisé à ce trajet."}, status=403)

    if request.method == 'GET':
        conv = (
            Conversation.objects
            .filter(trajet=trajet, type=Conversation.TYPE_TRAJET)
            .prefetch_related('participants__utilisateur', 'messages')
            .first()
        )
        if conv is None:
            return Response({"exists": False, "id": None})
        data = _conv_data(conv, request.user)
        data['exists'] = True
        return Response(data)

    # POST : get_or_create
    with transaction.atomic():
        conv, created = Conversation.objects.get_or_create(
            trajet=trajet,
            type=Conversation.TYPE_TRAJET,
            defaults={
                'titre':  f"{trajet.depart} → {trajet.destination}",
                'statut': Conversation.OUVERTE,
            },
        )
        if created:
            # Ajouter le conducteur
            Participant.objects.get_or_create(conversation=conv, utilisateur=trajet.conducteur)
            # Ajouter tous les passagers déjà confirmés
            for r in Reservation.objects.filter(
                trajet=trajet, statut__in=['confirmee', 'terminee']
            ).select_related('passager'):
                Participant.objects.get_or_create(conversation=conv, utilisateur=r.passager)
        else:
            # S'assurer que l'utilisateur courant est bien participant
            Participant.objects.get_or_create(conversation=conv, utilisateur=request.user)

    # Re-fetch avec prefetch pour éviter les N+1
    conv = (
        Conversation.objects
        .prefetch_related('participants__utilisateur', 'messages')
        .get(pk=conv.pk)
    )
    data = _conv_data(conv, request.user)
    data['created'] = created
    return Response(data, status=201 if created else 200)
