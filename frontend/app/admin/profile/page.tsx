"use client";

import { useEffect, useMemo, useState } from "react";
import { useAuth } from "@/src/hooks/useAuth";
import { api } from "@/src/services/api";
import { getMediaUrl } from "@/src/utils/imageUtils";

interface ProfileForm {
    first_name: string;
    last_name: string;
    numero_telephone: string;
}

interface PasswordForm {
    current_password: string;
    new_password: string;
    new_password2: string;
}

export default function AdminProfilePage() {
    const { user, loading: authLoading } = useAuth();
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [success, setSuccess] = useState<string | null>(null);
    const [profile, setProfile] = useState<ProfileForm>({
        first_name: "",
        last_name: "",
        numero_telephone: "",
    });
    const [passwordForm, setPasswordForm] = useState<PasswordForm>({
        current_password: "",
        new_password: "",
        new_password2: "",
    });
    const [photoFile, setPhotoFile] = useState<File | null>(null);
    const [photoPreview, setPhotoPreview] = useState<string>("");

    useEffect(() => {
        if (!user) return;

        setProfile({
            first_name: user.first_name || "",
            last_name: user.last_name || "",
            numero_telephone: user.numero_telephone || "",
        });

        setPhotoPreview(user.photo_profil ? getMediaUrl(user.photo_profil) : "");
    }, [user]);

    useEffect(() => {
        if (!photoFile) return;

        const objectUrl = URL.createObjectURL(photoFile);
        setPhotoPreview(objectUrl);

        return () => URL.revokeObjectURL(objectUrl);
    }, [photoFile]);

    const fullName = useMemo(
        () => `${user?.first_name || ""} ${user?.last_name || ""}`.trim(),
        [user],
    );

    const accountStatus = useMemo(() => {
        if (user?.is_active === false) return "Désactivé";
        return "Actif";
    }, [user]);

    const niveauAcces = useMemo(() => {
        if (user?.role === "admin") return "Accès administrateur";
        return user?.role ? `Accès ${user.role}` : "—";
    }, [user]);

    const handleFieldChange = (field: keyof ProfileForm, value: string) => {
        setProfile((prev) => ({ ...prev, [field]: value }));
    };

    const handlePasswordField = (field: keyof PasswordForm, value: string) => {
        setPasswordForm((prev) => ({ ...prev, [field]: value }));
    };

    const handlePhotoChange = (event: React.ChangeEvent<HTMLInputElement>) => {
        const file = event.target.files?.[0] || null;
        setPhotoFile(file);
    };

    const getErrorMessage = (err: unknown) => {
        if (!err) return "Erreur inconnue.";
        if (err instanceof Error) return err.message;
        if (typeof err === "string") return err;
        if (typeof err === "object" && err !== null) {
            if ("response" in err && typeof err.response === "object") {
                const response = (err as any).response;
                if (response.data) {
                    return typeof response.data === "string"
                        ? response.data
                        : JSON.stringify(response.data);
                }
            }
            return JSON.stringify(err);
        }
        return String(err);
    };

    const handleSaveProfile = async (event: React.FormEvent<HTMLFormElement>) => {
        event.preventDefault();
        setLoading(true);
        setError(null);
        setSuccess(null);

        try {
            const payload = new FormData();
            payload.append("first_name", profile.first_name);
            payload.append("last_name", profile.last_name);
            payload.append("numero_telephone", profile.numero_telephone);
            if (photoFile) payload.append("photo_profil", photoFile);

            await api("/utilisateurs/ko/profil/update/", "PUT", payload);
            setSuccess("Profil administrateur mis à jour avec succès.");
        } catch (err: unknown) {
            setError(getErrorMessage(err));
        } finally {
            setLoading(false);
        }
    };

    const handleChangePassword = async (event: React.FormEvent<HTMLFormElement>) => {
        event.preventDefault();
        setLoading(true);
        setError(null);
        setSuccess(null);

        if (passwordForm.new_password !== passwordForm.new_password2) {
            setError("Les nouveaux mots de passe ne correspondent pas.");
            setLoading(false);
            return;
        }

        if (passwordForm.new_password.length < 8) {
            setError("Le nouveau mot de passe doit contenir au moins 8 caractères.");
            setLoading(false);
            return;
        }

        try {
            await api("/utilisateurs/ko/profil/change-password/", "POST", {
                current_password: passwordForm.current_password,
                new_password: passwordForm.new_password,
                new_password2: passwordForm.new_password2,
            });
            setSuccess("Mot de passe modifié avec succès.");
            setPasswordForm({ current_password: "", new_password: "", new_password2: "" });
        } catch (err: unknown) {
            setError(getErrorMessage(err));
        } finally {
            setLoading(false);
        }
    };

    if (authLoading || !user) {
        return <div className="text-center py-12">Chargement du profil administrateur…</div>;
    }

    return (
        <div className="space-y-8">
            <div className="pb-6 border-b border-base-300">
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">
                    Administration
                </p>
                <h1 className="text-3xl font-bold text-base-content tracking-tight">
                    Profil administrateur
                </h1>
                <p className="mt-2 text-sm text-base-content/60 max-w-2xl">
                    Consultez et mettez à jour votre profil administrateur. Toutes les données essentielles sont regroupées dans un tableau de bord clair et professionnel.
                </p>
            </div>

            {error && (
                <div className="rounded-2xl border border-error/20 bg-error/10 p-4 text-sm text-error">
                    {error}
                </div>
            )}
            {success && (
                <div className="rounded-2xl border border-success/20 bg-success/10 p-4 text-sm text-success">
                    {success}
                </div>
            )}

            <div className="grid gap-6 xl:grid-cols-[1.05fr_0.95fr]">
                <div className="space-y-6">
                    <section className="bg-base-100 rounded-3xl border border-base-200 p-6 shadow-sm">
                        <div className="flex flex-col gap-6 lg:flex-row lg:items-center lg:justify-between">
                            <div className="flex items-center gap-4">
                                <div className="relative h-20 w-20 rounded-3xl overflow-hidden bg-primary/10 flex items-center justify-center">
                                    {photoPreview ? (
                                        <img src={photoPreview} alt="Photo de profil" className="h-full w-full object-cover" />
                                    ) : (
                                        <span className="text-3xl font-semibold text-primary">
                                            {user?.first_name?.[0]?.toUpperCase() || user?.username?.[0]?.toUpperCase()}
                                        </span>
                                    )}
                                </div>
                                <div>
                                    <p className="text-xl font-semibold text-base-content">{fullName || user.username}</p>
                                    <p className="text-sm text-base-content/50">{user.email}</p>
                                    <div className="mt-3 flex flex-wrap gap-2">
                                        <span className="badge badge-outline badge-primary">Admin</span>
                                        <span className="badge badge-outline badge-accent">{niveauAcces}</span>
                                        <span className="badge badge-outline badge-info">{accountStatus}</span>
                                    </div>
                                </div>
                            </div>
                            <div className="grid gap-3 sm:grid-cols-2">
                                <div className="rounded-2xl border border-base-200 bg-base-200 p-4">
                                    <p className="text-xs uppercase tracking-widest text-base-content/40">Date de création</p>
                                    <p className="mt-2 text-base font-semibold text-base-content">
                                        {user.date_joined ? new Date(user.date_joined).toLocaleDateString("fr-FR", { year: "numeric", month: "long", day: "numeric" }) : "—"}
                                    </p>
                                </div>
                                <div className="rounded-2xl border border-base-200 bg-base-200 p-4">
                                    <p className="text-xs uppercase tracking-widest text-base-content/40">Dernière connexion</p>
                                    <p className="mt-2 text-base font-semibold text-base-content">
                                        {user.last_login ? new Date(user.last_login).toLocaleString("fr-FR") : "Jamais"}
                                    </p>
                                </div>
                            </div>
                        </div>
                    </section>

                    <section className="grid gap-6 xl:grid-cols-2">
                        <div className="rounded-3xl border border-base-200 bg-base-100 p-6">
                            <h2 className="text-sm uppercase tracking-widest text-base-content/40 font-medium mb-4">
                                Informations personnelles
                            </h2>
                            <div className="grid gap-4">
                                {[
                                    { label: "Nom complet", value: fullName || "—" },
                                    { label: "Sexe", value: "Non renseigné" },
                                    { label: "Date de naissance", value: "Non renseigné" },
                                    { label: "Nationalité", value: "Non renseigné" },
                                    { label: "Adresse", value: "Non renseigné" },
                                    { label: "Ville", value: "Non renseigné" },
                                    { label: "Pays", value: "Non renseigné" },
                                ].map((item) => (
                                    <div key={item.label} className="flex items-center justify-between gap-4 rounded-2xl bg-base-200 px-4 py-3">
                                        <span className="text-sm text-base-content/60">{item.label}</span>
                                        <span className="text-sm font-medium text-base-content">{item.value}</span>
                                    </div>
                                ))}
                            </div>
                        </div>

                        <div className="rounded-3xl border border-base-200 bg-base-100 p-6">
                            <h2 className="text-sm uppercase tracking-widest text-base-content/40 font-medium mb-4">
                                Informations administratives
                            </h2>
                            <div className="grid gap-4">
                                {[
                                    { label: "Identifiant", value: user.id },
                                    { label: "Nom d'utilisateur", value: user.username },
                                    { label: "Rôle", value: user.role || "—" },
                                    { label: "Niveau d'accès", value: niveauAcces },
                                    { label: "Statut du compte", value: accountStatus },
                                    { label: "Permissions principales", value: user.profil_admin?.permissions_specifiques || "Aucune permission spécifique définie" },
                                ].map((item) => (
                                    <div key={item.label} className="flex items-center justify-between gap-4 rounded-2xl bg-base-200 px-4 py-3">
                                        <span className="text-sm text-base-content/60">{item.label}</span>
                                        <span className="max-w-[60%] text-sm font-medium text-base-content text-right">{item.value}</span>
                                    </div>
                                ))}
                            </div>
                        </div>
                    </section>

                    <section className="rounded-3xl border border-base-200 bg-base-100 p-6">
                        <h2 className="text-sm uppercase tracking-widest text-base-content/40 font-medium mb-4">
                            Informations professionnelles
                        </h2>
                        <div className="grid gap-4">
                            {[
                                { label: "Département", value: "Non renseigné" },
                                { label: "Fonction", value: "Administrateur système" },
                                { label: "Description", value: "Supervision du service, gestion des utilisateurs et coordination des opérations." },
                                { label: "Notes internes", value: user.profil_admin?.permissions_specifiques || "Aucune note interne" },
                            ].map((item) => (
                                <div key={item.label} className="flex items-center justify-between gap-4 rounded-2xl bg-base-200 px-4 py-3">
                                    <span className="text-sm text-base-content/60">{item.label}</span>
                                    <span className="max-w-[60%] text-sm font-medium text-base-content text-right">{item.value}</span>
                                </div>
                            ))}
                        </div>
                    </section>
                </div>

                <aside className="space-y-6">
                    <section className="rounded-3xl border border-base-200 bg-base-100 p-6">
                        <h2 className="text-sm uppercase tracking-widest text-base-content/40 font-medium mb-4">
                            Modifier le profil
                        </h2>
                        <form onSubmit={handleSaveProfile} className="space-y-5">
                            <div className="grid gap-4">
                                <div className="form-control">
                                    <label className="label py-1">
                                        <span className="label-text text-sm font-medium">Prénom</span>
                                    </label>
                                    <input
                                        type="text"
                                        value={profile.first_name}
                                        onChange={(e) => handleFieldChange("first_name", e.target.value)}
                                        className="input input-bordered rounded-xl"
                                    />
                                </div>
                                <div className="form-control">
                                    <label className="label py-1">
                                        <span className="label-text text-sm font-medium">Nom</span>
                                    </label>
                                    <input
                                        type="text"
                                        value={profile.last_name}
                                        onChange={(e) => handleFieldChange("last_name", e.target.value)}
                                        className="input input-bordered rounded-xl"
                                    />
                                </div>
                                <div className="form-control">
                                    <label className="label py-1">
                                        <span className="label-text text-sm font-medium">Téléphone</span>
                                    </label>
                                    <input
                                        type="tel"
                                        value={profile.numero_telephone}
                                        onChange={(e) => handleFieldChange("numero_telephone", e.target.value)}
                                        placeholder="+228 90 00 00 00"
                                        className="input input-bordered rounded-xl"
                                    />
                                </div>
                                <div className="form-control">
                                    <label className="label py-1">
                                        <span className="label-text text-sm font-medium">Photo de profil</span>
                                    </label>
                                    <input
                                        type="file"
                                        accept="image/*"
                                        onChange={handlePhotoChange}
                                        className="file-input file-input-bordered rounded-xl w-full"
                                    />
                                </div>
                            </div>
                            <button
                                type="submit"
                                disabled={loading}
                                className="btn btn-primary w-full rounded-full"
                            >
                                {loading ? <span className="loading loading-spinner loading-sm" /> : "Enregistrer les modifications"}
                            </button>
                        </form>
                    </section>

                    <section className="rounded-3xl border border-base-200 bg-base-100 p-6">
                        <h2 className="text-sm uppercase tracking-widest text-base-content/40 font-medium mb-4">
                            Sécurité & mot de passe
                        </h2>
                        <form onSubmit={handleChangePassword} className="space-y-4">
                            <div className="form-control">
                                <label className="label py-1">
                                    <span className="label-text text-sm font-medium">Mot de passe actuel</span>
                                </label>
                                <input
                                    type="password"
                                    value={passwordForm.current_password}
                                    onChange={(e) => handlePasswordField("current_password", e.target.value)}
                                    className="input input-bordered rounded-xl"
                                />
                            </div>
                            <div className="form-control">
                                <label className="label py-1">
                                    <span className="label-text text-sm font-medium">Nouveau mot de passe</span>
                                </label>
                                <input
                                    type="password"
                                    value={passwordForm.new_password}
                                    onChange={(e) => handlePasswordField("new_password", e.target.value)}
                                    className="input input-bordered rounded-xl"
                                />
                            </div>
                            <div className="form-control">
                                <label className="label py-1">
                                    <span className="label-text text-sm font-medium">Confirmation du mot de passe</span>
                                </label>
                                <input
                                    type="password"
                                    value={passwordForm.new_password2}
                                    onChange={(e) => handlePasswordField("new_password2", e.target.value)}
                                    className="input input-bordered rounded-xl"
                                />
                            </div>
                            <button
                                type="submit"
                                disabled={loading}
                                className="btn btn-outline btn-primary w-full rounded-full"
                            >
                                {loading ? <span className="loading loading-spinner loading-sm" /> : "Changer le mot de passe"}
                            </button>
                        </form>
                    </section>

                    <section className="rounded-3xl border border-base-200 bg-base-100 p-6">
                        <h2 className="text-sm uppercase tracking-widest text-base-content/40 font-medium mb-4">
                            Authentification & sessions
                        </h2>
                        <div className="space-y-4">
                            <div className="rounded-2xl bg-base-200 px-4 py-3">
                                <p className="text-sm text-base-content/60">Authentification à deux facteurs</p>
                                <p className="mt-2 text-sm font-medium text-base-content">Non disponible</p>
                            </div>
                            <div className="rounded-2xl bg-base-200 px-4 py-3">
                                <p className="text-sm text-base-content/60">Sessions actives</p>
                                <p className="mt-2 text-sm font-medium text-base-content">Gestion des sessions depuis le Django Admin</p>
                            </div>
                            <div className="rounded-2xl bg-base-200 px-4 py-3">
                                <p className="text-sm text-base-content/60">Historique des connexions</p>
                                <p className="mt-2 text-sm font-medium text-base-content">Dernière connexion : {user.last_login ? new Date(user.last_login).toLocaleString("fr-FR") : "Jamais"}</p>
                            </div>
                        </div>
                    </section>
                </aside>
            </div>
        </div>
    );
}
