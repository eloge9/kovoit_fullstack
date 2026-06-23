"use client";

import { useState, useEffect, useRef } from "react";
import { useParams, useRouter } from "next/navigation";
import { api } from "@/src/services/api";
import {
    initierPaiement,
    verifierPaiement,
    initierPaiementEspeces,
    annulerPaiement,
    getStatutPaiementReservation,
    OPERATEURS_MOBILE_MONEY,
    type OperateurMobileMoney,
    type PaiementStatut,
    type PaiementReservationResponse,
} from "@/src/services/paiement.service";

type Methode = "mobile" | "especes";

const ICONS = {
    FLOOZ: "🔵",
    YAS:   "🟡",
};

export default function PaiementPage() {
    const { id } = useParams();
    const router = useRouter();

    const [reservation, setReservation] = useState<any>(null);
    const [loading, setLoading] = useState(true);
    const [paying, setPaying] = useState(false);
    const [error, setError] = useState<string | null>(null);

    const [methode, setMethode] = useState<Methode>("mobile");
    const [network, setNetwork] = useState<OperateurMobileMoney>("FLOOZ");
    const [phone, setPhone] = useState("");

    // État espèces
    const [paiementEspeces, setPaiementEspeces] = useState<PaiementReservationResponse | null>(null);
    const [loadingEspeces, setLoadingEspeces] = useState(false);

    // État après initiation Mobile Money
    const [token, setToken]       = useState<string | null>(null);
    const [transref, setTransref] = useState<string | null>(null);
    const [statut, setStatut]     = useState<PaiementStatut | null>(null);
    const [verifying, setVerifying] = useState(false);
    const intervalRef = useRef<NodeJS.Timeout | null>(null);

    // Chargement réservation + statut paiement existant
    useEffect(() => {
        const fetch = async () => {
            try {
                const data = await api(`/reservations/${id}/detail/`, "GET");
                setReservation(data);
                try {
                    const pmt = await getStatutPaiementReservation(Number(id));
                    setPaiementEspeces(pmt);
                } catch (err: any) {
                    if (err.response?.status !== 404) {
                        console.error("Statut paiement:", err);
                    }
                    setPaiementEspeces(null);
                }
            } catch {
                const all = await api("/reservations/mes_reservations/", "GET");
                const r = all.find((r: any) => r.id === Number(id));
                setReservation(r || null);
            } finally {
                setLoading(false);
            }
        };
        if (id) fetch();
    }, [id]);

    // Polling toutes les 5 s après initiation Mobile Money
    useEffect(() => {
        if (!token) return;
        intervalRef.current = setInterval(() => handleVerifier(false), 5000);
        return () => { if (intervalRef.current) clearInterval(intervalRef.current); };
    }, [token]);

    // Arrêter le polling dès confirmation / échec
    useEffect(() => {
        if (statut?.statut === "payee" || statut?.statut === "echouee") {
            if (intervalRef.current) clearInterval(intervalRef.current);
        }
    }, [statut]);

    const handleInitier = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!phone.trim()) return setError("Entrez votre numéro de téléphone.");
        setPaying(true);
        setError(null);
        try {
            const data = await initierPaiement({
                reservation_id: Number(id),
                phone_number: phone.replace(/\s/g, ""),
                network,
            });
            setToken(data.token);
            setTransref(data.transref);
        } catch (err: any) {
            setError(err.response?.data?.error || "Erreur lors de l'initiation du paiement.");
        } finally {
            setPaying(false);
        }
    };

    const handleVerifier = async (manuel = true) => {
        if (!token) return;
        if (manuel) setVerifying(true);
        try {
            const data = await verifierPaiement(token);
            setStatut(data);
        } catch {
            // Silencieux pour le polling
        } finally {
            if (manuel) setVerifying(false);
        }
    };

    const handleAnnuler = async () => {
        if (!token) return;
        try {
            await annulerPaiement(Number(id));
        } catch {
            // ignore
        }
        if (intervalRef.current) clearInterval(intervalRef.current);
        setToken(null);
        setTransref(null);
        setStatut(null);
        setError(null);
    };

    const handleInitierEspeces = async () => {
        if (paiementEspeces && paiementEspeces.statut !== "ANNULE") {
            setError("Un paiement existe déjà pour cette réservation.");
            return;
        }
        setLoadingEspeces(true);
        setError(null);
        try {
            const data = await initierPaiementEspeces({ reservation_id: Number(id) });
            setPaiementEspeces({
                paiement_id: data.paiement_id,
                statut: data.statut,
                moyen_paiement: "ESPECE",
                montant: data.montant,
                date_creation: new Date().toISOString(),
            });
        } catch (err: any) {
            setError(err.response?.data?.error || "Erreur lors du paiement en espèces.");
        } finally {
            setLoadingEspeces(false);
        }
    };

    // ── Loading ──────────────────────────────────────────────────────────────
    if (loading) {
        return (
            <div className="max-w-lg mx-auto space-y-4 animate-pulse pt-8">
                <div className="h-6 bg-base-300 rounded w-1/3" />
                <div className="h-48 bg-base-300 rounded-2xl" />
            </div>
        );
    }

    if (!reservation) {
        return (
            <div className="max-w-lg mx-auto py-16 text-center">
                <p className="text-base-content/40">Réservation introuvable.</p>
                <button onClick={() => router.back()} className="btn btn-ghost btn-sm rounded-full mt-4">Retour</button>
            </div>
        );
    }

    const montant    = Number(reservation.prix_par_place) * (reservation.places_reservees || 1);
    const commission = Math.round(montant * 0.10);

    // ── Succès Mobile Money ───────────────────────────────────────────────────
    if (statut?.statut === "payee") {
        return (
            <div className="max-w-lg mx-auto py-16 text-center space-y-5">
                <div className="w-20 h-20 rounded-full bg-success/10 flex items-center justify-center mx-auto">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-10 w-10 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                </div>
                <div>
                    <h2 className="text-2xl font-bold text-base-content">Paiement réussi !</h2>
                    <p className="text-base-content/50 text-sm mt-1">
                        {montant.toLocaleString("fr-FR")} FCFA débités via {OPERATEURS_MOBILE_MONEY[network]?.label}
                    </p>
                </div>
                {statut.token && (
                    <div className="bg-base-200 rounded-xl px-4 py-3">
                        <p className="text-xs text-base-content/40 uppercase tracking-wide">Référence de paiement</p>
                        <p className="text-sm font-mono font-semibold text-base-content mt-1">{statut.token}</p>
                    </div>
                )}
                <button
                    onClick={() => router.push("/passager/reservations")}
                    className="btn btn-primary rounded-full px-8"
                >
                    Voir mes réservations
                </button>
            </div>
        );
    }

    return (
        <div className="max-w-lg mx-auto space-y-6 pb-10">

            {/* EN-TÊTE */}
            <div className="flex items-center gap-3 pb-4 border-b border-base-300">
                <button onClick={() => router.back()} className="btn btn-ghost btn-sm btn-square rounded-xl">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
                    </svg>
                </button>
                <div>
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">Paiement</p>
                    <h1 className="text-xl font-bold text-base-content tracking-tight">
                        {reservation.depart} → {reservation.destination}
                    </h1>
                </div>
            </div>

            {/* RÉSUMÉ MONTANT */}
            <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                <div className="divide-y divide-base-200">
                    {[
                        { label: "Places réservées", value: `${reservation.places_reservees || 1}` },
                        { label: "Prix par place",   value: `${Number(reservation.prix_par_place).toLocaleString("fr-FR")} FCFA` },
                        { label: "Commission KoVoit (10%)", value: `${commission.toLocaleString("fr-FR")} FCFA` },
                        { label: "Conducteur reçoit",       value: `${(montant - commission).toLocaleString("fr-FR")} FCFA` },
                    ].map((item) => (
                        <div key={item.label} className="flex justify-between items-center px-5 py-3">
                            <span className="text-xs text-base-content/40 uppercase tracking-wide">{item.label}</span>
                            <span className="text-sm font-semibold text-base-content">{item.value}</span>
                        </div>
                    ))}
                </div>
                <div className="px-5 py-4 bg-primary/5 border-t border-primary/10 flex items-center justify-between">
                    <span className="text-sm font-medium text-base-content/60">Total à payer</span>
                    <span className="text-2xl font-bold text-primary">{montant.toLocaleString("fr-FR")} FCFA</span>
                </div>
            </div>

            {/* ERREUR */}
            {error && (
                <div className="bg-error/10 border border-error/20 rounded-xl px-4 py-3">
                    <p className="text-sm text-error">{error}</p>
                </div>
            )}

            {/* ── FORMULAIRE — avant initiation ── */}
            {!token && (
                <div className="space-y-5">

                    {/* Choix méthode */}
                    <div className="bg-base-100 rounded-2xl border border-base-200 p-5 space-y-4">
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">Méthode de paiement</p>
                        <div className="grid grid-cols-2 gap-3">
                            {(["mobile", "especes"] as Methode[]).map((m) => (
                                <button
                                    key={m}
                                    type="button"
                                    onClick={() => { setMethode(m); setError(null); }}
                                    className={`btn rounded-xl ${methode === m ? "btn-primary" : "btn-outline"}`}
                                >
                                    {m === "mobile" ? "📱 Mobile Money" : "💵 Espèces"}
                                </button>
                            ))}
                        </div>
                    </div>

                    {/* Mobile Money */}
                    {methode === "mobile" && (
                        <form onSubmit={handleInitier} className="bg-base-100 rounded-2xl border border-base-200 p-5 space-y-5">
                            <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                                Paiement Mobile Money — PayPlus Africa
                            </p>

                            {/* Choix opérateur */}
                            <div className="space-y-2">
                                <label className="text-sm font-medium text-base-content">Opérateur</label>
                                <div className="grid grid-cols-2 gap-3">
                                    {(Object.keys(OPERATEURS_MOBILE_MONEY) as OperateurMobileMoney[]).map((op) => (
                                        <button
                                            key={op}
                                            type="button"
                                            onClick={() => setNetwork(op)}
                                            className={`flex flex-col items-center gap-1 p-4 rounded-xl border-2 transition-all ${
                                                network === op
                                                    ? "border-primary bg-primary/5"
                                                    : "border-base-200 bg-base-100 hover:border-base-300"
                                            }`}
                                        >
                                            <span className="text-2xl">{ICONS[op]}</span>
                                            <span className={`text-sm font-bold ${network === op ? "text-primary" : "text-base-content"}`}>
                                                {OPERATEURS_MOBILE_MONEY[op].label}
                                            </span>
                                            <span className="text-xs text-base-content/40">
                                                {OPERATEURS_MOBILE_MONEY[op].prefix}
                                            </span>
                                        </button>
                                    ))}
                                </div>
                            </div>

                            {/* Numéro de téléphone */}
                            <div className="space-y-1">
                                <label className="text-sm font-medium text-base-content">
                                    Numéro {OPERATEURS_MOBILE_MONEY[network].label}
                                </label>
                                <input
                                    type="tel"
                                    placeholder="ex : 90 00 00 00"
                                    className="input input-bordered rounded-xl w-full"
                                    value={phone}
                                    onChange={(e) => setPhone(e.target.value)}
                                    required
                                />
                                <p className="text-xs text-base-content/30 ml-1">
                                    Vous recevrez une demande de confirmation sur ce numéro.
                                </p>
                            </div>

                            <button
                                type="submit"
                                disabled={paying}
                                className="btn btn-primary w-full rounded-full"
                            >
                                {paying
                                    ? <span className="loading loading-spinner loading-sm" />
                                    : `Payer ${montant.toLocaleString("fr-FR")} FCFA via ${OPERATEURS_MOBILE_MONEY[network].label}`
                                }
                            </button>
                        </form>
                    )}

                    {/* Espèces */}
                    {methode === "especes" && (
                        <div className="bg-base-100 rounded-2xl border border-base-200 p-5 space-y-4">
                            <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                                Paiement en espèces
                            </p>

                            {paiementEspeces && paiementEspeces.statut === "EN_ATTENTE_CONFIRMATION" && (
                                <div className="bg-warning/10 border border-warning/20 rounded-xl px-4 py-3 flex items-center gap-2">
                                    <div className="w-3 h-3 rounded-full bg-warning animate-pulse" />
                                    <p className="text-sm font-medium text-base-content">En attente de confirmation du conducteur</p>
                                </div>
                            )}

                            {paiementEspeces && paiementEspeces.statut === "CONFIRME" && (
                                <div className="bg-success/10 border border-success/20 rounded-xl px-4 py-3 flex items-center gap-2">
                                    <div className="w-3 h-3 rounded-full bg-success" />
                                    <p className="text-sm font-medium text-base-content">Paiement confirmé par le conducteur</p>
                                </div>
                            )}

                            {!paiementEspeces && (
                                <>
                                    <div className="bg-info/10 border border-info/20 rounded-xl px-4 py-3 text-sm text-base-content/70 space-y-1">
                                        <p className="font-medium">Comment ça fonctionne :</p>
                                        <ul className="list-disc list-inside space-y-1 text-xs">
                                            <li>Vous réservez maintenant sans payer.</li>
                                            <li>Remettez <strong>{montant.toLocaleString("fr-FR")} FCFA</strong> en espèces au conducteur lors du trajet.</li>
                                            <li>Le conducteur confirmera la réception.</li>
                                        </ul>
                                    </div>
                                    <button
                                        onClick={handleInitierEspeces}
                                        disabled={loadingEspeces}
                                        className="btn btn-primary w-full rounded-full"
                                    >
                                        {loadingEspeces
                                            ? <span className="loading loading-spinner loading-sm" />
                                            : "Confirmer le paiement en espèces"
                                        }
                                    </button>
                                </>
                            )}
                        </div>
                    )}
                </div>
            )}

            {/* ── EN ATTENTE Mobile Money ── */}
            {token && statut?.statut !== "payee" && (
                <div className="bg-base-100 rounded-2xl border border-base-200 p-6 space-y-5 text-center">
                    <div className="w-16 h-16 rounded-full bg-warning/10 flex items-center justify-center mx-auto">
                        {statut?.statut === "echouee"
                            ? <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8 text-error" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                              </svg>
                            : <span className="loading loading-spinner loading-lg text-warning" />
                        }
                    </div>

                    <div>
                        <h2 className="font-semibold text-base-content">
                            {statut?.statut === "echouee" ? "Paiement échoué" : "En attente de confirmation"}
                        </h2>
                        <p className="text-sm text-base-content/50 mt-1">
                            {statut?.statut === "echouee"
                                ? statut.message || "Le paiement a échoué. Veuillez réessayer."
                                : `Confirmez le paiement de ${montant.toLocaleString("fr-FR")} FCFA sur votre téléphone ${phone}`
                            }
                        </p>
                    </div>

                    {/* Opérateur et référence */}
                    <div className="bg-base-200 rounded-xl px-4 py-3 space-y-1 text-left">
                        <div className="flex justify-between text-xs">
                            <span className="text-base-content/40">Opérateur</span>
                            <span className="font-medium">{ICONS[network]} {OPERATEURS_MOBILE_MONEY[network].label}</span>
                        </div>
                        <div className="flex justify-between text-xs">
                            <span className="text-base-content/40">Montant</span>
                            <span className="font-medium">{montant.toLocaleString("fr-FR")} FCFA</span>
                        </div>
                        {transref && (
                            <div className="flex justify-between text-xs">
                                <span className="text-base-content/40">Référence</span>
                                <span className="font-mono text-base-content/70">{transref}</span>
                            </div>
                        )}
                    </div>

                    <div className="flex gap-3">
                        <button
                            onClick={() => handleVerifier(true)}
                            disabled={verifying}
                            className="btn btn-primary rounded-full flex-1"
                        >
                            {verifying
                                ? <span className="loading loading-spinner loading-sm" />
                                : "Vérifier le statut"
                            }
                        </button>
                        <button
                            onClick={handleAnnuler}
                            className="btn btn-ghost rounded-full border border-base-300"
                        >
                            Annuler
                        </button>
                    </div>

                    {statut?.statut !== "echouee" && (
                        <p className="text-xs text-base-content/30">
                            Vérification automatique toutes les 5 secondes…
                        </p>
                    )}
                </div>
            )}

        </div>
    );
}
