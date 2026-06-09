"use client";

import { useState, useEffect } from "react";
import { api } from "@/src/services/api";

interface EvaluationRecue {
    id: number;
    auteur: string;
    auteur_id: string;
    trajet: string;
    trajet_id: number;
    note: number;
    commentaire: string;
    date: string;
    signale: boolean;
}

interface Blocage {
    passager_id: string;
    nom: string;
    motif: string;
    bloque_le: string;
}

type Onglet = "recues" | "bloques";

function Etoiles({ note, onSelect }: { note: number; onSelect?: (n: number) => void }) {
    const [survol, setSurvol] = useState(0);
    return (
        <div className="flex gap-0.5">
            {[1, 2, 3, 4, 5].map((s) => (
                <button
                    key={s}
                    type="button"
                    className={`text-xl transition-colors ${
                        s <= (onSelect ? (survol || note) : note)
                            ? "text-warning"
                            : "text-base-300"
                    } ${onSelect ? "cursor-pointer hover:scale-110" : "cursor-default"}`}
                    onClick={() => onSelect?.(s)}
                    onMouseEnter={() => onSelect && setSurvol(s)}
                    onMouseLeave={() => onSelect && setSurvol(0)}
                    disabled={!onSelect}
                >
                    ★
                </button>
            ))}
        </div>
    );
}

