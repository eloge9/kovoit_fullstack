"use client";

import { useState, useEffect } from "react";
import { useParams, useRouter } from "next/navigation";
import dynamic from "next/dynamic";
import { getTrajet, type Trajet } from "@/src/services/trajet.service";
import { annulerTrajet, commencerTrajet, terminerTrajet } from "@/src/services/trajet.service";

const MapView = dynamic(() => import("@/components/MapView"), { ssr: false });

export default function DetailTrajetPage() {
    const { id } = useParams();
    const router = useRouter();

    const [trajet, setTrajet] = useState<Trajet | null>(null);
    const [loading, setLoading] = useState(true);
    const [annulation, setAnnulation] = useState(false);
    const [demarrage, setDemarrage] = useState(false);
    const [terminaison, setTerminaison] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [success, setSuccess] = useState(false);

    useEffect(() => {
        const fetch = async () => {
            setLoading(true);
            try {
                const data = await getTrajet(Number(id));
                setTrajet(data);
            } catch {
                setError("Trajet introuvable.");
            } finally {
                setLoading(false);
            }
        };
        if (id) fetch();
    }, [id]);

    const handleAnnuler = async () => {
        if (!confirm("Confirmer l'annulation de ce trajet ?")) return;

        setAnnulation(true);
        setError(null);
        try {
            await annulerTrajet(Number(id));
            setTrajet(prev => prev ? { ...prev, statut: "annule" } : null);
            setSuccess(true);
        } catch (err: any) {
            setError(err.response?.data?.error || "Erreur lors de l'annulation.");
        } finally {
            setAnnulation(false);
        }
    };

    const handleCommencer = async () => {
        if (!confirm("Commencer le trajet ?")) return;

        setDemarrage(true);
        setError(null);
        try {
            await commencerTrajet(Number(id));
            setTrajet(prev => prev ? { ...prev, statut: "en_cours" } : null);
        } catch (err: any) {
            setError(err.response?.data?.error || "Erreur lors du démarrage du trajet.");
        } finally {
            setDemarrage(false);
        }
    };

    const handleTerminer = async () => {
        if (!confirm("Terminer le trajet ?")) return;

        setTerminaison(true);
        setError(null);
        try {
            await terminerTrajet(Number(id));
            setTrajet(prev => prev ? { ...prev, statut: "termine" } : null);
        } catch (err: any) {
            setError(err.response?.data?.error || "Erreur lors de la terminaison du trajet.");
        } finally {
            setTerminaison(false);
        }
    };

    const formatDate = (iso: string) =>
        new Date(iso).toLocaleDateString("fr-FR", {
            weekday: "long", day: "numeric", month: "long",
            year: "numeric", hour: "2-digit", minute: "2-digit",
        });

    const placesReservees = trajet
        ? trajet.places_disponibles - (trajet.places_restantes ?? trajet.places_disponibles)
        : 0;

    // ── Succès annulation ──────────────────────────────────────────────
    if (success) {
        return (
            <div className="max-w-lg mx-auto py-16 text-center space-y-4">
                <div className="w-16 h-16 rounded-full bg-success/10 flex items-center justify-center mx-auto">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                </div>
                <h2 className="text-xl font-bold text-base-content">Trajet annulé</h2>
                <p className="text-base-content/50 text-sm">
                    Le trajet a été annulé avec succès. Les passagers seront notifiés.
                </p>
                <div className="flex gap-3 justify-center pt-4">
                    <button
                        onClick={() => router.push("/conducteur/trajets")}
                        className="btn btn-primary rounded-full px-6"
                    >
                        Mes trajets
                    </button>
                    <button
                        onClick={() => setSuccess(false)}
                        className="btn btn-ghost rounded-full px-6 border border-base-300"
                    >
                        Voir le trajet
                    </button>
                </div>
            </div>
        );
    }

    // ── Chargement ──────────────────────────────────────────────────────
    if (loading) {
        return (
            <div className="max-w-2xl mx-auto space-y-4 animate-pulse">
                <div className="h-6 bg-base-300 rounded w-1/3" />
                <div className="h-64 bg-base-300 rounded-2xl" />
                <div className="h-32 bg-base-300 rounded-2xl" />
            </div>
        );
    }

    // ── Erreur ──────────────────────────────────────────────────────────
    if (!trajet) {
        return (
            <div className="max-w-lg mx-auto py-16 text-center">
                <p className="text-base-content/40">Trajet introuvable.</p>
                <button onClick={() => router.back()} className="btn btn-ghost btn-sm rounded-full mt-4">
                    Retour
                </button>
            </div>
        );
    }

    return (
        <div className="max-w-2xl mx-auto space-y-6">

            {/* EN-TÊTE */}
            <div className="flex items-center gap-3 pb-4 border-b border-base-300">
                <button
                    onClick={() => router.back()}
                    className="btn btn-ghost btn-sm btn-square rounded-xl"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
                    </svg>
                </button>
                <div>
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                        Mon trajet
                    </p>
                    <h1 className="text-xl font-bold text-base-content tracking-tight">
                        {trajet.depart}
                        <span className="text-base-content/25 mx-2 font-light">→</span>
                        {trajet.destination}
                    </h1>
                </div>
            </div>

            {/* CARTE */}
            {(trajet.depart_lat && trajet.destination_lat) && (
                <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                    <div className="h-52">
                        <MapView
                            depart={{ nom: trajet.depart, lat: trajet.depart_lat, lng: trajet.depart_lng }}
                            destination={{ nom: trajet.destination, lat: trajet.destination_lat, lng: trajet.destination_lng }}
                        />
                    </div>
                </div>
            )}

            {/* INFOS TRAJET */}
            <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                <div className="px-6 py-4 border-b border-base-200">
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                        Informations
                    </p>
                </div>
                <div className="divide-y divide-base-200">
                    {[
                        { label: "Départ", value: trajet.depart },
                        { label: "Arrivée", value: trajet.destination },
                        { label: "Date", value: formatDate(trajet.date_heure_depart) },
                        { label: "Distance", value: trajet.distance_km ? `${trajet.distance_km} km` : null },
                        { label: "Places réservées", value: `${placesReservees} / ${trajet.places_disponibles}` },
                        { label: "Prix par place", value: `${Number(trajet.prix_par_place).toLocaleString("fr-FR")} FCFA` },
                        trajet.description ? { label: "Note", value: trajet.description } : null,
                    ].filter(Boolean).map((item: any) => (
                        <div key={item.label} className="flex justify-between items-start px-6 py-3 gap-4">
                            <span className="text-xs text-base-content/40 uppercase tracking-wide shrink-0">
                                {item.label}
                            </span>
                            <span className="text-sm font-medium text-base-content text-right">
                                {item.value}
                            </span>
                        </div>
                    ))}
                </div>
            </div>

            {/* VÉHICULE */}
            {trajet.vehicule_info && (
                <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-4">
                        Véhicule
                    </p>
                    <div className="space-y-3">
                        <div className="flex items-center justify-between">
                            <span className="text-sm font-medium text-base-content">
                                {trajet.vehicule_info.marque} {trajet.vehicule_info.modele}
                            </span>
                            <span className="text-sm text-base-content/60">
                                {trajet.vehicule_info.plaque}
                            </span>
                        </div>
                        <div className="flex items-center gap-4 text-sm text-base-content/60">
                            <span>{trajet.vehicule_info.type_vehicule}</span>
                            <span>{trajet.vehicule_info.couleur}</span>
                            <span>{trajet.vehicule_info.places_max} places</span>
                        </div>
                    </div>
                </div>
            )}

            {/* STATUT + ACTIONS */}
            <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
                <div className="flex items-center justify-between mb-4">
                    <div>
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                            Statut
                        </p>
                        <span className={`badge rounded-full font-medium mt-1 ${trajet.statut === "ouvert" ? "badge-success badge-outline" :
                            trajet.statut === "en_cours" ? "badge-info badge-outline" :
                                trajet.statut === "termine" ? "badge-ghost" :
                                    "badge-error badge-outline"
                            }`}>
                            {trajet.statut === "ouvert" ? "Ouvert" :
                                trajet.statut === "en_cours" ? "En cours" :
                                    trajet.statut === "termine" ? "Terminé" : "Annulé"}
                        </span>
                    </div>
                    <div className="text-right">
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                            Revenu total
                        </p>
                        <p className="text-2xl font-bold text-primary mt-1">
                            {(placesReservees * Number(trajet.prix_par_place)).toLocaleString("fr-FR")} FCFA
                        </p>
                    </div>
                </div>

                {/* Erreur */}
                {error && (
                    <div className="bg-error/10 border border-error/20 rounded-xl px-4 py-3 mb-4">
                        <p className="text-sm text-error">{error}</p>
                    </div>
                )}

                {/* Actions */}
                <div className="space-y-3">
                    <button
                        onClick={() => router.push(`/conducteur/trajet/${trajet.id}`)}
                        className="btn btn-primary w-full rounded-full"
                    >
                        Gérer le trajet
                    </button>

                    {trajet.statut === "ouvert" && (
                        <>
                            <button
                                onClick={handleCommencer}
                                disabled={demarrage}
                                className="btn btn-success w-full rounded-full"
                            >
                                {demarrage
                                    ? <span className="loading loading-spinner loading-sm" />
                                    : "Commencer le trajet"
                                }
                            </button>
                            <button
                                onClick={() => router.push(`/conducteur/trajets/edit/${trajet.id}`)}
                                className="btn btn-outline w-full rounded-full"
                            >
                                Modifier
                            </button>
                            <button
                                onClick={handleAnnuler}
                                disabled={annulation}
                                className="btn btn-error btn-outline w-full rounded-full"
                            >
                                {annulation
                                    ? <span className="loading loading-spinner loading-sm" />
                                    : "Annuler le trajet"
                                }
                            </button>
                        </>
                    )}

                    {trajet.statut === "en_cours" && (
                        <>
                            <button
                                onClick={handleTerminer}
                                disabled={terminaison}
                                className="btn btn-warning w-full rounded-full"
                            >
                                {terminaison
                                    ? <span className="loading loading-spinner loading-sm" />
                                    : "Terminer le trajet"
                                }
                            </button>
                            <div className="text-center py-4 space-y-3">
                                <div className="flex items-center justify-center gap-2 text-info">
                                    <span className="loading loading-spinner loading-sm"></span>
                                    <span className="font-medium">Trajet en cours</span>
                                </div>
                                <p className="text-sm text-base-content/60">
                                    Les passagers ont été notifiés du début du trajet.
                                </p>
                            </div>
                        </>
                    )}
                </div>
            </div>

        </div>
    );
}
