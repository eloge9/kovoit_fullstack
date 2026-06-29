"use client";

import { Suspense, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import logoSrc from "@/public/logo/logo1.png";
import { useAuth } from "@/src/hooks/useAuth";
import { connexion } from "@/src/services/auth.service";

function ConnexionForm() {
    const router = useRouter();
    const searchParams = useSearchParams();
    const { login } = useAuth();
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [showPassword, setShowPassword] = useState(false);
    const [form, setForm] = useState({ email: "", password: "" });

    const set = (field: keyof typeof form, value: string) =>
        setForm((prev) => ({ ...prev, [field]: value }));

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);
        setError(null);
        try {
            const data = await connexion({ email: form.email, password: form.password });

            await login(data);

            const redirect = searchParams.get("redirect");
            if (redirect) {
                router.push(redirect);
            } else {
                const role = data.utilisateur?.role;
                if (role === "conducteur") {
                    router.push("/conducteur/dashboard");
                } else if (role === "passager") {
                    router.push("/passager/dashboard");
                } else if (role === "admin") {
                    router.push("/admin/dashboard");
                }
            }

        } catch (err: any) {
            const data = err.response?.data;
            if (data) {
                // Erreur serveur explicite ({"error": "..."} ou {"detail": "..."})
                if (data.error) { setError(data.error); }
                else if (data.detail) { setError(data.detail); }
                // Erreurs de validation par champ ({"email": [...], "password": [...]})
                else if (typeof data === "object") {
                    const msgs = Object.entries(data).map(([, v]) =>
                        Array.isArray(v) ? v.join(", ") : String(v)
                    );
                    setError(msgs.join(" — ") || "Email ou mot de passe incorrect.");
                } else {
                    setError("Email ou mot de passe incorrect.");
                }
            } else {
                setError("Impossible de contacter le serveur. Vérifiez que le backend est démarré.");
            }
        } finally {
            setLoading(false);
        }
    };

    return (
        <div data-theme="winter" className="min-h-screen bg-base-200 flex items-center justify-center px-4 py-12">
            <div className="w-full max-w-md">

                {/* En-tête */}
                <div className="text-center mb-8">
                    <div className="flex justify-center mb-4">
                        <img src={logoSrc.src} alt="logo kovoit" width={100} height={100} className="object-contain" />
                    </div>
                    <h1 className="text-3xl font-bold text-base-content">Bon retour !</h1>
                    <p className="text-base-content/60 mt-1">Connectez-vous à votre compte</p>
                </div>

                {/* Card */}
                <div className="card bg-base-100 shadow-xl">
                    <div className="card-body gap-4">

                        {/* Erreur */}
                        {error && (
                            <div role="alert" className="alert alert-error">
                                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                                </svg>
                                <span className="text-sm">{error}</span>
                            </div>
                        )}

                        <form onSubmit={handleSubmit} className="flex flex-col gap-4">

                            {/* Email */}
                            <div className="form-control">
                                <label className="label">
                                    <span className="label-text font-semibold">Email</span>
                                </label>
                                <input
                                    type="email"
                                    placeholder="exemple@email.com"
                                    className="input input-bordered w-full"
                                    value={form.email}
                                    onChange={(e) => set("email", e.target.value)}
                                    required
                                    autoComplete="email"
                                />
                            </div>

                            {/* Mot de passe */}
                            <div className="form-control">
                                <label className="label">
                                    <span className="label-text font-semibold">Mot de passe</span>
                                    <a href="/auth/mot-de-passe-oublie" className="label-text-alt link link-primary">
                                        Mot de passe oublié ?
                                    </a>
                                </label>
                                <div className="relative">
                                    <input
                                        type={showPassword ? "text" : "password"}
                                        placeholder="••••••••"
                                        className="input input-bordered w-full pr-12"
                                        value={form.password}
                                        onChange={(e) => set("password", e.target.value)}
                                        required
                                        autoComplete="current-password"
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
                            </div>

                            {/* Bouton */}
                            <button
                                type="submit"
                                disabled={loading}
                                className="btn btn-primary w-full mt-2"
                            >
                                {loading
                                    ? <span className="loading loading-spinner loading-sm" />
                                    : "Se connecter"
                                }
                            </button>
                        </form>

                        {/* Lien inscription */}
                        <div className="divider text-sm">ou</div>
                        <p className="text-center text-sm text-base-content/60">
                            Pas encore de compte ?{" "}
                            <a href="/auth/inscription" className="link link-primary font-medium">
                                S'inscrire
                            </a>
                        </p>

                    </div>
                </div>
            </div>
        </div>
    );
}

export default function ConnexionPage() {
    return (
        <Suspense>
            <ConnexionForm />
        </Suspense>
    );
}