"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { mesTrajets, annulerTrajet, commencerTrajet, type Trajet } from "@/src/services/trajet.service";

export default function MesTrajetsPage() {
    const [trajets, setTrajets] = useState<Trajet[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [filtre, setFiltre] = useState<"tous" | "ouvert" | "termine" | "annule">("tous");
    const [annulation, setAnnulation] = useState<number | null>(null);
    const [demarrage, setDemarrage] = useState<number | null>(null);

    useEffect(() => { fetchTrajets(); }, []);

    const fetchTrajets = async () => {
        setLoading(true);
        try {
            const data = await mesTrajets();
            setTrajets(data);
        } catch {
            setError("Impossible de charger vos trajets.");
        } finally {
            setLoading(false);
        }
    };

    const handleAnnuler = async (id: number) => {
        if (!confirm("Confirmer l'annulation de ce trajet ?")) return;
        setAnnulation(id);
        try {
            await annulerTrajet(id);
            setTrajets((prev) =>
                prev.map((t) => t.id === id ? { ...t, statut: "annule" } : t)
            );
        } catch {
            setError("Erreur lors de l'annulation.");
        } finally {
            setAnnulation(null);
        }
    };

    const handleCommencer = async (id: number) => {
        if (!confirm("Commencer le trajet ? Le suivi GPS sera activé et les passagers seront notifiés.")) return;
        setDemarrage(id);
        try {
            await commencerTrajet(id);
            setTrajets((prev) =>
                prev.map((t) => t.id === id ? { ...t, statut: "en_cours" } : t)
            );
        } catch {
            setError("Erreur lors du démarrage du trajet.");
        } finally {
            setDemarrage(null);
        }
    };

    const trajetsFiltres = trajets.filter((t) =>
        filtre === "tous" ? true : t.statut === filtre
    );

    const counts = {
        tous: trajets.length,
        ouvert: trajets.filter((t) => t.statut === "ouvert").length,
        termine: trajets.filter((t) => t.statut === "termine").length,
        annule: trajets.filter((t) => t.statut === "annule").length,
    };

    const formatDate = (iso: string) =>
        new Date(iso).toLocaleDateString("fr-FR", {
            weekday: "short", day: "numeric", month: "short",
            hour: "2-digit", minute: "2-digit",
        });

    const statutStyle = (statut: string) => {
        switch (statut) {
            case "ouvert": return "badge-success badge-outline";
            case "en_cours": return "badge-info badge-outline";
            case "termine": return "badge-ghost";
            case "annule": return "badge-error badge-outline";
            default: return "badge-ghost";
        }
    };

    return (
        <div className="space-y-8">

            {/* EN-TÊTE */}
            <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4 pb-6 border-b border-base-300">
                <div>
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">
                        Conducteur
                    </p>
                    <h1 className="text-2xl font-bold text-base-content tracking-tight">
                        Mes trajets
                    </h1>
                    <p className="text-base-content/40 mt-1 text-sm">
                        {counts.tous} trajet{counts.tous > 1 ? "s" : ""} au total
                    </p>
                </div>
                <Link href="/conducteur/trajets/create" className="btn btn-primary btn-sm rounded-full px-6 w-fit">
                    Proposer un trajet
                </Link>
            </div>

            {/* ERREUR */}
            {error && (
                <div className="bg-error/10 border border-error/20 rounded-xl px-4 py-3">
                    <p className="text-sm text-error">{error}</p>
                </div>
            )}

            {/* FILTRES */}
            <div className="flex gap-2 flex-wrap">
                {(["tous", "ouvert", "termine", "annule"] as const).map((f) => (
                    <button
                        key={f}
                        onClick={() => setFiltre(f)}
                        className={`btn btn-sm rounded-full capitalize transition-all ${filtre === f ? "btn-primary" : "btn-ghost border border-base-300"
                            }`}
                    >
                        {f === "tous" ? "Tous" : f === "ouvert" ? "Ouverts"
                            : f === "termine" ? "Terminés" : "Annulés"}
                        <span className={`ml-1 text-xs ${filtre === f ? "opacity-80" : "text-base-content/40"}`}>
                            {counts[f]}
                        </span>
                    </button>
                ))}
            </div>

            {/* LISTE */}
            {loading ? (
                <div className="flex flex-col gap-3">
                    {[1, 2, 3].map((i) => (
                        <div key={i} className="bg-base-100 rounded-2xl border border-base-200 p-6 animate-pulse">
                            <div className="h-4 bg-base-300 rounded w-1/3 mb-3" />
                            <div className="h-3 bg-base-300 rounded w-1/2" />
                        </div>
                    ))}
                </div>
            ) : trajetsFiltres.length === 0 ? (
                <div className="bg-base-100 rounded-2xl border border-base-200 p-12 text-center">
                    <p className="text-base-content/40 text-sm">
                        {filtre === "tous"
                            ? "Vous n'avez pas encore proposé de trajet."
                            : `Aucun trajet ${filtre === "ouvert" ? "ouvert" : filtre === "termine" ? "terminé" : "annulé"}.`
                        }
                    </p>
                    {filtre === "tous" && (
                        <Link href="/conducteur/trajets/create" className="btn btn-primary btn-sm rounded-full mt-4">
                            Proposer mon premier trajet
                        </Link>
                    )}
                </div>
            ) : (
                <div className="flex flex-col gap-3">
                    {trajetsFiltres.map((trajet) => (
                        <div
                            key={trajet.id}
                            className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden hover:shadow-sm transition-shadow"
                        >
                            <div className="flex flex-col sm:flex-row sm:items-center justify-between px-6 py-5 gap-4">
                                <div className="flex-1 min-w-0">
                                    <div className="flex items-center gap-2 flex-wrap">
                                        <p className="font-semibold text-base-content">
                                            {trajet.depart}
                                            <span className="text-base-content/25 mx-2 font-light">→</span>
                                            {trajet.destination}
                                        </p>
                                        <span className={`badge badge-sm rounded-full font-medium ${statutStyle(trajet.statut)}`}>
                                            {trajet.statut}
                                        </span>
                                    </div>
                                    <div className="flex items-center gap-4 mt-1.5 flex-wrap">
                                        <p className="text-xs text-base-content/40">{formatDate(trajet.date_heure_depart)}</p>
                                        <p className="text-xs text-base-content/40">
                                            {trajet.places_disponibles} place{trajet.places_disponibles > 1 ? "s" : ""}
                                        </p>
                                        <p className="text-xs font-semibold text-primary">
                                            {Number(trajet.prix_par_place).toLocaleString("fr-FR")} FCFA / place
                                        </p>
                                    </div>
                                </div>

                                <div className="flex items-center gap-2 shrink-0">
                                    <Link href={`/conducteur/trajets/${trajet.id}`}
                                        className="btn btn-ghost btn-sm rounded-xl border border-base-200 text-xs">
                                        Voir
                                    </Link>
                                    {trajet.statut === "ouvert" && (
                                        <>
                                            <button
                                                onClick={() => handleCommencer(trajet.id)}
                                                disabled={demarrage === trajet.id}
                                                className="btn btn-success btn-sm rounded-xl text-xs text-white"
                                            >
                                                {demarrage === trajet.id
                                                    ? <span className="loading loading-spinner loading-xs" />
                                                    : "Commencer"
                                                }
                                            </button>
                                            <Link href={`/conducteur/trajets/edit/${trajet.id}`}
                                                className="btn btn-ghost btn-sm rounded-xl border border-base-200 text-xs">
                                                Modifier
                                            </Link>
                                            <button
                                                onClick={() => handleAnnuler(trajet.id)}
                                                disabled={annulation === trajet.id}
                                                className="btn btn-ghost btn-sm rounded-xl border border-error/30 text-error text-xs hover:bg-error/5"
                                            >
                                                {annulation === trajet.id
                                                    ? <span className="loading loading-spinner loading-xs" />
                                                    : "Annuler"
                                                }
                                            </button>
                                        </>
                                    )}
                                </div>
                            </div>

                            <div className="px-6 py-3 bg-base-200/50 border-t border-base-200 flex items-center gap-6 flex-wrap">
                                {trajet.distance_km && (
                                    <div className="flex items-center gap-1.5">
                                        <span className="text-xs text-base-content/40 uppercase tracking-wide">Distance</span>
                                        <span className="text-xs font-medium text-base-content">{trajet.distance_km} km</span>
                                    </div>
                                )}
                                <div className="flex items-center gap-1.5">
                                    <span className="text-xs text-base-content/40 uppercase tracking-wide">Réservations</span>
                                    <span className="text-xs font-medium text-base-content">
                                        {trajet.places_disponibles - (trajet.places_restantes ?? trajet.places_disponibles)} / {trajet.places_disponibles}
                                    </span>
                                </div>
                                {trajet.description && (
                                    <div className="flex items-center gap-1.5 min-w-0">
                                        <span className="text-xs text-base-content/40 uppercase tracking-wide shrink-0">Note</span>
                                        <span className="text-xs text-base-content/60 truncate">{trajet.description}</span>
                                    </div>
                                )}
                            </div>
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
}