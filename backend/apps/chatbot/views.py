"""
Endpoint /api/chat/ — chatbot Kovi avec streaming SSE.
"""
import asyncio
import json
import logging
import re

from django.conf import settings
from django.http import StreamingHttpResponse
from rest_framework.permissions import AllowAny
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from .ai_router import AIRouter
from .context_builder import build_system_prompt
from .models import ConversationHistory
from .rule_engine import find_rule_response


class _ASGIStreamingResponse(StreamingHttpResponse):
    """StreamingHttpResponse compatible ASGI/Daphne.
    Exécute le générateur synchrone dans un thread pool pour ne pas bloquer la boucle asyncio.
    """
    async def __aiter__(self):
        loop = asyncio.get_running_loop()
        sentinel = object()
        it = self._iterator
        while True:
            chunk = await loop.run_in_executor(None, next, it, sentinel)
            if chunk is sentinel:
                break
            yield self.make_bytes(chunk)

logger = logging.getLogger(__name__)

_MAX_MSG_LEN = 500
_MAX_HISTORY = getattr(settings, 'CHATBOT_MAX_HISTORY_MESSAGES', 10)
_ALLOWED_ROLES = {'user', 'assistant'}

_NO_AI_RESPONSE = (
    "Je ne suis pas encore sûr de pouvoir répondre à cette question précisément. 🤔\n\n"
    "Pour une aide personnalisée, notre équipe est disponible :\n"
    "• 📞 **91 27 10 04**\n"
    "• 📧 **gominaeloge@gmail.com**\n\n"
    "Ou reformulez votre question — je connais beaucoup de choses sur Kovoit ! 😊"
)


def _is_ai_configured() -> bool:
    """Vérifie si au moins un provider IA est correctement configuré."""
    return bool(
        getattr(settings, 'GROQ_API_KEY', '') or
        getattr(settings, 'GEMINI_API_KEY_CHATBOT', '') or
        getattr(settings, 'ANTHROPIC_API_KEY', '')
    )


def _sanitize(text: str) -> str:
    """Nettoie et tronque le message utilisateur."""
    text = text.strip()
    # Supprimer les caractères de contrôle dangereux
    text = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]', '', text)
    return text[:_MAX_MSG_LEN]


def _get_user_data(user) -> dict:
    """Récupère les données de l'utilisateur connecté pour le contexte IA."""
    try:
        from apps.modeles.models import Reservation
        nb_trajets = Reservation.objects.filter(
            passager=user, statut='terminee'
        ).count()

        role = getattr(user, 'role', 'passager') or 'passager'

        vehicule = None
        try:
            v = user.vehicules.first()
            if v:
                vehicule = f"{getattr(v, 'marque', '')} {getattr(v, 'modele', '')}".strip()
        except Exception:
            pass

        return {
            'nb_trajets': nb_trajets,
            'note': float(getattr(user, 'note', 0) or 0),
            'role': role,
            'statut': 'actif',
            'vehicule': vehicule,
            'documents_verifies': getattr(user, 'documents_verifies', False),
        }
    except Exception as exc:
        logger.warning("[Chatbot] Impossible de charger les données utilisateur : %s", exc)
        return {}


