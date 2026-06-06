"use client";

import { useEffect, useRef, useState, useCallback } from "react";

const WS_BASE = process.env.NEXT_PUBLIC_WS_URL || "ws://127.0.0.1:8000";

export interface ChatMessage {
    id:            number;
    contenu:       string;
    expediteur_id: string;
    username:      string;
    timestamp:     string;
    moi:           boolean;
}

interface UseChatOptions {
    otherUserId: string | null;
    currentUserId: string | null;
    onMessage?: (msg: ChatMessage) => void;
}

interface UseChatReturn {
    isConnected:  boolean;
    isTyping:     boolean;
    sendMessage:  (contenu: string) => void;
    sendTyping:   () => void;
    markAsRead:   () => void;
}

/**
 * Hook WebSocket pour le chat pair-à-pair.
 * Même structure que useTrajetWebSocket — reconnexion automatique toutes les 3s.
 *
 * ws://host/ws/chat/{otherUserId}/?token={jwt}
 */
export function useChat({
    otherUserId,
    currentUserId,
    onMessage,
}: UseChatOptions): UseChatReturn {
    const wsRef         = useRef<WebSocket | null>(null);
    const reconnectRef  = useRef<NodeJS.Timeout | null>(null);
    const typingRef     = useRef<NodeJS.Timeout | null>(null);
    const mountedRef    = useRef(true);
    const onMessageRef  = useRef(onMessage);

    const [isConnected, setIsConnected] = useState(false);
    const [isTyping,    setIsTyping]    = useState(false);

    useEffect(() => { onMessageRef.current = onMessage; }, [onMessage]);

    const connect = useCallback(() => {
        if (!otherUserId || !mountedRef.current) return;

        const token = typeof window !== "undefined"
            ? localStorage.getItem("token")
            : null;
        if (!token) return;

        const url = `${WS_BASE}/ws/chat/${otherUserId}/?token=${encodeURIComponent(token)}`;
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
                const data = JSON.parse(event.data);

                if (data.type === "message") {
                    const msg: ChatMessage = {
                        id:            data.id,
                        contenu:       data.contenu,
                        expediteur_id: data.expediteur_id,
                        username:      data.username,
                        timestamp:     data.timestamp,
                        moi:           data.expediteur_id === currentUserId,
                    };
                    onMessageRef.current?.(msg);
                }

                if (data.type === "typing" && data.user_id !== currentUserId) {
                    setIsTyping(true);
                    if (typingRef.current) clearTimeout(typingRef.current);
                    typingRef.current = setTimeout(() => setIsTyping(false), 3000);
                }
            } catch {
                // Ignorer les messages malformés
            }
        };

        ws.onerror = () => { /* silencieux — reconnexion dans onclose */ };

        ws.onclose = () => {
            if (!mountedRef.current) return;
            setIsConnected(false);
            wsRef.current = null;
            reconnectRef.current = setTimeout(connect, 3000);
        };
    }, [otherUserId, currentUserId]);

    useEffect(() => {
        mountedRef.current = true;
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
        wsRef.current.send(JSON.stringify({ type: "lu" }));
    }, []);

    return { isConnected, isTyping, sendMessage, sendTyping, markAsRead };
}
