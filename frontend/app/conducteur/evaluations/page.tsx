"use client";

import { useState, useEffect, useCallback } from "react";
import { api } from "@/src/services/api";

// ── Types ─────────────────────────────────────────────────────────────────────

interface PassagerAEvaluer {
    passager_id: string;
    passager_nom: string;
    reservation_id: number;
}

interface TrajetAEvaluer {
    trajet_id: number;
    depart: string;
    destination: string;
    date_trajet: string;
    passagers: PassagerAEvaluer[];
}

interface EvaluationItem {
    id: number;
    auteur: string;
    auteur_id: string;
    cible: string;
    cible_id: string;
    trajet: string;
    trajet_id: number;
    note: number;
    commentaire: string;
    date: string;
    date_limite: string | null;
    statut: "publiee" | "verrouillee";
    signale: boolean;
    modifiable: boolean;
    ponctualite: number | null;
    respect_conducteur: number | null;
    respect_vehicule: number | null;
    communication: number | null;
}

interface Blocage {
    passager_id: string;
    nom: string;
    motif: string;
    bloque_le: string;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const CRITERES_CONDUCTEUR = [
    { key: "ponctualite",        label: "Ponctualité" },
    { key: "respect_conducteur", label: "Respect du conducteur" },
    { key: "respect_vehicule",   label: "Respect du véhicule" },
    { key: "communication",      label: "Communication" },
];

function formatDate(iso: string) {
    return new Date(iso).toLocaleDateString("fr-FR", { day: "numeric", month: "short", year: "numeric" });
}

function tempsRestant(dateLimite: string | null): string | null {
    if (!dateLimite) return null;
    const diff = new Date(dateLimite).getTime() - Date.now();
    if (diff <= 0) return null;
    const h = Math.floor(diff / 3600000);
    const m = Math.floor((diff % 3600000) / 60000);
    return h > 0 ? `${h}h${m > 0 ? m + "min" : ""} restantes` : `${m} min restantes`;
}

// ── Composants ────────────────────────────────────────────────────────────────

function Etoiles({ note, onChange, readonly = false }: {
    note: number; onChange?: (n: number) => void; readonly?: boolean;
}) {
    const [hover, setHover] = useState(0);
    return (
        <div className="flex gap-0.5">
            {[1, 2, 3, 4, 5].map((s) => (
                <button
                    key={s}
                    type="button"
                    disabled={readonly}
                    onClick={() => onChange?.(s)}
                    onMouseEnter={() => !readonly && setHover(s)}
                    onMouseLeave={() => !readonly && setHover(0)}
                    className={`text-xl transition-colors ${
                        s <= (onChange ? (hover || note) : note) ? "text-warning" : "text-base-300"
                    } ${readonly ? "cursor-default" : "cursor-pointer hover:scale-110"}`}
                >
                    ★
                </button>
            ))}
        </div>
    );
}

// ── Formulaire évaluation passager ────────────────────────────────────────────

function FormulairePassager({
    trajet, passager, isEdit, initialNote, initialCommentaire, initialCriteres,
    onSuccess, onCancel,
}: {
    trajet: TrajetAEvaluer;
    passager: PassagerAEvaluer;
    isEdit?: boolean;
    initialNote?: number;
    initialCommentaire?: string;
    initialCriteres?: Record<string, number>;
    evalId?: number;
    onSuccess: () => void;
    onCancel: () => void;
}) {
    const [note, setNote] = useState(initialNote ?? 0);
    const [commentaire, setCommentaire] = useState(initialCommentaire ?? "");
    const [criteres, setCriteres] = useState<Record<string, number>>(
        initialCriteres ?? { ponctualite: 0, respect_conducteur: 0, respect_vehicule: 0, communication: 0 }
    );
    const [submitting, setSubmitting] = useState(false);
    const [error, setError] = useState<string | null>(null);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (note === 0) { setError("Sélectionnez une note."); return; }
        setSubmitting(true);
        setError(null);
        try {
            await api("/evaluations/evaluer/", "POST", {
                trajet_id: trajet.trajet_id,
                cible_id:  passager.passager_id,
                note,
                commentaire,
                ponctualite:        criteres.ponctualite        || undefined,
                respect_conducteur: criteres.respect_conducteur || undefined,
                respect_vehicule:   criteres.respect_vehicule   || undefined,
                communication:      criteres.communication      || undefined,
            });
            onSuccess();
        } catch (err: unknown) {
            const msg = (err as { response?: { data?: { error?: string } } })?.response?.data?.error;
            setError(msg || "Erreur lors de l'envoi.");
        } finally {
            setSubmitting(false);
        }
    };

