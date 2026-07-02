"use client";

import { Suspense, useEffect, useRef, useState, useCallback } from "react";
import { useParams, useSearchParams, useRouter } from "next/navigation";
import Link from "next/link";
import dynamic from "next/dynamic";
import maplibregl from "maplibre-gl";
import { api } from "@/src/services/api";
import trajetApi from "@/libs/trajet-api";
import { useTrajetWebSocket, type PositionPayload } from "@/src/hooks/useTrajetWebSocket";
import { mesReservations } from "@/src/services/reservation.service";
import { useAuth } from "@/src/hooks/useAuth";

// ── Types ─────────────────────────────────────────────────────────────────────

interface TrajetDetail {
    id: number;
    depart: string; depart_lat?: number; depart_lng?: number;
    destination: string; destination_lat?: number; destination_lng?: number;
    date_heure_depart: string;
    distance_km?: number;
    prix_par_place: number;
    places_disponibles: number;
    statut: "ouvert" | "en_cours" | "termine" | "annule";
    description?: string;
    conducteur_nom?: string;
    conducteur_note?: number;
    vehicule_info?: { marque?: string; modele?: string; couleur?: string; immatriculation?: string; type_vehicule?: string };
}

interface Escale {
    id: number; nom: string;
    lat: number; lng: number;
    ordre: number;
    heure_prevue?: string; heure_reelle?: string;
    statut: "en_attente" | "arrive" | "parti";
}

interface MaReservation {
    id: number;
    trajet_id: number;
    point_prise_en_charge?: string;
    prise_en_charge_lat?: number;
    prise_en_charge_lng?: number;
    point_depose?: string;
    depose_lat?: number;
    depose_lng?: number;
    prix_passager?: number;
    conversation_id?: number | null;
    [key: string]: unknown;
}

// ── Carte spécialisée suivi passager ─────────────────────────────────────────

