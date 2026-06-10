"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import maplibregl from "maplibre-gl";
import { api } from "@/src/services/api";
import { confirmerEspeces, getStatutPaiementReservation, type PaiementReservationResponse } from "@/src/services/paiement.service";
import trajetApi from "@/libs/trajet-api";

// ── Types ─────────────────────────────────────────────────────────────────────

interface Trajet {
    id: number;
    depart: string; depart_lat?: number; depart_lng?: number;
    destination: string; destination_lat?: number; destination_lng?: number;
    date_heure_depart: string;
    distance_km?: number;
    prix_par_place: number;
    places_disponibles: number;
    statut: "ouvert" | "en_cours" | "termine" | "annule";
    description?: string;
    polyline?: string;
    vehicule?: { type_vehicule?: string; marque?: string; modele?: string; immatriculation?: string };
}

interface Escale {
    id: number; nom: string;
    lat: number; lng: number;
    ordre: number;
    heure_prevue?: string; heure_reelle?: string;
    statut: "en_attente" | "arrive" | "parti";
}

interface Reservation {
    id: number;
    passager: string;
    passager_id?: string;
    passager_nom: string;
    passager_telephone?: string;
    passager_note?: number;
    trajet_id: number;
    statut: "confirmee" | "en_attente" | "declinee" | "terminee";
    statut_embarquement: "en_attente" | "embarque" | "depose";
    point_prise_en_charge?: string; prise_en_charge_lat?: number; prise_en_charge_lng?: number;
    point_depose?: string; depose_lat?: number; depose_lng?: number;
    prix_passager?: number;
    distance_passager?: number;
    conversation_id?: number | null;
    code_embarquement?: string;
}

// ── Carte spécialisée ─────────────────────────────────────────────────────────

type PointType = "depart" | "destination" | "escale" | "pickup" | "dropoff";
interface MapPoint { nom: string; lat: number; lng: number; type: PointType; label?: string }

const COULEURS: Record<PointType, string> = {
    depart:      "#2563eb",
    destination: "#16a34a",
    escale:      "#d97706",
    pickup:      "#0891b2",
    dropoff:     "#dc2626",
};
const TAILLES: Record<PointType, number> = {
    depart: 20, destination: 20, escale: 14, pickup: 14, dropoff: 14,
};

async function fetchOsrmRoute(waypoints: { lat: number; lng: number }[]) {
    if (waypoints.length < 2) return null;
    try {
        const coords = waypoints.map((p) => `${p.lng},${p.lat}`).join(";");
        const res = await fetch(
            `https://router.project-osrm.org/route/v1/driving/${coords}?overview=full&geometries=geojson`
        );
        const data = await res.json();
        if (data.code === "Ok" && data.routes?.[0]?.geometry) return data.routes[0].geometry;
    } catch { /* fallback */ }
    return null;
}