class ChatView(APIView):
    """
    POST /api/chat/         → réponse JSON complète
    POST /api/chat/stream/  → Server-Sent Events (streaming)
    """
    authentication_classes = []   # token expiré ne doit pas bloquer un endpoint public
    permission_classes = [AllowAny]
    throttle_scope = 'chatbot'

    def _parse_request(self, request) -> tuple[str, str, list[dict]] | None:
        """Valide et retourne (message, session_id, history) ou None si invalide."""
        message = _sanitize(str(request.data.get('message', '')))
        session_id = str(request.data.get('session_id', ''))[:64]
        raw_history = request.data.get('conversation_history', [])

        if not message:
            return None

        # Valider et tronquer l'historique
        history: list[dict] = []
        for item in raw_history:
            if isinstance(item, dict) and item.get('role') in _ALLOWED_ROLES:
                history.append({
                    'role': str(item['role']),
                    'content': _sanitize(str(item.get('content', '')))[:_MAX_MSG_LEN],
                })
        # Garder seulement les N derniers échanges
        history = history[-(_MAX_HISTORY * 2):]

        return message, session_id, history

    def _build_messages(self, history: list[dict], message: str) -> list[dict]:
        return history + [{"role": "user", "content": message}]

    def _save_history(self, user, session_id: str, message: str, reply: str, provider: str):
        try:
            ConversationHistory.objects.bulk_create([
                ConversationHistory(
                    user=user if user and user.is_authenticated else None,
                    session_id=session_id,
                    role=ConversationHistory.ROLE_USER,
                    content=message,
                ),
                ConversationHistory(
                    user=user if user and user.is_authenticated else None,
                    session_id=session_id,
                    role=ConversationHistory.ROLE_ASSISTANT,
                    content=reply,
                    ai_provider_used=provider,
                ),
            ])
        except Exception as exc:
            logger.warning("[Chatbot] Impossible de sauvegarder l'historique : %s", exc)

    # ── POST /api/chat/ ───────────────────────────────────────────────────

    def post(self, request):
        parsed = self._parse_request(request)
        if parsed is None:
            return Response(
                {"error": "Le message est vide ou invalide."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        message, session_id, history = parsed
        user = request.user

        user_data = _get_user_data(user) if user and user.is_authenticated else None
        system_prompt = build_system_prompt(
            user=user if user and user.is_authenticated else None,
            user_data=user_data,
        )

        # ── Règles prédéfinies (pas d'IA nécessaire) ─────────────────────
        rule_answer = find_rule_response(message)
        if rule_answer:
            self._save_history(user, session_id, message, rule_answer, 'rules')
            return Response({
                "response":   rule_answer,
                "session_id": session_id,
                "provider":   "rules",
            })

        # ── IA non configurée → réponse de repli propre ───────────────────
        if not _is_ai_configured():
            self._save_history(user, session_id, message, _NO_AI_RESPONSE, 'rules')
            return Response({
                "response":   _NO_AI_RESPONSE,
                "session_id": session_id,
                "provider":   "rules",
            })

        # ── Fallback IA ───────────────────────────────────────────────────
        messages = self._build_messages(history, message)
        result = AIRouter().get_response(messages, system_prompt)

        self._save_history(user, session_id, message, result['text'], result['provider'])

        return Response({
            "response":   result['text'],
            "session_id": session_id,
            "provider":   result['provider'],
        })


class ChatStreamView(APIView):
    """
    POST /api/chat/stream/
    Retourne une réponse Server-Sent Events (text/event-stream).
    Chaque chunk : "data: <texte>\\n\\n"
    Dernier event : "data: [DONE]\\n\\n"
    """
    permission_classes = [AllowAny]
    throttle_scope = 'chatbot'

    def post(self, request):
        # Réutilise la logique de parsing de ChatView
        view = ChatView()
        view.request = request
        parsed = view._parse_request(request)

        if parsed is None:
            return Response(
                {"error": "Le message est vide ou invalide."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        message, session_id, history = parsed
        user = request.user

        # ── Règles prédéfinies ou IA non configurée → réponse instantanée ──
        rule_answer = find_rule_response(message)
        static_reply = rule_answer or (None if _is_ai_configured() else _NO_AI_RESPONSE)

        if static_reply:
            provider = 'rules'
            def rule_stream():
                yield f"data: {json.dumps({'provider': provider})}\n\n"
                safe = static_reply.replace('\n', '\\n')
                yield f"data: {json.dumps({'text': safe})}\n\n"
                view._save_history(user, session_id, message, static_reply, provider)
                yield f"data: {json.dumps({'done': True})}\n\n"

            response = _ASGIStreamingResponse(
                rule_stream(),
                content_type='text/event-stream; charset=utf-8',
            )
            response['Cache-Control'] = 'no-cache'
            response['X-Accel-Buffering'] = 'no'
            return response

        # ── Fallback IA ───────────────────────────────────────────────────
        user_data = _get_user_data(user) if user and user.is_authenticated else None
        system_prompt = build_system_prompt(
            user=user if user and user.is_authenticated else None,
            user_data=user_data,
        )

        messages = view._build_messages(history, message)

        def event_stream():
            full_response = []
            provider = "gemini"

            for chunk in AIRouter().stream_response(messages, system_prompt):
                if chunk.startswith("[PROVIDER:"):
                    provider = chunk[10:-1]
                    yield f"data: {json.dumps({'provider': provider})}\n\n"
                    continue
                full_response.append(chunk)
                safe = chunk.replace('\n', '\\n')
                yield f"data: {json.dumps({'text': safe})}\n\n"

            full_text = ''.join(full_response)
            view._save_history(user, session_id, message, full_text, provider)
            yield f"data: {json.dumps({'done': True})}\n\n"

        response = _ASGIStreamingResponse(
            event_stream(),
            content_type='text/event-stream; charset=utf-8',
        )
        response['Cache-Control'] = 'no-cache'
        response['X-Accel-Buffering'] = 'no'  # Désactive le buffering nginx
        return response
