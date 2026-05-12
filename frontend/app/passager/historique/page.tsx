"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { historiqueReservations, type Reservation } from "@/src/services/reservation.service";
import { useAuth } from "@/src/hooks/useAuth";

export default function HistoriquePage() {
    const router = useRouter();
    const { user } = useAuth();

    const [reservations, setReservations] = useState<Reservation[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [filter, setFilter] = useState<string>("tous");
    const [periodFilter, setPeriodFilter] = useState<string>("tous");
    const [startDate, setStartDate] = useState<string>("");
    const [endDate, setEndDate] = useState<string>("");

    useEffect(() => {
        const fetchHistorique = async () => {
            setLoading(true);
            try {
                const data = await historiqueReservations();
                setReservations(data);
            } catch (err: any) {
                console.error("Error loading history:", err);
                if (err.response?.status === 401) {
                    setError("Veuillez vous connecter pour voir votre historique.");
                } else {
                    setError("Impossible de charger votre historique de réservations.");
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
            confirmee: { label: "Confirmée", class: "badge-success" },
            en_attente: { label: "En attente", class: "badge-warning" },
            declinee: { label: "Déclinée", class: "badge-error" },
            annulee: { label: "Annulée", class: "badge-error" },
            terminee: { label: "Terminée", class: "badge-info" },
        };

        const config = statusConfig[statut as keyof typeof statusConfig] || { label: statut, class: "badge-ghost" };
        return <span className={`badge badge-outline ${config.class} text-xs`}>{config.label}</span>;
    };

    const filteredReservations = reservations.filter(reservation => {
        // Filtrer par statut
        if (filter !== "tous" && reservation.statut !== filter) {
            return false;
        }

        // Filtrer par période
        const reservationDate = new Date(reservation.date_reservation);
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        switch (periodFilter) {
            case "aujourd'hui":
                const todayEnd = new Date(today);
                todayEnd.setHours(23, 59, 59, 999);
                return reservationDate >= today && reservationDate <= todayEnd;

            case "hier":
                const yesterday = new Date(today);
                yesterday.setDate(yesterday.getDate() - 1);
                const yesterdayEnd = new Date(yesterday);
                yesterdayEnd.setHours(23, 59, 59, 999);
                return reservationDate >= yesterday && reservationDate <= yesterdayEnd;

            case "semaine":
                const weekStart = new Date(today);
                weekStart.setDate(today.getDate() - today.getDay());
                weekStart.setHours(0, 0, 0, 0);
                const weekEnd = new Date(weekStart);
                weekEnd.setDate(weekStart.getDate() + 6);
                weekEnd.setHours(23, 59, 59, 999);
                return reservationDate >= weekStart && reservationDate <= weekEnd;

            case "mois":
                const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);
                const monthEnd = new Date(today.getFullYear(), today.getMonth() + 1, 0);
                monthEnd.setHours(23, 59, 59, 999);
                return reservationDate >= monthStart && reservationDate <= monthEnd;

            case "mois_dernier":
                const lastMonthStart = new Date(today.getFullYear(), today.getMonth() - 1, 1);
                const lastMonthEnd = new Date(today.getFullYear(), today.getMonth(), 0);
                lastMonthEnd.setHours(23, 59, 59, 999);
                return reservationDate >= lastMonthStart && reservationDate <= lastMonthEnd;

            case "annee":
                const yearStart = new Date(today.getFullYear(), 0, 1);
                const yearEnd = new Date(today.getFullYear(), 11, 31);
                yearEnd.setHours(23, 59, 59, 999);
                return reservationDate >= yearStart && reservationDate <= yearEnd;

            case "personnalise":
                if (startDate && endDate) {
                    const start = new Date(startDate);
                    start.setHours(0, 0, 0, 0);
                    const end = new Date(endDate);
                    end.setHours(23, 59, 59, 999);
                    return reservationDate >= start && reservationDate <= end;
                }
                return true;

            default:
                return true;
        }
    });

    // Helper function pour vérifier si des filtres sont actifs
    const hasActiveFilters = () => {
        return filter !== "tous" || periodFilter !== "tous" || (periodFilter === "personnalise" && (startDate || endDate));
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
                        Mon historique
                    </h1>
                    <p className="text-sm text-base-content/60 mt-1">
                        Consultez toutes vos réservations passées
                    </p>
                </div>
                <div className="text-right">
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                        Total des réservations
                    </p>
                    <p className="text-2xl font-bold text-primary mt-1">
                        {reservations.length}
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
                            {[
                                { value: "tous", label: "Tous" },
                                { value: "confirmee", label: "Confirmées" },
                                { value: "en_attente", label: "En attente" },
                                { value: "terminee", label: "Terminées" },
                                { value: "declinee", label: "Déclinées" },
                            ].map((option) => (
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
                            {[
                                { value: "tous", label: "Tous" },
                                { value: "aujourd'hui", label: "Aujourd'hui" },
                                { value: "hier", label: "Hier" },
                                { value: "semaine", label: "Cette semaine" },
                                { value: "mois", label: "Ce mois" },
                                { value: "mois_dernier", label: "Mois dernier" },
                                { value: "annee", label: "Cette année" },
                                { value: "personnalise", label: "Personnalisé" },
                            ].map((option) => (
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

            {/* LISTE DES RÉSERVATIONS */}
            {filteredReservations.length === 0 ? (
                <div className="bg-base-100 rounded-xl border border-base-200 p-12 text-center">
                    <div className="w-16 h-16 rounded-full bg-base-200 flex items-center justify-center mx-auto mb-4">
                        <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8 text-base-content/40" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                        </svg>
                    </div>
                    <h3 className="text-lg font-semibold text-base-content mb-2">
                        {hasActiveFilters() ? "Aucune réservation trouvée" : "Aucune réservation"}
                    </h3>
                    <p className="text-sm text-base-content/60 mb-4">
                        {hasActiveFilters()
                            ? "Essayez de modifier vos filtres"
                            : "Vous n'avez pas encore effectué de réservation"
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
                        <Link href="/passager/trajets" className="btn btn-primary rounded-full px-6">
                            Rechercher un trajet
                        </Link>
                    )}
                </div>
            ) : (
                <div className="space-y-3">
                    {filteredReservations.map((reservation) => (
                        <div
                            key={reservation.id}
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
                                                        {reservation.depart}
                                                    </h3>
                                                    <span className="text-base-content/25">→</span>
                                                    <h3 className="font-semibold text-base-content">
                                                        {reservation.destination}
                                                    </h3>
                                                </div>
                                                {getStatutBadge(reservation.statut)}
                                            </div>
                                            <div className="flex items-center gap-4 text-sm text-base-content/60">
                                                <span>{formatDate(reservation.date_reservation)}</span>
                                                <span>•</span>
                                                <span>{reservation.conducteur}</span>
                                            </div>
                                        </div>

                                        {/* Détails additionnels */}
                                        <div className="flex flex-wrap gap-4 text-sm">
                                            <div className="flex items-center gap-2">
                                                <span className="text-base-content/40">Date de départ:</span>
                                                <span className="font-medium">
                                                    {new Date(reservation.date_depart).toLocaleDateString("fr-FR", {
                                                        day: "numeric",
                                                        month: "short",
                                                        hour: "2-digit",
                                                        minute: "2-digit",
                                                    })}
                                                </span>
                                            </div>
                                            <div className="flex items-center gap-2">
                                                <span className="text-base-content/40">Prix:</span>
                                                <span className="font-medium text-primary">
                                                    {Number(reservation.prix_par_place).toLocaleString("fr-FR")} FCFA
                                                </span>
                                            </div>
                                            {reservation.passager_note && (
                                                <div className="flex items-center gap-2">
                                                    <span className="text-base-content/40">Note:</span>
                                                    <div className="flex items-center gap-1">
                                                        <span className="font-medium">{reservation.passager_note}</span>
                                                        <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 text-warning" fill="currentColor" viewBox="0 0 24 24">
                                                            <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
                                                        </svg>
                                                    </div>
                                                </div>
                                            )}
                                        </div>
                                    </div>

                                    {/* Actions */}
                                    <div className="flex flex-col gap-2 lg:ml-4">
                                        <Link
                                            href={`/passager/reservations/${reservation.id}`}
                                            className="btn btn-outline btn-sm rounded-full"
                                        >
                                            Voir détails
                                        </Link>

                                        {reservation.statut === "confirmee" && (
                                            <Link
                                                href={`/passager/suivi/${reservation.trajet_id}`}
                                                className="btn btn-primary btn-sm rounded-full"
                                            >
                                                Suivre le trajet
                                            </Link>
                                        )}
                                    </div>
                                </div>
                            </div>
                        </div>
                    ))}
                </div>
            )}

            {/* Statistiques */}
            {reservations.length > 0 && (
                <div className="bg-base-100 rounded-xl border border-base-200 p-6">
                    <h3 className="text-lg font-semibold text-base-content mb-4">Statistiques</h3>
                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                        {[
                            { label: "Confirmées", value: reservations.filter(r => r.statut === "confirmee").length, color: "text-success" },
                            { label: "En attente", value: reservations.filter(r => r.statut === "en_attente").length, color: "text-warning" },
                            { label: "Terminées", value: reservations.filter(r => r.statut === "terminee").length, color: "text-base-content" },
                            { label: "Déclinées", value: reservations.filter(r => r.statut === "declinee").length, color: "text-error" },
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
