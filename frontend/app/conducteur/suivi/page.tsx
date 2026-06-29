"use client";

import { Suspense, useEffect, useRef, useState, useCallback } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import maplibregl from "maplibre-gl";
import { useTrajetWebSocket, type PassengerPosition } from "@/src/hooks/useTrajetWebSocket";
import trajetApi from "@/libs/trajet-api";

// ── Types ─────────────────────────────────────────────────────────────────────

interface TrajetInfo {
    id: number;
    depart: string;
    destination: string;
    statut: string;
    places_disponibles: number;
}

// ── Carte en temps réel (conducteur) ─────────────────────────────────────────

function MapLivePosition({
    lat, lng, passengers,
}: { lat: number; lng: number; passengers: Map<string, PassengerPosition> }) {
    const containerRef    = useRef<HTMLDivElement>(null);
    const mapRef          = useRef<maplibregl.Map | null>(null);
    const markerRef       = useRef<maplibregl.Marker | null>(null);
    const passengerMarkersRef = useRef<Map<string, maplibregl.Marker>>(new Map());
    const initializedRef  = useRef(false);

    useEffect(() => {
        if (mapRef.current || !containerRef.current) return;
        mapRef.current = new maplibregl.Map({
            container: containerRef.current,
            style: {
                version: 8,
                sources: { osm: { type: "raster", tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"], tileSize: 256, maxzoom: 19 } },
                layers: [{ id: "osm-tiles", type: "raster", source: "osm" }],
            } as maplibregl.StyleSpecification,
            center: [lng, lat],
            zoom: 15,
            attributionControl: false,
        });
        mapRef.current.addControl(new maplibregl.NavigationControl({ showCompass: false }), "top-right");

        // Marqueur conducteur (bleu)
        const el = document.createElement("div");
        el.style.cssText = `
            width:44px;height:44px;
            background:#2563eb;
            border:3px solid #fff;
            border-radius:50%;
            box-shadow:0 0 0 8px rgba(37,99,235,0.2),0 4px 12px rgba(0,0,0,0.3);
            display:flex;align-items:center;justify-content:center;
        `;
        el.innerHTML = `<svg width="22" height="22" viewBox="0 0 24 24" fill="white">
            <path d="M21 3L3 10.53v.98l6.84 2.65L12.48 21h.98L21 3z"/>
        </svg>`;
        el.title = "Vous";

        markerRef.current = new maplibregl.Marker({ element: el })
            .setLngLat([lng, lat])
            .addTo(mapRef.current);

        initializedRef.current = true;
        return () => {
            passengerMarkersRef.current.forEach(m => m.remove());
            passengerMarkersRef.current.clear();
            mapRef.current?.remove();
            mapRef.current = null;
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    // Mettre à jour position conducteur
    useEffect(() => {
        if (!initializedRef.current) return;
        markerRef.current?.setLngLat([lng, lat]);
        mapRef.current?.easeTo({ center: [lng, lat], duration: 800 });
    }, [lat, lng]);

    // Mettre à jour marqueurs passagers
    useEffect(() => {
        if (!mapRef.current || !initializedRef.current) return;
        const existing = passengerMarkersRef.current;

        passengers.forEach((p, userId) => {
            const lngLat: [number, number] = [p.longitude, p.latitude];
            if (existing.has(userId)) {
                existing.get(userId)!.setLngLat(lngLat);
            } else {
                // Créer marqueur passager (orange)
                const el = document.createElement("div");
                const initiale = p.nom.charAt(0).toUpperCase() || "?";
                el.style.cssText = `
                    width:40px;height:40px;
                    background:#f97316;
                    border:3px solid #fff;
                    border-radius:50%;
                    box-shadow:0 0 0 6px rgba(249,115,22,0.2),0 4px 12px rgba(0,0,0,0.25);
                    display:flex;align-items:center;justify-content:center;
                    color:white;font-weight:700;font-size:16px;cursor:pointer;
                `;
                el.textContent = initiale;
                el.title = p.nom;

                const marker = new maplibregl.Marker({ element: el })
                    .setLngLat(lngLat)
                    .setPopup(new maplibregl.Popup({ offset: 25 }).setText(`${p.nom} — passager`))
                    .addTo(mapRef.current!);
                existing.set(userId, marker);
            }
        });

        // Supprimer les marqueurs des passagers disparus
        existing.forEach((marker, userId) => {
            if (!passengers.has(userId)) {
                marker.remove();
                existing.delete(userId);
            }
        });
    }, [passengers]);

    return <div ref={containerRef} style={{ width: "100%", height: "100%" }} className="z-0 rounded-2xl overflow-hidden" />;
}

// ── Indicateur état ───────────────────────────────────────────────────────────

function StatusDot({ ok, label }: { ok: boolean; label: string }) {
    return (
        <div className="flex items-center gap-2">
            <span className={`w-2.5 h-2.5 rounded-full shrink-0 ${ok ? "bg-success animate-pulse" : "bg-base-300"}`} />
            <span className={`text-xs font-medium ${ok ? "text-success" : "text-base-content/40"}`}>{label}</span>
        </div>
    );
}

// ── Page principale ───────────────────────────────────────────────────────────

function ConducteurSuiviContent() {
    const router       = useRouter();
    const searchParams = useSearchParams();
    const trajetId     = searchParams.get("trajet");

    const [trajet,       setTrajet]       = useState<TrajetInfo | null>(null);
    const [loading,      setLoading]      = useState(true);
    const [position,     setPosition]     = useState<GeolocationPosition | null>(null);
    const [gpsError,     setGpsError]     = useState<string | null>(null);
    const [gpsActive,    setGpsActive]    = useState(false);
    const [lastSent,     setLastSent]     = useState<Date | null>(null);
    const [accuracy,     setAccuracy]     = useState<number | null>(null);

    const watchIdRef   = useRef<number | null>(null);
    const sendIntervalRef = useRef<NodeJS.Timeout | null>(null);
    const lastPositionRef = useRef<GeolocationPosition | null>(null);

    // Ne connecter le WS que si le trajet est réellement en_cours (sinon rejet 4003)
    const wsTrajetId = trajet?.statut === "en_cours" ? trajetId : null;
    const { isConnected, sendPosition, passengers } = useTrajetWebSocket({ trajetId: wsTrajetId });

    // ── Charger les infos du trajet ───────────────────────────────────────────

    useEffect(() => {
        if (!trajetId) { setLoading(false); return; }
        trajetApi.getTrajet(trajetId)
            .then((data: unknown) => setTrajet(data as TrajetInfo))
            .catch(() => setTrajet(null))
            .finally(() => setLoading(false));
    }, [trajetId]);

    // ── Envoyer la position toutes les 2 secondes ─────────────────────────────

    const startSending = useCallback(() => {
        if (sendIntervalRef.current) return;
        sendIntervalRef.current = setInterval(() => {
            const pos = lastPositionRef.current;
            if (!pos || !isConnected) return;
            sendPosition({
                latitude:    pos.coords.latitude,
                longitude:   pos.coords.longitude,
                vitesse_kmh: pos.coords.speed != null ? pos.coords.speed * 3.6 : 0,
                heading:     pos.coords.heading ?? undefined,
            });
            setLastSent(new Date());
        }, 2000);
    }, [isConnected, sendPosition]);

    const stopSending = useCallback(() => {
        if (sendIntervalRef.current) { clearInterval(sendIntervalRef.current); sendIntervalRef.current = null; }
    }, []);

    // ── Activer la géolocalisation ────────────────────────────────────────────

    const activerGPS = useCallback(() => {
        if (!navigator.geolocation) {
            setGpsError("La géolocalisation n'est pas supportée par votre navigateur.");
            return;
        }
        setGpsError(null);
        setGpsActive(true);

        watchIdRef.current = navigator.geolocation.watchPosition(
            (pos) => {
                setPosition(pos);
                setAccuracy(Math.round(pos.coords.accuracy));
                lastPositionRef.current = pos;
            },
            (err) => {
                setGpsError(
                    err.code === 1 ? "Permission GPS refusée. Autorisez la localisation dans votre navigateur." :
                    err.code === 2 ? "Position GPS indisponible." :
                    "Délai d'attente GPS dépassé."
                );
                setGpsActive(false);
            },
            { enableHighAccuracy: true, maximumAge: 0, timeout: 10000 }
        );
    }, []);

    const arreterGPS = useCallback(() => {
        if (watchIdRef.current !== null) {
            navigator.geolocation.clearWatch(watchIdRef.current);
            watchIdRef.current = null;
        }
        stopSending();
        setGpsActive(false);
        lastPositionRef.current = null;
    }, [stopSending]);

    // Démarrer/arrêter l'envoi selon la connexion WS et GPS
    useEffect(() => {
        if (isConnected && gpsActive && position) startSending();
        else stopSending();
        return stopSending;
    }, [isConnected, gpsActive, position, startSending, stopSending]);

    // Nettoyer en quittant la page
    useEffect(() => {
        return () => {
            if (watchIdRef.current !== null) navigator.geolocation.clearWatch(watchIdRef.current);
            if (sendIntervalRef.current) clearInterval(sendIntervalRef.current);
        };
    }, []);

    // ── Vérifications préalables ──────────────────────────────────────────────

    if (!trajetId) return (
        <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4">
            <p className="text-base-content/50 text-sm">Aucun trajet sélectionné.</p>
            <Link href="/conducteur/trajets" className="btn btn-primary btn-sm rounded-full">Mes trajets</Link>
        </div>
    );

    if (loading) return (
        <div className="flex items-center justify-center min-h-[60vh]">
            <span className="loading loading-spinner loading-lg text-primary" />
        </div>
    );

    const lat = position?.coords.latitude;
    const lng = position?.coords.longitude;
    const speed = position?.coords.speed != null ? (position.coords.speed * 3.6).toFixed(0) : null;

    const trajetEnCours = trajet?.statut === "en_cours";
    const peutConnecter = trajetEnCours;

    return (
        <div className="space-y-5 max-w-4xl mx-auto">

            {/* ── En-tête ── */}
            <div className="flex items-center gap-3 pb-4 border-b border-base-300">
                <button
                    onClick={() => { arreterGPS(); router.push(`/conducteur/trajets/${trajetId}/detail`); }}
                    className="btn btn-ghost btn-sm btn-square rounded-xl"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
                    </svg>
                </button>
                <div>
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">Suivi GPS en direct</p>
                    <h1 className="text-lg font-bold text-base-content">
                        {trajet ? `${trajet.depart} → ${trajet.destination}` : `Trajet #${trajetId}`}
                    </h1>
                </div>
                {trajet && (
                    <span className={`badge badge-sm rounded-full ml-auto font-medium ${
                        trajet.statut === "en_cours" ? "badge-success" :
                        trajet.statut === "ouvert"   ? "badge-primary" : "badge-ghost"
                    }`}>
                        {trajet.statut === "en_cours" ? "En cours" : trajet.statut === "ouvert" ? "Ouvert" : trajet.statut}
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
                        <p className="text-sm font-semibold text-warning">Trajet non démarré</p>
                        <p className="text-xs text-base-content/60 mt-0.5">
                            Le suivi GPS nécessite que le trajet soit en cours. Démarrez le trajet depuis la page détail.
                        </p>
                        <Link
                            href={`/conducteur/trajets/${trajetId}/detail`}
                            className="btn btn-warning btn-xs rounded-full mt-2"
                        >
                            Aller à la page détail
                        </Link>
                    </div>
                </div>
            )}

            {/* ── État connexion ── */}
            <div className="bg-base-100 rounded-2xl border border-base-200 p-4">
                <div className="flex flex-wrap items-center gap-x-6 gap-y-3">
                    <StatusDot ok={peutConnecter} label={peutConnecter ? "Trajet en cours" : "Trajet non démarré"} />
                    <StatusDot ok={isConnected}   label={isConnected ? "WebSocket connecté" : "WebSocket déconnecté"} />
                    <StatusDot ok={gpsActive && !gpsError} label={gpsActive ? "GPS actif" : "GPS inactif"} />
                    <StatusDot ok={lastSent !== null} label={lastSent ? `Envoyé ${lastSent.toLocaleTimeString("fr-FR")}` : "Aucune position envoyée"} />
                    {accuracy !== null && (
                        <span className="text-xs text-base-content/40">Précision : ±{accuracy} m</span>
                    )}
                    {speed !== null && (
                        <span className="text-xs font-bold text-primary">{speed} km/h</span>
                    )}
                </div>
            </div>

            {/* ── Carte ── */}
            <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden" style={{ height: 380 }}>
                {lat != null && lng != null ? (
                    <MapLivePosition lat={lat} lng={lng} passengers={passengers} />
                ) : (
                    <div className="h-full flex flex-col items-center justify-center text-base-content/30 gap-3">
                        <svg xmlns="http://www.w3.org/2000/svg" className="h-12 w-12" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                        </svg>
                        <p className="text-sm">En attente de votre position GPS…</p>
                        <p className="text-xs">Activez le GPS ci-dessous pour démarrer le suivi</p>
                    </div>
                )}
            </div>

            {/* ── Erreur GPS ── */}
            {gpsError && (
                <div className="bg-error/10 border border-error/20 rounded-xl px-4 py-3">
                    <p className="text-sm text-error">{gpsError}</p>
                </div>
            )}

            {/* ── Bouton principal ── */}
            {peutConnecter && (
                <div className="flex gap-3">
                    {!gpsActive ? (
                        <button
                            onClick={activerGPS}
                            className="btn btn-primary rounded-full flex-1 gap-2"
                        >
                            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                            </svg>
                            Activer le GPS et démarrer le suivi
                        </button>
                    ) : (
                        <button
                            onClick={arreterGPS}
                            className="btn btn-error btn-outline rounded-full flex-1 gap-2"
                        >
                            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                            </svg>
                            Arrêter le suivi GPS
                        </button>
                    )}
                </div>
            )}

            {/* ── Info suivi actif ── */}
            {trajetEnCours && isConnected && gpsActive && (
                <div className="bg-success/8 border border-success/20 rounded-2xl p-4 flex items-center gap-3">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-success shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <div>
                        <p className="text-sm font-semibold text-success">Suivi actif — vos passagers voient votre position</p>
                        <p className="text-xs text-base-content/60">
                            {passengers.size > 0
                                ? `${passengers.size} passager${passengers.size > 1 ? "s" : ""} partage${passengers.size === 1 ? "" : "nt"} leur position.`
                                : "En attente de la position des passagers…"}
                        </p>
                    </div>
                </div>
            )}

            {/* ── Liste passagers sur carte ── */}
            {passengers.size > 0 && (
                <div className="bg-base-100 rounded-2xl border border-base-200 p-4">
                    <p className="text-xs font-bold text-base-content/40 uppercase tracking-widest mb-3">
                        Passagers localisés ({passengers.size})
                    </p>
                    <div className="space-y-2">
                        {Array.from(passengers.values()).map(p => (
                            <div key={p.user_id} className="flex items-center gap-3">
                                <div className="w-9 h-9 rounded-full bg-orange-100 border-2 border-orange-400 flex items-center justify-center shrink-0">
                                    <span className="text-orange-600 font-bold text-sm">
                                        {p.nom.charAt(0).toUpperCase()}
                                    </span>
                                </div>
                                <div className="flex-1 min-w-0">
                                    <p className="text-sm font-semibold text-base-content truncate">{p.nom}</p>
                                    <p className="text-xs text-base-content/40">
                                        {p.latitude.toFixed(4)}, {p.longitude.toFixed(4)}
                                    </p>
                                </div>
                                <span className="w-2 h-2 rounded-full bg-orange-400 animate-pulse shrink-0" />
                            </div>
                        ))}
                    </div>
                </div>
            )}

        </div>
    );
}

export default function ConducteurSuiviPage() {
    return (
        <Suspense>
            <ConducteurSuiviContent />
        </Suspense>
    );
}
