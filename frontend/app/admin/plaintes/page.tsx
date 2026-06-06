"use client";

import { useEffect, useState } from "react";
import { useAuth } from "@/src/hooks/useAuth";
import { getApiUrl } from "@/src/utils/apiUtils";

interface Plainte {
    id: string;
    titre: string;
    description: string;
    type_plainte: string;
    statut: string;
    date_creation: string;
    date_resolution?: string;
    signalataire_details?: { username: string };
    utilisateur_signale_details: { username: string };
    admin_assigne_details?: { username: string };
    note_admin: string;
}

export default function AdminPlaintes() {
    const { user, token } = useAuth();
    const [plaintes, setPlaintes] = useState<Plainte[]>([]);
    const [loading, setLoading] = useState(true);
    const [filterStatut, setFilterStatut] = useState<string>("");
    const [filterType, setFilterType] = useState<string>("");
    const [selectedPlainte, setSelectedPlainte] = useState<Plainte | null>(null);
    const [noteAdmin, setNoteAdmin] = useState("");

    useEffect(() => {
        const fetchPlaintes = async () => {
            try {
                let url = `${getApiUrl()}/utilisateurs/admin/plaintes/`;
                const params = new URLSearchParams();
                if (filterStatut) params.append("statut", filterStatut);
                if (filterType) params.append("type", filterType);
                if (params.toString()) url += `?${params.toString()}`;

                const response = await fetch(url, {
                    headers: {
                        "Authorization": `Bearer ${token}`,
                        "Content-Type": "application/json",
                    },
                });

                if (!response.ok) throw new Error("Erreur");
                const data = await response.json();
                setPlaintes(Array.isArray(data) ? data : []);
            } catch {
                // erreur déjà gérée par l'état error
            } finally {
                setLoading(false);
            }
        };

        if (token) fetchPlaintes();
    }, [token, filterStatut, filterType]);

    const handleAssigner = async (plainteId: string) => {
        try {
            await fetch(
                `${getApiUrl()}/utilisateurs/admin/plaintes/${plainteId}/assigner/`,
                {
                    method: "POST",
                    headers: {
                        "Authorization": `Bearer ${token}`,
                        "Content-Type": "application/json",
                    },
                }
            );
            setPlaintes(plaintes.map(p =>
                p.id === plainteId
                    ? { ...p, statut: "en_cours", admin_assigne_details: { username: user?.username || "Admin" } }
                    : p
            ));
            alert("Plainte assignée !");
        } catch (err: any) {
            alert("Erreur: " + err.message);
        }
    };

    const handleResoudre = async (plainteId: string) => {
        try {
            await fetch(
                `${getApiUrl()}/utilisateurs/admin/plaintes/${plainteId}/resoudre/`,
                {
                    method: "POST",
                    headers: {
                        "Authorization": `Bearer ${token}`,
                        "Content-Type": "application/json",
                    },
                    body: JSON.stringify({ note_admin: noteAdmin }),
                }
            );
            setPlaintes(plaintes.map(p =>
                p.id === plainteId
                    ? { ...p, statut: "resolue", note_admin: noteAdmin, date_resolution: new Date().toISOString() }
                    : p
            ));
            setSelectedPlainte(null);
            setNoteAdmin("");
            alert("Plainte résolue !");
        } catch (err: any) {
            alert("Erreur: " + err.message);
        }
    };

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
                <h1 className="text-3xl font-bold text-base-content tracking-tight">⚠️ Plaintes & Signalements</h1>
            </div>

            {/* FILTRES */}
            <div className="bg-base-100 rounded-2xl border border-base-200 p-6 space-y-4">
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                    Filtres
                </p>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <select
                        value={filterStatut}
                        onChange={(e) => setFilterStatut(e.target.value)}
                        className="select select-bordered select-sm rounded-xl"
                    >
                        <option value="">Tous les statuts</option>
                        <option value="en_attente">En attente</option>
                        <option value="en_cours">En cours</option>
                        <option value="resolue">Résolues</option>
                        <option value="rejetee">Rejetées</option>
                    </select>

                    <select
                        value={filterType}
                        onChange={(e) => setFilterType(e.target.value)}
                        className="select select-bordered select-sm rounded-xl"
                    >
                        <option value="">Tous les types</option>
                        <option value="conducteur">Conducteur</option>
                        <option value="passager">Passager</option>
                        <option value="comportement">Comportement</option>
                        <option value="vehicule">Véhicule</option>
                        <option value="autre">Autre</option>
                    </select>
                </div>
            </div>

            {/* LISTE DES PLAINTES */}
            <div className="space-y-4">
                {plaintes.length === 0 ? (
                    <div className="bg-base-100 rounded-2xl border border-base-200 p-8 text-center text-base-content/40">
                        Aucune plainte trouvée
                    </div>
                ) : (
                    plaintes.map((p) => (
                        <div key={p.id} className="bg-base-100 rounded-2xl border border-base-200 p-6 hover:border-primary/30 transition-all">
                            <div className="flex flex-col md:flex-row md:items-start md:justify-between gap-4">
                                <div className="flex-1">
                                    <div className="flex items-start gap-3 mb-3">
                                        <div className={`badge badge-sm ${p.type_plainte === "comportement" ? "badge-warning" :
                                                p.type_plainte === "vehicule" ? "badge-error" :
                                                    "badge-info"
                                            }`}>
                                            {p.type_plainte}
                                        </div>
                                        <div className={`badge badge-sm ${p.statut === "en_attente" ? "badge-error" :
                                                p.statut === "en_cours" ? "badge-warning" :
                                                    "badge-success"
                                            }`}>
                                            {p.statut}
                                        </div>
                                    </div>

                                    <h3 className="text-lg font-bold mb-2">{p.titre}</h3>
                                    <p className="text-sm text-base-content/60 mb-4">{p.description}</p>

                                    <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-xs">
                                        <div>
                                            <p className="text-base-content/40">Signalé par</p>
                                            <p className="font-medium">{p.signalataire_details?.username || "—"}</p>
                                        </div>
                                        <div>
                                            <p className="text-base-content/40">Contre</p>
                                            <p className="font-medium">{p.utilisateur_signale_details?.username}</p>
                                        </div>
                                        <div>
                                            <p className="text-base-content/40">Créée le</p>
                                            <p className="font-medium">{formatDate(p.date_creation)}</p>
                                        </div>
                                        <div>
                                            <p className="text-base-content/40">Assignée à</p>
                                            <p className="font-medium">{p.admin_assigne_details?.username || "—"}</p>
                                        </div>
                                    </div>
                                </div>

                                <div className="flex flex-col gap-2">
                                    {p.statut === "en_attente" && (
                                        <button
                                            onClick={() => handleAssigner(p.id)}
                                            className="btn btn-primary btn-sm rounded-xl"
                                        >
                                            Assigner
                                        </button>
                                    )}
                                    {p.statut === "en_cours" && (
                                        <button
                                            onClick={() => setSelectedPlainte(p)}
                                            className="btn btn-success btn-sm rounded-xl"
                                        >
                                            Résoudre
                                        </button>
                                    )}
                                </div>
                            </div>
                        </div>
                    ))
                )}
            </div>

            {/* MODAL RÉSOUDRE */}
            {selectedPlainte && (
                <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
                    <div className="bg-base-100 rounded-2xl p-6 max-w-md w-full">
                        <h2 className="text-lg font-bold mb-4">Résoudre la plainte</h2>
                        <textarea
                            value={noteAdmin}
                            onChange={(e) => setNoteAdmin(e.target.value)}
                            placeholder="Ajouter une note d'admin..."
                            className="textarea textarea-bordered w-full rounded-xl mb-4 h-24"
                        />
                        <div className="flex gap-3">
                            <button
                                onClick={() => setSelectedPlainte(null)}
                                className="btn btn-ghost flex-1 rounded-xl"
                            >
                                Annuler
                            </button>
                            <button
                                onClick={() => handleResoudre(selectedPlainte.id)}
                                className="btn btn-success flex-1 rounded-xl"
                            >
                                Résoudre
                            </button>
                        </div>
                    </div>
                </div>
            )}

        </div>
    );
}
