"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/src/hooks/useAuth";
import { api } from "@/src/services/api";
import { getMediaUrl } from "@/src/utils/imageUtils";

interface ProfilForm {
    first_name: string;
    last_name: string;
    email: string;
    numero_telephone: string;
}

export default function ProfilPassagerPage() {
    const { user, logout } = useAuth();
    const router = useRouter();

    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [success, setSuccess] = useState<string | null>(null);
    const [photoFile, setPhotoFile] = useState<File | null>(null);
    const [suppression, setSuppression] = useState(false);

    // Bascule conducteur
    const [modaleBascule, setModaleBascule] = useState(false);
    const [basculeForm, setBasculeForm] = useState({
        numero_permis: "", experience_annees: "0",
        type_vehicule: "", marque: "", modele: "", couleur: "", plaque: "",
    });
    const [cniFile,    setCniFile]    = useState<File | null>(null);
    const [permisFile, setPermisFile] = useState<File | null>(null);
    const [basculeLoading, setBasculeLoading] = useState(false);

    const [profil, setProfil] = useState<ProfilForm>({
        first_name: "",
        last_name: "",
        email: "",
        numero_telephone: "",
    });

    useEffect(() => {
        if (user) {
            setProfil({
                first_name: user.first_name || "",
                last_name: user.last_name || "",
                email: user.email || "",
                numero_telephone: user.numero_telephone || "",
            });
        }
    }, [user]);

    const setP = (field: keyof ProfilForm, value: string) =>
        setProfil((prev) => ({ ...prev, [field]: value }));

    const handleSauvegarder = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);
        setError(null);
        setSuccess(null);
        try {
            const payload = new FormData();
            payload.append("first_name", profil.first_name);
            payload.append("last_name", profil.last_name);
            payload.append("numero_telephone", profil.numero_telephone);
            if (photoFile) payload.append("photo_profil", photoFile);

            await api("/utilisateurs/ko/profil/update/", "PUT", payload);
            setSuccess("Profil mis à jour avec succès.");
        } catch (err: any) {
            setError(err.response?.data?.error || "Erreur lors de la mise à jour.");
        } finally {
            setLoading(false);
        }
    };

    const setBF = (field: keyof typeof basculeForm, value: string) =>
        setBasculeForm((prev) => ({ ...prev, [field]: value }));

    const handleBasculerRole = async (e: React.FormEvent) => {
        e.preventDefault();
        setBasculeLoading(true);
        setError(null);
        try {
            const payload = new FormData();
            Object.entries(basculeForm).forEach(([k, v]) => payload.append(k, v));
            if (cniFile)    payload.append("photo_cni",    cniFile);
            if (permisFile) payload.append("photo_permis", permisFile);

            await api("/utilisateurs/ko/basculer-role/", "POST", payload);
            setModaleBascule(false);
            setSuccess("Demande soumise ! Un administrateur validera votre dossier sous 24h. Reconnectez-vous ensuite.");
        } catch (err: any) {
            const d = err.response?.data;
            if (d && typeof d === "object") {
                setError(Object.entries(d).map(([k, v]) => `${k} : ${v}`).join(" | "));
            } else {
                setError("Erreur lors de la soumission.");
            }
        } finally {
            setBasculeLoading(false);
        }
    };

    const handleSupprimerCompte = async () => {
        if (!confirm("Supprimer définitivement votre compte ? Cette action est irréversible.")) return;
        setSuppression(true);
        try {
            const refresh = localStorage.getItem("refresh");
            await api("/utilisateurs/ko/profil/delete/", "DELETE", { refresh });
            logout();
            router.push("/");
        } catch {
            setError("Erreur lors de la suppression du compte.");
            setSuppression(false);
        }
    };

    return (
        <div className="max-w-2xl mx-auto space-y-8">

            {/* EN-TÊTE */}
            <div className="pb-6 border-b border-base-300">
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">
                    Passager
                </p>
                <h1 className="text-2xl font-bold text-base-content tracking-tight">
                    Profil & Paramètres
                </h1>
            </div>

            {/* Avatar + infos rapides */}
            <div className="flex items-center gap-4">
                <div className="w-16 h-16 rounded-full bg-primary/10 flex items-center justify-center shrink-0 overflow-hidden">
                    {user?.photo_profil ? (
                        <img src={getMediaUrl(user.photo_profil)} alt="profil" className="w-16 h-16 object-cover" />
                    ) : (
                        <span className="text-2xl font-bold text-primary">
                            {user?.first_name?.[0]?.toUpperCase() || user?.username?.[0]?.toUpperCase()}
                        </span>
                    )}
                </div>
                <div>
                    <p className="font-semibold text-base-content">
                        {user?.first_name} {user?.last_name}
                    </p>
                    <p className="text-sm text-base-content/40">{user?.email}</p>
                    <div className="flex items-center gap-1 mt-1">
                        {[1, 2, 3, 4, 5].map((s) => (
                            <div key={s} className={`w-2.5 h-2.5 rounded-sm ${s <= Math.round(user?.note || 0) ? "bg-warning" : "bg-base-300"
                                }`} />
                        ))}
                        <span className="text-xs text-base-content/40 ml-1">
                            {user?.note || 0} / 5
                        </span>
                    </div>
                </div>
            </div>

            {/* Stats passager */}
            <div className="grid grid-cols-2 gap-4">
                <div className="bg-base-100 rounded-2xl border border-base-200 p-5">
                    <p className="text-2xl font-bold text-base-content">
                        {user?.profil_passager?.historique_points || 0}
                    </p>
                    <p className="text-xs text-base-content/40 uppercase tracking-wide mt-1">
                        Points accumulés
                    </p>
                </div>
                <div className="bg-base-100 rounded-2xl border border-base-200 p-5">
                    <p className="text-2xl font-bold text-base-content">
                        {user?.note || 0} / 5
                    </p>
                    <p className="text-xs text-base-content/40 uppercase tracking-wide mt-1">
                        Note moyenne
                    </p>
                </div>
            </div>

            {/* Messages */}
            {error && (
                <div className="bg-error/10 border border-error/20 rounded-xl px-4 py-3">
                    <p className="text-sm text-error">{error}</p>
                </div>
            )}
            {success && (
                <div className="bg-success/10 border border-success/20 rounded-xl px-4 py-3">
                    <p className="text-sm text-success">{success}</p>
                </div>
            )}

            {/* Formulaire */}
            <form onSubmit={handleSauvegarder} className="space-y-5">

                <div className="bg-base-100 rounded-2xl border border-base-200 p-6 space-y-4">
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                        Informations personnelles
                    </p>

                    <div className="grid grid-cols-2 gap-3">
                        <div className="form-control">
                            <label className="label py-1">
                                <span className="label-text text-sm font-medium">Prénom</span>
                            </label>
                            <input
                                type="text"
                                className="input input-bordered rounded-xl"
                                value={profil.first_name}
                                onChange={(e) => setP("first_name", e.target.value)}
                            />
                        </div>
                        <div className="form-control">
                            <label className="label py-1">
                                <span className="label-text text-sm font-medium">Nom</span>
                            </label>
                            <input
                                type="text"
                                className="input input-bordered rounded-xl"
                                value={profil.last_name}
                                onChange={(e) => setP("last_name", e.target.value)}
                            />
                        </div>
                    </div>

                    <div className="form-control">
                        <label className="label py-1">
                            <span className="label-text text-sm font-medium">Email</span>
                        </label>
                        <input
                            type="email"
                            className="input input-bordered rounded-xl bg-base-200 cursor-not-allowed"
                            value={profil.email}
                            disabled
                        />
                        <p className="text-xs text-base-content/30 mt-1 ml-1">
                            L'email ne peut pas être modifié
                        </p>
                    </div>

                    <div className="form-control">
                        <label className="label py-1">
                            <span className="label-text text-sm font-medium">Téléphone</span>
                        </label>
                        <input
                            type="tel"
                            placeholder="+228 90 00 00 00"
                            className="input input-bordered rounded-xl"
                            value={profil.numero_telephone}
                            onChange={(e) => setP("numero_telephone", e.target.value)}
                        />
                    </div>

                    <div className="form-control">
                        <label className="label py-1">
                            <span className="label-text text-sm font-medium">
                                Photo de profil
                            </span>
                        </label>
                        <input
                            type="file"
                            accept="image/*"
                            className="file-input file-input-bordered rounded-xl w-full"
                            onChange={(e) => setPhotoFile(e.target.files?.[0] || null)}
                        />
                    </div>
                </div>

                <button
                    type="submit"
                    disabled={loading}
                    className="btn btn-primary w-full rounded-full"
                >
                    {loading
                        ? <span className="loading loading-spinner loading-sm" />
                        : "Enregistrer les modifications"
                    }
                </button>
            </form>

            {/* Devenir conducteur */}
            <div className="bg-base-100 rounded-2xl border border-base-200 p-6 space-y-3">
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                    Devenir conducteur
                </p>

                {/* Statut si demande déjà soumise */}
                {user?.statut_validation === "en_attente" && (
                    <div className="bg-warning/10 border border-warning/20 rounded-xl px-4 py-3">
                        <p className="text-sm text-warning font-medium">⏳ Demande en cours de validation</p>
                        <p className="text-xs text-base-content/50 mt-1">
                            Votre dossier est examiné par un administrateur. Vous serez notifié sous 24h.
                        </p>
                    </div>
                )}
                {user?.statut_validation === "rejete" && (
                    <div className="bg-error/10 border border-error/20 rounded-xl px-4 py-3">
                        <p className="text-sm text-error font-medium">✗ Dossier rejeté</p>
                        <p className="text-xs text-base-content/50 mt-1">
                            Vos documents ont été refusés. Soumettez un nouveau dossier avec des documents conformes.
                        </p>
                    </div>
                )}

                {user?.statut_validation !== "en_attente" && (
                    <>
                        <p className="text-sm text-base-content/60">
                            Vous avez un véhicule et souhaitez proposer des trajets ?
                            Soumettez votre dossier pour devenir conducteur.
                        </p>
                        <button
                            onClick={() => setModaleBascule(true)}
                            className="btn btn-primary btn-sm rounded-full"
                        >
                            Devenir conducteur
                        </button>
                    </>
                )}
            </div>

            {/* ── MODALE BASCULE CONDUCTEUR ── */}
            {modaleBascule && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
                    <div className="bg-base-100 rounded-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto shadow-2xl">

                        <div className="p-6 border-b border-base-200 flex justify-between items-center sticky top-0 bg-base-100">
                            <div>
                                <h2 className="font-bold text-lg">Devenir conducteur</h2>
                                <p className="text-xs text-base-content/40">
                                    Remplissez le formulaire — validation sous 24h
                                </p>
                            </div>
                            <button onClick={() => setModaleBascule(false)} className="btn btn-ghost btn-sm btn-circle">✕</button>
                        </div>

                        <form onSubmit={handleBasculerRole} className="p-6 space-y-5">

                            {/* Permis */}
                            <div className="space-y-3">
                                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                                    Informations conducteur
                                </p>
                                <div className="grid grid-cols-2 gap-3">
                                    <div className="form-control col-span-2">
                                        <label className="label py-1">
                                            <span className="label-text text-sm font-medium">Numéro de permis</span>
                                        </label>
                                        <input type="text" placeholder="TG-12345-2020"
                                            className="input input-bordered input-sm rounded-xl"
                                            value={basculeForm.numero_permis}
                                            onChange={(e) => setBF("numero_permis", e.target.value)}
                                            required />
                                    </div>
                                    <div className="form-control">
                                        <label className="label py-1">
                                            <span className="label-text text-sm font-medium">Années d'expérience</span>
                                        </label>
                                        <input type="number" min="0" max="50"
                                            className="input input-bordered input-sm rounded-xl"
                                            value={basculeForm.experience_annees}
                                            onChange={(e) => setBF("experience_annees", e.target.value)} />
                                    </div>
                                </div>
                            </div>

                            {/* Véhicule */}
                            <div className="space-y-3">
                                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                                    Mon véhicule
                                </p>
                                <div className="grid grid-cols-2 gap-2">
                                    {[
                                        { value: "moto",    label: "Moto",    detail: "1 place · 30F/km" },
                                        { value: "voiture", label: "Voiture", detail: "5 places · 65F/km" },
                                        { value: "minibus", label: "Minibus", detail: "15 places · 120F/km" },
                                        { value: "camion",  label: "Camion",  detail: "3 places · 200F/km" },
                                    ].map((t) => (
                                        <button key={t.value} type="button"
                                            onClick={() => setBF("type_vehicule", t.value)}
                                            className={`btn btn-sm rounded-xl flex flex-col h-auto py-2 gap-0 ${basculeForm.type_vehicule === t.value ? "btn-primary" : "btn-outline"}`}>
                                            <span className="font-semibold">{t.label}</span>
                                            <span className="text-xs opacity-70 font-normal">{t.detail}</span>
                                        </button>
                                    ))}
                                </div>
                                <div className="grid grid-cols-2 gap-3">
                                    {(["marque", "modele", "couleur", "plaque"] as const).map((f) => (
                                        <div key={f} className="form-control">
                                            <label className="label py-1">
                                                <span className="label-text text-sm font-medium capitalize">{f}</span>
                                            </label>
                                            <input type="text"
                                                placeholder={f === "plaque" ? "TG 1234 LM" : f === "marque" ? "Toyota" : f === "modele" ? "Corolla" : "Blanc"}
                                                className="input input-bordered input-sm rounded-xl"
                                                value={basculeForm[f]}
                                                onChange={(e) => setBF(f, e.target.value)}
                                                required />
                                        </div>
                                    ))}
                                </div>
                            </div>

                            {/* Documents */}
                            <div className="space-y-3">
                                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                                    Documents d'identité
                                </p>
                                <div className="form-control">
                                    <label className="label py-1">
                                        <span className="label-text text-sm font-medium">CNI / Carte d'identité</span>
                                        <span className="label-text-alt text-base-content/40 text-xs">Recommandé</span>
                                    </label>
                                    <input type="file" accept="image/*,.pdf"
                                        className="file-input file-input-bordered file-input-sm rounded-xl w-full"
                                        onChange={(e) => setCniFile(e.target.files?.[0] || null)} />
                                </div>
                                <div className="form-control">
                                    <label className="label py-1">
                                        <span className="label-text text-sm font-medium">Permis de conduire</span>
                                        <span className="label-text-alt text-base-content/40 text-xs">Recommandé</span>
                                    </label>
                                    <input type="file" accept="image/*,.pdf"
                                        className="file-input file-input-bordered file-input-sm rounded-xl w-full"
                                        onChange={(e) => setPermisFile(e.target.files?.[0] || null)} />
                                </div>
                            </div>

                            <div className="flex gap-3 pt-2">
                                <button type="button" onClick={() => setModaleBascule(false)}
                                    className="btn btn-ghost btn-sm rounded-full flex-1 border border-base-300">
                                    Annuler
                                </button>
                                <button type="submit"
                                    disabled={basculeLoading || !basculeForm.numero_permis || !basculeForm.type_vehicule}
                                    className="btn btn-primary btn-sm rounded-full flex-1">
                                    {basculeLoading
                                        ? <span className="loading loading-spinner loading-xs" />
                                        : "Soumettre le dossier"
                                    }
                                </button>
                            </div>
                        </form>
                    </div>
                </div>
            )}

            {/* Zone danger */}
            <div className="bg-base-100 rounded-2xl border border-error/20 p-6 space-y-3">
                <p className="text-xs text-error/60 uppercase tracking-widest font-medium">
                    Zone dangereuse
                </p>
                <p className="text-sm text-base-content/60">
                    La suppression de votre compte est définitive. Toutes vos données seront perdues.
                </p>
                <button
                    onClick={handleSupprimerCompte}
                    disabled={suppression}
                    className="btn btn-ghost btn-sm rounded-full border border-error/30 text-error hover:bg-error/5"
                >
                    {suppression
                        ? <span className="loading loading-spinner loading-xs" />
                        : "Supprimer mon compte"
                    }
                </button>
            </div>

        </div>
    );
}