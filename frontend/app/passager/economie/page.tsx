"use client";

import { useEffect, useState, useCallback } from "react";
import dynamic from "next/dynamic";
import Link from "next/link";
import { api } from "@/src/services/api";
import { useAuth } from "@/src/hooks/useAuth";

const ChartEconomies = dynamic(() => import("./components/ChartEconomies"), { ssr: false });

// ── Types ─────────────────────────────────────────────────────────────────────

interface DetailReservation {
    reservation_id:       number;
    trajet:               string;
    date:                 string;
    distance_km:          number;
    type_vehicule:        string;
    places_reservees:     number;
    prix_kovoit_total:    number;
    prix_reference_total: number;
    economie:             number;
    pourcentage_economie: number;
    reference_type:       string;  // "Gozem" | "Taxi"
}

interface EconomiesData {
    periode:                    string;
    total_economie:             number;
    total_depense_kovoit:       number;
    total_depense_reference:    number;
    nombre_reservations:        number;
    economie_moyenne_reservation: number;
    details_reservations:       DetailReservation[];
}

interface ChartData {
    date:        string;
    economies:   number;
    reservations: number;
}

type Periode = "tous" | "mois" | "annee" | "semaine" | "personnalise";

// ── Helpers ───────────────────────────────────────────────────────────────────

const TYPE_ICON: Record<string, string> = {
    moto: "🏍️", voiture: "🚗", minibus: "🚌", camion: "🚚",
};

function fmtFCFA(v: number) {
    return new Intl.NumberFormat("fr-FR", { maximumFractionDigits: 0 }).format(Math.round(v)) + " FCFA";
}

function fmtDate(iso: string) {
    return new Date(iso).toLocaleDateString("fr-FR", {
        day: "2-digit", month: "2-digit", year: "numeric",
    });
}

function buildChartData(details: DetailReservation[]): ChartData[] {
    const map: Record<string, { economies: number; reservations: number }> = {};
    details.forEach((d) => {
        const key = new Date(d.date).toLocaleDateString("fr-FR", { month: "short", year: "2-digit" });
        if (!map[key]) map[key] = { economies: 0, reservations: 0 };
        map[key].economies   += d.economie;
        map[key].reservations += 1;
    });
    return Object.entries(map).map(([date, v]) => ({ date, ...v }));
}

function buildParams(periode: Periode, debut: string, fin: string): string {
    const p = new URLSearchParams();
    const now = new Date();
    if (periode === "mois") {
        p.set("mois",  String(now.getMonth() + 1));
        p.set("annee", String(now.getFullYear()));
    } else if (periode === "annee") {
        p.set("annee", String(now.getFullYear()));
    } else if (periode === "semaine") {
        const dow = now.getDay();
        const lundi = new Date(now);
        lundi.setDate(now.getDate() - ((dow + 6) % 7));
        const dim = new Date(lundi);
        dim.setDate(lundi.getDate() + 6);
        p.set("date_debut", lundi.toISOString().slice(0, 10));
        p.set("date_fin",   dim.toISOString().slice(0, 10));
    } else if (periode === "personnalise" && debut && fin) {
        p.set("date_debut", debut);
        p.set("date_fin",   fin);
    }
    // "tous" → pas de paramètre
    return p.toString();
}

// ── Page ─────────────────────────────────────────────────────────────────────