export default function ConducteurEvaluationsPage() {
    const [onglet, setOnglet] = useState<Onglet>("recues");
    const [evaluations, setEvaluations] = useState<EvaluationRecue[]>([]);
    const [blocages, setBlocages] = useState<Blocage[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    // Signalement
    const [signalerId, setSignalerOnId] = useState<number | null>(null);
    const [motifSignalement, setMotifSignalement] = useState("");
    const [signalerLoading, setSignalerLoading] = useState(false);

    // Déblocage
    const [debloquerLoading, setDebloquerLoading] = useState<string | null>(null);

    const fetchData = async () => {
        setLoading(true);
        setError(null);
        try {
            const [evals, blocs] = await Promise.all([
                api("/evaluations/mes_evaluations/"),
                api("/evaluations/mes_blocages/"),
            ]);
            setEvaluations(Array.isArray(evals) ? evals : []);
            setBlocages(Array.isArray(blocs) ? blocs : []);
        } catch {
            setError("Impossible de charger les données.");
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchData();
    }, []);

    const handleSignaler = async (evalId: number) => {
        setSignalerLoading(true);
        try {
            await api("/evaluations/signaler/", "POST", {
                evaluation_id: evalId,
                motif: motifSignalement,
            });
            setEvaluations((prev) =>
                prev.map((e) => e.id === evalId ? { ...e, signale: true } : e)
            );
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

    const noteMoyenne =
        evaluations.length > 0
            ? evaluations.reduce((s, e) => s + e.note, 0) / evaluations.length
            : 0;

    return (
        <div className="max-w-2xl mx-auto space-y-6">

            {/* En-tête */}
            <div>
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">
                    Réputation
                </p>
                <h1 className="text-3xl font-bold text-base-content tracking-tight">
                    Évaluations
                </h1>
                {!loading && evaluations.length > 0 && (
                    <div className="flex items-center gap-2 mt-2">
                        <Etoiles note={Math.round(noteMoyenne)} />
                        <span className="text-sm text-base-content/60 font-medium">
                            {noteMoyenne.toFixed(1)} / 5 · {evaluations.length} avis
                        </span>
                    </div>
                )}
            </div>

            {/* Onglets */}
            <div className="flex gap-1 bg-base-200 p-1 rounded-xl">
                {(
                    [
                        { key: "recues", label: `Reçues${evaluations.length ? ` (${evaluations.length})` : ""}` },
                        { key: "bloques", label: `Bloqués${blocages.length ? ` (${blocages.length})` : ""}` },
                    ] as { key: Onglet; label: string }[]
                ).map(({ key, label }) => (
                    <button
                        key={key}
                        onClick={() => setOnglet(key)}
                        className={`flex-1 py-2 px-4 text-sm font-medium rounded-lg transition-all ${
                            onglet === key
                                ? "bg-base-100 text-base-content shadow-sm"
                                : "text-base-content/50 hover:text-base-content"
                        }`}
                    >
                        {label}
                    </button>
                ))}
            </div>

            {/* Erreur */}
            {error && (
                <div className="bg-error/10 border border-error/20 rounded-xl px-4 py-3">
                    <p className="text-sm text-error">{error}</p>
                </div>
            )}

            {/* Skeleton */}
            {loading && (
                <div className="space-y-3 animate-pulse">
                    {[1, 2, 3].map((i) => (
                        <div key={i} className="h-24 bg-base-200 rounded-2xl" />
                    ))}
                </div>
            )}

            {/* ONGLET : ÉVALUATIONS REÇUES */}
            {!loading && onglet === "recues" && (
                <>
                    {evaluations.length === 0 ? (
                        <div className="bg-base-100 rounded-2xl border border-base-200 p-12 text-center">
                            <p className="text-4xl mb-3">⭐</p>
                            <p className="font-medium text-base-content">Aucune évaluation reçue</p>
                            <p className="text-sm text-base-content/40 mt-1">
                                Les avis de vos passagers apparaîtront ici après chaque trajet terminé.
                            </p>
                        </div>
                    ) : (
                        <div className="space-y-3">
                            {evaluations.map((eval_) => (
                                <div
                                    key={eval_.id}
                                    className="bg-base-100 rounded-2xl border border-base-200 p-5 space-y-3"
                                >
                                    <div className="flex items-start justify-between gap-3">
                                        <div>
                                            <p className="font-semibold text-base-content text-sm">
                                                {eval_.auteur}
                                            </p>
                                            <p className="text-xs text-base-content/40">
                                                {eval_.trajet} ·{" "}
                                                {new Date(eval_.date).toLocaleDateString("fr-FR", {
                                                    day: "numeric",
                                                    month: "long",
                                                    year: "numeric",
                                                })}
                                            </p>
                                        </div>
                                        <Etoiles note={eval_.note} />
                                    </div>

                                    {eval_.commentaire && (
                                        <p className="text-sm text-base-content/70 italic">
                                            "{eval_.commentaire}"
                                        </p>
                                    )}

                                    {eval_.signale ? (
                                        <span className="badge badge-sm badge-ghost rounded-full">
                                            Signalé
                                        </span>
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
                                                <button
                                                    onClick={() => handleSignaler(eval_.id)}
                                                    disabled={signalerLoading}
                                                    className="btn btn-error btn-sm rounded-full flex-1"
                                                >
                                                    {signalerLoading
                                                        ? <span className="loading loading-spinner loading-xs" />
                                                        : "Confirmer le signalement"
                                                    }
                                                </button>
                                                <button
                                                    onClick={() => {
                                                        setSignalerOnId(null);
                                                        setMotifSignalement("");
                                                    }}
                                                    className="btn btn-ghost btn-sm rounded-full"
                                                >
                                                    Annuler
                                                </button>
                                            </div>
                                        </div>
                                    ) : (
                                        <button
                                            onClick={() => setSignalerOnId(eval_.id)}
                                            className="btn btn-ghost btn-xs rounded-full text-base-content/40 hover:text-error"
                                        >
                                            Signaler comme abusif
                                        </button>
                                    )}
                                </div>
                            ))}
                        </div>
                    )}
                </>
            )}

            {/* ONGLET : PASSAGERS BLOQUÉS */}
            {!loading && onglet === "bloques" && (
                <>
                    {blocages.length === 0 ? (
                        <div className="bg-base-100 rounded-2xl border border-base-200 p-12 text-center">
                            <p className="text-4xl mb-3">🛡️</p>
                            <p className="font-medium text-base-content">Aucun passager bloqué</p>
                            <p className="text-sm text-base-content/40 mt-1">
                                Vous pouvez bloquer un passager depuis la page de gestion des réservations.
                            </p>
                        </div>
                    ) : (
                        <div className="space-y-3">
                            {blocages.map((b) => (
                                <div
                                    key={b.passager_id}
                                    className="bg-base-100 rounded-2xl border border-base-200 p-5 flex items-center justify-between gap-4"
                                >
                                    <div>
                                        <p className="font-semibold text-base-content text-sm">
                                            {b.nom}
                                        </p>
                                        {b.motif && (
                                            <p className="text-xs text-base-content/60 mt-0.5">
                                                {b.motif}
                                            </p>
                                        )}
                                        <p className="text-xs text-base-content/40 mt-1">
                                            Bloqué le{" "}
                                            {new Date(b.bloque_le).toLocaleDateString("fr-FR", {
                                                day: "numeric",
                                                month: "long",
                                                year: "numeric",
                                            })}
                                        </p>
                                    </div>
                                    <button
                                        onClick={() => handleDebloquer(b.passager_id)}
                                        disabled={debloquerLoading === b.passager_id}
                                        className="btn btn-ghost btn-sm rounded-full shrink-0"
                                    >
                                        {debloquerLoading === b.passager_id
                                            ? <span className="loading loading-spinner loading-xs" />
                                            : "Débloquer"
                                        }
                                    </button>
                                </div>
                            ))}
                        </div>
                    )}
                </>
            )}

        </div>
    );
}
