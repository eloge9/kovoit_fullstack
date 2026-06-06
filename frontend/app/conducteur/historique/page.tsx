"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { mesTrajets, type Trajet } from "@/src/services/trajet.service";
import { useAuth } from "@/src/hooks/useAuth";

export default function HistoriqueConducteurPage() {
    const router = useRouter();
    const { user } = useAuth();

    const [trajets, setTrajets] = useState<Trajet[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [filter, setFilter] = useState<"tous" | "ouvert" | "en_cours" | "termine" | "annule">("tous");
    const [periodFilter, setPeriodFilter] = useState<"tous" | "aujourd'hui" | "hier" | "semaine" | "mois" | "mois_dernier" | "annee" | "personnalise">("tous");
    const [startDate, setStartDate] = useState<string>("");
    const [endDate, setEndDate] = useState<string>("");

    useEffect(() => {
        const fetchHistorique = async () => {
            setLoading(true);
            try {
                const data = await mesTrajets();
                setTrajets(data);
            } catch (err: any) {
                if (err.response?.status === 401) {
                    setError("Veuillez vous connecter pour voir votre historique.");
                } else {
                    setError("Impossible de charger votre historique de trajets.");
                }
            } finally {
                setLoading(false);
            }
        };

        fetchHistorique();
    }, []);

    const formatDate = (iso: string) =>
        new Date(iso).toLocaleDateString("fr-FR", {
            weekday: "long",
            day: "numeric",
            month: "long",
            year: "numeric",
            hour: "2-digit",
            minute: "2-digit",
        });

    const getStatutBadge = (statut: string) => {
        const statusConfig = {
            ouvert: { label: "Ouvert", class: "badge-success" },
            en_cours: { label: "En cours", class: "badge-info" },
            termine: { label: "Terminé", class: "badge-ghost" },
            annule: { label: "Annulé", class: "badge-error" },
        };

        const config = statusConfig[statut as keyof typeof statusConfig] || { label: statut, class: "badge-ghost" };
        return <span className={`badge badge-outline ${config.class} text-xs`}>{config.label}</span>;
    };

    const filteredTrajets = trajets.filter(trajet => {
        // Filtrer par statut
        if (filter !== "tous" && trajet.statut !== filter) {
            return false;
        }

        // Filtrer par période
        const trajetDate = new Date(trajet.created_at);
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        switch (periodFilter) {
            case "aujourd'hui":
                const todayEnd = new Date(today);
                todayEnd.setHours(23, 59, 59, 999);
                return trajetDate >= today && trajetDate <= todayEnd;

            case "hier":
                const yesterday = new Date(today);
                yesterday.setDate(yesterday.getDate() - 1);
                const yesterdayEnd = new Date(yesterday);
                yesterdayEnd.setHours(23, 59, 59, 999);
                return trajetDate >= yesterday && trajetDate <= yesterdayEnd;

            case "semaine":
                const weekStart = new Date(today);
                weekStart.setDate(today.getDate() - today.getDay());
                weekStart.setHours(0, 0, 0, 0);
                const weekEnd = new Date(weekStart);
                weekEnd.setDate(weekStart.getDate() + 6);
                weekEnd.setHours(23, 59, 59, 999);
                return trajetDate >= weekStart && trajetDate <= weekEnd;

            case "mois":
                const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);
                const monthEnd = new Date(today.getFullYear(), today.getMonth() + 1, 0);
                monthEnd.setHours(23, 59, 59, 999);
                return trajetDate >= monthStart && trajetDate <= monthEnd;

            case "mois_dernier":
                const lastMonthStart = new Date(today.getFullYear(), today.getMonth() - 1, 1);
                const lastMonthEnd = new Date(today.getFullYear(), today.getMonth(), 0);
                lastMonthEnd.setHours(23, 59, 59, 999);
                return trajetDate >= lastMonthStart && trajetDate <= lastMonthEnd;

            case "annee":
                const yearStart = new Date(today.getFullYear(), 0, 1);
                const yearEnd = new Date(today.getFullYear(), 11, 31);
                yearEnd.setHours(23, 59, 59, 999);
                return trajetDate >= yearStart && trajetDate <= yearEnd;

            case "personnalise":
                if (startDate && endDate) {
                    const start = new Date(startDate);
                    start.setHours(0, 0, 0, 0);
                    const end = new Date(endDate);
                    end.setHours(23, 59, 59, 999);
                    return trajetDate >= start && trajetDate <= end;
                }
                return true;

            default:
                return true;
        }
    });

    // Helper function pour vérifier si des filtres sont actifs
    const hasActiveFilters = () => {
        return filter !== "tous" || periodFilter !== "tous";
    };

    // Calculer les revenus totaux
    const calculerRevenusTotaux = () => {
        return filteredTrajets.reduce((total, trajet) => {
            const placesReservees = trajet.places_disponibles - (trajet.places_restantes ?? trajet.places_disponibles);
            return total + (placesReservees * Number(trajet.prix_par_place));
        }, 0);
    };

    // ── État de chargement ──────────────────────────────────────────────────
    if (loading) {
        return (
            <div className="space-y-4">
                <div className="h-8 bg-base-300 rounded w-1/3 animate-pulse" />
                <div className="h-12 bg-base-300 rounded-xl animate-pulse" />
                <div className="space-y-3">
                    {[1, 2, 3].map((i) => (
                        <div key={i} className="bg-base-100 rounded-xl border border-base-200 p-6 animate-pulse">
                            <div className="h-4 bg-base-300 rounded w-3/4 mb-3" />
                            <div className="h-3 bg-base-300 rounded w-1/2 mb-2" />
                            <div className="h-3 bg-base-300 rounded w-1/3" />
                        </div>
                    ))}
                </div>
            </div>
        );
    }

    // ── Erreur ────────────────────────────────────────────────────────────
    if (error) {
        return (
            <div className="max-w-lg mx-auto py-16 text-center space-y-4">
                <div className="bg-error/10 border border-error/20 rounded-xl px-4 py-3">
                    <p className="text-sm text-error">{error}</p>
                </div>
                {error?.includes("connectez") && (
                    <button
                        onClick={() => router.push("/auth/connexion")}
                        className="btn btn-primary rounded-full px-6"
                    >
                        Se connecter
                    </button>
                )}
            </div>
        );
    }

    return (
        <div className="space-y-6">
            {/* EN-TÊTE */}
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                <div>
                    <h1 className="text-2xl font-bold text-base-content tracking-tight">
                        Mon historique de trajets
                    </h1>
                    <p className="text-sm text-base-content/60 mt-1">
                        Consultez tous vos trajets publiés
                    </p>
                </div>
                <div className="text-right">
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                        Revenus totaux
                    </p>
                    <p className="text-2xl font-bold text-primary mt-1">
                        {calculerRevenusTotaux().toLocaleString("fr-FR")} FCFA
                    </p>
                </div>
            </div>

            {/* FILTRES */}
            <div className="bg-base-100 rounded-xl border border-base-200 p-4 space-y-4">
                {/* Double filtre */}
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
                    {/* Filtre par statut */}
                    <div>
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-2">Statut</p>
                        <div className="flex gap-2 flex-wrap">
                            {([
                                { value: "tous",     label: "Tous" },
                                { value: "ouvert",   label: "Ouverts" },
                                { value: "en_cours", label: "En cours" },
                                { value: "termine",  label: "Terminés" },
                                { value: "annule",   label: "Annulés" },
                            ] as const).map((option) => (
                                <button
                                    key={option.value}
                                    onClick={() => setFilter(option.value)}
                                    className={`btn btn-xs rounded-lg transition-all ${filter === option.value
                                        ? "btn-primary"
                                        : "btn-ghost border-base-300"
                                        }`}
                                >
                                    {option.label}
                                </button>
                            ))}
                        </div>
                    </div>

                    {/* Filtre par période */}
                    <div>
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-2">Période</p>
                        <div className="flex gap-2 flex-wrap">
                            {([
                                { value: "tous",         label: "Tous" },
                                { value: "aujourd'hui",  label: "Aujourd'hui" },
                                { value: "hier",         label: "Hier" },
                                { value: "semaine",      label: "Cette semaine" },
                                { value: "mois",         label: "Ce mois" },
                                { value: "mois_dernier", label: "Mois dernier" },
                                { value: "annee",        label: "Cette année" },
                                { value: "personnalise", label: "Personnalisé" },
                            ] as const).map((option) => (
                                <button
                                    key={option.value}
                                    onClick={() => setPeriodFilter(option.value)}
                                    className={`btn btn-xs rounded-lg transition-all ${periodFilter === option.value
                                        ? "btn-primary"
                                        : "btn-ghost border-base-300"
                                        }`}
                                >
                                    {option.label}
                                </button>
                            ))}
                        </div>
                    </div>
                </div>

                {/* Filtre personnalisé */}
                {periodFilter === "personnalise" && (
                    <div className="border-t border-base-200 pt-4">
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-2">Période personnalisée</p>
                        <div className="flex flex-col sm:flex-row gap-3">
                            <div className="flex-1">
                                <label className="label">
                                    <span className="label-text text-xs">Date de début</span>
                                </label>
                                <input
                                    type="date"
                                    value={startDate}
                                    onChange={(e) => setStartDate(e.target.value)}
                                    className="input input-bordered input-sm w-full rounded-lg"
                                />
                            </div>
                            <div className="flex-1">
                                <label className="label">
                                    <span className="label-text text-xs">Date de fin</span>
                                </label>
                                <input
                                    type="date"
                                    value={endDate}
                                    onChange={(e) => setEndDate(e.target.value)}
                                    className="input input-bordered input-sm w-full rounded-lg"
                                />
                            </div>
                        </div>
                    </div>
                )}

                {/* Actions de filtre */}
                {hasActiveFilters() && (
                    <div className="flex justify-center pt-2 border-t border-base-200">
                        <button
                            onClick={() => {
                                setFilter("tous");
                                setPeriodFilter("tous");
                                setStartDate("");
                                setEndDate("");
                            }}
                            className="btn btn-ghost btn-sm rounded-full"
                        >
                            Réinitialiser tous les filtres
                        </button>
                    </div>
                )}
            </div>

            {/* LISTE DES TRAJETS */}
            {filteredTrajets.length === 0 ? (
                <div className="bg-base-100 rounded-xl border border-base-200 p-12 text-center">
                    <div className="w-16 h-16 rounded-full bg-base-200 flex items-center justify-center mx-auto mb-4">
                        <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8 text-base-content/40" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                        </svg>
                    </div>
                    <h3 className="text-lg font-semibold text-base-content mb-2">
                        {hasActiveFilters() ? "Aucun trajet trouvé" : "Aucun trajet"}
                    </h3>
                    <p className="text-sm text-base-content/60 mb-4">
                        {hasActiveFilters()
                            ? "Essayez de modifier vos filtres"
                            : "Vous n'avez pas encore publié de trajet"
                        }
                    </p>
                    {hasActiveFilters() ? (
                        <div className="flex gap-3 justify-center">
                            <button
                                onClick={() => {
                                    setFilter("tous");
                                    setPeriodFilter("tous");
                                    setStartDate("");
                                    setEndDate("");
                                }}
                                className="btn btn-ghost btn-sm rounded-full"
                            >
                                Réinitialiser les filtres
                            </button>
                        </div>
                    ) : (
                        <Link href="/conducteur/trajets/create" className="btn btn-primary rounded-full px-6">
                            Créer un trajet
                        </Link>
                    )}
                </div>
            ) : (
                <div className="space-y-3">
                    {filteredTrajets.map((trajet) => {
                        const placesReservees = trajet.places_disponibles - (trajet.places_restantes ?? trajet.places_disponibles);
                        const revenuTrajet = placesReservees * Number(trajet.prix_par_place);

                        return (
                            <div
                                key={trajet.id}
                                className="bg-base-100 rounded-xl border border-base-200 overflow-hidden hover:shadow-lg transition-all"
                            >
                                <div className="p-6">
                                    <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4">
                                        {/* Infos principales */}
                                        <div className="flex-1 space-y-3">
                                            <div className="space-y-3">
                                                <div className="flex items-center gap-3 flex-wrap">
                                                    <div className="flex items-center gap-3">
                                                        <h3 className="font-semibold text-base-content">
                                                            {trajet.depart}
                                                        </h3>
                                                        <span className="text-base-content/25">→</span>
                                                        <h3 className="font-semibold text-base-content">
                                                            {trajet.destination}
                                                        </h3>
                                                    </div>
                                                    {getStatutBadge(trajet.statut)}
                                                </div>
                                                <div className="flex items-center gap-4 text-sm text-base-content/60">
                                                    <span>{formatDate(trajet.date_heure_depart)}</span>
                                                    <span>•</span>
                                                    <span>{trajet.distance_km ? `${trajet.distance_km} km` : "Distance non précisée"}</span>
                                                </div>
                                            </div>

                                            {/* Détails additionnels */}
                                            <div className="flex flex-wrap gap-4 text-sm">
                                                <div className="flex items-center gap-2">
                                                    <span className="text-base-content/40">Places:</span>
                                                    <span className="font-medium">
                                                        {placesReservees} / {trajet.places_disponibles}
                                                    </span>
                                                </div>
                                                <div className="flex items-center gap-2">
                                                    <span className="text-base-content/40">Prix/place:</span>
                                                    <span className="font-medium text-primary">
                                                        {Number(trajet.prix_par_place).toLocaleString("fr-FR")} FCFA
                                                    </span>
                                                </div>
                                                <div className="flex items-center gap-2">
                                                    <span className="text-base-content/40">Revenu:</span>
                                                    <span className="font-medium text-success">
                                                        {revenuTrajet.toLocaleString("fr-FR")} FCFA
                                                    </span>
                                                </div>
                                                {trajet.vehicule_info && (
                                                    <div className="flex items-center gap-2">
                                                        <span className="text-base-content/40">Véhicule:</span>
                                                        <span className="font-medium">
                                                            {trajet.vehicule_info.marque} {trajet.vehicule_info.modele}
                                                        </span>
                                                    </div>
                                                )}
                                            </div>
                                        </div>

                                        {/* Actions */}
                                        <div className="flex flex-col gap-2 lg:ml-4">
                                            <Link
                                                href={`/conducteur/trajets/${trajet.id}`}
                                                className="btn btn-outline btn-sm rounded-full"
                                            >
                                                Voir détails
                                            </Link>

                                            {trajet.statut === "ouvert" && (
                                                <>
                                                    <Link
                                                        href={`/conducteur/trajets/edit/${trajet.id}`}
                                                        className="btn btn-ghost btn-sm rounded-full"
                                                    >
                                                        Modifier
                                                    </Link>
                                                    <Link
                                                        href={`/conducteur/trajet/${trajet.id}`}
                                                        className="btn btn-primary btn-sm rounded-full"
                                                    >
                                                        Gérer
                                                    </Link>
                                                </>
                                            )}

                                            {trajet.statut === "en_cours" && (
                                                <div className="text-center py-2 space-y-1">
                                                    <div className="flex items-center justify-center gap-2 text-info">
                                                        <span className="loading loading-spinner loading-sm"></span>
                                                        <span className="font-medium text-xs">Trajet en cours</span>
                                                    </div>
                                                </div>
                                            )}
                                        </div>
                                    </div>
                                </div>
                            </div>
                        );
                    })}
                </div>
            )}

            {/* Statistiques */}
            {trajets.length > 0 && (
                <div className="bg-base-100 rounded-xl border border-base-200 p-6">
                    <h3 className="text-lg font-semibold text-base-content mb-4">Statistiques</h3>
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                        {[
                            { label: "Ouverts", value: trajets.filter(t => t.statut === "ouvert").length, color: "text-success" },
                            { label: "En cours", value: trajets.filter(t => t.statut === "en_cours").length, color: "text-info" },
                            { label: "Terminés", value: trajets.filter(t => t.statut === "termine").length, color: "text-base-content" },
                            { label: "Annulés", value: trajets.filter(t => t.statut === "annule").length, color: "text-error" },
                        ].map((stat) => (
                            <div key={stat.label} className="text-center">
                                <p className={`text-2xl font-bold ${stat.color}`}>{stat.value}</p>
                                <p className="text-xs text-base-content/60 mt-1">{stat.label}</p>
                            </div>
                        ))}
                    </div>
                </div>
            )}
        </div>
    );
}