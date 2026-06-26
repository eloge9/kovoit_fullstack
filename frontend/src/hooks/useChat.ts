"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import type { ChatMessage } from "@/src/services/messagerie.service";

export type { ChatMessage };

const WS_BASE = process.env.NEXT_PUBLIC_WS_URL || "ws://127.0.0.1:8000";

interface UseChatOptions {
  convId:          number | null;
  currentUserId:   string | null;
  onMessage?:      (msg: ChatMessage) => void;
  onMessageEdited?:(msgId: number, contenu: string, editedAt: string) => void;
  onMessageDeleted?:(msgId: number, pourTous: boolean) => void;
  onReaction?:     (msgId: number, emoji: string, userId: string, action: 'add' | 'remove') => void;
  onLu?:           (userId: string) => void;
  onUserOnline?:   (userId: string, online: boolean) => void;
  onNotification?: (data: { auteur: string; contenu: string; conv_id: number }) => void;
}

interface UseChatReturn {
  isConnected:    boolean;
  isTyping:       boolean;
  typingUsername: string;
  convStatut:     'ouverte' | 'lecture_seule' | 'fermee' | null;
  interlocuteurEnLigne: boolean;
  sendMessage:    (contenu: string, replyToId?: number) => void;
  sendEdit:       (msgId: number, contenu: string) => void;
  sendDelete:     (msgId: number, pourTous: boolean) => void;
  sendReact:      (msgId: number, emoji: string) => void;
  sendTyping:     () => void;
  markAsRead:     () => void;
}

