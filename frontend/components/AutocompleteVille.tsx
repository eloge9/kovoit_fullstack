"use client";

import { useState, useRef, useEffect, useCallback } from "react";
import { autocompleteVille } from "@/src/services/trajet.service";

interface Suggestion {
    nom: string;
    display: string;
    lat: number;
    lng: number;
}

interface AutocompleteVilleProps {
    label?: string;
    placeholder?: string;
    value?: string;
    onSelect: (suggestion: Suggestion) => void;
    className?: string;
}

export default function AutocompleteVille({
    label,
    placeholder = "Ex: Lomé, Kpalimé…",
    value = "",
    onSelect,
    className = "",
}: AutocompleteVilleProps) {
    const [query,        setQuery]       = useState(value);
    const [suggestions,  setSuggestions] = useState<Suggestion[]>([]);
    const [loading,      setLoading]     = useState(false);
    const [open,         setOpen]        = useState(false);
    const timerRef   = useRef<ReturnType<typeof setTimeout> | null>(null);
    const wrapperRef = useRef<HTMLDivElement>(null);

    const chercher = useCallback((q: string) => {
        if (q.length < 2) { setSuggestions([]); return; }
        setLoading(true);
        autocompleteVille(q)
            .then(setSuggestions)
            .catch(() => setSuggestions([]))
            .finally(() => setLoading(false));
    }, []);

    const onChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        const q = e.target.value;
        setQuery(q);
        setOpen(true);
        if (timerRef.current) clearTimeout(timerRef.current);
        timerRef.current = setTimeout(() => chercher(q), 300);
    };

    const choisir = (s: Suggestion) => {
        setQuery(s.nom);
        setSuggestions([]);
        setOpen(false);
        onSelect(s);
    };

    // Fermer si clic à l'extérieur
    useEffect(() => {
        const handler = (e: MouseEvent) => {
            if (wrapperRef.current && !wrapperRef.current.contains(e.target as Node)) {
                setOpen(false);
            }
        };
        document.addEventListener("mousedown", handler);
        return () => document.removeEventListener("mousedown", handler);
    }, []);

    return (
        <div ref={wrapperRef} className={`relative ${className}`}>
            {label && (
                <label className="label">
                    <span className="label-text font-medium">{label}</span>
                </label>
            )}
            <div className="relative">
                <input
                    type="text"
                    value={query}
                    onChange={onChange}
                    onFocus={() => suggestions.length > 0 && setOpen(true)}
                    placeholder={placeholder}
                    className="input input-bordered w-full pr-10"
                    autoComplete="off"
                />
                {loading && (
                    <span className="absolute right-3 top-1/2 -translate-y-1/2">
                        <span className="loading loading-spinner loading-xs text-primary" />
                    </span>
                )}
            </div>

            {open && suggestions.length > 0 && (
                <ul className="absolute z-50 mt-1 w-full bg-base-100 border border-base-300 rounded-xl shadow-lg py-1 max-h-56 overflow-auto">
                    {suggestions.map((s, i) => (
                        <li key={i}>
                            <button
                                type="button"
                                className="w-full text-left px-4 py-2.5 hover:bg-base-200 transition-colors text-sm"
                                onClick={() => choisir(s)}
                            >
                                <span className="font-medium text-base-content">{s.nom}</span>
                                <span className="block text-xs text-base-content/50 truncate">{s.display}</span>
                            </button>
                        </li>
                    ))}
                </ul>
            )}
        </div>
    );
}
