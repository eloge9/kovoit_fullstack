"use client";

import { useEffect, useState, useCallback } from "react";
import Link from "next/link";
import { useAuth } from "@/src/hooks/useAuth";
import { getApiUrl } from "@/src/utils/apiUtils";

interface DashData {
    nb_utilisateurs: number;
    nb_conducteurs: number;
    nb_passagers: number;
    nb_inactifs: number;
    nb_trajets: number;
    nb_trajets_ouverts: number;
    nb_trajets_cours: number;
    nb_trajets_termines: number;
    nb_trajets_annules: number;
    nb_trajets_jour: number;
    nb_reservations: number;
    nb_reservations_jour: number;
    nb_reservations_conf: number;
    nb_reservations_att: number;
    nb_paiements_confirmes: number;
    nb_paiements_attente: number;
    ca_jour: number;
    ca_semaine: number;
    ca_mois: number;
    ca_total: number;
    commission_kovoit: number;
    net_conducteurs: number;
    nb_evaluations: number;
    nb_evaluations_signal: number;
    nb_plaintes: number;
    nb_plaintes_attente: number;
    nb_messages: number;
    nb_notifications: number;
}

interface RecentData {
    utilisateurs: { id: string; username: string; role: string; date_joined: string }[];
    trajets: { id: number; depart: string; destination: string; statut: string; conducteur: string; date: string }[];
    reservations: { id: number; passager: string; trajet: string; statut: string; date_reservation: string }[];
    paiements: { id: number; montant: number; commission: number; net: number; statut: string; passager: string; date: string | null }[];
    plaintes: { id: string; titre: string; type: string; statut: string; signalataire: string; date: string }[];
}

function fmtFCFA(v: number) {
    if (v >= 1_000_000) return `${(v / 1_000_000).toFixed(1)}M F`;
    if (v >= 1_000) return `${Math.round(v / 1_000)}k F`;
    return `${v} F`;
}

function fmtDate(iso: string | null) {
    if (!iso) return "—";
    return new Date(iso).toLocaleDateString("fr-FR", { day: "2-digit", month: "2-digit", year: "2-digit" });
}

const STATUT_COLORS: Record<string, string> = {
    ouvert: "badge-success", en_cours: "badge-info", termine: "badge-neutral",
    annule: "badge-error", confirmee: "badge-success", en_attente: "badge-warning",
    declinee: "badge-error", resolue: "badge-success",
};

