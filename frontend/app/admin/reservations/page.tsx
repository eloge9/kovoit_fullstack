"use client";

import { useEffect, useState, useCallback } from "react";
import { useAuth } from "@/src/hooks/useAuth";
import { getApiUrl } from "@/src/utils/apiUtils";

interface Resa {
    id: number;
    statut: string;
    passager: string;
    passager_id: string;
    conducteur: string;
    depart: string;
    destination: string;
    date_trajet: string;
    date_reservation: string;
    places: number;
    prix: number;
    code: string;
}

interface ApiResult { total: number; page: number; resultats: Resa[]; }

const STATUT_COLORS: Record<string, string> = {
    en_attente:  "badge-warning",
    confirmee:   "badge-success",
    declinee:    "badge-error",
    annulee:     "badge-error",
    en_cours:    "badge-info",
    terminee:    "badge-neutral",
};

function fmtDate(iso: string) {
    return new Date(iso).toLocaleDateString("fr-FR", { day: "2-digit", month: "2-digit", year: "2-digit", hour: "2-digit", minute: "2-digit" });
}

function fmtFCFA(v: number) {
    return new Intl.NumberFormat("fr-FR").format(Math.round(v)) + " F";
}

export default function AdminReservations() {
    const { token } = useAuth();
    const [data,    setData]    = useState<ApiResult | null>(null);
    const [loading, setLoading] = useState(true);
    const [error,   setError]   = useState("");
    const [q,       setQ]       = useState("");
    const [statut,  setStatut]  = useState("");
    const [page,    setPage]    = useState(1);
    const [confirm, setConfirm] = useState<Resa | null>(null);

    const load = useCallback(async (p = page) => {
        if (!token) return;
        setLoading(true);
        try {
            const qs = new URLSearchParams({ page: String(p), limit: "50" });
            if (q)      qs.set("q",      q);
            if (statut) qs.set("statut", statut);
            const r = await fetch(`${getApiUrl()}/utilisateurs/admin/reservations/?${qs}`, {
                headers: { Authorization: `Bearer ${token}` },
            });
            if (!r.ok) throw new Error();
            setData(await r.json());
        } catch { setError("Impossible de charger les réservations."); }
        finally  { setLoading(false); }
    }, [token, q, statut, page]);

    useEffect(() => { load(1); setPage(1); }, [token, q, statut]); // eslint-disable-line react-hooks/exhaustive-deps
    useEffect(() => { load(page); }, [page]); // eslint-disable-line react-hooks/exhaustive-deps

    async function annuler(id: number) {
        try {
            await fetch(`${getApiUrl()}/utilisateurs/admin/reservations/${id}/annuler/`, {
                method: "POST",
                headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
                body: JSON.stringify({ motif: "Annulation par administrateur" }),
            });
            setConfirm(null);
            load(page);
        } catch { alert("Erreur lors de l'annulation."); }
    }

    const totalPages = data ? Math.ceil(data.total / 50) : 1;

    return (
        <div className="space-y-6">
            <div className="pb-4 border-b border-base-200 flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3">
                <div>
                    <p className="text-xs text-base-content/40 uppercase tracking-widest mb-1">Administration</p>
                    <h1 className="text-2xl font-bold tracking-tight">Réservations</h1>
                    {data && <p className="text-sm text-base-content/40 mt-1">{data.total} réservation{data.total > 1 ? "s" : ""} au total</p>}
                </div>
            </div>

            {/* Filtres */}
            <div className="flex gap-3 flex-wrap">
                <input
                    type="text"
                    placeholder="Passager, trajet, code..."
                    value={q}
                    onChange={(e) => setQ(e.target.value)}
                    className="input input-bordered input-sm rounded-xl flex-1 min-w-48"
                />
                <select value={statut} onChange={(e) => setStatut(e.target.value)}
                    className="select select-bordered select-sm rounded-xl">
                    <option value="">Tous les statuts</option>
                    <option value="en_attente">En attente</option>
                    <option value="confirmee">Confirmée</option>
                    <option value="declinee">Déclinée</option>
                    <option value="annulee">Annulée</option>
                    <option value="terminee">Terminée</option>
                </select>
            </div>

            {error && <div className="alert alert-error text-sm">{error}</div>}

            {/* Tableau */}
            <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="table table-sm">
                        <thead className="bg-base-200/50">
                            <tr>
                                <th>ID</th>
                                <th>Passager</th>
                                <th>Trajet</th>
                                <th>Date trajet</th>
                                <th>Places</th>
                                <th>Prix</th>
                                <th>Statut</th>
                                <th>Code</th>
                                <th>Action</th>
                            </tr>
                        </thead>
                        <tbody>
                            {loading ? (
                                Array.from({ length: 8 }).map((_, i) => (
                                    <tr key={i} className="animate-pulse">
                                        {Array.from({ length: 9 }).map((__, j) => (
                                            <td key={j}><div className="h-4 bg-base-200 rounded" /></td>
                                        ))}
                                    </tr>
                                ))
                            ) : data?.resultats.map((r) => (
                                <tr key={r.id} className="hover">
                                    <td className="font-mono text-xs text-base-content/50">#{r.id}</td>
                                    <td className="font-medium text-sm">{r.passager}</td>
                                    <td className="text-sm max-w-[160px] truncate" title={`${r.depart} → ${r.destination}`}>
                                        {r.depart} → {r.destination}
                                    </td>
                                    <td className="text-xs text-base-content/60 whitespace-nowrap">{fmtDate(r.date_trajet)}</td>
                                    <td className="text-center">{r.places}</td>
                                    <td className="font-semibold text-sm">{fmtFCFA(r.prix)}</td>
                                    <td>
                                        <span className={`badge badge-sm ${STATUT_COLORS[r.statut] || "badge-ghost"}`}>
                                            {r.statut.replace("_", " ")}
                                        </span>
                                    </td>
                                    <td className="font-mono text-xs">{r.code}</td>
                                    <td>
                                        {r.statut === "confirmee" || r.statut === "en_attente" ? (
                                            <button onClick={() => setConfirm(r)}
                                                className="btn btn-xs btn-error rounded-lg">
                                                Annuler
                                            </button>
                                        ) : <span className="text-xs text-base-content/30">—</span>}
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>

                {/* Pagination */}
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

            {/* Modal confirmation annulation */}
            {confirm && (
                <div className="modal modal-open">
                    <div className="modal-box rounded-2xl">
                        <h3 className="font-bold text-lg mb-2">Annuler la réservation #{confirm.id} ?</h3>
                        <p className="text-sm text-base-content/60 mb-4">
                            Passager: <strong>{confirm.passager}</strong> — Trajet: {confirm.depart} → {confirm.destination}
                        </p>
                        <div className="flex gap-3 justify-end">
                            <button onClick={() => setConfirm(null)} className="btn btn-ghost btn-sm rounded-xl">Annuler</button>
                            <button onClick={() => annuler(confirm.id)} className="btn btn-error btn-sm rounded-xl">Confirmer</button>
                        </div>
                    </div>
                    <div className="modal-backdrop" onClick={() => setConfirm(null)} />
                </div>
            )}
        </div>
    );
}
