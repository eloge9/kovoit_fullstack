"use client";

import { useState, useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import dynamic from "next/dynamic";
import { useDriverVerification } from "@/src/hooks/useDriverVerification";
import {
    searchLieu,
    formatNominatimLabel,
    calculerDistance,
    calculerCoutTotal,
    calculerPrixParPlace,
    mesVehicules,
    creerTrajet,
    ajouterEscale,
    type NominatimResult,
    type Vehicule,
    type Escale,
} from "@/src/services/trajet.service";

const MapView = dynamic(() => import("@/components/MapView"), { ssr: false });

// ─── Types ────────────────────────────────────────────────────────────────
interface LieuSelectionne {
    nom: string;
    lat: number;
    lng: number;
}

interface FormData {
    vehicule_id: number | null;
    depart: LieuSelectionne | null;
    destination: LieuSelectionne | null;
    distance_km: number;
    cout_total: number;
    prix_par_place: number;
    places_disponibles: number;   // places proposées par le conducteur
    date_heure_depart: string;
    description: string;
    est_regulier: boolean;
    jours_semaine: string[];
}

const JOURS = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"];

// ─── Autocomplete ──────────────────────────────────────────────────────────
function AutocompleteInput({ label, placeholder, value, onSelect, onClear }: {
    label: string;
    placeholder: string;
    value: LieuSelectionne | null;
    onSelect: (lieu: LieuSelectionne) => void;
    onClear: () => void;
}) {
    const [query, setQuery] = useState(value?.nom || "");
    const [results, setResults] = useState<NominatimResult[]>([]);
    const [loading, setLoading] = useState(false);
    const [open, setOpen] = useState(false);
    const debounceRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

    useEffect(() => { setQuery(value?.nom || ""); }, [value]);

    const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        const q = e.target.value;
        setQuery(q);
        if (value) onClear();
        clearTimeout(debounceRef.current);
        if (q.length < 2) { setResults([]); setOpen(false); return; }
        debounceRef.current = setTimeout(async () => {
            setLoading(true);
            try {
                const data = await searchLieu(q);
                setResults(data);
                setOpen(true);
            } finally { setLoading(false); }
        }, 400);
    };

    const handleSelect = (result: NominatimResult) => {
        const lbl = formatNominatimLabel(result);
        setQuery(lbl);
        setOpen(false);
        onSelect({ nom: lbl, lat: parseFloat(result.lat), lng: parseFloat(result.lon) });
    };

    const handleGPS = () => {
        if (!navigator.geolocation) return;
        setLoading(true);
        navigator.geolocation.getCurrentPosition(async (pos) => {
            const { latitude: lat, longitude: lng } = pos.coords;
            try {
                const res = await fetch(
                    `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lng}&format=json`,
                    { headers: { "Accept-Language": "fr" } }
                );
                const data = await res.json();
                const nom = formatNominatimLabel(data);
                setQuery(nom);
                onSelect({ nom, lat, lng });
            } finally { setLoading(false); }
        }, () => setLoading(false));
    };

    return (
        <div className="form-control relative">
            <label className="label">
                <span className="label-text font-medium text-sm">{label}</span>
            </label>
            <div className="relative flex gap-2">
                <div className="relative flex-1">
                    <input
                        type="text"
                        value={query}
                        onChange={handleChange}
                        placeholder={placeholder}
                        className={`input input-bordered w-full rounded-xl pr-8 ${value ? "input-success" : ""}`}
                    />
                    {loading && <span className="loading loading-spinner loading-xs absolute right-3 top-1/2 -translate-y-1/2 text-base-content/40" />}
                    {value && !loading && (
                        <button type="button" onClick={() => { onClear(); setQuery(""); }}
                            className="absolute right-3 top-1/2 -translate-y-1/2 text-base-content/30 hover:text-base-content">
                            ×
                        </button>
                    )}
                </div>
                <button type="button" onClick={handleGPS}
                    className="btn btn-square btn-outline rounded-xl" title="Ma position actuelle">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                    </svg>
                </button>
            </div>
            {open && results.length > 0 && (
                <ul className="absolute top-full left-0 right-0 z-50 bg-base-100 border border-base-200 rounded-xl shadow-lg mt-1 overflow-hidden">
                    {results.map((r) => (
                        <li key={r.place_id} onMouseDown={() => handleSelect(r)}
                            className="px-4 py-2.5 hover:bg-base-200 cursor-pointer transition-colors">
                            <p className="text-sm font-medium text-base-content">{formatNominatimLabel(r)}</p>
                            <p className="text-xs text-base-content/40 truncate">{r.display_name}</p>
                        </li>
                    ))}
                </ul>
            )}
        </div>
    );
}

