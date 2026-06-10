"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { mesReservations } from "@/src/services/reservation.service";
import { api } from "@/src/services/api";

interface Reservation {
    id: number;
    trajet_id: number;
    depart: string;
    destination: string;
    date_depart: string;
    conducteur: string;
    prix_par_place: number;
    statut: "en_attente" | "confirmee" | "declinee" | "terminee";
    date_reservation: string;
}

export default function MesReservationsPage() {
    const router = useRouter();

    const [reservations, setReservations] = useState<Reservation[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [filtre, setFiltre] = useState<"tous" | "en_attente" | "confirmee" | "declinee" | "terminee">("tous");
    const [annulation, setAnnulation] = useState<number | null>(null);

    useEffect(() => { fetchReservations(); }, []);

    const fetchReservations = async () => {
        setLoading(true);
        try {
            const data = await mesReservations();
            setReservations(Array.isArray(data) ? data : []);
        } catch {
            setError("Impossible de charger vos réservations.");
        } finally {
            setLoading(false);
        }
    };

    const handleAnnuler = async (id: number) => {
        if (!confirm("Confirmer l'annulation de cette réservation ?")) return;
        setAnnulation(id);
        setError(null);
        try {
            await api(`/reservations/${id}/annuler/`, "POST");
            // Supprimer de la liste localement
            setReservations((prev) => prev.filter((r) => r.id !== id));
        } catch (err: any) {
            setError(err.response?.data?.error || "Erreur lors de l'annulation.");
        } finally {
            setAnnulation(null);
        }
    };

    const filtrees = reservations.filter((r) =>
        filtre === "tous" ? true : r.statut === filtre
    );

    const counts = {
        tous: reservations.length,
        en_attente: reservations.filter((r) => r.statut === "en_attente").length,
        confirmee: reservations.filter((r) => r.statut === "confirmee").length,
        declinee: reservations.filter((r) => r.statut === "declinee").length,
        terminee: reservations.filter((r) => r.statut === "terminee").length,
    };

    const formatDate = (iso: string) =>
        new Date(iso).toLocaleDateString("fr-FR", {
            weekday: "short", day: "numeric", month: "short",
            hour: "2-digit", minute: "2-digit",
        });

    const statutBadge = (statut: string) => {
        switch (statut) {
            case "en_attente": return "badge-warning badge-outline";
            case "confirmee": return "badge-success badge-outline";
            case "declinee": return "badge-error badge-outline";
            case "terminee": return "badge-info badge-outline";
            default: return "badge-ghost";
        }
    };

    const statutLabel = (statut: string) => {
        switch (statut) {
            case "en_attente": return "En attente";
            case "confirmee": return "Confirmée";
            case "declinee": return "Déclinée";
            case "terminee": return "Terminée";
            default: return statut;
        }
    };

    return (
        <div className="space-y-8">

            {/* EN-TÊTE */}
            <div className="pb-6 border-b border-base-300">
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">
                    Passager
                </p>
                <h1 className="text-2xl font-bold text-base-content tracking-tight">
                    Mes réservations
                </h1>
                <p className="text-base-content/40 mt-1 text-sm">
                    {counts.tous} réservation{counts.tous > 1 ? "s" : ""} au total
                </p>
            </div>

            {/* ERREUR */}
            {error && (
                <div className="bg-error/10 border border-error/20 rounded-xl px-4 py-3">
                    <p className="text-sm text-error">{error}</p>
                </div>
            )}

            {/* FILTRES */}
            <div className="flex gap-2 flex-wrap">
                {([
                    { value: "tous", label: "Toutes" },
                    { value: "en_attente", label: "En attente" },
                    { value: "confirmee", label: "Confirmées" },
                    { value: "declinee", label: "Déclinées" },
                    { value: "terminee", label: "Terminées" },
                ] as const).map((f) => (
                    <button
                        key={f.value}
                        onClick={() => setFiltre(f.value)}
                        className={`btn btn-sm rounded-full transition-all ${filtre === f.value ? "btn-primary" : "btn-ghost border border-base-300"
                            }`}
                    >
                        {f.label}
                        <span className={`ml-1 text-xs ${filtre === f.value ? "opacity-80" : "text-base-content/40"
                            }`}>
                            {counts[f.value]}
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
            ) : filtrees.length === 0 ? (
                <div className="bg-base-100 rounded-2xl border border-base-200 p-12 text-center space-y-3">
                    <p className="text-base-content/40 text-sm">
                        {filtre === "tous"
                            ? "Vous n'avez pas encore de réservation."
                            : `Aucune réservation ${filtre === "en_attente" ? "en attente"
                                : filtre === "confirmee" ? "confirmée"
                                    : filtre === "declinee" ? "déclinée"
                                        : filtre === "terminee" ? "terminée"
                                            : ""
                            }.`
                        }
                    </p>
                    {filtre === "tous" && (
                        <button
                            onClick={() => router.push("/passager/trajets")}
                            className="btn btn-primary btn-sm rounded-full"
                        >
                            Rechercher un trajet
                        </button>
                    )}
                </div>
            ) : (
                <div className="flex flex-col gap-3">
                    {filtrees.map((resa) => (
                        <div
                            key={resa.id}
                            className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden"
                        >
                            <div className="px-6 py-5">

                                {/* Itinéraire + prix */}
                                <div className="flex items-start justify-between gap-4 mb-3">
                                    <div className="flex-1 min-w-0">
                                        <div className="flex items-center gap-2 flex-wrap mb-1">
                                            <p className="font-semibold text-base-content">
                                                {resa.depart}
                                                <span className="text-base-content/25 mx-2 font-light">→</span>
                                                {resa.destination}
                                            </p>
                                            <span className={`badge badge-sm rounded-full font-medium ${statutBadge(resa.statut)}`}>
                                                {statutLabel(resa.statut)}
                                            </span>
                                        </div>
                                        <p className="text-xs text-base-content/40">
                                            Départ : {formatDate(resa.date_depart)}
                                        </p>
                                    </div>
                                    <div className="text-right shrink-0">
                                        <p className="text-lg font-bold text-primary">
                                            {Number(resa.prix_par_place).toLocaleString("fr-FR")} FCFA
                                        </p>
                                        <p className="text-xs text-base-content/40">par place</p>
                                    </div>
                                </div>

                                {/* Conducteur + date réservation */}
                                <div className="flex items-center justify-between pt-3 border-t border-base-200">
                                    <div className="flex items-center gap-2">
                                        <div className="w-7 h-7 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                                            <span className="text-xs font-bold text-primary">
                                                {resa.conducteur?.[0]?.toUpperCase()}
                                            </span>
                                        </div>
                                        <div>
                                            <p className="text-xs font-medium text-base-content">
                                                {resa.conducteur}
                                            </p>
                                            <p className="text-xs text-base-content/30">
                                                Réservé le {formatDate(resa.date_reservation)}
                                            </p>
                                        </div>
                                    </div>

                                    {/* Actions */}
                                    <div className="flex items-center gap-2">
                                        {/* Voir la réservation */}
                                        <button
                                            onClick={() => router.push(`/passager/reservations/${resa.id}`)}
                                            className="btn btn-ghost btn-xs rounded-xl border border-base-200 text-xs"
                                        >
                                            Voir
                                        </button>
                                        {/* Payer  seullment si le tajet est confirmé */}
                                        {resa.statut === "confirmee" && (
                                            <button
                                                onClick={() => router.push(`/passager/reservations/paiement/${resa.id}`)}
                                                className="btn btn-primary btn-xs rounded-xl text-xs"
                                            >
                                                Payer
                                            </button>
                                        )}

                                        {/* Suivre trajet — réservation confirmée */}
                                        {resa.statut === "confirmee" && (
                                            <button
                                                onClick={() => router.push(`/passager/suivi/${resa.trajet_id}`)}
                                                className="btn btn-outline btn-xs rounded-xl text-xs gap-1"
                                            >
                                                <svg xmlns="http://www.w3.org/2000/svg" className="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                                                </svg>
                                                Suivre
                                            </button>
                                        )}

                                        {/* Annuler — seulement si en attente */}
                                        {resa.statut === "en_attente" && (
                                            <button
                                                onClick={() => handleAnnuler(resa.id)}
                                                disabled={annulation === resa.id}
                                                className="btn btn-ghost btn-xs rounded-xl border border-error/30 text-error hover:bg-error/5 text-xs"
                                            >
                                                {annulation === resa.id
                                                    ? <span className="loading loading-spinner loading-xs" />
                                                    : "Annuler"
                                                }
                                            </button>
                                        )}
                                    </div>
                                </div>

                                {/* Message si déclinée */}
                                {resa.statut === "declinee" && (
                                    <div className="mt-3 bg-error/5 border border-error/10 rounded-xl px-4 py-2.5">
                                        <p className="text-xs text-error/70">
                                            Le conducteur a décliné votre demande. Vous pouvez rechercher un autre trajet.
                                        </p>
                                    </div>
                                )}

                                {/* Message si confirmée */}
                                {resa.statut === "confirmee" && (
                                    <div className="mt-3 bg-success/5 border border-success/10 rounded-xl px-4 py-2.5">
                                        <p className="text-xs text-success/70">
                                            Votre place est confirmée. Retrouvez le conducteur au point de départ.
                                        </p>
                                    </div>
                                )}

                                {/* Message si terminée */}
                                {resa.statut === "terminee" && (
                                    <div className="mt-3 bg-info/5 border border-info/10 rounded-xl px-4 py-2.5">
                                        <p className="text-xs text-info/70">
                                            Trajet terminé ! Merci d'avoir utilisé Kovoit.
                                        </p>
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