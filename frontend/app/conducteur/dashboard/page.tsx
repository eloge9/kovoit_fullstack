"use client";

import Link from "next/link";
import { useAuth } from "@/src/hooks/useAuth";
import { useDashboardData } from "@/src/hooks/useDashboardData";
import { useVehiculeData } from "@/src/hooks/useVehiculeData";

export default function ConducteurDashboard() {
    const { user } = useAuth();
    const { trajets, reservations, stats, loading, error, refresh } = useDashboardData();
    const { vehiculePrincipal, loading: vehiculeLoading, error: vehiculeError } = useVehiculeData();

    const heure = new Date().getHours();
    const salutation = heure < 12 ? "Bonjour" : heure < 18 ? "Bon après-midi" : "Bonsoir";

    // Mettre à jour la note moyenne depuis le profil utilisateur
    const statsWithNote = {
        ...stats,
        noteMoyenne: user?.note || 0,
    };

    const statsData = [
        { label: "Trajets proposés", value: statsWithNote.trajetsProposes.toString(), sub: "total" },
        { label: "Réservations reçues", value: statsWithNote.reservationsEnAttente.toString(), sub: "en attente" },
        { label: "Revenus", value: `${statsWithNote.revenusMensuels.toLocaleString("fr-FR")} FCFA`, sub: "ce mois" },
        { label: "Note", value: `${statsWithNote.noteMoyenne.toFixed(1)} / 5`, sub: "moyenne" },
    ];

    // Formater les trajets récents
    const formatTrajetDate = (dateString: string) => {
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

    // Trier les trajets par date (plus récents en premier)
    const trajetsRecents = trajets
        .sort((a, b) => new Date(b.date_heure_depart).getTime() - new Date(a.date_heure_depart).getTime())
        .slice(0, 5)
        .map(trajet => ({
            id: trajet.id,
            depart: trajet.depart,
            arrivee: trajet.destination,
            date: formatTrajetDate(trajet.date_heure_depart),
            places: trajet.places_restantes,
            statut: trajet.statut === "ouvert" ? "actif" : trajet.statut === "en_cours" ? "en cours" : trajet.statut,
        }));

    return (
        <div className="space-y-10">

            {/* EN-TÊTE */}
            <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4 pb-6 border-b border-base-300">
                <div>
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">
                        Tableau de bord — Conducteur
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
                <Link
                    href="/conducteur/trajets/create"
                    className="btn btn-primary btn-sm rounded-full px-6 w-fit"
                >
                    Proposer un trajet
                </Link>
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

                {/* Trajets récents */}
                <div className="lg:col-span-2 bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                    <div className="flex items-center justify-between px-6 py-4 border-b border-base-200">
                        <p className="text-xs font-semibold text-base-content/50 uppercase tracking-widest">
                            Trajets récents
                        </p>
                        <Link href="/conducteur/trajets" className="text-xs text-primary hover:underline">
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
                                    <div className="flex items-center gap-3">
                                        <div className="h-3 bg-base-300 rounded w-12"></div>
                                        <div className="h-6 bg-base-300 rounded-full w-16"></div>
                                    </div>
                                </div>
                            ))
                        ) : trajetsRecents.length > 0 ? (
                            trajetsRecents.map((trajet) => (
                                <div key={trajet.id} className="flex items-center justify-between px-6 py-4 hover:bg-base-200/40 transition-colors">
                                    <div className="space-y-0.5">
                                        <p className="font-semibold text-sm text-base-content">
                                            {trajet.depart}
                                            <span className="text-base-content/25 mx-2 font-light">→</span>
                                            {trajet.arrivee}
                                        </p>
                                        <p className="text-xs text-base-content/40">{trajet.date}</p>
                                    </div>
                                    <div className="flex items-center gap-3">
                                        <span className="text-xs text-base-content/30">
                                            {trajet.places} place{trajet.places > 1 ? "s" : ""}
                                        </span>
                                        <span className={`badge badge-sm rounded-full font-medium ${trajet.statut === "actif" || trajet.statut === "ouvert"
                                            ? "badge-success badge-outline"
                                            : trajet.statut === "en cours"
                                                ? "badge-warning badge-outline"
                                                : "badge-error badge-outline"
                                            }`}>
                                            {trajet.statut === "ouvert" ? "actif" : trajet.statut}
                                        </span>
                                    </div>
                                </div>
                            ))
                        ) : (
                            <div className="px-6 py-8 text-center">
                                <p className="text-sm text-base-content/40">
                                    Aucun trajet proposé pour le moment
                                </p>
                                <Link
                                    href="/conducteur/trajets/create"
                                    className="btn btn-primary btn-xs rounded-full mt-3"
                                >
                                    Proposer un trajet
                                </Link>
                            </div>
                        )}
                    </div>
                </div>

                {/* Colonne droite */}
                <div className="space-y-4">

                    {/* Véhicule */}
                    <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                        <div className="px-6 py-4 border-b border-base-200">
                            <p className="text-xs font-semibold text-base-content/50 uppercase tracking-widest">
                                Mon véhicule
                            </p>
                        </div>
                        <div className="px-6 py-4">
                            {vehiculeLoading ? (
                                <div className="space-y-3 animate-pulse">
                                    <div className="h-4 bg-base-300 rounded"></div>
                                    <div className="h-4 bg-base-300 rounded w-3/4"></div>
                                    <div className="h-4 bg-base-300 rounded w-1/2"></div>
                                    <div className="h-4 bg-base-300 rounded w-2/3"></div>
                                </div>
                            ) : vehiculePrincipal ? (
                                <div className="space-y-3">
                                    {[
                                        { label: "Véhicule", value: `${vehiculePrincipal.marque} ${vehiculePrincipal.modele}` },
                                        { label: "Type", value: vehiculePrincipal.type_vehicule },
                                        { label: "Couleur", value: vehiculePrincipal.couleur },
                                        { label: "Plaque", value: vehiculePrincipal.plaque },
                                    ].map((item) => (
                                        <div key={item.label} className="flex justify-between items-center">
                                            <span className="text-xs text-base-content/40 uppercase tracking-wide">
                                                {item.label}
                                            </span>
                                            <span className="text-sm font-medium text-base-content">
                                                {item.value}
                                            </span>
                                        </div>
                                    ))}
                                    <div className="pt-2">
                                        <Link
                                            href="/conducteur/profil"
                                            className="btn btn-ghost btn-xs rounded-full w-full border border-base-200"
                                        >
                                            Modifier
                                        </Link>
                                    </div>
                                </div>
                            ) : (
                                <div className="py-6 text-center space-y-3">
                                    <p className="text-sm text-base-content/40">
                                        Aucun véhicule renseigné
                                    </p>
                                    <Link
                                        href="/conducteur/profil"
                                        className="btn btn-primary btn-xs rounded-full"
                                    >
                                        Ajouter un véhicule
                                    </Link>
                                </div>
                            )}
                        </div>
                    </div>

                    {/* Accès rapides */}
                    <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                        <div className="px-6 py-4 border-b border-base-200">
                            <p className="text-xs font-semibold text-base-content/50 uppercase tracking-widest">
                                Navigation
                            </p>
                        </div>
                        <div className="divide-y divide-base-200">
                            {[
                                { href: "/conducteur/reservations", label: "Réservations reçues" },
                                { href: "/conducteur/historique", label: "Historique" },
                                { href: "/conducteur/evaluations", label: "Évaluations" },
                                { href: "/conducteur/profil", label: "Profil & Paramètres" },
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