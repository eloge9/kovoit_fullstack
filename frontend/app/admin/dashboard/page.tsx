"use client";

import { useEffect, useState } from "react";
import { useAuth } from "@/src/hooks/useAuth";
import { getApiUrl } from "@/src/utils/apiUtils";

interface StatistiquesGlobales {
    nombre_utilisateurs_total: number;
    nombre_conducteurs: number;
    nombre_passagers: number;
    nombre_admins: number;
    nombre_trajets_total: number;
    nombre_trajets_ouverts: number;
    nombre_trajets_termines: number;
    nombre_trajets_annules: number;
    nombre_reservations_total: number;
    nombre_reservations_confirmees: number;
    nombre_reservations_terminees: number;
    nombre_paiements_total: number;
    nombre_paiements_confirmes: number;
    revenu_total_kovoit: number;
    revenu_total_conducteurs: number;
    nombre_evaluations: number;
    note_moyenne_conducteurs: number;
    note_moyenne_passagers: number;
    nombre_plaintes: number;
    nombre_plaintes_en_attente: number;
    nombre_plaintes_resolues: number;
}

export default function AdminDashboard() {
    const { user, token } = useAuth();
    const [stats, setStats] = useState<StatistiquesGlobales | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState("");

    useEffect(() => {
        const fetchStats = async () => {
            try {
                const response = await fetch(
                    `${getApiUrl()}/utilisateurs/admin/statistiques/`,
                    {
                        headers: {
                            "Authorization": `Bearer ${token}`,
                            "Content-Type": "application/json",
                        },
                    }
                );

                if (!response.ok) throw new Error("Erreur lors du chargement des statistiques");

                const data = await response.json();
                setStats(data);
            } catch (err: any) {
                setError(err.message);
            } finally {
                setLoading(false);
            }
        };

        if (token) fetchStats();
    }, [token]);

    const heure = new Date().getHours();
    const salutation = heure < 12 ? "Bonjour" : heure < 18 ? "Bon après-midi" : "Bonsoir";

    if (loading) {
        return (
            <div className="space-y-6">
                <div className="animate-pulse space-y-4">
                    <div className="h-32 bg-base-300 rounded-2xl"></div>
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                        {[...Array(8)].map((_, i) => (
                            <div key={i} className="h-32 bg-base-300 rounded-2xl"></div>
                        ))}
                    </div>
                </div>
            </div>
        );
    }

    if (!stats) {
        return (
            <div className="alert alert-error">
                <span>{error || "Erreur lors du chargement des données"}</span>
            </div>
        );
    }

    const StatCard = ({ label, value, sub, icon }: { label: string; value: string | number; sub?: string; icon?: string }) => (
        <div className="bg-base-100 rounded-2xl border border-base-200 p-6 hover:border-primary/30 transition-all">
            <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-3">
                {icon} {label}
            </p>
            <p className="text-2xl font-bold text-base-content">
                {typeof value === "number" ? value.toLocaleString("fr-FR") : value}
            </p>
            {sub && <p className="text-sm text-base-content/60 mt-2">{sub}</p>}
        </div>
    );

    return (
        <div className="space-y-10">

            {/* EN-TÊTE */}
            <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4 pb-6 border-b border-base-300">
                <div>
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">
                        Tableau de bord — Administration
                    </p>
                    <h1 className="text-3xl font-bold text-base-content tracking-tight">
                        {salutation}, {user?.first_name || user?.username}
                    </h1>
                    <p className="text-base-content/40 mt-1 text-sm">
                        Vue d'ensemble de la plateforme KoVoit
                    </p>
                </div>
            </div>

            {/* UTILISATEURS */}
            <div className="space-y-4">
                <h2 className="text-lg font-bold text-base-content">Utilisateurs</h2>
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                    <StatCard
                        label="Total"
                        value={stats.nombre_utilisateurs_total}

                    />
                    <StatCard
                        label="Conducteurs"
                        value={stats.nombre_conducteurs}

                    />
                    <StatCard
                        label="Passagers"
                        value={stats.nombre_passagers}
                    />
                    <StatCard
                        label="Admins"
                        value={stats.nombre_admins}
                    />
                </div>
            </div>

            {/* TRAJETS */}
            <div className="space-y-4">
                <h2 className="text-lg font-bold text-base-content">Trajets</h2>
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                    <StatCard
                        label="Total"
                        value={stats.nombre_trajets_total}
                    />
                    <StatCard
                        label="Ouverts"
                        value={stats.nombre_trajets_ouverts}
                    />
                    <StatCard
                        label="Terminés"
                        value={stats.nombre_trajets_termines}
                    />
                    <StatCard
                        label="Annulés"
                        value={stats.nombre_trajets_annules}
                    />
                </div>
            </div>

            {/* RÉSERVATIONS */}
            <div className="space-y-4">
                <h2 className="text-lg font-bold text-base-content">Réservations</h2>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                    <StatCard
                        label="Total"
                        value={stats.nombre_reservations_total}
                    />
                    <StatCard
                        label="Confirmées"
                        value={stats.nombre_reservations_confirmees}
                        icon="✓"
                    />
                    <StatCard
                        label="Terminées"
                        value={stats.nombre_reservations_terminees}
                    />
                </div>
            </div>

            {/* PAIEMENTS & REVENUS */}
            <div className="space-y-4">
                <h2 className="text-lg font-bold text-base-content">Paiements & Revenus</h2>
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                    <StatCard
                        label="Paiements total"
                        value={stats.nombre_paiements_total}
                        icon="💳"
                    />
                    <StatCard
                        label="Confirmés"
                        value={stats.nombre_paiements_confirmes}
                        icon="✓"
                    />
                    <StatCard
                        label="Commission KoVoit (10%)"
                        value={`${Math.round(stats.revenu_total_kovoit).toLocaleString("fr-FR")} FCFA`}
                    />
                    <StatCard
                        label="Revenus conducteurs (90%)"
                        value={`${Math.round(stats.revenu_total_conducteurs).toLocaleString("fr-FR")} FCFA`}
                    />
                </div>
            </div>

            {/* ÉVALUATIONS */}
            <div className="space-y-4">
                <h2 className="text-lg font-bold text-base-content">Évaluations</h2>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                    <StatCard
                        label="Total"
                        value={stats.nombre_evaluations}
                    />
                    <StatCard
                        label="Note conducteurs"
                        value={`${stats.note_moyenne_conducteurs.toFixed(1)} / 5`}
                    />
                    <StatCard
                        label="Note passagers"
                        value={`${stats.note_moyenne_passagers.toFixed(1)} / 5`}
                    />
                </div>
            </div>

            {/* PLAINTES */}
            <div className="space-y-4">
                <h2 className="text-lg font-bold text-base-content">Plaintes</h2>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                    <StatCard
                        label="Total"
                        value={stats.nombre_plaintes}
                    />
                    <StatCard
                        label="En attente"
                        value={stats.nombre_plaintes_en_attente}
                    />
                    <StatCard
                        label="Résolues"
                        value={stats.nombre_plaintes_resolues}
                        icon="✅"
                    />
                </div>
            </div>

        </div>
    );
}