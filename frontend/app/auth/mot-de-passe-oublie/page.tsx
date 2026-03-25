"use client";

import { useState } from "react";
import Image from "next/image";
import { motDePasseOublie } from "@/src/services/auth.service";

type Etape = "formulaire" | "succes";

export default function MotDePasseOubliePage() {
    const [email, setEmail] = useState("");
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [etape, setEtape] = useState<Etape>("formulaire");

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);
        setError(null);

        try {
            await motDePasseOublie(email);
            setEtape("succes");
        } catch (err: any) {
            setError(err.response?.data?.error || "Une erreur est survenue.");
        } finally {
            setLoading(false);
        }
    };

    return (
        <div data-theme="winter" className="min-h-screen bg-base-200 flex items-center justify-center px-4 py-12">
            <div className="w-full max-w-md">

                {/* En-tête */}
                <div className="text-center mb-8">
                    <div className="avatar placeholder mb-4">
                        <Image src="/logo/logo1.png" alt="logo koivoit" width={100} height={100} />
                    </div>
                    <h1 className="text-3xl font-bold text-base-content">
                        {etape === "formulaire" ? "Mot de passe oublié" : "Email envoyé !"}
                    </h1>
                    <p className="text-base-content/60 mt-1">
                        {etape === "formulaire"
                            ? "Entrez votre email pour recevoir un lien de réinitialisation"
                            : "Vérifiez votre boîte mail"
                        }
                    </p>
                </div>

                <div className="card bg-base-100 shadow-xl">
                    <div className="card-body gap-4">

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
                                        />
                                        <label className="label">
                                            <span className="label-text-alt text-base-content/50">
                                                Un lien valable 24h vous sera envoyé
                                            </span>
                                        </label>
                                    </div>

                                    <button
                                        type="submit"
                                        disabled={loading}
                                        className="btn btn-primary w-full"
                                    >
                                        {loading
                                            ? <span className="loading loading-spinner loading-sm" />
                                            : "Envoyer le lien"
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
                                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                                        </svg>
                                    </div>
                                </div>

                                <div>
                                    <p className="font-semibold text-lg text-base-content">Email envoyé avec succès</p>
                                    <p className="text-base-content/60 text-sm mt-2">
                                        Nous avons envoyé un lien de réinitialisation à
                                    </p>
                                    <p className="font-semibold text-primary mt-1">{email}</p>
                                </div>

                                <div className="alert">
                                    <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 shrink-0 text-info" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                                    </svg>
                                    <span className="text-sm">
                                        Le lien expire dans <strong>24 heures</strong>. Vérifiez aussi vos spams.
                                    </span>
                                </div>

                                <button
                                    type="button"
                                    onClick={() => { setEtape("formulaire"); setEmail(""); }}
                                    className="btn btn-outline btn-sm"
                                >
                                    Utiliser un autre email
                                </button>
                            </div>
                        )}

                        {/* Lien retour */}
                        <div className="divider text-sm">ou</div>
                        <p className="text-center text-sm text-base-content/60">
                            <a href="/auth/connexion" className="link link-primary font-medium">
                                ← Retour à la connexion
                            </a>
                        </p>

                    </div>
                </div>
            </div>
        </div>
    );
}