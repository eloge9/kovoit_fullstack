"use client";

import { useEffect, useRef } from "react";
import maplibregl from "maplibre-gl";
import { PositionGPS, SuiviInfo } from "@/types/trajet";

interface CarteTrajetProps {
    positionActuelle?: PositionGPS;
    departLat?: number;
    departLng?: number;
    destinationLat?: number;
    destinationLng?: number;
    suiviInfo?: SuiviInfo;
    className?: string;
}

// Tuiles raster OpenStreetMap — aucune clé API requise
const OSM_STYLE: maplibregl.StyleSpecification = {
    version: 8,
    sources: {
        osm: {
            type: "raster",
            tiles: ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
            tileSize: 256,
            attribution: "© <a href='https://openstreetmap.org' target='_blank'>OpenStreetMap</a>",
            maxzoom: 19,
        },
    },
    layers: [{ id: "osm-tiles", type: "raster", source: "osm" }],
};

// Crée un élément DOM pour un marqueur statique (départ / destination)
function creerMarqueurStatique(couleur: string, taille = 16): HTMLElement {
    const el = document.createElement("div");
    el.style.cssText = `
        width:${taille}px; height:${taille}px;
        background:${couleur}; border:3px solid #fff;
        border-radius:50%; box-shadow:0 2px 8px rgba(0,0,0,.4);
    `;
    return el;
}

// Crée le marqueur animé pour le conducteur (point rouge pulsant)
function creerMarqueurConducteur(): HTMLElement {
    const el = document.createElement("div");
    el.style.cssText = "position:relative; width:28px; height:28px;";
    el.innerHTML = `
        <div style="
            position:absolute; inset:0;
            background:#ef4444; border-radius:50%;
            animation:kovoit-pulse 1.8s ease-out infinite;
        "></div>
        <div style="
            position:absolute; inset:5px;
            background:#ef4444; border:2.5px solid #fff;
            border-radius:50%; box-shadow:0 2px 8px rgba(0,0,0,.45);
        "></div>
    `;
    return el;
}

export default function CarteTrajet({
    positionActuelle,
    departLat,
    departLng,
    destinationLat,
    destinationLng,
    suiviInfo,
    className = "h-96 w-full",
}: CarteTrajetProps) {
    const containerRef        = useRef<HTMLDivElement>(null);
    const mapRef              = useRef<maplibregl.Map | null>(null);
    const conducteurRef       = useRef<maplibregl.Marker | null>(null);
    const staticMarkersRef    = useRef<maplibregl.Marker[]>([]);

    // ── Initialiser la carte ───────────────────────────────────────────────
    useEffect(() => {
        if (mapRef.current || !containerRef.current) return;

        const lat = positionActuelle?.latitude ?? departLat ?? 6.1375;
        const lng = positionActuelle?.longitude ?? departLng ?? 1.2214;

        mapRef.current = new maplibregl.Map({
            container: containerRef.current,
            style: OSM_STYLE,
            center: [lng, lat],
            zoom: 13,
            attributionControl: false,
        });

        mapRef.current.addControl(
            new maplibregl.AttributionControl({ compact: true }),
            "bottom-right"
        );
        mapRef.current.addControl(
            new maplibregl.NavigationControl({ showCompass: false }),
            "top-right"
        );

        return () => {
            conducteurRef.current?.remove();
            conducteurRef.current = null;
            staticMarkersRef.current.forEach((m) => m.remove());
            staticMarkersRef.current = [];
            mapRef.current?.remove();
            mapRef.current = null;
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    // ── Marqueurs statiques (départ / destination) — créés une seule fois ──
    useEffect(() => {
        const map = mapRef.current;
        if (!map) return;

        const addStatic = () => {
            staticMarkersRef.current.forEach((m) => m.remove());
            staticMarkersRef.current = [];

            if (departLat && departLng) {
                const m = new maplibregl.Marker({ element: creerMarqueurStatique("#2563eb", 16) })
                    .setLngLat([departLng, departLat])
                    .setPopup(new maplibregl.Popup({ closeButton: false }).setText("Départ"))
                    .addTo(map);
                staticMarkersRef.current.push(m);
            }

            if (destinationLat && destinationLng) {
                const m = new maplibregl.Marker({ element: creerMarqueurStatique("#16a34a", 16) })
                    .setLngLat([destinationLng, destinationLat])
                    .setPopup(new maplibregl.Popup({ closeButton: false }).setText("Destination"))
                    .addTo(map);
                staticMarkersRef.current.push(m);
            }
        };

        if (map.isStyleLoaded()) {
            addStatic();
        } else {
            map.once("load", addStatic);
        }
    }, [departLat, departLng, destinationLat, destinationLng]);

    // ── Marqueur conducteur (mise à jour temps réel) ───────────────────────
    useEffect(() => {
        const map = mapRef.current;
        if (!map || !positionActuelle) return;

        const { latitude: lat, longitude: lng, vitesse_kmh } = positionActuelle;

        if (conducteurRef.current) {
            // Déplacer le marqueur existant (animation fluide)
            conducteurRef.current.setLngLat([lng, lat]);
        } else {
            // Créer le marqueur pulsant pour la première fois
            const popup = new maplibregl.Popup({ offset: 16, closeButton: false }).setHTML(`
                <div style="font-size:12px; line-height:1.5;">
                    <strong>Conducteur</strong>
                    ${vitesse_kmh != null ? `<br>Vitesse : ${vitesse_kmh} km/h` : ""}
                    ${suiviInfo?.temps_restant_minutes != null
                        ? `<br>Arrivée dans ~${Math.round(suiviInfo.temps_restant_minutes)} min`
                        : ""}
                </div>
            `);

            conducteurRef.current = new maplibregl.Marker({
                element: creerMarqueurConducteur(),
            })
                .setLngLat([lng, lat])
                .setPopup(popup)
                .addTo(map);
        }

        // Suivre la position du conducteur
        map.easeTo({ center: [lng, lat], duration: 600, zoom: Math.max(map.getZoom(), 13) });
    }, [positionActuelle, suiviInfo]);

    return (
        <div className={className}>
            <div ref={containerRef} className="w-full h-full z-0" />
        </div>
    );
}
