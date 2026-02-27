"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Image from "next/image";

import { inscription } from "@/src/services/auth.service";
import { useAuth } from "@/src/hooks/useAuth";

type Role = "passager" | "conducteur";

interface InscriptionForm {
    username: string;
    email: string;
    password: string;
    password2: string;
    role: Role;
    numero_telephone: string;
    photo_profil: File | null;
    numero_permis: string;
    vehicule: string;
    couleur_vehicule: string;
    type_vehicule: string;
    plaque: string;
    experience_annees: string;
}

export default function InscriptionPage() {
    const router = useRouter();
    const { login } = useAuth();
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [step, setStep] = useState<1 | 2>(1);

    const [form, setForm] = useState<InscriptionForm>({
        username: "",
        email: "",
        password: "",
        password2: "",
        role: "passager",
        numero_telephone: "",
        photo_profil: null,
        numero_permis: "",
        vehicule: "",
        couleur_vehicule: "",
        type_vehicule: "",
        plaque: "",
        experience_annees: "",
    });

    const set = (field: keyof InscriptionForm, value: any) =>
        setForm((prev) => ({ ...prev, [field]: value }));

    const handleNextStep = (e: React.FormEvent) => {
        e.preventDefault();
        if (form.password !== form.password2) {
            setError("Les mots de passe ne correspondent pas.");
            return;
        }
        setError(null);
        setStep(2);
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);
        setError(null);

        try {
            const payload = new FormData();
            payload.append("username", form.username);
            payload.append("email", form.email);
            payload.append("password", form.password);
            payload.append("password2", form.password2);
            payload.append("role", form.role);
            if (form.numero_telephone) payload.append("numero_telephone", form.numero_telephone);
            if (form.photo_profil) payload.append("photo_profil", form.photo_profil);

            if (form.role === "conducteur") {
                payload.append("numero_permis", form.numero_permis);
                payload.append("vehicule", form.vehicule);
                payload.append("couleur_vehicule", form.couleur_vehicule);
                payload.append("type_vehicule", form.type_vehicule);
                payload.append("plaque", form.plaque);
                payload.append("experience_annees", form.experience_annees);
            }

            const response = await inscription(payload);
            login(response);

            if (form.role === "conducteur") router.push("/conducteur/dashboard");
            else router.push("/passager/dashboard");

        } catch (err: any) {
            const errors = err.response?.data;
            if (errors && typeof errors === "object") {
                setError(Object.entries(errors).map(([k, v]) => `${k} : ${v}`).join(" | "));
            } else {
                setError("Erreur lors de l'inscription.");
            }
        } finally {
            setLoading(false);
        }
    };

    return (
        <div data-theme="winter" className="min-h-screen bg-base-200 flex items-center justify-center px-4 py-12">
            <div className="w-full max-w-lg">

                {/* En-tête */}
                <div className="text-center mb-8">
                    <div className="avatar placeholder mb-4">
                        <Image src="/logo/logo1.png" alt='logo koivoit' width={100} height={100} />
                    </div>
                    <h1 className="text-3xl font-bold text-base-content">Créer un compte</h1>
                    <p className="text-base-content/60 mt-1">Rejoignez notre communauté de covoiturage</p>
                </div>

                {/* Indicateur d'étape */}
                <ul className="steps steps-horizontal w-full mb-8">
                    <li className={`step ${step >= 1 ? "step-primary" : ""}`}>Informations</li>
                    <li className={`step ${step >= 2 ? "step-primary" : ""}`}>Profil</li>
                </ul>

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

                        {/* ── ÉTAPE 1 ── */}
                        {step === 1 && (
                            <form onSubmit={handleNextStep} className="flex flex-col gap-4">

                                {/* Choix du rôle */}
                                <div className="form-control">
                                    <label className="label">
                                        <span className="label-text font-semibold">Je suis</span>
                                    </label>
                                    <div className="grid grid-cols-2 gap-3">
                                        {(["passager", "conducteur"] as Role[]).map((r) => (
                                            <button
                                                key={r}
                                                type="button"
                                                onClick={() => set("role", r)}
                                                className={`btn ${form.role === r ? "btn-primary" : "btn-outline"}`}
                                            >
                                                {r === "passager" ? " Passager" : " Conducteur"}
                                            </button>
                                        ))}
                                    </div>
                                </div>

                                {/* Username */}
                                <div className="form-control">
                                    <label className="label">
                                        <span className="label-text font-semibold">Nom d'utilisateur</span>
                                    </label>
                                    <input
                                        type="text"
                                        placeholder="ex: jean_dupont"
                                        className="input input-bordered w-full"
                                        value={form.username}
                                        onChange={(e) => set("username", e.target.value)}
                                        required
                                    />
                                </div>

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
                                    />
                                </div>

                                {/* Téléphone */}
                                <div className="form-control">
                                    <label className="label">
                                        <span className="label-text font-semibold">
                                            Téléphone
                                            <span className="label-text-alt ml-1">(optionnel)</span>
                                        </span>
                                    </label>
                                    <input
                                        type="tel"
                                        placeholder="+228 90 00 00 00"
                                        className="input input-bordered w-full"
                                        value={form.numero_telephone}
                                        onChange={(e) => set("numero_telephone", e.target.value)}
                                    />
                                </div>

                                {/* Mots de passe */}
                                <div className="grid grid-cols-2 gap-3">
                                    <div className="form-control">
                                        <label className="label">
                                            <span className="label-text font-semibold">Mot de passe</span>
                                        </label>
                                        <input
                                            type="password"
                                            placeholder="••••••••"
                                            className="input input-bordered w-full"
                                            value={form.password}
                                            onChange={(e) => set("password", e.target.value)}
                                            required
                                            minLength={8}
                                        />
                                    </div>
                                    <div className="form-control">
                                        <label className="label">
                                            <span className="label-text font-semibold">Confirmer</span>
                                        </label>
                                        <input
                                            type="password"
                                            placeholder="••••••••"
                                            className={`input input-bordered w-full ${form.password2 && form.password !== form.password2
                                                ? "input-error"
                                                : ""
                                                }`}
                                            value={form.password2}
                                            onChange={(e) => set("password2", e.target.value)}
                                            required
                                        />
                                    </div>
                                </div>

                                {/* Photo */}
                                <div className="form-control">
                                    <label className="label">
                                        <span className="label-text font-semibold">
                                            Photo de profil
                                            <span className="label-text-alt ml-1">(optionnel)</span>
                                        </span>
                                    </label>
                                    <input
                                        type="file"
                                        accept="image/*"
                                        className="file-input file-input-bordered w-full"
                                        onChange={(e) => set("photo_profil", e.target.files?.[0] || null)}
                                    />
                                </div>

                                <button type="submit" className="btn btn-primary w-full mt-2">
                                    Continuer →
                                </button>
                            </form>
                        )}

                        {/* ── ÉTAPE 2 ── */}
                        {step === 2 && (
                            <form onSubmit={handleSubmit} className="flex flex-col gap-4">

                                {/* Passager */}
                                {form.role === "passager" && (
                                    <div className="text-center py-4">
                                        <div className="text-5xl mb-4">🧍</div>
                                        <p className="font-semibold text-lg">Profil Passager</p>
                                        <p className="text-base-content/60 text-sm mt-2">
                                            Votre compte passager ne nécessite aucune information supplémentaire.
                                            Vous pourrez rechercher et réserver des trajets immédiatement.
                                        </p>

                                        <div className="divider" />

                                        <div className="bg-base-200 rounded-2xl p-4 text-left space-y-2">
                                            <p className="text-xs font-bold uppercase tracking-widest text-base-content/40 mb-3">Récapitulatif</p>
                                            <div className="flex justify-between text-sm">
                                                <span className="text-base-content/60">Nom</span>
                                                <span className="font-medium">{form.username}</span>
                                            </div>
                                            <div className="flex justify-between text-sm">
                                                <span className="text-base-content/60">Email</span>
                                                <span className="font-medium">{form.email}</span>
                                            </div>
                                            {form.numero_telephone && (
                                                <div className="flex justify-between text-sm">
                                                    <span className="text-base-content/60">Téléphone</span>
                                                    <span className="font-medium">{form.numero_telephone}</span>
                                                </div>
                                            )}
                                            <div className="flex justify-between text-sm">
                                                <span className="text-base-content/60">Rôle</span>
                                                <div className="badge badge-info badge-sm">Passager</div>
                                            </div>
                                        </div>
                                    </div>
                                )}

                                {/* Conducteur */}
                                {form.role === "conducteur" && (
                                    <>
                                        <div className="divider divider-start text-sm font-bold">
                                            🚗 Informations véhicule
                                        </div>

                                        <div className="form-control">
                                            <label className="label">
                                                <span className="label-text font-semibold">Numéro de permis</span>
                                            </label>
                                            <input
                                                type="text"
                                                placeholder="ex: TG-123456"
                                                className="input input-bordered w-full"
                                                value={form.numero_permis}
                                                onChange={(e) => set("numero_permis", e.target.value)}
                                                required
                                            />
                                        </div>

                                        <div className="grid grid-cols-2 gap-3">
                                            <div className="form-control">
                                                <label className="label">
                                                    <span className="label-text font-semibold">Marque / Modèle</span>
                                                </label>
                                                <input
                                                    type="text"
                                                    placeholder="Toyota Corolla"
                                                    className="input input-bordered w-full"
                                                    value={form.vehicule}
                                                    onChange={(e) => set("vehicule", e.target.value)}
                                                    required
                                                />
                                            </div>
                                            <div className="form-control">
                                                <label className="label">
                                                    <span className="label-text font-semibold">Couleur</span>
                                                </label>
                                                <input
                                                    type="text"
                                                    placeholder="Blanc"
                                                    className="input input-bordered w-full"
                                                    value={form.couleur_vehicule}
                                                    onChange={(e) => set("couleur_vehicule", e.target.value)}
                                                    required
                                                />
                                            </div>
                                        </div>

                                        <div className="form-control">
                                            <label className="label">
                                                <span className="label-text font-semibold">Type de véhicule</span>
                                            </label>
                                            <select
                                                className="select select-bordered w-full"
                                                value={form.type_vehicule}
                                                onChange={(e) => set("type_vehicule", e.target.value)}
                                                required
                                            >
                                                <option value="">-- Sélectionner --</option>
                                                <option value="berline">Berline</option>
                                                <option value="suv">SUV</option>
                                                <option value="minivan">Minivan</option>
                                                <option value="pickup">Pick-up</option>
                                                <option value="moto">Moto</option>
                                                <option value="autre">Autre</option>
                                            </select>
                                        </div>

                                        <div className="grid grid-cols-2 gap-3">
                                            <div className="form-control">
                                                <label className="label">
                                                    <span className="label-text font-semibold">Plaque</span>
                                                </label>
                                                <input
                                                    type="text"
                                                    placeholder="TG 1234 LM"
                                                    className="input input-bordered w-full"
                                                    value={form.plaque}
                                                    onChange={(e) => set("plaque", e.target.value)}
                                                    required
                                                />
                                            </div>
                                            <div className="form-control">
                                                <label className="label">
                                                    <span className="label-text font-semibold">Expérience (ans)</span>
                                                </label>
                                                <input
                                                    type="number"
                                                    placeholder="0"
                                                    min="0"
                                                    max="50"
                                                    className="input input-bordered w-full"
                                                    value={form.experience_annees}
                                                    onChange={(e) => set("experience_annees", e.target.value)}
                                                    required
                                                />
                                            </div>
                                        </div>
                                    </>
                                )}

                                {/* Boutons */}
                                <div className="flex gap-3 mt-2">
                                    <button
                                        type="button"
                                        onClick={() => setStep(1)}
                                        className="btn btn-outline flex-1"
                                    >
                                        ← Retour
                                    </button>
                                    <button
                                        type="submit"
                                        disabled={loading}
                                        className="btn btn-primary flex-1"
                                    >
                                        {loading
                                            ? <span className="loading loading-spinner loading-sm" />
                                            : "Créer mon compte ✓"
                                        }
                                    </button>
                                </div>
                            </form>
                        )}

                        {/* Lien connexion */}
                        <div className="divider text-sm">ou</div>
                        <p className="text-center text-sm text-base-content/60">
                            Déjà un compte ?{" "}
                            <a href="/auth/connexion" className="link link-primary font-medium">
                                Se connecter
                            </a>
                        </p>

                    </div>
                </div>
            </div>
        </div>
    );
}