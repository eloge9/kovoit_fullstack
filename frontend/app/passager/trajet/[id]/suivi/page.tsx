"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import { useParams, useSearchParams, useRouter } from "next/navigation";
import Link from "next/link";
import maplibregl from "maplibre-gl";
import { useTrajetWebSocket, type PositionPayload, type DriverArrivedEvent } from "@/src/hooks/useTrajetWebSocket";
import { api } from "@/src/services/api";
import { useAuth } from "@/src/hooks/useAuth";

// ── Types ─────────────────────────────────────────────────────────────────────

interface TrajetInfo {
    id: number;
    depart: string;
    destination: string;
    statut: string;
    conducteur_nom?: string;
}

// ── Carte suivi conducteur ────────────────────────────────────────────────────

function MapSuivi({
    conducteurPos,
    conducteurNom,
}: {
    conducteurPos: PositionPayload | null;
    conducteurNom: string;
}) {
    const containerRef    = useRef<HTMLDivElement>(null);
    const mapRef          = useRef<maplibregl.Map | null>(null);
    const markerRef       = useRef<maplibregl.Marker | null>(null);
    const initializedRef  = useRef(false);

    useEffect(() => {
        if (mapRef.current || !containerRef.current) return;
        const center: [number, number] = conducteurPos
            ? [conducteurPos.longitude, conducteurPos.latitude]
            : [1.2123, 6.1375];

        mapRef.current = new maplibregl.Map({
            container: containerRef.current,
            style: {
                version: 8,
                sources: {
                    osm: { type: "raster", tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"], tileSize: 256, maxzoom: 19 },
                },
                layers: [{ id: "osm-tiles", type: "raster", source: "osm" }],
            } as maplibregl.StyleSpecification,
            center,
            zoom: 14,
            attributionControl: false,
        });
        mapRef.current.addControl(new maplibregl.NavigationControl({ showCompass: false }), "top-right");

        // Marqueur conducteur (voiture verte)
        const el = document.createElement("div");
        el.style.cssText = `
            width:48px;height:48px;
            background:#16a34a;
            border:3px solid #fff;
            border-radius:50%;
            box-shadow:0 0 0 8px rgba(22,163,74,0.2),0 4px 16px rgba(0,0,0,0.3);
            display:flex;align-items:center;justify-content:center;
            cursor:pointer;
        `;
        el.title = conducteurNom;
        el.innerHTML = `<svg width="24" height="24" viewBox="0 0 24 24" fill="white">
            <path d="M18.92 6.01C18.72 5.42 18.16 5 17.5 5h-11c-.66 0-1.21.42-1.42 1.01L3 12v8c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1h12v1c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-8l-2.08-5.99zM6.5 16c-.83 0-1.5-.67-1.5-1.5S5.67 13 6.5 13s1.5.67 1.5 1.5S7.33 16 6.5 16zm11 0c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zM5 11l1.5-4.5h11L19 11H5z"/>
        </svg>`;

        if (conducteurPos) {
            markerRef.current = new maplibregl.Marker({ element: el })
                .setLngLat([conducteurPos.longitude, conducteurPos.latitude])
                .setPopup(new maplibregl.Popup({ offset: 25 }).setText(conducteurNom))
                .addTo(mapRef.current);
        } else {
            // Stocker le marker pour l'ajouter quand la position arrive
            (mapRef.current as unknown as { _pendingMarkerEl: HTMLElement })._pendingMarkerEl = el;
        }

        initializedRef.current = true;
        return () => { mapRef.current?.remove(); mapRef.current = null; };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    // Mettre à jour position conducteur
    useEffect(() => {
        if (!conducteurPos || !mapRef.current) return;
        const lngLat: [number, number] = [conducteurPos.longitude, conducteurPos.latitude];

        if (markerRef.current) {
            markerRef.current.setLngLat(lngLat);
        } else {
            // Créer le marker si pas encore sur la carte
            const el = document.createElement("div");
            el.style.cssText = `
                width:48px;height:48px;
                background:#16a34a;
                border:3px solid #fff;
                border-radius:50%;
                box-shadow:0 0 0 8px rgba(22,163,74,0.2),0 4px 16px rgba(0,0,0,0.3);
                display:flex;align-items:center;justify-content:center;
            `;
            el.innerHTML = `<svg width="24" height="24" viewBox="0 0 24 24" fill="white">
                <path d="M18.92 6.01C18.72 5.42 18.16 5 17.5 5h-11c-.66 0-1.21.42-1.42 1.01L3 12v8c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1h12v1c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-8l-2.08-5.99zM6.5 16c-.83 0-1.5-.67-1.5-1.5S5.67 13 6.5 13s1.5.67 1.5 1.5S7.33 16 6.5 16zm11 0c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zM5 11l1.5-4.5h11L19 11H5z"/>
            </svg>`;
            markerRef.current = new maplibregl.Marker({ element: el })
                .setLngLat(lngLat)
                .setPopup(new maplibregl.Popup({ offset: 25 }).setText(conducteurNom))
                .addTo(mapRef.current);
        }

        mapRef.current.easeTo({ center: lngLat, duration: 800, zoom: 15 });
    }, [conducteurPos, conducteurNom]);

    return (
        <div ref={containerRef} style={{ width: "100%", height: "100%" }}
            className="z-0 rounded-2xl overflow-hidden" />
    );
}

// ── Overlay "Conducteur arrivé" ───────────────────────────────────────────────

function DriverArrivedOverlay({
    event,
    conducteurNom,
    onDismiss,
}: {
    event: DriverArrivedEvent;
    conducteurNom: string;
    onDismiss: () => void;
}) {
    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm">
            <div className="bg-white rounded-3xl shadow-2xl p-8 max-w-sm w-full text-center animate-in slide-in-from-bottom duration-300">
                <div className="w-20 h-20 bg-success/10 rounded-full flex items-center justify-center mx-auto mb-5">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-10 w-10 text-success" viewBox="0 0 24 24" fill="currentColor">
                        <path d="M18.92 6.01C18.72 5.42 18.16 5 17.5 5h-11c-.66 0-1.21.42-1.42 1.01L3 12v8c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1h12v1c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-8l-2.08-5.99z"/>
                    </svg>
                </div>
                <h2 className="text-2xl font-bold text-base-content mb-2">Conducteur arrivé !</h2>
                <p className="text-base-content/60 text-sm mb-1">
                    <span className="font-semibold text-base-content">{conducteurNom}</span> est à{" "}
                    <span className="font-bold text-success">{event.distance_m} m</span> de vous.
                </p>
                <p className="text-base-content/50 text-xs mb-6">Préparez-vous à monter dans le véhicule.</p>
                <button
                    onClick={onDismiss}
                    className="btn btn-success btn-lg rounded-full w-full text-white font-bold"
                >
                    Je monte ! 🚗
                </button>
            </div>
        </div>
    );
}

// ── Indicateur statut ─────────────────────────────────────────────────────────

function StatusDot({ ok, label }: { ok: boolean; label: string }) {
    return (
        <div className="flex items-center gap-2">
            <span className={`w-2.5 h-2.5 rounded-full shrink-0 ${ok ? "bg-success animate-pulse" : "bg-base-300"}`} />
            <span className={`text-xs font-medium ${ok ? "text-success" : "text-base-content/40"}`}>{label}</span>
        </div>
    );
}

// ── Calcul ETA approximatif ───────────────────────────────────────────────────

function etaLabel(pos: PositionPayload | null): string {
    if (!pos || !pos.vitesse_kmh || pos.vitesse_kmh < 2) return "—";
    return `${pos.vitesse_kmh.toFixed(0)} km/h`;
}

// ── Page principale ───────────────────────────────────────────────────────────

export default function PassagerSuiviPage() {
    const params       = useParams();
    const searchParams = useSearchParams();
    const router       = useRouter();
    const { user }     = useAuth();

    const trajetId = params?.id as string | undefined;

    const [trajet,           setTrajet]           = useState<TrajetInfo | null>(null);
    const [loading,          setLoading]          = useState(true);
    const [driverArrivedEvt, setDriverArrivedEvt] = useState<DriverArrivedEvent | null>(null);
    const [dismissed,        setDismissed]        = useState(false);

    // Partage de position du passager
    const watchIdRef      = useRef<number | null>(null);
    const sendIntervalRef = useRef<NodeJS.Timeout | null>(null);
    const lastPosRef      = useRef<GeolocationPosition | null>(null);
    const [gpsActive, setGpsActive] = useState(false);

    const conducteurNom = trajet?.conducteur_nom
        ?? searchParams.get("conducteur")
        ?? "Conducteur";

    const wsTrajetId = trajet?.statut === "en_cours" ? trajetId ?? null : null;

    const { isConnected, lastPosition, sendPassengerPos } = useTrajetWebSocket({
        trajetId: wsTrajetId,
        onDriverArrived: useCallback((e: DriverArrivedEvent) => {
            if (!dismissed) setDriverArrivedEvt(e);
        }, [dismissed]),
    });

    // ── Charger les infos trajet ──────────────────────────────────────────────

    useEffect(() => {
        if (!trajetId) { setLoading(false); return; }
        api(`/trajets/${trajetId}/`)
            .then(d => setTrajet(d))
            .catch(() => setTrajet(null))
            .finally(() => setLoading(false));
    }, [trajetId]);

    // ── Partage de position passager ──────────────────────────────────────────

    const startGps = useCallback(() => {
        if (!navigator.geolocation || gpsActive) return;
        setGpsActive(true);
        watchIdRef.current = navigator.geolocation.watchPosition(
            (pos) => { lastPosRef.current = pos; },
            () => setGpsActive(false),
            { enableHighAccuracy: true, maximumAge: 0, timeout: 10000 },
        );
        // Envoyer toutes les 4 secondes
        const nom = user ? `${user.first_name ?? ""} ${user.last_name ?? ""}`.trim() || user.username : "";
        sendIntervalRef.current = setInterval(() => {
            const pos = lastPosRef.current;
            if (pos && isConnected) {
                sendPassengerPos(nom, pos.coords.latitude, pos.coords.longitude);
            }
        }, 4000);
    }, [gpsActive, isConnected, sendPassengerPos]);

    const stopGps = useCallback(() => {
        if (watchIdRef.current !== null) {
            navigator.geolocation.clearWatch(watchIdRef.current);
            watchIdRef.current = null;
        }
        if (sendIntervalRef.current) {
            clearInterval(sendIntervalRef.current);
            sendIntervalRef.current = null;
        }
        setGpsActive(false);
    }, []);

    // Démarrer GPS auto quand connecté au trajet
    useEffect(() => {
        if (isConnected && !gpsActive) startGps();
    }, [isConnected, gpsActive, startGps]);

    useEffect(() => () => stopGps(), [stopGps]);

    // ── Rendu ─────────────────────────────────────────────────────────────────

    if (!trajetId) return (
        <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4">
            <p className="text-base-content/50 text-sm">Aucun trajet sélectionné.</p>
            <Link href="/passager/reservations" className="btn btn-primary btn-sm rounded-full">Mes réservations</Link>
        </div>
    );

    if (loading) return (
        <div className="flex items-center justify-center min-h-[60vh]">
            <span className="loading loading-spinner loading-lg text-primary" />
        </div>
    );

    const trajetEnCours = trajet?.statut === "en_cours";

    return (
        <div className="space-y-5 max-w-4xl mx-auto">

            {/* Overlay arrivée conducteur */}
            {driverArrivedEvt && !dismissed && (
                <DriverArrivedOverlay
                    event={driverArrivedEvt}
                    conducteurNom={conducteurNom}
                    onDismiss={() => { setDismissed(true); setDriverArrivedEvt(null); }}
                />
            )}

            {/* ── En-tête ── */}
            <div className="flex items-center gap-3 pb-4 border-b border-base-300">
                <button
                    onClick={() => router.back()}
                    className="btn btn-ghost btn-sm btn-square rounded-xl"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
                    </svg>
                </button>
                <div>
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">Suivi en temps réel</p>
                    <h1 className="text-lg font-bold text-base-content">
                        {trajet ? `${trajet.depart} → ${trajet.destination}` : `Trajet #${trajetId}`}
                    </h1>
                </div>
                {trajet?.statut && (
                    <span className={`badge badge-sm rounded-full ml-auto font-medium ${
                        trajetEnCours ? "badge-success" : "badge-ghost"
                    }`}>
                        {trajetEnCours ? "En cours" : trajet.statut}
                    </span>
                )}
            </div>

            {/* ── Avertissement si trajet non démarré ── */}
            {trajet && !trajetEnCours && (
                <div className="bg-warning/10 border border-warning/25 rounded-2xl p-4 flex items-start gap-3">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-warning shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                    </svg>
                    <div>
                        <p className="text-sm font-semibold text-warning">Trajet pas encore démarré</p>
                        <p className="text-xs text-base-content/60 mt-0.5">
                            Le conducteur n&apos;a pas encore démarré ce trajet. Revenez quand il est en cours.
                        </p>
                    </div>
                </div>
            )}

            {/* ── Infos conducteur ── */}
            <div className="bg-base-100 rounded-2xl border border-base-200 p-4">
                <div className="flex items-center gap-3 mb-3">
                    <div className="w-10 h-10 rounded-full bg-success/10 flex items-center justify-center shrink-0">
                        <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-success" viewBox="0 0 24 24" fill="currentColor">
                            <path d="M18.92 6.01C18.72 5.42 18.16 5 17.5 5h-11c-.66 0-1.21.42-1.01 1.01L3 12v8c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-1h12v1c0 .55.45 1 1 1h1c.55 0 1-.45 1-1v-8l-2.08-5.99z"/>
                        </svg>
                    </div>
                    <div>
                        <p className="text-xs text-base-content/40 font-medium">Conducteur</p>
                        <p className="text-sm font-bold text-base-content">{conducteurNom}</p>
                    </div>
                    {lastPosition && (
                        <span className="ml-auto text-sm font-bold text-success">
                            {etaLabel(lastPosition)}
                        </span>
                    )}
                </div>
                <div className="flex flex-wrap gap-x-5 gap-y-2">
                    <StatusDot ok={isConnected} label={isConnected ? "Connecté au trajet" : "Connexion…"} />
                    <StatusDot ok={lastPosition !== null} label={lastPosition ? "Position conducteur reçue" : "En attente de position…"} />
                    <StatusDot ok={gpsActive} label={gpsActive ? "Votre position partagée" : "Position non partagée"} />
                </div>
            </div>

            {/* ── Carte ── */}
            <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden" style={{ height: 420 }}>
                {trajetEnCours ? (
                    lastPosition ? (
                        <MapSuivi conducteurPos={lastPosition} conducteurNom={conducteurNom} />
                    ) : (
                        <div className="h-full flex flex-col items-center justify-center text-base-content/30 gap-3">
                            <div className="loading loading-spinner loading-lg text-primary" />
                            <p className="text-sm">En attente de la position du conducteur…</p>
                            <p className="text-xs text-base-content/40">
                                {conducteurNom} doit avoir activé le GPS sur son application.
                            </p>
                        </div>
                    )
                ) : (
                    <div className="h-full flex flex-col items-center justify-center text-base-content/30 gap-3">
                        <svg xmlns="http://www.w3.org/2000/svg" className="h-12 w-12" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                        </svg>
                        <p className="text-sm">Carte disponible quand le trajet est en cours</p>
                    </div>
                )}
            </div>

            {/* ── Info suivi actif ── */}
            {trajetEnCours && isConnected && (
                <div className="bg-success/8 border border-success/20 rounded-2xl p-4 flex items-start gap-3">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-success shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <div>
                        <p className="text-sm font-semibold text-success">Suivi actif</p>
                        <p className="text-xs text-base-content/60">
                            Vous suivez la position de {conducteurNom} en temps réel.
                            {gpsActive && " Votre position est partagée avec le conducteur."}
                        </p>
                    </div>
                </div>
            )}

        </div>
    );
}
