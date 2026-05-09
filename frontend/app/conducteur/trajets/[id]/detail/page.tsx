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

// Types définis localement pour éviter les erreurs d'import
interface Reservation {
    id: number;
    passager_nom?: string;
    passager_telephone?: string;
    statut: "confirmé" | "en_attente" | "annulé";
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
    const params = useParams();
    const router = useRouter();
    const trajetId = params.id as string;

    const [trajet, setTrajet] = useState<Trajet | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        loadTrajet();
    }, []);

    const loadTrajet = async () => {
        try {
            const trajetData = await trajetApi.getTrajet(trajetId);
            setTrajet(trajetData);

            // Vérifier si le trajet est bien en cours
            if (trajetData.statut !== "en_cours") {
                setError("Cette page n'est accessible que pour les trajets en cours");
            }
        } catch (err) {
            setError("Impossible de charger les détails du trajet");
        } finally {
            setLoading(false);
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
            await trajetApi.terminerTrajet(trajetId);
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

    const reservations = trajet.reservations || [];
    const passagersConfirmes = reservations.filter((r: Reservation) => r.statut === "confirmé");

    return (
        <div className="min-h-screen bg-base-200">
            {/* En-tête */}
            <div className="bg-base-100 border-b border-base-300 sticky top-0 z-40">
                <div className="max-w-6xl mx-auto px-4 py-4">
                    <div className="flex items-center justify-between">
                        <div className="flex items-center gap-4">
                            <Link
                                href="/conducteur/trajets"
                                className="btn btn-ghost btn-circle btn-sm"
                            >
                                <ArrowLeft className="w-4 h-4" />
                            </Link>
                            <div>
                                <h1 className="text-lg font-bold text-base-content">
                                    Détails du trajet en cours
                                </h1>
                                <p className="text-xs text-base-content/60">
                                    Trajet #{trajet.id}
                                </p>
                            </div>
                        </div>
                        <div className="flex items-center gap-2">
                            <span className="badge badge-info badge-outline">
                                En cours
                            </span>
                        </div>
                    </div>
                </div>
            </div>

            <div className="max-w-6xl mx-auto px-4 py-6 space-y-6">
                {/* Carte et informations principales */}
                <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                    {/* Carte */}
                    <div className="lg:col-span-2">
                        <div className="bg-base-100 rounded-2xl border border-base-300 overflow-hidden">
                            <div className="p-4 border-b border-base-300">
                                <h2 className="font-semibold text-base-content flex items-center gap-2">
                                    <Navigation className="w-4 h-4" />
                                    Itinéraire en temps réel
                                </h2>
                            </div>
                            <div className="h-96 bg-base-200 flex items-center justify-center">
                                <p className="text-base-content/60">
                                    Carte interactive du trajet
                                </p>
                            </div>
                        </div>
                    </div>

                    {/* Informations du trajet */}
                    <div className="space-y-4">
                        {/* Statut et actions */}
                        <div className="bg-base-100 rounded-2xl border border-base-300 p-4">
                            <div className="space-y-3">
                                <div className="flex items-center justify-between">
                                    <span className="text-sm font-medium text-base-content">Statut</span>
                                    <span className="badge badge-info badge-outline">En cours</span>
                                </div>
                                <div className="flex items-center justify-between">
                                    <span className="text-sm font-medium text-base-content">Places</span>
                                    <span className="text-sm">
                                        {passagersConfirmes.length}/{trajet.places_disponibles}
                                    </span>
                                </div>
                                <button
                                    onClick={handleTerminerTrajet}
                                    className="btn btn-warning btn-sm w-full"
                                >
                                    Terminer le trajet
                                </button>
                            </div>
                        </div>

                        {/* Itinéraire */}
                        <div className="bg-base-100 rounded-2xl border border-base-300 p-4">
                            <h3 className="font-semibold text-base-content mb-3 flex items-center gap-2">
                                <MapPin className="w-4 h-4" />
                                Itinéraire
                            </h3>
                            <div className="space-y-3">
                                <div>
                                    <p className="text-xs text-base-content/60">Départ</p>
                                    <p className="text-sm font-medium text-base-content">
                                        {trajet.depart}
                                    </p>
                                    <p className="text-xs text-base-content/40">
                                        {formatDate(trajet.date_heure_depart)}
                                    </p>
                                </div>
                                <div className="border-l-2 border-base-300 h-4 ml-2"></div>
                                <div>
                                    <p className="text-xs text-base-content/60">Destination</p>
                                    <p className="text-sm font-medium text-base-content">
                                        {trajet.destination}
                                    </p>
                                </div>
                                {trajet.distance_km && (
                                    <div className="pt-2 border-t border-base-300">
                                        <p className="text-xs text-base-content/60">Distance</p>
                                        <p className="text-sm font-medium text-base-content">
                                            {trajet.distance_km} km
                                        </p>
                                    </div>
                                )}
                            </div>
                        </div>

                        {/* Prix */}
                        <div className="bg-base-100 rounded-2xl border border-base-300 p-4">
                            <h3 className="font-semibold text-base-content mb-2">Prix</h3>
                            <p className="text-2xl font-bold text-primary">
                                {Number(trajet.prix_par_place).toLocaleString("fr-FR")} FCFA
                            </p>
                            <p className="text-xs text-base-content/60">par place</p>
                        </div>
                    </div>
                </div>

                {/* Passagers */}
                <div className="bg-base-100 rounded-2xl border border-base-300 overflow-hidden">
                    <div className="p-4 border-b border-base-300">
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
                                        className="border border-base-300 rounded-xl p-3 space-y-2"
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
                    <div className="bg-base-100 rounded-2xl border border-base-300 p-4">
                        <h3 className="font-semibold text-base-content mb-2">Description</h3>
                        <p className="text-sm text-base-content/80">
                            {trajet.description}
                        </p>
                    </div>
                )}

                {/* Notes importantes */}
                <div className="bg-warning/10 border border-warning/20 rounded-2xl p-4">
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
