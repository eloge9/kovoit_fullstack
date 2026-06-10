"use client";

import { useState, useEffect, useCallback } from "react";
import { api } from "@/src/services/api";

// ── Types ─────────────────────────────────────────────────────────────────────

interface EvalItem {
    id: number;
    auteur: string;
    cible: string;
    trajet: string;
    note: number;
    commentaire: string;
    date: string;
    statut: "publiee" | "verrouillee";
    signale: boolean;
}

interface TopUser {
    cible__id: string;
    cible__username: string;
    cible__first_name: string;
    cible__last_name: string;
    moy: number;
    nb: number;
}

interface Stats {
    total: number;
    note_moyenne: number;
    nb_signalees: number;
    nb_verrouillee: number;
    top_utilisateurs: TopUser[];
    pires_utilisateurs: TopUser[];
}

// ── Page ─────────────────────────────────────────────────────────────────────

export default function AdminEvaluationsPage() {
    const [stats, setStats] = useState<Stats | null>(null);
    const [evaluations, setEvaluations] = useState<EvalItem[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    const [filtreSignalees, setFiltreSignalees] = useState(false);
    const [filtreStatut, setFiltreStatut] = useState<"" | "publiee" | "verrouillee">("");

    const fetchData = useCallback(async () => {
        setLoading(true);
        setError(null);
        const params = new URLSearchParams();
        if (filtreSignalees) params.set("signalees", "1");
        if (filtreStatut) params.set("statut", filtreStatut);
        const qs = params.toString() ? `?${params}` : "";
        try {
            const res = await api(`/evaluations/admin_stats/${qs}`, "GET");
            setStats(res.stats);
            setEvaluations(Array.isArray(res.evaluations) ? res.evaluations : []);
        } catch {
            setError("Accès refusé ou erreur serveur.");
        } finally {
            setLoading(false);
        }
    }, [filtreSignalees, filtreStatut]);

    useEffect(() => { fetchData(); }, [fetchData]);

    const formatDate = (iso: string) =>
        new Date(iso).toLocaleDateString("fr-FR", { day: "numeric", month: "short", year: "numeric" });

    const nomUser = (u: TopUser) =>
        (`${u.cible__first_name} ${u.cible__last_name}`.trim()) || u.cible__username;

    return (
        <div className="space-y-8">

            {/* En-tête */}
            <div>
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">Admin</p>
                <h1 className="text-2xl font-bold text-base-content">Évaluations</h1>
            </div>

            {error && (
                <div className="bg-error/10 border border-error/20 rounded-xl px-4 py-3">
                    <p className="text-sm text-error">{error}</p>
                </div>
            )}

            {/* Statistiques */}
            {stats && !loading && (
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                    <StatCard label="Total" value={stats.total} />
                    <StatCard label="Note moyenne" value={`${stats.note_moyenne}/5`} />
                    <StatCard label="Signalées" value={stats.nb_signalees} highlight={stats.nb_signalees > 0} />
                    <StatCard label="Verrouillées" value={stats.nb_verrouillee} />
                </div>
            )}

            {/* Meilleurs / Moins bons */}
            {stats && !loading && (
                <div className="grid md:grid-cols-2 gap-6">
                    <div className="bg-base-100 rounded-2xl border border-base-200 p-5">
                        <p className="text-sm font-semibold text-base-content mb-3">Meilleurs utilisateurs</p>
                        {stats.top_utilisateurs.length === 0 ? (
                            <p className="text-xs text-base-content/40">Pas encore de données (min. 3 évaluations).</p>
                        ) : (
                            <div className="space-y-2">
                                {stats.top_utilisateurs.map((u) => (
                                    <div key={u.cible__id} className="flex items-center justify-between gap-3">
                                        <p className="text-sm text-base-content">{nomUser(u)}</p>
                                        <div className="flex items-center gap-2">
                                            <span className="text-xs text-base-content/40">{u.nb} avis</span>
                                            <span className="badge badge-success badge-sm rounded-full">{u.moy.toFixed(1)}</span>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        )}
                    </div>
                    <div className="bg-base-100 rounded-2xl border border-base-200 p-5">
                        <p className="text-sm font-semibold text-base-content mb-3">Notes les plus basses</p>
                        {stats.pires_utilisateurs.length === 0 ? (
                            <p className="text-xs text-base-content/40">Pas encore de données (min. 3 évaluations).</p>
                        ) : (
                            <div className="space-y-2">
                                {stats.pires_utilisateurs.map((u) => (
                                    <div key={u.cible__id} className="flex items-center justify-between gap-3">
                                        <p className="text-sm text-base-content">{nomUser(u)}</p>
                                        <div className="flex items-center gap-2">
                                            <span className="text-xs text-base-content/40">{u.nb} avis</span>
                                            <span className="badge badge-error badge-sm rounded-full">{u.moy.toFixed(1)}</span>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        )}
                    </div>
                </div>
            )}

            {/* Filtres */}
            <div className="flex flex-wrap gap-3 items-center">
                <label className="flex items-center gap-2 cursor-pointer">
                    <input
                        type="checkbox"
                        className="checkbox checkbox-sm"
                        checked={filtreSignalees}
                        onChange={(e) => setFiltreSignalees(e.target.checked)}
                    />
                    <span className="text-sm text-base-content/70">Signalées uniquement</span>
                </label>
                <select
                    className="select select-bordered select-sm rounded-xl"
                    value={filtreStatut}
                    onChange={(e) => setFiltreStatut(e.target.value as "" | "publiee" | "verrouillee")}
                >
                    <option value="">Tous les statuts</option>
                    <option value="publiee">Publiées</option>
                    <option value="verrouillee">Verrouillées</option>
                </select>
                <button onClick={fetchData} className="btn btn-ghost btn-sm rounded-full">
                    Actualiser
                </button>
            </div>

            {/* Liste */}
            {loading ? (
                <div className="space-y-3 animate-pulse">
                    {[1, 2, 3, 4].map((i) => <div key={i} className="h-16 bg-base-200 rounded-2xl" />)}
                </div>
            ) : evaluations.length === 0 ? (
                <div className="bg-base-100 rounded-2xl border border-base-200 p-12 text-center">
                    <p className="text-base-content/40 text-sm">Aucune évaluation avec ces filtres.</p>
                </div>
            ) : (
                <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                    <table className="table table-sm w-full">
                        <thead>
                            <tr className="text-xs text-base-content/40 uppercase">
                                <th>Auteur → Cible</th>
                                <th>Trajet</th>
                                <th>Note</th>
                                <th>Date</th>
                                <th>Statut</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-base-200">
                            {evaluations.map((e) => (
                                <tr key={e.id} className={e.signale ? "bg-error/5" : ""}>
                                    <td>
                                        <p className="text-sm text-base-content font-medium">{e.auteur}</p>
                                        <p className="text-xs text-base-content/40">→ {e.cible}</p>
                                        {e.signale && (
                                            <span className="badge badge-error badge-xs rounded-full mt-0.5">Signalée</span>
                                        )}
                                    </td>
                                    <td className="text-xs text-base-content/60 max-w-xs truncate">{e.trajet}</td>
                                    <td>
                                        <span className={`font-bold text-sm ${e.note >= 4 ? "text-success" : e.note <= 2 ? "text-error" : "text-warning"}`}>
                                            {e.note}/5
                                        </span>
                                    </td>
                                    <td className="text-xs text-base-content/40">{formatDate(e.date)}</td>
                                    <td>
                                        <span className={`badge badge-xs rounded-full ${
                                            e.statut === "verrouillee" ? "badge-ghost" : "badge-info"
                                        }`}>
                                            {e.statut === "verrouillee" ? "Verrouillée" : "Publiée"}
                                        </span>
                                    </td>
                                </tr>
                            ))}
                        </tbody>
                    </table>
                </div>
            )}
        </div>
    );
}

function StatCard({ label, value, highlight }: { label: string; value: string | number; highlight?: boolean }) {
    return (
        <div className={`rounded-2xl border p-5 ${highlight ? "border-error/30 bg-error/5" : "border-base-200 bg-base-100"}`}>
            <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">{label}</p>
            <p className={`text-2xl font-bold mt-1 ${highlight ? "text-error" : "text-base-content"}`}>{value}</p>
        </div>
    );
}
