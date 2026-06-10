"use client";

import { useEffect, useState, useCallback } from "react";
import dynamic from "next/dynamic";
import { api } from "@/src/services/api";

const ChartRevenus = dynamic(() => import("./components/ChartRevenus"), { ssr: false });

// ── Types ─────────────────────────────────────────────────────────────────────

interface Paiement {
    paiement_id:       number;
    reservation_id:    number;
    depart:            string;
    destination:       string;
    date_trajet:       string | null;
    date_paiement:     string | null;
    passager_nom:      string;
    places:            number;
    montant_brut:      number;
    commission_kovoit: number;
    montant_net:       number;
    taux_commission:   number;
    moyen_paiement:    string;
    statut:            string;
}

interface ReponseApi {
    nombre:           number;
    total_brut:       number;
    total_commission: number;
    total_net:        number;
    taux_commission:  number;
    paiements:        Paiement[];
}

interface ChartData {
    date:       string;
    net:        number;
    commission: number;
    brut:       number;
}

type Periode = "mois" | "trimestre" | "annee" | "tout" | "personnalise";

// ── Helpers ───────────────────────────────────────────────────────────────────

const MOYEN_LABEL: Record<string, string> = {
    ESPECE: "Espèces", FLOOZ: "Flooz", TMONEY: "T-Money",
};

function fmtFCFA(v: number) {
    return new Intl.NumberFormat("fr-FR", {
        style: "decimal", maximumFractionDigits: 0,
    }).format(Math.round(v)) + " FCFA";
}

function fmtDate(iso: string | null) {
    if (!iso) return "—";
    return new Date(iso).toLocaleDateString("fr-FR", {
        day: "2-digit", month: "2-digit", year: "numeric",
    });
}

function groupeParMois(paiements: Paiement[]): ChartData[] {
    const map: Record<string, { net: number; commission: number; brut: number }> = {};
    paiements.forEach((p) => {
        const raw = p.date_paiement || p.date_trajet;
        if (!raw) return;
        const d = new Date(raw);
        const key = d.toLocaleDateString("fr-FR", { month: "short", year: "2-digit" });
        if (!map[key]) map[key] = { net: 0, commission: 0, brut: 0 };
        map[key].net        += p.montant_net;
        map[key].commission += p.commission_kovoit;
        map[key].brut       += p.montant_brut;
    });
    return Object.entries(map).map(([date, vals]) => ({ date, ...vals }));
}

function periodeParams(periode: Periode, dateDebut: string, dateFin: string): string {
    const now = new Date();
    const params = new URLSearchParams();
    if (periode === "mois") {
        params.set("mois", String(now.getMonth() + 1));
        params.set("annee", String(now.getFullYear()));
    } else if (periode === "trimestre") {
        const t = Math.floor(now.getMonth() / 3);
        const d1 = new Date(now.getFullYear(), t * 3, 1);
        const d2 = new Date(now.getFullYear(), t * 3 + 3, 0);
        params.set("date_debut", d1.toISOString().slice(0, 10));
        params.set("date_fin",   d2.toISOString().slice(0, 10));
    } else if (periode === "annee") {
        params.set("annee", String(now.getFullYear()));
    } else if (periode === "personnalise" && dateDebut && dateFin) {
        params.set("date_debut", dateDebut);
        params.set("date_fin",   dateFin);
    }
    // "tout" → pas de paramètre = toute l'historique
    return params.toString();
}

// ── Page ─────────────────────────────────────────────────────────────────────

