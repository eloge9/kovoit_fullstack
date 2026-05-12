"use client";

import { useState, useEffect } from "react";
import { useParams, useRouter } from "next/navigation";
import dynamic from "next/dynamic";
import { api } from "@/src/services/api";
import { getTrajet, type Trajet } from "@/src/services/trajet.service";

const MapView = dynamic(() => import("@/components/MapView"), { ssr: false });

interface ReservationDetail {
    id: number;
    trajet_id: number;
    depart: string;
    destination: string;
    date_depart: string;
    conducteur: string;
    conducteur_note: number;
    prix_par_place: number;
    statut: "en_attente" | "confirmee" | "declinee" | "terminee";
    date_reservation: string;
    trajet_info?: Trajet;
}

export default function DetailReservationPage() {
    const { id } = useParams();
    const router = useRouter();

    const [reservation, setReservation] = useState<ReservationDetail | null>(null);
    const [trajet, setTrajet] = useState<Trajet | null>(null);
    const [loading, setLoading] = useState(true);
    const [annulation, setAnnulation] = useState(false);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        const fetchReservation = async () => {
            setLoading(true);
            try {
                // Récupérer les détails de la réservation
                const reservationData = await api(`/reservations/${id}/`);
                setReservation(reservationData);

                // Récupérer les détails du trajet associé
                try {
                    const trajetData = await getTrajet(reservationData.trajet_id);
                    setTrajet(trajetData);
                } catch (trajetErr: any) {
                    // Si le trajet n'est plus accessible (terminé/annulé), on garde quand même la réservation
                    console.warn("Trajet non accessible, mais réservation trouvée:", trajetErr);
                    setTrajet(null);
                }
            } catch (err: any) {
                // Gérer les différents cas d'erreur
                if (err.response?.status === 404) {
                    setError("Cette réservation n'existe pas ou a été supprimée.");
                } else if (err.response?.status === 403) {
                    setError("Vous n'avez pas l'autorisation de voir cette réservation.");
                } else {
                    setError(err.response?.data?.error || "Réservation introuvable.");
                }
            } finally {
                setLoading(false);
            }
        };

        if (id) fetchReservation();
    }, [id]);

    const handleAnnuler = async () => {
        if (!confirm("Confirmer l'annulation de cette réservation ?")) return;
        setAnnulation(true);
        setError(null);
        try {
            await api(`/reservations/${id}/annuler/`, "POST");
            router.push("/passager/reservations");
        } catch (err: any) {
            setError(err.response?.data?.error || "Erreur lors de l'annulation.");
            setAnnulation(false);
        }
    };

    const formatDate = (iso: string) =>
        new Date(iso).toLocaleDateString("fr-FR", {
            weekday: "long", day: "numeric", month: "long",
            year: "numeric", hour: "2-digit", minute: "2-digit",
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
            case "en_attente": return "En attente de confirmation";
            case "confirmee": return "Place confirmée";
            case "declinee": return "Demande déclinée";
            case "terminee": return "Trajet terminé";
            default: return statut;
        }
    };

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
    if (!reservation) {
        return (
            <div className="max-w-lg mx-auto py-16 text-center">
                <p className="text-base-content/40">{error || "Réservation introuvable."}</p>
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
                    <svg xmlns="http://www.w.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
                    </svg>
                </button>
                <div>
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                        Détail de la réservation
                    </p>
                    <h1 className="text-xl font-bold text-base-content tracking-tight">
                        {reservation.depart}
                        <span className="text-base-content/25 mx-2 font-light">→</span>
                        {reservation.destination}
                    </h1>
                </div>
            </div>

            {/* ERREUR */}
            {error && (
                <div className="bg-error/10 border border-error/20 rounded-xl px-4 py-3">
                    <p className="text-sm text-error">{error}</p>
                </div>
            )}

            {/* STATUT */}
            <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
                <div className="flex items-center justify-between">
                    <div>
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-2">
                            Statut de votre réservation
                        </p>
                        <div className="flex items-center gap-3">
                            <span className={`badge badge-md rounded-full font-medium ${statutBadge(reservation.statut)}`}>
                                {statutLabel(reservation.statut)}
                            </span>
                            <p className="text-sm text-base-content/60">
                                Réservée le {formatDate(reservation.date_reservation)}
                            </p>
                        </div>
                    </div>
                    <div className="text-right">
                        <p className="text-2xl font-bold text-primary">
                            {Number(reservation.prix_par_place).toLocaleString("fr-FR")} FCFA
                        </p>
                        <p className="text-xs text-base-content/40">par place</p>
                    </div>
                </div>

                {/* Messages selon statut */}
                {reservation.statut === "en_attente" && (
                    <div className="mt-4 bg-warning/5 border border-warning/10 rounded-xl px-4 py-3">
                        <p className="text-sm text-warning/70">
                            ⏳ Votre demande est en attente de confirmation par le conducteur. Vous serez notifié dès qu'il répondra.
                        </p>
                    </div>
                )}

                {reservation.statut === "confirmee" && (
                    <div className="mt-4 bg-success/5 border border-success/10 rounded-xl px-4 py-3">
                        <p className="text-sm text-success/70">
                            Votre place est confirmée ! Présentez-vous au point de départ à l'heure prévue.
                        </p>
                    </div>
                )}

                {reservation.statut === "declinee" && (
                    <div className="mt-4 bg-error/5 border border-error/10 rounded-xl px-4 py-3">
                        <p className="text-sm text-error/70">
                            Le conducteur a décliné votre demande. Vous pouvez rechercher un autre trajet.
                        </p>
                    </div>
                )}

                {reservation.statut === "terminee" && (
                    <div className="mt-4 bg-info/5 border border-info/10 rounded-xl px-4 py-3">
                        <p className="text-sm text-info/70">
                            🎉 Trajet terminé avec succès ! Merci d'avoir utilisé Kovoit pour votre voyage.
                        </p>
                    </div>
                )}
            </div>

            {/* CARTE */}
            {trajet && trajet.depart_lat && trajet.destination_lat ? (
                <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                    <div className="h-52">
                        <MapView
                            depart={{ nom: trajet.depart, lat: trajet.depart_lat, lng: trajet.depart_lng }}
                            destination={{ nom: trajet.destination, lat: trajet.destination_lat, lng: trajet.destination_lng }}
                        />
                    </div>
                </div>
            ) : (
                <div className="bg-base-100 rounded-2xl border border-base-200 p-8 text-center">
                    <div className="w-16 h-16 rounded-full bg-base-200 flex items-center justify-center mx-auto mb-4">
                        <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8 text-base-content/40" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7" />
                        </svg>
                    </div>
                    <p className="text-base-content/40 text-sm">
                        Carte du trajet non disponible
                    </p>
                    {reservation.statut === "terminee" && (
                        <p className="text-base-content/30 text-xs mt-2">
                            Le trajet est terminé
                        </p>
                    )}
                </div>
            )}

            {/* INFOS TRAJET */}
            <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                <div className="px-6 py-4 border-b border-base-200">
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                        Informations du trajet
                    </p>
                </div>
                <div className="divide-y divide-base-200">
                    {[
                        { label: "Départ", value: trajet ? trajet.depart : reservation.depart },
                        { label: "Arrivée", value: trajet ? trajet.destination : reservation.destination },
                        { label: "Date", value: trajet ? formatDate(trajet.date_heure_depart) : formatDate(reservation.date_depart) },
                        { label: "Distance", value: trajet?.distance_km ? `${trajet.distance_km} km` : "Non spécifiée" },
                        { label: "Statut du trajet", value: trajet ? (trajet.statut === 'termine' ? 'Terminé' : trajet.statut) : 'Terminé' },
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

            {/* CONDUCTEUR */}
            <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-4">
                    Conducteur
                </p>
                <div className="flex items-center gap-4">
                    <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                        <span className="text-lg font-bold text-primary">
                            {reservation.conducteur?.[0]?.toUpperCase()}
                        </span>
                    </div>
                    <div>
                        <p className="font-semibold text-base-content">{reservation.conducteur}</p>
                        <div className="flex items-center gap-1 mt-0.5">
                            <div className="flex gap-0.5">
                                {[1, 2, 3, 4, 5].map((s) => (
                                    <div key={s} className={`w-2.5 h-2.5 rounded-sm ${s <= Math.round(reservation.conducteur_note || 0)
                                        ? "bg-warning" : "bg-base-300"
                                        }`} />
                                ))}
                            </div>
                            <span className="text-xs text-base-content/40 ml-1">
                                {reservation.conducteur_note || 0} / 5
                            </span>
                        </div>
                    </div>
                </div>
            </div>

            {/* ACTIONS */}
            <div className="flex gap-3">
                {reservation.statut === "en_attente" && (
                    <>
                        <button
                            onClick={handleAnnuler}
                            disabled={annulation}
                            className="btn btn-error btn-outline rounded-full flex-1"
                        >
                            {annulation
                                ? <span className="loading loading-spinner loading-sm" />
                                : "Annuler la demande"
                            }
                        </button>
                        <button
                            onClick={() => router.push(`/passager/trajets/${reservation.trajet_id}`)}
                            className="btn btn-ghost rounded-full flex-1 border border-base-300"
                        >
                            Voir le trajet
                        </button>
                    </>
                )}

                {reservation.statut === "confirmee" && (
                    <>
                        <button
                            onClick={() => router.push(`/passager/reservations/paiement/${reservation.id}`)}
                            className="btn btn-primary rounded-full flex-1"
                        >
                            Payer la réservation
                        </button>
                        <button
                            onClick={() => router.push(`/passager/trajets/${reservation.trajet_id}`)}
                            className="btn btn-ghost rounded-full flex-1 border border-base-300"
                        >
                            Voir le trajet
                        </button>
                    </>
                )}

                {reservation.statut === "declinee" && (
                    <>
                        <button
                            onClick={() => router.push("/passager/trajets")}
                            className="btn btn-primary rounded-full flex-1"
                        >
                            Rechercher un autre trajet
                        </button>
                        <button
                            onClick={() => router.push(`/passager/trajets/${reservation.trajet_id}`)}
                            className="btn btn-ghost rounded-full flex-1 border border-base-300"
                        >
                            Voir le trajet
                        </button>
                    </>
                )}

                {reservation.statut === "terminee" && (
                    <>
                        <button
                            onClick={() => router.push("/passager/trajets")}
                            className="btn btn-primary rounded-full flex-1"
                        >
                            Réserver un autre trajet
                        </button>
                        <button
                            onClick={() => router.push(`/passager/trajets/${reservation.trajet_id}`)}
                            className="btn btn-ghost rounded-full flex-1 border border-base-300"
                        >
                            Voir le trajet
                        </button>
                    </>
                )}
            </div>

        </div>
    );
}
