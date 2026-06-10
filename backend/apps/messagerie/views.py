import logging
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.utils import timezone

from .models import Conversation, Participant, MessageConv

logger = logging.getLogger(__name__)


def _user_info(u):
    return {
        'id':          str(u.id),
        'username':    u.username,
        'nom':         f"{u.first_name} {u.last_name}".strip() or u.username,
        'photo_profil': u.photo_profil.url if getattr(u, 'photo_profil', None) and u.photo_profil else None,
        'role':        getattr(u, 'role', ''),
    }


def _non_lus_pour_participant(p: Participant) -> int:
    qs = p.conversation.messages.exclude(auteur=p.utilisateur)
    if p.dernier_lu_at:
        return qs.filter(created_at__gt=p.dernier_lu_at).count()
    return qs.count()


def _conv_data(conv: Conversation, current_user) -> dict:
    dernier = conv.messages.order_by('-created_at').first()
    dernier_data = None
    if dernier:
        dernier_data = {
            'id':        dernier.id,
            'contenu':   dernier.contenu,
            'auteur_id': str(dernier.auteur_id),
            'timestamp': dernier.created_at.isoformat(),
            'moi':       dernier.auteur_id == current_user.id,
        }

    interlocuteurs = []
    for p in conv.participants.exclude(utilisateur=current_user).select_related('utilisateur'):
        interlocuteurs.append(_user_info(p.utilisateur))

    trajet_info = None
    if conv.reservation_id:
        try:
            res = conv.reservation
            t = res.trajet
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

    try:
        p_current = conv.participants.get(utilisateur=current_user)
        non_lus = _non_lus_pour_participant(p_current)
    except Participant.DoesNotExist:
        non_lus = 0

    return {
        'id':             conv.id,
        'statut':         conv.statut,
        'reservation_id': conv.reservation_id,
        'trajet':         trajet_info,
        'interlocuteurs': interlocuteurs,
        'dernier_message': dernier_data,
        'non_lus':        non_lus,
        'updated_at':     conv.updated_at.isoformat(),
    }


# ── GET /messagerie/conversations/ ───────────────────────────────────────────

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


# ── GET /messagerie/conversations/{id}/ ──────────────────────────────────────

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


# ── GET /messagerie/conversations/{id}/messages/ ─────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def messages_conversation(request, conv_id):
    if not Participant.objects.filter(conversation_id=conv_id, utilisateur=request.user).exists():
        return Response({"error": "Conversation introuvable."}, status=404)

    # Pagination basique : cursor via ?avant=<id> pour charger les anciens messages
    avant_id = request.query_params.get('avant')
    qs = MessageConv.objects.filter(conversation_id=conv_id).select_related('auteur')
    if avant_id:
        qs = qs.filter(id__lt=avant_id)
    msgs = list(qs.order_by('-created_at')[:50])

    # Marquer comme lu
    Participant.objects.filter(
        conversation_id=conv_id,
        utilisateur=request.user,
    ).update(dernier_lu_at=timezone.now())

    data = [
        {
            'id':        m.id,
            'contenu':   m.contenu,
            'auteur_id': str(m.auteur_id),
            'username':  m.auteur.username,
            'timestamp': m.created_at.isoformat(),
            'moi':       m.auteur_id == request.user.id,
        }
        for m in reversed(msgs)
    ]
    return Response(data)


# ── POST /messagerie/conversations/{id}/messages/ (REST fallback) ─────────────

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
        return Response(
            {"error": f"La conversation est en mode {conv.statut}."},
            status=status.HTTP_403_FORBIDDEN,
        )

    contenu = str(request.data.get('contenu', '')).strip()
    if not contenu:
        return Response({"error": "Le message ne peut pas être vide."}, status=400)

    msg = MessageConv.objects.create(conversation=conv, auteur=request.user, contenu=contenu)
    Conversation.objects.filter(pk=conv_id).update(updated_at=timezone.now())

    return Response({
        'id':        msg.id,
        'contenu':   msg.contenu,
        'auteur_id': str(msg.auteur_id),
        'username':  request.user.username,
        'timestamp': msg.created_at.isoformat(),
        'moi':       True,
    }, status=201)


# ── GET /messagerie/non-lus/ ──────────────────────────────────────────────────

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def non_lus_count(request):
    total = 0
    for p in Participant.objects.filter(utilisateur=request.user).prefetch_related('conversation__messages'):
        total += _non_lus_pour_participant(p)
    return Response({'count': total})
