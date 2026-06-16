"use client";

import { useEffect, useState, useCallback } from "react";
import dynamic from "next/dynamic";
import { useAuth } from "@/src/hooks/useAuth";
import { getApiUrl } from "@/src/utils/apiUtils";
import {
    BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid,
    Tooltip, ResponsiveContainer, Legend,
} from "recharts";

interface Serie { date: string; valeur: number; }

interface SeriesData {
    inscriptions:      Serie[];
    trajets:           Serie[];
    reservations:      Serie[];
    revenus:           Serie[];
    inscriptions_mois: { date: string; valeur: number }[];
}

function fmtFCFA(v: number) {
    if (v >= 1_000_000) return `${(v / 1_000_000).toFixed(1)}M F`;
    if (v >= 1_000)     return `${Math.round(v / 1_000)}k F`;
    return `${v} F`;
}

function fmtShort(v: number) {
    if (v >= 1_000) return `${Math.round(v / 1_000)}k`;
    return String(v);
}

export default function AdminStatistiques() {
    const { token } = useAuth();
    const [data,    setData]    = useState<SeriesData | null>(null);
    const [loading, setLoading] = useState(true);
    const [jours,   setJours]   = useState(30);

    const load = useCallback(async () => {
        if (!token) return;
        setLoading(true);
        try {
            const r = await fetch(`${getApiUrl()}/utilisateurs/admin/stats/series/?jours=${jours}`, {
                headers: { Authorization: `Bearer ${token}` },
            });
            if (!r.ok) throw new Error();
            setData(await r.json());
        } catch { /* silencieux */ }
        finally  { setLoading(false); }
    }, [token, jours]);

    useEffect(() => { load(); }, [load]);

    const periodeBtns = [7, 14, 30, 60, 90];

    return (
        <div className="space-y-6">
            <div className="pb-4 border-b border-base-200 flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3">
                <div>
                    <p className="text-xs text-base-content/40 uppercase tracking-widest mb-1">Administration</p>
                    <h1 className="text-2xl font-bold tracking-tight">Statistiques avancées</h1>
                </div>
                <div className="flex gap-2 flex-wrap">
                    {periodeBtns.map(j => (
                        <button key={j} onClick={() => setJours(j)}
                            className={`btn btn-sm rounded-full ${jours === j ? "btn-primary" : "btn-ghost border border-base-200"}`}>
                            {j}j
                        </button>
                    ))}
                </div>
            </div>

            {loading ? (
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    {[1,2,3,4].map(i => <div key={i} className="h-72 bg-base-200 rounded-2xl animate-pulse" />)}
                </div>
            ) : !data ? (
                <div className="alert alert-error">Impossible de charger les statistiques.</div>
            ) : (
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">

                    {/* Inscriptions par jour */}
                    <ChartCard titre="Inscriptions par jour" couleur="#6366f1">
                        <LineChart data={data.inscriptions}>
                            <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
                            <XAxis dataKey="date" tick={{ fontSize: 11 }} tickFormatter={d => d.slice(5)} />
                            <YAxis tick={{ fontSize: 11 }} tickFormatter={fmtShort} />
                            <Tooltip />
                            <Line type="monotone" dataKey="valeur" name="Inscriptions" stroke="#6366f1" strokeWidth={2} dot={false} />
                        </LineChart>
                    </ChartCard>

                    {/* Trajets par jour */}
                    <ChartCard titre="Trajets créés par jour" couleur="#22c55e">
                        <BarChart data={data.trajets}>
                            <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
                            <XAxis dataKey="date" tick={{ fontSize: 11 }} tickFormatter={d => d.slice(5)} />
                            <YAxis tick={{ fontSize: 11 }} tickFormatter={fmtShort} />
                            <Tooltip />
                            <Bar dataKey="valeur" name="Trajets" fill="#22c55e" radius={[3,3,0,0]} />
                        </BarChart>
                    </ChartCard>

                    {/* Réservations par jour */}
                    <ChartCard titre="Réservations par jour" couleur="#f59e0b">
                        <BarChart data={data.reservations}>
                            <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
                            <XAxis dataKey="date" tick={{ fontSize: 11 }} tickFormatter={d => d.slice(5)} />
                            <YAxis tick={{ fontSize: 11 }} tickFormatter={fmtShort} />
                            <Tooltip />
                            <Bar dataKey="valeur" name="Réservations" fill="#f59e0b" radius={[3,3,0,0]} />
                        </BarChart>
                    </ChartCard>

                    {/* Revenus par jour */}
                    <ChartCard titre="Revenus par jour (FCFA)" couleur="#3b82f6">
                        <LineChart data={data.revenus}>
                            <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
                            <XAxis dataKey="date" tick={{ fontSize: 11 }} tickFormatter={d => d.slice(5)} />
                            <YAxis tick={{ fontSize: 11 }} tickFormatter={fmtFCFA} />
                            <Tooltip formatter={(v) => [fmtFCFA(Number(v)), "Revenus"]} />
                            <Line type="monotone" dataKey="valeur" name="Revenus" stroke="#3b82f6" strokeWidth={2} dot={false} />
                        </LineChart>
                    </ChartCard>

                    {/* Inscriptions par mois — pleine largeur */}
                    {data.inscriptions_mois.length > 0 && (
                        <div className="lg:col-span-2">
                            <ChartCard titre="Inscriptions par mois (12 mois)" couleur="#8b5cf6" height={280}>
                                <BarChart data={data.inscriptions_mois}>
                                    <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
                                    <XAxis dataKey="date" tick={{ fontSize: 11 }} />
                                    <YAxis tick={{ fontSize: 11 }} tickFormatter={fmtShort} />
                                    <Tooltip />
                                    <Bar dataKey="valeur" name="Inscriptions" fill="#8b5cf6" radius={[3,3,0,0]} />
                                </BarChart>
                            </ChartCard>
                        </div>
                    )}
                </div>
            )}
        </div>
    );
}

function ChartCard({ titre, couleur, children, height = 220 }: {
    titre: string; couleur: string; children: React.ReactElement; height?: number;
}) {
    return (
        <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
            <div className="px-5 py-4 border-b border-base-200 flex items-center gap-2">
                <div className="w-3 h-3 rounded-full" style={{ background: couleur }} />
                <h3 className="font-semibold text-sm">{titre}</h3>
            </div>
            <div className="px-4 py-4" style={{ height }}>
                <ResponsiveContainer width="100%" height="100%">
                    {children}
                </ResponsiveContainer>
            </div>
        </div>
    );
}
