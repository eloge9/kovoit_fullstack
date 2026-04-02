"use client";

import { useState, useEffect } from "react";
import { useParams, useRouter } from "next/navigation";
import dynamic from "next/dynamic";
import { getTrajet, type Trajet } from "@/src/services/trajet.service";
import { reserver } from "@/src/services/reservation.service";
import { useAuth } from "@/src/hooks/useAuth";

const MapView = dynamic(() => import("@/components/MapView"), { ssr: false });

export default function DetailTrajetPage() {
    const { id } = useParams();
    const router = useRouter();
    const { user } = useAuth();

    const [trajet, setTrajet] = useState<Trajet | null>(null);
    const [loading, setLoading] = useState(true);
    const [reserving, setReserving] = useState(false);
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

    const handleReserver = async () => {
        if (!user) {
            router.push("/auth/connexion");
            return;
        }
        setReserving(true);
        setError(null);
        try {
            await reserver({ trajet_id: Number(id) });
            setSuccess(true);
        } catch (err: any) {
            setError(err.response?.data?.error || "Erreur lors de la réservation.");
        } finally {
            setReserving(false);
        }
    };

    const formatDate = (iso: string) =>
        new Date(iso).toLocaleDateString("fr-FR", {
            weekday: "long", day: "numeric", month: "long",
            year: "numeric", hour: "2-digit", minute: "2-digit",
        });

    const placesRestantes = trajet
        ? (trajet.places_restantes ?? trajet.places_disponibles)
        : 0;

    // ── Succès réservation ──────────────────────────────────────────────
    if (success) {
        return (
            <div className="max-w-lg mx-auto py-16 text-center space-y-4">
                <div className="w-16 h-16 rounded-full bg-success/10 flex items-center justify-center mx-auto">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                </div>
                <h2 className="text-xl font-bold text-base-content">Réservation envoyée</h2>
                <p className="text-base-content/50 text-sm">
                    Votre demande a été transmise au conducteur. Vous serez notifié dès qu'il confirme.
                </p>
                <div className="flex gap-3 justify-center pt-4">
                    <button
                        onClick={() => router.push("/passager/reservations")}
                        className="btn btn-primary rounded-full px-6"
                    >
                        Mes réservations
                    </button>
                    <button
                        onClick={() => router.push("/passager/trajets")}
                        className="btn btn-ghost rounded-full px-6 border border-base-300"
                    >
                        Retour à la recherche
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
                        Détail du trajet
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
                        { label: "Places restantes", value: `${placesRestantes} place${placesRestantes > 1 ? "s" : ""}` },
                        trajet.description ? { label: "Note du conducteur", value: trajet.description } : null,
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
                            {trajet.conducteur_nom?.[0]?.toUpperCase()}
                        </span>
                    </div>
                    <div>
                        <p className="font-semibold text-base-content">{trajet.conducteur_nom}</p>
                        <div className="flex items-center gap-1 mt-0.5">
                            <div className="flex gap-0.5">
                                {[1, 2, 3, 4, 5].map((s) => (
                                    <div key={s} className={`w-2.5 h-2.5 rounded-sm ${s <= Math.round(trajet.conducteur_note)
                                            ? "bg-warning" : "bg-base-300"
                                        }`} />
                                ))}
                            </div>
                            <span className="text-xs text-base-content/40 ml-1">
                                {trajet.conducteur_note} / 5
                            </span>
                        </div>
                    </div>
                </div>
            </div>

            {/* PRIX + RÉSERVATION */}
            <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
                <div className="flex items-center justify-between mb-4">
                    <div>
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                            Prix par place
                        </p>
                        <p className="text-3xl font-bold text-primary mt-1">
                            {Number(trajet.prix_par_place).toLocaleString("fr-FR")} FCFA
                        </p>
                        <p className="text-xs text-base-content/30 mt-0.5">
                            Recalculé selon le nombre de passagers confirmés
                        </p>
                    </div>
                    <div className="text-right">
                        <span className={`badge rounded-full font-medium ${placesRestantes > 0
                                ? "badge-success badge-outline"
                                : "badge-error badge-outline"
                            }`}>
                            {placesRestantes > 0 ? "Disponible" : "Complet"}
                        </span>
                    </div>
                </div>

                {/* Erreur */}
                {error && (
                    <div className="bg-error/10 border border-error/20 rounded-xl px-4 py-3 mb-4">
                        <p className="text-sm text-error">{error}</p>
                    </div>
                )}

                {/* Bouton réserver */}
                {placesRestantes > 0 ? (
                    <button
                        onClick={handleReserver}
                        disabled={reserving}
                        className="btn btn-primary w-full rounded-full"
                    >
                        {reserving
                            ? <span className="loading loading-spinner loading-sm" />
                            : "Réserver une place"
                        }
                    </button>
                ) : (
                    <button disabled className="btn btn-disabled w-full rounded-full">
                        Trajet complet
                    </button>
                )}

                {!user && (
                    <p className="text-xs text-base-content/40 text-center mt-3">
                        Vous serez redirigé vers la connexion
                    </p>
                )}
            </div>

        </div>
    );
}