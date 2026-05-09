"use client";

import { useState, useEffect, useRef } from "react";
import { useParams, useRouter } from "next/navigation";
import dynamic from "next/dynamic";
import {
    searchLieu,
    formatNominatimLabel,
    calculerDistance,
    calculerCoutTotal,
    calculerPrixParPlace,
    mesVehicules,
    getTrajet,
    modifierTrajet,
    type NominatimResult,
    type Vehicule,
    type Trajet,
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
    places_disponibles: number;
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
    const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

    useEffect(() => { setQuery(value?.nom || ""); }, [value]);

    const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        const q = e.target.value;
        setQuery(q);
        if (value) onClear();
        if (debounceRef.current) clearTimeout(debounceRef.current);
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

export default function EditTrajetPage() {
    const params = useParams();
    const router = useRouter();
    const trajetId = params.id as string;

    const [loading, setLoading] = useState(false);
    const [saving, setSaving] = useState(false);
    const [calcul, setCalcul] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [trajetOriginal, setTrajetOriginal] = useState<Trajet | null>(null);
    const [vehicules, setVehicules] = useState<Vehicule[]>([]);
    const [loadingVehicules, setLoadingVehicules] = useState(true);

    const [form, setForm] = useState<FormData>({
        vehicule_id: null,
        depart: null,
        destination: null,
        distance_km: 0,
        cout_total: 0,
        prix_par_place: 0,
        places_disponibles: 0,
        date_heure_depart: "",
        description: "",
        est_regulier: false,
        jours_semaine: [],
    });

    const set = (field: keyof FormData, value: any) =>
        setForm((prev) => ({ ...prev, [field]: value }));

    // Charger le trajet et les véhicules
    useEffect(() => {
        const loadData = async () => {
            try {
                const [trajetData, vehiculesData] = await Promise.all([
                    getTrajet(Number(trajetId)),
                    mesVehicules(),
                ]);

                setTrajetOriginal(trajetData);
                setVehicules(Array.isArray(vehiculesData) ? vehiculesData.filter((v: Vehicule) => v.est_actif) : []);

                // Pré-remplir le formulaire
                setForm({
                    vehicule_id: trajetData.vehicule,
                    depart: {
                        nom: trajetData.depart,
                        lat: trajetData.depart_lat,
                        lng: trajetData.depart_lng,
                    },
                    destination: {
                        nom: trajetData.destination,
                        lat: trajetData.destination_lat,
                        lng: trajetData.destination_lng,
                    },
                    distance_km: trajetData.distance_km || 0,
                    cout_total: trajetData.cout_total || 0,
                    prix_par_place: trajetData.prix_par_place || 0,
                    places_disponibles: trajetData.places_disponibles,
                    date_heure_depart: trajetData.date_heure_depart,
                    description: trajetData.description || "",
                    est_regulier: trajetData.est_regulier || false,
                    jours_semaine: trajetData.jours_semaine || [],
                });
            } catch (err: any) {
                setError(err.response?.data?.error || "Impossible de charger le trajet");
            } finally {
                setLoading(false);
                setLoadingVehicules(false);
            }
        };

        if (trajetId) {
            loadData();
        }
    }, [trajetId]);

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
    }, [form.depart, form.destination, form.places_disponibles, form.vehicule_id, vehicules]);

    const toggleJour = (jour: string) => {
        const jours = form.jours_semaine.includes(jour)
            ? form.jours_semaine.filter((j) => j !== jour)
            : [...form.jours_semaine, jour];
        set("jours_semaine", jours);
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();

        if (!form.vehicule_id) return setError("Sélectionnez un véhicule.");
        if (!form.depart) return setError("Sélectionnez un lieu de départ.");
        if (!form.destination) return setError("Sélectionnez une destination.");
        if (form.places_disponibles <= 0) return setError("Indiquez le nombre de places disponibles.");
        if (!form.date_heure_depart) return setError("Sélectionnez une date de départ.");
        if (form.est_regulier && form.jours_semaine.length === 0)
            return setError("Sélectionnez au moins un jour pour un trajet régulier.");

        setSaving(true);
        setError(null);
        try {
            await modifierTrajet(Number(trajetId), {
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
                places_disponibles: form.places_disponibles,
                date_heure_depart: new Date(form.date_heure_depart).toISOString(),
                description: form.description,
                est_regulier: form.est_regulier,
                jours_semaine: form.est_regulier ? form.jours_semaine : null,
            });
            router.push(`/conducteur/trajets/${trajetId}`);
        } catch (err: any) {
            const errors = err.response?.data;
            if (errors && typeof errors === "object") {
                setError(Object.entries(errors).map(([k, v]) => `${k} : ${v}`).join(" | "));
            } else {
                setError("Erreur lors de la modification du trajet.");
            }
        } finally {
            setSaving(false);
        }
    };

    if (loading) {
        return (
            <div className="max-w-2xl mx-auto py-8">
                <div className="space-y-6 animate-pulse">
                    <div className="h-8 bg-base-300 rounded w-1/3" />
                    <div className="h-64 bg-base-300 rounded-2xl" />
                    <div className="space-y-4">
                        <div className="h-12 bg-base-300 rounded-xl" />
                        <div className="h-12 bg-base-300 rounded-xl" />
                        <div className="h-12 bg-base-300 rounded-xl" />
                    </div>
                </div>
            </div>
        );
    }

    if (error && !trajetOriginal) {
        return (
            <div className="max-w-lg mx-auto py-16 text-center">
                <p className="text-base-content/40">{error}</p>
                <button onClick={() => router.back()} className="btn btn-ghost btn-sm rounded-full mt-4">
                    Retour
                </button>
            </div>
        );
    }

    return (
        <div className="max-w-2xl mx-auto py-8 space-y-6">
            {/* EN-TÊTE */}
            <div className="flex items-center gap-3 pb-4 border-b border-base-300">
                <button
                    onClick={() => router.back()}
                    className="btn btn-ghost btn-sm btn-square rounded-xl"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
                    </svg>
                </button>
                <div>
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                        Modifier le trajet
                    </p>
                    <h1 className="text-xl font-bold text-base-content tracking-tight">
                        {trajetOriginal?.depart} → {trajetOriginal?.destination}
                    </h1>
                </div>
            </div>

            {/* FORMULAIRE */}
            <form onSubmit={handleSubmit} className="space-y-6">
                {/* CARTE */}
                {form.depart && form.destination && (
                    <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                        <div className="h-52">
                            <MapView
                                depart={{ nom: form.depart.nom, lat: form.depart.lat, lng: form.depart.lng }}
                                destination={{ nom: form.destination.nom, lat: form.destination.lat, lng: form.destination.lng }}
                            />
                        </div>
                    </div>
                )}

                {/* VÉHICULE */}
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
                                        if (form.places_disponibles > v.places_max) {
                                            set("places_disponibles", v.places_max);
                                        }
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

                {/* LIEUX */}
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

                {/* PLACES ET INFOS */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    {/* Places disponibles */}
                    {vehiculeSelectionne && (
                        <div className="bg-base-100 rounded-2xl border border-base-200 p-6 space-y-3">
                            <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                                Places disponibles
                            </p>
                            <p className="text-sm text-base-content/50">
                                Max {vehiculeSelectionne.places_max} place{vehiculeSelectionne.places_max > 1 ? "s" : ""}
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
                        </div>
                    )}

                    {/* Date et heure */}
                    <div className="bg-base-100 rounded-2xl border border-base-200 p-6 space-y-3">
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                            Date et heure
                        </p>
                        <input
                            type="datetime-local"
                            value={form.date_heure_depart}
                            onChange={(e) => set("date_heure_depart", e.target.value)}
                            className="input input-bordered w-full rounded-xl"
                            min={new Date().toISOString().slice(0, 16)}
                            required
                        />
                    </div>
                </div>

                {/* FRÉQUENCE ET DESCRIPTION */}
                <div className="bg-base-100 rounded-2xl border border-base-200 p-6 space-y-5">
                    <div>
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-3">
                            Fréquence
                        </p>
                        <div className="grid grid-cols-2 gap-3">
                            {[{ value: false, label: "Trajet unique" }, { value: true, label: "Trajet régulier" }].map((opt) => (
                                <button key={String(opt.value)} type="button"
                                    onClick={() => set("est_regulier", opt.value)}
                                    className={`btn rounded-xl ${form.est_regulier === opt.value ? "btn-primary" : "btn-outline"}`}>
                                    {opt.label}
                                </button>
                            ))}
                        </div>
                    </div>

                    {form.est_regulier && (
                        <div>
                            <p className="text-sm font-medium text-base-content/60 mb-2">Jours de la semaine</p>
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

                    <div>
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-2">
                            Description
                        </p>
                        <textarea
                            value={form.description}
                            onChange={(e) => set("description", e.target.value)}
                            placeholder="Point de rendez-vous précis, bagages acceptés, remarques..."
                            className="textarea textarea-bordered w-full rounded-xl resize-none"
                            rows={3}
                        />
                    </div>
                </div>

                {/* RÉSUMÉ */}
                <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
                    <h3 className="text-sm font-medium text-base-content/60 uppercase tracking-wider mb-4">
                        Résumé du trajet
                    </h3>
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
                            <p className="text-xs text-base-content/40 mt-0.5">Places</p>
                        </div>
                    </div>
                    {!calcul && form.cout_total > 0 && (
                        <p className="text-xs text-base-content/30 mt-3">
                            Coût total : {form.cout_total.toLocaleString("fr-FR")} FCFA
                            · dont {Math.round(form.cout_total / 11).toLocaleString("fr-FR")} FCFA commission KoVoit (10%)
                        </p>
                    )}
                </div>

                {/* ERREUR */}
                {error && (
                    <div className="bg-error/10 border border-error/20 rounded-xl px-4 py-3">
                        <p className="text-sm text-error">{error}</p>
                    </div>
                )}

                {/* BOUTONS */}
                <div className="flex gap-3">
                    <button
                        type="button"
                        onClick={() => router.back()}
                        className="btn btn-ghost rounded-full border border-base-300 flex-1"
                    >
                        Annuler
                    </button>
                    <button
                        type="submit"
                        disabled={saving || !form.vehicule_id || !form.depart || !form.destination || form.places_disponibles <= 0 || !form.date_heure_depart || calcul}
                        className="btn btn-primary flex-1 rounded-full"
                    >
                        {saving ? <span className="loading loading-spinner loading-sm" /> : "Enregistrer les modifications"}
                    </button>
                </div>
            </form>
        </div>
    );
}
