"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import {
    getMonWallet, getMesTransactions, getMesRetraits,
    deposerInitier, deposerVerifier, demanderRetrait,
    WALLET_TYPE_LABEL, RETRAIT_STATUT_LABEL,
    type MonWallet, type WalletTransaction, type Retrait,
} from "@/src/services/wallet.service";
import { OPERATEURS_MOBILE_MONEY, type OperateurMobileMoney } from "@/src/services/paiement.service";

const ICONS: Record<OperateurMobileMoney, string> = { FLOOZ: "🔵", YAS: "🟡" };

function fmtFCFA(v: number) {
    return new Intl.NumberFormat("fr-FR", { maximumFractionDigits: 0 }).format(Math.round(v)) + " FCFA";
}

function fmtDate(iso: string | null) {
    if (!iso) return "—";
    return new Date(iso).toLocaleDateString("fr-FR", {
        day: "2-digit", month: "2-digit", year: "numeric", hour: "2-digit", minute: "2-digit",
    });
}

export default function PortefeuillePage() {
    const [wallet, setWallet]           = useState<MonWallet | null>(null);
    const [transactions, setTransactions] = useState<WalletTransaction[]>([]);
    const [retraits, setRetraits]       = useState<Retrait[]>([]);
    const [tab, setTab]                 = useState<"transactions" | "retraits">("transactions");
    const [loading, setLoading]         = useState(true);
    const [error, setError]             = useState<string | null>(null);

    const [showDeposit, setShowDeposit]   = useState(false);
    const [showWithdraw, setShowWithdraw] = useState(false);

    const load = useCallback(async () => {
        setLoading(true);
        setError(null);
        try {
            const [w, t, r] = await Promise.all([getMonWallet(), getMesTransactions(), getMesRetraits()]);
            setWallet(w);
            setTransactions(t);
            setRetraits(r);
        } catch {
            setError("Impossible de charger votre portefeuille.");
        } finally {
            setLoading(false);
        }
    }, []);

    useEffect(() => { load(); }, [load]);

    if (loading) {
        return (
            <div className="space-y-7 animate-pulse">
                <div className="h-6 bg-base-300 rounded w-1/3" />
                <div className="grid grid-cols-2 gap-4">
                    <div className="h-28 bg-base-300 rounded-2xl" />
                    <div className="h-28 bg-base-300 rounded-2xl" />
                </div>
                <div className="h-64 bg-base-300 rounded-2xl" />
            </div>
        );
    }

    return (
        <div className="space-y-7">
            {/* En-tête */}
            <div className="pb-5 border-b border-base-200">
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">Conducteur</p>
                <h1 className="text-2xl font-bold text-base-content tracking-tight">Mon portefeuille</h1>
                <p className="text-sm text-base-content/40 mt-1">
                    Vos gains sur les paiements Mobile Money, vos dépôts et vos retraits.
                </p>
            </div>

            {error && (
                <div className="bg-error/5 border border-error/20 rounded-xl p-4 flex items-center gap-3">
                    <p className="text-sm text-error flex-1">{error}</p>
                    <button onClick={load} className="btn btn-error btn-xs rounded-full">Réessayer</button>
                </div>
            )}

            {/* Dette en cours */}
            {wallet && wallet.solde_du > 0 && (
                <div className="bg-warning/10 border border-warning/30 rounded-2xl p-5 flex items-center justify-between gap-4 flex-wrap">
                    <div className="flex items-center gap-3">
                        <span className="text-2xl">⚠️</span>
                        <div>
                            <p className="font-semibold text-base-content">
                                Vous devez {fmtFCFA(wallet.solde_du)} de commission KoVoit
                            </p>
                            <p className="text-xs text-base-content/50 mt-0.5">
                                Sur vos courses payées en espèces. Déposez pour régler — vous ne pouvez pas retirer tant que cette dette existe.
                            </p>
                        </div>
                    </div>
                    <button onClick={() => setShowDeposit(true)} className="btn btn-warning btn-sm rounded-full shrink-0">
                        Régler maintenant
                    </button>
                </div>
            )}

            {/* Cartes soldes */}
            <div className="grid grid-cols-2 gap-4">
                <div className="rounded-2xl border border-base-200 p-5 bg-green-50 dark:bg-green-950/20">
                    <div className="flex items-center justify-between mb-1">
                        <span className="text-xs text-base-content/40 font-medium uppercase tracking-wide">Solde disponible</span>
                        <span className="text-lg">💰</span>
                    </div>
                    <p className="text-2xl font-bold text-green-600 leading-tight mt-2">
                        {wallet ? fmtFCFA(wallet.solde_disponible) : "—"}
                    </p>
                    <p className="text-xs text-base-content/40 mt-1">Retirable vers Mobile Money</p>
                </div>
                <div className={`rounded-2xl border p-5 ${
                    wallet && wallet.solde_du > 0
                        ? "border-warning/30 bg-warning/5"
                        : "border-base-200 bg-base-100"
                }`}>
                    <div className="flex items-center justify-between mb-1">
                        <span className="text-xs text-base-content/40 font-medium uppercase tracking-wide">Commission due</span>
                        <span className="text-lg">🧾</span>
                    </div>
                    <p className={`text-2xl font-bold leading-tight mt-2 ${
                        wallet && wallet.solde_du > 0 ? "text-warning" : "text-base-content/60"
                    }`}>
                        {wallet ? fmtFCFA(wallet.solde_du) : "—"}
                    </p>
                    <p className="text-xs text-base-content/40 mt-1">Courses réglées en espèces</p>
                </div>
            </div>

            {/* Actions */}
            <div className="flex gap-3 flex-wrap">
                <button onClick={() => setShowDeposit(true)} className="btn btn-primary rounded-full px-6">
                    Déposer
                </button>
                <button
                    onClick={() => setShowWithdraw(true)}
                    disabled={!wallet?.peut_retirer}
                    className="btn btn-outline rounded-full px-6"
                    title={!wallet?.peut_retirer ? "Réglez votre dette et attendez un solde disponible pour retirer" : ""}
                >
                    Retirer
                </button>
            </div>

            {/* Onglets historique */}
            <div className="bg-base-100 rounded-2xl border border-base-200">
                <div className="px-5 pt-4 border-b border-base-200 flex gap-1">
                    {(["transactions", "retraits"] as const).map((t) => (
                        <button
                            key={t}
                            onClick={() => setTab(t)}
                            className={`px-4 py-2 text-sm font-medium rounded-t-lg transition-colors ${
                                tab === t
                                    ? "text-primary border-b-2 border-primary"
                                    : "text-base-content/40 hover:text-base-content"
                            }`}
                        >
                            {t === "transactions" ? "Transactions" : "Retraits"}
                        </button>
                    ))}
                </div>

                {tab === "transactions" ? (
                    transactions.length === 0 ? (
                        <div className="py-16 text-center">
                            <p className="text-4xl mb-3">📜</p>
                            <p className="text-base-content/40 text-sm">Aucune transaction pour le moment.</p>
                        </div>
                    ) : (
                        <div className="divide-y divide-base-200">
                            {transactions.map((t) => (
                                <div key={t.id} className="px-5 py-4 flex items-center justify-between gap-4">
                                    <div className="min-w-0">
                                        <div className="flex items-center gap-2 flex-wrap">
                                            <span className="font-semibold text-sm text-base-content">
                                                {WALLET_TYPE_LABEL[t.type] ?? t.type}
                                            </span>
                                        </div>
                                        {t.description && (
                                            <p className="text-xs text-base-content/40 mt-0.5">{t.description}</p>
                                        )}
                                        <p className="text-xs text-base-content/30 mt-0.5">{fmtDate(t.created_at)}</p>
                                    </div>
                                    <span className={`text-sm font-bold shrink-0 ${
                                        t.sens === "CREDIT" ? "text-green-600" : "text-error"
                                    }`}>
                                        {t.sens === "CREDIT" ? "+" : "−"}{fmtFCFA(t.montant)}
                                    </span>
                                </div>
                            ))}
                        </div>
                    )
                ) : (
                    retraits.length === 0 ? (
                        <div className="py-16 text-center">
                            <p className="text-4xl mb-3">🏦</p>
                            <p className="text-base-content/40 text-sm">Aucun retrait demandé.</p>
                        </div>
                    ) : (
                        <div className="divide-y divide-base-200">
                            {retraits.map((r) => (
                                <div key={r.id} className="px-5 py-4 flex items-center justify-between gap-4">
                                    <div className="min-w-0">
                                        <div className="flex items-center gap-2 flex-wrap">
                                            <span className="font-semibold text-sm text-base-content">
                                                {ICONS[r.moyen]} {OPERATEURS_MOBILE_MONEY[r.moyen]?.label ?? r.moyen}
                                            </span>
                                            <span className="text-xs text-base-content/40">vers {r.numero_destination}</span>
                                        </div>
                                        {r.statut === "ECHOUE" && r.motif_echec && (
                                            <p className="text-xs text-error mt-0.5">{r.motif_echec}</p>
                                        )}
                                        <p className="text-xs text-base-content/30 mt-0.5">
                                            Demandé le {fmtDate(r.date_demande)}
                                            {r.date_traitement ? ` — traité le ${fmtDate(r.date_traitement)}` : ""}
                                        </p>
                                    </div>
                                    <div className="text-right shrink-0">
                                        <p className="text-sm font-bold text-base-content">{fmtFCFA(r.montant)}</p>
                                        <span className={`badge badge-xs rounded-full mt-1 ${
                                            r.statut === "REUSSI" ? "badge-success"
                                            : r.statut === "ECHOUE" ? "badge-error"
                                            : "badge-warning"
                                        }`}>
                                            {RETRAIT_STATUT_LABEL[r.statut]}
                                        </span>
                                    </div>
                                </div>
                            ))}
                        </div>
                    )
                )}
            </div>

            {showDeposit && (
                <DepositModal
                    onClose={() => setShowDeposit(false)}
                    onSuccess={() => { setShowDeposit(false); load(); }}
                />
            )}
            {showWithdraw && wallet && (
                <WithdrawModal
                    soldeDisponible={wallet.solde_disponible}
                    onClose={() => setShowWithdraw(false)}
                    onSuccess={() => { setShowWithdraw(false); load(); }}
                />
            )}
        </div>
    );
}

