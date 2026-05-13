"use client";

import Link from "next/link";
import { useAuth } from "@/src/hooks/useAuth";
import { usePassagerDashboardData } from "@/src/hooks/usePassagerDashboardData";

export default function PassagerDashboard() {
    const { user } = useAuth();
    const { reservations, stats, pointsEconomies, loading, error, refresh } = usePassagerDashboardData();

    // Debug: voir la structure des données utilisateur
    console.log("Données utilisateur passager:", user);
    console.log("Données réservations:", reservations);
    console.log("Points calculés:", pointsEconomies);

    const heure = new Date().getHours();
    const salutation = heure < 12 ? "Bonjour" : heure < 18 ? "Bon après-midi" : "Bonsoir";

    // Mettre à jour la note moyenne depuis le profil utilisateur
    const statsWithNote = {
        ...stats,
        noteMoyenne: user?.note || 0,
    };

    const statsData = [
        { label: "Trajets effectués", value: statsWithNote.trajetsEffectues.toString(), sub: "au total" },
        { label: "Réservations actives", value: statsWithNote.reservationsActives.toString(), sub: "en cours" },
        { label: "Économies", value: `${statsWithNote.economiesMensuelles.toLocaleString("fr-FR")} FCFA`, sub: "ce mois" },
        { label: "Note", value: `${statsWithNote.noteMoyenne.toFixed(1)} / 5`, sub: "moyenne" },
    ];

    // Formater les réservations récentes
    const formatReservationDate = (dateString: string) => {
        const date = new Date(dateString);
        const today = new Date();
        const tomorrow = new Date(today);
        tomorrow.setDate(today.getDate() + 1);

        if (date.toDateString() === today.toDateString()) {
            return `Aujourd'hui, ${date.toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" })}`;
        } else if (date.toDateString() === tomorrow.toDateString()) {
            return `Demain, ${date.toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" })}`;
        } else {
            return date.toLocaleDateString("fr-FR", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
        }
    };

    // Trier les réservations par date (plus récentes en premier)
    const reservationsRecentes = reservations
        .sort((a, b) => new Date(b.date_reservation).getTime() - new Date(a.date_reservation).getTime())
        .slice(0, 5)
        .map(reservation => ({
            id: reservation.id,
            conducteur: reservation.conducteur || "Conducteur",
            depart: reservation.depart,
            arrivee: reservation.destination,
            date: formatReservationDate(reservation.date_depart),
            statut: reservation.statut === "confirmee" ? "confirmé" : reservation.statut === "en_attente" ? "en attente" : reservation.statut,
        }));

    return (
        <div className="space-y-10">

            {/* EN-TÊTE */}
            <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4 pb-6 border-b border-base-300">
                <div>
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">
                        Tableau de bord — Passager
                    </p>
                    <h1 className="text-3xl font-bold text-base-content tracking-tight">
                        {salutation}, {user?.first_name || user?.username}
                    </h1>
                    <p className="text-base-content/40 mt-1 text-sm">
                        {new Date().toLocaleDateString("fr-FR", {
                            weekday: "long", day: "numeric", month: "long", year: "numeric"
                        })}
                    </p>
                </div>
            </div>

            {/* BARRE DE RECHERCHE */}
            <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-4">
                    Recherche rapide
                </p>
                <div className="flex flex-col sm:flex-row gap-3">
                    <input
                        type="text"
                        placeholder="Ville de départ"
                        className="input input-bordered input-sm flex-1 rounded-xl"
                    />
                    <input
                        type="text"
                        placeholder="Ville d'arrivée"
                        className="input input-bordered input-sm flex-1 rounded-xl"
                    />
                    <input
                        type="date"
                        className="input input-bordered input-sm w-full sm:w-40 rounded-xl"
                        defaultValue={new Date().toISOString().split("T")[0]}
                    />
                    <Link
                        href="/passager/trajets"
                        className="btn btn-primary btn-sm rounded-xl shrink-0 px-6"
                    >
                        Rechercher
                    </Link>
                </div>
            </div>

            {/* STATS */}
            {loading ? (
                <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                    {[1, 2, 3, 4].map((i) => (
                        <div key={i} className="bg-base-100 rounded-2xl p-6 border border-base-200 animate-pulse">
                            <div className="h-8 bg-base-300 rounded mb-2"></div>
                            <div className="h-4 bg-base-300 rounded w-3/4"></div>
                            <div className="h-3 bg-base-300 rounded w-1/2 mt-1"></div>
                        </div>
                    ))}
                </div>
            ) : error ? (
                <div className="alert alert-error">
                    <span>{error}</span>
                    <button className="btn btn-sm btn-ghost" onClick={refresh}>
                        Réessayer
                    </button>
                </div>
            ) : (
                <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                    {statsData.map((stat) => (
                        <div key={stat.label} className="bg-base-100 rounded-2xl p-6 border border-base-200">
                            <p className="text-3xl font-bold text-base-content tracking-tight">{stat.value}</p>
                            <p className="text-sm font-medium text-base-content mt-1">{stat.label}</p>
                            <p className="text-xs text-base-content/40 mt-0.5">{stat.sub}</p>
                        </div>
                    ))}
                </div>
            )}

            {/* CONTENU PRINCIPAL */}
            <div className="grid lg:grid-cols-3 gap-6">

                {/* Réservations récentes */}
                <div className="lg:col-span-2 bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                    <div className="flex items-center justify-between px-6 py-4 border-b border-base-200">
                        <p className="text-xs font-semibold text-base-content/50 uppercase tracking-widest">
                            Réservations récentes
                        </p>
                        <Link href="/passager/historique" className="text-xs text-primary hover:underline">
                            Voir tout
                        </Link>
                    </div>
                    <div className="divide-y divide-base-200">
                        {loading ? (
                            [1, 2, 3].map((i) => (
                                <div key={i} className="flex items-center justify-between px-6 py-4 animate-pulse">
                                    <div className="space-y-1">
                                        <div className="h-4 bg-base-300 rounded w-32"></div>
                                        <div className="h-3 bg-base-300 rounded w-24"></div>
                                    </div>
                                    <div className="h-6 bg-base-300 rounded-full w-16"></div>
                                </div>
                            ))
                        ) : reservationsRecentes.length > 0 ? (
                            reservationsRecentes.map((reservation) => (
                                <div key={reservation.id} className="flex items-center justify-between px-6 py-4 hover:bg-base-200/40 transition-colors">
                                    <div className="space-y-0.5">
                                        <p className="font-semibold text-sm text-base-content">
                                            {reservation.depart}
                                            <span className="text-base-content/25 mx-2 font-light">→</span>
                                            {reservation.arrivee}
                                        </p>
                                        <p className="text-xs text-base-content/40">
                                            Conducteur : {reservation.conducteur} · {reservation.date}
                                        </p>
                                    </div>
                                    <span className={`badge badge-sm rounded-full font-medium ${reservation.statut === "confirmé"
                                        ? "badge-success badge-outline"
                                        : "badge-warning badge-outline"
                                        }`}>
                                        {reservation.statut}
                                    </span>
                                </div>
                            ))
                        ) : (
                            <div className="px-6 py-8 text-center">
                                <p className="text-sm text-base-content/40">
                                    Aucune réservation pour le moment
                                </p>
                                <Link
                                    href="/passager/trajets"
                                    className="btn btn-primary btn-xs rounded-full mt-3"
                                >
                                    Rechercher un trajet
                                </Link>
                            </div>
                        )}
                    </div>
                </div>

                {/* Colonne droite */}
                <div className="space-y-4">

                    {/* Points */}
                    <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                        <div className="px-6 py-4 border-b border-base-200">
                            <p className="text-xs font-semibold text-base-content/50 uppercase tracking-widest">
                                Points & Économies
                            </p>
                        </div>
                        <div className="px-6 py-4 space-y-3">
                            {loading ? (
                                <div className="space-y-3 animate-pulse">
                                    <div className="h-4 bg-base-300 rounded"></div>
                                    <div className="h-4 bg-base-300 rounded w-3/4"></div>
                                    <div className="h-4 bg-base-300 rounded w-1/2"></div>
                                    <div className="h-4 bg-base-300 rounded w-2/3"></div>
                                </div>
                            ) : (
                                <>
                                    {[
                                        { label: "Points accumulés", value: `${user?.profil_passager?.historique_points || pointsEconomies.pointsAccumules} pts` },
                                        { label: "Économies totales", value: `${pointsEconomies.economiesTotales.toLocaleString("fr-FR")} FCFA` },
                                        { label: "Trajets ce mois", value: `${pointsEconomies.trajetsCeMois} trajets` },
                                        { label: "CO₂ économisé", value: `${pointsEconomies.co2Economise} kg` },
                                    ].map((item) => (
                                        <div key={item.label} className="flex justify-between items-center">
                                            <span className="text-xs text-base-content/40 uppercase tracking-wide">
                                                {item.label}
                                            </span>
                                            <span className="text-sm font-semibold text-base-content">
                                                {item.value}
                                            </span>
                                        </div>
                                    ))}
                                    <div className="pt-2">
                                        <Link
                                            href="/passager/economie"
                                            className="btn btn-ghost btn-xs rounded-full w-full border border-base-200"
                                        >
                                            Voir le détail
                                        </Link>
                                    </div>
                                </>
                            )}
                        </div>
                    </div>

                    {/* Navigation */}
                    <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                        <div className="px-6 py-4 border-b border-base-200">
                            <p className="text-xs font-semibold text-base-content/50 uppercase tracking-widest">
                                Navigation
                            </p>
                        </div>
                        <div className="divide-y divide-base-200">
                            {[
                                { href: "/passager/reservations", label: "Historique des réservations" },
                                { href: "/passager/historique", label: "Historique des trajets" },
                                { href: "/passager/evaluations", label: "Mes évaluations" },
                                { href: "/passager/profil", label: "Profil & Paramètres" },
                            ].map((item) => (
                                <Link
                                    key={item.href}
                                    href={item.href}
                                    className="flex items-center justify-between px-6 py-3 hover:bg-base-200/50 transition-colors group"
                                >
                                    <span className="text-sm text-base-content/60 group-hover:text-base-content transition-colors">
                                        {item.label}
                                    </span>
                                    <span className="text-base-content/20 group-hover:text-base-content/50 transition-colors text-xs">
                                        →
                                    </span>
                                </Link>
                            ))}
                        </div>
                    </div>

                </div>
            </div>

        </div>
    );
}