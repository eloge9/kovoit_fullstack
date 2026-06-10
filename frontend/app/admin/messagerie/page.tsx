"use client";

import { useEffect, useState, useCallback } from "react";
import { useAuth } from "@/src/hooks/useAuth";
import { getApiUrl } from "@/src/utils/apiUtils";

interface Participant { id: string; username: string; }
interface Conv {
    id: number;
    statut: string;
    participants: Participant[];
    nb_messages: number;
    updated_at: string | null;
}

interface Message {
    id: number;
    contenu: string;
    auteur_id: string;
    auteur: string;
    timestamp: string;
}

interface ConvsResult { total: number; page: number; resultats: Conv[]; }

function fmtDate(iso: string) {
    return new Date(iso).toLocaleString("fr-FR", { day: "2-digit", month: "2-digit", year: "2-digit", hour: "2-digit", minute: "2-digit" });
}

export default function AdminMessagerie() {
    const { token } = useAuth();
    const [convs,    setConvs]    = useState<ConvsResult | null>(null);
    const [messages, setMessages] = useState<Message[]>([]);
    const [selected, setSelected] = useState<Conv | null>(null);
    const [loading,  setLoading]  = useState(true);
    const [loadMsg,  setLoadMsg]  = useState(false);
    const [error,    setError]    = useState("");
    const [q,        setQ]        = useState("");
    const [page,     setPage]     = useState(1);

    const loadConvs = useCallback(async (p = page) => {
        if (!token) return;
        setLoading(true);
        try {
            const qs = new URLSearchParams({ page: String(p), limit: "50" });
            if (q) qs.set("q", q);
            const r = await fetch(`${getApiUrl()}/utilisateurs/admin/messagerie/conversations/?${qs}`, {
                headers: { Authorization: `Bearer ${token}` },
            });
            if (!r.ok) throw new Error();
            setConvs(await r.json());
        } catch { setError("Impossible de charger les conversations."); }
        finally  { setLoading(false); }
    }, [token, q, page]);

    useEffect(() => { loadConvs(1); setPage(1); }, [token, q]); // eslint-disable-line react-hooks/exhaustive-deps
    useEffect(() => { loadConvs(page); }, [page]); // eslint-disable-line react-hooks/exhaustive-deps

    async function openConv(c: Conv) {
        setSelected(c);
        setLoadMsg(true);
        try {
            const r = await fetch(
                `${getApiUrl()}/utilisateurs/admin/messagerie/conversations/${c.id}/messages/`,
                { headers: { Authorization: `Bearer ${token}` } }
            );
            if (!r.ok) throw new Error();
            setMessages(await r.json());
        } catch { setMessages([]); }
        finally  { setLoadMsg(false); }
    }

    const totalPages = convs ? Math.ceil(convs.total / 50) : 1;

    return (
        <div className="space-y-6">
            <div className="pb-4 border-b border-base-200">
                <p className="text-xs text-base-content/40 uppercase tracking-widest mb-1">Administration</p>
                <h1 className="text-2xl font-bold tracking-tight">Messagerie (lecture seule)</h1>
                <p className="text-sm text-base-content/40 mt-1">Vue admin des conversations — toute lecture est auditée.</p>
            </div>

            <div className="flex gap-3 flex-wrap">
                <input type="text" placeholder="Rechercher un utilisateur..."
                    value={q} onChange={(e) => setQ(e.target.value)}
                    className="input input-bordered input-sm rounded-xl flex-1 min-w-64" />
            </div>

            {error && <div className="alert alert-error text-sm">{error}</div>}

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                {/* Liste conversations */}
                <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                    <div className="px-4 py-3 border-b border-base-200">
                        <h2 className="font-semibold text-sm">Conversations {convs ? `(${convs.total})` : ""}</h2>
                    </div>
                    <div className="divide-y divide-base-200 max-h-[600px] overflow-y-auto">
                        {loading ? (
                            Array.from({ length: 5 }).map((_, i) => (
                                <div key={i} className="p-4 animate-pulse">
                                    <div className="h-4 bg-base-200 rounded w-2/3 mb-2" />
                                    <div className="h-3 bg-base-200 rounded w-1/3" />
                                </div>
                            ))
                        ) : convs?.resultats.map((c) => (
                            <button key={c.id} onClick={() => openConv(c)}
                                className={`w-full text-left p-4 hover:bg-base-200/50 transition-colors ${selected?.id === c.id ? "bg-primary/5 border-l-2 border-primary" : ""}`}>
                                <div className="font-medium text-sm truncate">
                                    {c.participants.map(p => p.username).join(", ") || `Conv #${c.id}`}
                                </div>
                                <div className="flex items-center gap-2 mt-1">
                                    <span className={`badge badge-xs ${c.statut === "ouverte" ? "badge-success" : "badge-ghost"}`}>
                                        {c.statut}
                                    </span>
                                    <span className="text-xs text-base-content/40">{c.nb_messages} msg</span>
                                    {c.updated_at && (
                                        <span className="text-xs text-base-content/30 ml-auto">{fmtDate(c.updated_at)}</span>
                                    )}
                                </div>
                            </button>
                        ))}
                    </div>
                    {totalPages > 1 && (
                        <div className="flex justify-center items-center gap-2 p-3 border-t border-base-200">
                            <button disabled={page <= 1} onClick={() => setPage(p => p - 1)}
                                className="btn btn-xs btn-ghost rounded-xl">‹</button>
                            <span className="text-xs text-base-content/50">{page}/{totalPages}</span>
                            <button disabled={page >= totalPages} onClick={() => setPage(p => p + 1)}
                                className="btn btn-xs btn-ghost rounded-xl">›</button>
                        </div>
                    )}
                </div>

                {/* Messages */}
                <div className="lg:col-span-2 bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                    {!selected ? (
                        <div className="h-full flex flex-col items-center justify-center py-24 text-center text-base-content/30">
                            <p className="text-4xl mb-3">💬</p>
                            <p className="text-sm">Sélectionnez une conversation</p>
                        </div>
                    ) : (
                        <>
                            <div className="px-5 py-3 border-b border-base-200 flex items-center gap-3">
                                <div>
                                    <p className="font-semibold text-sm">
                                        {selected.participants.map(p => p.username).join(", ")}
                                    </p>
                                    <p className="text-xs text-base-content/40">Conv #{selected.id} · {selected.nb_messages} messages</p>
                                </div>
                            </div>
                            <div className="p-4 space-y-3 max-h-[520px] overflow-y-auto">
                                {loadMsg ? (
                                    <div className="flex justify-center py-8">
                                        <span className="loading loading-spinner loading-md" />
                                    </div>
                                ) : messages.length === 0 ? (
                                    <p className="text-center text-sm text-base-content/30 py-8">Aucun message.</p>
                                ) : messages.map((m) => (
                                    <div key={m.id} className="flex flex-col gap-1">
                                        <div className="flex items-center gap-2">
                                            <span className="text-xs font-semibold text-base-content/70">{m.auteur}</span>
                                            <span className="text-xs text-base-content/30">{fmtDate(m.timestamp)}</span>
                                        </div>
                                        <div className="bg-base-200/60 rounded-xl px-4 py-2 text-sm max-w-[80%]">
                                            {m.contenu}
                                        </div>
                                    </div>
                                ))}
                            </div>
                        </>
                    )}
                </div>
            </div>
        </div>
    );
}