function MapTrajetConducteur({ points, routeWaypoints }: {
    points: MapPoint[];
    routeWaypoints: { lat: number; lng: number }[];
}) {
    const containerRef = useRef<HTMLDivElement>(null);
    const mapRef = useRef<maplibregl.Map | null>(null);
    const markersRef = useRef<maplibregl.Marker[]>([]);

    useEffect(() => {
        if (mapRef.current || !containerRef.current) return;
        mapRef.current = new maplibregl.Map({
            container: containerRef.current,
            style: {
                version: 8,
                sources: { osm: { type: "raster", tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"], tileSize: 256, maxzoom: 19 } },
                layers: [{ id: "osm-tiles", type: "raster", source: "osm" }],
            } as maplibregl.StyleSpecification,
            center: [1.2214, 6.1375],
            zoom: 9,
            attributionControl: false,
        });
        mapRef.current.addControl(new maplibregl.NavigationControl({ showCompass: false }), "top-right");
        mapRef.current.addControl(new maplibregl.AttributionControl({ compact: true }), "bottom-right");
        return () => { mapRef.current?.remove(); mapRef.current = null; };
    }, []);

    useEffect(() => {
        const map = mapRef.current;
        if (!map || points.length === 0) return;
        let cancelled = false;

        markersRef.current.forEach((m) => m.remove());
        markersRef.current = [];

        const removeRoute = () => {
            ["route", "route-casing"].forEach((id) => { try { if (map.getLayer(id)) map.removeLayer(id); } catch {} });
            try { if (map.getSource("route")) map.removeSource("route"); } catch {}
        };

        points.forEach((p) => {
            const el = document.createElement("div");
            const c = COULEURS[p.type];
            const t = TAILLES[p.type];
            el.style.cssText = `width:${t}px;height:${t}px;background:${c};border:2.5px solid #fff;border-radius:50%;box-shadow:0 2px 6px rgba(0,0,0,.35);cursor:pointer;display:flex;align-items:center;justify-content:center;`;
            if (p.label) {
                el.style.fontSize = "8px";
                el.style.fontWeight = "700";
                el.style.color = "#fff";
                el.innerHTML = p.label;
            }
            const marker = new maplibregl.Marker({ element: el })
                .setLngLat([p.lng, p.lat])
                .setPopup(new maplibregl.Popup({ offset: 16, closeButton: false })
                    .setHTML(`<p style="font-size:13px;font-weight:600;margin:0">${p.nom}</p>`))
                .addTo(map);
            markersRef.current.push(marker);
        });

        const bounds = new maplibregl.LngLatBounds();
        points.forEach((p) => bounds.extend([p.lng, p.lat]));
        map.fitBounds(bounds, { padding: 60, maxZoom: 13, duration: 700 });

        if (routeWaypoints.length >= 2) {
            const drawRoute = async () => {
                const geometry = await fetchOsrmRoute(routeWaypoints);
                if (cancelled) return;
                const lineGeo = geometry ?? {
                    type: "LineString",
                    coordinates: routeWaypoints.map((p) => [p.lng, p.lat]),
                };
                const addLayers = () => {
                    removeRoute();
                    map.addSource("route", { type: "geojson", data: { type: "Feature", geometry: lineGeo, properties: {} } });
                    map.addLayer({ id: "route-casing", type: "line", source: "route", paint: { "line-color": "#1d4ed8", "line-width": 8, "line-opacity": 0.18 }, layout: { "line-cap": "round", "line-join": "round" } });
                    map.addLayer({ id: "route", type: "line", source: "route", paint: { "line-color": "#2563eb", "line-width": 4, "line-opacity": 0.85, ...(geometry ? {} : { "line-dasharray": [3, 3] }) }, layout: { "line-cap": "round", "line-join": "round" } });
                };
                if (map.isStyleLoaded()) addLayers();
                else map.once("load", () => { if (!cancelled) addLayers(); });
            };
            if (map.isStyleLoaded()) { removeRoute(); drawRoute(); }
            else map.once("load", () => { if (!cancelled) { removeRoute(); drawRoute(); } });
        }

        return () => { cancelled = true; };
    }, [points, routeWaypoints]);

    return <div ref={containerRef} style={{ width: "100%", height: "100%" }} className="z-0" />;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const STATUT_LABELS: Record<string, string> = {
    ouvert: "Ouvert", en_cours: "En cours", termine: "Terminé", annule: "Annulé",
};
const STATUT_BADGE: Record<string, string> = {
    ouvert: "badge-primary", en_cours: "badge-info", termine: "badge-success", annule: "badge-ghost",
};
const EMBARQUEMENT_BADGE: Record<string, string> = {
    en_attente: "badge-warning", embarque: "badge-info", depose: "badge-success",
};
const EMBARQUEMENT_LABEL: Record<string, string> = {
    en_attente: "En attente", embarque: "Embarqué", depose: "Déposé",
};

function fmt(iso: string) {
    return new Date(iso).toLocaleDateString("fr-FR", { weekday: "short", day: "numeric", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" });
}
function fmtHeure(iso?: string) {
    if (!iso) return null;
    return new Date(iso).toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" });
}
function initiales(nom: string) {
    return nom.split(" ").map((n) => n[0]).join("").slice(0, 2).toUpperCase();
}

// ── Page ─────────────────────────────────────────────────────────────────────

export default function DetailTrajetPage() {
    const { id } = useParams();
    const router = useRouter();

    const [trajet, setTrajet] = useState<Trajet | null>(null);
    const [escales, setEscales] = useState<Escale[]>([]);
    const [reservations, setReservations] = useState<Reservation[]>([]);
    const [paiements, setPaiements] = useState<Record<number, PaiementReservationResponse>>({});
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [actionLoading, setActionLoading] = useState<string | null>(null);
    const [confirming, setConfirming] = useState<number | null>(null);

    const loadAll = useCallback(async () => {
        setLoading(true);
        setError(null);
        try {
            const [trajetData, escalesData, resasData] = await Promise.all([
                trajetApi.getTrajet(String(id)) as Promise<Trajet>,
                api(`/trajets/${id}/escales/`, "GET").catch(() => []),
                api(`/reservations/recues/`, "GET").catch(() => []),
            ]);

            setTrajet(trajetData);

            const escalesList = Array.isArray(escalesData) ? escalesData : [];
            setEscales(escalesList);

            const filtered = (Array.isArray(resasData) ? resasData : [])
                .filter((r: Reservation) => r.trajet_id === Number(id) && ["confirmee", "terminee"].includes(r.statut));
            setReservations(filtered);

            // Charger les statuts de paiement en parallèle
            const paiementsResult: Record<number, PaiementReservationResponse> = {};
            await Promise.all(
                filtered.map(async (r: Reservation) => {
                    try {
                        paiementsResult[r.id] = await getStatutPaiementReservation(r.id);
                    } catch { /* pas de paiement */ }
                })
            );
            setPaiements(paiementsResult);
        } catch {
            setError("Impossible de charger les données du trajet.");
        } finally {
            setLoading(false);
        }
    }, [id]);

    useEffect(() => { loadAll(); }, [loadAll]);

    const handleAction = async (action: "commencer" | "terminer") => {
        if (!confirm(action === "commencer" ? "Démarrer le trajet ?" : "Terminer le trajet ? Cette action est irréversible.")) return;
        setActionLoading(action);
        try {
            if (action === "commencer") await trajetApi.commencerTrajet(String(id));
            else await trajetApi.terminerTrajet(String(id));
            await loadAll();
        } catch {
            setError("Erreur lors de l'action. Réessayez.");
        } finally {
            setActionLoading(null);
        }
    };

    const handleConfirmerPaiement = async (reservationId: number) => {
        setConfirming(reservationId);
        try {
            await confirmerEspeces(reservationId);
            setPaiements((prev) => ({
                ...prev,
                [reservationId]: { ...prev[reservationId], statut: "CONFIRME", date_confirmation: new Date().toISOString() },
            }));
        } catch {
            setError("Erreur lors de la confirmation du paiement.");
        } finally {
            setConfirming(null);
        }
    };

    // ── Points carte ──────────────────────────────────────────────────────────

    const mapPoints: MapPoint[] = [];
    const routeWaypoints: { lat: number; lng: number }[] = [];

    if (trajet?.depart_lat && trajet?.depart_lng) {
        mapPoints.push({ nom: trajet.depart, lat: trajet.depart_lat, lng: trajet.depart_lng, type: "depart" });
        routeWaypoints.push({ lat: trajet.depart_lat, lng: trajet.depart_lng });
    }
    escales.forEach((e) => {
        mapPoints.push({ nom: e.nom, lat: e.lat, lng: e.lng, type: "escale" });
        routeWaypoints.push({ lat: e.lat, lng: e.lng });
    });
    if (trajet?.destination_lat && trajet?.destination_lng) {
        routeWaypoints.push({ lat: trajet.destination_lat, lng: trajet.destination_lng });
        mapPoints.push({ nom: trajet.destination, lat: trajet.destination_lat, lng: trajet.destination_lng, type: "destination" });
    }
    reservations.forEach((r) => {
        if (r.prise_en_charge_lat && r.prise_en_charge_lng) {
            mapPoints.push({
                nom: `↑ ${r.passager_nom}${r.point_prise_en_charge ? ` — ${r.point_prise_en_charge}` : ""}`,
                lat: r.prise_en_charge_lat, lng: r.prise_en_charge_lng,
                type: "pickup", label: "↑",
            });
        }
        if (r.depose_lat && r.depose_lng) {
            mapPoints.push({
                nom: `↓ ${r.passager_nom}${r.point_depose ? ` — ${r.point_depose}` : ""}`,
                lat: r.depose_lat, lng: r.depose_lng,
                type: "dropoff", label: "↓",
            });
        }
    });

    const hasMap = mapPoints.length >= 2;

    // ── UI ────────────────────────────────────────────────────────────────────

    if (loading) return (
        <div className="flex items-center justify-center min-h-[60vh]">
            <span className="loading loading-spinner loading-lg text-primary" />
        </div>
    );

    if (error && !trajet) return (
        <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4">
            <p className="text-error text-sm">{error}</p>
            <Link href="/conducteur/trajets" className="btn btn-primary btn-sm rounded-full">
                Retour à mes trajets
            </Link>
        </div>
    );

    return (
        <div className="space-y-6">

            {/* ── En-tête ── */}
            <div className="flex flex-wrap items-center justify-between gap-4 pb-5 border-b border-base-300">
                <div className="flex items-center gap-3">
                    <Link href="/conducteur/trajets" className="btn btn-ghost btn-sm btn-square rounded-xl">
                        <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
                        </svg>
                    </Link>
                    <div>
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">Trajet #{id}</p>
                        <h1 className="text-xl font-bold text-base-content">
                            {trajet?.depart} → {trajet?.destination}
                        </h1>
                    </div>
                </div>
                <div className="flex items-center gap-3">
                    {trajet && (
                        <span className={`badge badge-sm rounded-full font-medium ${STATUT_BADGE[trajet.statut] ?? "badge-ghost"}`}>
                            {STATUT_LABELS[trajet.statut] ?? trajet.statut}
                        </span>
                    )}
                    {trajet?.statut === "ouvert" && (
                        <button onClick={() => handleAction("commencer")} disabled={!!actionLoading}
                            className="btn btn-info btn-sm rounded-full">
                            {actionLoading === "commencer" ? <span className="loading loading-spinner loading-xs" /> : "Démarrer le trajet"}
                        </button>
                    )}
                    {trajet?.statut === "en_cours" && (
                        <button onClick={() => handleAction("terminer")} disabled={!!actionLoading}
                            className="btn btn-warning btn-sm rounded-full">
                            {actionLoading === "terminer" ? <span className="loading loading-spinner loading-xs" /> : "Terminer le trajet"}
                        </button>
                    )}
                    {trajet?.statut === "termine" && (
                        <Link href="/conducteur/evaluations" className="btn btn-success btn-sm rounded-full">
                            Évaluer les passagers
                        </Link>
                    )}
                </div>
            </div>

            {error && (
                <div className="bg-error/10 border border-error/20 rounded-xl px-4 py-3">
                    <p className="text-sm text-error">{error}</p>
                </div>
            )}

            {/* ── Carte + infos ── */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-5">

                {/* Carte */}
                <div className="lg:col-span-2 bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                    <div className="px-5 py-3 border-b border-base-200 flex items-center justify-between">
                        <h2 className="font-semibold text-base-content text-sm">Itinéraire</h2>
                        <div className="flex items-center gap-3 text-xs text-base-content/50">
                            <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded-full bg-blue-600 inline-block" />Départ</span>
                            <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded-full bg-green-600 inline-block" />Arrivée</span>
                            {escales.length > 0 && <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded-full bg-amber-500 inline-block" />Escale</span>}
                            {mapPoints.some((p) => p.type === "pickup") && <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded-full bg-cyan-600 inline-block" />Montée</span>}
                            {mapPoints.some((p) => p.type === "dropoff") && <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded-full bg-red-600 inline-block" />Descente</span>}
                        </div>
                    </div>
                    <div className="h-96">
                        {hasMap ? (
                            <MapTrajetConducteur points={mapPoints} routeWaypoints={routeWaypoints} />
                        ) : (
                            <div className="h-full flex flex-col items-center justify-center text-base-content/30">
                                <svg xmlns="http://www.w3.org/2000/svg" className="h-10 w-10 mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6-10l6-3m0 13l5.447 2.724A1 1 0 0021 18.382V7.618a1 1 0 00-1.447-.894L15 10" />
                                </svg>
                                <p className="text-sm">Coordonnées GPS non disponibles</p>
                                <p className="text-xs mt-1">{trajet?.depart} → {trajet?.destination}</p>
                            </div>
                        )}
                    </div>
                </div>

                {/* Infos trajet */}
                <div className="space-y-4">
                    <div className="bg-base-100 rounded-2xl border border-base-200 p-5 space-y-3">
                        <h3 className="font-semibold text-base-content text-sm mb-2">Infos trajet</h3>
                        <InfoRow label="Départ" value={trajet?.depart ?? "—"} />
                        {escales.map((e) => (
                            <InfoRow key={e.id} label={`Escale ${e.ordre}`} value={e.nom}
                                sub={fmtHeure(e.heure_prevue) ?? undefined}
                                badge={e.statut === "parti" ? "Parti" : e.statut === "arrive" ? "Arrivé" : undefined} />
                        ))}
                        <InfoRow label="Arrivée" value={trajet?.destination ?? "—"} />
                        <div className="border-t border-base-200 pt-3 space-y-2">
                            <InfoRow label="Date" value={trajet ? fmt(trajet.date_heure_depart) : "—"} />
                            {trajet?.distance_km && <InfoRow label="Distance" value={`${trajet.distance_km} km`} />}
                            <InfoRow label="Prix / place" value={trajet ? `${Number(trajet.prix_par_place).toLocaleString("fr-FR")} FCFA` : "—"} />
                            <InfoRow label="Passagers" value={`${reservations.length} / ${trajet?.places_disponibles ?? "?"}`} />
                            {trajet?.vehicule?.type_vehicule && (
                                <InfoRow label="Véhicule" value={`${trajet.vehicule.marque ?? ""} ${trajet.vehicule.modele ?? ""} (${trajet.vehicule.immatriculation ?? ""})`} />
                            )}
                        </div>
                    </div>

                    {trajet?.description && (
                        <div className="bg-base-100 rounded-2xl border border-base-200 p-5">
                            <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">Description</p>
                            <p className="text-sm text-base-content/80">{trajet.description}</p>
                        </div>
                    )}
                </div>
            </div>

            {/* ── Escales ── */}
            {escales.length > 0 && (
                <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                    <div className="px-5 py-3 border-b border-base-200">
                        <h2 className="font-semibold text-base-content text-sm">Escales ({escales.length})</h2>
                    </div>
                    <div className="divide-y divide-base-200">
                        {escales.map((e, i) => (
                            <div key={e.id} className="flex items-center justify-between px-5 py-3 gap-4">
                                <div className="flex items-center gap-3">
                                    <div className="w-7 h-7 rounded-full bg-amber-100 text-amber-700 flex items-center justify-center text-xs font-bold shrink-0">
                                        {i + 1}
                                    </div>
                                    <div>
                                        <p className="text-sm font-medium text-base-content">{e.nom}</p>
                                        {e.heure_prevue && (
                                            <p className="text-xs text-base-content/40">
                                                Prévu {fmtHeure(e.heure_prevue)}
                                                {e.heure_reelle && ` · Réel ${fmtHeure(e.heure_reelle)}`}
                                            </p>
                                        )}
                                    </div>
                                </div>
                                <span className={`badge badge-sm rounded-full shrink-0 ${
                                    e.statut === "parti" ? "badge-success" : e.statut === "arrive" ? "badge-info" : "badge-ghost"
                                }`}>
                                    {e.statut === "parti" ? "Parti" : e.statut === "arrive" ? "Arrivé" : "En attente"}
                                </span>
                            </div>
                        ))}
                    </div>
                </div>
            )}

            {/* ── Passagers ── */}
            <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                <div className="px-5 py-3 border-b border-base-200">
                    <h2 className="font-semibold text-base-content text-sm">
                        Passagers ({reservations.length})
                    </h2>
                </div>

                {reservations.length === 0 ? (
                    <div className="py-12 text-center">
                        <p className="text-base-content/40 text-sm">Aucun passager pour ce trajet.</p>
                    </div>
                ) : (
                    <div className="divide-y divide-base-200">
                        {reservations.map((r) => {
                            const paiement = paiements[r.id];
                            const monteePoint = r.point_prise_en_charge || r.passager_nom;
                            const descente = r.point_depose;
                            return (
                                <div key={r.id} className="p-5 space-y-3">
                                    <div className="flex items-start justify-between gap-3 flex-wrap">
                                        {/* Avatar + nom + note */}
                                        <div className="flex items-center gap-3">
                                            <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                                                <span className="text-sm font-bold text-primary">
                                                    {initiales(r.passager_nom || "?")}
                                                </span>
                                            </div>
                                            <div>
                                                <p className="font-semibold text-base-content text-sm">{r.passager_nom}</p>
                                                <div className="flex items-center gap-2 mt-0.5">
                                                    {r.passager_note != null && (
                                                        <span className="text-xs text-base-content/50">
                                                            {"★".repeat(Math.round(r.passager_note))} {Number(r.passager_note).toFixed(1)}
                                                        </span>
                                                    )}
                                                    <span className={`badge badge-xs rounded-full ${EMBARQUEMENT_BADGE[r.statut_embarquement] ?? "badge-ghost"}`}>
                                                        {EMBARQUEMENT_LABEL[r.statut_embarquement] ?? r.statut_embarquement}
                                                    </span>
                                                </div>
                                            </div>
                                        </div>

                                        {/* Boutons */}
                                        <div className="flex items-center gap-2 shrink-0">
                                            {r.passager_telephone && (
                                                <a href={`tel:${r.passager_telephone}`}
                                                    className="btn btn-ghost btn-xs rounded-full gap-1 border border-base-300"
                                                    title="Appeler">
                                                    <svg xmlns="http://www.w3.org/2000/svg" className="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
                                                    </svg>
                                                    <span className="hidden sm:inline">Appeler</span>
                                                </a>
                                            )}
                                            {r.conversation_id && (
                                                <button
                                                    onClick={() => router.push(`/communication/messages?conv=${r.conversation_id}`)}
                                                    className="btn btn-primary btn-xs rounded-full gap-1">
                                                    <svg xmlns="http://www.w3.org/2000/svg" className="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                                                    </svg>
                                                    <span className="hidden sm:inline">Message</span>
                                                </button>
                                            )}
                                        </div>
                                    </div>

                                    {/* Points montée / descente */}
                                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                                        <div className="flex items-start gap-2 bg-cyan-50 dark:bg-cyan-950/20 rounded-xl px-3 py-2">
                                            <span className="w-5 h-5 rounded-full bg-cyan-600 text-white flex items-center justify-center text-xs font-bold shrink-0 mt-0.5">↑</span>
                                            <div className="min-w-0">
                                                <p className="text-xs text-base-content/40 uppercase tracking-wide font-medium">Montée</p>
                                                <p className="text-sm text-base-content font-medium truncate">{monteePoint}</p>
                                                {r.prise_en_charge_lat && (
                                                    <p className="text-xs text-base-content/40">
                                                        {r.prise_en_charge_lat.toFixed(4)}, {r.prise_en_charge_lng?.toFixed(4)}
                                                    </p>
                                                )}
                                            </div>
                                        </div>
                                        <div className="flex items-start gap-2 bg-red-50 dark:bg-red-950/20 rounded-xl px-3 py-2">
                                            <span className="w-5 h-5 rounded-full bg-red-600 text-white flex items-center justify-center text-xs font-bold shrink-0 mt-0.5">↓</span>
                                            <div className="min-w-0">
                                                <p className="text-xs text-base-content/40 uppercase tracking-wide font-medium">Descente</p>
                                                <p className="text-sm text-base-content font-medium truncate">{descente || trajet?.destination || "Destination finale"}</p>
                                                {r.depose_lat && (
                                                    <p className="text-xs text-base-content/40">
                                                        {r.depose_lat.toFixed(4)}, {r.depose_lng?.toFixed(4)}
                                                    </p>
                                                )}
                                            </div>
                                        </div>
                                    </div>

                                    {/* Prix passager + paiement */}
                                    <div className="flex items-center justify-between gap-3 flex-wrap">
                                        <div className="flex items-center gap-3">
                                            {r.prix_passager && (
                                                <span className="text-sm font-bold text-primary">
                                                    {Number(r.prix_passager).toLocaleString("fr-FR")} FCFA
                                                </span>
                                            )}
                                            {r.distance_passager && (
                                                <span className="text-xs text-base-content/40">{r.distance_passager} km</span>
                                            )}
                                            {r.code_embarquement && (
                                                <span className="text-xs font-mono bg-base-200 px-2 py-0.5 rounded-lg text-base-content/60">
                                                    #{r.code_embarquement}
                                                </span>
                                            )}
                                        </div>
                                        {paiement && (
                                            paiement.statut === "EN_ATTENTE_CONFIRMATION" ? (
                                                <button
                                                    onClick={() => handleConfirmerPaiement(r.id)}
                                                    disabled={confirming === r.id}
                                                    className="btn btn-warning btn-xs rounded-full">
                                                    {confirming === r.id
                                                        ? <span className="loading loading-spinner loading-xs" />
                                                        : "Confirmer paiement espèces"
                                                    }
                                                </button>
                                            ) : paiement.statut === "CONFIRME" ? (
                                                <span className="text-xs text-success font-medium flex items-center gap-1">
                                                    <svg xmlns="http://www.w3.org/2000/svg" className="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                                                    </svg>
                                                    Payé
                                                </span>
                                            ) : null
                                        )}
                                    </div>
                                </div>
                            );
                        })}
                    </div>
                )}
            </div>

            {/* ── Suivi GPS ── */}
            {(trajet?.statut === "ouvert" || trajet?.statut === "en_cours") && (
                <div className="bg-base-100 rounded-2xl border border-base-200 p-5 flex items-center justify-between gap-4 flex-wrap">
                    <div>
                        <p className="font-semibold text-base-content text-sm">Suivi en temps réel</p>
                        <p className="text-xs text-base-content/40 mt-0.5">
                            Partagez votre position GPS avec les passagers pendant le trajet
                        </p>
                    </div>
                    <Link
                        href={`/conducteur/suivi?trajet=${id}`}
                        className="btn btn-primary btn-sm rounded-full"
                    >
                        Activer le suivi GPS
                    </Link>
                </div>
            )}

        </div>
    );
}

// ── Composant utilitaire ──────────────────────────────────────────────────────

function InfoRow({ label, value, sub, badge }: { label: string; value: string; sub?: string; badge?: string }) {
    return (
        <div className="flex items-start justify-between gap-3">
            <span className="text-xs text-base-content/40 uppercase tracking-wide font-medium shrink-0">{label}</span>
            <div className="text-right">
                <span className="text-sm text-base-content font-medium">{value}</span>
                {sub && <p className="text-xs text-base-content/40">{sub}</p>}
                {badge && <span className="badge badge-xs badge-success rounded-full ml-1">{badge}</span>}
            </div>
        </div>
    );
}