export default function AdminDashboard() {
    const { user, token } = useAuth();
    const [dash, setDash] = useState<DashData | null>(null);
    const [recent, setRecent] = useState<RecentData | null>(null);
    const [loading, setLoading] = useState(true);

    const load = useCallback(async () => {
        if (!token) return;
        setLoading(true);
        try {
            const [r1, r2] = await Promise.all([
                fetch(`${getApiUrl()}/utilisateurs/admin/dashboard/`, { headers: { Authorization: `Bearer ${token}` } }),
                fetch(`${getApiUrl()}/utilisateurs/admin/recent/?limit=5`, { headers: { Authorization: `Bearer ${token}` } }),
            ]);
            if (r1.ok) setDash(await r1.json());
            if (r2.ok) setRecent(await r2.json());
        } catch { /* silencieux */ }
        finally { setLoading(false); }
    }, [token]);

    useEffect(() => { load(); }, [load]);

    const heure = new Date().getHours();
    const salut = heure < 12 ? "Bonjour" : heure < 18 ? "Bon après-midi" : "Bonsoir";

    if (loading) return (
        <div className="space-y-6">
            <div className="animate-pulse space-y-4">
                <div className="h-28 bg-base-300 rounded-2xl" />
                <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                    {Array.from({ length: 8 }).map((_, i) => <div key={i} className="h-28 bg-base-300 rounded-2xl" />)}
                </div>
            </div>
        </div>
    );

    return (
        <div className="space-y-8">

            {/* En-tête */}
            <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4 pb-6 border-b border-base-300">
                <div>
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">Tableau de bord</p>
                    <h1 className="text-3xl font-bold tracking-tight">{salut}, {user?.first_name || user?.username}</h1>
                    <p className="text-base-content/40 mt-1 text-sm">Vue d'ensemble de la plateforme KoVoit</p>
                </div>
                <button onClick={load} className="btn btn-ghost btn-sm rounded-xl gap-2 self-start sm:self-auto">
                    ↺ Actualiser
                </button>
            </div>

            {dash && <>
                {/* Cartes principales */}
                <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                    <StatCard label="Utilisateurs" value={dash.nb_utilisateurs}
                        sub={`${dash.nb_conducteurs} conducteurs, ${dash.nb_passagers} passagers`}
                        color="blue" href="/admin/utilisateurs" />
                    <StatCard label="Trajets actifs" value={dash.nb_trajets_ouverts + dash.nb_trajets_cours}
                        sub={`${dash.nb_trajets_jour} aujourd'hui`}
                        color="green" href="/admin/trajets" />
                    <StatCard label="Réservations" value={dash.nb_reservations_conf}
                        sub={`${dash.nb_reservations_att} en attente`}
                        color="amber" href="/admin/reservations" />
                    <StatCard label="CA total" value={fmtFCFA(dash.ca_total)}
                        sub={`Commission: ${fmtFCFA(dash.commission_kovoit)}`}
                        color="purple" href="/admin/paiements" />
                </div>

                {/* Finance */}
                <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
                    <h2 className="font-bold text-base mb-5 flex items-center gap-2">Revenus plateforme</h2>
                    <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
                        {[
                            { l: "Aujourd'hui", v: fmtFCFA(dash.ca_jour), c: "text-blue-600" },
                            { l: "Cette semaine", v: fmtFCFA(dash.ca_semaine), c: "text-indigo-600" },
                            { l: "Ce mois", v: fmtFCFA(dash.ca_mois), c: "text-violet-600" },
                            { l: "Total", v: fmtFCFA(dash.ca_total), c: "text-purple-600" },
                        ].map(({ l, v, c }) => (
                            <div key={l} className="text-center">
                                <p className="text-xs text-base-content/40 uppercase tracking-wide">{l}</p>
                                <p className={`text-xl font-bold mt-1 ${c}`}>{v}</p>
                            </div>
                        ))}
                    </div>
                    {/* Barre commission / net */}
                    <div>
                        <div className="flex justify-between text-xs text-base-content/50 mb-1">
                            <span>Commission KoVoit (10%) — {fmtFCFA(dash.commission_kovoit)}</span>
                            <span>Net conducteurs (90%) — {fmtFCFA(dash.net_conducteurs)}</span>
                        </div>
                        <div className="flex h-3 rounded-full overflow-hidden">
                            <div className="bg-amber-500 h-full" style={{ width: "10%" }} />
                            <div className="bg-green-500 h-full flex-1" />
                        </div>
                    </div>
                </div>

                {/* Indicateurs opérationnels */}
                <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                    <MiniCard label="Plaintes en attente" value={dash.nb_plaintes_attente}
                        urgent={dash.nb_plaintes_attente > 0} href="/admin/plaintes" />
                    <MiniCard label="Évals signalées" value={dash.nb_evaluations_signal}
                        urgent={dash.nb_evaluations_signal > 0} href="/admin/evaluations" />
                    <MiniCard label="Comptes inactifs" value={dash.nb_inactifs}
                        urgent={false} href="/admin/utilisateurs" />
                    <MiniCard label="Paiements en attente" value={dash.nb_paiements_attente}
                        urgent={dash.nb_paiements_attente > 5} href="/admin/paiements" />
                </div>
            </>}

            {/* Activité récente */}
            {recent && (
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">

                    {/* Derniers utilisateurs */}
                    <RecentCard titre="Dernières inscriptions" href="/admin/utilisateurs">
                        {recent.utilisateurs.map(u => (
                            <div key={u.id} className="flex items-center justify-between py-2">
                                <div>
                                    <p className="text-sm font-medium">{u.username}</p>
                                    <p className="text-xs text-base-content/40 capitalize">{u.role}</p>
                                </div>
                                <p className="text-xs text-base-content/40">{fmtDate(u.date_joined)}</p>
                            </div>
                        ))}
                    </RecentCard>

                    {/* Derniers trajets */}
                    <RecentCard titre="Derniers trajets" href="/admin/trajets">
                        {recent.trajets.map(t => (
                            <div key={t.id} className="flex items-center justify-between py-2">
                                <div className="min-w-0 flex-1">
                                    <p className="text-sm font-medium truncate">{t.depart} → {t.destination}</p>
                                    <p className="text-xs text-base-content/40">{t.conducteur}</p>
                                </div>
                                <span className={`badge badge-xs ml-3 ${STATUT_COLORS[t.statut] || "badge-ghost"}`}>
                                    {t.statut}
                                </span>
                            </div>
                        ))}
                    </RecentCard>

                    {/* Dernières réservations */}
                    <RecentCard titre="Dernières réservations" href="/admin/reservations">
                        {recent.reservations.map(r => (
                            <div key={r.id} className="flex items-center justify-between py-2">
                                <div className="min-w-0 flex-1">
                                    <p className="text-sm font-medium">{r.passager}</p>
                                    <p className="text-xs text-base-content/40 truncate">{r.trajet}</p>
                                </div>
                                <span className={`badge badge-xs ml-3 ${STATUT_COLORS[r.statut] || "badge-ghost"}`}>
                                    {r.statut.replace("_", " ")}
                                </span>
                            </div>
                        ))}
                    </RecentCard>

                    {/* Dernières plaintes */}
                    <RecentCard titre="Dernières plaintes" href="/admin/plaintes">
                        {recent.plaintes.map(p => (
                            <div key={p.id} className="flex items-center justify-between py-2">
                                <div className="min-w-0 flex-1">
                                    <p className="text-sm font-medium truncate">{p.titre}</p>
                                    <p className="text-xs text-base-content/40">{p.signalataire} · {p.type}</p>
                                </div>
                                <span className={`badge badge-xs ml-3 ${STATUT_COLORS[p.statut] || "badge-ghost"}`}>
                                    {p.statut.replace("_", " ")}
                                </span>
                            </div>
                        ))}
                    </RecentCard>

                </div>
            )}
        </div>
    );
}

