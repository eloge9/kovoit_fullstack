"use client";

import { useEffect, useState } from "react";
import { useAuth } from "@/src/hooks/useAuth";
import { getApiUrl } from "@/src/utils/apiUtils";

interface Trajet {
    id: number;
    depart: string;
    destination: string;
    conducteur_details: { username: string };
    distance_km: number;
    cout_total: number;
    prix_par_place: number;
    date_heure_depart: string;
    statut: string;
    reservations_count: number;
    revenus_total: number;
    commission_kovoit: number;
}

export default function AdminTrajets() {
    const { token } = useAuth();
    const [trajets, setTrajets] = useState<Trajet[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState("");
    const [filterStatut, setFilterStatut] = useState<string>("");

    useEffect(() => {
        const fetchTrajets = async () => {
            try {
                let url = `${getApiUrl()}/utilisateurs/admin/trajets/`;
                if (filterStatut) url += `?statut=${filterStatut}`;

                const response = await fetch(url, {
                    headers: {
                        "Authorization": `Bearer ${token}`,
                        "Content-Type": "application/json",
                    },
                });

                if (!response.ok) throw new Error("Erreur");
                const data = await response.json();
                setTrajets(Array.isArray(data) ? data : []);
            } catch (err: any) {
                setError(err.message);
            } finally {
                setLoading(false);
            }
        };

        if (token) fetchTrajets();
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
                <h1 className="text-3xl font-bold text-base-content tracking-tight"> Trajets</h1>
            </div>

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
                    <option value="ouvert">Ouverts</option>
                    <option value="en_cours">En cours</option>
                    <option value="termine">Terminés</option>
                    <option value="annule">Annulés</option>
                </select>
            </div>

            {/* TABLEAU */}
            <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="table table-zebra w-full text-sm">
                        <thead className="bg-base-200">
                            <tr>
                                <th className="text-xs uppercase">Trajet</th>
                                <th className="text-xs uppercase">Conducteur</th>
                                <th className="text-xs uppercase">Date</th>
                                <th className="text-xs uppercase">Réservations</th>
                                <th className="text-xs uppercase">Revenus</th>
                                <th className="text-xs uppercase">Statut</th>
                            </tr>
                        </thead>
                        <tbody>
                            {trajets.length === 0 ? (
                                <tr>
                                    <td colSpan={6} className="text-center py-8 text-base-content/40">
                                        Aucun trajet trouvé
                                    </td>
                                </tr>
                            ) : (
                                trajets.map((t) => (
                                    <tr key={t.id} className="hover:bg-base-200/50">
                                        <td>
                                            <div>
                                                <p className="font-medium">{t.depart} → {t.destination}</p>
                                                <p className="text-xs text-base-content/60">{t.distance_km} km</p>
                                            </div>
                                        </td>
                                        <td>{t.conducteur_details?.username}</td>
                                        <td className="text-xs">{formatDate(t.date_heure_depart)}</td>
                                        <td>
                                            <div className="badge badge-sm badge-primary">
                                                {t.reservations_count}
                                            </div>
                                        </td>
                                        <td>
                                            <div className="text-xs">
                                                <p className="font-medium">{Math.round(t.revenus_total).toLocaleString("fr-FR")} FCFA</p>
                                                <p className="text-base-content/60">KoVoit: {Math.round(t.commission_kovoit).toLocaleString("fr-FR")} FCFA</p>
                                            </div>
                                        </td>
                                        <td>
                                            <div className={`badge badge-sm ${t.statut === "termine" ? "badge-success" :
                                                t.statut === "annule" ? "badge-error" :
                                                    t.statut === "en_cours" ? "badge-warning" :
                                                        "badge-info"
                                                }`}>
                                                {t.statut}
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