    return (
        <form onSubmit={handleSubmit} className="bg-base-100 rounded-2xl border border-primary/20 overflow-hidden mt-2">
            <div className="px-5 py-3 border-b border-base-200 flex items-center justify-between">
                <p className="text-sm font-medium text-base-content">Évaluer {passager.passager_nom}</p>
                <button type="button" onClick={onCancel} className="btn btn-ghost btn-xs btn-square rounded-lg">×</button>
            </div>
            <div className="p-5 space-y-4">
                {error && <p className="text-sm text-error">{error}</p>}

                <div className="space-y-1.5">
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">Note générale</p>
                    <Etoiles note={note} onChange={setNote} />
                    {note > 0 && (
                        <p className="text-xs text-base-content/40">
                            {["", "Très mauvais", "Mauvais", "Correct", "Bien", "Excellent"][note]}
                        </p>
                    )}
                </div>

                <div className="space-y-2">
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                        Critères <span className="normal-case font-normal">(optionnel)</span>
                    </p>
                    {CRITERES_CONDUCTEUR.map((c) => (
                        <div key={c.key} className="flex items-center justify-between gap-4">
                            <span className="text-sm text-base-content/60 w-40 shrink-0">{c.label}</span>
                            <Etoiles note={criteres[c.key] ?? 0} onChange={(n) => setCriteres((p) => ({ ...p, [c.key]: n }))} />
                        </div>
                    ))}
                </div>

                <textarea
                    className="textarea textarea-bordered rounded-xl resize-none w-full"
                    rows={2}
                    placeholder="Commentaire (optionnel)…"
                    value={commentaire}
                    onChange={(e) => setCommentaire(e.target.value)}
                />

                <div className="flex gap-2">
                    <button type="button" onClick={onCancel} className="btn btn-ghost btn-sm rounded-full flex-1 border border-base-300">
                        Annuler
                    </button>
                    <button type="submit" disabled={submitting || note === 0} className="btn btn-primary btn-sm rounded-full flex-1">
                        {submitting ? <span className="loading loading-spinner loading-xs" /> : "Envoyer"}
                    </button>
                </div>
            </div>
        </form>
    );
}

// ── Page ─────────────────────────────────────────────────────────────────────

type Onglet = "recues" | "a_evaluer" | "donnees" | "bloques";

