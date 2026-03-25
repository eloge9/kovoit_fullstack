"use client";

import { useEffect, useRef } from "react";
import "leaflet/dist/leaflet.css";

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

export default function MapRecherche({
    trajets = [],
    trajetSurvole,
    depart,
    destination,
    onTrajetClick,
}: Props) {
    const mapRef = useRef<HTMLDivElement>(null);
    const instanceRef = useRef<any>(null);
    const layersRef = useRef<any[]>([]);

    // ── Initialiser la carte ──────────────────────────────────────────────
    useEffect(() => {
        if (instanceRef.current || !mapRef.current) return;
        const L = require("leaflet");

        delete (L.Icon.Default.prototype as any)._getIconUrl;
        L.Icon.Default.mergeOptions({
            iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
            iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
            shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
        });

        instanceRef.current = L.map(mapRef.current, {
            center: [6.8, 1.1],
            zoom: 7,
        });

        L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
            attribution: "© OpenStreetMap contributors",
        }).addTo(instanceRef.current);

        return () => {
            instanceRef.current?.remove();
            instanceRef.current = null;
        };
    }, []);

    // ── Mettre à jour les marqueurs selon les trajets ─────────────────────
    useEffect(() => {
        if (!instanceRef.current) return;

        // ✅ Garde — trajets doit être un tableau valide
        if (!trajets || !Array.isArray(trajets)) return;

        const L = require("leaflet");

        // Supprimer anciens layers
        layersRef.current.forEach((l) => l.remove());
        layersRef.current = [];

        const makeIcon = (color: string, size: number) => L.divIcon({
            html: `<div style="
                width:${size}px;
                height:${size}px;
                background:${color};
                border:2px solid white;
                border-radius:50%;
                box-shadow:0 2px 8px rgba(0,0,0,0.25);
            "></div>`,
            className: "",
            iconSize: [size, size],
            iconAnchor: [size / 2, size / 2],
        });

        const points: [number, number][] = [];

        trajets.forEach((trajet) => {
            if (!trajet.depart_lat || !trajet.destination_lat) return;

            const survole = trajetSurvole?.id === trajet.id;
            const color = survole ? "#2563eb" : "#94a3b8";
            const size = survole ? 16 : 10;

            // Marqueur départ
            const mDepart = L.marker([trajet.depart_lat, trajet.depart_lng], {
                icon: makeIcon(survole ? "#2563eb" : "#475569", size),
                zIndexOffset: survole ? 1000 : 0,
            })
                .bindTooltip(
                    `<b>${trajet.depart}</b> → ${trajet.destination}<br/>${Number(trajet.prix_par_place).toLocaleString("fr-FR")} FCFA`,
                    { direction: "top" }
                )
                .on("click", () => onTrajetClick(trajet.id))
                .addTo(instanceRef.current);

            // Marqueur destination
            const mDest = L.marker([trajet.destination_lat, trajet.destination_lng], {
                icon: makeIcon(survole ? "#16a34a" : "#94a3b8", size),
                zIndexOffset: survole ? 1000 : 0,
            })
                .bindTooltip(trajet.destination, { direction: "top" })
                .on("click", () => onTrajetClick(trajet.id))
                .addTo(instanceRef.current);

            // Ligne du trajet
            const ligne = L.polyline(
                [
                    [trajet.depart_lat, trajet.depart_lng],
                    [trajet.destination_lat, trajet.destination_lng],
                ],
                {
                    color,
                    weight: survole ? 3 : 1.5,
                    opacity: survole ? 0.9 : 0.35,
                    dashArray: "6, 4",
                }
            )
                .on("click", () => onTrajetClick(trajet.id))
                .addTo(instanceRef.current);

            layersRef.current.push(mDepart, mDest, ligne);
            points.push(
                [trajet.depart_lat, trajet.depart_lng],
                [trajet.destination_lat, trajet.destination_lng]
            );
        });

        // Ajuster le zoom
        if (points.length > 0) {
            instanceRef.current.fitBounds(
                L.latLngBounds(points),
                { padding: [40, 40] }
            );
        } else if (depart) {
            instanceRef.current.setView([depart.lat, depart.lng], 10);
        } else {
            // Recentrer sur le Togo par défaut
            instanceRef.current.setView([6.8, 1.1], 7);
        }

    }, [trajets, trajetSurvole]);

    return (
        <div
            ref={mapRef}
            style={{ height: "100%", width: "100%" }}
            className="z-0"
        />
    );
}