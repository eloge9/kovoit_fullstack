"use client";

import { useEffect, useState } from "react";
import { useAuth } from "@/src/hooks/useAuth";
import { getApiUrl } from "@/src/utils/apiUtils";

interface Paiement {
    id: number;
    montant: number;
    commission: number;
    net: number;
    moyen: string;
    statut: string;
    date: string;
    passager: string;
    conducteur: string;
    trajet: string;
}

export default function AdminPaiements() {
    const { token } = useAuth();
    const [paiements, setPaiements] = useState<Paiement[]>([]);
    const [stats, setStats] = useState<any>(null);
    const [loading, setLoading] = useState(true);
    const [filterStatut, setFilterStatut] = useState<string>("");

    useEffect(() => {
        const fetchData = async () => {
            try {
                // Paiements
                let url = `${getApiUrl()}/utilisateurs/admin/paiements/`;
                if (filterStatut) url += `?statut=${filterStatut}`;

                const response = await fetch(url, {
                    headers: {
                        "Authorization": `Bearer ${token}`,
                        "Content-Type": "application/json",
                    },
                });

                if (!response.ok) throw new Error("Erreur");
                const data = await response.json();
                setPaiements(Array.isArray(data.resultats) ? data.resultats : []);

                // Stats
                const statsResponse = await fetch(
                    `${getApiUrl()}/utilisateurs/admin/paiements/statistiques/`,
                    {
                        headers: {
                            "Authorization": `Bearer ${token}`,
                            "Content-Type": "application/json",
                        },
                    }
                );
                if (statsResponse.ok) {
                    const statsData = await statsResponse.json();
                    setStats(statsData);
                }
            } catch {
                // erreur déjà gérée par l'état error
            } finally {
                setLoading(false);
            }
        };

        if (token) fetchData();
    }, [token, filterStatut]);

    const formatDate = (dateString: string) => {
        const date = new Date(dateString);
        return date.toLocaleDateString("fr-FR") + " " + date.toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" });
    };

    if (loading) return <div className="text-center py-8">Chargement...</div>;

    return (
        <div className="space-y-6">

            {/* EN-TÊTE */}
            <div className="pb-6 border-b border-base-300">
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">
                    Gestion
                </p>
                <h1 className="text-3xl font-bold text-base-content tracking-tight"> Paiements</h1>
            </div>

            {/* STATISTIQUES */}
            {stats && (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                    <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-3">
                            Total paiements
                        </p>
                        <p className="text-2xl font-bold">{stats.nb_transactions || 0}</p>
                    </div>
                    <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-3">
                            Revenus totaux
                        </p>
                        <p className="text-2xl font-bold">{Math.round(stats.ca_total || 0).toLocaleString("fr-FR")} FCFA</p>
                    </div>
                    <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-3">
                            Commission KoVoit (10%)
                        </p>
                        <p className="text-2xl font-bold text-success">{Math.round(stats.commission || 0).toLocaleString("fr-FR")} FCFA</p>
                    </div>
                    <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-3">
                            Conducteurs (90%)
                        </p>
                        <p className="text-2xl font-bold text-primary">{Math.round(stats.net_conducteurs || 0).toLocaleString("fr-FR")} FCFA</p>
                    </div>
                </div>
            )}

            {/* FILTRES */}
            <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-4">
                    Filtres
                </p>
                <select
                    value={filterStatut}
                    onChange={(e) => setFilterStatut(e.target.value)}
                    className="select select-bordered select-sm rounded-xl"
                >
                    <option value="">Tous les statuts</option>
                    <option value="CONFIRME">Confirmés</option>
                    <option value="EN_ATTENTE_CONFIRMATION">En attente</option>
                    <option value="ANNULE">Annulés</option>
                </select>
            </div>

            {/* TABLEAU */}
            <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="table table-zebra w-full text-sm">
                        <thead className="bg-base-200">
                            <tr>
                                <th className="text-xs uppercase">Passager</th>
                                <th className="text-xs uppercase">Conducteur</th>
                                <th className="text-xs uppercase">Trajet</th>
                                <th className="text-xs uppercase">Montant</th>
                                <th className="text-xs uppercase">Commission</th>
                                <th className="text-xs uppercase">Moyen</th>
                                <th className="text-xs uppercase">Date</th>
                                <th className="text-xs uppercase">Statut</th>
                            </tr>
                        </thead>
                        <tbody>
                            {paiements.length === 0 ? (
                                <tr>
                                    <td colSpan={8} className="text-center py-8 text-base-content/40">
                                        Aucun paiement trouvé
                                    </td>
                                </tr>
                            ) : (
                                paiements.map((p) => (
                                    <tr key={p.id} className="hover:bg-base-200/50">
                                        <td className="text-sm">{p.passager}</td>
                                        <td className="text-sm">{p.conducteur}</td>
                                        <td className="text-xs text-base-content/60">{p.trajet}</td>
                                        <td className="font-medium text-sm">
                                            {Math.round(p.montant).toLocaleString("fr-FR")} FCFA
                                        </td>
                                        <td className="text-xs text-success">
                                            {Math.round(p.commission).toLocaleString("fr-FR")} FCFA
                                        </td>
                                        <td>
                                            <div className="badge badge-sm badge-ghost">{p.moyen}</div>
                                        </td>
                                        <td className="text-xs">{p.date ? formatDate(p.date) : "—"}</td>
                                        <td>
                                            <div className={`badge badge-sm ${p.statut === "CONFIRME" || p.statut === "PAYEE"
                                                    ? "badge-success"
                                                    : p.statut === "EN_ATTENTE_CONFIRMATION" || p.statut === "EN_ATTENTE"
                                                        ? "badge-warning"
                                                        : "badge-error"
                                                }`}>
                                                {p.statut}
                                            </div>
                                        </td>
                                    </tr>
                                ))
                            )}
                        </tbody>
                    </table>
                </div>
            </div>

        </div>
    );
}
