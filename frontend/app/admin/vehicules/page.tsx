"use client";

import { useEffect, useState, useCallback } from "react";
import { useAuth } from "@/src/hooks/useAuth";
import { getApiUrl } from "@/src/utils/apiUtils";

interface Vehicule {
    id: number;
    type: string;
    marque: string;
    modele: string;
    couleur: string;
    plaque: string;
    places_max: number;
    est_actif: boolean;
    conducteur_id: string;
    conducteur: string;
    photo: string | null;
    created_at: string;
}

interface ApiResult { total: number; page: number; resultats: Vehicule[]; }

const TYPE_ICON: Record<string, string> = {
    moto: "🏍️", voiture: "🚗", minibus: "🚌", camion: "🚚",
};

function fmtDate(iso: string) {
    return new Date(iso).toLocaleDateString("fr-FR", { day: "2-digit", month: "short", year: "numeric" });
}

export default function AdminVehicules() {
    const { token } = useAuth();
    const [data,    setData]    = useState<ApiResult | null>(null);
    const [loading, setLoading] = useState(true);
    const [error,   setError]   = useState("");
    const [q,       setQ]       = useState("");
    const [type,    setType]    = useState("");
    const [actif,   setActif]   = useState("");
    const [page,    setPage]    = useState(1);

    const load = useCallback(async (p = page) => {
        if (!token) return;
        setLoading(true);
        try {
            const qs = new URLSearchParams({ page: String(p), limit: "50" });
            if (q)    qs.set("q",    q);
            if (type) qs.set("type", type);
            if (actif !== "") qs.set("actif", actif);
            const r = await fetch(`${getApiUrl()}/utilisateurs/admin/vehicules/?${qs}`, {
                headers: { Authorization: `Bearer ${token}` },
            });
            if (!r.ok) throw new Error();
            setData(await r.json());
        } catch { setError("Impossible de charger les véhicules."); }
        finally  { setLoading(false); }
    }, [token, q, type, actif, page]);

    useEffect(() => { load(1); setPage(1); }, [token, q, type, actif]); // eslint-disable-line react-hooks/exhaustive-deps
    useEffect(() => { load(page); }, [page]); // eslint-disable-line react-hooks/exhaustive-deps

    async function toggleActif(v: Vehicule) {
        const action = v.est_actif ? "suspendre" : "activer";
        try {
            await fetch(`${getApiUrl()}/utilisateurs/admin/vehicules/${v.id}/${action}/`, {
                method: "POST",
                headers: { Authorization: `Bearer ${token}` },
            });
            load(page);
        } catch { alert("Erreur lors de la modification."); }
    }

    const totalPages = data ? Math.ceil(data.total / 50) : 1;

    return (
        <div className="space-y-6">
            <div className="pb-4 border-b border-base-200 flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3">
                <div>
                    <p className="text-xs text-base-content/40 uppercase tracking-widest mb-1">Administration</p>
                    <h1 className="text-2xl font-bold tracking-tight">Véhicules</h1>
                    {data && <p className="text-sm text-base-content/40 mt-1">{data.total} véhicule{data.total > 1 ? "s" : ""}</p>}
                </div>
            </div>

            {/* Filtres */}
            <div className="flex gap-3 flex-wrap">
                <input type="text" placeholder="Marque, modèle, plaque, conducteur..."
                    value={q} onChange={(e) => setQ(e.target.value)}
                    className="input input-bordered input-sm rounded-xl flex-1 min-w-48" />
                <select value={type} onChange={(e) => setType(e.target.value)}
                    className="select select-bordered select-sm rounded-xl">
                    <option value="">Tous types</option>
                    <option value="moto">Moto</option>
                    <option value="voiture">Voiture</option>
                    <option value="minibus">Minibus</option>
                    <option value="camion">Camion</option>
                </select>
                <select value={actif} onChange={(e) => setActif(e.target.value)}
                    className="select select-bordered select-sm rounded-xl">
                    <option value="">Tous</option>
                    <option value="true">Actifs</option>
                    <option value="false">Suspendus</option>
                </select>
            </div>

            {error && <div className="alert alert-error text-sm">{error}</div>}

            <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="table table-sm">
                        <thead className="bg-base-200/50">
                            <tr>
                                <th>Type</th>
                                <th>Véhicule</th>
                                <th>Plaque</th>
                                <th>Places</th>
                                <th>Conducteur</th>
                                <th>Ajouté le</th>
                                <th>Statut</th>
                                <th>Action</th>
                            </tr>
                        </thead>
                        <tbody>
                            {loading ? (
                                Array.from({ length: 6 }).map((_, i) => (
                                    <tr key={i} className="animate-pulse">
                                        {Array.from({ length: 8 }).map((__, j) => (
                                            <td key={j}><div className="h-4 bg-base-200 rounded" /></td>
                                        ))}
                                    </tr>
                                ))
                            ) : data?.resultats.map((v) => (
                                <tr key={v.id} className="hover">
                                    <td>
                                        <span className="text-xl">{TYPE_ICON[v.type] ?? "🚗"}</span>
                                    </td>
                                    <td>
                                        <div className="font-semibold text-sm">{v.marque} {v.modele}</div>
                                        <div className="text-xs text-base-content/40 capitalize">{v.couleur} — {v.type}</div>
                                    </td>
                                    <td className="font-mono text-xs font-bold">{v.plaque}</td>
                                    <td className="text-center">{v.places_max}</td>
                                    <td className="text-sm">{v.conducteur}</td>
                                    <td className="text-xs text-base-content/60">{fmtDate(v.created_at)}</td>
                                    <td>
                                        <span className={`badge badge-sm ${v.est_actif ? "badge-success" : "badge-error"}`}>
                                            {v.est_actif ? "Actif" : "Suspendu"}
                                        </span>
                                    </td>
                                    <td>
                                        <button onClick={() => toggleActif(v)}
                                            className={`btn btn-xs rounded-lg ${v.est_actif ? "btn-error" : "btn-success"}`}>
                                            {v.est_actif ? "Suspendre" : "Activer"}
                                        </button>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>

                {totalPages > 1 && (
                    <div className="flex justify-center items-center gap-2 p-4 border-t border-base-200">
                        <button disabled={page <= 1} onClick={() => setPage(p => p - 1)}
                            className="btn btn-sm btn-ghost rounded-xl">‹</button>
                        <span className="text-sm text-base-content/60">Page {page} / {totalPages}</span>
                        <button disabled={page >= totalPages} onClick={() => setPage(p => p + 1)}
                            className="btn btn-sm btn-ghost rounded-xl">›</button>
                    </div>
                )}
            </div>
        </div>
    );
}
