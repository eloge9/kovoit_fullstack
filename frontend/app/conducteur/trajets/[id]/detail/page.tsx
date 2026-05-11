"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import {
    ArrowLeft,
    MapPin,
    Users,
    Clock,
    Calendar,
    Phone,
    MessageCircle,
    Navigation,
    AlertTriangle,
    CheckCircle
} from "lucide-react";
import trajetApi from "@/libs/trajet-api";
import { confirmerEspeces, getStatutPaiementReservation, type PaiementReservationResponse } from "@/src/services/paiement.service";

// Types définis localement pour éviter les erreurs d'import
// Interface pour les réservations (basée sur le serializer backend)
interface Reservation {
    id: number;
    trajet_id: number;
    depart: string;
    destination: string;
    date_depart: string;
    prix_par_place: number;
    conducteur: string;
    passager_nom: string;
    passager_telephone?: string;
    passager_note?: string;
    statut: "confirmee" | "en_attente" | "annulee";
    date_reservation: string;
}

interface Trajet {
    id: number;
    depart: string;
    destination: string;
    date_heure_depart: string;
    distance_km?: number;
    prix_par_place: number;
    places_disponibles: number;
    statut: "ouvert" | "en_cours" | "termine" | "annule";
    description?: string;
    reservations?: Reservation[];
}

