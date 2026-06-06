"use client";

import { useEffect, useRef, useCallback } from "react";

const WS_BASE = process.env.NEXT_PUBLIC_WS_URL || "ws://127.0.0.1:8000";

export interface NotifPayload {
    type:      string;  // ex: 'nouvelle_reservation', 'reservation_confirmee', ...
    data:      Record<string, unknown>;
    timestamp: string;
}

interface UseNotifsOptions {
    onNotification?: (notif: NotifPayload) => void;
    enabled?: boolean;
}

/**
 * Hook WebSocket pour les notifications temps réel.
 * Se connecte à ws://host/ws/notifications/?token={jwt}
 * Reconnexion automatique toutes les 5s.
 *
 * Usage dans un layout ou composant racine :
 *   useNotifs({ onNotification: (n) => afficherToast(n) })
 */
export function useNotifs({ onNotification, enabled = true }: UseNotifsOptions = {}): void {
    const wsRef          = useRef<WebSocket | null>(null);
    const reconnectRef   = useRef<NodeJS.Timeout | null>(null);
    const mountedRef     = useRef(true);
    const onNotifRef     = useRef(onNotification);

    useEffect(() => { onNotifRef.current = onNotification; }, [onNotification]);

    const connect = useCallback(() => {
        if (!enabled || !mountedRef.current) return;

        const token = typeof window !== "undefined"
            ? localStorage.getItem("token")
            : null;
        if (!token) return;

        const url = `${WS_BASE}/ws/notifications/?token=${encodeURIComponent(token)}`;
        const ws  = new WebSocket(url);
        wsRef.current = ws;

        ws.onopen  = () => {
            if (!mountedRef.current) return;
            if (reconnectRef.current) {
                clearTimeout(reconnectRef.current);
                reconnectRef.current = null;
            }
        };

        ws.onmessage = (event) => {
            if (!mountedRef.current) return;
            try {
                const data = JSON.parse(event.data) as NotifPayload;
                onNotifRef.current?.(data);
            } catch { /* ignorer */ }
        };

        ws.onerror = () => { /* silencieux */ };

        ws.onclose = () => {
            if (!mountedRef.current) return;
            wsRef.current = null;
            reconnectRef.current = setTimeout(connect, 5000);
        };
    }, [enabled]);

    useEffect(() => {
        mountedRef.current = true;
        connect();
        return () => {
            mountedRef.current = false;
            if (reconnectRef.current) clearTimeout(reconnectRef.current);
            wsRef.current?.close();
            wsRef.current = null;
        };
    }, [connect]);
}
