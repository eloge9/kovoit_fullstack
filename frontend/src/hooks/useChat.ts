"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import type { ChatMessage } from "@/src/services/messagerie.service";

export type { ChatMessage };

const WS_BASE = process.env.NEXT_PUBLIC_WS_URL || "ws://127.0.0.1:8000";

interface UseChatOptions {
  convId:        number | null;
  currentUserId: string | null;
  onMessage?:    (msg: ChatMessage) => void;
  onLu?:         (userId: string) => void;
  onNotification?: (data: { auteur: string; contenu: string; conv_id: number }) => void;
}

interface UseChatReturn {
  isConnected: boolean;
  isTyping:    boolean;
  sendMessage: (contenu: string) => void;
  sendTyping:  () => void;
  markAsRead:  () => void;
  convStatut:  'ouverte' | 'lecture_seule' | 'fermee' | null;
}

/**
 * WebSocket de conversation par ID.
 * ws://host/ws/conv/{convId}/?token={jwt}
 * Reconnexion automatique toutes les 3s.
 */
export function useChat({
  convId,
  currentUserId,
  onMessage,
  onLu,
  onNotification,
}: UseChatOptions): UseChatReturn {
  const wsRef        = useRef<WebSocket | null>(null);
  const reconnectRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const typingRef    = useRef<ReturnType<typeof setTimeout> | null>(null);
  const mountedRef   = useRef(true);
  const cbRefs       = useRef({ onMessage, onLu, onNotification });

  const [isConnected, setIsConnected] = useState(false);
  const [isTyping,    setIsTyping]    = useState(false);
  const [convStatut,  setConvStatut]  = useState<'ouverte' | 'lecture_seule' | 'fermee' | null>(null);

  useEffect(() => {
    cbRefs.current = { onMessage, onLu, onNotification };
  }, [onMessage, onLu, onNotification]);

  const connect = useCallback(() => {
    if (!convId || !mountedRef.current) return;

    const token = typeof window !== "undefined" ? localStorage.getItem("token") : null;
    if (!token) return;

    const url = `${WS_BASE}/ws/conv/${convId}/?token=${encodeURIComponent(token)}`;
    const ws  = new WebSocket(url);
    wsRef.current = ws;

    ws.onopen = () => {
      if (!mountedRef.current) return;
      setIsConnected(true);
      if (reconnectRef.current) {
        clearTimeout(reconnectRef.current);
        reconnectRef.current = null;
      }
    };

    ws.onmessage = (event) => {
      if (!mountedRef.current) return;
      try {
        const data = JSON.parse(event.data as string);

        if (data.type === "message") {
          const msg: ChatMessage = {
            id:        data.id,
            contenu:   data.contenu,
            auteur_id: data.auteur_id,
            username:  data.username,
            timestamp: data.timestamp,
            moi:       data.auteur_id === currentUserId,
          };
          cbRefs.current.onMessage?.(msg);
        }

        if (data.type === "typing" && data.user_id !== currentUserId) {
          setIsTyping(true);
          if (typingRef.current) clearTimeout(typingRef.current);
          typingRef.current = setTimeout(() => setIsTyping(false), 3000);
        }

        if (data.type === "lu") {
          cbRefs.current.onLu?.(data.user_id);
        }

        if (data.type === "error" && data.reason?.startsWith("conversation_")) {
          const statut = data.reason.replace("conversation_", "") as 'lecture_seule' | 'fermee';
          setConvStatut(statut);
        }
      } catch {
        // Ignorer les messages malformés
      }
    };

    ws.onerror = () => { /* reconnexion dans onclose */ };

    ws.onclose = () => {
      if (!mountedRef.current) return;
      setIsConnected(false);
      wsRef.current = null;
      reconnectRef.current = setTimeout(connect, 3000);
    };
  }, [convId, currentUserId]);

  useEffect(() => {
    mountedRef.current = true;
    setConvStatut(null);
    connect();
    return () => {
      mountedRef.current = false;
      if (reconnectRef.current) clearTimeout(reconnectRef.current);
      if (typingRef.current)    clearTimeout(typingRef.current);
      wsRef.current?.close();
      wsRef.current = null;
    };
  }, [connect]);

  const sendMessage = useCallback((contenu: string) => {
    if (wsRef.current?.readyState !== WebSocket.OPEN) return;
    wsRef.current.send(JSON.stringify({ type: "message", contenu }));
  }, []);

  const sendTyping = useCallback(() => {
    if (wsRef.current?.readyState !== WebSocket.OPEN) return;
    wsRef.current.send(JSON.stringify({ type: "typing" }));
  }, []);

  const markAsRead = useCallback(() => {
    if (wsRef.current?.readyState !== WebSocket.OPEN) return;
    wsRef.current.send(JSON.stringify({ type: "lire" }));
  }, []);

  return { isConnected, isTyping, sendMessage, sendTyping, markAsRead, convStatut };
}


/**
 * Hook secondaire — canal de notifications (lecture seule).
 * ws://host/ws/notifications/?token={jwt}
 */
export function useNotifications({
  onNotification,
}: {
  onNotification: (data: { type: string; data: Record<string, unknown> }) => void;
}) {
  const wsRef      = useRef<WebSocket | null>(null);
  const reconnRef  = useRef<ReturnType<typeof setTimeout> | null>(null);
  const mountedRef = useRef(true);
  const cbRef      = useRef(onNotification);

  useEffect(() => { cbRef.current = onNotification; }, [onNotification]);

  const connect = useCallback(() => {
    if (!mountedRef.current) return;
    const token = typeof window !== "undefined" ? localStorage.getItem("token") : null;
    if (!token) return;

    const url = `${WS_BASE}/ws/notifications/?token=${encodeURIComponent(token)}`;
    const ws  = new WebSocket(url);
    wsRef.current = ws;

    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data as string);
        cbRef.current(data);
      } catch { /* ignore */ }
    };

    ws.onclose = () => {
      if (!mountedRef.current) return;
      wsRef.current = null;
      reconnRef.current = setTimeout(connect, 5000);
    };
  }, []);

  useEffect(() => {
    mountedRef.current = true;
    connect();
    return () => {
      mountedRef.current = false;
      if (reconnRef.current) clearTimeout(reconnRef.current);
      wsRef.current?.close();
      wsRef.current = null;
    };
  }, [connect]);
}
