"use client";

import { useState, useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
import dynamic from "next/dynamic";
import {
    searchLieu,
    formatNominatimLabel,
    calculerDistance,
    calculerCoutTotal,
    calculerPrixPrevu,
    creerTrajet,
    type NominatimResult,
} from "@/src/services/trajet.service";

// Leaflet chargé côté client uniquement (pas de SSR)
const MapView = dynamic(() => import("@/components/MapView"), { ssr: false });

// ─── Types ────────────────────────────────────────────────────────────────
interface LieuSelectionne {
    nom: string;
    lat: number;
    lng: number;
}

interface FormData {
    depart: LieuSelectionne | null;
    destination: LieuSelectionne | null;
    distance_km: number;
    cout_total: number;
    prix_par_place: number;
    date_heure_depart: string;
    places_disponibles: number;
    description: string;
    est_regulier: boolean;
    jours_semaine: string[];
}

const JOURS = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"];

// ─── Composant Autocomplete ────────────────────────────────────────────────
function AutocompleteInput({
    label,
    placeholder,
    value,
    onSelect,
    onClear,
}: {
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
    const debounceRef = useRef<NodeJS.Timeout>();

    useEffect(() => {
        setQuery(value?.nom || "");
    }, [value]);

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
            } finally {
                setLoading(false);
            }
        }, 400);
    };

    const handleSelect = (result: NominatimResult) => {
        const label = formatNominatimLabel(result);
        setQuery(label);
        setOpen(false);
        onSelect({ nom: label, lat: parseFloat(result.lat), lng: parseFloat(result.lon) });
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
            } finally {
                setLoading(false);
            }
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
                    {loading && (
                        <span className="loading loading-spinner loading-xs absolute right-3 top-1/2 -translate-y-1/2 text-base-content/40" />
                    )}
                    {value && !loading && (
                        <button
                            type="button"
                            onClick={() => { onClear(); setQuery(""); }}
                            className="absolute right-3 top-1/2 -translate-y-1/2 text-base-content/30 hover:text-base-content"
                        >
                            ×
                        </button>
                    )}
                </div>
                <button
                    type="button"
                    onClick={handleGPS}
                    className="btn btn-square btn-outline rounded-xl"
                    title="Ma position actuelle"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                    </svg>
                </button>
            </div>

            {/* Suggestions */}
            {open && results.length > 0 && (
                <ul className="absolute top-full left-0 right-0 z-50 bg-base-100 border border-base-200 rounded-xl shadow-lg mt-1 overflow-hidden">
                    {results.map((r) => (
                        <li
                            key={r.place_id}
                            className="px-4 py-2.5 hover:bg-base-200 cursor-pointer transition-colors"
                            onMouseDown={() => handleSelect(r)}
                        >
                            <p className="text-sm font-medium text-base-content">
                                {formatNominatimLabel(r)}
                            </p>
                            <p className="text-xs text-base-content/40 truncate">
                                {r.display_name}
                            </p>
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
    const [step, setStep] = useState<1 | 2 | 3>(1);
    const [loading, setLoading] = useState(false);
    const [calcul, setCalcul] = useState(false);
    const [error, setError] = useState<string | null>(null);

    const [form, setForm] = useState<FormData>({
        depart: null,
        destination: null,
        distance_km: 0,
        cout_total: 0,
        prix_par_place: 0,
        date_heure_depart: "",
        places_disponibles: 3,
        description: "",
        est_regulier: false,
        jours_semaine: [],
    });

    const set = (field: keyof FormData, value: any) =>
        setForm((prev) => ({ ...prev, [field]: value }));

    // Recalcule distance + coût total + prix prévu
    useEffect(() => {
        const { depart, destination, places_disponibles } = form;
        if (!depart || !destination) return;

        const compute = async () => {
            setCalcul(true);
            try {
                const result = await calculerDistance(depart, destination);
                const cout = calculerCoutTotal(result.distance_km);
                const prix = calculerPrixPrevu(cout, places_disponibles);
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
    }, [form.depart, form.destination, form.places_disponibles]);

    // Toggle jour semaine
    const toggleJour = (jour: string) => {
        const jours = form.jours_semaine.includes(jour)
            ? form.jours_semaine.filter((j) => j !== jour)
            : [...form.jours_semaine, jour];
        set("jours_semaine", jours);
    };

    // Validation étape 1
    const validerEtape1 = () => {
        if (!form.depart) return setError("Sélectionnez un lieu de départ.");
        if (!form.destination) return setError("Sélectionnez un lieu d'arrivée.");
        if (form.distance_km === 0) return setError("Calcul de distance en cours...");
        setError(null);
        setStep(2);
    };

    // Validation étape 2
    const validerEtape2 = () => {
        if (!form.date_heure_depart) return setError("Sélectionnez une date de départ.");
        if (form.est_regulier && form.jours_semaine.length === 0)
            return setError("Sélectionnez au moins un jour pour un trajet régulier.");
        setError(null);
        setStep(3);
    };

    // Soumission finale
    const handleSubmit = async () => {
        setLoading(true);
        setError(null);
        try {
            await creerTrajet({
                depart: form.depart!.nom,
                depart_lat: form.depart!.lat,
                depart_lng: form.depart!.lng,
                destination: form.destination!.nom,
                destination_lat: form.destination!.lat,
                destination_lng: form.destination!.lng,
                cout_total: form.cout_total,
                prix_par_place: form.prix_par_place,
                date_heure_depart: new Date(form.date_heure_depart).toISOString(),
                places_disponibles: form.places_disponibles,
                description: form.description,
            });
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

    const steps = ["Itinéraire", "Détails", "Confirmation"];

    return (
        <div className="max-w-2xl mx-auto space-y-8">

            {/* En-tête */}
            <div className="pb-4 border-b border-base-300">
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">
                    Conducteur
                </p>
                <h1 className="text-2xl font-bold text-base-content tracking-tight">
                    Proposer un trajet
                </h1>
            </div>

            {/* Indicateur étapes */}
            <div className="flex items-center gap-0">
                {steps.map((label, i) => (
                    <div key={label} className="flex items-center flex-1">
                        <div className="flex flex-col items-center">
                            <div className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-semibold transition-colors ${step > i + 1
                                    ? "bg-success text-success-content"
                                    : step === i + 1
                                        ? "bg-primary text-primary-content"
                                        : "bg-base-200 text-base-content/40"
                                }`}>
                                {step > i + 1 ? "✓" : i + 1}
                            </div>
                            <span className={`text-xs mt-1 font-medium ${step === i + 1 ? "text-base-content" : "text-base-content/40"
                                }`}>
                                {label}
                            </span>
                        </div>
                        {i < steps.length - 1 && (
                            <div className={`flex-1 h-px mx-2 mb-4 transition-colors ${step > i + 1 ? "bg-success" : "bg-base-200"
                                }`} />
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

            {/* ── ÉTAPE 1 — Itinéraire ─────────────────────────────── */}
            {step === 1 && (
                <div className="space-y-6">
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

                    {/* Carte Leaflet */}
                    {(form.depart || form.destination) && (
                        <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                            <div className="px-6 py-4 border-b border-base-200">
                                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                                    Aperçu du trajet
                                </p>
                            </div>
                            <div className="h-64">
                                <MapView
                                    depart={form.depart}
                                    destination={form.destination}
                                />
                            </div>
                        </div>
                    )}

                    {/* Estimation */}
                    {form.depart && form.destination && (
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
                                        <p className="text-xs text-base-content/40 mt-0.5">Prix estimé / place</p>
                                    </div>
                                    <div className="form-control">
                                        <label className="label py-0">
                                            <span className="text-xs text-base-content/40 uppercase tracking-widest">
                                                Places
                                            </span>
                                        </label>
                                        <input
                                            type="number"
                                            min={1}
                                            max={8}
                                            value={form.places_disponibles}
                                            onChange={(e) => {
                                                const val = parseInt(e.target.value);
                                                if (!isNaN(val)) set("places_disponibles", val);
                                            }}
                                            className="input input-bordered input-sm rounded-xl w-full"
                                        />
                                    </div>
                                </div>
                            )}
                            {!calcul && form.cout_total > 0 && (
                                <p className="text-xs text-base-content/30 mt-3">
                                    Coût total : {form.cout_total.toLocaleString("fr-FR")} FCFA
                                    (dont {Math.round(form.cout_total * 0.10 / 1.10).toLocaleString("fr-FR")} FCFA commission KoVoit)
                                </p>
                            )}
                        </div>
                    )}

                    <button
                        type="button"
                        onClick={validerEtape1}
                        disabled={!form.depart || !form.destination || calcul}
                        className="btn btn-primary w-full rounded-full"
                    >
                        Continuer
                    </button>
                </div>
            )}

            {/* ── ÉTAPE 2 — Détails ────────────────────────────────── */}
            {step === 2 && (
                <div className="space-y-6">
                    <div className="bg-base-100 rounded-2xl border border-base-200 p-6 space-y-5">
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                            Date & heure
                        </p>

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
                            {[
                                { value: false, label: "Trajet unique" },
                                { value: true, label: "Trajet régulier" },
                            ].map((opt) => (
                                <button
                                    key={String(opt.value)}
                                    type="button"
                                    onClick={() => set("est_regulier", opt.value)}
                                    className={`btn rounded-xl ${form.est_regulier === opt.value ? "btn-primary" : "btn-outline"
                                        }`}
                                >
                                    {opt.label}
                                </button>
                            ))}
                        </div>

                        {form.est_regulier && (
                            <div className="space-y-2">
                                <p className="text-sm font-medium text-base-content/60">
                                    Jours de la semaine
                                </p>
                                <div className="flex flex-wrap gap-2">
                                    {JOURS.map((jour) => (
                                        <button
                                            key={jour}
                                            type="button"
                                            onClick={() => toggleJour(jour)}
                                            className={`btn btn-sm rounded-full capitalize ${form.jours_semaine.includes(jour) ? "btn-primary" : "btn-outline"
                                                }`}
                                        >
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

                    <div className="flex gap-3">
                        <button type="button" onClick={() => setStep(1)} className="btn btn-outline rounded-full flex-1">
                            Retour
                        </button>
                        <button type="button" onClick={validerEtape2} className="btn btn-primary rounded-full flex-1">
                            Continuer
                        </button>
                    </div>
                </div>
            )}

            {/* ── ÉTAPE 3 — Confirmation ───────────────────────────── */}
            {step === 3 && (
                <div className="space-y-6">
                    <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                        <div className="px-6 py-4 border-b border-base-200">
                            <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                                Récapitulatif
                            </p>
                        </div>
                        <div className="divide-y divide-base-200">
                            {[
                                { label: "Départ", value: form.depart?.nom },
                                { label: "Destination", value: form.destination?.nom },
                                { label: "Distance", value: `${form.distance_km} km` },
                                { label: "Prix estimé", value: `${form.prix_par_place.toLocaleString("fr-FR")} FCFA / place` },
                                {
                                    label: "Date départ", value: new Date(form.date_heure_depart).toLocaleString("fr-FR", {
                                        weekday: "long", day: "numeric", month: "long",
                                        hour: "2-digit", minute: "2-digit"
                                    })
                                },
                                { label: "Places", value: `${form.places_disponibles} places` },
                                {
                                    label: "Fréquence", value: form.est_regulier
                                        ? `Régulier — ${form.jours_semaine.join(", ")}`
                                        : "Trajet unique"
                                },
                                form.description
                                    ? { label: "Description", value: form.description }
                                    : null,
                            ].filter(Boolean).map((item: any) => (
                                <div key={item.label} className="flex justify-between items-start px-6 py-3 gap-4">
                                    <span className="text-xs text-base-content/40 uppercase tracking-wide shrink-0">
                                        {item.label}
                                    </span>
                                    <span className="text-sm font-medium text-base-content text-right">
                                        {item.value}
                                    </span>
                                </div>
                            ))}
                        </div>

                        {/* Prix mis en avant */}
                        <div className="px-6 py-5 bg-primary/5 border-t border-primary/10">
                            <div className="flex justify-between items-center">
                                <div>
                                    <p className="text-sm font-medium text-base-content/60">
                                        Prix estimé par passager
                                    </p>
                                    <p className="text-xs text-base-content/30 mt-0.5">
                                        Recalculé à chaque nouvelle réservation confirmée
                                    </p>
                                </div>
                                <p className="text-2xl font-bold text-primary">
                                    {form.prix_par_place.toLocaleString("fr-FR")} FCFA
                                </p>
                            </div>
                        </div>
                    </div>

                    <div className="flex gap-3">
                        <button type="button" onClick={() => setStep(2)} className="btn btn-outline rounded-full flex-1">
                            Retour
                        </button>
                        <button
                            type="button"
                            onClick={handleSubmit}
                            disabled={loading}
                            className="btn btn-primary rounded-full flex-1"
                        >
                            {loading
                                ? <span className="loading loading-spinner loading-sm" />
                                : "Publier le trajet"
                            }
                        </button>
                    </div>
                </div>
            )}

        </div>
    );
}