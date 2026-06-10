"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import {
    confirmerReservation,
    declinerReservation,
} from "@/src/services/reservation.service";
import { confirmerEspeces, confirmerMobile } from "@/src/services/paiement.service";
import { api } from "@/src/services/api";

async function bloquerPassager(passagerId: string, motif: string) {
    return api("/evaluations/bloquer/", "POST", { passager_id: passagerId, motif });
}

interface Reservation {
    id: number;
    trajet_id: number;
    depart: string;
    destination: string;
    date_depart: string;
    passager_id?: string;
    passager_nom: string;
    passager_note: number;
    passager_telephone: string;
    prix_par_place: number;
    prix_passager?: number;
    code_embarquement?: string;
    statut_embarquement?: "en_attente" | "embarque" | "depose";
    heure_embarquement?: string;
    heure_depose?: string;
    statut: "en_attente" | "confirmee" | "declinee";
    date_reservation: string;
    conversation_id?: number | null;
    paiement_statut: string | null;
    paiement_moyen: string | null;
    paiement_reference_mobile: string | null;
}

export default function ReservationsRecuesPage() {
    const router = useRouter();
    const [reservations, setReservations] = useState<Reservation[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);
    const [filtre, setFiltre] = useState<"tous" | "en_attente" | "confirmee" | "declinee">("tous");
    const [actions, setActions] = useState<Record<number, "confirming" | "declining" | "paying" | null>>({});

    useEffect(() => { fetchReservations(); }, []);

    const fetchReservations = async () => {
        setLoading(true);
        try {
            const data = await api("/reservations/recues/", "GET");
            setReservations(Array.isArray(data) ? data : []);
        } catch {
            setError("Impossible de charger les réservations.");
        } finally {
            setLoading(false);
        }
    };

    const handleConfirmer = async (id: number) => {
        setActions((prev) => ({ ...prev, [id]: "confirming" }));
        try {
            await confirmerReservation(id);
            setReservations((prev) =>
                prev.map((r) => r.id === id ? { ...r, statut: "confirmee" } : r)
            );
        } catch (err: any) {
            setError(err.response?.data?.error || "Erreur lors de la confirmation.");
        } finally {
            setActions((prev) => ({ ...prev, [id]: null }));
        }
    };

    const handleConfirmerPaiement = async (id: number, moyen: string) => {
        if (!confirm(`Confirmer la réception du paiement ${moyen} pour cette réservation ?`)) return;
        setActions((prev) => ({ ...prev, [id]: "paying" }));
        try {
            if (moyen === "ESPECE") {
                await confirmerEspeces(id);
            } else {
                await confirmerMobile(id);
            }
            setReservations((prev) =>
                prev.map((r) => r.id === id ? { ...r, paiement_statut: "CONFIRME" } : r)
            );
        } catch (err: any) {
            setError(err.response?.data?.error || "Erreur lors de la confirmation du paiement.");
        } finally {
            setActions((prev) => ({ ...prev, [id]: null }));
        }
    };

    const handleDecliner = async (id: number) => {
        if (!confirm("Confirmer le refus de cette réservation ?")) return;
        setActions((prev) => ({ ...prev, [id]: "declining" }));
        try {
            await declinerReservation(id);
            setReservations((prev) =>
                prev.map((r) => r.id === id ? { ...r, statut: "declinee" } : r)
            );
        } catch (err: any) {
            setError(err.response?.data?.error || "Erreur lors du refus.");
        } finally {
            setActions((prev) => ({ ...prev, [id]: null }));
        }
    };

    const filtrees = reservations.filter((r) =>
        filtre === "tous" ? true : r.statut === filtre
    );

    const counts = {
        tous: reservations.length,
        en_attente: reservations.filter((r) => r.statut === "en_attente").length,
        confirmee: reservations.filter((r) => r.statut === "confirmee").length,
        declinee: reservations.filter((r) => r.statut === "declinee").length,
    };

    const formatDate = (iso: string) =>
        new Date(iso).toLocaleDateString("fr-FR", {
            weekday: "short", day: "numeric", month: "short",
            hour: "2-digit", minute: "2-digit",
        });

    const statutBadge = (statut: string) => {
        switch (statut) {
            case "en_attente": return "badge-warning badge-outline";
            case "confirmee": return "badge-success badge-outline";
            case "declinee": return "badge-error badge-outline";
            default: return "badge-ghost";
        }
    };

    const statutLabel = (statut: string) => {
        switch (statut) {
            case "en_attente": return "En attente";
            case "confirmee": return "Confirmée";
            case "declinee": return "Déclinée";
            default: return statut;
        }
    };

    return (
        <div className="space-y-8">

            {/* EN-TÊTE */}
            <div className="pb-6 border-b border-base-300">
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">
                    Conducteur
                </p>
                <h1 className="text-2xl font-bold text-base-content tracking-tight">
                    Réservations reçues
                </h1>
                <p className="text-base-content/40 mt-1 text-sm">
                    {counts.en_attente > 0
                        ? `${counts.en_attente} en attente de validation`
                        : "Aucune réservation en attente"
                    }
                </p>
            </div>

            {/* ERREUR */}
            {error && (
                <div className="bg-error/10 border border-error/20 rounded-xl px-4 py-3">
                    <p className="text-sm text-error">{error}</p>
                </div>
            )}

            {/* FILTRES */}
            <div className="flex gap-2 flex-wrap">
                {([
                    { value: "tous", label: "Toutes" },
                    { value: "en_attente", label: "En attente" },
                    { value: "confirmee", label: "Confirmées" },
                    { value: "declinee", label: "Déclinées" },
                ] as const).map((f) => (
                    <button
                        key={f.value}
                        onClick={() => setFiltre(f.value)}
                        className={`btn btn-sm rounded-full transition-all ${filtre === f.value ? "btn-primary" : "btn-ghost border border-base-300"
                            }`}
                    >
                        {f.label}
                        <span className={`ml-1 text-xs ${filtre === f.value ? "opacity-80" : "text-base-content/40"
                            }`}>
                            {counts[f.value]}
                        </span>
                    </button>
                ))}
            </div>

            {/* LISTE */}
            {loading ? (
                <div className="flex flex-col gap-3">
                    {[1, 2, 3].map((i) => (
                        <div key={i} className="bg-base-100 rounded-2xl border border-base-200 p-6 animate-pulse">
                            <div className="h-4 bg-base-300 rounded w-1/3 mb-3" />
                            <div className="h-3 bg-base-300 rounded w-1/2" />
                        </div>
                    ))}
                </div>
            ) : filtrees.length === 0 ? (
                <div className="bg-base-100 rounded-2xl border border-base-200 p-12 text-center">
                    <p className="text-base-content/40 text-sm">
                        {filtre === "tous"
                            ? "Aucune réservation reçue pour l'instant."
                            : `Aucune réservation ${filtre === "en_attente" ? "en attente"
                                : filtre === "confirmee" ? "confirmée"
                                    : "déclinée"
                            }.`
                        }
                    </p>
                </div>
            ) : (
                <div className="flex flex-col gap-3">
                    {filtrees.map((resa) => (
                        <div
                            key={resa.id}
                            className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden"
                        >
                            {/* Ligne principale */}
                            <div className="px-6 py-5">
                                <div className="flex items-start justify-between gap-4 mb-3">
                                    <div className="flex-1 min-w-0">
                                        <div className="flex items-center gap-2 flex-wrap mb-1">
                                            <p className="font-semibold text-base-content">
                                                {resa.depart}
                                                <span className="text-base-content/25 mx-2 font-light">→</span>
                                                {resa.destination}
                                            </p>
                                            <span className={`badge badge-sm rounded-full font-medium ${statutBadge(resa.statut)}`}>
                                                {statutLabel(resa.statut)}
                                            </span>
                                        </div>
                                        <p className="text-xs text-base-content/40">
                                            Départ : {formatDate(resa.date_depart)}
                                        </p>
                                    </div>
                                    <div className="text-right shrink-0">
                                        <p className="text-lg font-bold text-primary">
                                            {Number(resa.prix_par_place).toLocaleString("fr-FR")} FCFA
                                        </p>
                                        <p className="text-xs text-base-content/40">par place</p>
                                    </div>
                                </div>

                                {/* Passager */}
                                <BlocagePassagerRow resa={resa} formatDate={formatDate} />

                                {/* Boutons — seulement si en attente */}
                                {resa.statut === "en_attente" && (
                                    <div className="flex gap-3 mt-3">
                                        <button
                                            onClick={() => handleConfirmer(resa.id)}
                                            disabled={!!actions[resa.id]}
                                            className="btn btn-success btn-sm rounded-full flex-1"
                                        >
                                            {actions[resa.id] === "confirming"
                                                ? <span className="loading loading-spinner loading-xs" />
                                                : "Confirmer"
                                            }
                                        </button>
                                        <button
                                            onClick={() => handleDecliner(resa.id)}
                                            disabled={!!actions[resa.id]}
                                            className="btn btn-ghost btn-sm rounded-full flex-1 border border-error/30 text-error hover:bg-error/5"
                                        >
                                            {actions[resa.id] === "declining"
                                                ? <span className="loading loading-spinner loading-xs" />
                                                : "Décliner"
                                            }
                                        </button>
                                    </div>
                                )}

                                {/* Embarquement — visible si confirmée */}
                                {resa.statut === "confirmee" && (
                                    <EmbarquementRow
                                        resa={resa}
                                        onUpdate={(updated) => setReservations((prev) =>
                                            prev.map((r) => r.id === resa.id ? { ...r, ...updated } : r)
                                        )}
                                    />
                                )}

                                {/* Bouton messagerie — visible dès qu'une conversation existe */}
                                {resa.conversation_id && (
                                    <div className="mt-3">
                                        <button
                                            onClick={() => router.push(`/communication/messages?conv=${resa.conversation_id}`)}
                                            className="btn btn-outline btn-sm rounded-full gap-2"
                                        >
                                            <svg xmlns="http://www.w3.org/2000/svg" className="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                                            </svg>
                                            Message passager
                                        </button>
                                    </div>
                                )}

                                {/* Bloc paiement — visible si confirmée */}
                                {resa.statut === "confirmee" && resa.paiement_statut && (
                                    <div className={`mt-3 rounded-xl px-4 py-3 border ${
                                        resa.paiement_statut === "CONFIRME"
                                            ? "bg-success/5 border-success/20"
                                            : "bg-warning/5 border-warning/20"
                                    }`}>
                                        <div className="flex items-center justify-between gap-3 flex-wrap">
                                            <div>
                                                <p className="text-xs text-base-content/40 uppercase tracking-wide mb-0.5">Paiement</p>
                                                <div className="flex items-center gap-2 flex-wrap">
                                                    <span className="text-sm font-semibold text-base-content">
                                                        {resa.paiement_moyen === "ESPECE"   ? "💵 Espèces"
                                                        : resa.paiement_moyen === "TMONEY" ? "🟠 T-Money"
                                                        : resa.paiement_moyen === "FLOOZ"  ? "🟢 Flooz"
                                                        : resa.paiement_moyen}
                                                    </span>
                                                    <span className={`badge badge-sm ${
                                                        resa.paiement_statut === "CONFIRME" ? "badge-success" : "badge-warning"
                                                    }`}>
                                                        {resa.paiement_statut === "CONFIRME" ? "✓ Confirmé" : "⏳ En attente"}
                                                    </span>
                                                </div>
                                                {/* Référence mobile money */}
                                                {resa.paiement_reference_mobile && (
                                                    <p className="text-xs font-mono text-base-content/60 mt-1">
                                                        Réf : <strong>{resa.paiement_reference_mobile}</strong>
                                                    </p>
                                                )}
                                            </div>

                                            {/* Bouton confirmer si en attente */}
                                            {resa.paiement_statut === "EN_ATTENTE_CONFIRMATION" && (
                                                <button
                                                    onClick={() => handleConfirmerPaiement(resa.id, resa.paiement_moyen || "ESPECE")}
                                                    disabled={actions[resa.id] === "paying"}
                                                    className="btn btn-success btn-xs rounded-full"
                                                >
                                                    {actions[resa.id] === "paying"
                                                        ? <span className="loading loading-spinner loading-xs" />
                                                        : "Confirmer réception"
                                                    }
                                                </button>
                                            )}
                                        </div>
                                    </div>
                                )}
                            </div>
                        </div>
                    ))}
                </div>
            )}

        </div>
    );
}

