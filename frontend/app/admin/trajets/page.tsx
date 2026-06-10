"use client";

import { useEffect, useState } from "react";
import { useAuth } from "@/src/hooks/useAuth";
import { getApiUrl } from "@/src/utils/apiUtils";

interface Trajet {
    id: number;
    depart: string;
    destination: string;
    conducteur: string;
    distance_km: number;
    prix_par_place: number;
    date_depart: string;
    statut: string;
    nb_reservations: number;
    vehicule: string | null;
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
                setTrajets(Array.isArray(data.resultats) ? data.resultats : []);
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
                                <th className="text-xs uppercase">Véhicule</th>
                                <th className="text-xs uppercase">Date départ</th>
                                <th className="text-xs uppercase">Réservations</th>
                                <th className="text-xs uppercase">Prix/place</th>
                                <th className="text-xs uppercase">Statut</th>
                            </tr>
                        </thead>
                        <tbody>
                            {trajets.length === 0 ? (
                                <tr>
                                    <td colSpan={7} className="text-center py-8 text-base-content/40">
                                        Aucun trajet trouvé
                                    </td>
                                </tr>
                            ) : (
                                trajets.map((t) => (
                                    <tr key={t.id} className="hover:bg-base-200/50">
                                        <td>
                                            <div>
                                                <p className="font-medium">{t.depart} → {t.destination}</p>
                                                {t.distance_km && (
                                                    <p className="text-xs text-base-content/60">{t.distance_km} km</p>
                                                )}
                                            </div>
                                        </td>
                                        <td className="text-sm">{t.conducteur}</td>
                                        <td className="text-xs text-base-content/60">{t.vehicule || "—"}</td>
                                        <td className="text-xs">{formatDate(t.date_depart)}</td>
                                        <td>
                                            <div className="badge badge-sm badge-primary">
                                                {t.nb_reservations}
                                            </div>
                                        </td>
                                        <td className="text-sm font-medium">
                                            {Math.round(t.prix_par_place).toLocaleString("fr-FR")} FCFA
                                        </td>
                                        <td>
                                            <div className={`badge badge-sm ${
                                                t.statut === "termine" ? "badge-success" :
                                                t.statut === "annule"  ? "badge-error"   :
                                                t.statut === "en_cours"? "badge-warning"  :
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
