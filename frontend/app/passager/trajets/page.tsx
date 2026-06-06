"use client";

import { useState, useEffect, useRef, useMemo } from "react";
import { useRouter } from "next/navigation";
import dynamic from "next/dynamic";
import {
    searchLieu,
    formatNominatimLabel,
    rechercherTrajets,
    type NominatimResult,
    type Trajet,
} from "@/src/services/trajet.service";

const MapRecherche = dynamic(() => import("@/components/MapRecherche"), { ssr: false });

interface LieuSelectionne {
    nom: string;
    lat: number;
    lng: number;
}

type TriOption = "pertinence" | "prix_asc" | "prix_desc" | "date" | "places";

// ─── Autocomplete lieu ────────────────────────────────────────────────────
function AutocompleteInput({
    placeholder, value, onSelect, onClear,
}: {
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
        <div className="relative">
            <div className="flex gap-2">
                <div className="relative flex-1">
                    <input
                        type="text"
                        value={query}
                        onChange={handleChange}
                        placeholder={placeholder}
                        className={`input input-bordered input-sm w-full rounded-xl bg-white/10 border-white/20 text-white placeholder-white/50 focus:bg-white focus:text-base-content focus:placeholder-base-content/40 transition-all pr-8 ${value ? "bg-white/20 border-white/40" : ""
                            }`}
                    />
                    {loading && (
                        <span className="loading loading-spinner loading-xs absolute right-3 top-1/2 -translate-y-1/2 text-white/60" />
                    )}
                    {value && !loading && (
                        <button type="button" onClick={() => { onClear(); setQuery(""); }}
                            className="absolute right-3 top-1/2 -translate-y-1/2 text-white/60 hover:text-white">
                            ×
                        </button>
                    )}
                </div>
                <button
                    type="button"
                    onClick={handleGPS}
                    className="btn btn-sm btn-square rounded-xl bg-white/10 border-white/20 text-white hover:bg-white/20"
                    title="Ma position actuelle"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                    </svg>
                </button>
            </div>

            {open && results.length > 0 && (
                <ul className="absolute top-full left-0 right-0 z-50 bg-base-100 border border-base-200 rounded-xl shadow-xl mt-1 overflow-hidden">
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
export default function RechercherTrajetPage() {
    const router = useRouter();

    // Filtres — tous vides par défaut, rien de présélectionné
    const [depart, setDepart] = useState<LieuSelectionne | null>(null);
    const [destination, setDestination] = useState<LieuSelectionne | null>(null);
    const [date, setDate] = useState("");
    const [placesInput, setPlacesInput] = useState("");   // texte libre, pas de valeur par défaut
    const [typeVehicule, setTypeVehicule] = useState("");
    const [tri, setTri] = useState<TriOption>("date");

    const [tousLesTrajets, setTousLesTrajets] = useState<Trajet[]>([]);
    const [loading, setLoading] = useState(true);
    const [trajetSurvole, setTrajetSurvole] = useState<Trajet | null>(null);

    const TYPES = ["", "voiture", "moto", "minibus", "camion"];
    const TYPES_LABELS: Record<string, string> = {
        "": "Tous", voiture: "Voiture", moto: "Moto", minibus: "Minibus", camion: "Camion",
    };

    const TRI_OPTIONS: { value: TriOption; label: string }[] = [
        { value: "date", label: "Date" },
        { value: "pertinence", label: "Pertinence" },
        { value: "prix_asc", label: "Prix ↑" },
        { value: "prix_desc", label: "Prix ↓" },
        { value: "places", label: "Places" },
    ];

    // Charger tous les trajets au démarrage
    useEffect(() => {
        const fetch = async () => {
            setLoading(true);
            try {
                const data = await rechercherTrajets({});
                setTousLesTrajets(Array.isArray(data) ? data : []);
            } catch {
                setTousLesTrajets([]);
            } finally {
                setLoading(false);
            }
        };
        fetch();
    }, []);

    // Nombre de places demandées (0 = pas de filtre)
    const placesRecherchees = parseInt(placesInput) || 0;

    // Filtrage + tri en temps réel côté frontend
    const trajetsFiltres = useMemo(() => {
        let result = [...tousLesTrajets];

        // Filtre départ — recherche partielle insensible à la casse
        if (depart) {
            const motDepart = depart.nom.split(",")[0].toLowerCase().trim();
            result = result.filter((t) =>
                t.depart.toLowerCase().includes(motDepart)
            );
        }

        // Filtre destination
        if (destination) {
            const motDest = destination.nom.split(",")[0].toLowerCase().trim();
            result = result.filter((t) =>
                t.destination.toLowerCase().includes(motDest)
            );
        }

        // Filtre date
        if (date) {
            result = result.filter((t) =>
                new Date(t.date_heure_depart).toISOString().split("T")[0] === date
            );
        }

        // Filtre places — le trajet doit avoir AU MOINS autant de places restantes
        // que ce que le passager recherche
        if (placesRecherchees > 0) {
            result = result.filter((t) => {
                const restantes = t.places_restantes ?? t.places_disponibles;
                return restantes >= placesRecherchees;
            });
        }

        // Filtre type de véhicule
        if (typeVehicule) {
            result = result.filter((t) =>
                t.type_vehicule?.toLowerCase().includes(typeVehicule.toLowerCase())
            );
        }

        // Tri
        switch (tri) {
            case "prix_asc":
                result.sort((a, b) => Number(a.prix_par_place) - Number(b.prix_par_place));
                break;
            case "prix_desc":
                result.sort((a, b) => Number(b.prix_par_place) - Number(a.prix_par_place));
                break;
            case "date":
                result.sort((a, b) =>
                    new Date(a.date_heure_depart).getTime() - new Date(b.date_heure_depart).getTime()
                );
                break;
            case "places":
                result.sort((a, b) =>
                    (b.places_restantes ?? b.places_disponibles) - (a.places_restantes ?? a.places_disponibles)
                );
                break;
            case "pertinence":
            default:
                if (depart || destination) {
                    result.sort((a, b) => {
                        const motD = depart?.nom.split(",")[0].toLowerCase() || "";
                        const motA = destination?.nom.split(",")[0].toLowerCase() || "";
                        const sA =
                            (motD && a.depart.toLowerCase().includes(motD) ? 1 : 0) +
                            (motA && a.destination.toLowerCase().includes(motA) ? 1 : 0);
                        const sB =
                            (motD && b.depart.toLowerCase().includes(motD) ? 1 : 0) +
                            (motA && b.destination.toLowerCase().includes(motA) ? 1 : 0);
                        return sB - sA;
                    });
                }
                break;
        }

        return result;
    }, [tousLesTrajets, depart, destination, date, placesRecherchees, typeVehicule, tri]);

    const formatDate = (iso: string) =>
        new Date(iso).toLocaleDateString("fr-FR", {
            weekday: "short", day: "numeric", month: "short",
            hour: "2-digit", minute: "2-digit",
        });

    const aDesF = depart || destination || date || placesInput || typeVehicule;

    const reinitialiser = () => {
        setDepart(null);
        setDestination(null);
        setDate("");
        setPlacesInput("");
        setTypeVehicule("");
    };

    return (
        <div className="space-y-0 -mt-8 -mx-4 lg:-mx-8">

            {/* ── HERO RECHERCHE ────────────────────────────────────── */}
            <div
                className="relative px-4 lg:px-8 pt-10 pb-8"
                style={{ background: "linear-gradient(135deg, #1e3a5f 0%, #2d6a4f 50%, #1e3a5f 100%)" }}
            >
                <div className="absolute inset-0 opacity-5" style={{
                    backgroundImage: `repeating-linear-gradient(45deg, transparent, transparent 20px, rgba(255,255,255,0.3) 20px, rgba(255,255,255,0.3) 21px)`
                }} />

                <div className="relative max-w-4xl mx-auto">
                    <p className="text-white/60 text-xs uppercase tracking-widest font-medium mb-2">Passager</p>
                    <h1 className="text-2xl font-bold text-white tracking-tight mb-1">Où allez-vous ?</h1>
                    <p className="text-white/50 text-sm mb-6">
                        {loading
                            ? "Chargement des trajets..."
                            : `${tousLesTrajets.length} trajet${tousLesTrajets.length > 1 ? "s" : ""} disponible${tousLesTrajets.length > 1 ? "s" : ""} au Togo`
                        }
                    </p>

                    {/* Filtres */}
                    <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-3 mb-4">
                        <div>
                            <p className="text-white/50 text-xs uppercase tracking-wide mb-1.5">Départ</p>
                            <AutocompleteInput
                                placeholder="D'où partez-vous ?"
                                value={depart}
                                onSelect={setDepart}
                                onClear={() => setDepart(null)}
                            />
                        </div>
                        <div>
                            <p className="text-white/50 text-xs uppercase tracking-wide mb-1.5">Destination</p>
                            <AutocompleteInput
                                placeholder="Où allez-vous ?"
                                value={destination}
                                onSelect={setDestination}
                                onClear={() => setDestination(null)}
                            />
                        </div>
                        <div>
                            <p className="text-white/50 text-xs uppercase tracking-wide mb-1.5">Date</p>
                            <input
                                type="date"
                                value={date}
                                min={new Date().toISOString().split("T")[0]}
                                onChange={(e) => setDate(e.target.value)}
                                className="input input-sm w-full rounded-xl bg-white/10 border-white/20 text-white [color-scheme:dark] focus:bg-white focus:text-base-content focus:[color-scheme:light] transition-all"
                            />
                        </div>
                        <div>
                            <p className="text-white/50 text-xs uppercase tracking-wide mb-1.5">
                                Nombre de places
                            </p>
                            <input
                                type="number"
                                min={1}
                                max={8}
                                value={placesInput}
                                placeholder="Ex: 2"
                                onChange={(e) => setPlacesInput(e.target.value)}
                                className="input input-sm w-full rounded-xl bg-white/10 border-white/20 text-white placeholder-white/40 focus:bg-white focus:text-base-content transition-all"
                            />
                        </div>
                    </div>

                    {/* Type de véhicule */}
                    <div className="flex items-center gap-2 flex-wrap">
                        <span className="text-white/40 text-xs uppercase tracking-wide">Véhicule :</span>
                        {TYPES.map((t) => (
                            <button
                                key={t}
                                onClick={() => setTypeVehicule(t === typeVehicule ? "" : t)}
                                className={`btn btn-xs rounded-full transition-all ${typeVehicule === t && t !== ""
                                        ? "bg-white text-base-content border-white font-semibold"
                                        : t === "" && typeVehicule === ""
                                            ? "bg-white text-base-content border-white font-semibold"
                                            : "bg-white/10 text-white border-white/20 hover:bg-white/20"
                                    }`}
                            >
                                {TYPES_LABELS[t]}
                            </button>
                        ))}

                        {/* Réinitialiser */}
                        {aDesF && (
                            <button
                                onClick={reinitialiser}
                                className="btn btn-xs rounded-full bg-white/5 text-white/50 border-white/10 hover:bg-white/20 ml-2"
                            >
                                Effacer les filtres
                            </button>
                        )}
                    </div>
                </div>
            </div>

            {/* ── BARRE DE TRI ─────────────────────────────────────── */}
            <div className="bg-base-100 border-b border-base-200 px-4 lg:px-8 py-3 sticky top-14 z-40">
                <div className="max-w-7xl mx-auto flex items-center justify-between gap-4 flex-wrap">
                    <p className="text-sm text-base-content/50">
                        {loading ? (
                            <span className="flex items-center gap-2">
                                <span className="loading loading-spinner loading-xs" />
                                Chargement...
                            </span>
                        ) : (
                            <>
                                <span className="font-semibold text-base-content">{trajetsFiltres.length}</span>
                                {" "}trajet{trajetsFiltres.length > 1 ? "s" : ""} affiché{trajetsFiltres.length > 1 ? "s" : ""}
                                {aDesF && (
                                    <span className="text-base-content/30 ml-1">
                                        sur {tousLesTrajets.length} disponible{tousLesTrajets.length > 1 ? "s" : ""}
                                    </span>
                                )}
                            </>
                        )}
                    </p>
                    <div className="flex items-center gap-1.5 flex-wrap">
                        <span className="text-xs text-base-content/40 mr-1">Trier :</span>
                        {TRI_OPTIONS.map((opt) => (
                            <button
                                key={opt.value}
                                onClick={() => setTri(opt.value)}
                                className={`btn btn-xs rounded-full transition-all ${tri === opt.value ? "btn-primary" : "btn-ghost border border-base-300"
                                    }`}
                            >
                                {opt.label}
                            </button>
                        ))}
                    </div>
                </div>
            </div>

            {/* ── CONTENU — Liste + Carte ───────────────────────────── */}
            <div className="px-4 lg:px-8 pt-6">
                <div className="max-w-7xl mx-auto">
                    <div className="grid lg:grid-cols-5 gap-6">

                        {/* Liste trajets */}
                        <div className="lg:col-span-3 space-y-3 pb-8">

                            {/* Skeleton chargement */}
                            {loading && [1, 2, 3, 4].map((i) => (
                                <div key={i} className="bg-base-100 rounded-2xl border border-base-200 p-5 animate-pulse">
                                    <div className="h-4 bg-base-300 rounded w-1/2 mb-3" />
                                    <div className="h-3 bg-base-300 rounded w-1/3 mb-2" />
                                    <div className="h-3 bg-base-300 rounded w-1/4" />
                                </div>
                            ))}

                            {/* Aucun résultat */}
                            {!loading && trajetsFiltres.length === 0 && (
                                <div className="bg-base-100 rounded-2xl border border-base-200 p-12 text-center">
                                    <p className="text-base-content/40 text-sm">
                                        {tousLesTrajets.length === 0
                                            ? "Aucun trajet disponible pour le moment."
                                            : "Aucun trajet ne correspond à vos critères."
                                        }
                                    </p>
                                    {aDesF && (
                                        <button
                                            onClick={reinitialiser}
                                            className="btn btn-ghost btn-sm rounded-full mt-4 border border-base-300"
                                        >
                                            Voir tous les trajets
                                        </button>
                                    )}
                                </div>
                            )}

                            {/* Cartes trajets */}
                            {!loading && trajetsFiltres.map((trajet) => {
                                const placesRestantes = trajet.places_restantes ?? trajet.places_disponibles;
                                return (
                                    <div
                                        key={trajet.id}
                                        onMouseEnter={() => setTrajetSurvole(trajet)}
                                        onMouseLeave={() => setTrajetSurvole(null)}
                                        onClick={() => router.push(`/passager/trajets/${trajet.id}`)}
                                        className={`bg-base-100 rounded-2xl border overflow-hidden cursor-pointer transition-all hover:shadow-md ${trajetSurvole?.id === trajet.id
                                                ? "border-primary shadow-md"
                                                : "border-base-200"
                                            }`}
                                    >
                                        <div className="p-5">
                                            <div className="flex items-start justify-between gap-4 mb-3">
                                                <div className="flex-1 min-w-0">
                                                    <p className="font-semibold text-base-content">
                                                        {trajet.depart}
                                                        <span className="text-base-content/25 mx-2 font-light">→</span>
                                                        {trajet.destination}
                                                    </p>
                                                    <p className="text-xs text-base-content/40 mt-0.5">
                                                        {formatDate(trajet.date_heure_depart)}
                                                    </p>
                                                </div>
                                                <div className="text-right shrink-0">
                                                    <p className="text-xl font-bold text-primary leading-none">
                                                        {Number(trajet.prix_par_place).toLocaleString("fr-FR")}
                                                    </p>
                                                    <p className="text-xs text-base-content/40 mt-0.5">FCFA / place</p>
                                                </div>
                                            </div>

                                            <div className="flex items-center gap-4 flex-wrap">
                                                {/* Conducteur */}
                                                <div className="flex items-center gap-1.5">
                                                    <div className="w-5 h-5 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                                                        <span className="text-xs font-bold text-primary">
                                                            {trajet.conducteur_nom?.[0]?.toUpperCase()}
                                                        </span>
                                                    </div>
                                                    <span className="text-xs text-base-content/60">
                                                        {trajet.conducteur_nom}
                                                    </span>
                                                </div>

                                                {/* Note */}
                                                <div className="flex items-center gap-1">
                                                    <div className="flex gap-0.5">
                                                        {[1, 2, 3, 4, 5].map((s) => (
                                                            <div key={s} className={`w-2 h-2 rounded-sm ${s <= Math.round(trajet.conducteur_note)
                                                                    ? "bg-warning" : "bg-base-300"
                                                                }`} />
                                                        ))}
                                                    </div>
                                                    <span className="text-xs text-base-content/40">
                                                        {trajet.conducteur_note}/5
                                                    </span>
                                                </div>

                                                {/* Places */}
                                                <span className={`text-xs font-medium ${placesRestantes <= 1 ? "text-error" : "text-base-content/50"
                                                    }`}>
                                                    {placesRestantes} place{placesRestantes > 1 ? "s" : ""} dispo
                                                </span>

                                                {/* Distance */}
                                                {trajet.distance_km && (
                                                    <span className="text-xs text-base-content/40">
                                                        {trajet.distance_km} km
                                                    </span>
                                                )}

                                                {/* Type véhicule */}
                                                {trajet.type_vehicule && (
                                                    <span className="text-xs text-base-content/40 capitalize">
                                                        {trajet.type_vehicule}
                                                    </span>
                                                )}
                                            </div>
                                        </div>

                                        <div className="px-5 py-2.5 bg-base-200/40 border-t border-base-200 flex items-center justify-between">
                                            <span className="badge badge-success badge-outline badge-sm rounded-full">
                                                ouvert
                                            </span>
                                            <span className="text-xs text-primary font-medium">
                                                Voir le trajet →
                                            </span>
                                        </div>
                                    </div>
                                );
                            })}
                        </div>

                        {/* Carte sticky */}
                        <div className="hidden lg:block lg:col-span-2">
                            <div className="sticky top-28 bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                                <div className="px-5 py-3 border-b border-base-200 flex items-center justify-between">
                                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                                        Carte
                                    </p>
                                    <p className="text-xs text-base-content/30">
                                        {trajetsFiltres.length} trajet{trajetsFiltres.length > 1 ? "s" : ""}
                                    </p>
                                </div>
                                <div className="h-[calc(100vh-220px)] min-h-[400px]">
                                    <MapRecherche
                                        trajets={trajetsFiltres ?? []}
                                        trajetSurvole={trajetSurvole}
                                        depart={depart}
                                        destination={destination}
                                        onTrajetClick={(id) => router.push(`/passager/trajets/${id}`)}
                                    />
                                </div>
                            </div>
                        </div>

                    </div>
                </div>
            </div>

        </div>
    );
}