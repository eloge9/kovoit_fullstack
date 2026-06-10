"use client";

import { useEffect, useState, useCallback } from "react";
import { useAuth } from "@/src/hooks/useAuth";
import { getApiUrl } from "@/src/utils/apiUtils";

interface AuditLog {
    id: number;
    admin: string;
    action: string;
    action_label: string;
    cible_type: string;
    cible_id: string;
    description: string;
    ip: string | null;
    date: string;
}

interface ApiResult { total: number; page: number; resultats: AuditLog[]; }

const ACTION_COLORS: Record<string, string> = {
    user_suspend:     "badge-warning",
    user_activate:    "badge-success",
    user_ban:         "badge-error",
    user_delete:      "badge-error",
    doc_validate:     "badge-success",
    doc_reject:       "badge-warning",
    trip_cancel:      "badge-warning",
    trip_delete:      "badge-error",
    eval_hide:        "badge-warning",
    eval_restore:     "badge-success",
    complaint_assign: "badge-info",
    complaint_close:  "badge-success",
    complaint_reject: "badge-error",
    msg_read:         "badge-ghost",
    config_update:    "badge-info",
    notif_send:       "badge-info",
    admin_login:      "badge-neutral",
};

function fmtDate(iso: string) {
    return new Date(iso).toLocaleString("fr-FR", {
        day: "2-digit", month: "2-digit", year: "2-digit",
        hour: "2-digit", minute: "2-digit", second: "2-digit",
    });
}

export default function AdminAudit() {
    const { token } = useAuth();
    const [data,    setData]    = useState<ApiResult | null>(null);
    const [loading, setLoading] = useState(true);
    const [error,   setError]   = useState("");
    const [action,  setAction]  = useState("");
    const [page,    setPage]    = useState(1);

    const load = useCallback(async (p = page) => {
        if (!token) return;
        setLoading(true);
        try {
            const qs = new URLSearchParams({ page: String(p), limit: "100" });
            if (action) qs.set("action", action);
            const r = await fetch(`${getApiUrl()}/utilisateurs/admin/audit/?${qs}`, {
                headers: { Authorization: `Bearer ${token}` },
            });
            if (!r.ok) throw new Error(`Erreur serveur (${r.status})`);
            setData(await r.json());
            setError("");
        } catch (e: unknown) { setError(e instanceof Error ? e.message : "Erreur"); }
        finally  { setLoading(false); }
    }, [token, action, page]);

    useEffect(() => { load(1); setPage(1); }, [token, action]); // eslint-disable-line react-hooks/exhaustive-deps
    useEffect(() => { load(page); }, [page]); // eslint-disable-line react-hooks/exhaustive-deps

    const totalPages = data ? Math.ceil(data.total / 100) : 1;

    return (
        <div className="space-y-6">
            <div className="pb-4 border-b border-base-200">
                <p className="text-xs text-base-content/40 uppercase tracking-widest mb-1">Administration</p>
                <h1 className="text-2xl font-bold tracking-tight">Journal d'audit</h1>
                {data && <p className="text-sm text-base-content/40 mt-1">{data.total} entrée{data.total > 1 ? "s" : ""}</p>}
            </div>

            {error && (
                <div className="alert alert-error rounded-xl">
                    <span>{error}</span>
                </div>
            )}

            <div className="flex gap-3">
                <select value={action} onChange={(e) => setAction(e.target.value)}
                    className="select select-bordered select-sm rounded-xl">
                    <option value="">Toutes les actions</option>
                    <option value="user_suspend">Suspension utilisateur</option>
                    <option value="user_activate">Activation utilisateur</option>
                    <option value="user_ban">Bannissement</option>
                    <option value="user_delete">Suppression utilisateur</option>
                    <option value="doc_validate">Validation documents</option>
                    <option value="doc_reject">Rejet documents</option>
                    <option value="trip_cancel">Annulation trajet</option>
                    <option value="trip_delete">Suppression trajet</option>
                    <option value="eval_hide">Masquage évaluation</option>
                    <option value="complaint_assign">Assignation plainte</option>
                    <option value="complaint_close">Fermeture plainte</option>
                    <option value="msg_read">Lecture messages</option>
                    <option value="config_update">Modif config</option>
                    <option value="notif_send">Envoi notification</option>
                </select>
            </div>

            <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="table table-xs">
                        <thead className="bg-base-200/50">
                            <tr>
                                <th>Date</th>
                                <th>Admin</th>
                                <th>Action</th>
                                <th>Cible</th>
                                <th className="min-w-[300px]">Description</th>
                                <th>IP</th>
                            </tr>
                        </thead>
                        <tbody>
                            {loading ? (
                                Array.from({ length: 10 }).map((_, i) => (
                                    <tr key={i} className="animate-pulse">
                                        {[1,2,3,4,5,6].map(j => <td key={j}><div className="h-3 bg-base-200 rounded" /></td>)}
                                    </tr>
                                ))
                            ) : data?.resultats.map((a) => (
                                <tr key={a.id} className="hover">
                                    <td className="text-xs text-base-content/50 whitespace-nowrap font-mono">
                                        {fmtDate(a.date)}
                                    </td>
                                    <td className="font-semibold text-xs">{a.admin}</td>
                                    <td>
                                        <span className={`badge badge-xs ${ACTION_COLORS[a.action] || "badge-ghost"}`}>
                                            {a.action_label}
                                        </span>
                                    </td>
                                    <td className="text-xs text-base-content/50">
                                        {a.cible_type && <span className="font-medium">{a.cible_type}</span>}
                                        {a.cible_id && <span className="ml-1 font-mono">#{a.cible_id}</span>}
                                    </td>
                                    <td className="text-xs text-base-content/70 max-w-xs truncate" title={a.description}>
                                        {a.description}
                                    </td>
                                    <td className="text-xs font-mono text-base-content/30">{a.ip || "—"}</td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>

                {!loading && data?.resultats.length === 0 && (
                    <div className="py-16 text-center">
                        <p className="text-3xl mb-2">📋</p>
                        <p className="text-sm text-base-content/40">Aucune entrée dans le journal.</p>
                    </div>
                )}

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
