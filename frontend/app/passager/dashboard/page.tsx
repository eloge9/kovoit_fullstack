"use client";

import Link from "next/link";
import { useAuth } from "@/src/hooks/useAuth";

export default function PassagerDashboard() {
    const { user } = useAuth();

    const heure = new Date().getHours();
    const salutation = heure < 12 ? "Bonjour" : heure < 18 ? "Bon après-midi" : "Bonsoir";

    const stats = [
        { label: "Trajets effectués", value: "12", sub: "au total" },
        { label: "Réservations actives", value: "2", sub: "en cours" },
        { label: "Économies", value: "12 500 FCFA", sub: "ce mois" },
        { label: "Note", value: `${user?.note || "0"} / 5`, sub: "moyenne" },
    ];

    const reservationsRecentes = [
        { conducteur: "Marc D.", depart: "Lomé", arrivee: "Kpalimé", date: "Aujourd'hui, 08h00", statut: "confirmé" },
        { conducteur: "Afi K.", depart: "Lomé", arrivee: "Atakpamé", date: "Demain, 07h30", statut: "en attente" },
        { conducteur: "Kofi A.", depart: "Lomé", arrivee: "Sokodé", date: "07 Mar, 06h00", statut: "confirmé" },
    ];

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

                {/* Réservations récentes */}
                <div className="lg:col-span-2 bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                    <div className="flex items-center justify-between px-6 py-4 border-b border-base-200">
                        <p className="text-xs font-semibold text-base-content/50 uppercase tracking-widest">
                            Réservations récentes
                        </p>
                        <Link href="/passager/reservation/historique" className="text-xs text-primary hover:underline">
                            Voir tout
                        </Link>
                    </div>
                    <div className="divide-y divide-base-200">
                        {reservationsRecentes.map((resa, i) => (
                            <div key={i} className="flex items-center justify-between px-6 py-4 hover:bg-base-200/40 transition-colors">
                                <div className="space-y-0.5">
                                    <p className="font-semibold text-sm text-base-content">
                                        {resa.depart}
                                        <span className="text-base-content/25 mx-2 font-light">→</span>
                                        {resa.arrivee}
                                    </p>
                                    <p className="text-xs text-base-content/40">
                                        Conducteur : {resa.conducteur} · {resa.date}
                                    </p>
                                </div>
                                <span className={`badge badge-sm rounded-full font-medium ${resa.statut === "confirmé"
                                    ? "badge-success badge-outline"
                                    : "badge-warning badge-outline"
                                    }`}>
                                    {resa.statut}
                                </span>
                            </div>
                        ))}
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
                            {[
                                { label: "Points accumulés", value: `${user?.profil_passager?.historique_points || 0} pts` },
                                { label: "Économies totales", value: "42 000 FCFA" },
                                { label: "Trajets ce mois", value: "5 trajets" },
                                { label: "CO₂ économisé", value: "12 kg" },
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
                                { href: "/passager/reservation/historique", label: "Historique des réservations" },
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