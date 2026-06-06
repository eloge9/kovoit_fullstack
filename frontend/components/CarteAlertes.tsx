"use client";

import { useEffect, useRef } from "react";
import maplibregl from "maplibre-gl";

interface Feature {
    type: "Feature";
    geometry: { type: "LineString"; coordinates: number[][] };
    properties: { type_alerte: string; nom: string; ref: string };
}

interface FeatureCollection {
    type: "FeatureCollection";
    features: Feature[];
    count?: number;
}

interface CarteAlertesProps {
    data: FeatureCollection | null;
    className?: string;
    centre?: [number, number];
    zoom?: number;
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

const COULEUR_ALERTE: Record<string, string> = {
    bloquee:     "#dc2626",
    inondable:   "#2563eb",
    impraticable:"#d97706",
};

export default function CarteAlertes({
    data,
    className = "h-96 w-full rounded-xl overflow-hidden",
    centre = [1.2214, 6.1375],
    zoom = 12,
}: CarteAlertesProps) {
    const containerRef = useRef<HTMLDivElement>(null);
    const mapRef       = useRef<maplibregl.Map | null>(null);

    useEffect(() => {
        if (mapRef.current || !containerRef.current) return;

        mapRef.current = new maplibregl.Map({
            container: containerRef.current,
            style: OSM_STYLE,
            center: centre,
            zoom,
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
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    useEffect(() => {
        const map = mapRef.current;
        if (!map || !data) return;

        const addLayers = () => {
            ["alertes-source", "alertes-lines", "alertes-labels"].forEach((id) => {
                if (map.getLayer(id)) map.removeLayer(id);
                if (map.getSource(id.replace("-lines", "-source").replace("-labels", "-source"))) {
                    // remove source only once
                }
            });
            if (map.getLayer("alertes-lines")) map.removeLayer("alertes-lines");
            if (map.getLayer("alertes-labels")) map.removeLayer("alertes-labels");
            if (map.getSource("alertes-source")) map.removeSource("alertes-source");

            if (!data.features.length) return;

            map.addSource("alertes-source", {
                type: "geojson",
                data: data as GeoJSON.FeatureCollection,
            });

            map.addLayer({
                id: "alertes-lines",
                type: "line",
                source: "alertes-source",
                layout: { "line-cap": "round", "line-join": "round" },
                paint: {
                    "line-width": 5,
                    "line-color": [
                        "match",
                        ["get", "type_alerte"],
                        "bloquee",     COULEUR_ALERTE.bloquee,
                        "inondable",   COULEUR_ALERTE.inondable,
                        "impraticable",COULEUR_ALERTE.impraticable,
                        "#6b7280",
                    ],
                    "line-opacity": 0.85,
                },
            });

            // Popup au click
            map.on("click", "alertes-lines", (e) => {
                const feat = e.features?.[0];
                if (!feat) return;
                const props = feat.properties as { type_alerte: string; nom: string };
                const label = {
                    bloquee:      "Route bloquée",
                    inondable:    "Zone inondable",
                    impraticable: "Route impraticable",
                }[props.type_alerte] ?? props.type_alerte;

                new maplibregl.Popup({ closeButton: true })
                    .setLngLat(e.lngLat)
                    .setHTML(
                        `<div style="font-size:13px;line-height:1.6">
                            <strong>${label}</strong><br/>
                            ${props.nom || "Route sans nom"}
                        </div>`
                    )
                    .addTo(map);
            });

            map.on("mouseenter", "alertes-lines", () => {
                map.getCanvas().style.cursor = "pointer";
            });
            map.on("mouseleave", "alertes-lines", () => {
                map.getCanvas().style.cursor = "";
            });
        };

        if (map.isStyleLoaded()) {
            addLayers();
        } else {
            map.once("load", addLayers);
        }
    }, [data]);

    return (
        <div className={className}>
            <div ref={containerRef} className="w-full h-full" />
        </div>
    );
}
