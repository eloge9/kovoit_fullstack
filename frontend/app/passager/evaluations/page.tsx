"use client";

import { useState, useEffect, useCallback } from "react";
import { api } from "@/src/services/api";

// ── Types ────────────────────────────────────────────────────────────────────

interface TrajetAEvaluer {
    trajet_id: number;
    conducteur_id: string;
    conducteur_nom: string;
    depart: string;
    destination: string;
    date_trajet: string;
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
    courtoisie: number | null;
    conduite: number | null;
    respect_trajet: number | null;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

const CRITERES_PASSAGER = [
    { key: "ponctualite",    label: "Ponctualité" },
    { key: "courtoisie",     label: "Courtoisie" },
    { key: "conduite",       label: "Conduite" },
    { key: "respect_trajet", label: "Respect du trajet" },
];

function formatDate(iso: string) {
    return new Date(iso).toLocaleDateString("fr-FR", {
        day: "numeric", month: "short", year: "numeric",
    });
}

function tempsRestant(dateLimite: string | null): string | null {
    if (!dateLimite) return null;
    const diff = new Date(dateLimite).getTime() - Date.now();
    if (diff <= 0) return null;
    const h = Math.floor(diff / 3600000);
    const m = Math.floor((diff % 3600000) / 60000);
    if (h > 0) return `${h}h${m > 0 ? m + "min" : ""} restantes`;
    return `${m} min restantes`;
}

// ── Composants ────────────────────────────────────────────────────────────────

function Etoiles({ note, onChange, readonly = false }: {
    note: number;
    onChange?: (n: number) => void;
    readonly?: boolean;
}) {
    const [hover, setHover] = useState(0);
    return (
        <div className="flex gap-1">
            {[1, 2, 3, 4, 5].map((s) => (
                <button
                    key={s}
                    type="button"
                    disabled={readonly}
                    onClick={() => onChange?.(s)}
                    onMouseEnter={() => !readonly && setHover(s)}
                    onMouseLeave={() => !readonly && setHover(0)}
                    className={`w-7 h-7 rounded-lg text-xs font-bold transition-all ${
                        s <= (hover || note)
                            ? "bg-warning text-warning-content"
                            : "bg-base-200 text-base-content/30"
                    } ${readonly ? "cursor-default" : "hover:scale-110"}`}
                >
                    {s}
                </button>
            ))}
        </div>
    );
}

function CritereRow({ label, value, onChange }: {
    label: string;
    value: number;
    onChange: (n: number) => void;
}) {
    return (
        <div className="flex items-center justify-between gap-4">
            <span className="text-sm text-base-content/60 w-36 shrink-0">{label}</span>
            <Etoiles note={value} onChange={onChange} />
        </div>
    );
}

// ── Page ─────────────────────────────────────────────────────────────────────

type Onglet = "a_evaluer" | "donnees" | "recues";

export default function EvaluationsPage() {
    const [onglet, setOnglet] = useState<Onglet>("a_evaluer");
    const [trajets, setTrajets] = useState<TrajetAEvaluer[]>([]);
    const [donnees, setDonnees] = useState<EvaluationItem[]>([]);
    const [recues, setRecues] = useState<EvaluationItem[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [success, setSuccess] = useState<string | null>(null);

    // Formulaire créer/modifier
    const [trajetEnCours, setTrajetEnCours] = useState<TrajetAEvaluer | null>(null);
    const [evalEnModif, setEvalEnModif] = useState<EvaluationItem | null>(null);
    const [note, setNote] = useState(0);
    const [commentaire, setCommentaire] = useState("");
    const [criteres, setCriteres] = useState<Record<string, number>>({ ponctualite: 0, courtoisie: 0, conduite: 0, respect_trajet: 0 });
    const [submitting, setSubmitting] = useState(false);

    const fetchData = useCallback(async () => {
        setLoading(true);
        setError(null);
        try {
            const [aEvaluer, mesRecues, mesDonnees] = await Promise.all([
                api("/evaluations/a_evaluer/", "GET"),
                api("/evaluations/mes_evaluations/", "GET"),
                api("/evaluations/mes_evaluations_donnees/", "GET"),
            ]);
            setTrajets(Array.isArray(aEvaluer) ? aEvaluer : []);
            setRecues(Array.isArray(mesRecues) ? mesRecues : []);
            setDonnees(Array.isArray(mesDonnees) ? mesDonnees : []);
        } catch {
            setError("Impossible de charger les évaluations.");
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => { fetchData(); }, [fetchData]);

    const ouvrirFormulaire = (trajet: TrajetAEvaluer) => {
        setTrajetEnCours(trajet);
        setEvalEnModif(null);
        setNote(0);
        setCommentaire("");
        setCriteres({ ponctualite: 0, courtoisie: 0, conduite: 0, respect_trajet: 0 });
        setError(null);
        setSuccess(null);
    };

    const ouvrirModification = (eval_: EvaluationItem) => {
        setEvalEnModif(eval_);
        setTrajetEnCours(null);
        setNote(eval_.note);
        setCommentaire(eval_.commentaire);
        setCriteres({
            ponctualite:    eval_.ponctualite    ?? 0,
            courtoisie:     eval_.courtoisie     ?? 0,
            conduite:       eval_.conduite       ?? 0,
            respect_trajet: eval_.respect_trajet ?? 0,
        } as Record<string, number>);
        setError(null);
        setSuccess(null);
    };

    const handleSoumettre = async (e: React.FormEvent) => {
        e.preventDefault();
        if (note === 0) { setError("Sélectionnez une note globale."); return; }
        setSubmitting(true);
        setError(null);

        const payload = {
            note,
            commentaire,
            ponctualite:    criteres.ponctualite    || undefined,
            courtoisie:     criteres.courtoisie     || undefined,
            conduite:       criteres.conduite       || undefined,
            respect_trajet: criteres.respect_trajet || undefined,
        };

        try {
            if (evalEnModif) {
                await api(`/evaluations/modifier/${evalEnModif.id}/`, "PUT", payload);
                setSuccess("Évaluation mise à jour.");
            } else if (trajetEnCours) {
                await api("/evaluations/evaluer/", "POST", {
                    trajet_id: trajetEnCours.trajet_id,
                    cible_id:  trajetEnCours.conducteur_id,
                    ...payload,
                });
                setSuccess("Évaluation envoyée.");
                setTrajets((prev) => prev.filter((t) => t.trajet_id !== trajetEnCours.trajet_id));
            }
            setTrajetEnCours(null);
            setEvalEnModif(null);
            setNote(0);
            setCommentaire("");
            setCriteres({ ponctualite: 0, courtoisie: 0, conduite: 0, respect_trajet: 0 });
            fetchData();
        } catch (err: unknown) {
            const msg = (err as { response?: { data?: { error?: string } } })?.response?.data?.error;
            setError(msg || "Erreur lors de l'envoi.");
        } finally {
            setSubmitting(false);
        }
    };

    const fermerFormulaire = () => {
        setTrajetEnCours(null);
        setEvalEnModif(null);
        setError(null);
    };

    const tabs: { value: Onglet; label: string }[] = [
        { value: "a_evaluer", label: `À évaluer (${trajets.length})` },
        { value: "donnees",   label: `Données (${donnees.length})` },
        { value: "recues",    label: `Reçues (${recues.length})` },
    ];

    return (
        <div className="space-y-8">

            {/* En-tête */}
            <div className="pb-6 border-b border-base-300">
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">Passager</p>
                <h1 className="text-2xl font-bold text-base-content tracking-tight">Évaluations</h1>
            </div>

            {/* Onglets */}
            <div className="flex gap-1 bg-base-200 rounded-xl p-1">
                {tabs.map((tab) => (
                    <button
                        key={tab.value}
                        onClick={() => { setOnglet(tab.value); fermerFormulaire(); setSuccess(null); }}
                        className={`flex-1 btn btn-sm rounded-lg transition-all ${
                            onglet === tab.value ? "btn-primary shadow-sm" : "btn-ghost"
                        }`}
                    >
                        {tab.label}
                    </button>
                ))}
            </div>

            {/* Messages */}
            {error && (
                <div className="bg-error/10 border border-error/20 rounded-xl px-4 py-3">
                    <p className="text-sm text-error">{error}</p>
                </div>
            )}
            {success && (
                <div className="bg-success/10 border border-success/20 rounded-xl px-4 py-3">
                    <p className="text-sm text-success">{success}</p>
                </div>
            )}

            {/* ── À ÉVALUER ── */}
            {onglet === "a_evaluer" && (
                <div className="space-y-4">
                    {loading ? <Squelette /> : trajets.length === 0 ? (
                        <Vide message="Aucun trajet à évaluer pour le moment." sous="Les évaluations sont disponibles après la fin du trajet." />
                    ) : trajets.map((trajet) => (
                        <div key={trajet.trajet_id}>
                            {trajetEnCours?.trajet_id !== trajet.trajet_id && (
                                <div className="bg-base-100 rounded-2xl border border-base-200 flex items-center justify-between px-5 py-4">
                                    <div>
                                        <p className="font-semibold text-base-content text-sm">
                                            {trajet.depart} <span className="text-base-content/25 mx-1">→</span> {trajet.destination}
                                        </p>
                                        <p className="text-xs text-base-content/40 mt-0.5">
                                            Conducteur : {trajet.conducteur_nom} · {formatDate(trajet.date_trajet)}
                                        </p>
                                    </div>
                                    <button
                                        onClick={() => ouvrirFormulaire(trajet)}
                                        className="btn btn-primary btn-sm rounded-full px-4"
                                    >
                                        Évaluer
                                    </button>
                                </div>
                            )}
                            {trajetEnCours?.trajet_id === trajet.trajet_id && (
                                <FormulaireEval
                                    titre={`${trajet.depart} → ${trajet.destination}`}
                                    sous={`Évaluer ${trajet.conducteur_nom}`}
                                    note={note}
                                    setNote={setNote}
                                    commentaire={commentaire}
                                    setCommentaire={setCommentaire}
                                    criteres={criteres}
                                    setCriteres={setCriteres}
                                    submitting={submitting}
                                    onSubmit={handleSoumettre}
                                    onCancel={fermerFormulaire}
                                />
                            )}
                        </div>
                    ))}
                </div>
            )}

            {/* ── DONNÉES ── */}
            {onglet === "donnees" && (
                <div className="space-y-3">
                    {loading ? <Squelette /> : donnees.length === 0 ? (
                        <Vide message="Vous n'avez pas encore donné d'évaluation." />
                    ) : donnees.map((eval_) => (
                        <div key={eval_.id}>
                            {evalEnModif?.id === eval_.id ? (
                                <FormulaireEval
                                    titre={eval_.trajet}
                                    sous={`Modifier l'évaluation de ${eval_.cible}`}
                                    note={note}
                                    setNote={setNote}
                                    commentaire={commentaire}
                                    setCommentaire={setCommentaire}
                                    criteres={criteres}
                                    setCriteres={setCriteres}
                                    submitting={submitting}
                                    onSubmit={handleSoumettre}
                                    onCancel={fermerFormulaire}
                                    isEdit
                                />
                            ) : (
                                <CarteDonnee eval_={eval_} onModifier={() => ouvrirModification(eval_)} />
                            )}
                        </div>
                    ))}
                </div>
            )}

            {/* ── REÇUES ── */}
            {onglet === "recues" && (
                <div className="space-y-3">
                    {loading ? <Squelette /> : recues.length === 0 ? (
                        <Vide message="Vous n'avez pas encore reçu d'évaluation." />
                    ) : recues.map((eval_) => (
                        <CarteRecue key={eval_.id} eval_={eval_} onSignalOk={() => fetchData()} />
                    ))}
                </div>
            )}
        </div>
    );
}

// ── Formulaire réutilisable ───────────────────────────────────────────────────

function FormulaireEval({ titre, sous, note, setNote, commentaire, setCommentaire, criteres, setCriteres, submitting, onSubmit, onCancel, isEdit }: {
    titre: string;
    sous: string;
    note: number;
    setNote: (n: number) => void;
    commentaire: string;
    setCommentaire: (s: string) => void;
    criteres: Record<string, number>;
    setCriteres: React.Dispatch<React.SetStateAction<Record<string, number>>>;
    submitting: boolean;
    onSubmit: (e: React.FormEvent) => void;
    onCancel: () => void;
    isEdit?: boolean;
}) {
    return (
        <form onSubmit={onSubmit} className="bg-base-100 rounded-2xl border border-primary/20 overflow-hidden">
            <div className="px-5 py-4 border-b border-base-200 flex items-center justify-between">
                <div>
                    <p className="font-semibold text-base-content text-sm">{titre}</p>
                    <p className="text-xs text-base-content/40">{sous}</p>
                </div>
                <button type="button" onClick={onCancel} className="btn btn-ghost btn-xs btn-square rounded-lg">×</button>
            </div>
            <div className="p-5 space-y-5">
                {/* Note globale */}
                <div className="space-y-2">
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">Note générale</p>
                    <Etoiles note={note} onChange={setNote} />
                    {note > 0 && (
                        <p className="text-xs text-base-content/40">
                            {["", "Très mauvais", "Mauvais", "Correct", "Bien", "Excellent"][note]}
                        </p>
                    )}
                </div>

                {/* Critères */}
                <div className="space-y-3">
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                        Critères détaillés <span className="normal-case font-normal">(optionnel)</span>
                    </p>
                    {CRITERES_PASSAGER.map((c) => (
                        <CritereRow
                            key={c.key}
                            label={c.label}
                            value={criteres[c.key] ?? 0}
                            onChange={(n) => setCriteres((prev) => ({ ...prev, [c.key]: n }))}
                        />
                    ))}
                </div>

                {/* Commentaire */}
                <div className="form-control">
                    <label className="label py-1">
                        <span className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                            Commentaire <span className="normal-case font-normal">(optionnel)</span>
                        </span>
                    </label>
                    <textarea
                        className="textarea textarea-bordered rounded-xl resize-none"
                        rows={3}
                        placeholder="Partagez votre expérience…"
                        value={commentaire}
                        onChange={(e) => setCommentaire(e.target.value)}
                    />
                </div>

                <div className="flex gap-3">
                    <button type="button" onClick={onCancel} className="btn btn-ghost btn-sm rounded-full flex-1 border border-base-300">
                        Annuler
                    </button>
                    <button type="submit" disabled={submitting || note === 0} className="btn btn-primary btn-sm rounded-full flex-1">
                        {submitting
                            ? <span className="loading loading-spinner loading-xs" />
                            : isEdit ? "Enregistrer les modifications" : "Envoyer l'évaluation"
                        }
                    </button>
                </div>
            </div>
        </form>
    );
}

// ── Carte évaluation donnée ───────────────────────────────────────────────────

function CarteDonnee({ eval_, onModifier }: { eval_: EvaluationItem; onModifier: () => void }) {
    const restant = tempsRestant(eval_.date_limite);
    const bientotVerrouillee = restant && eval_.date_limite
        ? new Date(eval_.date_limite).getTime() - Date.now() < 6 * 3600000
        : false;

    return (
        <div className="bg-base-100 rounded-2xl border border-base-200 p-5 space-y-2">
            <div className="flex items-start justify-between gap-3">
                <div>
                    <p className="font-semibold text-base-content text-sm">{eval_.cible}</p>
                    <p className="text-xs text-base-content/40 mt-0.5">{eval_.trajet} · {formatDate(eval_.date)}</p>
                </div>
                <div className="flex items-center gap-1 shrink-0">
                    {[1, 2, 3, 4, 5].map((s) => (
                        <span key={s} className={`text-sm ${s <= eval_.note ? "text-warning" : "text-base-300"}`}>★</span>
                    ))}
                </div>
            </div>

            {eval_.commentaire && (
                <p className="text-sm text-base-content/60 italic">"{eval_.commentaire}"</p>
            )}

            {/* Indicateur temps restant */}
            {eval_.statut === "publiee" && restant && (
                <p className={`text-xs font-medium ${bientotVerrouillee ? "text-warning" : "text-info"}`}>
                    {bientotVerrouillee ? "⚠ " : ""}Modifiable encore {restant}
                </p>
            )}
            {eval_.statut === "verrouillee" && (
                <span className="badge badge-sm badge-ghost rounded-full">Verrouillée</span>
            )}

            {eval_.modifiable && (
                <button onClick={onModifier} className="btn btn-ghost btn-xs rounded-full text-base-content/40 hover:text-primary">
                    Modifier
                </button>
            )}
        </div>
    );
}

// ── Carte évaluation reçue ────────────────────────────────────────────────────

function CarteRecue({ eval_, onSignalOk }: { eval_: EvaluationItem; onSignalOk: () => void }) {
    const [showSignal, setShowSignal] = useState(false);
    const [motif, setMotif] = useState("");
    const [loading, setLoading] = useState(false);
    const [signale, setSignale] = useState(eval_.signale);

    const handleSignaler = async () => {
        setLoading(true);
        try {
            await api("/evaluations/signaler/", "POST", { evaluation_id: eval_.id, motif });
            setSignale(true);
            setShowSignal(false);
            onSignalOk();
        } catch {
            // silencieux
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="bg-base-100 rounded-2xl border border-base-200 p-5 space-y-3">
            <div className="flex items-start justify-between gap-4">
                <div>
                    <p className="text-sm font-semibold text-base-content">{eval_.auteur}</p>
                    <p className="text-xs text-base-content/40 mt-0.5">{eval_.trajet} · {formatDate(eval_.date)}</p>
                </div>
                <div className="flex gap-0.5 shrink-0">
                    {[1, 2, 3, 4, 5].map((s) => (
                        <span key={s} className={`text-sm ${s <= eval_.note ? "text-warning" : "text-base-300"}`}>★</span>
                    ))}
                </div>
            </div>

            {eval_.commentaire && (
                <p className="text-sm text-base-content/60 bg-base-200/50 rounded-xl px-4 py-3 italic">
                    "{eval_.commentaire}"
                </p>
            )}

            {signale ? (
                <p className="text-xs text-success">✓ Signalée — notre équipe va l'examiner.</p>
            ) : !showSignal ? (
                <button onClick={() => setShowSignal(true)} className="btn btn-ghost btn-xs rounded-full text-base-content/40 hover:text-error">
                    Signaler comme abusive
                </button>
            ) : (
                <div className="space-y-2">
                    <textarea value={motif} onChange={(e) => setMotif(e.target.value)}
                        placeholder="Motif du signalement (facultatif)…"
                        className="textarea textarea-bordered textarea-xs w-full rounded-xl" rows={2} />
                    <div className="flex gap-2">
                        <button onClick={() => setShowSignal(false)} className="btn btn-ghost btn-xs rounded-full">Annuler</button>
                        <button onClick={handleSignaler} disabled={loading} className="btn btn-error btn-xs rounded-full">
                            {loading ? <span className="loading loading-spinner loading-xs" /> : "Confirmer"}
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
}

// ── Utilitaires ───────────────────────────────────────────────────────────────

function Squelette() {
    return (
        <div className="space-y-3 animate-pulse">
            {[1, 2, 3].map((i) => <div key={i} className="h-20 bg-base-200 rounded-2xl" />)}
        </div>
    );
}

function Vide({ message, sous }: { message: string; sous?: string }) {
    return (
        <div className="bg-base-100 rounded-2xl border border-base-200 p-12 text-center">
            <p className="text-base-content/40 text-sm">{message}</p>
            {sous && <p className="text-base-content/30 text-xs mt-1">{sous}</p>}
        </div>
    );
}
