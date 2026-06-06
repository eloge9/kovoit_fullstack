"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import { api } from "@/src/services/api";
import { getMediaUrl } from "@/src/utils/imageUtils";

interface ProfilPublic {
    id: string;
    nom: string;
    photo_profil: string | null;
    note: number;
    score_confiance: number;
    statut_validation: string;
    est_verifie: boolean;
    vehicules: { type_vehicule: string; marque: string; modele: string; couleur: string; places_max: number }[];
    evaluations_recentes: { auteur: string; note: number; commentaire: string; date: string }[];
    nb_evaluations: number;
}

const LABELS_VEHICULE: Record<string, string> = {
    moto: "Moto", voiture: "Voiture", minibus: "Minibus", camion: "Camion",
};

export default function ProfilPublicConducteur() {
    const { id }  = useParams();
    const router  = useRouter();
    const [profil,   setProfil]  = useState<ProfilPublic | null>(null);
    const [loading,  setLoading] = useState(true);

    useEffect(() => {
        if (!id) return;
        api(`/utilisateurs/conducteur/${id}/profil/`, "GET")
            .then(setProfil)
            .catch(() => setProfil(null))
            .finally(() => setLoading(false));
    }, [id]);

    const etoiles = (n: number) =>
        [1, 2, 3, 4, 5].map((s) => (
            <span key={s} className={`text-lg ${s <= Math.round(n) ? "text-warning" : "text-base-300"}`}>★</span>
        ));

    const formatDate = (iso: string) =>
        new Date(iso).toLocaleDateString("fr-FR", { day: "numeric", month: "long", year: "numeric" });

    if (loading) {
        return (
            <div data-theme="winter" className="min-h-screen bg-base-200 flex items-center justify-center">
                <span className="loading loading-spinner loading-lg text-primary" />
            </div>
        );
    }

    if (!profil) {
        return (
            <div data-theme="winter" className="min-h-screen bg-base-200 flex items-center justify-center">
                <div className="text-center">
                    <p className="text-base-content/50">Conducteur introuvable.</p>
                    <button onClick={() => router.back()} className="btn btn-ghost btn-sm mt-4 rounded-full">Retour</button>
                </div>
            </div>
        );
    }

    return (
        <div data-theme="winter" className="min-h-screen bg-base-200 p-6">
            <div className="max-w-2xl mx-auto space-y-6">

                {/* Retour */}
                <button onClick={() => router.back()} className="btn btn-ghost btn-sm rounded-full gap-2">
                    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
                    </svg>
                    Retour
                </button>

                {/* En-tête profil */}
                <div className="card bg-base-100 shadow-sm">
                    <div className="card-body items-center text-center gap-4">
                        <div className="relative">
                            <div className="w-24 h-24 rounded-full bg-primary/10 flex items-center justify-center overflow-hidden">
                                {profil.photo_profil ? (
                                    <img src={getMediaUrl(profil.photo_profil)} alt={profil.nom}
                                        className="w-full h-full object-cover" />
                                ) : (
                                    <span className="text-4xl font-bold text-primary">
                                        {profil.nom[0]?.toUpperCase()}
                                    </span>
                                )}
                            </div>
                            {profil.est_verifie && (
                                <div className="absolute -bottom-1 -right-1 w-8 h-8 bg-success rounded-full flex items-center justify-center border-2 border-base-100"
                                    title="Conducteur vérifié">
                                    <svg className="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
                                    </svg>
                                </div>
                            )}
                        </div>

                        <div>
                            <div className="flex items-center gap-2 justify-center">
                                <h1 className="text-2xl font-bold text-base-content">{profil.nom}</h1>
                                {profil.est_verifie && (
                                    <span className="badge badge-success badge-sm">✓ Vérifié</span>
                                )}
                            </div>
                            <div className="flex items-center gap-1 justify-center mt-1">
                                {etoiles(profil.note)}
                                <span className="text-sm text-base-content/50 ml-1">
                                    {profil.note.toFixed(1)} ({profil.nb_evaluations} avis)
                                </span>
                            </div>
                        </div>

                        {/* Score de confiance */}
                        <div className="w-full bg-base-200 rounded-2xl p-4">
                            <p className="text-xs text-base-content/40 uppercase tracking-widest mb-2">Score de confiance</p>
                            <div className="flex items-center gap-3">
                                <div className="flex-1 bg-base-300 rounded-full h-3 overflow-hidden">
                                    <div
                                        className="h-full rounded-full bg-gradient-to-r from-warning to-success transition-all"
                                        style={{ width: `${profil.score_confiance}%` }}
                                    />
                                </div>
                                <span className="font-bold text-lg text-base-content w-12 text-right">
                                    {profil.score_confiance}
                                </span>
                            </div>
                            <p className="text-xs text-base-content/30 mt-1">
                                Basé sur les 20 dernières évaluations
                            </p>
                        </div>
                    </div>
                </div>

                {/* Véhicules */}
                {profil.vehicules.length > 0 && (
                    <div className="card bg-base-100 shadow-sm">
                        <div className="card-body">
                            <h2 className="card-title text-base">Véhicule(s)</h2>
                            <div className="space-y-3">
                                {profil.vehicules.map((v, i) => (
                                    <div key={i} className="flex items-center gap-3 p-3 bg-base-200 rounded-xl">
                                        <div className="w-10 h-10 bg-primary/10 rounded-lg flex items-center justify-center">
                                            <span className="text-lg">
                                                {v.type_vehicule === 'moto' ? '🏍️' : v.type_vehicule === 'minibus' ? '🚐' : '🚗'}
                                            </span>
                                        </div>
                                        <div className="flex-1">
                                            <p className="font-medium text-sm">
                                                {v.marque} {v.modele}
                                                <span className="ml-2 text-xs text-base-content/50">({v.couleur})</span>
                                            </p>
                                            <p className="text-xs text-base-content/40">
                                                {LABELS_VEHICULE[v.type_vehicule]} · {v.places_max} places
                                            </p>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        </div>
                    </div>
                )}

                {/* Évaluations */}
                {profil.evaluations_recentes.length > 0 && (
                    <div className="card bg-base-100 shadow-sm">
                        <div className="card-body">
                            <h2 className="card-title text-base">Avis récents</h2>
                            <div className="space-y-4">
                                {profil.evaluations_recentes.map((e, i) => (
                                    <div key={i} className="border-b border-base-200 pb-4 last:border-0 last:pb-0">
                                        <div className="flex items-center justify-between mb-1">
                                            <p className="font-medium text-sm">{e.auteur}</p>
                                            <div className="flex">
                                                {etoiles(e.note)}
                                            </div>
                                        </div>
                                        {e.commentaire && (
                                            <p className="text-sm text-base-content/70 mt-1">{e.commentaire}</p>
                                        )}
                                        <p className="text-xs text-base-content/30 mt-1">{formatDate(e.date)}</p>
                                    </div>
                                ))}
                            </div>
                        </div>
                    </div>
                )}

                {profil.nb_evaluations === 0 && (
                    <div className="card bg-base-100 shadow-sm">
                        <div className="card-body items-center text-center py-8">
                            <p className="text-base-content/40 text-sm">Aucun avis pour ce conducteur</p>
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
}
