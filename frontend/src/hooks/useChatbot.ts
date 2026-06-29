"use client";
import { useState, useCallback, useRef, useEffect } from "react";
import { streamChatMessage, type ChatMessage } from "@/src/services/chatbot.service";

const MAX_HISTORY = 10;
const SESSION_KEY = "kovoit_chat_session";

function generateSessionId(): string {
  return typeof crypto !== "undefined" && crypto.randomUUID
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(36).slice(2, 11)}`;
}

export interface UIMessage {
  id:        string;
  role:      "user" | "assistant";
  content:   string;
  streaming: boolean;
  provider?: string;
}

const WELCOME: UIMessage = {
  id:        "welcome",
  role:      "assistant",
  content:   "Bonjour ! Je suis **Kovi**, votre assistant Kovoit 👋\nComment puis-je vous aider aujourd'hui ?",
  streaming: false,
  provider:  "system",
};

export function useChatbot() {
  const [messages,   setMessages]   = useState<UIMessage[]>([WELCOME]);
  const [isLoading,  setIsLoading]  = useState(false);
  const [sessionId,  setSessionId]  = useState<string>("");

  // Historique propre pour l'API (sans le message de bienvenue)
  const historyRef = useRef<ChatMessage[]>([]);

  useEffect(() => {
    let sid = sessionStorage.getItem(SESSION_KEY);
    if (!sid) {
      sid = generateSessionId();
      sessionStorage.setItem(SESSION_KEY, sid);
    }
    setSessionId(sid);
  }, []);

  const sendMessage = useCallback(async (text: string) => {
    if (!text.trim() || isLoading) return;

    const userMsg: UIMessage = {
      id:        `u-${Date.now()}`,
      role:      "user",
      content:   text.trim(),
      streaming: false,
    };

    const assistantId = `a-${Date.now()}`;
    const assistantMsg: UIMessage = {
      id:        assistantId,
      role:      "assistant",
      content:   "",
      streaming: true,
    };

    setMessages(prev => [...prev, userMsg, assistantMsg]);
    setIsLoading(true);

    // Historique tronqué pour l'API
    const history = historyRef.current.slice(-(MAX_HISTORY * 2));

    try {
      let fullText = "";
      let provider = "gemini";

      for await (const chunk of streamChatMessage(text.trim(), sessionId, history)) {
        if (chunk.provider) {
          provider = chunk.provider;
          setMessages(prev =>
            prev.map(m => m.id === assistantId ? { ...m, provider } : m)
          );
        }
        if (chunk.text) {
          fullText += chunk.text;
          setMessages(prev =>
            prev.map(m => m.id === assistantId ? { ...m, content: fullText } : m)
          );
        }
        if (chunk.done) break;
      }

      // Finaliser le message assistant
      setMessages(prev =>
        prev.map(m => m.id === assistantId ? { ...m, streaming: false, provider } : m)
      );

      // Mettre à jour l'historique
      historyRef.current = [
        ...historyRef.current,
        { role: "user",      content: text.trim() },
        { role: "assistant", content: fullText },
      ].slice(-(MAX_HISTORY * 2));

    } catch {
      setMessages(prev =>
        prev.map(m =>
          m.id === assistantId
            ? { ...m, content: "Désolé, une erreur est survenue. Réessayez ou contactez le support au 91 27 10 04.", streaming: false }
            : m
        )
      );
    } finally {
      setIsLoading(false);
    }
  }, [isLoading, sessionId]);

  const clearHistory = useCallback(() => {
    const newSid = generateSessionId();
    sessionStorage.setItem(SESSION_KEY, newSid);
    setSessionId(newSid);
    historyRef.current = [];
    setMessages([WELCOME]);
  }, []);

  return { messages, isLoading, sessionId, sendMessage, clearHistory };
}