// ─── Page principale ───────────────────────────────────────────────────────
export default function ProposerTrajetPage() {
    const router = useRouter();
    const { isActive, loading: verifLoading, status: verifStatus } = useDriverVerification();

    const [step, setStep] = useState<1 | 2 | 3>(1);
    const [loading, setLoading] = useState(false);
    const [calcul, setCalcul] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [vehicules, setVehicules] = useState<Vehicule[]>([]);
    const [loadingVehicules, setLoadingVehicules] = useState(true);
    const [escales, setEscales] = useState<Omit<Escale, "id">[]>([]);
    const [nouvelleEscale, setNouvelleEscale] = useState<{ nom: string; lat: number | null; lng: number | null } | null>(null);

    const [form, setForm] = useState<FormData>({
        vehicule_id: null,
        depart: null,
        destination: null,
        distance_km: 0,
        cout_total: 0,
        prix_par_place: 0,
        places_disponibles: 0,   // 0 = pas encore défini
        date_heure_depart: "",
        description: "",
        est_regulier: false,
        jours_semaine: [],
    });

    const set = (field: keyof FormData, value: any) =>
        setForm((prev) => ({ ...prev, [field]: value }));

    // Charger les véhicules du conducteur
    useEffect(() => {
        const fetch = async () => {
            setLoadingVehicules(true);
            try {
                const data = await mesVehicules();
                setVehicules(Array.isArray(data) ? data.filter((v: Vehicule) => v.est_actif) : []);
            } catch {
                setError("Impossible de charger vos véhicules.");
            } finally {
                setLoadingVehicules(false);
            }
        };
        fetch();
    }, []);

    // Véhicule sélectionné
    const vehiculeSelectionne = vehicules.find((v) => v.id === form.vehicule_id) || null;

    // Recalcul prix quand départ, destination ou places changent
    useEffect(() => {
        const { depart, destination, places_disponibles, vehicule_id } = form;
        if (!depart || !destination || !vehicule_id || places_disponibles <= 0) return;

        const vehicule = vehicules.find((v) => v.id === vehicule_id);
        if (!vehicule) return;

        const compute = async () => {
            setCalcul(true);
            try {
                const result = await calculerDistance(depart, destination);
                const cout = calculerCoutTotal(result.distance_km, vehicule.type_vehicule);
                const prix = calculerPrixParPlace(cout, places_disponibles);
                setForm((prev) => ({
                    ...prev,
                    distance_km: result.distance_km,
                    cout_total: cout,
                    prix_par_place: prix,
                }));
            } catch {
                setError("Impossible de calculer la distance. Vérifiez les lieux.");
            } finally {
                setCalcul(false);
            }
        };
        compute();
    }, [form.depart, form.destination, form.places_disponibles, form.vehicule_id]);

    const toggleJour = (jour: string) => {
        const jours = form.jours_semaine.includes(jour)
            ? form.jours_semaine.filter((j) => j !== jour)
            : [...form.jours_semaine, jour];
        set("jours_semaine", jours);
    };

    const validerEtape1 = () => {
        if (!form.vehicule_id) return setError("Sélectionnez un véhicule.");
        if (!form.depart) return setError("Sélectionnez un lieu de départ.");
        if (!form.destination) return setError("Sélectionnez une destination.");
        if (form.places_disponibles <= 0) return setError("Indiquez le nombre de places disponibles.");
        if (form.distance_km === 0) return setError("Calcul de distance en cours...");
        setError(null);
        setStep(2);
    };

    const validerEtape2 = () => {
        if (!form.date_heure_depart) return setError("Sélectionnez une date de départ.");
        if (form.est_regulier && form.jours_semaine.length === 0)
            return setError("Sélectionnez au moins un jour pour un trajet régulier.");
        setError(null);
        setStep(3);
    };

    const handleSubmit = async () => {
        setLoading(true);
        setError(null);
        try {
            const trajet = await creerTrajet({
                vehicule_id: form.vehicule_id!,
                depart: form.depart!.nom,
                depart_lat: form.depart!.lat,
                depart_lng: form.depart!.lng,
                destination: form.destination!.nom,
                destination_lat: form.destination!.lat,
                destination_lng: form.destination!.lng,
                distance_km: form.distance_km,
                cout_total: form.cout_total,
                prix_par_place: form.prix_par_place,
                date_heure_depart: new Date(form.date_heure_depart).toISOString(),
                places_disponibles: form.places_disponibles,
                description: form.description,
                est_regulier: form.est_regulier,
                jours_semaine: form.est_regulier ? form.jours_semaine : null,
            });
            // Créer les escales si définies
            if (trajet?.id && escales.length > 0) {
                await Promise.all(escales.map((e) => ajouterEscale(trajet.id, e)));
            }
            router.push("/conducteur/trajets");
        } catch (err: any) {
            const errors = err.response?.data;
            if (errors && typeof errors === "object") {
                setError(Object.entries(errors).map(([k, v]) => `${k} : ${v}`).join(" | "));
            } else {
                setError("Erreur lors de la création du trajet.");
            }
        } finally {
            setLoading(false);
        }
    };

    // Garde — retourné après tous les hooks
    if (!verifLoading && !isActive) {
        const driverStatus = verifStatus?.status ?? "DOCUMENTS_MISSING";
        const isPending = driverStatus === "PENDING_AI_REVIEW" || driverStatus === "PENDING_ADMIN_REVIEW" || driverStatus === "AI_APPROVED";

        return (
            <div className="max-w-lg mx-auto py-16 text-center space-y-6">
                <div className="text-6xl">{isPending ? "⏳" : "🔒"}</div>
                <h1 className="text-2xl font-bold text-base-content">
                    {isPending ? "Vérification en cours" : "Compte non activé"}
                </h1>
                <p className="text-base-content/60 text-sm leading-relaxed">
                    {isPending
                        ? "Votre dossier est en cours de vérification. Vous pourrez proposer des trajets dès que votre compte sera validé."
                        : "Vous devez activer votre compte conducteur avant de pouvoir proposer des trajets. Envoyez vos documents pour commencer."}
                </p>
                <div className="flex flex-col sm:flex-row gap-3 justify-center">
                    <Link href="/conducteur/verification" className="btn btn-warning rounded-full px-8">
                        {isPending ? "Voir le statut" : "Activer mon compte"}
                    </Link>
                    <Link href="/conducteur/dashboard" className="btn btn-ghost rounded-full border border-base-200">
                        Retour au tableau de bord
                    </Link>
                </div>
            </div>
        );
    }

    const steps = ["Itinéraire", "Détails", "Confirmation"];

    return (
        <div className="max-w-2xl mx-auto space-y-8">

            {/* En-tête */}
            <div className="pb-4 border-b border-base-300">
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">Conducteur</p>
                <h1 className="text-2xl font-bold text-base-content tracking-tight">Proposer un trajet</h1>
            </div>

            {/* Indicateur étapes */}
            <div className="flex items-center gap-0">
                {steps.map((label, i) => (
                    <div key={label} className="flex items-center flex-1">
                        <div className="flex flex-col items-center">
                            <div className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-semibold transition-colors ${step > i + 1 ? "bg-success text-success-content"
                                    : step === i + 1 ? "bg-primary text-primary-content"
                                        : "bg-base-200 text-base-content/40"
                                }`}>
                                {step > i + 1 ? "✓" : i + 1}
                            </div>
                            <span className={`text-xs mt-1 font-medium ${step === i + 1 ? "text-base-content" : "text-base-content/40"}`}>
                                {label}
                            </span>
                        </div>
                        {i < steps.length - 1 && (
                            <div className={`flex-1 h-px mx-2 mb-4 transition-colors ${step > i + 1 ? "bg-success" : "bg-base-200"}`} />
                        )}
                    </div>
                ))}
            </div>

            {/* Erreur */}
            {error && (
                <div className="bg-error/10 border border-error/20 rounded-xl px-4 py-3">
                    <p className="text-sm text-error">{error}</p>
                </div>
            )}

            {/* ── ÉTAPE 1 — Itinéraire ── */}
            {step === 1 && (
                <div className="space-y-6">

                    {/* Sélection véhicule */}
                    <div className="bg-base-100 rounded-2xl border border-base-200 p-6 space-y-4">
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                            Véhicule utilisé
                        </p>

                        {loadingVehicules ? (
                            <div className="flex items-center gap-2">
                                <span className="loading loading-spinner loading-sm" />
                                <span className="text-sm text-base-content/40">Chargement...</span>
                            </div>
                        ) : vehicules.length === 0 ? (
                            <div className="text-center py-4 space-y-2">
                                <p className="text-sm text-base-content/40">Aucun véhicule enregistré.</p>
                                <a href="/conducteur/profil" className="btn btn-sm btn-primary rounded-full">
                                    Ajouter un véhicule
                                </a>
                            </div>
                        ) : (
                            <div className="flex flex-col gap-2">
                                {vehicules.map((v) => (
                                    <button
                                        key={v.id}
                                        type="button"
                                        onClick={() => {
                                            set("vehicule_id", v.id);
                                            // Réinitialiser les places quand on change de véhicule
                                            set("places_disponibles", 0);
                                        }}
                                        className={`flex items-center justify-between px-4 py-3 rounded-xl border transition-all text-left ${form.vehicule_id === v.id
                                                ? "border-primary bg-primary/5"
                                                : "border-base-200 hover:border-base-300"
                                            }`}
                                    >
                                        <div>
                                            <p className="font-semibold text-sm text-base-content">
                                                {v.marque} {v.modele}
                                                <span className="text-base-content/40 font-normal ml-2 capitalize">({v.type_vehicule})</span>
                                            </p>
                                            <p className="text-xs text-base-content/40 mt-0.5">
                                                {v.couleur} · {v.plaque} · max {v.places_max} place{v.places_max > 1 ? "s" : ""}
                                            </p>
                                        </div>
                                        {form.vehicule_id === v.id && (
                                            <div className="w-5 h-5 rounded-full bg-primary flex items-center justify-center shrink-0">
                                                <svg xmlns="http://www.w3.org/2000/svg" className="h-3 w-3 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
                                                </svg>
                                            </div>
                                        )}
                                    </button>
                                ))}
                            </div>
                        )}
                    </div>

                    {/* Lieux */}
                    <div className="bg-base-100 rounded-2xl border border-base-200 p-6 space-y-4">
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                            Itinéraire
                        </p>
                        <AutocompleteInput
                            label="Lieu de départ"
                            placeholder="Quartier, adresse, point de repère..."
                            value={form.depart}
                            onSelect={(lieu) => set("depart", lieu)}
                            onClear={() => set("depart", null)}
                        />
                        <AutocompleteInput
                            label="Destination"
                            placeholder="Quartier, adresse, point de repère..."
                            value={form.destination}
                            onSelect={(lieu) => set("destination", lieu)}
                            onClear={() => set("destination", null)}
                        />
                    </div>

                    {/* Places disponibles */}
                    {vehiculeSelectionne && (
                        <div className="bg-base-100 rounded-2xl border border-base-200 p-6 space-y-3">
                            <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                                Places disponibles pour ce trajet
                            </p>
                            <p className="text-sm text-base-content/50">
                                Votre {vehiculeSelectionne.marque} {vehiculeSelectionne.modele} a {vehiculeSelectionne.places_max} place{vehiculeSelectionne.places_max > 1 ? "s" : ""} au total.
                                Combien proposez-vous pour ce trajet ?
                                <span className="text-base-content/30 ml-1">(ex: 3 si 2 places sont pour votre famille)</span>
                            </p>
                            <div className="flex gap-2 flex-wrap">
                                {Array.from({ length: vehiculeSelectionne.places_max }, (_, i) => i + 1).map((n) => (
                                    <button
                                        key={n}
                                        type="button"
                                        onClick={() => set("places_disponibles", n)}
                                        className={`btn btn-sm rounded-full w-12 ${form.places_disponibles === n ? "btn-primary" : "btn-outline"
                                            }`}
                                    >
                                        {n}
                                    </button>
                                ))}
                            </div>
                            {form.places_disponibles > 0 && (
                                <p className="text-xs text-base-content/40">
                                    {form.places_disponibles} place{form.places_disponibles > 1 ? "s" : ""} proposée{form.places_disponibles > 1 ? "s" : ""} sur {vehiculeSelectionne.places_max}
                                </p>
                            )}
                        </div>
                    )}

                    {/* Carte */}
                    {(form.depart || form.destination) && (
                        <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                            <div className="px-6 py-4 border-b border-base-200">
                                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">Aperçu du trajet</p>
                            </div>
                            <div className="h-64">
                                <MapView depart={form.depart} destination={form.destination} />
                            </div>
                        </div>
                    )}

                    {/* Estimation prix */}
                    {form.depart && form.destination && form.places_disponibles > 0 && (
                        <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
                            <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-4">
                                Estimation automatique
                            </p>
                            {calcul ? (
                                <div className="flex items-center gap-3">
                                    <span className="loading loading-spinner loading-sm" />
                                    <span className="text-sm text-base-content/60">Calcul en cours...</span>
                                </div>
                            ) : (
                                <div className="grid grid-cols-3 gap-4">
                                    <div>
                                        <p className="text-2xl font-bold text-base-content">{form.distance_km} km</p>
                                        <p className="text-xs text-base-content/40 mt-0.5">Distance</p>
                                    </div>
                                    <div>
                                        <p className="text-2xl font-bold text-primary">
                                            {form.prix_par_place.toLocaleString("fr-FR")} FCFA
                                        </p>
                                        <p className="text-xs text-base-content/40 mt-0.5">Prix / place</p>
                                    </div>
                                    <div>
                                        <p className="text-2xl font-bold text-base-content">{form.places_disponibles}</p>
                                        <p className="text-xs text-base-content/40 mt-0.5">Places proposées</p>
                                    </div>
                                </div>
                            )}
                            {!calcul && form.cout_total > 0 && (
                                <p className="text-xs text-base-content/30 mt-3">
                                    Coût total : {form.cout_total.toLocaleString("fr-FR")} FCFA
                                    · dont {Math.round(form.cout_total / 11).toLocaleString("fr-FR")} FCFA commission KoVoit (10%)
                                </p>
                            )}
                        </div>
                    )}

                    <button
                        type="button"
                        onClick={validerEtape1}
                        disabled={!form.vehicule_id || !form.depart || !form.destination || form.places_disponibles <= 0 || calcul}
                        className="btn btn-primary w-full rounded-full"
                    >
                        Continuer
                    </button>
                </div>
            )}

            {/* ── ÉTAPE 2 — Détails ── */}
            {step === 2 && (
                <div className="space-y-6">
                    <div className="bg-base-100 rounded-2xl border border-base-200 p-6 space-y-5">
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">Date & heure</p>

                        <div className="form-control">
                            <label className="label">
                                <span className="label-text font-medium text-sm">Date et heure de départ</span>
                            </label>
                            <input
                                type="datetime-local"
                                className="input input-bordered rounded-xl w-full"
                                value={form.date_heure_depart}
                                min={new Date().toISOString().slice(0, 16)}
                                onChange={(e) => set("date_heure_depart", e.target.value)}
                            />
                        </div>

                        <div className="divider text-xs text-base-content/40">Fréquence</div>

                        <div className="grid grid-cols-2 gap-3">
                            {[{ value: false, label: "Trajet unique" }, { value: true, label: "Trajet régulier" }].map((opt) => (
                                <button key={String(opt.value)} type="button"
                                    onClick={() => set("est_regulier", opt.value)}
                                    className={`btn rounded-xl ${form.est_regulier === opt.value ? "btn-primary" : "btn-outline"}`}>
                                    {opt.label}
                                </button>
                            ))}
                        </div>

                        {form.est_regulier && (
                            <div className="space-y-2">
                                <p className="text-sm font-medium text-base-content/60">Jours de la semaine</p>
                                <div className="flex flex-wrap gap-2">
                                    {JOURS.map((jour) => (
                                        <button key={jour} type="button" onClick={() => toggleJour(jour)}
                                            className={`btn btn-sm rounded-full capitalize ${form.jours_semaine.includes(jour) ? "btn-primary" : "btn-outline"}`}>
                                            {jour.slice(0, 3)}
                                        </button>
                                    ))}
                                </div>
                            </div>
                        )}

                        <div className="divider text-xs text-base-content/40">Description</div>

                        <div className="form-control">
                            <label className="label">
                                <span className="label-text font-medium text-sm">
                                    Description
                                    <span className="label-text-alt ml-1 text-base-content/40">(optionnel)</span>
                                </span>
                            </label>
                            <textarea
                                className="textarea textarea-bordered rounded-xl w-full resize-none"
                                rows={3}
                                placeholder="Point de rendez-vous précis, bagages acceptés, remarques..."
                                value={form.description}
                                onChange={(e) => set("description", e.target.value)}
                            />
                        </div>
                    </div>

                    {/* Escales optionnelles */}
                    <div className="bg-base-100 rounded-2xl border border-base-200 p-6 space-y-4">
                        <div className="flex items-center justify-between">
                            <div>
                                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                                    Escales
                                    <span className="ml-2 text-base-content/30 normal-case font-normal">(optionnel)</span>
                                </p>
                                <p className="text-xs text-base-content/30 mt-0.5">
                                    Arrêts intermédiaires où vous pouvez prendre des passagers
                                </p>
                            </div>
                            <button
                                type="button"
                                onClick={() => setNouvelleEscale({ nom: "", lat: null, lng: null })}
                                className="btn btn-sm btn-outline rounded-full"
                            >
                                + Ajouter
                            </button>
                        </div>

                        {/* Liste des escales ajoutées */}
                        {escales.length > 0 && (
                            <div className="space-y-2">
                                {escales.map((e, i) => (
                                    <div key={i} className="flex items-center justify-between bg-base-200/50 rounded-xl px-4 py-2.5 gap-3">
                                        <div className="flex items-center gap-2 min-w-0">
                                            <div className="w-5 h-5 rounded-full bg-primary/15 flex items-center justify-center shrink-0">
                                                <span className="text-xs font-bold text-primary">{i + 1}</span>
                                            </div>
                                            <p className="text-sm font-medium text-base-content truncate">{e.nom}</p>
                                        </div>
                                        <button
                                            type="button"
                                            onClick={() => setEscales((prev) => prev.filter((_, idx) => idx !== i))}
                                            className="btn btn-ghost btn-xs text-error hover:text-error"
                                        >
                                            ×
                                        </button>
                                    </div>
                                ))}
                            </div>
                        )}

                        {/* Formulaire ajout escale */}
                        {nouvelleEscale !== null && (
                            <div className="bg-base-200/40 rounded-xl p-4 space-y-3">
                                <AutocompleteInput
                                    label="Nom de l'escale"
                                    placeholder="Ville, carrefour, point de repère..."
                                    value={nouvelleEscale.lat ? { nom: nouvelleEscale.nom, lat: nouvelleEscale.lat, lng: nouvelleEscale.lng! } : null}
                                    onSelect={(lieu) => setNouvelleEscale({ nom: lieu.nom, lat: lieu.lat, lng: lieu.lng })}
                                    onClear={() => setNouvelleEscale({ nom: "", lat: null, lng: null })}
                                />
                                <div className="flex gap-2">
                                    <button
                                        type="button"
                                        onClick={() => setNouvelleEscale(null)}
                                        className="btn btn-ghost btn-sm rounded-full"
                                    >
                                        Annuler
                                    </button>
                                    <button
                                        type="button"
                                        disabled={!nouvelleEscale.lat}
                                        onClick={() => {
                                            if (!nouvelleEscale.lat) return;
                                            setEscales((prev) => [...prev, {
                                                nom: nouvelleEscale.nom,
                                                lat: nouvelleEscale.lat!,
                                                lng: nouvelleEscale.lng!,
                                                ordre: prev.length,
                                            }]);
                                            setNouvelleEscale(null);
                                        }}
                                        className="btn btn-primary btn-sm rounded-full flex-1"
                                    >
                                        Ajouter cette escale
                                    </button>
                                </div>
                            </div>
                        )}
                    </div>

                    <div className="flex gap-3">
                        <button type="button" onClick={() => setStep(1)} className="btn btn-outline rounded-full flex-1">Retour</button>
                        <button type="button" onClick={validerEtape2} className="btn btn-primary rounded-full flex-1">Continuer</button>
                    </div>
                </div>
            )}

            {/* ── ÉTAPE 3 — Confirmation ── */}
            {step === 3 && (
                <div className="space-y-6">
                    <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                        <div className="px-6 py-4 border-b border-base-200">
                            <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">Récapitulatif</p>
                        </div>
                        <div className="divide-y divide-base-200">
                            {[
                                { label: "Véhicule", value: vehiculeSelectionne ? `${vehiculeSelectionne.marque} ${vehiculeSelectionne.modele} (${vehiculeSelectionne.plaque})` : "-" },
                                { label: "Départ", value: form.depart?.nom },
                                { label: "Destination", value: form.destination?.nom },
                                { label: "Distance", value: `${form.distance_km} km` },
                                { label: "Places", value: `${form.places_disponibles} place${form.places_disponibles > 1 ? "s" : ""} proposée${form.places_disponibles > 1 ? "s" : ""}` },
                                { label: "Prix / place", value: `${form.prix_par_place.toLocaleString("fr-FR")} FCFA` },
                                {
                                    label: "Date départ", value: new Date(form.date_heure_depart).toLocaleString("fr-FR", {
                                        weekday: "long", day: "numeric", month: "long",
                                        hour: "2-digit", minute: "2-digit"
                                    })
                                },
                                { label: "Fréquence", value: form.est_regulier ? `Régulier — ${form.jours_semaine.join(", ")}` : "Trajet unique" },
                                form.description ? { label: "Description", value: form.description } : null,
                                escales.length > 0 ? { label: "Escales", value: escales.map((e) => e.nom).join(" → ") } : null,
                            ].filter(Boolean).map((item: any) => (
                                <div key={item.label} className="flex justify-between items-start px-6 py-3 gap-4">
                                    <span className="text-xs text-base-content/40 uppercase tracking-wide shrink-0">{item.label}</span>
                                    <span className="text-sm font-medium text-base-content text-right">{item.value}</span>
                                </div>
                            ))}
                        </div>
                        <div className="px-6 py-5 bg-primary/5 border-t border-primary/10">
                            <div className="flex justify-between items-center">
                                <div>
                                    <p className="text-sm font-medium text-base-content/60">Prix fixe par passager</p>
                                    <p className="text-xs text-base-content/30 mt-0.5">
                                        Calculé selon distance + type véhicule + places proposées
                                    </p>
                                </div>
                                <p className="text-2xl font-bold text-primary">
                                    {form.prix_par_place.toLocaleString("fr-FR")} FCFA
                                </p>
                            </div>
                        </div>
                    </div>

                    <div className="flex gap-3">
                        <button type="button" onClick={() => setStep(2)} className="btn btn-outline rounded-full flex-1">Retour</button>
                        <button type="button" onClick={handleSubmit} disabled={loading} className="btn btn-primary rounded-full flex-1">
                            {loading ? <span className="loading loading-spinner loading-sm" /> : "Publier le trajet"}
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
}