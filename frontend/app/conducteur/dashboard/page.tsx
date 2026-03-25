"use client";

import Link from "next/link";
import { useAuth } from "@/src/hooks/useAuth";

export default function ConducteurDashboard() {
    const { user } = useAuth();

    const heure = new Date().getHours();
    const salutation = heure < 12 ? "Bonjour" : heure < 18 ? "Bon après-midi" : "Bonsoir";

    const stats = [
        { label: "Trajets proposés", value: "24", sub: "ce mois" },
        { label: "Réservations reçues", value: "8", sub: "en attente" },
        { label: "Revenus", value: "47 500 FCFA", sub: "ce mois" },
        { label: "Note", value: `${user?.note || "0"} / 5`, sub: "moyenne" },
    ];

    const trajetsRecents = [
        { depart: "Lomé", arrivee: "Kpalimé", date: "Aujourd'hui, 08h00", places: 3, statut: "actif" },
        { depart: "Lomé", arrivee: "Atakpamé", date: "Demain, 07h30", places: 0, statut: "complet" },
        { depart: "Lomé", arrivee: "Sokodé", date: "07 Mar, 06h00", places: 4, statut: "actif" },
    ];

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
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                {stats.map((stat) => (
                    <div key={stat.label} className="bg-base-100 rounded-2xl p-6 border border-base-200">
                        <p className="text-3xl font-bold text-base-content tracking-tight">{stat.value}</p>
                        <p className="text-sm font-medium text-base-content mt-1">{stat.label}</p>
                        <p className="text-xs text-base-content/40 mt-0.5">{stat.sub}</p>
                    </div>
                ))}
            </div>

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
                        {trajetsRecents.map((trajet, i) => (
                            <div key={i} className="flex items-center justify-between px-6 py-4 hover:bg-base-200/40 transition-colors">
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
                                    <span className={`badge badge-sm rounded-full font-medium ${trajet.statut === "actif"
                                            ? "badge-success badge-outline"
                                            : "badge-error badge-outline"
                                        }`}>
                                        {trajet.statut}
                                    </span>
                                </div>
                            </div>
                        ))}
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
                            {user?.profil_conducteur ? (
                                <div className="space-y-3">
                                    {[
                                        { label: "Véhicule", value: user.profil_conducteur.vehicule },
                                        { label: "Type", value: user.profil_conducteur.type_vehicule },
                                        { label: "Couleur", value: user.profil_conducteur.couleur_vehicule },
                                        { label: "Plaque", value: user.profil_conducteur.plaque },
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
                                            href="/conducteur/profil/edit"
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
                                        href="/conducteur/profil/edit"
                                        className="btn btn-primary btn-xs rounded-full"
                                    >
                                        Compléter mon profil
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