"use client";

import { useEffect, useState, useCallback } from "react";
import { useAuth } from "@/src/hooks/useAuth";
import { getApiUrl } from "@/src/utils/apiUtils";

interface Notif {
    id: number;
    contenu: string;
    lu: boolean;
    destinataire: string;
    date: string;
}

interface ApiResult { total: number; page: number; resultats: Notif[]; }

function fmtDate(iso: string) {
    return new Date(iso).toLocaleString("fr-FR", { day: "2-digit", month: "2-digit", year: "2-digit", hour: "2-digit", minute: "2-digit" });
}

export default function AdminNotifications() {
    const { token } = useAuth();
    const [data,    setData]    = useState<ApiResult | null>(null);
    const [loading, setLoading] = useState(true);
    const [sending, setSending] = useState(false);
    const [page,    setPage]    = useState(1);

    // Formulaire envoi
    const [contenu,  setContenu]  = useState("");
    const [role,     setRole]     = useState("");
    const [userId,   setUserId]   = useState("");
    const [success,  setSuccess]  = useState("");

    const load = useCallback(async (p = page) => {
        if (!token) return;
        setLoading(true);
        try {
            const r = await fetch(`${getApiUrl()}/utilisateurs/admin/notifications/?page=${p}&limit=50`, {
                headers: { Authorization: `Bearer ${token}` },
            });
            if (!r.ok) throw new Error();
            setData(await r.json());
        } catch { /* silencieux */ }
        finally  { setLoading(false); }
    }, [token, page]);

    useEffect(() => { load(page); }, [page]); // eslint-disable-line react-hooks/exhaustive-deps

    async function envoyer() {
        if (!contenu.trim()) return;
        setSending(true);
        setSuccess("");
        try {
            const body: Record<string, string> = { contenu };
            if (userId.trim()) body.utilisateur_id = userId.trim();
            else if (role)     body.role = role;
            const r = await fetch(`${getApiUrl()}/utilisateurs/admin/notifications/envoyer/`, {
                method: "POST",
                headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
                body: JSON.stringify(body),
            });
            const res = await r.json();
            setSuccess(res.message || "Notification envoyée.");
            setContenu(""); setRole(""); setUserId("");
            load(1); setPage(1);
        } catch { setSuccess("Erreur lors de l'envoi."); }
        finally  { setSending(false); }
    }

    const totalPages = data ? Math.ceil(data.total / 50) : 1;

    return (
        <div className="space-y-6">
            <div className="pb-4 border-b border-base-200">
                <p className="text-xs text-base-content/40 uppercase tracking-widest mb-1">Administration</p>
                <h1 className="text-2xl font-bold tracking-tight">Notifications</h1>
            </div>

            {/* Formulaire envoi */}
            <div className="bg-base-100 rounded-2xl border border-base-200 p-6 space-y-4">
                <h2 className="font-semibold text-base">Envoyer une notification</h2>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div className="sm:col-span-2">
                        <label className="text-xs text-base-content/50 mb-1 block">Message</label>
                        <textarea value={contenu} onChange={(e) => setContenu(e.target.value)}
                            rows={3} placeholder="Contenu de la notification..."
                            className="textarea textarea-bordered w-full rounded-xl text-sm" />
                    </div>

                    <div>
                        <label className="text-xs text-base-content/50 mb-1 block">Cibler un rôle (optionnel)</label>
                        <select value={role} onChange={(e) => { setRole(e.target.value); setUserId(""); }}
                            className="select select-bordered select-sm rounded-xl w-full">
                            <option value="">Tous les utilisateurs actifs</option>
                            <option value="conducteur">Conducteurs</option>
                            <option value="passager">Passagers</option>
                            <option value="admin">Admins</option>
                        </select>
                    </div>

                    <div>
                        <label className="text-xs text-base-content/50 mb-1 block">Ou ID utilisateur spécifique</label>
                        <input type="text" value={userId} onChange={(e) => { setUserId(e.target.value); setRole(""); }}
                            placeholder="UUID de l'utilisateur..."
                            className="input input-bordered input-sm rounded-xl w-full" />
                    </div>
                </div>

                {success && (
                    <div className={`alert text-sm rounded-xl ${success.includes("Erreur") ? "alert-error" : "alert-success"}`}>
                        {success}
                    </div>
                )}

                <button onClick={envoyer} disabled={!contenu.trim() || sending}
                    className="btn btn-primary btn-sm rounded-xl">
                    {sending ? <span className="loading loading-spinner loading-xs" /> : null}
                    Envoyer
                </button>
            </div>

            {/* Historique */}
            <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                <div className="px-5 py-4 border-b border-base-200">
                    <h2 className="font-semibold text-sm">Historique des notifications {data ? `(${data.total})` : ""}</h2>
                </div>

                <div className="overflow-x-auto">
                    <table className="table table-sm">
                        <thead className="bg-base-200/50">
                            <tr>
                                <th>Destinataire</th>
                                <th>Message</th>
                                <th>Lu</th>
                                <th>Date</th>
                            </tr>
                        </thead>
                        <tbody>
                            {loading ? (
                                Array.from({ length: 5 }).map((_, i) => (
                                    <tr key={i} className="animate-pulse">
                                        {[1,2,3,4].map(j => <td key={j}><div className="h-4 bg-base-200 rounded" /></td>)}
                                    </tr>
                                ))
                            ) : data?.resultats.map((n) => (
                                <tr key={n.id} className="hover">
                                    <td className="font-medium text-sm">{n.destinataire}</td>
                                    <td className="text-sm max-w-xs truncate" title={n.contenu}>{n.contenu}</td>
                                    <td>
                                        <span className={`badge badge-xs ${n.lu ? "badge-success" : "badge-ghost"}`}>
                                            {n.lu ? "Lu" : "Non lu"}
                                        </span>
                                    </td>
                                    <td className="text-xs text-base-content/50 whitespace-nowrap">{fmtDate(n.date)}</td>
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