export function useChat({
  convId,
  currentUserId,
  onMessage,
  onMessageEdited,
  onMessageDeleted,
  onReaction,
  onLu,
  onUserOnline,
  onNotification,
}: UseChatOptions): UseChatReturn {
  const wsRef        = useRef<WebSocket | null>(null);
  const reconnectRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const typingRef    = useRef<ReturnType<typeof setTimeout> | null>(null);
  const mountedRef   = useRef(true);
  const cbRefs       = useRef({
    onMessage, onMessageEdited, onMessageDeleted, onReaction, onLu, onUserOnline, onNotification,
  });

  const [isConnected,           setIsConnected]           = useState(false);
  const [isTyping,              setIsTyping]              = useState(false);
  const [typingUsername,        setTypingUsername]        = useState("");
  const [convStatut,            setConvStatut]            = useState<'ouverte' | 'lecture_seule' | 'fermee' | null>(null);
  const [interlocuteurEnLigne,  setInterlocuteurEnLigne]  = useState(false);

  useEffect(() => {
    cbRefs.current = {
      onMessage, onMessageEdited, onMessageDeleted, onReaction,
      onLu, onUserOnline, onNotification,
    };
  });

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
      if (reconnectRef.current) { clearTimeout(reconnectRef.current); reconnectRef.current = null; }
    };

    ws.onmessage = (event) => {
      if (!mountedRef.current) return;
      try {
        const data = JSON.parse(event.data as string);

        if (data.type === "message") {
          const msg: ChatMessage = {
            id:             data.id,
            deleted:        data.deleted ?? false,
            contenu:        data.contenu,
            message_type:   data.message_type ?? 'text',
            audio_url:      data.audio_url ?? null,
            audio_duration: data.audio_duration ?? null,
            auteur_id:      data.auteur_id,
            username:       data.username,
            timestamp:      data.timestamp,
            moi:            data.auteur_id === currentUserId,
            is_edited:      data.is_edited ?? false,
            edited_at:      data.edited_at ?? null,
            reply_to:       data.reply_to ?? null,
            reactions:      data.reactions ?? {},
            is_read:        false,
          };
          cbRefs.current.onMessage?.(msg);
        }

        if (data.type === "message_edited") {
          cbRefs.current.onMessageEdited?.(data.message_id, data.contenu, data.edited_at);
        }

        if (data.type === "message_deleted") {
          cbRefs.current.onMessageDeleted?.(data.message_id, data.pour_tous);
        }

        if (data.type === "reaction") {
          cbRefs.current.onReaction?.(data.message_id, data.emoji, data.user_id, data.action);
        }

        if (data.type === "typing" && data.user_id !== currentUserId) {
          setIsTyping(true);
          setTypingUsername(data.username ?? "");
          if (typingRef.current) clearTimeout(typingRef.current);
          typingRef.current = setTimeout(() => { setIsTyping(false); setTypingUsername(""); }, 3000);
        }

        if (data.type === "lu") {
          cbRefs.current.onLu?.(data.user_id);
        }

        if (data.type === "user_online" && data.user_id !== currentUserId) {
          setInterlocuteurEnLigne(data.online);
          cbRefs.current.onUserOnline?.(data.user_id, data.online);
        }

        if (data.type === "error" && data.reason?.startsWith("conversation_")) {
          const statut = data.reason.replace("conversation_", "") as 'lecture_seule' | 'fermee';
          setConvStatut(statut);
        }
      } catch { /* ignorer messages malformés */ }
    };

    ws.onerror = () => { /* reconnexion dans onclose */ };

    ws.onclose = () => {
      if (!mountedRef.current) return;
      setIsConnected(false);
      setInterlocuteurEnLigne(false);
      wsRef.current = null;
      reconnectRef.current = setTimeout(connect, 3000);
    };
  }, [convId, currentUserId]);

  useEffect(() => {
    mountedRef.current = true;
    setConvStatut(null);
    setInterlocuteurEnLigne(false);
    connect();
    return () => {
      mountedRef.current = false;
      if (reconnectRef.current) clearTimeout(reconnectRef.current);
      if (typingRef.current)    clearTimeout(typingRef.current);
      wsRef.current?.close();
      wsRef.current = null;
    };
  }, [connect]);

  const sendRaw = useCallback((payload: object) => {
    if (wsRef.current?.readyState !== WebSocket.OPEN) return;
    wsRef.current.send(JSON.stringify(payload));
  }, []);

  const sendMessage = useCallback((contenu: string, replyToId?: number) => {
    sendRaw({ type: "message", contenu, ...(replyToId ? { reply_to_id: replyToId } : {}) });
  }, [sendRaw]);

  const sendEdit = useCallback((msgId: number, contenu: string) => {
    sendRaw({ type: "edit_message", message_id: msgId, contenu });
  }, [sendRaw]);

  const sendDelete = useCallback((msgId: number, pourTous: boolean) => {
    sendRaw({ type: "delete_message", message_id: msgId, pour_tous: pourTous });
  }, [sendRaw]);

  const sendReact = useCallback((msgId: number, emoji: string) => {
    sendRaw({ type: "react", message_id: msgId, emoji });
  }, [sendRaw]);

  const sendTyping = useCallback(() => {
    sendRaw({ type: "typing" });
  }, [sendRaw]);

  const markAsRead = useCallback(() => {
    sendRaw({ type: "lire" });
  }, [sendRaw]);

  return {
    isConnected, isTyping, typingUsername, convStatut, interlocuteurEnLigne,
    sendMessage, sendEdit, sendDelete, sendReact, sendTyping, markAsRead,
  };
}


export function useNotifications({
  onNotification,
}: {
  onNotification: (data: { type: string; data: Record<string, unknown> }) => void;
}) {
  const wsRef      = useRef<WebSocket | null>(null);
  const reconnRef  = useRef<ReturnType<typeof setTimeout> | null>(null);
  const mountedRef = useRef(true);
  const cbRef      = useRef(onNotification);

  useEffect(() => { cbRef.current = onNotification; });

  const connect = useCallback(() => {
    if (!mountedRef.current) return;
    const token = typeof window !== "undefined" ? localStorage.getItem("token") : null;
    if (!token) return;

    const url = `${WS_BASE}/ws/notifications/?token=${encodeURIComponent(token)}`;
    const ws  = new WebSocket(url);
    wsRef.current = ws;

    ws.onmessage = (event) => {
      try { cbRef.current(JSON.parse(event.data as string)); } catch { /* ignore */ }
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