export default function EconomieConducteur() {
    const [periode,   setPeriode]   = useState<Periode>("mois");
    const [dateDebut, setDateDebut] = useState("");
    const [dateFin,   setDateFin]   = useState("");
    const [data,      setData]      = useState<ReponseApi | null>(null);
    const [loading,   setLoading]   = useState(true);
    const [error,     setError]     = useState<string | null>(null);
    const [chartType, setChartType] = useState<"bar" | "line">("bar");

    const load = useCallback(async () => {
        setLoading(true);
        setError(null);
        try {
            const qs = periodeParams(periode, dateDebut, dateFin);
            const res: ReponseApi = await api(
                `/paiements/paiements_conducteur/${qs ? "?" + qs : ""}`,
                "GET"
            );
            setData(res);
        } catch {
            setError("Impossible de charger vos données de revenus.");
        } finally {
            setLoading(false);
        }
    }, [periode, dateDebut, dateFin]);

    useEffect(() => {
        if (periode !== "personnalise") load();
    }, [load, periode]);

    const chartData = data ? groupeParMois(data.paiements) : [];
    const taux      = data?.taux_commission ?? 0.10;

    return (
        <div className="space-y-7">

            {/* ── En-tête ── */}
            <div className="pb-5 border-b border-base-200">
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">Conducteur</p>
                <h1 className="text-2xl font-bold text-base-content tracking-tight">Mes revenus</h1>
                <p className="text-sm text-base-content/40 mt-1">
                    Revenus réels après commission Kovoit ({Math.round(taux * 100)}%)
                </p>
            </div>

            {/* ── Filtres période ── */}
            <div className="flex gap-2 flex-wrap">
                {(["mois", "trimestre", "annee", "tout", "personnalise"] as Periode[]).map((p) => (
                    <button key={p}
                        onClick={() => setPeriode(p)}
                        className={`btn btn-sm rounded-full capitalize transition-all ${
                            periode === p ? "btn-primary" : "btn-ghost border border-base-200"
                        }`}
                    >
                        {p === "mois" ? "Ce mois" : p === "trimestre" ? "Ce trimestre"
                            : p === "annee" ? "Cette année" : p === "tout" ? "Tout" : "Personnalisé"}
                    </button>
                ))}
            </div>

            {/* ── Filtres date personnalisée ── */}
            {periode === "personnalise" && (
                <div className="bg-base-100 rounded-xl border border-base-200 p-4 flex flex-wrap items-end gap-3">
                    <div>
                        <label className="text-xs text-base-content/50 mb-1 block">Du</label>
                        <input type="date" value={dateDebut} onChange={(e) => setDateDebut(e.target.value)}
                            className="input input-bordered input-sm" />
                    </div>
                    <div>
                        <label className="text-xs text-base-content/50 mb-1 block">Au</label>
                        <input type="date" value={dateFin} onChange={(e) => setDateFin(e.target.value)}
                            className="input input-bordered input-sm" />
                    </div>
                    <button onClick={load} disabled={!dateDebut || !dateFin || loading}
                        className="btn btn-primary btn-sm">
                        Filtrer
                    </button>
                </div>
            )}

            {/* ── Erreur ── */}
            {error && (
                <div className="bg-error/5 border border-error/20 rounded-xl p-4 flex items-center gap-3">
                    <p className="text-sm text-error flex-1">{error}</p>
                    <button onClick={load} className="btn btn-error btn-xs rounded-full">Réessayer</button>
                </div>
            )}

            {/* ── Cartes stats ── */}
            {loading ? (
                <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 animate-pulse">
                    {[1,2,3,4].map((i) => <div key={i} className="h-28 bg-base-300 rounded-2xl" />)}
                </div>
            ) : data && (
                <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                    <StatCard
                        label="Net conducteur"
                        value={fmtFCFA(data.total_net)}
                        sub="Ce que vous recevez"
                        couleur="text-green-600"
                        bg="bg-green-50 dark:bg-green-950/20"
                        icon="💰"
                    />
                    <StatCard
                        label="Commission Kovoit"
                        value={fmtFCFA(data.total_commission)}
                        sub={`${Math.round(taux * 100)}% du brut`}
                        couleur="text-amber-600"
                        bg="bg-amber-50 dark:bg-amber-950/20"
                        icon="🏢"
                    />
                    <StatCard
                        label="Total brut"
                        value={fmtFCFA(data.total_brut)}
                        sub="Payé par les passagers"
                        couleur="text-blue-600"
                        bg="bg-blue-50 dark:bg-blue-950/20"
                        icon="📊"
                    />
                    <StatCard
                        label="Transactions"
                        value={String(data.nombre)}
                        sub={data.nombre > 0 ? `Moy. ${fmtFCFA(data.total_net / data.nombre)}/trajet` : "Aucun paiement"}
                        couleur="text-purple-600"
                        bg="bg-purple-50 dark:bg-purple-950/20"
                        icon="🎫"
                    />
                </div>
            )}

            {/* ── Schéma commission ── */}
            {!loading && data && data.total_brut > 0 && (
                <div className="bg-base-100 rounded-2xl border border-base-200 p-5">
                    <h3 className="font-semibold text-sm text-base-content mb-3">
                        Répartition du montant payé par les passagers
                    </h3>
                    <div className="flex items-center gap-2 mb-2">
                        <div className="flex-1 bg-base-200 rounded-full h-5 overflow-hidden flex">
                            <div
                                className="bg-green-500 h-full rounded-l-full transition-all"
                                style={{ width: `${(1 - taux) * 100}%` }}
                            />
                            <div
                                className="bg-amber-400 h-full rounded-r-full transition-all"
                                style={{ width: `${taux * 100}%` }}
                            />
                        </div>
                    </div>
                    <div className="flex justify-between text-xs text-base-content/50">
                        <span className="flex items-center gap-1">
                            <span className="w-2 h-2 rounded-full bg-green-500 inline-block" />
                            Vous ({Math.round((1 - taux) * 100)}%) — {fmtFCFA(data.total_net)}
                        </span>
                        <span className="flex items-center gap-1">
                            Kovoit ({Math.round(taux * 100)}%) — {fmtFCFA(data.total_commission)}
                            <span className="w-2 h-2 rounded-full bg-amber-400 inline-block" />
                        </span>
                    </div>
                </div>
            )}

            {/* ── Graphique ── */}
            {!loading && chartData.length > 0 && (
                <div className="bg-base-100 rounded-2xl border border-base-200">
                    <div className="px-5 py-4 border-b border-base-200 flex items-center justify-between">
                        <h2 className="font-semibold text-sm text-base-content">Évolution des revenus (FCFA)</h2>
                        <div className="flex gap-1">
                            <button onClick={() => setChartType("bar")}
                                className={`btn btn-xs rounded-full ${chartType === "bar" ? "btn-primary" : "btn-ghost border border-base-200"}`}>
                                Barres
                            </button>
                            <button onClick={() => setChartType("line")}
                                className={`btn btn-xs rounded-full ${chartType === "line" ? "btn-primary" : "btn-ghost border border-base-200"}`}>
                                Ligne
                            </button>
                        </div>
                    </div>
                    <div className="px-5 py-4">
                        <ChartRevenus data={chartData} type={chartType} />
                    </div>
                </div>
            )}

            {/* ── Liste des paiements ── */}
            <div className="bg-base-100 rounded-2xl border border-base-200">
                <div className="px-5 py-4 border-b border-base-200">
                    <h2 className="font-semibold text-sm text-base-content">
                        Détail des paiements reçus
                    </h2>
                </div>

                {loading ? (
                    <div className="divide-y divide-base-200">
                        {[1,2,3].map((i) => (
                            <div key={i} className="px-5 py-4 animate-pulse flex gap-4">
                                <div className="flex-1 space-y-2">
                                    <div className="h-4 bg-base-300 rounded w-2/3" />
                                    <div className="h-3 bg-base-300 rounded w-1/3" />
                                </div>
                                <div className="h-10 bg-base-300 rounded w-28" />
                            </div>
                        ))}
                    </div>
                ) : !data || data.paiements.length === 0 ? (
                    <div className="py-16 text-center">
                        <p className="text-4xl mb-3">💳</p>
                        <p className="text-base-content/40 text-sm">Aucun paiement reçu sur cette période.</p>
                    </div>
                ) : (
                    <div className="divide-y divide-base-200">
                        {data.paiements.map((p) => (
                            <PaiementRow key={p.paiement_id} p={p} />
                        ))}
                    </div>
                )}
            </div>
        </div>
    );
}