// ── Modal Dépôt ──────────────────────────────────────────────────────────────

function DepositModal({ onClose, onSuccess }: { onClose: () => void; onSuccess: () => void }) {
    const [montant, setMontant] = useState("");
    const [network, setNetwork] = useState<OperateurMobileMoney>("FLOOZ");
    const [phone, setPhone]     = useState("");
    const [loading, setLoading] = useState(false);
    const [error, setError]     = useState<string | null>(null);

    const [pending, setPending] = useState<{ token: string; transref: string; montant: number; paymentUrl: string } | null>(null);
    const [checking, setChecking] = useState(false);
    const [confirmed, setConfirmed] = useState(false);
    const intervalRef = useRef<NodeJS.Timeout | null>(null);

    useEffect(() => {
        if (!pending || confirmed) return;
        intervalRef.current = setInterval(() => handleVerifier(), 5000);
        return () => { if (intervalRef.current) clearInterval(intervalRef.current); };
    }, [pending, confirmed]);

    const handleInitier = async (e: React.FormEvent) => {
        e.preventDefault();
        const m = Number(montant);
        if (!m || m <= 0) return setError("Entrez un montant valide.");
        if (!phone.trim()) return setError("Entrez votre numéro de téléphone.");
        setLoading(true);
        setError(null);
        try {
            const data = await deposerInitier({ montant: m, phone_number: phone.replace(/\s/g, ""), network });
            setPending({ token: data.token, transref: data.transref, montant: data.montant, paymentUrl: data.payment_url });
            if (data.payment_url) window.open(data.payment_url, "_blank", "noopener,noreferrer");
        } catch (err: any) {
            setError(err.response?.data?.error || "Erreur lors de l'initiation du dépôt.");
        } finally {
            setLoading(false);
        }
    };

    const handleVerifier = async () => {
        if (!pending) return;
        setChecking(true);
        try {
            const data = await deposerVerifier(pending.token, pending.transref);
            if (data.statut === "confirme") {
                setConfirmed(true);
                if (intervalRef.current) clearInterval(intervalRef.current);
            }
        } catch {
            // silencieux pour le polling
        } finally {
            setChecking(false);
        }
    };

    return (
        <div className="modal modal-open">
            <div className="modal-box rounded-2xl max-w-md">
                {confirmed ? (
                    <div className="text-center space-y-4 py-4">
                        <div className="w-16 h-16 rounded-full bg-success/10 flex items-center justify-center mx-auto">
                            <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                            </svg>
                        </div>
                        <div>
                            <h3 className="font-bold text-lg">Dépôt crédité !</h3>
                            <p className="text-sm text-base-content/50 mt-1">Votre portefeuille a été mis à jour.</p>
                        </div>
                        <button onClick={onSuccess} className="btn btn-primary rounded-full px-8">Fermer</button>
                    </div>
                ) : pending ? (
                    <div className="text-center space-y-4 py-2">
                        <span className="loading loading-spinner loading-lg text-warning" />
                        <div>
                            <h3 className="font-bold text-lg">En attente de confirmation</h3>
                            <p className="text-sm text-base-content/50 mt-1">
                                Ouvrez la page de paiement pour confirmer le dépôt de {fmtFCFA(pending.montant)} avec {phone}.
                            </p>
                        </div>
                        {error && <p className="text-sm text-error">{error}</p>}
                        {pending.paymentUrl && (
                            <a
                                href={pending.paymentUrl}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="btn btn-outline btn-sm rounded-full w-full"
                            >
                                Ouvrir la page de paiement
                            </a>
                        )}
                        <div className="flex gap-3 justify-center">
                            <button onClick={handleVerifier} disabled={checking} className="btn btn-primary btn-sm rounded-full">
                                {checking ? <span className="loading loading-spinner loading-xs" /> : "Vérifier maintenant"}
                            </button>
                            <button onClick={onClose} className="btn btn-ghost btn-sm rounded-full border border-base-300">
                                Fermer
                            </button>
                        </div>
                        <p className="text-xs text-base-content/30">Vérification automatique toutes les 5 secondes…</p>
                    </div>
                ) : (
                    <form onSubmit={handleInitier} className="space-y-4">
                        <h3 className="font-bold text-lg">Déposer sur mon portefeuille</h3>

                        <div className="space-y-1">
                            <label className="text-sm font-medium text-base-content">Montant (FCFA)</label>
                            <input
                                type="number" min={1} placeholder="ex : 5000"
                                className="input input-bordered rounded-xl w-full"
                                value={montant} onChange={(e) => setMontant(e.target.value)} required
                            />
                        </div>

                        <div className="space-y-2">
                            <label className="text-sm font-medium text-base-content">Opérateur</label>
                            <div className="grid grid-cols-2 gap-3">
                                {(Object.keys(OPERATEURS_MOBILE_MONEY) as OperateurMobileMoney[]).map((op) => (
                                    <button
                                        key={op} type="button" onClick={() => setNetwork(op)}
                                        className={`flex flex-col items-center gap-1 p-3 rounded-xl border-2 transition-all ${
                                            network === op ? "border-primary bg-primary/5" : "border-base-200 hover:border-base-300"
                                        }`}
                                    >
                                        <span className="text-xl">{ICONS[op]}</span>
                                        <span className={`text-sm font-bold ${network === op ? "text-primary" : "text-base-content"}`}>
                                            {OPERATEURS_MOBILE_MONEY[op].label}
                                        </span>
                                    </button>
                                ))}
                            </div>
                        </div>

                        <div className="space-y-1">
                            <label className="text-sm font-medium text-base-content">
                                Numéro {OPERATEURS_MOBILE_MONEY[network].label}
                            </label>
                            <input
                                type="tel" placeholder="ex : 90 00 00 00"
                                className="input input-bordered rounded-xl w-full"
                                value={phone} onChange={(e) => setPhone(e.target.value)} required
                            />
                        </div>

                        {error && <p className="text-sm text-error">{error}</p>}

                        <div className="flex gap-3 justify-end pt-2">
                            <button type="button" onClick={onClose} className="btn btn-ghost btn-sm rounded-full">Annuler</button>
                            <button type="submit" disabled={loading} className="btn btn-primary btn-sm rounded-full px-6">
                                {loading ? <span className="loading loading-spinner loading-xs" /> : "Déposer"}
                            </button>
                        </div>
                    </form>
                )}
            </div>
            <div className="modal-backdrop" onClick={onClose} />
        </div>
    );
}

