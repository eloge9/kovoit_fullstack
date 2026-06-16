"use client";

import { useState, useRef } from "react";
import { useRouter } from "next/navigation";
import Image from "next/image";
import { demanderCodeReset, reinitialisation } from "@/src/services/auth.service";

type Etape = "email" | "code" | "password" | "succes";

export default function MotDePasseOubliePage() {
    const router = useRouter();
    const [etape, setEtape] = useState<Etape>("email");
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState("");

    const [email, setEmail] = useState("");
    const [digits, setDigits] = useState(["", "", "", "", "", ""]);
    const [newPassword, setNewPassword] = useState("");
    const [newPassword2, setNewPassword2] = useState("");
    const [showPwd, setShowPwd] = useState(false);
    const [showPwd2, setShowPwd2] = useState(false);

    const inputRefs = useRef<(HTMLInputElement | null)[]>([]);

    // ── Étape 1 : envoi email ────────────────────────────────────────────────
    const handleEnvoyerEmail = async (e: React.FormEvent) => {
        e.preventDefault();
        setError("");
        setLoading(true);
        try {
            await demanderCodeReset(email);
            setEtape("code");
        } catch (err: unknown) {
            const msg = (err as { response?: { data?: { error?: string } } })?.response?.data?.error;
            setError(msg || "Une erreur est survenue.");
        } finally {
            setLoading(false);
        }
    };

    // ── Étape 2 : saisie du code OTP ─────────────────────────────────────────
    const handleDigitChange = (i: number, val: string) => {
        if (!/^\d?$/.test(val)) return;
        const next = [...digits];
        next[i] = val;
        setDigits(next);
        if (val && i < 5) inputRefs.current[i + 1]?.focus();
    };

    const handleDigitKeyDown = (i: number, e: React.KeyboardEvent) => {
        if (e.key === "Backspace" && !digits[i] && i > 0) {
            inputRefs.current[i - 1]?.focus();
        }
    };

    const handleVerifierCode = (e: React.FormEvent) => {
        e.preventDefault();
        setError("");
        const code = digits.join("");
        if (code.length < 6) {
            setError("Saisissez les 6 chiffres du code.");
            return;
        }
        setEtape("password");
    };

    // ── Étape 3 : nouveau mot de passe ───────────────────────────────────────
    const getStrength = (pwd: string) => {
        if (!pwd) return null;
        if (pwd.length < 6) return { label: "Trop court", color: "bg-error", w: "w-1/4" };
        if (pwd.length < 8) return { label: "Faible", color: "bg-warning", w: "w-2/4" };
        if (!/[A-Z]/.test(pwd) || !/[0-9]/.test(pwd)) return { label: "Moyen", color: "bg-info", w: "w-3/4" };
        return { label: "Fort", color: "bg-success", w: "w-full" };
    };

    const handleReinitialiser = async (e: React.FormEvent) => {
        e.preventDefault();
        setError("");
        if (newPassword !== newPassword2) {
            setError("Les mots de passe ne correspondent pas.");
            return;
        }
        if (newPassword.length < 8) {
            setError("Le mot de passe doit contenir au moins 8 caractères.");
            return;
        }
        setLoading(true);
        try {
            await reinitialisation({
                email,
                code: digits.join(""),
                new_password: newPassword,
                new_password2: newPassword2,
            });
            setEtape("succes");
        } catch (err: unknown) {
            const msg = (err as { response?: { data?: { error?: string } } })?.response?.data?.error;
            setError(msg || "Code invalide ou expiré.");
        } finally {
            setLoading(false);
        }
    };

    const strength = getStrength(newPassword);

    const titres: Record<Etape, string> = {
        email:    "Mot de passe oublié",
        code:     "Vérification du code",
        password: "Nouveau mot de passe",
        succes:   "Mot de passe modifié !",
    };
    const subtitres: Record<Etape, string> = {
        email:    "Entrez votre email pour recevoir un code",
        code:     `Code envoyé à ${email}`,
        password: "Choisissez un nouveau mot de passe sécurisé",
        succes:   "Vous pouvez maintenant vous connecter",
    };

    return (
        <div data-theme="winter" className="min-h-screen bg-base-200 flex items-center justify-center px-4 py-12">
            <div className="w-full max-w-md">

                {/* En-tête */}
                <div className="text-center mb-8">
                    <div className="mb-4 flex justify-center">
                        <Image src="/logo/logo1.png" alt="KoVoit" width={80} height={80} />
                    </div>
                    <h1 className="text-2xl font-bold text-base-content">{titres[etape]}</h1>
                    <p className="text-base-content/60 mt-1 text-sm">{subtitres[etape]}</p>
                </div>

                {/* Indicateur d'étapes */}
                {etape !== "succes" && (
                    <div className="flex items-center justify-center gap-2 mb-6">
                        {(["email", "code", "password"] as const).map((e, i) => (
                            <div key={e} className="flex items-center gap-2">
                                <div className={`w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold transition-all ${
                                    etape === e ? "bg-primary text-primary-content" :
                                    ["email", "code", "password"].indexOf(etape) > i ? "bg-success text-success-content" :
                                    "bg-base-300 text-base-content/40"
                                }`}>
                                    {["email", "code", "password"].indexOf(etape) > i ? "✓" : i + 1}
                                </div>
                                {i < 2 && <div className={`w-8 h-0.5 ${["email","code","password"].indexOf(etape) > i ? "bg-success" : "bg-base-300"}`} />}
                            </div>
                        ))}
                    </div>
                )}

                <div className="card bg-base-100 shadow-xl">
                    <div className="card-body gap-4">

                        {error && (
                            <div className="alert alert-error text-sm">
                                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                                </svg>
                                <span>{error}</span>
                            </div>
                        )}

                        {/* ── ÉTAPE 1 : EMAIL ── */}
                        {etape === "email" && (
                            <form onSubmit={handleEnvoyerEmail} className="flex flex-col gap-4">
                                <div className="form-control">
                                    <label className="label">
                                        <span className="label-text font-semibold">Adresse email</span>
                                    </label>
                                    <input
                                        type="email"
                                        placeholder="exemple@email.com"
                                        className="input input-bordered w-full"
                                        value={email}
                                        onChange={(e) => setEmail(e.target.value)}
                                        required
                                        autoComplete="email"
                                        autoFocus
                                    />
                                    <label className="label">
                                        <span className="label-text-alt text-base-content/50">
                                            Un code à 6 chiffres valable 10 minutes vous sera envoyé
                                        </span>
                                    </label>
                                </div>
                                <button type="submit" disabled={loading} className="btn btn-primary w-full">
                                    {loading ? <span className="loading loading-spinner loading-sm" /> : "Envoyer le code"}
                                </button>
                            </form>
                        )}

                        {/* ── ÉTAPE 2 : CODE OTP ── */}
                        {etape === "code" && (
                            <form onSubmit={handleVerifierCode} className="flex flex-col gap-6">
                                <div>
                                    <p className="text-sm text-center text-base-content/60 mb-4">
                                        Entrez le code à 6 chiffres reçu par email
                                    </p>
                                    <div className="flex justify-center gap-2">
                                        {digits.map((d, i) => (
                                            <input
                                                key={i}
                                                ref={(el) => { inputRefs.current[i] = el; }}
                                                type="text"
                                                inputMode="numeric"
                                                maxLength={1}
                                                value={d}
                                                onChange={(e) => handleDigitChange(i, e.target.value)}
                                                onKeyDown={(e) => handleDigitKeyDown(i, e)}
                                                className="input input-bordered w-11 h-14 text-center text-xl font-bold rounded-xl focus:input-primary"
                                                autoFocus={i === 0}
                                            />
                                        ))}
                                    </div>
                                </div>
                                <button type="submit" className="btn btn-primary w-full">
                                    Vérifier le code
                                </button>
                                <button
                                    type="button"
                                    onClick={async () => {
                                        setError("");
                                        setLoading(true);
                                        try { await demanderCodeReset(email); setDigits(["","","","","",""]); }
                                        catch { setError("Impossible de renvoyer le code."); }
                                        finally { setLoading(false); }
                                    }}
                                    disabled={loading}
                                    className="btn btn-ghost btn-sm"
                                >
                                    {loading ? <span className="loading loading-spinner loading-xs" /> : "Renvoyer le code"}
                                </button>
                            </form>
                        )}

                        {/* ── ÉTAPE 3 : NOUVEAU MOT DE PASSE ── */}
                        {etape === "password" && (
                            <form onSubmit={handleReinitialiser} className="flex flex-col gap-4">
                                <div className="form-control">
                                    <label className="label">
                                        <span className="label-text font-semibold">Nouveau mot de passe</span>
                                    </label>
                                    <div className="relative">
                                        <input
                                            type={showPwd ? "text" : "password"}
                                            placeholder="••••••••"
                                            className="input input-bordered w-full pr-12"
                                            value={newPassword}
                                            onChange={(e) => setNewPassword(e.target.value)}
                                            required minLength={8} autoFocus
                                        />
                                        <button type="button" onClick={() => setShowPwd(!showPwd)}
                                            className="absolute right-3 top-1/2 -translate-y-1/2 text-base-content/40 hover:text-base-content">
                                            {showPwd
                                                ? <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" /></svg>
                                                : <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                                            }
                                        </button>
                                    </div>
                                    {strength && (
                                        <div className="mt-2 space-y-1">
                                            <div className="w-full bg-base-300 rounded-full h-1.5">
                                                <div className={`h-1.5 rounded-full transition-all ${strength.color} ${strength.w}`} />
                                            </div>
                                            <p className="text-xs text-base-content/50">Force : <span className="font-medium">{strength.label}</span></p>
                                        </div>
                                    )}
                                </div>

                                <div className="form-control">
                                    <label className="label">
                                        <span className="label-text font-semibold">Confirmer le mot de passe</span>
                                    </label>
                                    <div className="relative">
                                        <input
                                            type={showPwd2 ? "text" : "password"}
                                            placeholder="••••••••"
                                            className={`input input-bordered w-full pr-12 ${newPassword2 && newPassword !== newPassword2 ? "input-error" : newPassword2 && newPassword === newPassword2 ? "input-success" : ""}`}
                                            value={newPassword2}
                                            onChange={(e) => setNewPassword2(e.target.value)}
                                            required
                                        />
                                        <button type="button" onClick={() => setShowPwd2(!showPwd2)}
                                            className="absolute right-3 top-1/2 -translate-y-1/2 text-base-content/40 hover:text-base-content">
                                            {showPwd2
                                                ? <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" /></svg>
                                                : <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                                            }
                                        </button>
                                    </div>
                                    {newPassword2 && (
                                        <label className="label">
                                            {newPassword === newPassword2
                                                ? <span className="label-text-alt text-success">✓ Les mots de passe correspondent</span>
                                                : <span className="label-text-alt text-error">✗ Les mots de passe ne correspondent pas</span>
                                            }
                                        </label>
                                    )}
                                </div>

                                <button type="submit" disabled={loading} className="btn btn-primary w-full mt-2">
                                    {loading ? <span className="loading loading-spinner loading-sm" /> : "Réinitialiser le mot de passe"}
                                </button>
                            </form>
                        )}

                        {/* ── SUCCÈS ── */}
                        {etape === "succes" && (
                            <div className="text-center py-4 flex flex-col gap-4">
                                <div className="flex justify-center">
                                    <div className="bg-success/10 rounded-full p-6">
                                        <svg xmlns="http://www.w3.org/2000/svg" className="h-16 w-16 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                                        </svg>
                                    </div>
                                </div>
                                <div>
                                    <p className="font-semibold text-lg">Mot de passe modifié avec succès</p>
                                    <p className="text-base-content/60 text-sm mt-2">Vous pouvez maintenant vous connecter avec votre nouveau mot de passe.</p>
                                </div>
                                <button onClick={() => router.push("/auth/connexion")} className="btn btn-primary w-full">
                                    Se connecter
                                </button>
                            </div>
                        )}

                        {etape !== "succes" && (
                            <>
                                <div className="divider text-xs">ou</div>
                                <p className="text-center text-sm text-base-content/60">
                                    <a href="/auth/connexion" className="link link-primary font-medium">← Retour à la connexion</a>
                                </p>
                            </>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
}
