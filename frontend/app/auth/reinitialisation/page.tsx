"use client";

import { useState, useEffect } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { reinitialisation } from "@/src/services/auth.service";

type Etape = "formulaire" | "succes" | "lien_invalide";

export default function ReinitialisationPage() {
    const router = useRouter();
    const searchParams = useSearchParams();

    const email = searchParams.get("email");
    const code = searchParams.get("code");

    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [etape, setEtape] = useState<Etape>("formulaire");
    const [showPassword, setShowPassword] = useState(false);
    const [showPassword2, setShowPassword2] = useState(false);

    const [form, setForm] = useState({
        new_password: "",
        new_password2: "",
    });

    // Vérifie que email et code sont présents dans l'URL
    useEffect(() => {
        if (!email || !code) {
            setEtape("lien_invalide");
        }
    }, [email, code]);

    const set = (field: keyof typeof form, value: string) =>
        setForm((prev) => ({ ...prev, [field]: value }));

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();

        if (form.new_password !== form.new_password2) {
            setError("Les mots de passe ne correspondent pas.");
            return;
        }

        if (form.new_password.length < 8) {
            setError("Le mot de passe doit contenir au moins 8 caractères.");
            return;
        }

        setLoading(true);
        setError(null);

        try {
            await reinitialisation({
                email: email!,
                code: code!,
                new_password: form.new_password,
                new_password2: form.new_password2,
            });
            setEtape("succes");
        } catch (err: any) {
            const errors = err.response?.data;
            if (errors && typeof errors === "object") {
                setError(Object.entries(errors).map(([k, v]) => `${k} : ${v}`).join(" | "));
            } else {
                setError("Lien invalide ou expiré. Faites une nouvelle demande.");
            }
        } finally {
            setLoading(false);
        }
    };

    // Force du mot de passe
    const getPasswordStrength = (pwd: string) => {
        if (pwd.length === 0) return null;
        if (pwd.length < 6) return { label: "Trop court", color: "bg-error", width: "w-1/4" };
        if (pwd.length < 8) return { label: "Faible", color: "bg-warning", width: "w-2/4" };
        if (!/[A-Z]/.test(pwd) || !/[0-9]/.test(pwd)) return { label: "Moyen", color: "bg-info", width: "w-3/4" };
        return { label: "Fort", color: "bg-success", width: "w-full" };
    };

    const strength = getPasswordStrength(form.new_password);

    return (
        <div data-theme="winter" className="min-h-screen bg-base-200 flex items-center justify-center px-4 py-12">
            <div className="w-full max-w-md">

                {/* En-tête */}
                <div className="text-center mb-8">
                    <div className="flex justify-center mb-4">
                        <img src="/logo/logo1.png" alt="logo kovoit" width={100} height={100} className="object-contain" />
                    </div>
                    <h1 className="text-3xl font-bold text-base-content">
                        {etape === "succes" ? "Mot de passe modifié !" : "Nouveau mot de passe"}
                    </h1>
                    <p className="text-base-content/60 mt-1">
                        {etape === "formulaire" && "Choisissez un nouveau mot de passe sécurisé"}
                        {etape === "succes" && "Vous pouvez maintenant vous connecter"}
                        {etape === "lien_invalide" && "Ce lien est invalide ou a expiré"}
                    </p>
                </div>

                <div className="card bg-base-100 shadow-xl">
                    <div className="card-body gap-4">

                        {/* ── Lien invalide ── */}
                        {etape === "lien_invalide" && (
                            <div className="text-center py-4 flex flex-col gap-4">
                                <div className="flex justify-center">
                                    <div className="bg-error/10 rounded-full p-6">
                                        <svg xmlns="http://www.w3.org/2000/svg" className="h-16 w-16 text-error" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                                        </svg>
                                    </div>
                                </div>
                                <div>
                                    <p className="font-semibold text-lg">Lien invalide ou expiré</p>
                                    <p className="text-base-content/60 text-sm mt-2">
                                        Ce lien de réinitialisation est invalide ou a expiré.
                                        Faites une nouvelle demande.
                                    </p>
                                </div>
                                <a href="/auth/mot-de-passe-oublie" className="btn btn-primary w-full">
                                    Nouvelle demande
                                </a>
                            </div>
                        )}

                        {/* ── Formulaire ── */}
                        {etape === "formulaire" && (
                            <>
                                {error && (
                                    <div role="alert" className="alert alert-error">
                                        <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                                        </svg>
                                        <span className="text-sm">{error}</span>
                                    </div>
                                )}

                                <form onSubmit={handleSubmit} className="flex flex-col gap-4">

                                    {/* Nouveau mot de passe */}
                                    <div className="form-control">
                                        <label className="label">
                                            <span className="label-text font-semibold">Nouveau mot de passe</span>
                                        </label>
                                        <div className="relative">
                                            <input
                                                type={showPassword ? "text" : "password"}
                                                placeholder="••••••••"
                                                className="input input-bordered w-full pr-12"
                                                value={form.new_password}
                                                onChange={(e) => set("new_password", e.target.value)}
                                                required
                                                minLength={8}
                                            />
                                            <button
                                                type="button"
                                                className="absolute right-3 top-1/2 -translate-y-1/2 text-base-content/40 hover:text-base-content transition"
                                                onClick={() => setShowPassword(!showPassword)}
                                            >
                                                {showPassword ? (
                                                    <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                                                    </svg>
                                                ) : (
                                                    <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                                                    </svg>
                                                )}
                                            </button>
                                        </div>

                                        {/* Jauge de force */}
                                        {strength && (
                                            <div className="mt-2 space-y-1">
                                                <div className="w-full bg-base-300 rounded-full h-1.5">
                                                    <div className={`h-1.5 rounded-full transition-all ${strength.color} ${strength.width}`} />
                                                </div>
                                                <p className="text-xs text-base-content/50">
                                                    Force : <span className="font-medium">{strength.label}</span>
                                                </p>
                                            </div>
                                        )}
                                    </div>

                                    {/* Confirmer mot de passe */}
                                    <div className="form-control">
                                        <label className="label">
                                            <span className="label-text font-semibold">Confirmer le mot de passe</span>
                                        </label>
                                        <div className="relative">
                                            <input
                                                type={showPassword2 ? "text" : "password"}
                                                placeholder="••••••••"
                                                className={`input input-bordered w-full pr-12 ${form.new_password2 && form.new_password !== form.new_password2
                                                        ? "input-error"
                                                        : form.new_password2 && form.new_password === form.new_password2
                                                            ? "input-success"
                                                            : ""
                                                    }`}
                                                value={form.new_password2}
                                                onChange={(e) => set("new_password2", e.target.value)}
                                                required
                                            />
                                            <button
                                                type="button"
                                                className="absolute right-3 top-1/2 -translate-y-1/2 text-base-content/40 hover:text-base-content transition"
                                                onClick={() => setShowPassword2(!showPassword2)}
                                            >
                                                {showPassword2 ? (
                                                    <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                                                    </svg>
                                                ) : (
                                                    <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                                                    </svg>
                                                )}
                                            </button>
                                        </div>

                                        {/* Validation visuelle */}
                                        {form.new_password2 && (
                                            <label className="label">
                                                {form.new_password === form.new_password2 ? (
                                                    <span className="label-text-alt text-success flex items-center gap-1">
                                                        <svg xmlns="http://www.w3.org/2000/svg" className="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
                                                        </svg>
                                                        Les mots de passe correspondent
                                                    </span>
                                                ) : (
                                                    <span className="label-text-alt text-error flex items-center gap-1">
                                                        <svg xmlns="http://www.w3.org/2000/svg" className="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M6 18L18 6M6 6l12 12" />
                                                        </svg>
                                                        Les mots de passe ne correspondent pas
                                                    </span>
                                                )}
                                            </label>
                                        )}
                                    </div>

                                    <button
                                        type="submit"
                                        disabled={loading}
                                        className="btn btn-primary w-full mt-2"
                                    >
                                        {loading
                                            ? <span className="loading loading-spinner loading-sm" />
                                            : "Réinitialiser le mot de passe"
                                        }
                                    </button>
                                </form>
                            </>
                        )}

                        {/* ── Succès ── */}
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
                                    <p className="font-semibold text-lg text-base-content">
                                        Mot de passe modifié avec succès
                                    </p>
                                    <p className="text-base-content/60 text-sm mt-2">
                                        Votre mot de passe a été mis à jour. Vous pouvez maintenant vous connecter.
                                    </p>
                                </div>

                                <button
                                    onClick={() => router.push("/auth/connexion")}
                                    className="btn btn-primary w-full"
                                >
                                    Se connecter
                                </button>
                            </div>
                        )}

                        {/* Lien retour (seulement sur le formulaire) */}
                        {etape === "formulaire" && (
                            <>
                                <div className="divider text-sm">ou</div>
                                <p className="text-center text-sm text-base-content/60">
                                    <a href="/auth/connexion" className="link link-primary font-medium">
                                        ← Retour à la connexion
                                    </a>
                                </p>
                            </>
                        )}

                    </div>
                </div>
            </div>
        </div>
    );
}