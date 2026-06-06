"use client";

import { useState, useEffect, useRef } from "react";
import { useParams, useRouter } from "next/navigation";
import { api } from "@/src/services/api";
import {
    initierPaiement,
    verifierPaiement,
    initierPaiementEspeces,
    soumettreReferenceMobile,
    getStatutPaiementReservation,
    type PaiementStatut,
    type PaiementReservationResponse,
} from "@/src/services/paiement.service";

export default function PaiementPage() {
    const { id } = useParams(); // reservation_id
    const router = useRouter();

    const [reservation, setReservation] = useState<any>(null);
    const [loading, setLoading] = useState(true);
    const [paying, setPaying] = useState(false);
    const [error, setError] = useState<string | null>(null);

    // Formulaire paiement mobile manuel
    const [network, setNetwork]   = useState<"FLOOZ" | "TMONEY">("TMONEY");
    const [referenceUssd, setReferenceUssd] = useState("");
    const [methode, setMethode]   = useState<"mobile_manuel" | "especes">("mobile_manuel");
    const [mobileSuccess, setMobileSuccess] = useState(false);

    // Formulaire paiement mobile PayGate (legacy)
    const [phone, setPhone] = useState("");

    // État du paiement espèces
    const [paiementEspeces, setPaiementEspeces] = useState<PaiementReservationResponse | null>(null);
    const [loadingEspeces, setLoadingEspeces] = useState(false);

    // État après initiation mobile money
    const [identifier, setIdentifier] = useState<string | null>(null);
    const [txReference, setTxReference] = useState<string | null>(null);
    const [statut, setStatut] = useState<PaiementStatut | null>(null);
    const [verifying, setVerifying] = useState(false);
    const intervalRef = useRef<NodeJS.Timeout | null>(null);

    useEffect(() => {
        const fetch = async () => {
            try {
                // Charger la réservation via l'endpoint retrieve standard
                const data = await api(`/reservations/${id}/`, "GET");
                setReservation(data);
            } catch {
                // Fallback — charger depuis mes_reservations si retrieve échoue
                try {
                    const all = await api("/reservations/mes_reservations/", "GET");
                    const r = all.find((r: any) => r.id === Number(id));
                    setReservation(r || null);
                } catch {
                    setReservation(null);
                }
            }

            // Vérifier le statut de paiement existant
            try {
                const paiementStatut = await getStatutPaiementReservation(Number(id));
                setPaiementEspeces(paiementStatut);
            } catch (err: any) {
                // Ne pas bloquer si pas de paiement ou erreur d'auth
                if (err.response?.status !== 401 && err.response?.status !== 403) {
                    setPaiementEspeces(null);
                }
            } finally {
                setLoading(false);
            }
        };
        if (id) fetch();
    }, [id]);

    // Polling toutes les 5 secondes après initiation mobile money
    useEffect(() => {
        if (!identifier) return;
        intervalRef.current = setInterval(async () => {
            await handleVerifier(false);
        }, 5000);
        return () => {
            if (intervalRef.current) {
                clearInterval(intervalRef.current);
            }
        };
    }, [identifier]);

    // Arrêter le polling si paiement mobile money terminé
    useEffect(() => {
        if (statut?.statut === "payee" || statut?.statut === "echouee") {
            if (intervalRef.current) {
                clearInterval(intervalRef.current);
            }
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
                phone_number: phone,
                network,
            });
            setIdentifier(data.identifier);
            setTxReference(data.tx_reference);
        } catch (err: any) {
            setError(err.response?.data?.error || "Erreur lors de l'initiation du paiement.");
        } finally {
            setPaying(false);
        }
    };

    const handleVerifier = async (manuel = true) => {
        if (!identifier) return;
        if (manuel) setVerifying(true);
        try {
            const data = await verifierPaiement(identifier);
            setStatut(data);
            if (data.statut === "payee") {
                if (intervalRef.current) {
                    clearInterval(intervalRef.current);
                }
            }
        } catch {
            // Silencieux pour le polling automatique
        } finally {
            if (manuel) setVerifying(false);
        }
    };

    const handleSoumettreReference = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!referenceUssd.trim()) return setError("Entrez la référence reçue.");
        setPaying(true);
        setError(null);
        try {
            await soumettreReferenceMobile({
                reservation_id: Number(id),
                reference_mobile: referenceUssd.trim(),
                network,
            });
            setMobileSuccess(true);
        } catch (err: any) {
            setError(err.response?.data?.error || "Erreur lors de la soumission.");
        } finally {
            setPaying(false);
        }
    };

    const handleInitierEspeces = async () => {
        setLoadingEspeces(true);
        setError(null);

        // Double protection : vérifier localement si un paiement existe déjà
        if (paiementEspeces && paiementEspeces.statut !== 'ANNULE') {
            setError("Un paiement existe déjà pour cette réservation.");
            setLoadingEspeces(false);
            return;
        }

        try {
            const data = await initierPaiementEspeces({
                reservation_id: Number(id),
            });
            setPaiementEspeces({
                paiement_id: data.paiement_id,
                statut: data.statut,
                moyen_paiement: 'ESPECE',
                montant: data.montant,
                date_creation: new Date().toISOString(),
            });
        } catch (err: any) {
            setError(err.response?.data?.error || "Erreur lors de l'initiation du paiement en espèces.");
        } finally {
            setLoadingEspeces(false);
        }
    };

    // Rendu du statut de paiement espèces
    const renderStatutEspeces = () => {
        if (!paiementEspeces) return null;

        switch (paiementEspeces.statut) {
            case 'EN_ATTENTE_CONFIRMATION':
                return (
                    <div className="bg-warning/10 border border-warning/20 rounded-xl px-4 py-3">
                        <div className="flex items-center gap-2">
                            <div className="w-3 h-3 rounded-full bg-warning animate-pulse" />
                            <p className="text-sm font-medium text-base-content">
                                🔵 En attente de confirmation du conducteur
                            </p>
                        </div>
                    </div>
                );
            case 'CONFIRME':
                return (
                    <div className="bg-success/10 border border-success/20 rounded-xl px-4 py-3">
                        <div className="flex items-center gap-2">
                            <div className="w-3 h-3 rounded-full bg-success" />
                            <p className="text-sm font-medium text-base-content">
                                🟢 Paiement confirmé
                            </p>
                        </div>
                    </div>
                );
            default:
                return null;
        }
    };

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
                <button onClick={() => router.back()} className="btn btn-ghost btn-sm rounded-full mt-4">
                    Retour
                </button>
            </div>
        );
    }

    const montant = Number(reservation.prix_par_place);
    const commission = Math.round(montant * 0.10);

    // ── Écran succès ──────────────────────────────────────────────────────
    if (statut?.statut === "payee") {
        return (
            <div className="max-w-lg mx-auto py-16 text-center space-y-5">
                <div className="w-20 h-20 rounded-full bg-success/10 flex items-center justify-center mx-auto">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-10 w-10 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                </div>
                <div>
                    <h2 className="text-2xl font-bold text-base-content">Paiement réussi</h2>
                    <p className="text-base-content/50 text-sm mt-1">
                        {montant.toLocaleString("fr-FR")} FCFA débités via {statut.payment_method}
                    </p>
                </div>
                {statut.payment_reference && (
                    <div className="bg-base-200 rounded-xl px-4 py-3">
                        <p className="text-xs text-base-content/40 uppercase tracking-wide">Référence de paiement</p>
                        <p className="text-sm font-mono font-semibold text-base-content mt-1">
                            {statut.payment_reference}
                        </p>
                    </div>
                )}
                <div className="flex gap-3 justify-center pt-2">
                    <button
                        onClick={() => router.push("/passager/reservations")}
                        className="btn btn-primary rounded-full px-6"
                    >
                        Mes réservations
                    </button>
                </div>
            </div>
        );
    }

    return (
        <div className="max-w-lg mx-auto space-y-6">

            {/* EN-TÊTE */}
            <div className="flex items-center gap-3 pb-4 border-b border-base-300">
                <button onClick={() => router.back()}
                    className="btn btn-ghost btn-sm btn-square rounded-xl">
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

            {/* RÉSUMÉ */}
            <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                <div className="divide-y divide-base-200">
                    {[
                        { label: "Prix par place", value: `${montant.toLocaleString("fr-FR")} FCFA` },
                        { label: "Commission KoVoit", value: `${commission.toLocaleString("fr-FR")} FCFA` },
                        { label: "Conducteur reçoit", value: `${(montant - commission).toLocaleString("fr-FR")} FCFA` },
                    ].map((item) => (
                        <div key={item.label} className="flex justify-between items-center px-5 py-3">
                            <span className="text-xs text-base-content/40 uppercase tracking-wide">{item.label}</span>
                            <span className="text-sm font-semibold text-base-content">{item.value}</span>
                        </div>
                    ))}
                </div>
                <div className="px-5 py-4 bg-primary/5 border-t border-primary/10 flex items-center justify-between">
                    <span className="text-sm font-medium text-base-content/60">Total à payer</span>
                    <span className="text-2xl font-bold text-primary">
                        {montant.toLocaleString("fr-FR")} FCFA
                    </span>
                </div>
            </div>

            {/* Erreur */}
            {error && (
                <div className="bg-error/10 border border-error/20 rounded-xl px-4 py-3">
                    <p className="text-sm text-error">{error}</p>
                </div>
            )}

            {/* ── Choix méthode + formulaires ── */}
            {!identifier && !mobileSuccess && (
                <div className="space-y-5">

                    {/* Choix méthode */}
                    <div className="bg-base-100 rounded-2xl border border-base-200 p-5 space-y-4">
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                            Méthode de paiement
                        </p>
                        <div className="grid grid-cols-2 gap-3">
                            {[
                                { value: "mobile_manuel", label: "📱 T-Money / Flooz" },
                                { value: "especes",       label: "💵 Espèces" },
                            ].map((m) => (
                                <button key={m.value} type="button"
                                    onClick={() => setMethode(m.value as any)}
                                    className={`btn rounded-xl ${methode === m.value ? "btn-primary" : "btn-outline"}`}
                                >
                                    {m.label}
                                </button>
                            ))}
                        </div>
                    </div>

                    {/* ── T-Money / Flooz (Manuel USSD) ── */}
                    {methode === "mobile_manuel" && (
                        <form onSubmit={handleSoumettreReference}
                            className="bg-base-100 rounded-2xl border border-base-200 p-5 space-y-5">

                            <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                                Paiement T-Money / Flooz
                            </p>

                            {/* Choix réseau */}
                            <div className="grid grid-cols-2 gap-3">
                                {[
                                    { value: "TMONEY", label: "T-Money",    color: "border-orange-400 text-orange-600" },
                                    { value: "FLOOZ",  label: "Flooz (Yas)", color: "border-green-500 text-green-600" },
                                ].map((n) => (
                                    <button key={n.value} type="button"
                                        onClick={() => setNetwork(n.value as any)}
                                        className={`btn btn-sm rounded-xl font-semibold border-2 transition-all ${
                                            network === n.value
                                                ? "btn-primary border-primary"
                                                : `bg-base-100 ${n.color}`
                                        }`}
                                    >
                                        {n.label}
                                    </button>
                                ))}
                            </div>

                            {/* Code USSD à composer */}
                            <div className="bg-base-200 rounded-2xl p-4 space-y-2">
                                <p className="text-xs text-base-content/50 uppercase tracking-wide font-medium">
                                    1. Composez ce code sur votre téléphone
                                </p>
                                <div className="bg-base-100 rounded-xl px-4 py-3 flex items-center justify-between gap-3 border border-base-300">
                                    <code className="text-lg font-bold tracking-wider text-primary">
                                        {network === "TMONEY"
                                            ? `*145*1*${montant}*${reservation?.conducteur_telephone || "XXXXXXXXX"}#`
                                            : `*144*1*${montant}*${reservation?.conducteur_telephone || "XXXXXXXXX"}#`
                                        }
                                    </code>
                                    <button type="button"
                                        onClick={() => navigator.clipboard?.writeText(
                                            network === "TMONEY"
                                                ? `*145*1*${montant}*${reservation?.conducteur_telephone || ""}#`
                                                : `*144*1*${montant}*${reservation?.conducteur_telephone || ""}#`
                                        )}
                                        className="btn btn-ghost btn-xs rounded-lg"
                                        title="Copier"
                                    >
                                        📋
                                    </button>
                                </div>
                                <p className="text-xs text-base-content/40">
                                    {network === "TMONEY" ? "T-Money (Moov Africa)" : "Flooz (Yas Mobile)"}
                                    &nbsp;·&nbsp;Montant : <strong>{montant.toLocaleString("fr-FR")} FCFA</strong>
                                    {reservation?.conducteur_telephone && (
                                        <>&nbsp;·&nbsp;N° conducteur : <strong>{reservation.conducteur_telephone}</strong></>
                                    )}
                                </p>
                            </div>

                            {/* Saisie référence */}
                            <div className="space-y-2">
                                <p className="text-xs text-base-content/50 uppercase tracking-wide font-medium">
                                    2. Entrez la référence reçue par SMS
                                </p>
                                <input
                                    type="text"
                                    placeholder="ex : TM240605123456 ou FL240605987654"
                                    className="input input-bordered rounded-xl w-full font-mono tracking-wide"
                                    value={referenceUssd}
                                    onChange={(e) => setReferenceUssd(e.target.value.toUpperCase())}
                                    required
                                />
                                <p className="text-xs text-base-content/30">
                                    La référence est le code de confirmation envoyé par SMS après le virement.
                                </p>
                            </div>

                            <button type="submit" disabled={paying || !referenceUssd.trim()}
                                className="btn btn-primary w-full rounded-full">
                                {paying
                                    ? <span className="loading loading-spinner loading-sm" />
                                    : "Confirmer mon paiement"
                                }
                            </button>
                        </form>
                    )}

                    {/* ── Espèces ── */}
                    {methode === "especes" && (
                        <div className="bg-base-100 rounded-2xl border border-base-200 p-5 space-y-4">
                            <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                                Paiement en espèces
                            </p>

                            {paiementEspeces && renderStatutEspeces()}

                            {!paiementEspeces && (
                                <>
                                    <div className="bg-warning/10 border border-warning/20 rounded-xl px-4 py-3">
                                        <p className="text-sm text-base-content/70">
                                            Remettez l'argent directement au conducteur lors du trajet.
                                            Il devra confirmer la réception.
                                        </p>
                                    </div>
                                    <div className="flex justify-between py-2 border-b border-base-200">
                                        <span className="text-xs text-base-content/40 uppercase tracking-wide">À remettre</span>
                                        <span className="text-sm font-bold text-base-content">{montant.toLocaleString("fr-FR")} FCFA</span>
                                    </div>
                                    <button onClick={handleInitierEspeces} disabled={loadingEspeces}
                                        className="btn btn-primary w-full rounded-full">
                                        {loadingEspeces
                                            ? <span className="loading loading-spinner loading-sm" />
                                            : "Payer en espèces"
                                        }
                                    </button>
                                </>
                            )}
                        </div>
                    )}
                </div>
            )}

            {/* ── Succès paiement mobile manuel ── */}
            {mobileSuccess && (
                <div className="bg-base-100 rounded-2xl border border-success/20 p-6 space-y-4 text-center">
                    <div className="w-16 h-16 rounded-full bg-success/10 flex items-center justify-center mx-auto">
                        <span className="text-3xl">✅</span>
                    </div>
                    <div>
                        <h2 className="font-bold text-lg text-base-content">Référence soumise !</h2>
                        <p className="text-sm text-base-content/50 mt-1">
                            Référence <strong className="font-mono">{referenceUssd}</strong> enregistrée.
                        </p>
                        <p className="text-sm text-base-content/50 mt-1">
                            En attente de confirmation du conducteur.
                        </p>
                    </div>
                    <button onClick={() => router.push("/passager/reservations")}
                        className="btn btn-primary rounded-full w-full">
                        Mes réservations
                    </button>
                </div>
            )}

            {/* ── Après initiation mobile money — attente confirmation ── */}
            {identifier && (statut?.statut === "en_attente" || statut?.statut === "echouee") && (
                <div className="bg-base-100 rounded-2xl border border-base-200 p-6 space-y-5 text-center">
                    <div className="w-16 h-16 rounded-full bg-warning/10 flex items-center justify-center mx-auto">
                        <span className="loading loading-spinner loading-lg text-warning" />
                    </div>

                    <div>
                        <h2 className="font-semibold text-base-content">En attente de confirmation</h2>
                        <p className="text-sm text-base-content/50 mt-1">
                            Confirmez le paiement de {montant.toLocaleString("fr-FR")} FCFA
                            sur votre téléphone {phone}
                        </p>
                    </div>

                    {statut?.statut === "echouee" && (
                        <div className="bg-error/10 border border-error/20 rounded-xl px-4 py-3">
                            <p className="text-sm text-error">{statut.message}</p>
                        </div>
                    )}

                    {txReference && (
                        <div className="bg-base-200 rounded-xl px-4 py-2">
                            <p className="text-xs text-base-content/40">Référence transaction</p>
                            <p className="text-xs font-mono text-base-content">{txReference}</p>
                        </div>
                    )}

                    <div className="flex gap-3">
                        <button
                            onClick={() => handleVerifier(true)}
                            disabled={verifying}
                            className="btn btn-primary rounded-full flex-1"
                        >
                            {verifying
                                ? <span className="loading loading-spinner loading-sm" />
                                : "Vérifier le paiement"
                            }
                        </button>
                        <button
                            onClick={() => { setIdentifier(null); setStatut(null); setError(null); }}
                            className="btn btn-ghost rounded-full border border-base-300"
                        >
                            Annuler
                        </button>
                    </div>

                    <p className="text-xs text-base-content/30">
                        Vérification automatique toutes les 5 secondes...
                    </p>
                </div>
            )}

        </div>
    );
}