export default function ConducteurEvaluationsPage() {
    const [onglet, setOnglet] = useState<Onglet>("recues");
    const [recues, setRecues] = useState<EvaluationItem[]>([]);
    const [donnees, setDonnees] = useState<EvaluationItem[]>([]);
    const [trajetsAEvaluer, setTrajetsAEvaluer] = useState<TrajetAEvaluer[]>([]);
    const [blocages, setBlocages] = useState<Blocage[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    // Quel (trajetId, passagerId) a son formulaire ouvert
    const [formulaireOuvert, setFormulaireOuvert] = useState<{ trajetId: number; passagerId: string } | null>(null);

    // Signalement
    const [signalerOnId, setSignalerOnId] = useState<number | null>(null);
    const [motifSignalement, setMotifSignalement] = useState("");
    const [signalerLoading, setSignalerLoading] = useState(false);

    // Déblocage
    const [debloquerLoading, setDebloquerLoading] = useState<string | null>(null);

    const fetchData = useCallback(async () => {
        setLoading(true);
        setError(null);
        try {
            const [evals, blocs, aEvaluer, donnees_] = await Promise.all([
                api("/evaluations/mes_evaluations/", "GET"),
                api("/evaluations/mes_blocages/", "GET"),
                api("/evaluations/passagers_a_evaluer/", "GET"),
                api("/evaluations/mes_evaluations_donnees/", "GET"),
            ]);
            setRecues(Array.isArray(evals) ? evals : []);
            setBlocages(Array.isArray(blocs) ? blocs : []);
            setTrajetsAEvaluer(Array.isArray(aEvaluer) ? aEvaluer : []);
            setDonnees(Array.isArray(donnees_) ? donnees_ : []);
        } catch {
            setError("Impossible de charger les données.");
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => { fetchData(); }, [fetchData]);

    const noteMoyenne = recues.length > 0
        ? recues.reduce((s, e) => s + e.note, 0) / recues.length
        : 0;

    // Nombre total de passagers encore à évaluer
    const nbPassagersAEvaluer = trajetsAEvaluer.reduce((s, t) => s + t.passagers.length, 0);

    const tabs: { value: Onglet; label: string }[] = [
        { value: "recues",    label: `Reçues (${recues.length})` },
        { value: "a_evaluer", label: `À évaluer (${nbPassagersAEvaluer})` },
        { value: "donnees",   label: `Données (${donnees.length})` },
        { value: "bloques",   label: `Bloqués (${blocages.length})` },
    ];

    const handleSignaler = async (evalId: number) => {
        setSignalerLoading(true);
        try {
            await api("/evaluations/signaler/", "POST", { evaluation_id: evalId, motif: motifSignalement });
            setRecues((prev) => prev.map((e) => e.id === evalId ? { ...e, signale: true } : e));
            setSignalerOnId(null);
            setMotifSignalement("");
        } catch {
            // silencieux
        } finally {
            setSignalerLoading(false);
        }
    };

    const handleDebloquer = async (passagerId: string) => {
        setDebloquerLoading(passagerId);
        try {
            await api(`/evaluations/debloquer/${passagerId}/`, "DELETE");
            setBlocages((prev) => prev.filter((b) => b.passager_id !== passagerId));
        } catch {
            // silencieux
        } finally {
            setDebloquerLoading(null);
        }
    };

    const handleEvalSuccess = async () => {
        setFormulaireOuvert(null);
        await fetchData();
    };

    return (
        <div className="max-w-2xl mx-auto space-y-6">

            {/* En-tête */}
            <div>
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">Réputation</p>
                <h1 className="text-3xl font-bold text-base-content tracking-tight">Évaluations</h1>
                {!loading && recues.length > 0 && (
                    <div className="flex items-center gap-2 mt-2">
                        <Etoiles note={Math.round(noteMoyenne)} readonly />
                        <span className="text-sm text-base-content/60 font-medium">
                            {noteMoyenne.toFixed(1)} / 5 · {recues.length} avis
                        </span>
                    </div>
                )}
            </div>

            {/* Onglets */}
            <div className="flex gap-1 bg-base-200 p-1 rounded-xl overflow-x-auto">
                {tabs.map(({ value, label }) => (
                    <button
                        key={value}
                        onClick={() => setOnglet(value)}
                        className={`flex-1 py-2 px-3 text-sm font-medium rounded-lg transition-all whitespace-nowrap ${
                            onglet === value
                                ? "bg-base-100 text-base-content shadow-sm"
                                : "text-base-content/50 hover:text-base-content"
                        }`}
                    >
                        {label}
                    </button>
                ))}
            </div>

            {error && (
                <div className="bg-error/10 border border-error/20 rounded-xl px-4 py-3">
                    <p className="text-sm text-error">{error}</p>
                </div>
            )}

            {loading && (
                <div className="space-y-3 animate-pulse">
                    {[1, 2, 3].map((i) => <div key={i} className="h-24 bg-base-200 rounded-2xl" />)}
                </div>
            )}

            {/* ── REÇUES ── */}
            {!loading && onglet === "recues" && (
                recues.length === 0 ? (
                    <Vide message="Aucune évaluation reçue" sous="Les avis de vos passagers apparaîtront ici après chaque trajet terminé." />
                ) : (
                    <div className="space-y-3">
                        {recues.map((eval_) => (
                            <div key={eval_.id} className="bg-base-100 rounded-2xl border border-base-200 p-5 space-y-3">
                                <div className="flex items-start justify-between gap-3">
                                    <div>
                                        <p className="font-semibold text-base-content text-sm">{eval_.auteur}</p>
                                        <p className="text-xs text-base-content/40">
                                            {eval_.trajet} · {formatDate(eval_.date)}
                                        </p>
                                    </div>
                                    <Etoiles note={eval_.note} readonly />
                                </div>
                                {eval_.commentaire && (
                                    <p className="text-sm text-base-content/70 italic">"{eval_.commentaire}"</p>
                                )}
                                {eval_.signale ? (
                                    <span className="badge badge-sm badge-ghost rounded-full">Signalé</span>
                                ) : signalerOnId === eval_.id ? (
                                    <div className="space-y-2">
                                        <textarea
                                            className="textarea textarea-bordered w-full text-sm rounded-xl resize-none"
                                            placeholder="Motif du signalement (optionnel)"
                                            rows={2}
                                            value={motifSignalement}
                                            onChange={(e) => setMotifSignalement(e.target.value)}
                                        />
                                        <div className="flex gap-2">
                                            <button onClick={() => handleSignaler(eval_.id)} disabled={signalerLoading}
                                                className="btn btn-error btn-sm rounded-full flex-1">
                                                {signalerLoading ? <span className="loading loading-spinner loading-xs" /> : "Confirmer le signalement"}
                                            </button>
                                            <button onClick={() => { setSignalerOnId(null); setMotifSignalement(""); }}
                                                className="btn btn-ghost btn-sm rounded-full">Annuler</button>
                                        </div>
                                    </div>
                                ) : (
                                    <button onClick={() => setSignalerOnId(eval_.id)}
                                        className="btn btn-ghost btn-xs rounded-full text-base-content/40 hover:text-error">
                                        Signaler comme abusif
                                    </button>
                                )}
                            </div>
                        ))}
                    </div>
                )
            )}

            {/* ── À ÉVALUER ── */}
            {!loading && onglet === "a_evaluer" && (
                trajetsAEvaluer.length === 0 ? (
                    <Vide message="Aucun passager à évaluer" sous="Les passagers de vos trajets terminés apparaîtront ici." />
                ) : (
                    <div className="space-y-4">
                        {trajetsAEvaluer.map((trajet) => (
                            <div key={trajet.trajet_id} className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                                <div className="px-5 py-3 bg-base-200/50 border-b border-base-200">
                                    <p className="font-semibold text-base-content text-sm">
                                        {trajet.depart} <span className="text-base-content/30 mx-1">→</span> {trajet.destination}
                                    </p>
                                    <p className="text-xs text-base-content/40 mt-0.5">{formatDate(trajet.date_trajet)}</p>
                                </div>
                                <div className="divide-y divide-base-200">
                                    {trajet.passagers.map((passager) => {
                                        const formOuvert = formulaireOuvert?.trajetId === trajet.trajet_id
                                            && formulaireOuvert?.passagerId === passager.passager_id;
                                        return (
                                            <div key={passager.passager_id} className="px-5 py-3">
                                                <div className="flex items-center justify-between">
                                                    <p className="text-sm text-base-content">{passager.passager_nom}</p>
                                                    {!formOuvert && (
                                                        <button
                                                            onClick={() => setFormulaireOuvert({ trajetId: trajet.trajet_id, passagerId: passager.passager_id })}
                                                            className="btn btn-primary btn-xs rounded-full px-3"
                                                        >
                                                            Évaluer
                                                        </button>
                                                    )}
                                                </div>
                                                {formOuvert && (
                                                    <FormulairePassager
                                                        trajet={trajet}
                                                        passager={passager}
                                                        onSuccess={handleEvalSuccess}
                                                        onCancel={() => setFormulaireOuvert(null)}
                                                    />
                                                )}
                                            </div>
                                        );
                                    })}
                                </div>
                            </div>
                        ))}
                    </div>
                )
            )}

            {/* ── DONNÉES ── */}
            {!loading && onglet === "donnees" && (
                donnees.length === 0 ? (
                    <Vide message="Aucune évaluation donnée" sous="Les évaluations que vous avez envoyées apparaîtront ici." />
                ) : (
                    <div className="space-y-3">
                        {donnees.map((eval_) => {
                            const restant = tempsRestant(eval_.date_limite);
                            const bientot = restant && eval_.date_limite
                                ? new Date(eval_.date_limite).getTime() - Date.now() < 6 * 3600000 : false;
                            return (
                                <div key={eval_.id} className="bg-base-100 rounded-2xl border border-base-200 p-5 space-y-2">
                                    <div className="flex items-start justify-between gap-3">
                                        <div>
                                            <p className="font-semibold text-base-content text-sm">{eval_.cible}</p>
                                            <p className="text-xs text-base-content/40 mt-0.5">
                                                {eval_.trajet} · {formatDate(eval_.date)}
                                            </p>
                                        </div>
                                        <Etoiles note={eval_.note} readonly />
                                    </div>
                                    {eval_.commentaire && (
                                        <p className="text-sm text-base-content/60 italic">"{eval_.commentaire}"</p>
                                    )}
                                    {eval_.statut === "publiee" && restant && (
                                        <p className={`text-xs font-medium ${bientot ? "text-warning" : "text-info"}`}>
                                            {bientot ? "⚠ " : ""}Modifiable encore {restant}
                                        </p>
                                    )}
                                    {eval_.statut === "verrouillee" && (
                                        <span className="badge badge-sm badge-ghost rounded-full">Verrouillée</span>
                                    )}
                                </div>
                            );
                        })}
                    </div>
                )
            )}

            {/* ── BLOQUÉS ── */}
            {!loading && onglet === "bloques" && (
                blocages.length === 0 ? (
                    <Vide message="Aucun passager bloqué" sous="Vous pouvez bloquer un passager depuis la page de gestion des réservations." />
                ) : (
                    <div className="space-y-3">
                        {blocages.map((b) => (
                            <div key={b.passager_id} className="bg-base-100 rounded-2xl border border-base-200 p-5 flex items-center justify-between gap-4">
                                <div>
                                    <p className="font-semibold text-base-content text-sm">{b.nom}</p>
                                    {b.motif && <p className="text-xs text-base-content/60 mt-0.5">{b.motif}</p>}
                                    <p className="text-xs text-base-content/40 mt-1">
                                        Bloqué le {new Date(b.bloque_le).toLocaleDateString("fr-FR", { day: "numeric", month: "long", year: "numeric" })}
                                    </p>
                                </div>
                                <button onClick={() => handleDebloquer(b.passager_id)} disabled={debloquerLoading === b.passager_id}
                                    className="btn btn-ghost btn-sm rounded-full shrink-0">
                                    {debloquerLoading === b.passager_id ? <span className="loading loading-spinner loading-xs" /> : "Débloquer"}
                                </button>
                            </div>
                        ))}
                    </div>
                )
            )}
        </div>
    );
}

function Vide({ message, sous }: { message: string; sous?: string }) {
    return (
        <div className="bg-base-100 rounded-2xl border border-base-200 p-12 text-center">
            <p className="font-medium text-base-content">{message}</p>
            {sous && <p className="text-sm text-base-content/40 mt-1">{sous}</p>}
        </div>
    );
}
