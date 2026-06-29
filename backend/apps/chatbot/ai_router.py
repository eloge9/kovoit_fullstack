"""
Routeur IA multi-provider avec fallback automatique.
Ordre : Groq (llama-3.3-70b) → Gemini (2.0-flash) → Claude (haiku)
Si un provider échoue, le suivant prend le relais.
"""
import logging
from typing import Generator

from django.conf import settings

logger = logging.getLogger(__name__)

_FALLBACK_MSG = (
    "Je ne suis pas sûr de pouvoir répondre à cette question. "
    "Contactez notre support au 91 27 10 04 ou par email à gominaeloge@gmail.com."
)


class AIRouter:

    def get_response(self, messages: list[dict], system_prompt: str) -> dict:
        # ── 1. Groq ───────────────────────────────────────────────────────
        if getattr(settings, 'GROQ_API_KEY', ''):
            try:
                return {"text": self._call_groq(messages, system_prompt), "provider": "groq"}
            except Exception as exc:
                logger.warning("[Chatbot] Groq échoué (%s) — bascule Gemini", type(exc).__name__)

        # ── 2. Gemini ─────────────────────────────────────────────────────
        if getattr(settings, 'GEMINI_API_KEY_CHATBOT', ''):
            try:
                return {"text": self._call_gemini(messages, system_prompt), "provider": "gemini"}
            except Exception as exc:
                logger.warning("[Chatbot] Gemini échoué (%s) — bascule Claude", type(exc).__name__)

        # ── 3. Claude ─────────────────────────────────────────────────────
        if getattr(settings, 'ANTHROPIC_API_KEY', ''):
            try:
                return {"text": self._call_claude(messages, system_prompt), "provider": "claude"}
            except Exception as exc:
                logger.error("[Chatbot] Claude échoué (%s) — tous les providers ont échoué", type(exc).__name__)

        return {"text": _FALLBACK_MSG, "provider": "error"}

    def stream_response(self, messages: list[dict], system_prompt: str) -> Generator[str, None, None]:
        # ── 1. Groq streaming ─────────────────────────────────────────────
        if getattr(settings, 'GROQ_API_KEY', ''):
            try:
                yield "[PROVIDER:groq]"
                yield from self._stream_groq(messages, system_prompt)
                return
            except Exception as exc:
                logger.warning("[Chatbot] Groq stream échoué (%s) — bascule Gemini", type(exc).__name__)

        # ── 2. Gemini streaming ───────────────────────────────────────────
        if getattr(settings, 'GEMINI_API_KEY_CHATBOT', ''):
            try:
                yield "[PROVIDER:gemini]"
                yield from self._stream_gemini(messages, system_prompt)
                return
            except Exception as exc:
                logger.warning("[Chatbot] Gemini stream échoué (%s) — bascule Claude", type(exc).__name__)

        # ── 3. Claude streaming ───────────────────────────────────────────
        if getattr(settings, 'ANTHROPIC_API_KEY', ''):
            try:
                yield "[PROVIDER:claude]"
                yield from self._stream_claude(messages, system_prompt)
                return
            except Exception as exc:
                logger.error("[Chatbot] Claude stream échoué (%s) — tous les providers ont échoué", type(exc).__name__)

        yield "[PROVIDER:error]"
        yield _FALLBACK_MSG

    # ── Groq (llama-3.3-70b-versatile) ───────────────────────────────────

    def _call_groq(self, messages: list[dict], system_prompt: str) -> str:
        from groq import Groq
        client = Groq(api_key=settings.GROQ_API_KEY)
        all_msgs = [{"role": "system", "content": system_prompt}] + messages
        resp = client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=all_msgs,
            max_tokens=settings.CHATBOT_MAX_TOKENS_RESPONSE,
            timeout=20,
        )
        return resp.choices[0].message.content

    def _stream_groq(self, messages: list[dict], system_prompt: str) -> Generator[str, None, None]:
        from groq import Groq
        client = Groq(api_key=settings.GROQ_API_KEY)
        all_msgs = [{"role": "system", "content": system_prompt}] + messages
        stream = client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=all_msgs,
            max_tokens=settings.CHATBOT_MAX_TOKENS_RESPONSE,
            stream=True,
            timeout=20,
        )
        for chunk in stream:
            text = chunk.choices[0].delta.content
            if text:
                yield text

    # ── Gemini (gemini-2.0-flash) ─────────────────────────────────────────

    def _build_gemini_history(self, messages: list[dict]) -> tuple[list, str]:
        history = []
        for msg in messages[:-1]:
            role = "model" if msg["role"] == "assistant" else "user"
            history.append({"role": role, "parts": [msg["content"]]})
        last = messages[-1]["content"] if messages else ""
        return history, last

    def _call_gemini(self, messages: list[dict], system_prompt: str) -> str:
        import google.generativeai as genai
        genai.configure(api_key=settings.GEMINI_API_KEY_CHATBOT)
        model = genai.GenerativeModel(
            model_name="gemini-2.0-flash",
            system_instruction=system_prompt,
            generation_config={"max_output_tokens": settings.CHATBOT_MAX_TOKENS_RESPONSE},
        )
        history, last_msg = self._build_gemini_history(messages)
        chat = model.start_chat(history=history)
        return chat.send_message(last_msg, request_options={"timeout": 15}).text

    def _stream_gemini(self, messages: list[dict], system_prompt: str) -> Generator[str, None, None]:
        import google.generativeai as genai
        genai.configure(api_key=settings.GEMINI_API_KEY_CHATBOT)
        model = genai.GenerativeModel(
            model_name="gemini-2.0-flash",
            system_instruction=system_prompt,
            generation_config={"max_output_tokens": settings.CHATBOT_MAX_TOKENS_RESPONSE},
        )
        history, last_msg = self._build_gemini_history(messages)
        chat = model.start_chat(history=history)
        for chunk in chat.send_message(last_msg, stream=True, request_options={"timeout": 15}):
            if chunk.text:
                yield chunk.text

    # ── Claude (claude-haiku) ─────────────────────────────────────────────

    def _call_claude(self, messages: list[dict], system_prompt: str) -> str:
        import anthropic
        client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
        resp = client.messages.create(
            model="claude-haiku-4-5-20251001",
            max_tokens=settings.CHATBOT_MAX_TOKENS_RESPONSE,
            system=system_prompt,
            messages=messages,
        )
        return resp.content[0].text

    def _stream_claude(self, messages: list[dict], system_prompt: str) -> Generator[str, None, None]:
        import anthropic
        client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
        with client.messages.stream(
            model="claude-haiku-4-5-20251001",
            max_tokens=settings.CHATBOT_MAX_TOKENS_RESPONSE,
            system=system_prompt,
            messages=messages,
        ) as stream:
            for text in stream.text_stream:
                yield text