function StatCard({ label, value, sub, icon, color, href }: {
    label: string; value: string | number; sub: string; icon: string; color: string; href: string;
}) {
    const COLORS: Record<string, string> = {
        blue: "text-blue-600 bg-blue-50 dark:bg-blue-950/20",
        green: "text-green-600 bg-green-50 dark:bg-green-950/20",
        amber: "text-amber-600 bg-amber-50 dark:bg-amber-950/20",
        purple: "text-purple-600 bg-purple-50 dark:bg-purple-950/20",
    };
    return (
        <Link href={href} className={`rounded-2xl border border-base-200 p-5 ${COLORS[color]} hover:opacity-90 transition-opacity block`}>
            <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-medium uppercase tracking-wide opacity-60">{label}</span>
                <span className="text-xl">{icon}</span>
            </div>
            <p className="text-2xl font-bold leading-tight">
                {typeof value === "number" ? value.toLocaleString("fr-FR") : value}
            </p>
            <p className="text-xs opacity-60 mt-1">{sub}</p>
        </Link>
    );
}

function MiniCard({ label, value, urgent, href }: {
    label: string; value: number; urgent: boolean; href: string;
}) {
    return (
        <Link href={href} className={`rounded-2xl border p-4 hover:opacity-90 transition-opacity block ${urgent ? "border-error/30 bg-error/5" : "border-base-200 bg-base-100"
            }`}>
            <p className="text-xs text-base-content/50 uppercase tracking-wide">{label}</p>
            <p className={`text-3xl font-bold mt-1 ${urgent ? "text-error" : "text-base-content"}`}>
                {value.toLocaleString("fr-FR")}
            </p>
        </Link>
    );
}

function RecentCard({ titre, href, children }: { titre: string; href: string; children: React.ReactNode }) {
    return (
        <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
            <div className="px-5 py-4 border-b border-base-200 flex items-center justify-between">
                <h3 className="font-semibold text-sm">{titre}</h3>
                <Link href={href} className="text-xs text-primary hover:underline">Voir tout</Link>
            </div>
            <div className="px-5 divide-y divide-base-200">
                {children}
            </div>
        </div>
    );
}
