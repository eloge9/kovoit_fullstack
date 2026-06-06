"use client";

import { useEffect, useRef } from "react";
import maplibregl from "maplibre-gl";
import type { ItineraireRoute } from "@/src/services/trajet.service";

interface CarteItineraireProps {
    routes: ItineraireRoute[];
    departLat: number;
    departLng: number;
    destinationLat: number;
    destinationLng: number;
    routeSelectionnee?: number;
    className?: string;
}

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

function creerMarqueur(couleur: string, label: string): HTMLElement {
    const el = document.createElement("div");
    el.title = label;
    el.style.cssText = `
        width:18px;height:18px;
        background:${couleur};border:3px solid #fff;
        border-radius:50%;box-shadow:0 2px 8px rgba(0,0,0,.4);
        cursor:pointer;
    `;
    return el;
}

export default function CarteItineraire({
    routes,
    departLat,
    departLng,
    destinationLat,
    destinationLng,
    routeSelectionnee = 0,
    className = "h-80 w-full rounded-xl overflow-hidden",
}: CarteItineraireProps) {
    const containerRef = useRef<HTMLDivElement>(null);
    const mapRef       = useRef<maplibregl.Map | null>(null);
    const markersRef   = useRef<maplibregl.Marker[]>([]);

    useEffect(() => {
        if (mapRef.current || !containerRef.current) return;

        mapRef.current = new maplibregl.Map({
            container: containerRef.current,
            style: OSM_STYLE,
            center: [departLng, departLat],
            zoom: 11,
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
            markersRef.current.forEach((m) => m.remove());
            markersRef.current = [];
            mapRef.current?.remove();
            mapRef.current = null;
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    useEffect(() => {
        const map = mapRef.current;
        if (!map || !routes.length) return;

        const drawRoutes = () => {
            // Nettoyer les couches précédentes
            routes.forEach((_, i) => {
                if (map.getLayer(`route-${i}`)) map.removeLayer(`route-${i}`);
                if (map.getSource(`route-${i}`)) map.removeSource(`route-${i}`);
            });
            markersRef.current.forEach((m) => m.remove());
            markersRef.current = [];

            // Dessiner les alternatives d'abord (gris pointillé), puis la principale (bleu)
            const ordre = [...routes.map((_, i) => i)].sort((a, b) =>
                a === routeSelectionnee ? 1 : b === routeSelectionnee ? -1 : 0
            );

            ordre.forEach((i) => {
                const route    = routes[i];
                const estPrinc = i === routeSelectionnee;

                map.addSource(`route-${i}`, {
                    type: "geojson",
                    data: {
                        type: "Feature",
                        geometry: route.geometry as GeoJSON.Geometry,
                        properties: {},
                    },
                });

                map.addLayer({
                    id: `route-${i}`,
                    type: "line",
                    source: `route-${i}`,
                    layout: { "line-cap": "round", "line-join": "round" },
                    paint: {
                        "line-width":   estPrinc ? 5 : 3,
                        "line-color":   estPrinc ? "#2563eb" : "#9ca3af",
                        "line-opacity": estPrinc ? 0.9 : 0.6,
                        "line-dasharray": estPrinc ? [1] : [2, 2],
                    },
                });
            });

            // Marqueurs départ / destination
            markersRef.current.push(
                new maplibregl.Marker({ element: creerMarqueur("#2563eb", "Départ") })
                    .setLngLat([departLng, departLat])
                    .setPopup(new maplibregl.Popup({ closeButton: false }).setText("Départ"))
                    .addTo(map)
            );
            markersRef.current.push(
                new maplibregl.Marker({ element: creerMarqueur("#16a34a", "Destination") })
                    .setLngLat([destinationLng, destinationLat])
                    .setPopup(new maplibregl.Popup({ closeButton: false }).setText("Destination"))
                    .addTo(map)
            );

            // Ajuster le viewport pour englober toutes les routes
            const allCoords = routes.flatMap((r) =>
                (r.geometry.coordinates as number[][]).map(([lng, lat]) => [lng, lat] as [number, number])
            );
            if (allCoords.length > 0) {
                const bounds = allCoords.reduce(
                    (b, [lng, lat]) => b.extend([lng, lat]),
                    new maplibregl.LngLatBounds(allCoords[0], allCoords[0])
                );
                map.fitBounds(bounds, { padding: 48, maxZoom: 15, duration: 600 });
            }
        };

        if (map.isStyleLoaded()) {
            drawRoutes();
        } else {
            map.once("load", drawRoutes);
        }
    }, [routes, routeSelectionnee, departLat, departLng, destinationLat, destinationLng]);

    return (
        <div className={className}>
            <div ref={containerRef} className="w-full h-full" />
        </div>
    );
}