export default function DetailTrajetPage() {
    const { id } = useParams();
    const router = useRouter();
    const [trajet, setTrajet] = useState<Trajet | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [confirming, setConfirming] = useState<number | null>(null);
    const [paiementsStatus, setPaiementsStatus] = useState<{ [key: number]: PaiementReservationResponse }>({});
    const [reservations, setReservations] = useState<Reservation[]>([]);

    useEffect(() => {
        loadTrajet();
        loadReservations();
    }, []);

    const loadTrajet = async () => {
        try {
            const trajetData = await trajetApi.getTrajet(String(id));
            setTrajet(trajetData);

            // Vérifier si le trajet est bien en cours
            if (trajetData.statut !== "en_cours") {
                setError("Cette page n'est accessible que pour les trajets en cours");
            }
        } catch (err) {
            setError("Impossible de charger les détails du trajet");
        }
    };

    const loadReservations = async () => {
        try {
            console.log('Chargement des réservations pour le trajet:', Number(id));
            const reservationsData = await trajetApi.getReservationsTrajet(String(id));
            console.log('Réservations reçues:', reservationsData);
            setReservations(reservationsData);

            // Charger les statuts de paiement pour chaque réservation
            for (const reservation of reservationsData) {
                try {
                    const paiementStatus = await getStatutPaiementReservation(reservation.id);
                    setPaiementsStatus(prev => ({
                        ...prev,
                        [reservation.id]: paiementStatus
                    }));
                } catch {
                    // Pas de paiement existant
                }
            }
        } catch (err) {
            console.error("Erreur lors du chargement des réservations:", err);
        } finally {
            setLoading(false);
        }
    };

    const handleConfirmerPaiement = async (reservationId: number) => {
        setConfirming(reservationId);
        try {
            await confirmerEspeces(reservationId);
            // Mettre à jour le statut localement
            setPaiementsStatus(prev => ({
                ...prev,
                [reservationId]: {
                    ...prev[reservationId],
                    statut: 'CONFIRME',
                    date_confirmation: new Date().toISOString()
                }
            }));
        } catch (err: any) {
            setError(err.response?.data?.error || "Erreur lors de la confirmation du paiement");
        } finally {
            setConfirming(null);
        }
    };

    const formatDate = (dateString: string) => {
        return new Date(dateString).toLocaleDateString("fr-FR", {
            weekday: "long",
            day: "numeric",
            month: "long",
            year: "numeric",
            hour: "2-digit",
            minute: "2-digit"
        });
    };

    const handleTerminerTrajet = async () => {
        if (!confirm("Êtes-vous sûr de vouloir terminer ce trajet ?")) return;

        try {
            await trajetApi.terminerTrajet(String(id));
            router.push("/conducteur/trajets");
        } catch (err) {
            setError("Erreur lors de la terminaison du trajet");
        }
    };

    if (loading) {
        return (
            <div className="min-h-screen flex items-center justify-center">
                <div className="loading loading-spinner loading-lg"></div>
            </div>
        );
    }

    if (error || !trajet) {
        return (
            <div className="min-h-screen flex items-center justify-center">
                <div className="text-center">
                    <AlertTriangle className="w-16 h-16 text-error mx-auto mb-4" />
                    <p className="text-error mb-4">{error || "Trajet non trouvé"}</p>
                    <Link href="/conducteur/trajets" className="btn btn-primary">
                        Retour à mes trajets
                    </Link>
                </div>
            </div>
        );
    }

    const passagersConfirmes = reservations.filter((r: Reservation) => r.statut === "confirmee");
    console.log('Passagers confirmés:', passagersConfirmes);
    console.log('Statuts des réservations:', reservations.map(r => r.statut));

    return (
        <div className="min-h-screen bg-base-200">
            <div className="container mx-auto py-8 space-y-8">
                {/* EN-TÊTE */}
                <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4 pb-6 border-b border-base-300">
                    <div className="flex items-center gap-4">
                        <Link
                            href="/conducteur/trajets"
                            className="btn btn-ghost btn-circle btn-sm"
                        >
                            <ArrowLeft className="w-4 h-4" />
                        </Link>
                        <div>
                            <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">
                                Conducteur
                            </p>
                            <h1 className="text-2xl font-bold text-base-content tracking-tight">
                                Détails du trajet
                            </h1>
                            <p className="text-base-content/40 mt-1 text-sm">
                                Trajet #{trajet?.id}
                            </p>
                        </div>
                    </div>
                </div>

                {/* Carte et informations principales */}
                <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                    {/* Carte */}
                    <div className="lg:col-span-2">
                        <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                            <div className="px-6 py-4 border-b border-base-200">
                                <h2 className="font-semibold text-base-content flex items-center gap-2">
                                    <Navigation className="w-4 h-4" />
                                    Itinéraire
                                </h2>
                            </div>
                            <div className="h-96 bg-base-200 flex items-center justify-center">
                                <div className="text-center">
                                    <Navigation className="w-12 h-12 text-base-content/40 mx-auto mb-2" />
                                    <p className="text-base-content/60">
                                        Carte interactive du trajet
                                    </p>
                                    <p className="text-xs text-base-content/40 mt-2">
                                        {trajet?.depart} → {trajet?.destination}
                                    </p>
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Informations du trajet */}
                    <div className="space-y-4">
                        {/* Statut et actions */}
                        <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
                            <div className="space-y-3">
                                <div className="flex items-center justify-between">
                                    <span className="text-sm font-medium text-base-content">Statut</span>
                                    <span className={`badge badge-sm rounded-full font-medium ${trajet.statut === "en_cours" ? "badge-info badge-outline" : "badge-ghost"}`}>
                                        {trajet.statut}
                                    </span>
                                </div>
                                <div className="flex items-center justify-between">
                                    <span className="text-sm font-medium text-base-content">Places</span>
                                    <span className="text-sm">
                                        {passagersConfirmes.length}/{trajet.places_disponibles}
                                    </span>
                                </div>
                                {trajet.statut === "en_cours" && (
                                    <button
                                        onClick={handleTerminerTrajet}
                                        className="btn btn-warning btn-sm w-full"
                                    >
                                        Terminer le trajet
                                    </button>
                                )}
                            </div>
                        </div>

                        {/* Itinéraire */}
                        <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
                            <h3 className="font-semibold text-base-content mb-3 flex items-center gap-2">
                                <MapPin className="w-4 h-4" />
                                Itinéraire
                            </h3>
                            <div className="space-y-3">
                                <div>
                                    <p className="text-xs text-base-content/40 uppercase tracking-wide">Départ</p>
                                    <p className="text-sm font-medium text-base-content">
                                        {trajet.depart}
                                    </p>
                                    <p className="text-xs text-base-content/40">
                                        {formatDate(trajet.date_heure_depart)}
                                    </p>
                                </div>
                                <div className="border-l-2 border-base-300 h-4 ml-2"></div>
                                <div>
                                    <p className="text-xs text-base-content/40 uppercase tracking-wide">Destination</p>
                                    <p className="text-sm font-medium text-base-content">
                                        {trajet.destination}
                                    </p>
                                </div>
                                {trajet.distance_km && (
                                    <div className="pt-2 border-t border-base-300">
                                        <p className="text-xs text-base-content/40 uppercase tracking-wide">Distance</p>
                                        <p className="text-sm font-medium text-base-content">
                                            {trajet.distance_km} km
                                        </p>
                                    </div>
                                )}
                            </div>
                        </div>

                        {/* Prix */}
                        <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
                            <h3 className="font-semibold text-base-content mb-2">Prix</h3>
                            <p className="text-2xl font-bold text-primary">
                                {Number(trajet.prix_par_place).toLocaleString("fr-FR")} FCFA
                            </p>
                            <p className="text-xs text-base-content/40">par place</p>
                        </div>
                    </div>
                </div>

                {/* Passagers */}
                <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                    <div className="px-6 py-4 border-b border-base-200">
                        <h2 className="font-semibold text-base-content flex items-center gap-2">
                            <Users className="w-4 h-4" />
                            Passagers ({passagersConfirmes.length})
                        </h2>
                    </div>
                    <div className="p-4">
                        {passagersConfirmes.length === 0 ? (
                            <p className="text-center text-base-content/60 py-8">
                                Aucun passager pour ce trajet
                            </p>
                        ) : (
                            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                                {passagersConfirmes.map((reservation: Reservation) => (
                                    <div
                                        key={reservation.id}
                                        className="border border-base-200 rounded-xl p-3 space-y-2"
                                    >
                                        <div className="flex items-center gap-3">
                                            <div className="w-10 h-10 bg-primary/10 rounded-full flex items-center justify-center">
                                                <Users className="w-5 h-5 text-primary" />
                                            </div>
                                            <div className="flex-1 min-w-0">
                                                <p className="text-sm font-medium text-base-content truncate">
                                                    {reservation.passager_nom || "Passager"}
                                                </p>
                                                <p className="text-xs text-base-content/60">
                                                    {reservation.passager_telephone || "Non renseigné"}
                                                </p>
                                            </div>
                                        </div>

                                        {/* Statut de paiement */}
                                        {paiementsStatus[reservation.id] && (
                                            <div className="mt-2 p-2 rounded-lg border border-base-200 bg-base-50">
                                                <p className="text-xs text-base-content/40 mb-1">Paiement</p>
                                                {paiementsStatus[reservation.id].statut === 'EN_ATTENTE_CONFIRMATION' ? (
                                                    <div className="space-y-2">
                                                        <div className="flex items-center gap-1 text-xs text-warning">
                                                            <div className="w-2 h-2 rounded-full bg-warning animate-pulse" />
                                                            <span>En attente de confirmation</span>
                                                        </div>
                                                        <button
                                                            onClick={() => handleConfirmerPaiement(reservation.id)}
                                                            disabled={confirming === reservation.id}
                                                            className="btn btn-primary btn-xs w-full"
                                                        >
                                                            {confirming === reservation.id ? (
                                                                <span className="loading loading-spinner loading-xs" />
                                                            ) : (
                                                                "👉 Confirmer réception"
                                                            )}
                                                        </button>
                                                    </div>
                                                ) : paiementsStatus[reservation.id].statut === 'CONFIRME' ? (
                                                    <div className="flex items-center gap-1 text-xs text-success">
                                                        <CheckCircle className="w-3 h-3" />
                                                        <span>Paiement confirmé</span>
                                                    </div>
                                                ) : (
                                                    <div className="text-xs text-base-content/60">
                                                        {paiementsStatus[reservation.id].statut}
                                                    </div>
                                                )}
                                            </div>
                                        )}

                                        <div className="flex gap-2">
                                            <button className="btn btn-ghost btn-xs flex-1">
                                                <Phone className="w-3 h-3" />
                                            </button>
                                            <button className="btn btn-ghost btn-xs flex-1">
                                                <MessageCircle className="w-3 h-3" />
                                            </button>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        )}
                    </div>
                </div>

                {/* Description */}
                {trajet.description && (
                    <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
                        <h3 className="font-semibold text-base-content mb-2">Description</h3>
                        <p className="text-sm text-base-content/80">
                            {trajet.description}
                        </p>
                    </div>
                )}

                {/* Notes importantes */}
                <div className="bg-warning/10 border border-warning/20 rounded-2xl p-6">
                    <h3 className="font-semibold text-warning mb-2 flex items-center gap-2">
                        <AlertTriangle className="w-4 h-4" />
                        Points d'attention
                    </h3>
                    <ul className="text-sm text-base-content/80 space-y-1">
                        <li>• Respectez les horaires prévus</li>
                        <li>• Vérifiez que tous les passagers sont bien présents</li>
                        <li>• Conduisez prudemment et respectez le code de la route</li>
                        <li>• Terminez le trajet uniquement à l'arrivée</li>
                    </ul>
                </div>
            </div>
        </div>
    );
}
