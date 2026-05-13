"use client";

import { useState, useEffect } from "react";
import { useAuth } from "@/src/hooks/useAuth";
import { api } from "@/src/services/api";
import {
    mesVehicules,
    ajouterVehicule,
    desactiverVehicule,
    type Vehicule,
} from "@/src/services/trajet.service";
import { getMediaUrl } from "@/src/utils/imageUtils";

const TYPES_VEHICULE = [
    { value: "moto", label: "Moto", places: 1, tarif: "30 FCFA/km" },
    { value: "voiture", label: "Voiture", places: 5, tarif: "65 FCFA/km" },
    { value: "minibus", label: "Minibus", places: 15, tarif: "120 FCFA/km" },
    { value: "camion", label: "Camion", places: 3, tarif: "200 FCFA/km" },
];

interface ProfilForm {
    first_name: string;
    last_name: string;
    email: string;
    numero_telephone: string;
    numero_permis: string;
    experience_annees: string;
}

interface VehiculeForm {
    type_vehicule: string;
    marque: string;
    modele: string;
    couleur: string;
    plaque: string;
}

export default function ProfilConducteurPage() {
    const { user } = useAuth();

    const [onglet, setOnglet] = useState<"profil" | "vehicules">("profil");
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [success, setSuccess] = useState<string | null>(null);
    const [vehicules, setVehicules] = useState<Vehicule[]>([]);
    const [ajout, setAjout] = useState(false);
    const [photoFile, setPhotoFile] = useState<File | null>(null);

    const [profil, setProfil] = useState<ProfilForm>({
        first_name: "",
        last_name: "",
        email: "",
        numero_telephone: "",
        numero_permis: "",
        experience_annees: "",
    });

    const [vForm, setVForm] = useState<VehiculeForm>({
        type_vehicule: "",
        marque: "",
        modele: "",
        couleur: "",
        plaque: "",
    });

    // Charger les données utilisateur
    useEffect(() => {
        if (user) {
            console.log(" Données utilisateur:", user);
            console.log(" first_name:", user.first_name);
            console.log(" last_name:", user.last_name);
            setProfil({
                first_name: user.first_name || "",
                last_name: user.last_name || "",
                email: user.email || "",
                numero_telephone: user.numero_telephone || "",
                numero_permis: user.profil_conducteur?.numero_permis || "",
                experience_annees: String(user.profil_conducteur?.experience_annees || ""),
            });
        }
    }, [user]);

    // Charger les véhicules
    useEffect(() => {
        fetchVehicules();
    }, []);

    const fetchVehicules = async () => {
        try {
            const data = await mesVehicules();
            setVehicules(Array.isArray(data) ? data : []);
        } catch {
            setError("Impossible de charger les véhicules.");
        }
    };

    const setP = (field: keyof ProfilForm, value: string) =>
        setProfil((prev) => ({ ...prev, [field]: value }));

    const setV = (field: keyof VehiculeForm, value: string) =>
        setVForm((prev) => ({ ...prev, [field]: value }));

    // Sauvegarder le profil
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

    // Ajouter un véhicule
    const handleAjouterVehicule = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);
        setError(null);
        setSuccess(null);
        try {
            await ajouterVehicule({
                type_vehicule: vForm.type_vehicule,
                marque: vForm.marque,
                modele: vForm.modele,
                couleur: vForm.couleur,
                plaque: vForm.plaque,
                places_max: TYPES_VEHICULE.find((t) => t.value === vForm.type_vehicule)?.places || 4,
            });
            setSuccess("Véhicule ajouté avec succès.");
            setAjout(false);
            setVForm({ type_vehicule: "", marque: "", modele: "", couleur: "", plaque: "" });
            fetchVehicules();
        } catch (err: any) {
            const errors = err.response?.data;
            if (errors && typeof errors === "object") {
                setError(Object.entries(errors).map(([k, v]) => `${k} : ${v}`).join(" | "));
            } else {
                setError("Erreur lors de l'ajout du véhicule.");
            }
        } finally {
            setLoading(false);
        }
    };

    // Désactiver un véhicule
    const handleDesactiver = async (id: number) => {
        if (!confirm("Désactiver ce véhicule ? Il ne sera plus disponible pour les trajets.")) return;
        try {
            await desactiverVehicule(id);
            setVehicules((prev) => prev.map((v) => v.id === id ? { ...v, est_actif: false } : v));
            setSuccess("Véhicule désactivé.");
        } catch {
            setError("Erreur lors de la désactivation.");
        }
    };

    const typeSelectionne = TYPES_VEHICULE.find((t) => t.value === vForm.type_vehicule);

    return (
        <div className="max-w-2xl mx-auto space-y-8">

            {/* EN-TÊTE */}
            <div className="pb-6 border-b border-base-300">
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">
                    Conducteur
                </p>
                <h1 className="text-2xl font-bold text-base-content tracking-tight">
                    Profil & Paramètres
                </h1>
            </div>

            {/* Avatar */}
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
                        <span className="text-xs text-base-content/40 ml-1">{user?.note || 0} / 5</span>
                    </div>
                </div>
            </div>

            {/* ONGLETS */}
            <div className="flex gap-1 bg-base-200 rounded-xl p-1">
                {([
                    { value: "profil", label: "Informations" },
                    { value: "vehicules", label: "Mes véhicules" },
                ] as const).map((tab) => (
                    <button
                        key={tab.value}
                        onClick={() => { setOnglet(tab.value); setError(null); setSuccess(null); }}
                        className={`flex-1 btn btn-sm rounded-lg transition-all ${onglet === tab.value ? "btn-primary shadow-sm" : "btn-ghost"
                            }`}
                    >
                        {tab.label}
                    </button>
                ))}
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

            {/* ── ONGLET PROFIL ── */}
            {onglet === "profil" && (
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
                                <input type="text" className="input input-bordered rounded-xl"
                                    value={profil.first_name}
                                    onChange={(e) => setP("first_name", e.target.value)} />
                            </div>
                            <div className="form-control">
                                <label className="label py-1">
                                    <span className="label-text text-sm font-medium">Nom</span>
                                </label>
                                <input type="text" className="input input-bordered rounded-xl"
                                    value={profil.last_name}
                                    onChange={(e) => setP("last_name", e.target.value)} />
                            </div>
                        </div>

                        <div className="form-control">
                            <label className="label py-1">
                                <span className="label-text text-sm font-medium">Email</span>
                            </label>
                            <input type="email" className="input input-bordered rounded-xl bg-base-200 cursor-not-allowed"
                                value={profil.email} disabled />
                            <p className="text-xs text-base-content/30 mt-1 ml-1">L'email ne peut pas être modifié</p>
                        </div>

                        <div className="form-control">
                            <label className="label py-1">
                                <span className="label-text text-sm font-medium">Téléphone</span>
                            </label>
                            <input type="tel" placeholder="+228 90 00 00 00"
                                className="input input-bordered rounded-xl"
                                value={profil.numero_telephone}
                                onChange={(e) => setP("numero_telephone", e.target.value)} />
                        </div>

                        <div className="form-control">
                            <label className="label py-1">
                                <span className="label-text text-sm font-medium">Photo de profil</span>
                            </label>
                            <input type="file" accept="image/*"
                                className="file-input file-input-bordered rounded-xl w-full"
                                onChange={(e) => setPhotoFile(e.target.files?.[0] || null)} />
                        </div>
                    </div>

                    <div className="bg-base-100 rounded-2xl border border-base-200 p-6 space-y-4">
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                            Informations conducteur
                        </p>

                        <div className="flex justify-between items-center py-2">
                            <span className="text-xs text-base-content/40 uppercase tracking-wide">Numéro de permis</span>
                            <span className="text-sm font-medium text-base-content">{profil.numero_permis || "—"}</span>
                        </div>

                        <div className="flex justify-between items-center py-2 border-t border-base-200">
                            <span className="text-xs text-base-content/40 uppercase tracking-wide">Expérience</span>
                            <span className="text-sm font-medium text-base-content">
                                {profil.experience_annees ? `${profil.experience_annees} an${Number(profil.experience_annees) > 1 ? "s" : ""}` : "—"}
                            </span>
                        </div>

                        <p className="text-xs text-base-content/30">
                            Le numéro de permis et l'expérience ne peuvent pas être modifiés. Contactez le support si nécessaire.
                        </p>
                    </div>

                    <button type="submit" disabled={loading} className="btn btn-primary w-full rounded-full">
                        {loading ? <span className="loading loading-spinner loading-sm" /> : "Enregistrer les modifications"}
                    </button>
                </form>
            )}

            {/* ── ONGLET VÉHICULES ── */}
            {onglet === "vehicules" && (
                <div className="space-y-4">

                    {/* Liste des véhicules */}
                    {vehicules.length === 0 ? (
                        <div className="bg-base-100 rounded-2xl border border-base-200 p-12 text-center">
                            <p className="text-base-content/40 text-sm">Aucun véhicule enregistré.</p>
                        </div>
                    ) : (
                        <div className="flex flex-col gap-3">
                            {vehicules.map((v) => (
                                <div key={v.id}
                                    className={`bg-base-100 rounded-2xl border overflow-hidden ${v.est_actif ? "border-base-200" : "border-base-200 opacity-50"
                                        }`}
                                >
                                    <div className="flex items-center justify-between px-5 py-4">
                                        <div className="flex-1">
                                            <div className="flex items-center gap-2 mb-1">
                                                <p className="font-semibold text-base-content">
                                                    {v.marque} {v.modele}
                                                </p>
                                                <span className={`badge badge-sm rounded-full ${v.est_actif ? "badge-success badge-outline" : "badge-ghost"
                                                    }`}>
                                                    {v.est_actif ? "Actif" : "Désactivé"}
                                                </span>
                                            </div>
                                            <div className="flex gap-4 flex-wrap">
                                                {[
                                                    { label: "Type", value: v.type_vehicule },
                                                    { label: "Couleur", value: v.couleur },
                                                    { label: "Plaque", value: v.plaque },
                                                    { label: "Places", value: `${v.places_max} max` },
                                                ].map((item) => (
                                                    <div key={item.label} className="flex items-center gap-1">
                                                        <span className="text-xs text-base-content/40 capitalize">{item.label} :</span>
                                                        <span className="text-xs font-medium text-base-content capitalize">{item.value}</span>
                                                    </div>
                                                ))}
                                            </div>
                                        </div>
                                        {v.est_actif && (
                                            <button
                                                onClick={() => handleDesactiver(v.id)}
                                                className="btn btn-ghost btn-xs rounded-xl border border-error/30 text-error hover:bg-error/5 ml-3"
                                            >
                                                Désactiver
                                            </button>
                                        )}
                                    </div>

                                    {/* Tarif info */}
                                    <div className="px-5 py-2.5 bg-base-200/40 border-t border-base-200">
                                        <p className="text-xs text-base-content/40">
                                            Tarif : {TYPES_VEHICULE.find((t) => t.value === v.type_vehicule)?.tarif || "—"}
                                            · Prix calculé automatiquement selon ce tarif
                                        </p>
                                    </div>
                                </div>
                            ))}
                        </div>
                    )}

                    {/* Bouton ajouter */}
                    {!ajout && (
                        <button
                            onClick={() => { setAjout(true); setError(null); setSuccess(null); }}
                            className="btn btn-primary w-full rounded-full"
                        >
                            Ajouter un véhicule
                        </button>
                    )}

                    {/* Formulaire ajout véhicule */}
                    {ajout && (
                        <form onSubmit={handleAjouterVehicule}
                            className="bg-base-100 rounded-2xl border border-base-200 p-6 space-y-4">
                            <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                                Nouveau véhicule
                            </p>

                            {/* Type */}
                            <div className="form-control">
                                <label className="label py-1">
                                    <span className="label-text text-sm font-medium">Type de véhicule</span>
                                </label>
                                <div className="grid grid-cols-2 gap-2">
                                    {TYPES_VEHICULE.map((t) => (
                                        <button key={t.value} type="button"
                                            onClick={() => setV("type_vehicule", t.value)}
                                            className={`btn btn-sm rounded-xl flex flex-col h-auto py-2 gap-0 ${vForm.type_vehicule === t.value ? "btn-primary" : "btn-outline"
                                                }`}>
                                            <span className="font-semibold">{t.label}</span>
                                            <span className="text-xs opacity-70 font-normal">
                                                {t.places} place{t.places > 1 ? "s" : ""} · {t.tarif}
                                            </span>
                                        </button>
                                    ))}
                                </div>
                            </div>

                            {/* Marque + Modèle */}
                            <div className="grid grid-cols-2 gap-3">
                                <div className="form-control">
                                    <label className="label py-1">
                                        <span className="label-text text-sm font-medium">Marque</span>
                                    </label>
                                    <input type="text" placeholder="Toyota, Honda..."
                                        className="input input-bordered input-sm rounded-xl"
                                        value={vForm.marque}
                                        onChange={(e) => setV("marque", e.target.value)}
                                        required />
                                </div>
                                <div className="form-control">
                                    <label className="label py-1">
                                        <span className="label-text text-sm font-medium">Modèle</span>
                                    </label>
                                    <input type="text" placeholder="Corolla, CB125..."
                                        className="input input-bordered input-sm rounded-xl"
                                        value={vForm.modele}
                                        onChange={(e) => setV("modele", e.target.value)}
                                        required />
                                </div>
                            </div>

                            {/* Couleur + Plaque */}
                            <div className="grid grid-cols-2 gap-3">
                                <div className="form-control">
                                    <label className="label py-1">
                                        <span className="label-text text-sm font-medium">Couleur</span>
                                    </label>
                                    <input type="text" placeholder="Blanc, Rouge..."
                                        className="input input-bordered input-sm rounded-xl"
                                        value={vForm.couleur}
                                        onChange={(e) => setV("couleur", e.target.value)}
                                        required />
                                </div>
                                <div className="form-control">
                                    <label className="label py-1">
                                        <span className="label-text text-sm font-medium">Plaque</span>
                                    </label>
                                    <input type="text" placeholder="TG 1234 LM"
                                        className="input input-bordered input-sm rounded-xl"
                                        value={vForm.plaque}
                                        onChange={(e) => setV("plaque", e.target.value)}
                                        required />
                                </div>
                            </div>

                            {typeSelectionne && (
                                <div className="bg-primary/5 border border-primary/10 rounded-xl px-4 py-3">
                                    <p className="text-xs text-base-content/50">
                                        Tarif carburant : <span className="font-semibold">{typeSelectionne.tarif}</span>
                                        · Places max : <span className="font-semibold">{typeSelectionne.places}</span>
                                    </p>
                                </div>
                            )}

                            <div className="flex gap-3">
                                <button type="button"
                                    onClick={() => { setAjout(false); setVForm({ type_vehicule: "", marque: "", modele: "", couleur: "", plaque: "" }); }}
                                    className="btn btn-ghost btn-sm rounded-full flex-1 border border-base-300">
                                    Annuler
                                </button>
                                <button type="submit" disabled={loading || !vForm.type_vehicule}
                                    className="btn btn-primary btn-sm rounded-full flex-1">
                                    {loading ? <span className="loading loading-spinner loading-xs" /> : "Ajouter"}
                                </button>
                            </div>
                        </form>
                    )}
                </div>
            )}

        </div>
    );
}