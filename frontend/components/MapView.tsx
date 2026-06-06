"use client";

import { useEffect, useRef } from "react";
import maplibregl from "maplibre-gl";

interface Point {
    nom: string;
    lat: number;
    lng: number;
}

interface MapViewProps {
    depart: Point | null;
    destination: Point | null;
    escales?: Point[];
    height?: string;
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

// Récupère la géométrie de la route réelle depuis OSRM
async function fetchRouteGeometry(dep: Point, dest: Point): Promise<any> {
    try {
        const coords = `${dep.lng},${dep.lat};${dest.lng},${dest.lat}`;
        const res = await fetch(
            `https://router.project-osrm.org/route/v1/driving/${coords}?overview=full&geometries=geojson`
        );
        const data = await res.json();
        if (data.code === "Ok" && data.routes?.[0]?.geometry) {
            return data.routes[0].geometry;
        }
    } catch {
        // OSRM inaccessible : on utilisera une ligne droite en fallback
    }
    return null;
}

export default function MapView({
    depart,
    destination,
    escales = [],
    height = "100%",
}: MapViewProps) {
    const containerRef = useRef<HTMLDivElement>(null);
    const mapRef       = useRef<maplibregl.Map | null>(null);
    const markersRef   = useRef<maplibregl.Marker[]>([]);

    // Initialiser la carte une seule fois
    useEffect(() => {
        if (mapRef.current || !containerRef.current) return;

        mapRef.current = new maplibregl.Map({
            container: containerRef.current,
            style: OSM_STYLE,
            center: [1.2214, 6.1375], // Lomé, Togo
            zoom: 10,
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
            mapRef.current?.remove();
            mapRef.current = null;
        };
    }, []);

    // Mettre à jour marqueurs + route à chaque changement de points
    useEffect(() => {
        const map = mapRef.current;
        if (!map) return;

        let cancelled = false;

        // Supprimer les anciens marqueurs
        markersRef.current.forEach((m) => m.remove());
        markersRef.current = [];

        // Supprimer les couches/sources de route précédentes
        const removeRoute = () => {
            ["route", "route-casing"].forEach((id) => {
                try { if (map.getLayer(id)) map.removeLayer(id); } catch {}
            });
            try { if (map.getSource("route")) map.removeSource("route"); } catch {}
        };

        const points = [depart, ...escales, destination].filter(Boolean) as Point[];
        if (points.length === 0) return;

        // Créer les marqueurs colorés
        points.forEach((p, i) => {
            const isLast  = i === points.length - 1 && points.length > 1;
            const couleur = i === 0 ? "#2563eb" : isLast ? "#16a34a" : "#d97706";
            const taille  = (i === 0 || isLast) ? 18 : 14;

            const el = document.createElement("div");
            el.style.cssText = `
                width:${taille}px; height:${taille}px;
                background:${couleur}; border:3px solid #fff;
                border-radius:50%; box-shadow:0 2px 8px rgba(0,0,0,.4);
                cursor:pointer;
            `;

            const marker = new maplibregl.Marker({ element: el })
                .setLngLat([p.lng, p.lat])
                .setPopup(
                    new maplibregl.Popup({ offset: 14, closeButton: false }).setText(p.nom)
                )
                .addTo(map);

            markersRef.current.push(marker);
        });

        // Cadrer la vue sur tous les points
        if (points.length === 1) {
            map.flyTo({ center: [points[0].lng, points[0].lat], zoom: 14, duration: 700 });
        } else {
            const bounds = new maplibregl.LngLatBounds();
            points.forEach((p) => bounds.extend([p.lng, p.lat]));
            map.fitBounds(bounds, { padding: 60, maxZoom: 14, duration: 700 });
        }

        // Route OSRM uniquement si départ ET destination définis
        if (!depart || !destination) return;

        const drawRoute = async () => {
            const geometry = await fetchRouteGeometry(depart, destination);
            if (cancelled) return;

            // Fallback : ligne droite si OSRM échoue
            const lineGeometry = geometry ?? {
                type: "LineString",
                coordinates: points.map((p) => [p.lng, p.lat]),
            };

            if (map.isStyleLoaded()) {
                removeRoute();
            }

            map.addSource("route", {
                type: "geojson",
                data: { type: "Feature", geometry: lineGeometry, properties: {} },
            });

            // Halo de la route (effet de profondeur)
            map.addLayer({
                id: "route-casing",
                type: "line",
                source: "route",
                paint: {
                    "line-color": "#1d4ed8",
                    "line-width": 8,
                    "line-opacity": geometry ? 0.2 : 0,
                },
                layout: { "line-cap": "round", "line-join": "round" },
            });

            // Route principale
            map.addLayer({
                id: "route",
                type: "line",
                source: "route",
                paint: {
                    "line-color": "#2563eb",
                    "line-width": 4,
                    "line-opacity": 0.85,
                    // Tirets si c'est une ligne droite de fallback
                    ...(geometry ? {} : { "line-dasharray": [3, 3] }),
                },
                layout: { "line-cap": "round", "line-join": "round" },
            });
        };

        if (map.isStyleLoaded()) {
            removeRoute();
            drawRoute();
        } else {
            map.once("load", () => {
                if (!cancelled) drawRoute();
            });
        }

        return () => {
            cancelled = true;
        };
    }, [depart, destination, escales]);

    return (
        <div ref={containerRef} style={{ height, width: "100%" }} className="z-0" />
    );
}