// ── Sous-composants ───────────────────────────────────────────────────────────

function StatCard({ label, value, sub, couleur, bg, icon }: {
    label: string; value: string; sub: string; couleur: string; bg: string; icon: string;
}) {
    return (
        <div className={`rounded-2xl border border-base-200 p-5 ${bg}`}>
            <div className="flex items-center justify-between mb-1">
                <span className="text-xs text-base-content/40 font-medium uppercase tracking-wide">{label}</span>
                <span className="text-lg">{icon}</span>
            </div>
            <p className={`text-xl font-bold ${couleur} leading-tight mt-2`}>{value}</p>
            <p className="text-xs text-base-content/40 mt-1">{sub}</p>
        </div>
    );
}

function PaiementRow({ p }: { p: Paiement }) {
    return (
        <div className="px-5 py-4 flex flex-col sm:flex-row sm:items-center gap-4">
            <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 flex-wrap">
                    <span className="font-semibold text-sm text-base-content">
                        {p.depart} → {p.destination}
                    </span>
                    <span className="badge badge-xs badge-ghost rounded-full">
                        {MOYEN_LABEL[p.moyen_paiement] ?? p.moyen_paiement}
                    </span>
                </div>
                <div className="flex items-center gap-3 mt-1 flex-wrap text-xs text-base-content/40">
                    <span>Trajet : {fmtDate(p.date_trajet)}</span>
                    <span>Payé le : {fmtDate(p.date_paiement)}</span>
                    <span>Passager : {p.passager_nom}</span>
                    <span>{p.places} place{p.places > 1 ? "s" : ""}</span>
                </div>
            </div>

            <div className="flex items-center gap-4 shrink-0">
                {/* Brut */}
                <div className="text-right">
                    <p className="text-xs text-base-content/40">Brut</p>
                    <p className="text-sm font-medium text-base-content">
                        {new Intl.NumberFormat("fr-FR").format(Math.round(p.montant_brut))} F
                    </p>
                </div>
                {/* Flèche séparateur */}
                <div className="text-base-content/20 text-xs">−</div>
                {/* Commission */}
                <div className="text-right">
                    <p className="text-xs text-base-content/40">Commission</p>
                    <p className="text-sm font-medium text-amber-500">
                        {new Intl.NumberFormat("fr-FR").format(Math.round(p.commission_kovoit))} F
                    </p>
                </div>
                {/* = Net */}
                <div className="w-px h-8 bg-base-200" />
                <div className="text-right min-w-[80px]">
                    <p className="text-xs text-base-content/40">Vous recevez</p>
                    <p className="text-base font-bold text-green-600">
                        {new Intl.NumberFormat("fr-FR").format(Math.round(p.montant_net))} F
                    </p>
                </div>
            </div>
        </div>
    );
}