function EmbarquementRow({ resa, onUpdate }: {
    resa: Reservation;
    onUpdate: (data: Partial<Reservation>) => void;
}) {
    const [code, setCode] = useState("");
    const [loading, setLoading] = useState(false);
    const [msg, setMsg] = useState<{ type: "success" | "error"; text: string } | null>(null);

    const handleEmbarquer = async () => {
        if (!code.trim()) return;
        setLoading(true);
        setMsg(null);
        try {
            const res = await api("/reservations/embarquer/", "POST", { code_embarquement: code.trim().toUpperCase() });
            setMsg({ type: "success", text: `Embarquement confirmé — ${res.passager}` });
            setCode("");
            onUpdate({ statut_embarquement: "embarque", heure_embarquement: res.heure_embarquement });
        } catch (err: any) {
            setMsg({ type: "error", text: err.response?.data?.error || "Code invalide." });
        } finally {
            setLoading(false);
        }
    };

    const handleDebarquer = async () => {
        setLoading(true);
        setMsg(null);
        try {
            const res = await api(`/reservations/${resa.id}/debarquer/`, "POST");
            setMsg({ type: "success", text: `Dépose confirmée — ${res.passager}` });
            onUpdate({ statut_embarquement: "depose", heure_depose: res.heure_depose });
        } catch (err: any) {
            setMsg({ type: "error", text: err.response?.data?.error || "Erreur lors de la dépose." });
        } finally {
            setLoading(false);
        }
    };

    const se = resa.statut_embarquement;

    return (
        <div className="mt-3 pt-3 border-t border-base-200">
            <p className="text-xs text-base-content/40 uppercase tracking-wide mb-2">Embarquement</p>

            {/* Statut actuel */}
            {se === "embarque" && (
                <div className="flex items-center justify-between gap-3">
                    <span className="badge badge-success badge-outline badge-sm">Embarqué{resa.heure_embarquement ? ` — ${new Date(resa.heure_embarquement).toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" })}` : ""}</span>
                    <button onClick={handleDebarquer} disabled={loading} className="btn btn-xs btn-outline rounded-full">
                        {loading ? <span className="loading loading-spinner loading-xs" /> : "Confirmer dépose"}
                    </button>
                </div>
            )}
            {se === "depose" && (
                <span className="badge badge-info badge-outline badge-sm">
                    Déposé{resa.heure_depose ? ` — ${new Date(resa.heure_depose).toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" })}` : ""}
                </span>
            )}
            {(!se || se === "en_attente") && (
                <div className="flex gap-2">
                    <input
                        type="text"
                        value={code}
                        onChange={(e) => setCode(e.target.value.toUpperCase())}
                        onKeyDown={(e) => e.key === "Enter" && handleEmbarquer()}
                        placeholder="Code passager (KVT-XXXX)"
                        maxLength={8}
                        className="input input-sm input-bordered rounded-xl flex-1 font-mono tracking-wider uppercase"
                    />
                    <button onClick={handleEmbarquer} disabled={loading || !code.trim()} className="btn btn-sm btn-primary rounded-xl">
                        {loading ? <span className="loading loading-spinner loading-xs" /> : "Valider"}
                    </button>
                </div>
            )}

            {msg && (
                <p className={`text-xs mt-1.5 ${msg.type === "success" ? "text-success" : "text-error"}`}>
                    {msg.text}
                </p>
            )}
        </div>
    );
}