export default function EconomiePassager() {
    const { token, loading: authLoading } = useAuth();
    const [periode,   setPeriode]   = useState<Periode>("tous");
    const [dateDebut, setDateDebut] = useState("");
    const [dateFin,   setDateFin]   = useState("");
    const [data,      setData]      = useState<EconomiesData | null>(null);
    const [loading,   setLoading]   = useState(true);
    const [error,     setError]     = useState<string | null>(null);

    const load = useCallback(async () => {
        if (!token) return;
        setLoading(true);
        setError(null);
        try {
            const qs = buildParams(periode, dateDebut, dateFin);
            const res: EconomiesData = await api(
                `/economie/mes_economies/${qs ? "?" + qs : ""}`,
                "GET"
            );
            setData(res);
        } catch {
            setError("Impossible de charger vos économies.");
        } finally {
            setLoading(false);
        }
    }, [token, periode, dateDebut, dateFin]);

    useEffect(() => {
        if (periode !== "personnalise") load();
    }, [load, periode]);

    // ── Attente auth ──
    if (authLoading) return (
        <div className="flex items-center justify-center min-h-96">
            <span className="loading loading-spinner loading-lg" />
        </div>
    );

    if (!token) return (
        <div className="flex flex-col items-center justify-center min-h-96 gap-4 text-center">
            <p className="text-5xl">🔒</p>
            <p className="font-semibold text-base-content">Connexion requise</p>
            <p className="text-sm text-base-content/50">Connectez-vous pour voir vos économies.</p>
            <Link href="/auth/connexion" className="btn btn-primary btn-sm rounded-full">Se connecter</Link>
        </div>
    );

    const chartData = data ? buildChartData(data.details_reservations) : [];
    const pctEco    = data && data.total_depense_reference > 0
        ? (data.total_economie / data.total_depense_reference) * 100 : 0;

    return (
        <div className="space-y-7">

            {/* ── En-tête ── */}
            <div className="pb-5 border-b border-base-200">
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">Passager</p>
                <h1 className="text-2xl font-bold text-base-content tracking-tight">Mes économies</h1>
                <p className="text-sm text-base-content/40 mt-1">
                    Économies réalisées par rapport au prix Gozem / Taxi
                </p>
            </div>

            {/* ── Filtres ── */}
            <div className="flex gap-2 flex-wrap">
                {(["tous", "semaine", "mois", "annee", "personnalise"] as Periode[]).map((p) => (
                    <button key={p} onClick={() => setPeriode(p)}
                        className={`btn btn-sm rounded-full capitalize transition-all ${
                            periode === p ? "btn-primary" : "btn-ghost border border-base-200"
                        }`}>
                        {p === "tous" ? "Tout" : p === "semaine" ? "Cette semaine"
                            : p === "mois" ? "Ce mois" : p === "annee" ? "Cette année" : "Personnalisé"}
                    </button>
                ))}
            </div>

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
                        className="btn btn-primary btn-sm">Filtrer</button>
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
                    <StatCard label="Économies totales"
                        value={fmtFCFA(data.total_economie)}
                        sub="Vs Gozem / Taxi"
                        couleur="text-green-600"
                        bg="bg-green-50 dark:bg-green-950/20"
                        icon="💚" />
                    <StatCard label="Dépensé via Kovoit"
                        value={fmtFCFA(data.total_depense_kovoit)}
                        sub="Total payé sur l'app"
                        couleur="text-blue-600"
                        bg="bg-blue-50 dark:bg-blue-950/20"
                        icon="💳" />
                    <StatCard label="Prix Gozem / Taxi"
                        value={fmtFCFA(data.total_depense_reference)}
                        sub="Ce qu'aurait coûté un taxi"
                        couleur="text-orange-600"
                        bg="bg-orange-50 dark:bg-orange-950/20"
                        icon="🚕" />
                    <StatCard label="Économie moyenne"
                        value={`${pctEco.toFixed(1)} %`}
                        sub={data.nombre_reservations > 0
                            ? `${data.nombre_reservations} réservation${data.nombre_reservations > 1 ? "s" : ""}`
                            : "Aucune réservation"}
                        couleur="text-emerald-600"
                        bg="bg-emerald-50 dark:bg-emerald-950/20"
                        icon="📈" />
                </div>
            )}

            {/* ── Graphique ── */}
            {!loading && chartData.length > 0 && (
                <div className="bg-base-100 rounded-2xl border border-base-200">
                    <div className="px-5 py-4 border-b border-base-200">
                        <h2 className="font-semibold text-sm text-base-content">Évolution des économies (FCFA)</h2>
                    </div>
                    <div className="px-5 py-4">
                        <ChartEconomies data={chartData} type="bar" />
                    </div>
                </div>
            )}

            {/* ── Liste des réservations ── */}
            <div className="bg-base-100 rounded-2xl border border-base-200">
                <div className="px-5 py-4 border-b border-base-200">
                    <h2 className="font-semibold text-sm text-base-content">Détail par réservation</h2>
                </div>

                {loading ? (
                    <div className="divide-y divide-base-200">
                        {[1,2,3].map((i) => (
                            <div key={i} className="px-5 py-4 animate-pulse flex gap-4">
                                <div className="flex-1 space-y-2">
                                    <div className="h-4 bg-base-300 rounded w-2/3" />
                                    <div className="h-3 bg-base-300 rounded w-1/3" />
                                </div>
                                <div className="h-10 bg-base-300 rounded w-32" />
                            </div>
                        ))}
                    </div>
                ) : !data || data.details_reservations.length === 0 ? (
                    <div className="py-16 text-center">
                        <p className="text-4xl mb-3">🛣️</p>
                        <p className="text-base-content/40 text-sm">Aucune réservation sur cette période.</p>
                        <Link href="/passager/trajets" className="btn btn-primary btn-sm rounded-full mt-4">
                            Chercher un trajet
                        </Link>
                    </div>
                ) : (
                    <div className="divide-y divide-base-200">
                        {data.details_reservations.map((r) => (
                            <ReservationRow key={r.reservation_id} r={r} />
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

function ReservationRow({ r }: { r: DetailReservation }) {
    return (
        <div className="px-5 py-4 flex flex-col sm:flex-row sm:items-center gap-4">
            <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 flex-wrap">
                    <span className="text-base">{TYPE_ICON[r.type_vehicule] ?? "🚗"}</span>
                    <span className="font-semibold text-sm text-base-content">{r.trajet}</span>
                </div>
                <div className="flex items-center gap-3 mt-1 flex-wrap text-xs text-base-content/40">
                    <span>{fmtDate(r.date)}</span>
                    {r.distance_km > 0 && <span>{r.distance_km} km</span>}
                    <span>{r.places_reservees} place{r.places_reservees > 1 ? "s" : ""}</span>
                    <span className="capitalize">{r.reference_type}</span>
                </div>
            </div>

            <div className="flex items-center gap-4 shrink-0">
                {/* Prix Kovoit */}
                <div className="text-right">
                    <p className="text-xs text-base-content/40">Prix Kovoit</p>
                    <p className="text-sm font-medium text-blue-600">
                        {new Intl.NumberFormat("fr-FR").format(Math.round(r.prix_kovoit_total))} F
                    </p>
                </div>
                {/* Prix référence */}
                <div className="text-right">
                    <p className="text-xs text-base-content/40">{r.reference_type}</p>
                    <p className="text-sm font-medium text-orange-500">
                        {new Intl.NumberFormat("fr-FR").format(Math.round(r.prix_reference_total))} F
                    </p>
                </div>
                {/* Séparateur */}
                <div className="w-px h-8 bg-base-200" />
                {/* Économie */}
                <div className="text-right min-w-[80px]">
                    <p className="text-xs text-base-content/40">Économie</p>
                    <p className="text-base font-bold text-green-600">
                        {new Intl.NumberFormat("fr-FR").format(Math.round(r.economie))} F
                    </p>
                    {r.pourcentage_economie > 0 && (
                        <p className="text-xs text-green-500">{r.pourcentage_economie.toFixed(1)} %</p>
                    )}
                </div>
            </div>
        </div>
    );
}
