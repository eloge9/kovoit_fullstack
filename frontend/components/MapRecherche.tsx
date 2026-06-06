"use client";

import { useEffect, useRef } from "react";
import maplibregl from "maplibre-gl";

interface Point { nom: string; lat: number; lng: number; }

interface Trajet {
    id: number;
    depart: string;
    destination: string;
    depart_lat: number;
    depart_lng: number;
    destination_lat: number;
    destination_lng: number;
    prix_par_place: number;
    conducteur_nom: string;
}

interface Props {
    trajets: Trajet[];
    trajetSurvole: Trajet | null;
    depart: Point | null;
    destination: Point | null;
    onTrajetClick: (id: number) => void;
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

export default function MapRecherche({
    trajets = [],
    trajetSurvole,
    depart,
    destination,
    onTrajetClick,
}: Props) {
    const containerRef = useRef<HTMLDivElement>(null);
    const mapRef       = useRef<maplibregl.Map | null>(null);
    const markersRef   = useRef<maplibregl.Marker[]>([]);
    const linesRef     = useRef<string[]>([]); // IDs des layers de lignes

    // Initialiser la carte une seule fois
    useEffect(() => {
        if (mapRef.current || !containerRef.current) return;

        mapRef.current = new maplibregl.Map({
            container: containerRef.current,
            style: OSM_STYLE,
            center: [1.1, 6.8], // Centre du Togo
            zoom: 7,
            attributionControl: false,
        });

        mapRef.current.addControl(
            new maplibregl.AttributionControl({ compact: true }),
            "bottom-right"
        );

        return () => {
            mapRef.current?.remove();
            mapRef.current = null;
        };
    }, []);

    // Mettre à jour les marqueurs et lignes quand les trajets changent
    useEffect(() => {
        const map = mapRef.current;
        if (!map || !Array.isArray(trajets)) return;

        // Supprimer anciens marqueurs
        markersRef.current.forEach((m) => m.remove());
        markersRef.current = [];

        // Supprimer anciens layers de lignes
        const removeLines = () => {
            linesRef.current.forEach((id) => {
                try { if (map.getLayer(id)) map.removeLayer(id); } catch {}
                try { if (map.getSource(id)) map.removeSource(id); } catch {}
            });
            linesRef.current = [];
        };

        const renderTrajets = () => {
            removeLines();

            const bounds = new maplibregl.LngLatBounds();
            let hasBounds = false;

            trajets.forEach((trajet) => {
                if (!trajet.depart_lat || !trajet.destination_lat) return;

                const survole = trajetSurvole?.id === trajet.id;
                const couleurDepart = survole ? "#2563eb" : "#475569";
                const couleurDest   = survole ? "#16a34a" : "#94a3b8";
                const tailleM       = survole ? 16 : 10;

                // Marqueur départ
                const elDep = document.createElement("div");
                elDep.style.cssText = `
                    width:${tailleM}px; height:${tailleM}px;
                    background:${couleurDepart}; border:2px solid #fff;
                    border-radius:50%; box-shadow:0 1px 6px rgba(0,0,0,.3);
                    cursor:pointer; z-index:${survole ? 10 : 1};
                `;

                const mDep = new maplibregl.Marker({ element: elDep })
                    .setLngLat([trajet.depart_lng, trajet.depart_lat])
                    .setPopup(
                        new maplibregl.Popup({ closeButton: false }).setHTML(
                            `<b>${trajet.depart}</b> → ${trajet.destination}<br/>
                            <span style="color:#2563eb;font-weight:600">
                                ${Number(trajet.prix_par_place).toLocaleString("fr-FR")} FCFA
                            </span>`
                        )
                    )
                    .addTo(map);
                elDep.addEventListener("click", () => onTrajetClick(trajet.id));

                // Marqueur destination
                const elDest = document.createElement("div");
                elDest.style.cssText = `
                    width:${tailleM}px; height:${tailleM}px;
                    background:${couleurDest}; border:2px solid #fff;
                    border-radius:50%; box-shadow:0 1px 6px rgba(0,0,0,.3);
                    cursor:pointer; z-index:${survole ? 10 : 1};
                `;

                const mDest = new maplibregl.Marker({ element: elDest })
                    .setLngLat([trajet.destination_lng, trajet.destination_lat])
                    .setPopup(
                        new maplibregl.Popup({ closeButton: false }).setText(trajet.destination)
                    )
                    .addTo(map);
                elDest.addEventListener("click", () => onTrajetClick(trajet.id));

                markersRef.current.push(mDep, mDest);

                // Ligne départ → destination
                const lineId = `line-${trajet.id}`;
                map.addSource(lineId, {
                    type: "geojson",
                    data: {
                        type: "Feature",
                        geometry: {
                            type: "LineString",
                            coordinates: [
                                [trajet.depart_lng, trajet.depart_lat],
                                [trajet.destination_lng, trajet.destination_lat],
                            ],
                        },
                        properties: {},
                    },
                });
                map.addLayer({
                    id: lineId,
                    type: "line",
                    source: lineId,
                    paint: {
                        "line-color": survole ? "#2563eb" : "#94a3b8",
                        "line-width": survole ? 3 : 1.5,
                        "line-opacity": survole ? 0.9 : 0.35,
                        "line-dasharray": [5, 4],
                    },
                    layout: { "line-cap": "round", "line-join": "round" },
                });
                linesRef.current.push(lineId);

                bounds.extend([trajet.depart_lng, trajet.depart_lat]);
                bounds.extend([trajet.destination_lng, trajet.destination_lat]);
                hasBounds = true;
            });

            // Ajuster la vue
            if (hasBounds) {
                map.fitBounds(bounds, { padding: 50, maxZoom: 13, duration: 600 });
            } else if (depart) {
                map.flyTo({ center: [depart.lng, depart.lat], zoom: 10 });
            } else {
                map.flyTo({ center: [1.1, 6.8], zoom: 7 });
            }
        };

        if (map.isStyleLoaded()) {
            renderTrajets();
        } else {
            map.once("load", renderTrajets);
        }
    }, [trajets, trajetSurvole, depart]);

    return (
        <div ref={containerRef} style={{ height: "100%", width: "100%" }} className="z-0" />
    );
}