function BlocagePassagerRow({ resa, formatDate }: {
    resa: Reservation;
    formatDate: (d: string) => string;
}) {
    const [bloque,      setBloque]      = useState(false);
    const [showBlocage, setShowBlocage] = useState(false);
    const [motif,       setMotif]       = useState("");
    const [loading,     setLoading]     = useState(false);

    const handleBloquer = async () => {
        if (!resa.passager_id) return;
        setLoading(true);
        try {
            await bloquerPassager(resa.passager_id, motif);
            setBloque(true);
            setShowBlocage(false);
        } catch { }
        finally { setLoading(false); }
    };

    return (
        <div className="py-3 border-t border-base-200">
            <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-full bg-base-200 flex items-center justify-center shrink-0">
                    <span className="text-xs font-bold text-base-content/60">
                        {resa.passager_nom?.[0]?.toUpperCase()}
                    </span>
                </div>
                <div className="flex-1">
                    <p className="text-sm font-medium text-base-content">{resa.passager_nom}</p>
                    <div className="flex items-center gap-1 mt-0.5">
                        {[1, 2, 3, 4, 5].map((s) => (
                            <div key={s} className={`w-2 h-2 rounded-sm ${s <= Math.round(resa.passager_note) ? "bg-warning" : "bg-base-300"}`} />
                        ))}
                        <span className="text-xs text-base-content/40 ml-1">{resa.passager_note} / 5</span>
                    </div>
                </div>
                <p className="text-xs text-base-content/30">Demandé le {formatDate(resa.date_reservation)}</p>
            </div>
            {/* Blocage */}
            {resa.passager_id && (
                bloque ? (
                    <p className="text-xs text-error mt-2">✓ Passager bloqué.</p>
                ) : !showBlocage ? (
                    <button onClick={() => setShowBlocage(true)}
                        className="btn btn-ghost btn-xs rounded-full text-base-content/30 hover:text-error mt-1">
                        Bloquer ce passager
                    </button>
                ) : (
                    <div className="mt-2 space-y-2">
                        <textarea value={motif} onChange={(e) => setMotif(e.target.value)}
                            placeholder="Motif du blocage (facultatif)…"
                            className="textarea textarea-bordered textarea-xs w-full rounded-xl" rows={2} />
                        <div className="flex gap-2">
                            <button onClick={() => setShowBlocage(false)} className="btn btn-ghost btn-xs rounded-full">Annuler</button>
                            <button onClick={handleBloquer} disabled={loading}
                                className="btn btn-error btn-xs rounded-full">
                                {loading ? <span className="loading loading-spinner loading-xs" /> : "Bloquer"}
                            </button>
                        </div>
                    </div>
                )
            )}
        </div>
    );
}