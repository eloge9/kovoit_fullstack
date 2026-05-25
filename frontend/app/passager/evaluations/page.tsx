"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { api } from "@/src/services/api";

interface TrajetAEvaluer {
    trajet_id: number;
    conducteur_id: string;
    conducteur_nom: string;
    depart: string;
    destination: string;
    date_trajet: string;
}

interface EvaluationRecue {
    id: number;
    auteur: string;
    trajet: string;
    note: number;
    commentaire: string;
    date: string;
}

const CRITERES = [
    { key: "ponctualite", label: "Ponctualité" },
    { key: "conduite", label: "Conduite" },
    { key: "proprete", label: "Propreté" },
];

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
                    className={`w-8 h-8 rounded-lg transition-all ${s <= (hover || note)
                        ? "bg-warning text-warning-content"
                        : "bg-base-200 text-base-content/20"
                        } ${readonly ? "cursor-default" : "hover:scale-110"}`}
                >
                    <span className="text-sm font-bold">{s}</span>
                </button>
            ))}
        </div>
    );
}

export default function EvaluationsPage() {
    const router = useRouter();

    const [onglet, setOnglet] = useState<"a_evaluer" | "recues">("a_evaluer");
    const [trajets, setTrajets] = useState<TrajetAEvaluer[]>([]);
    const [recues, setRecues] = useState<EvaluationRecue[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [success, setSuccess] = useState<string | null>(null);

    // Formulaire évaluation
    const [trajetEnCours, setTrajetEnCours] = useState<TrajetAEvaluer | null>(null);
    const [note, setNote] = useState(0);
    const [commentaire, setCommentaire] = useState("");
    const [criteres, setCriteres] = useState({
        ponctualite: 0,
        conduite: 0,
        proprete: 0,
    });
    const [submitting, setSubmitting] = useState(false);

    useEffect(() => {
        fetchData();
    }, []);

    const fetchData = async () => {
        setLoading(true);
        try {
            const [aEvaluer, mesEvals] = await Promise.all([
                api("/evaluations/a_evaluer/", "GET"),
                api("/evaluations/mes_evaluations/", "GET"),
            ]);
            setTrajets(Array.isArray(aEvaluer) ? aEvaluer : []);
            setRecues(Array.isArray(mesEvals) ? mesEvals : []);
        } catch {
            setError("Impossible de charger les évaluations.");
        } finally {
            setLoading(false);
        }
    };

    const handleSoumettre = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!trajetEnCours) return;
        if (note === 0) return setError("Sélectionnez une note.");

        setSubmitting(true);
        setError(null);
        try {
            await api("/evaluations/evaluer/", "POST", {
                trajet_id: trajetEnCours.trajet_id,
                cible_id: trajetEnCours.conducteur_id,
                note,
                commentaire,
                ponctualite: criteres.ponctualite || undefined,
                conduite: criteres.conduite || undefined,
                proprete: criteres.proprete || undefined,
            });

            setSuccess("Évaluation envoyée avec succès.");
            setTrajetEnCours(null);
            setNote(0);
            setCommentaire("");
            setCriteres({ ponctualite: 0, conduite: 0, proprete: 0 });

            // Retirer le trajet de la liste
            setTrajets((prev) => prev.filter((t) => t.trajet_id !== trajetEnCours.trajet_id));
            fetchData();
        } catch (err: any) {
            setError(err.response?.data?.error || "Erreur lors de l'envoi.");
        } finally {
            setSubmitting(false);
        }
    };

    const formatDate = (iso: string) =>
        new Date(iso).toLocaleDateString("fr-FR", {
            day: "numeric", month: "short", year: "numeric",
        });

    return (
        <div className="space-y-8">

            {/* EN-TÊTE */}
            <div className="pb-6 border-b border-base-300">
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">
                    Passager
                </p>
                <h1 className="text-2xl font-bold text-base-content tracking-tight">
                    Évaluations
                </h1>
            </div>

            {/* ONGLETS */}
            <div className="flex gap-1 bg-base-200 rounded-xl p-1">
                {([
                    { value: "a_evaluer", label: `À évaluer (${trajets.length})` },
                    { value: "recues", label: `Reçues (${recues.length})` },
                ] as const).map((tab) => (
                    <button
                        key={tab.value}
                        onClick={() => { setOnglet(tab.value); setTrajetEnCours(null); setError(null); setSuccess(null); }}
                        className={`flex-1 btn btn-sm rounded-lg transition-all ${onglet === tab.value ? "btn-primary shadow-sm" : "btn-ghost"
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
                    {loading ? (
                        <div className="flex flex-col gap-3">
                            {[1, 2].map((i) => (
                                <div key={i} className="bg-base-100 rounded-2xl border border-base-200 p-5 animate-pulse">
                                    <div className="h-4 bg-base-300 rounded w-1/2 mb-3" />
                                    <div className="h-3 bg-base-300 rounded w-1/3" />
                                </div>
                            ))}
                        </div>
                    ) : trajets.length === 0 ? (
                        <div className="bg-base-100 rounded-2xl border border-base-200 p-12 text-center">
                            <p className="text-base-content/40 text-sm">
                                Aucun trajet à évaluer pour le moment.
                            </p>
                            <p className="text-base-content/30 text-xs mt-1">
                                Les évaluations sont disponibles après la fin du trajet.
                            </p>
                        </div>
                    ) : (
                        trajets.map((trajet) => (
                            <div key={trajet.trajet_id}>
                                {/* Carte trajet */}
                                {trajetEnCours?.trajet_id !== trajet.trajet_id && (
                                    <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                                        <div className="flex items-center justify-between px-5 py-4">
                                            <div>
                                                <p className="font-semibold text-base-content">
                                                    {trajet.depart}
                                                    <span className="text-base-content/25 mx-2 font-light">→</span>
                                                    {trajet.destination}
                                                </p>
                                                <p className="text-xs text-base-content/40 mt-0.5">
                                                    Conducteur : {trajet.conducteur_nom} · {formatDate(trajet.date_trajet)}
                                                </p>
                                            </div>
                                            <button
                                                onClick={() => { setTrajetEnCours(trajet); setError(null); setSuccess(null); }}
                                                className="btn btn-primary btn-sm rounded-full px-4"
                                            >
                                                Évaluer
                                            </button>
                                        </div>
                                    </div>
                                )}

                                {/* Formulaire évaluation */}
                                {trajetEnCours?.trajet_id === trajet.trajet_id && (
                                    <form onSubmit={handleSoumettre}
                                        className="bg-base-100 rounded-2xl border border-primary/20 overflow-hidden">

                                        <div className="px-5 py-4 border-b border-base-200 flex items-center justify-between">
                                            <div>
                                                <p className="font-semibold text-base-content text-sm">
                                                    {trajet.depart} → {trajet.destination}
                                                </p>
                                                <p className="text-xs text-base-content/40">
                                                    Évaluer {trajet.conducteur_nom}
                                                </p>
                                            </div>
                                            <button type="button"
                                                onClick={() => setTrajetEnCours(null)}
                                                className="btn btn-ghost btn-xs btn-square rounded-lg">
                                                ×
                                            </button>
                                        </div>

                                        <div className="p-5 space-y-5">

                                            {/* Note générale */}
                                            <div className="space-y-2">
                                                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                                                    Note générale
                                                </p>
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
                                                    Critères détaillés
                                                </p>
                                                {CRITERES.map((c) => (
                                                    <div key={c.key} className="flex items-center justify-between">
                                                        <span className="text-sm text-base-content/60">{c.label}</span>
                                                        <Etoiles
                                                            note={criteres[c.key as keyof typeof criteres]}
                                                            onChange={(n) => setCriteres((prev) => ({ ...prev, [c.key]: n }))}
                                                        />
                                                    </div>
                                                ))}
                                            </div>

                                            {/* Commentaire */}
                                            <div className="form-control">
                                                <label className="label py-1">
                                                    <span className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                                                        Commentaire
                                                        <span className="ml-1 normal-case font-normal">(optionnel)</span>
                                                    </span>
                                                </label>
                                                <textarea
                                                    className="textarea textarea-bordered rounded-xl resize-none"
                                                    rows={3}
                                                    placeholder="Partagez votre expérience..."
                                                    value={commentaire}
                                                    onChange={(e) => setCommentaire(e.target.value)}
                                                />
                                            </div>

                                            <div className="flex gap-3">
                                                <button type="button"
                                                    onClick={() => setTrajetEnCours(null)}
                                                    className="btn btn-ghost btn-sm rounded-full flex-1 border border-base-300">
                                                    Annuler
                                                </button>
                                                <button type="submit" disabled={submitting || note === 0}
                                                    className="btn btn-primary btn-sm rounded-full flex-1">
                                                    {submitting
                                                        ? <span className="loading loading-spinner loading-xs" />
                                                        : "Envoyer l'évaluation"
                                                    }
                                                </button>
                                            </div>
                                        </div>
                                    </form>
                                )}
                            </div>
                        ))
                    )}
                </div>
            )}

            {/* ── ÉVALUATIONS REÇUES ── */}
            {onglet === "recues" && (
                <div className="space-y-3">
                    {loading ? (
                        <div className="flex flex-col gap-3">
                            {[1, 2, 3].map((i) => (
                                <div key={i} className="bg-base-100 rounded-2xl border border-base-200 p-5 animate-pulse">
                                    <div className="h-4 bg-base-300 rounded w-1/3 mb-3" />
                                    <div className="h-3 bg-base-300 rounded w-1/2" />
                                </div>
                            ))}
                        </div>
                    ) : recues.length === 0 ? (
                        <div className="bg-base-100 rounded-2xl border border-base-200 p-12 text-center">
                            <p className="text-base-content/40 text-sm">
                                Vous n'avez pas encore reçu d'évaluation.
                            </p>
                        </div>
                    ) : (
                        recues.map((eval_) => (
                            <div key={eval_.id} className="bg-base-100 rounded-2xl border border-base-200 p-5 space-y-3">
                                <div className="flex items-start justify-between gap-4">
                                    <div>
                                        <p className="text-sm font-semibold text-base-content">{eval_.auteur}</p>
                                        <p className="text-xs text-base-content/40 mt-0.5">{eval_.trajet}</p>
                                    </div>
                                    <div className="text-right shrink-0">
                                        <Etoiles note={eval_.note} readonly />
                                        <p className="text-xs text-base-content/30 mt-1">{formatDate(eval_.date)}</p>
                                    </div>
                                </div>
                                {eval_.commentaire && (
                                    <p className="text-sm text-base-content/60 bg-base-200/50 rounded-xl px-4 py-3 italic">
                                        "{eval_.commentaire}"
                                    </p>
                                )}
                            </div>
                        ))
                    )}
                </div>
            )}

        </div>
    );
}