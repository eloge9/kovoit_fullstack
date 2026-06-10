"use client";

import { useEffect, useState, useCallback } from "react";
import { useAuth } from "@/src/hooks/useAuth";
import { getApiUrl } from "@/src/utils/apiUtils";

interface Config {
    id: number;
    cle: string;
    valeur: string;
    description: string;
    modifie_par: string | null;
    date_modification: string;
}

const CONFIG_LABELS: Record<string, string> = {
    tarif_moto:              "Tarif moto (FCFA/km)",
    tarif_voiture:           "Tarif voiture (FCFA/km)",
    tarif_minibus:           "Tarif minibus (FCFA/km)",
    tarif_camion:            "Tarif camion (FCFA/km)",
    commission_kovoit:       "Commission KoVoit (%)",
    rayon_recherche_km:      "Rayon de recherche par défaut (km)",
    rayons_disponibles:      "Rayons disponibles (virgule séparés)",
    duree_modif_evaluation:  "Durée modification évaluation (heures)",
    delai_annulation_min:    "Délai annulation réservation (minutes)",
    places_max_reservation:  "Places max par réservation",
};

const CONFIG_GROUPS = [
    { titre: "Tarification", icone: "💰", cles: ["tarif_moto", "tarif_voiture", "tarif_minibus", "tarif_camion"] },
    { titre: "Commission & Finance", icone: "📊", cles: ["commission_kovoit"] },
    { titre: "Recherche", icone: "🔍", cles: ["rayon_recherche_km", "rayons_disponibles"] },
    { titre: "Règles métier", icone: "⚙️", cles: ["duree_modif_evaluation", "delai_annulation_min", "places_max_reservation"] },
];

function fmtDate(iso: string) {
    return new Date(iso).toLocaleString("fr-FR", { day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" });
}

export default function AdminParametres() {
    const { token } = useAuth();
    const [configs,  setConfigs]  = useState<Config[]>([]);
    const [loading,  setLoading]  = useState(true);
    const [editing,  setEditing]  = useState<Record<string, string>>({});
    const [saving,   setSaving]   = useState<Record<string, boolean>>({});
    const [messages, setMessages] = useState<Record<string, { ok: boolean; txt: string }>>({});

    const load = useCallback(async () => {
        if (!token) return;
        setLoading(true);
        try {
            const r = await fetch(`${getApiUrl()}/utilisateurs/admin/config/`, {
                headers: { Authorization: `Bearer ${token}` },
            });
            if (!r.ok) throw new Error();
            setConfigs(await r.json());
        } catch { /* silencieux */ }
        finally  { setLoading(false); }
    }, [token]);

    useEffect(() => { load(); }, [load]);

    function startEdit(c: Config) {
        setEditing(prev => ({ ...prev, [c.cle]: c.valeur }));
    }

    function cancelEdit(cle: string) {
        setEditing(prev => { const n = { ...prev }; delete n[cle]; return n; });
    }

    async function saveConfig(cle: string) {
        const valeur = editing[cle];
        if (valeur === undefined) return;
        setSaving(prev => ({ ...prev, [cle]: true }));
        try {
            const r = await fetch(`${getApiUrl()}/utilisateurs/admin/config/${cle}/update/`, {
                method: "POST",
                headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
                body: JSON.stringify({ valeur }),
            });
            const res = await r.json();
            if (!r.ok) throw new Error(res.error || "Erreur");
            setMessages(prev => ({ ...prev, [cle]: { ok: true, txt: "Sauvegardé." } }));
            setEditing(prev => { const n = { ...prev }; delete n[cle]; return n; });
            await load();
        } catch (e: unknown) {
            const msg = e instanceof Error ? e.message : "Erreur";
            setMessages(prev => ({ ...prev, [cle]: { ok: false, txt: msg } }));
        } finally {
            setSaving(prev => ({ ...prev, [cle]: false }));
            setTimeout(() => setMessages(prev => { const n = { ...prev }; delete n[cle]; return n; }), 3000);
        }
    }

    const byKey = Object.fromEntries(configs.map(c => [c.cle, c]));

    return (
        <div className="space-y-6">
            <div className="pb-4 border-b border-base-200">
                <p className="text-xs text-base-content/40 uppercase tracking-widest mb-1">Administration</p>
                <h1 className="text-2xl font-bold tracking-tight">Paramètres plateforme</h1>
                <p className="text-sm text-base-content/40 mt-1">Configuration globale de KoVoit — chaque modification est auditée.</p>
            </div>

            {loading ? (
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    {[1,2,3,4].map(i => <div key={i} className="h-40 bg-base-200 rounded-2xl animate-pulse" />)}
                </div>
            ) : (
                <div className="space-y-6">
                    {CONFIG_GROUPS.map((group) => (
                        <div key={group.titre} className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                            <div className="px-5 py-4 border-b border-base-200 bg-base-200/30">
                                <h2 className="font-semibold text-sm flex items-center gap-2">
                                    <span>{group.icone}</span> {group.titre}
                                </h2>
                            </div>
                            <div className="divide-y divide-base-200">
                                {group.cles.map((cle) => {
                                    const c = byKey[cle];
                                    if (!c) return null;
                                    const isEditing = cle in editing;
                                    const msg = messages[cle];
                                    return (
                                        <div key={cle} className="px-5 py-4 flex flex-col sm:flex-row sm:items-center gap-3">
                                            <div className="flex-1 min-w-0">
                                                <p className="font-medium text-sm">{CONFIG_LABELS[cle] || cle}</p>
                                                <p className="text-xs text-base-content/40">{c.description}</p>
                                                {c.modifie_par && (
                                                    <p className="text-xs text-base-content/30 mt-0.5">
                                                        Modifié par <strong>{c.modifie_par}</strong> le {fmtDate(c.date_modification)}
                                                    </p>
                                                )}
                                            </div>
                                            <div className="flex items-center gap-2 shrink-0">
                                                {isEditing ? (
                                                    <>
                                                        <input
                                                            type="text"
                                                            value={editing[cle]}
                                                            onChange={(e) => setEditing(prev => ({ ...prev, [cle]: e.target.value }))}
                                                            className="input input-bordered input-sm rounded-xl w-32 text-right"
                                                            onKeyDown={(e) => { if (e.key === "Enter") saveConfig(cle); if (e.key === "Escape") cancelEdit(cle); }}
                                                            autoFocus
                                                        />
                                                        <button onClick={() => saveConfig(cle)} disabled={saving[cle]}
                                                            className="btn btn-success btn-xs rounded-xl">
                                                            {saving[cle] ? <span className="loading loading-spinner loading-xs" /> : "✓"}
                                                        </button>
                                                        <button onClick={() => cancelEdit(cle)}
                                                            className="btn btn-ghost btn-xs rounded-xl">✕</button>
                                                    </>
                                                ) : (
                                                    <>
                                                        <span className="font-bold text-base text-primary min-w-[80px] text-right">
                                                            {c.valeur}
                                                        </span>
                                                        <button onClick={() => startEdit(c)}
                                                            className="btn btn-ghost btn-xs rounded-xl text-xs">
                                                            Modifier
                                                        </button>
                                                    </>
                                                )}
                                                {msg && (
                                                    <span className={`text-xs ${msg.ok ? "text-success" : "text-error"}`}>{msg.txt}</span>
                                                )}
                                            </div>
                                        </div>
                                    );
                                })}
                            </div>
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
}
