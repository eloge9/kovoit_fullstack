"use client";

import { useEffect, useRef, useState, useCallback } from "react";

const WS_BASE = process.env.NEXT_PUBLIC_WS_URL || "ws://127.0.0.1:8000";

export interface PositionPayload {
    latitude:    number;
    longitude:   number;
    vitesse_kmh?: number;
    direction?:  number;
    timestamp?:  string;
}

interface UseTrajetWebSocketOptions {
    trajetId: string | null;
    onPosition?: (pos: PositionPayload) => void;
}

interface UseTrajetWebSocketReturn {
    isConnected: boolean;
    lastPosition: PositionPayload | null;
    sendPosition: (pos: Omit<PositionPayload, 'timestamp'>) => void;
}

/**
 * Hook pour la communication WebSocket temps réel sur un trajet.
 *
 * Conducteur  → appelle sendPosition() pour diffuser sa position GPS
 * Passager    → reçoit les positions via onPosition() ou lastPosition
 *
 * Room : ws://host/ws/trajet/{trajetId}/
 */
export function useTrajetWebSocket({
    trajetId,
    onPosition,
}: UseTrajetWebSocketOptions): UseTrajetWebSocketReturn {
    const wsRef           = useRef<WebSocket | null>(null);
    const reconnectRef    = useRef<NodeJS.Timeout | null>(null);
    const mountedRef      = useRef(true);
    const onPositionRef   = useRef(onPosition);

    const [isConnected,  setIsConnected]  = useState(false);
    const [lastPosition, setLastPosition] = useState<PositionPayload | null>(null);

    // Garder onPosition à jour sans recréer la connexion
    useEffect(() => { onPositionRef.current = onPosition; }, [onPosition]);

    const connect = useCallback(() => {
        if (!trajetId || !mountedRef.current) return;

        const token = typeof window !== "undefined"
            ? localStorage.getItem("token")
            : null;

        // Sans token valide on n'ouvre pas la connexion (le serveur refuserait 4003)
        if (!token) return;

        const url = `${WS_BASE}/ws/trajet/${trajetId}/?token=${encodeURIComponent(token)}`;
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
                if (data.type === 'position_update') {
                    const pos: PositionPayload = {
                        latitude:    data.latitude,
                        longitude:   data.longitude,
                        vitesse_kmh: data.vitesse_kmh,
                        direction:   data.direction,
                        timestamp:   data.timestamp,
                    };
                    setLastPosition(pos);
                    onPositionRef.current?.(pos);
                }
            } catch {
                // Ignorer les messages malformés
            }
        };

        ws.onerror = () => {
            // Silencieux en prod — reconnexion automatique dans onclose
        };

        ws.onclose = () => {
            if (!mountedRef.current) return;
            setIsConnected(false);
            wsRef.current = null;
            // Tenter une reconnexion toutes les 3 secondes
            reconnectRef.current = setTimeout(connect, 3000);
        };
    }, [trajetId]);

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

    const sendPosition = useCallback((pos: Omit<PositionPayload, 'timestamp'>) => {
        if (wsRef.current?.readyState !== WebSocket.OPEN) return;
        wsRef.current.send(JSON.stringify({
            type:      'position',
            timestamp: new Date().toISOString(),
            ...pos,
        }));
    }, []);

    return { isConnected, lastPosition, sendPosition };
}
