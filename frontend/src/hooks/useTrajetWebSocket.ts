"use client";

import { useEffect, useRef, useState, useCallback } from "react";

const WS_BASE = process.env.NEXT_PUBLIC_WS_URL || "ws://127.0.0.1:8000";

export interface PositionPayload {
    latitude:     number;
    longitude:    number;
    vitesse_kmh?: number;
    heading?:     number;
    timestamp?:   string;
}

export interface PassengerPosition {
    user_id:   string;
    nom:       string;
    latitude:  number;
    longitude: number;
    timestamp?: string;
}

export interface DriverArrivedEvent {
    user_id:    string;
    nom:        string;
    distance_m: number;
}

interface UseTrajetWebSocketOptions {
    trajetId:         string | null;
    onPosition?:      (pos: PositionPayload) => void;
    onPassenger?:     (p: PassengerPosition) => void;
    onDriverArrived?: (e: DriverArrivedEvent) => void;
}

interface UseTrajetWebSocketReturn {
    isConnected:      boolean;
    lastPosition:     PositionPayload | null;
    passengers:       Map<string, PassengerPosition>;
    sendPosition:     (pos: Omit<PositionPayload, 'timestamp'>) => void;
    sendPassengerPos: (nom: string, lat: number, lng: number) => void;
}

/**
 * Hook WebSocket temps réel pour le suivi GPS d'un trajet.
 *
 * Conducteur → sendPosition() pour diffuser sa position à tous
 * Passager   → sendPassengerPos() pour partager sa position avec le conducteur
 *            → reçoit position_update (conducteur), driver_arrived
 * Conducteur → reçoit passenger_position (passagers)
 */
export function useTrajetWebSocket({
    trajetId,
    onPosition,
    onPassenger,
    onDriverArrived,
}: UseTrajetWebSocketOptions): UseTrajetWebSocketReturn {
    const wsRef             = useRef<WebSocket | null>(null);
    const reconnectRef      = useRef<NodeJS.Timeout | null>(null);
    const mountedRef        = useRef(true);
    const onPositionRef     = useRef(onPosition);
    const onPassengerRef    = useRef(onPassenger);
    const onDriverArrivedRef = useRef(onDriverArrived);

    const [isConnected,  setIsConnected]  = useState(false);
    const [lastPosition, setLastPosition] = useState<PositionPayload | null>(null);
    const [passengers,   setPassengers]   = useState<Map<string, PassengerPosition>>(new Map());

    useEffect(() => { onPositionRef.current = onPosition; },      [onPosition]);
    useEffect(() => { onPassengerRef.current = onPassenger; },    [onPassenger]);
    useEffect(() => { onDriverArrivedRef.current = onDriverArrived; }, [onDriverArrived]);

    const connect = useCallback(() => {
        if (!trajetId || !mountedRef.current) return;

        const token = typeof window !== "undefined"
            ? localStorage.getItem("token")
            : null;
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
                const data = JSON.parse(event.data as string);
                if (data.type === "position_update") {
                    const pos: PositionPayload = {
                        latitude:    data.latitude,
                        longitude:   data.longitude,
                        vitesse_kmh: data.vitesse_kmh,
                        heading:     data.heading,
                        timestamp:   data.timestamp,
                    };
                    setLastPosition(pos);
                    onPositionRef.current?.(pos);
                } else if (data.type === "passenger_position") {
                    const p: PassengerPosition = {
                        user_id:   data.user_id,
                        nom:       data.nom,
                        latitude:  data.latitude,
                        longitude: data.longitude,
                        timestamp: data.timestamp,
                    };
                    setPassengers(prev => new Map(prev).set(p.user_id, p));
                    onPassengerRef.current?.(p);
                } else if (data.type === "driver_arrived") {
                    const e: DriverArrivedEvent = {
                        user_id:    data.user_id,
                        nom:        data.nom,
                        distance_m: data.distance_m,
                    };
                    onDriverArrivedRef.current?.(e);
                }
            } catch {
                // Ignorer les messages malformés
            }
        };

        ws.onerror = () => {
            // Silencieux — reconnexion dans onclose
        };

        ws.onclose = () => {
            if (!mountedRef.current) return;
            setIsConnected(false);
            wsRef.current = null;
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

    const sendPosition = useCallback((pos: Omit<PositionPayload, "timestamp">) => {
        if (wsRef.current?.readyState !== WebSocket.OPEN) return;
        wsRef.current.send(JSON.stringify({
            type:      "position",
            timestamp: new Date().toISOString(),
            ...pos,
        }));
    }, []);

    const sendPassengerPos = useCallback((nom: string, lat: number, lng: number) => {
        if (wsRef.current?.readyState !== WebSocket.OPEN) return;
        wsRef.current.send(JSON.stringify({
            type:      "passenger_position",
            nom,
            latitude:  lat,
            longitude: lng,
            timestamp: new Date().toISOString(),
        }));
    }, []);

    return { isConnected, lastPosition, passengers, sendPosition, sendPassengerPos };
}