const OSM_STYLE: maplibregl.StyleSpecification = {
    version: 8,
    sources: { osm: { type: "raster", tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"], tileSize: 256, maxzoom: 19 } },
    layers: [{ id: "osm-tiles", type: "raster", source: "osm" }],
};

async function fetchRoute(waypoints: { lat: number; lng: number }[]) {
    if (waypoints.length < 2) return null;
    try {
        const coords = waypoints.map((p) => `${p.lng},${p.lat}`).join(";");
        const res = await fetch(`https://router.project-osrm.org/route/v1/driving/${coords}?overview=full&geometries=geojson`);
        const data = await res.json();
        if (data.code === "Ok" && data.routes?.[0]?.geometry) return data.routes[0].geometry;
    } catch { /* fallback */ }
    return null;
}

function marqueurStatique(couleur: string, taille = 16, texte?: string): HTMLElement {
    const el = document.createElement("div");
    el.style.cssText = `width:${taille}px;height:${taille}px;background:${couleur};border:2.5px solid #fff;border-radius:50%;box-shadow:0 2px 6px rgba(0,0,0,.35);display:flex;align-items:center;justify-content:center;`;
    if (texte) { el.style.fontSize = "8px"; el.style.fontWeight = "700"; el.style.color = "#fff"; el.textContent = texte; }
    return el;
}

function marqueurConducteur(): HTMLElement {
    const el = document.createElement("div");
    el.style.cssText = "position:relative;width:32px;height:32px;";
    el.innerHTML = `
        <style>@keyframes kv-pulse{0%{transform:scale(1);opacity:.7}70%{transform:scale(2.2);opacity:0}100%{transform:scale(1);opacity:0}}</style>
        <div style="position:absolute;inset:0;background:#ef4444;border-radius:50%;animation:kv-pulse 1.8s ease-out infinite"></div>
        <div style="position:absolute;inset:6px;background:#ef4444;border:2.5px solid #fff;border-radius:50%;box-shadow:0 2px 8px rgba(0,0,0,.45)"></div>
        <div style="position:absolute;inset:10px;background:#fff;border-radius:50%"></div>`;
    return el;
}

interface CarteSuiviProps {
    trajet: TrajetDetail;
    escales: Escale[];
    maResa: MaReservation | null;
    positionConducteur: PositionPayload | null;
}

function CarteSuivi({ trajet, escales, maResa, positionConducteur }: CarteSuiviProps) {
    const containerRef = useRef<HTMLDivElement>(null);
    const mapRef       = useRef<maplibregl.Map | null>(null);
    const conductRef   = useRef<maplibregl.Marker | null>(null);
    const staticRef    = useRef<maplibregl.Marker[]>([]);

    // Init carte
    useEffect(() => {
        if (mapRef.current || !containerRef.current) return;
        const lat = trajet.depart_lat ?? 6.1375;
        const lng = trajet.depart_lng ?? 1.2214;
        mapRef.current = new maplibregl.Map({ container: containerRef.current, style: OSM_STYLE, center: [lng, lat], zoom: 10, attributionControl: false });
        mapRef.current.addControl(new maplibregl.NavigationControl({ showCompass: false }), "top-right");
        mapRef.current.addControl(new maplibregl.AttributionControl({ compact: true }), "bottom-right");
        return () => { mapRef.current?.remove(); mapRef.current = null; };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    // Marqueurs statiques + route
    useEffect(() => {
        const map = mapRef.current;
        if (!map) return;
        let cancelled = false;

        const removeRoute = () => {
            ["route", "route-casing"].forEach((id) => { try { if (map.getLayer(id)) map.removeLayer(id); } catch {} });
            try { if (map.getSource("route")) map.removeSource("route"); } catch {}
        };

        const addAll = async () => {
            staticRef.current.forEach((m) => m.remove());
            staticRef.current = [];

            const points: { lat: number; lng: number; nom: string; couleur: string; taille?: number; texte?: string }[] = [];

            if (trajet.depart_lat && trajet.depart_lng)
                points.push({ lat: trajet.depart_lat, lng: trajet.depart_lng, nom: `Départ : ${trajet.depart}`, couleur: "#2563eb", taille: 18 });

            escales.forEach((e) =>
                points.push({ lat: e.lat, lng: e.lng, nom: `Escale : ${e.nom}${e.heure_prevue ? ` (${new Date(e.heure_prevue).toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" })})` : ""}`, couleur: "#d97706", taille: 14 })
            );

            if (trajet.destination_lat && trajet.destination_lng)
                points.push({ lat: trajet.destination_lat, lng: trajet.destination_lng, nom: `Arrivée : ${trajet.destination}`, couleur: "#16a34a", taille: 18 });

            if (maResa?.prise_en_charge_lat && maResa?.prise_en_charge_lng)
                points.push({ lat: maResa.prise_en_charge_lat, lng: maResa.prise_en_charge_lng, nom: `Votre montée : ${maResa.point_prise_en_charge || ""}`, couleur: "#0891b2", taille: 15, texte: "↑" });

            if (maResa?.depose_lat && maResa?.depose_lng)
                points.push({ lat: maResa.depose_lat, lng: maResa.depose_lng, nom: `Votre descente : ${maResa.point_depose || ""}`, couleur: "#dc2626", taille: 15, texte: "↓" });

            points.forEach((p) => {
                const m = new maplibregl.Marker({ element: marqueurStatique(p.couleur, p.taille, p.texte) })
                    .setLngLat([p.lng, p.lat])
                    .setPopup(new maplibregl.Popup({ offset: 14, closeButton: false }).setHTML(`<p style="font-size:13px;font-weight:600;margin:0">${p.nom}</p>`))
                    .addTo(map);
                staticRef.current.push(m);
            });

            if (points.length >= 2) {
                const bounds = new maplibregl.LngLatBounds();
                points.forEach((p) => bounds.extend([p.lng, p.lat]));
                map.fitBounds(bounds, { padding: 60, maxZoom: 14, duration: 700 });
            }

            // Route principale depart → escales → destination
            const routeWps: { lat: number; lng: number }[] = [];
            if (trajet.depart_lat && trajet.depart_lng) routeWps.push({ lat: trajet.depart_lat, lng: trajet.depart_lng });
            escales.forEach((e) => routeWps.push({ lat: e.lat, lng: e.lng }));
            if (trajet.destination_lat && trajet.destination_lng) routeWps.push({ lat: trajet.destination_lat, lng: trajet.destination_lng });

            if (routeWps.length >= 2) {
                const geo = await fetchRoute(routeWps);
                if (cancelled) return;
                const lineGeo = geo ?? { type: "LineString", coordinates: routeWps.map((p) => [p.lng, p.lat]) };
                const addRoute = () => {
                    removeRoute();
                    map.addSource("route", { type: "geojson", data: { type: "Feature", geometry: lineGeo, properties: {} } });
                    map.addLayer({ id: "route-casing", type: "line", source: "route", paint: { "line-color": "#1d4ed8", "line-width": 8, "line-opacity": 0.18 }, layout: { "line-cap": "round", "line-join": "round" } });
                    map.addLayer({ id: "route", type: "line", source: "route", paint: { "line-color": "#2563eb", "line-width": 4, "line-opacity": 0.85, ...(geo ? {} : { "line-dasharray": [3, 3] }) }, layout: { "line-cap": "round", "line-join": "round" } });
                };
                if (map.isStyleLoaded()) addRoute();
                else map.once("load", () => { if (!cancelled) addRoute(); });
            }
        };

        if (map.isStyleLoaded()) addAll();
        else map.once("load", () => { if (!cancelled) addAll(); });

        return () => { cancelled = true; };
    }, [trajet, escales, maResa]);

    // Marqueur conducteur (temps réel)
    useEffect(() => {
        const map = mapRef.current;
        if (!map || !positionConducteur) return;
        const { latitude: lat, longitude: lng, vitesse_kmh } = positionConducteur;

        if (conductRef.current) {
            conductRef.current.setLngLat([lng, lat]);
            conductRef.current.getPopup()?.setHTML(`<div style="font-size:12px;line-height:1.6"><strong>Conducteur</strong>${vitesse_kmh != null ? `<br>Vitesse : ${vitesse_kmh} km/h` : ""}</div>`);
        } else {
            const popup = new maplibregl.Popup({ offset: 18, closeButton: false })
                .setHTML(`<div style="font-size:12px;line-height:1.6"><strong>Conducteur</strong>${vitesse_kmh != null ? `<br>Vitesse : ${vitesse_kmh} km/h` : ""}</div>`);
            conductRef.current = new maplibregl.Marker({ element: marqueurConducteur() })
                .setLngLat([lng, lat]).setPopup(popup).addTo(map);
        }
        // Suivre le conducteur en douceur
        map.easeTo({ center: [lng, lat], duration: 800, zoom: Math.max(map.getZoom(), 13) });
    }, [positionConducteur]);

    return <div ref={containerRef} className="w-full h-full z-0" />;
}

const CarteSuiviDynamic = dynamic(() => Promise.resolve(CarteSuivi), { ssr: false });

// ── Helpers ───────────────────────────────────────────────────────────────────

const STATUT_BADGE: Record<string, string> = {
    ouvert: "badge-warning badge-outline", en_cours: "badge-success badge-outline",
    termine: "badge-info badge-outline", annule: "badge-error badge-outline",
};
const STATUT_LABEL: Record<string, string> = {
    ouvert: "Pas encore démarré", en_cours: "En cours", termine: "Terminé", annule: "Annulé",
};
const ESCALE_BADGE: Record<string, string> = { en_attente: "badge-ghost", arrive: "badge-info", parti: "badge-success" };
const ESCALE_LABEL: Record<string, string> = { en_attente: "En attente", arrive: "Arrivé", parti: "Parti" };

function fmtH(iso?: string) {
    if (!iso) return null;
    return new Date(iso).toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" });
}

// ── Page ─────────────────────────────────────────────────────────────────────

function SuiviPassagerContent() {
    const { id } = useParams();
    const searchParams = useSearchParams();
    const router = useRouter();
    const { user } = useAuth();
    const trajetId = id as string;

    const [trajet,     setTrajet]     = useState<TrajetDetail | null>(null);
    const [escales,    setEscales]    = useState<Escale[]>([]);
    const [maResa,     setMaResa]     = useState<MaReservation | null>(null);
    const [position,   setPosition]   = useState<PositionPayload | null>(null);
    const [vitesse,    setVitesse]    = useState<number | undefined>();
    const [loading,    setLoading]    = useState(true);
    const [error,      setError]      = useState<string | null>(null);
    const [refreshing, setRefreshing] = useState(false);

    // Partage de position du passager
    const watchIdRef      = useRef<number | null>(null);
    const sendIntervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
    const lastPosRef      = useRef<GeolocationPosition | null>(null);
    const autoStartDone   = useRef(false);
    const [gpsActive, setGpsActive] = useState(false);

    // WebSocket temps réel
    const { isConnected: wsOk, sendPassengerPos } = useTrajetWebSocket({
        trajetId: trajet?.statut === "en_cours" ? trajetId : null,
        onPosition: useCallback((pos: PositionPayload) => {
            setPosition(pos);
            setVitesse(pos.vitesse_kmh);
            setError(null);
        }, []),
    });

    const startGps = useCallback(() => {
        if (!navigator.geolocation || gpsActive) return;
        setGpsActive(true);
        watchIdRef.current = navigator.geolocation.watchPosition(
            (pos) => { lastPosRef.current = pos; },
            () => setGpsActive(false),
            { enableHighAccuracy: true, maximumAge: 0, timeout: 10000 },
        );
        const nom = user ? `${user.first_name ?? ""} ${user.last_name ?? ""}`.trim() || (user.username ?? "") : "";
        sendIntervalRef.current = setInterval(() => {
            const pos = lastPosRef.current;
            if (pos && wsOk) {
                sendPassengerPos(nom, pos.coords.latitude, pos.coords.longitude);
            }
        }, 4000);
    }, [gpsActive, wsOk, sendPassengerPos, user]);

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

    const sendOnce = useCallback(() => {
        if (!navigator.geolocation) return;
        const nom = user ? `${user.first_name ?? ""} ${user.last_name ?? ""}`.trim() || (user.username ?? "") : "";
        navigator.geolocation.getCurrentPosition(
            (pos) => {
                sendPassengerPos(nom, pos.coords.latitude, pos.coords.longitude);
            },
            () => {},
            { enableHighAccuracy: true, timeout: 10000 },
        );
    }, [sendPassengerPos, user]);

    // Auto-démarrage GPS selon param URL (?gps=realtime|once)
    useEffect(() => {
        if (autoStartDone.current || !wsOk) return;
        const mode = searchParams?.get("gps");
        if (mode === "realtime") {
            autoStartDone.current = true;
            startGps();
        } else if (mode === "once") {
            autoStartDone.current = true;
            sendOnce();
        }
    }, [wsOk, searchParams, startGps, sendOnce]);

    useEffect(() => () => stopGps(), [stopGps]);

    const loadAll = useCallback(async () => {
        try {
            const [trajetData, escalesData, resasData] = await Promise.all([
                trajetApi.getTrajet(trajetId) as Promise<TrajetDetail>,
                api(`/trajets/${trajetId}/escales/`, "GET").catch(() => [] as Escale[]),
                mesReservations().catch(() => []),
            ]);
            setTrajet(trajetData);
            setEscales(Array.isArray(escalesData) ? escalesData : []);
            const maResaFound = (Array.isArray(resasData) ? resasData : []).find(
                (r: MaReservation) => r.trajet_id === Number(trajetId)
            );
            setMaResa(maResaFound ?? null);

            // Charger la dernière position GPS connue
            if (trajetData.statut === "en_cours") {
                try {
                    const pos = await trajetApi.getPositionActuelle(trajetId);
                    if (pos?.latitude) {
                        setPosition({ latitude: pos.latitude, longitude: pos.longitude, vitesse_kmh: pos.vitesse_kmh });
                    }
                } catch { /* pas encore de position */ }
            }
        } catch {
            setError("Impossible de charger les informations du trajet.");
        } finally {
            setLoading(false);
        }
    }, [trajetId]);

    useEffect(() => { loadAll(); }, [loadAll]);

    // Fallback polling REST si WebSocket déconnecté
    useEffect(() => {
        if (trajet?.statut !== "en_cours" || wsOk) return;
        const t = setInterval(async () => {
            try {
                const pos = await trajetApi.getPositionActuelle(trajetId);
                if (pos?.latitude) setPosition({ latitude: pos.latitude, longitude: pos.longitude, vitesse_kmh: pos.vitesse_kmh });
            } catch { /* ignore */ }
        }, 5000);
        return () => clearInterval(t);
    }, [trajet?.statut, trajetId, wsOk]);

    const refresh = async () => {
        setRefreshing(true);
        await loadAll();
        setRefreshing(false);
    };

    // ── Skeleton ─────────────────────────────────────────────────────────────

    if (loading) return (
        <div className="space-y-4 animate-pulse">
            <div className="h-8 bg-base-300 rounded w-1/3" />
            <div className="h-24 bg-base-300 rounded-2xl" />
            <div className="h-96 bg-base-300 rounded-2xl" />
        </div>
    );

    if (error && !trajet) return (
        <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4 text-center">
            <p className="text-error text-sm">{error}</p>
            <Link href="/passager/reservations" className="btn btn-primary btn-sm rounded-full">
                Mes réservations
            </Link>
        </div>
    );

    const hasMap = !!(trajet?.depart_lat && trajet?.destination_lat);

    return (
        <div className="space-y-5">

            {/* ── En-tête ── */}
            <div className="flex items-center justify-between gap-3 flex-wrap">
                <div className="flex items-center gap-3">
                    <Link href="/passager/reservations" className="btn btn-ghost btn-sm btn-square rounded-xl">
                        <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
                        </svg>
                    </Link>
                    <div>
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">Suivi en temps réel</p>
                        <h1 className="text-xl font-bold text-base-content tracking-tight">
                            {trajet?.depart} <span className="text-base-content/25 mx-1 font-light">→</span> {trajet?.destination}
                        </h1>
                    </div>
                </div>
                <div className="flex items-center gap-2">
                    {trajet?.statut === "en_cours" && (
                        wsOk ? (
                            <span className="badge badge-sm badge-success badge-outline gap-1">
                                <span className="w-1.5 h-1.5 rounded-full bg-success animate-pulse" />
                                Temps réel
                            </span>
                        ) : (
                            <span className="badge badge-sm badge-ghost gap-1">
                                <span className="w-1.5 h-1.5 rounded-full bg-base-content/30" />
                                Reconnexion…
                            </span>
                        )
                    )}
                    <button onClick={refresh} disabled={refreshing} className="btn btn-ghost btn-sm btn-square rounded-xl" title="Actualiser">
                        <svg xmlns="http://www.w3.org/2000/svg" className={`h-4 w-4 ${refreshing ? "animate-spin" : ""}`} fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                        </svg>
                    </button>
                </div>
            </div>

            {/* ── Infos conducteur ── */}
            {trajet && (
                <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                    <div className="grid grid-cols-2 sm:grid-cols-4 divide-x divide-y sm:divide-y-0 divide-base-200">
                        <InfoCell label="Conducteur"
                            value={trajet.conducteur_nom || "—"}
                            sub={trajet.conducteur_note ? `${trajet.conducteur_note}/5 ★` : undefined} />
                        <InfoCell label="Véhicule"
                            value={trajet.vehicule_info ? `${trajet.vehicule_info.marque ?? ""} ${trajet.vehicule_info.modele ?? ""}`.trim() || "Non précisé" : "Non précisé"}
                            sub={trajet.vehicule_info?.couleur} />
                        <InfoCell label="Distance"
                            value={trajet.distance_km ? `${trajet.distance_km} km` : "—"}
                            sub={trajet.prix_par_place ? `${Number(trajet.prix_par_place).toLocaleString("fr-FR")} FCFA/place` : undefined} />
                        <div className="px-4 py-4 flex flex-col justify-between">
                            <p className="text-xs text-base-content/40 uppercase tracking-wide mb-1">Statut</p>
                            <span className={`badge badge-sm rounded-full font-medium w-fit ${STATUT_BADGE[trajet.statut] ?? "badge-ghost"}`}>
                                {STATUT_LABEL[trajet.statut] ?? trajet.statut}
                            </span>
                        </div>
                    </div>
                </div>
            )}

            {/* ── GPS en direct + partage position passager ── */}
            {trajet?.statut === "en_cours" && (
                <div className="space-y-3">
                    {position && (
                        <div className="grid grid-cols-2 gap-3">
                            <GpsCard label="Vitesse" value={vitesse != null ? `${Math.round(vitesse)} km/h` : "—"} icon="🚗" />
                            <GpsCard label="Position conducteur" value="Suivi actif" icon="📡" highlight />
                        </div>
                    )}

                    {/* Carte partage position passager */}
                    <div className={`rounded-2xl border px-4 py-3.5 flex items-center justify-between gap-3 ${
                        gpsActive
                            ? "border-success/30 bg-success/5"
                            : "border-base-200 bg-base-100"
                    }`}>
                        <div className="flex items-center gap-3 min-w-0">
                            <div className={`w-8 h-8 rounded-xl flex items-center justify-center shrink-0 ${gpsActive ? "bg-success/15" : "bg-base-200"}`}>
                                <svg xmlns="http://www.w3.org/2000/svg" className={`h-4 w-4 ${gpsActive ? "text-success" : "text-base-content/50"}`} viewBox="0 0 24 24" fill="currentColor">
                                    <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/>
                                </svg>
                            </div>
                            <div className="min-w-0">
                                <p className={`text-xs font-semibold ${gpsActive ? "text-success" : "text-base-content/70"}`}>
                                    {gpsActive ? "Votre position partagée" : "Partager ma position"}
                                </p>
                                {gpsActive && (
                                    <p className="text-xs text-success/70 flex items-center gap-1 mt-0.5">
                                        <span className="w-1.5 h-1.5 rounded-full bg-success animate-pulse inline-block" />
                                        GPS actif · mise à jour toutes les 4 s
                                    </p>
                                )}
                                {!gpsActive && (
                                    <p className="text-xs text-base-content/40 mt-0.5">Le conducteur verra votre position</p>
                                )}
                            </div>
                        </div>
                        {gpsActive ? (
                            <button onClick={stopGps} className="btn btn-error btn-outline btn-xs rounded-xl shrink-0">
                                Désactiver
                            </button>
                        ) : (
                            <button onClick={startGps} disabled={!wsOk} className="btn btn-primary btn-xs rounded-xl shrink-0">
                                Activer
                            </button>
                        )}
                    </div>
                </div>
            )}

            {error && trajet && (
                <div className="bg-warning/10 border border-warning/20 rounded-xl px-4 py-3">
                    <p className="text-sm text-warning">{error}</p>
                </div>
            )}

            {/* ── Carte + colonne droite ── */}
            {trajet && (
                <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">

                    {/* Carte */}
                    <div className="lg:col-span-2 bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                        <div className="px-5 py-3 border-b border-base-200 flex items-center justify-between">
                            <h2 className="font-semibold text-base-content text-sm">Carte</h2>
                            <div className="flex items-center gap-3 text-xs text-base-content/50 flex-wrap">
                                <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-blue-600 inline-block" />Départ</span>
                                <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-green-600 inline-block" />Arrivée</span>
                                {escales.length > 0 && <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-amber-500 inline-block" />Escale</span>}
                                {maResa?.prise_en_charge_lat && <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-cyan-600 inline-block" />Votre montée</span>}
                                {maResa?.depose_lat && <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-red-600 inline-block" />Votre descente</span>}
                                {position && <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-red-500 animate-pulse inline-block" />Conducteur</span>}
                            </div>
                        </div>
                        <div className="h-96">
                            {hasMap ? (
                                <CarteSuiviDynamic
                                    trajet={trajet}
                                    escales={escales}
                                    maResa={maResa}
                                    positionConducteur={position}
                                />
                            ) : (
                                <div className="h-full flex flex-col items-center justify-center text-base-content/30">
                                    <svg xmlns="http://www.w3.org/2000/svg" className="h-10 w-10 mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6-10l6-3m0 13l5.447 2.724A1 1 0 0021 18.382V7.618a1 1 0 00-1.447-.894L15 10" />
                                    </svg>
                                    <p className="text-sm">Coordonnées GPS non disponibles</p>
                                </div>
                            )}
                        </div>
                    </div>

                    {/* Colonne droite : itinéraire + votre trajet */}
                    <div className="space-y-4">

                        {/* Itinéraire */}
                        <div className="bg-base-100 rounded-2xl border border-base-200 p-5">
                            <h3 className="font-semibold text-base-content text-sm mb-3">Itinéraire</h3>
                            <div className="space-y-0">
                                <EtapeRow
                                    couleur="#2563eb"
                                    nom={trajet.depart}
                                    heure={new Date(trajet.date_heure_depart).toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" })}
                                    statut="depart"
                                    last={escales.length === 0}
                                />
                                {escales.map((e, i) => (
                                    <EtapeRow
                                        key={e.id}
                                        couleur="#d97706"
                                        nom={e.nom}
                                        heure={fmtH(e.heure_reelle ?? e.heure_prevue) ?? undefined}
                                        badge={ESCALE_LABEL[e.statut]}
                                        badgeClass={ESCALE_BADGE[e.statut]}
                                        last={i === escales.length - 1}
                                    />
                                ))}
                                <EtapeRow
                                    couleur="#16a34a"
                                    nom={trajet.destination}
                                    statut="destination"
                                    last={true}
                                />
                            </div>
                        </div>

                        {/* Votre montée / descente */}
                        {maResa && (maResa.prise_en_charge_lat || maResa.depose_lat || maResa.point_prise_en_charge) && (
                            <div className="bg-base-100 rounded-2xl border border-base-200 p-5 space-y-3">
                                <h3 className="font-semibold text-base-content text-sm">Votre trajet</h3>
                                {(maResa.point_prise_en_charge || maResa.prise_en_charge_lat) && (
                                    <div className="flex items-start gap-2 bg-cyan-50 dark:bg-cyan-950/20 rounded-xl px-3 py-2">
                                        <span className="w-5 h-5 rounded-full bg-cyan-600 text-white flex items-center justify-center text-xs font-bold shrink-0">↑</span>
                                        <div>
                                            <p className="text-xs text-base-content/40 font-medium">Montée</p>
                                            <p className="text-sm font-medium text-base-content">{maResa.point_prise_en_charge || trajet.depart}</p>
                                        </div>
                                    </div>
                                )}
                                {(maResa.point_depose || maResa.depose_lat) && (
                                    <div className="flex items-start gap-2 bg-red-50 dark:bg-red-950/20 rounded-xl px-3 py-2">
                                        <span className="w-5 h-5 rounded-full bg-red-600 text-white flex items-center justify-center text-xs font-bold shrink-0">↓</span>
                                        <div>
                                            <p className="text-xs text-base-content/40 font-medium">Descente</p>
                                            <p className="text-sm font-medium text-base-content">{maResa.point_depose || trajet.destination}</p>
                                        </div>
                                    </div>
                                )}
                                {maResa.prix_passager && (
                                    <p className="text-xs text-base-content/50">
                                        Prix : <span className="font-semibold text-primary">{Number(maResa.prix_passager).toLocaleString("fr-FR")} FCFA</span>
                                    </p>
                                )}
                                {maResa.conversation_id && (
                                    <button
                                        onClick={() => router.push(`/communication/messages?conv=${maResa.conversation_id}`)}
                                        className="btn btn-primary btn-xs rounded-full w-full gap-1">
                                        <svg xmlns="http://www.w3.org/2000/svg" className="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                                        </svg>
                                        Message au conducteur
                                    </button>
                                )}
                            </div>
                        )}
                    </div>
                </div>
            )}

            {/* ── Messages contextuels ── */}
            {trajet?.statut === "ouvert" && (
                <div className="bg-info/5 border border-info/20 rounded-2xl p-5">
                    <p className="font-medium text-base-content text-sm">Le trajet n&apos;a pas encore commencé</p>
                    <p className="text-sm text-base-content/60 mt-1">La position GPS du conducteur s&apos;affichera automatiquement au démarrage.</p>
                </div>
            )}
            {trajet?.statut === "termine" && (
                <div className="bg-success/5 border border-success/20 rounded-2xl p-5 flex items-center justify-between gap-4 flex-wrap">
                    <div>
                        <p className="font-medium text-base-content text-sm">Trajet terminé</p>
                        <p className="text-sm text-base-content/60 mt-0.5">N&apos;oubliez pas d&apos;évaluer votre conducteur.</p>
                    </div>
                    <div className="flex gap-2">
                        <Link href="/passager/evaluations" className="btn btn-primary btn-sm rounded-full">
                            Évaluer le conducteur
                        </Link>
                        <Link href="/passager/reservations" className="btn btn-ghost btn-sm rounded-full">
                            Mes réservations
                        </Link>
                    </div>
                </div>
            )}

        </div>
    );
}

export default function SuiviPassagerPage() {
    return (
        <Suspense fallback={
            <div className="space-y-4 animate-pulse">
                <div className="h-8 bg-base-300 rounded w-1/3" />
                <div className="h-24 bg-base-300 rounded-2xl" />
                <div className="h-96 bg-base-300 rounded-2xl" />
            </div>
        }>
            <SuiviPassagerContent />
        </Suspense>
    );
}

// ── Sous-composants ───────────────────────────────────────────────────────────

function InfoCell({ label, value, sub }: { label: string; value: string; sub?: string }) {
    return (
        <div className="px-4 py-4">
            <p className="text-xs text-base-content/40 uppercase tracking-wide mb-1">{label}</p>
            <p className="text-sm font-semibold text-base-content leading-tight">{value}</p>
            {sub && <p className="text-xs text-base-content/50 mt-0.5">{sub}</p>}
        </div>
    );
}

function GpsCard({ label, value, icon, highlight }: { label: string; value: string; icon: string; highlight?: boolean }) {
    return (
        <div className={`rounded-2xl border p-4 ${highlight ? "border-success/30 bg-success/5" : "border-base-200 bg-base-100"}`}>
            <p className="text-lg mb-1">{icon}</p>
            <p className="text-xs text-base-content/40 uppercase tracking-wide font-medium">{label}</p>
            <p className={`text-base font-bold mt-0.5 ${highlight ? "text-success" : "text-base-content"}`}>{value}</p>
        </div>
    );
}

function EtapeRow({ couleur, nom, heure, badge, badgeClass, statut, last }: {
    couleur: string; nom: string; heure?: string;
    badge?: string; badgeClass?: string;
    statut?: string; last?: boolean;
}) {
    return (
        <div className="flex gap-3">
            {/* Ligne verticale */}
            <div className="flex flex-col items-center">
                <div className="w-3 h-3 rounded-full border-2 border-white shrink-0 mt-1" style={{ background: couleur, boxShadow: "0 1px 4px rgba(0,0,0,.25)" }} />
                {!last && <div className="w-px flex-1 my-1" style={{ background: couleur, opacity: 0.3 }} />}
            </div>
            {/* Contenu */}
            <div className={`pb-3 min-w-0 flex-1 ${last ? "" : ""}`}>
                <div className="flex items-center justify-between gap-2">
                    <p className="text-sm font-medium text-base-content truncate">{nom}</p>
                    {badge && (
                        <span className={`badge badge-xs rounded-full shrink-0 ${badgeClass}`}>{badge}</span>
                    )}
                </div>
                {heure && <p className="text-xs text-base-content/40">{heure}</p>}
                {statut === "depart" && <p className="text-xs text-base-content/40">Point de départ</p>}
                {statut === "destination" && <p className="text-xs text-base-content/40">Destination finale</p>}
            </div>
        </div>
    );
}