// ── Modal Retrait ────────────────────────────────────────────────────────────

function WithdrawModal({ soldeDisponible, onClose, onSuccess }: {
    soldeDisponible: number; onClose: () => void; onSuccess: () => void;
}) {
    const [montant, setMontant] = useState("");
    const [moyen, setMoyen]     = useState<OperateurMobileMoney>("FLOOZ");
    const [numero, setNumero]   = useState("");
    const [loading, setLoading] = useState(false);
    const [error, setError]     = useState<string | null>(null);
    const [done, setDone]       = useState(false);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        const m = Number(montant);
        if (!m || m <= 0) return setError("Entrez un montant valide.");
        if (m > soldeDisponible) return setError("Montant supérieur à votre solde disponible.");
        if (!numero.trim()) return setError("Entrez le numéro de destination.");
        setLoading(true);
        setError(null);
        try {
            await demanderRetrait({ montant: m, moyen, numero_destination: numero.replace(/\s/g, "") });
            setDone(true);
        } catch (err: any) {
            setError(err.response?.data?.error || "Erreur lors de la demande de retrait.");
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="modal modal-open">
            <div className="modal-box rounded-2xl max-w-md">
                {done ? (
                    <div className="text-center space-y-4 py-4">
                        <div className="w-16 h-16 rounded-full bg-success/10 flex items-center justify-center mx-auto">
                            <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                            </svg>
                        </div>
                        <div>
                            <h3 className="font-bold text-lg">Demande enregistrée</h3>
                            <p className="text-sm text-base-content/50 mt-1">
                                Votre retrait sera traité manuellement sous 24 à 48h.
                            </p>
                        </div>
                        <button onClick={onSuccess} className="btn btn-primary rounded-full px-8">Fermer</button>
                    </div>
                ) : (
                    <form onSubmit={handleSubmit} className="space-y-4">
                        <h3 className="font-bold text-lg">Retirer mon solde</h3>
                        <p className="text-xs text-base-content/40">
                            Disponible : {fmtFCFA(soldeDisponible)}
                        </p>

                        <div className="space-y-1">
                            <label className="text-sm font-medium text-base-content">Montant (FCFA)</label>
                            <input
                                type="number" min={1} max={soldeDisponible} placeholder="ex : 5000"
                                className="input input-bordered rounded-xl w-full"
                                value={montant} onChange={(e) => setMontant(e.target.value)} required
                            />
                        </div>

                        <div className="space-y-2">
                            <label className="text-sm font-medium text-base-content">Vers</label>
                            <div className="grid grid-cols-2 gap-3">
                                {(Object.keys(OPERATEURS_MOBILE_MONEY) as OperateurMobileMoney[]).map((op) => (
                                    <button
                                        key={op} type="button" onClick={() => setMoyen(op)}
                                        className={`flex flex-col items-center gap-1 p-3 rounded-xl border-2 transition-all ${
                                            moyen === op ? "border-primary bg-primary/5" : "border-base-200 hover:border-base-300"
                                        }`}
                                    >
                                        <span className="text-xl">{ICONS[op]}</span>
                                        <span className={`text-sm font-bold ${moyen === op ? "text-primary" : "text-base-content"}`}>
                                            {OPERATEURS_MOBILE_MONEY[op].label}
                                        </span>
                                    </button>
                                ))}
                            </div>
                        </div>

                        <div className="space-y-1">
                            <label className="text-sm font-medium text-base-content">
                                Numéro {OPERATEURS_MOBILE_MONEY[moyen].label}
                            </label>
                            <input
                                type="tel" placeholder="ex : 90 00 00 00"
                                className="input input-bordered rounded-xl w-full"
                                value={numero} onChange={(e) => setNumero(e.target.value)} required
                            />
                        </div>

                        {error && <p className="text-sm text-error">{error}</p>}

                        <div className="flex gap-3 justify-end pt-2">
                            <button type="button" onClick={onClose} className="btn btn-ghost btn-sm rounded-full">Annuler</button>
                            <button type="submit" disabled={loading} className="btn btn-primary btn-sm rounded-full px-6">
                                {loading ? <span className="loading loading-spinner loading-xs" /> : "Demander le retrait"}
                            </button>
                        </div>
                    </form>
                )}
            </div>
            <div className="modal-backdrop" onClick={onClose} />
        </div>
    );
}
