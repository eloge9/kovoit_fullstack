"use client";

import { useEffect, useRef } from "react";
import dynamic from "next/dynamic";
import dynamicImport from 'next/dynamic';

const L = dynamicImport(() => import('leaflet'), {
    ssr: false,
});

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

export default function MapView({
    depart,
    destination,
    escales = [],
    height = "100%",
}: MapViewProps) {
    const mapRef = useRef<HTMLDivElement>(null);
    const instanceRef = useRef<any>(null);
    const layersRef = useRef<any[]>([]);

    useEffect(() => {
        if (instanceRef.current || !mapRef.current) return;

        // ✅ require uniquement Leaflet (pas le CSS)
        const L = require("leaflet");

        delete (L.Icon.Default.prototype as any)._getIconUrl;
        L.Icon.Default.mergeOptions({
            iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
            iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
            shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
        });

        instanceRef.current = L.map(mapRef.current, {
            center: [6.1375, 1.2214],
            zoom: 10,
        });

        L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
            attribution: "© OpenStreetMap contributors",
        }).addTo(instanceRef.current);

        return () => {
            instanceRef.current?.remove();
            instanceRef.current = null;
        };
    }, []);

    useEffect(() => {
        if (!instanceRef.current) return;
        const L = require("leaflet");

        layersRef.current.forEach((layer) => layer.remove());
        layersRef.current = [];

        const points = [depart, ...escales, destination].filter(Boolean) as Point[];
        if (points.length === 0) return;

        const makeIcon = (color: string) => L.divIcon({
            html: `<div style="width:14px;height:14px;background:${color};border:2px solid white;border-radius:50%;box-shadow:0 2px 6px rgba(0,0,0,0.3);"></div>`,
            className: "",
            iconSize: [14, 14],
            iconAnchor: [7, 7],
        });

        points.forEach((point, i) => {
            const isDepart = i === 0;
            const isDestination = i === points.length - 1;
            const color = isDepart ? "#2563eb" : isDestination ? "#16a34a" : "#d97706";

            const marker = L.marker([point.lat, point.lng], { icon: makeIcon(color) })
                .bindTooltip(point.nom, { permanent: false, direction: "top" })
                .addTo(instanceRef.current);
            layersRef.current.push(marker);
        });

        if (points.length >= 2) {
            const line = L.polyline(
                points.map((p) => [p.lat, p.lng]),
                { color: "#2563eb", weight: 3, opacity: 0.7, dashArray: "8, 6" }
            ).addTo(instanceRef.current);
            layersRef.current.push(line);

            const bounds = L.latLngBounds(points.map((p) => [p.lat, p.lng]));
            instanceRef.current.fitBounds(bounds, { padding: [40, 40] });
        }
    }, [depart, destination, escales]);

    return <div ref={mapRef} style={{ height, width: "100%" }} className="z-0" />;
}