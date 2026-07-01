"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import logoSrc from "@/public/logo/logo1.png";
import { inscription, googleAuth } from "@/src/services/auth.service";
import { useAuth } from "@/src/hooks/useAuth";
import { PLACES_MAX_PAR_TYPE } from "@/src/services/trajet.service";
import { GoogleLogin } from "@react-oauth/google";

type Role = "passager" | "conducteur";

const TYPES_VEHICULE = [
    { value: "moto", label: "Moto", places: 1, tarif: "30 FCFA/km" },
    { value: "voiture", label: "Voiture", places: 5, tarif: "65 FCFA/km" },
    { value: "minibus", label: "Minibus", places: 15, tarif: "120 FCFA/km" },
    { value: "camion", label: "Camion", places: 3, tarif: "200 FCFA/km" },
];

interface InscriptionForm {
    // Compte
    username: string;
    first_name: string;
    last_name: string;
    email: string;
    password: string;
    password2: string;
    role: Role;
    numero_telephone: string;
    photo_profil: File | null;
    // Conducteur
    numero_permis: string;
    experience_annees: string;
    // Véhicule
    type_vehicule: string;
    marque: string;
    modele: string;
    couleur: string;
    plaque: string;
}

export default function InscriptionPage() {
    const router = useRouter();
    const { login } = useAuth();

    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [step, setStep] = useState<1 | 2>(1);

    const handleGoogleSuccess = async (idToken: string) => {
        setLoading(true);
        setError(null);
        try {
            const data = await googleAuth(idToken);
            await login(data);
            router.push("/passager/dashboard");
        } catch (err: any) {
            setError(err.response?.data?.error || "Inscription Google échouée. Réessayez.");
        } finally {
            setLoading(false);
        }
    };

    const [form, setForm] = useState<InscriptionForm>({
        username: "",
        first_name: "",
        last_name: "",
        email: "",
        password: "",
        password2: "",
        role: "passager",
        numero_telephone: "",
        photo_profil: null,
        numero_permis: "",
        experience_annees: "",
        type_vehicule: "",
        marque: "",
        modele: "",
        couleur: "",
        plaque: "",
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
            payload.append("first_name", form.first_name);
            payload.append("last_name", form.last_name);
            payload.append("email", form.email);
            payload.append("password", form.password);
            payload.append("password2", form.password2);
            payload.append("role", form.role);
            if (form.numero_telephone) payload.append("numero_telephone", form.numero_telephone);
            if (form.photo_profil) payload.append("photo_profil", form.photo_profil);

            if (form.role === "conducteur") {
                payload.append("numero_permis", form.numero_permis);
                payload.append("experience_annees", form.experience_annees || "0");
                payload.append("type_vehicule", form.type_vehicule);
                payload.append("marque", form.marque);
                payload.append("modele", form.modele);
                payload.append("couleur", form.couleur);
                payload.append("plaque", form.plaque);
            }

            const response = await inscription(payload);
            await login(response);

            if (form.role === "conducteur") router.push("/conducteur/dashboard");
            else router.push("/passager/dashboard");

        } catch (err: any) {
            const data = err.response?.data;

            if (data && typeof data === "object") {
                // Messages d'erreur lisibles par l'utilisateur
                const LABELS: Record<string, string> = {
                    username:      "Nom d'utilisateur",
                    email:         "Email",
                    password:      "Mot de passe",
                    numero_permis: "Numéro de permis",
                    plaque:        "Plaque",
                    type_vehicule: "Type de véhicule",
                    non_field_errors: "",
                };

                const messages = Object.entries(data)
                    .filter(([k]) => !["code", "messages"].includes(k))
                    .map(([k, v]) => {
                        const label = LABELS[k] ?? k;
                        const texte = Array.isArray(v) ? v.join(", ") : String(v);
                        return label ? `${label} : ${texte}` : texte;
                    });

                setError(messages.join(" — ") || "Erreur lors de l'inscription.");
            } else {
                setError(err.message === "Erreur API"
                    ? "Erreur serveur. Réessayez."
                    : "Impossible de contacter le serveur. Vérifiez que le backend est démarré.");
            }
        } finally {
            setLoading(false);
        }
    };

    const typeSelectionne = TYPES_VEHICULE.find((t) => t.value === form.type_vehicule);

    return (
        <div data-theme="winter" className="min-h-screen bg-base-200 flex items-center justify-center px-4 py-12">
            <div className="w-full max-w-lg">

                {/* En-tête */}
                <div className="text-center mb-8">
                    <div className="flex justify-center mb-4">
                        <img src={logoSrc.src} alt="logo kovoit" width={100} height={100} className="object-contain" />
                    </div>
                    <h1 className="text-3xl font-bold text-base-content">Créer un compte</h1>
                    <p className="text-base-content/60 mt-1">Rejoignez KoVoit au Togo</p>
                </div>

                {/* Indicateur d'étape */}
                <ul className="steps steps-horizontal w-full mb-8">
                    <li className={`step ${step >= 1 ? "step-primary" : ""}`}>Informations</li>
                    <li className={`step ${step >= 2 ? "step-primary" : ""}`}>Profil</li>
                </ul>

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

                        {/* Google Sign-In — visible uniquement à l'étape 1 */}
                        {step === 1 && process.env.NEXT_PUBLIC_GOOGLE_CLIENT_ID && (
                            <div className="flex flex-col items-center gap-2">
                                <div className="flex justify-center w-full">
                                    <GoogleLogin
                                        onSuccess={(cr) => handleGoogleSuccess(cr.credential!)}
                                        onError={() => setError("Inscription Google échouée.")}
                                        text="signup_with"
                                        shape="rectangular"
                                        locale="fr"
                                        width={400}
                                    />
                                </div>
                                <p className="text-xs text-base-content/40">
                                    Crée un compte passager en un clic
                                </p>
                                <div className="divider text-xs w-full">ou remplis le formulaire</div>
                            </div>
                        )}

                        {/* ── ÉTAPE 1 — Informations de base ── */}
                        {step === 1 && (
                            <form onSubmit={handleNextStep} className="flex flex-col gap-4">

                                {/* Rôle */}
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
                                                className={`btn rounded-xl ${form.role === r ? "btn-primary" : "btn-outline"}`}
                                            >
                                                {r === "passager" ? "Passager" : "Conducteur"}
                                            </button>
                                        ))}
                                    </div>
                                </div>

                                {/* Prénom + Nom */}
                                <div className="grid grid-cols-2 gap-3">
                                    <div className="form-control">
                                        <label className="label">
                                            <span className="label-text font-semibold">Prénom</span>
                                        </label>
                                        <input
                                            type="text"
                                            placeholder="Jean"
                                            className="input input-bordered w-full"
                                            value={form.first_name}
                                            onChange={(e) => set("first_name", e.target.value)}
                                            required
                                        />
                                    </div>
                                    <div className="form-control">
                                        <label className="label">
                                            <span className="label-text font-semibold">Nom</span>
                                        </label>
                                        <input
                                            type="text"
                                            placeholder="Dupont"
                                            className="input input-bordered w-full"
                                            value={form.last_name}
                                            onChange={(e) => set("last_name", e.target.value)}
                                            required
                                        />
                                    </div>
                                </div>

                                {/* Username */}
                                <div className="form-control">
                                    <label className="label">
                                        <span className="label-text font-semibold">Nom d&apos;utilisateur</span>
                                    </label>
                                    <input
                                        type="text"
                                        placeholder="jean_dupont"
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
                                            <span className="label-text-alt ml-1 text-base-content/40">(optionnel)</span>
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
                                                ? "input-error" : ""
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
                                            <span className="label-text-alt ml-1 text-base-content/40">(optionnel)</span>
                                        </span>
                                    </label>
                                    <input
                                        type="file"
                                        accept="image/*"
                                        className="file-input file-input-bordered w-full"
                                        onChange={(e) => set("photo_profil", e.target.files?.[0] || null)}
                                    />
                                </div>

                                <button type="submit" className="btn btn-primary w-full mt-2 rounded-full">
                                    Continuer →
                                </button>
                            </form>
                        )}

                        {/* ── ÉTAPE 2 — Profil ── */}
                        {step === 2 && (
                            <form onSubmit={handleSubmit} className="flex flex-col gap-4">

                                {/* PASSAGER */}
                                {form.role === "passager" && (
                                    <div className="space-y-4">
                                        <div className="bg-base-200 rounded-2xl p-5 text-center">
                                            <p className="font-semibold text-base-content mb-1">Profil Passager</p>
                                            <p className="text-base-content/50 text-sm">
                                                Votre compte est prêt. Vous pourrez rechercher et réserver des trajets immédiatement.
                                            </p>
                                        </div>

                                        {/* Récapitulatif */}
                                        <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                                            <div className="px-5 py-3 border-b border-base-200">
                                                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                                                    Récapitulatif
                                                </p>
                                            </div>
                                            <div className="divide-y divide-base-200">
                                                {[
                                                    { label: "Prénom", value: form.first_name },
                                                    { label: "Nom", value: form.last_name },
                                                    { label: "Email", value: form.email },
                                                    { label: "Rôle", value: "Passager" },
                                                ].map((item) => (
                                                    <div key={item.label} className="flex justify-between px-5 py-2.5">
                                                        <span className="text-xs text-base-content/40 uppercase tracking-wide">{item.label}</span>
                                                        <span className="text-sm font-medium text-base-content">{item.value}</span>
                                                    </div>
                                                ))}
                                            </div>
                                        </div>
                                    </div>
                                )}

                                {/* CONDUCTEUR */}
                                {form.role === "conducteur" && (
                                    <div className="space-y-4">

                                        {/* Permis + expérience */}
                                        <div className="bg-base-100 rounded-2xl border border-base-200 p-5 space-y-4">
                                            <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                                                Informations conducteur
                                            </p>
                                            <div className="grid grid-cols-2 gap-3">
                                                <div className="form-control">
                                                    <label className="label py-1">
                                                        <span className="label-text font-semibold text-sm">Numéro de permis</span>
                                                    </label>
                                                    <input
                                                        type="text"
                                                        placeholder="TG-123456"
                                                        className="input input-bordered input-sm w-full rounded-xl"
                                                        value={form.numero_permis}
                                                        onChange={(e) => set("numero_permis", e.target.value)}
                                                        required
                                                    />
                                                </div>
                                                <div className="form-control">
                                                    <label className="label py-1">
                                                        <span className="label-text font-semibold text-sm">Expérience (ans)</span>
                                                    </label>
                                                    <input
                                                        type="number"
                                                        placeholder="0"
                                                        min="0"
                                                        max="50"
                                                        className="input input-bordered input-sm w-full rounded-xl"
                                                        value={form.experience_annees}
                                                        onChange={(e) => set("experience_annees", e.target.value)}
                                                    />
                                                </div>
                                            </div>
                                        </div>

                                        {/* Véhicule */}
                                        <div className="bg-base-100 rounded-2xl border border-base-200 p-5 space-y-4">
                                            <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                                                Votre véhicule principal
                                            </p>

                                            {/* Type de véhicule */}
                                            <div className="form-control">
                                                <label className="label py-1">
                                                    <span className="label-text font-semibold text-sm">Type de véhicule</span>
                                                </label>
                                                <div className="grid grid-cols-2 gap-2">
                                                    {TYPES_VEHICULE.map((t) => (
                                                        <button
                                                            key={t.value}
                                                            type="button"
                                                            onClick={() => set("type_vehicule", t.value)}
                                                            className={`btn btn-sm rounded-xl flex flex-col h-auto py-2 gap-0 ${form.type_vehicule === t.value
                                                                ? "btn-primary"
                                                                : "btn-outline"
                                                                }`}
                                                        >
                                                            <span className="font-semibold">{t.label}</span>
                                                            <span className="text-xs opacity-70 font-normal">
                                                                {t.places} place{t.places > 1 ? "s" : ""} · {t.tarif}
                                                            </span>
                                                        </button>
                                                    ))}
                                                </div>
                                                {typeSelectionne && (
                                                    <p className="text-xs text-base-content/40 mt-2">
                                                        Tarif carburant : {typeSelectionne.tarif} — maximum {typeSelectionne.places} place{typeSelectionne.places > 1 ? "s" : ""}
                                                    </p>
                                                )}
                                            </div>

                                            {/* Marque + Modèle */}
                                            <div className="grid grid-cols-2 gap-3">
                                                <div className="form-control">
                                                    <label className="label py-1">
                                                        <span className="label-text font-semibold text-sm">Marque</span>
                                                    </label>
                                                    <input
                                                        type="text"
                                                        placeholder="Toyota, Honda..."
                                                        className="input input-bordered input-sm w-full rounded-xl"
                                                        value={form.marque}
                                                        onChange={(e) => set("marque", e.target.value)}
                                                        required
                                                    />
                                                </div>
                                                <div className="form-control">
                                                    <label className="label py-1">
                                                        <span className="label-text font-semibold text-sm">Modèle</span>
                                                    </label>
                                                    <input
                                                        type="text"
                                                        placeholder="Corolla, CB125..."
                                                        className="input input-bordered input-sm w-full rounded-xl"
                                                        value={form.modele}
                                                        onChange={(e) => set("modele", e.target.value)}
                                                        required
                                                    />
                                                </div>
                                            </div>

                                            {/* Couleur + Plaque */}
                                            <div className="grid grid-cols-2 gap-3">
                                                <div className="form-control">
                                                    <label className="label py-1">
                                                        <span className="label-text font-semibold text-sm">Couleur</span>
                                                    </label>
                                                    <input
                                                        type="text"
                                                        placeholder="Blanc, Rouge..."
                                                        className="input input-bordered input-sm w-full rounded-xl"
                                                        value={form.couleur}
                                                        onChange={(e) => set("couleur", e.target.value)}
                                                        required
                                                    />
                                                </div>
                                                <div className="form-control">
                                                    <label className="label py-1">
                                                        <span className="label-text font-semibold text-sm">Plaque</span>
                                                    </label>
                                                    <input
                                                        type="text"
                                                        placeholder="TG 1234 LM"
                                                        className="input input-bordered input-sm w-full rounded-xl"
                                                        value={form.plaque}
                                                        onChange={(e) => set("plaque", e.target.value)}
                                                        required
                                                    />
                                                </div>
                                            </div>
                                        </div>

                                        {/* Info tarif */}
                                        {typeSelectionne && (
                                            <div className="bg-primary/5 border border-primary/10 rounded-2xl px-5 py-3">
                                                <p className="text-xs text-base-content/50 uppercase tracking-widest font-medium mb-2">
                                                    Tarification automatique
                                                </p>
                                                <p className="text-sm text-base-content/70">
                                                    Pour une <span className="font-semibold">{typeSelectionne.label}</span>, le prix par place sera calculé automatiquement :
                                                </p>
                                                <p className="text-xs text-base-content/40 mt-1">
                                                    distance × {typeSelectionne.tarif} ÷ places + 10% commission KoVoit
                                                </p>
                                            </div>
                                        )}
                                    </div>
                                )}

                                {/* Boutons */}
                                <div className="flex gap-3 mt-2">
                                    <button
                                        type="button"
                                        onClick={() => setStep(1)}
                                        className="btn btn-outline rounded-full flex-1"
                                    >
                                        Retour
                                    </button>
                                    <button
                                        type="submit"
                                        disabled={loading || (form.role === "conducteur" && !form.type_vehicule)}
                                        className="btn btn-primary rounded-full flex-1"
                                    >
                                        {loading
                                            ? <span className="loading loading-spinner loading-sm" />
                                            : "Créer mon compte"
                                        }
                                    </button>
                                </div>
                            </form>
                        )}

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