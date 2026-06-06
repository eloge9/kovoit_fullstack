"use client";

import { useEffect, useState } from "react";
import CarteAlertes from "@/components/CarteAlertes";
import { getAlertesRoutes } from "@/src/services/trajet.service";

interface AlerteFeature {
    type: "Feature";
    geometry: { type: string; coordinates: number[][] };
    properties: { type_alerte: string; nom: string; ref: string };
}

interface AlertesData {
    type: "FeatureCollection";
    features: AlerteFeature[];
    count?: number;
}

export default function RoutesBloquees() {
    const [data,    setData]    = useState<AlertesData | null>(null);
    const [loading, setLoading] = useState(true);
    const [erreur,  setErreur]  = useState("");

    useEffect(() => {
        getAlertesRoutes("bloquee")
            .then((d) => setData(d as unknown as AlertesData))
            .catch(() => setErreur("Impossible de charger les données. Réessayez plus tard."))
            .finally(() => setLoading(false));
    }, []);

    return (
        <div data-theme="winter" className="min-h-screen bg-base-200 p-6">
            <div className="max-w-5xl mx-auto space-y-6">

                {/* En-tête */}
                <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-error/10 rounded-xl flex items-center justify-center">
                        <svg className="w-5 h-5 text-error" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636" />
                        </svg>
                    </div>
                    <div>
                        <h1 className="text-xl font-bold text-base-content">Routes bloquées</h1>
                        <p className="text-sm text-base-content/50">Axes fermés à la circulation à Lomé et environs</p>
                    </div>
                </div>

                {/* Stats */}
                {data && (
                    <div className="stats shadow bg-base-100">
                        <div className="stat">
                            <div className="stat-figure text-error">
                                <svg className="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                        d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                                </svg>
                            </div>
                            <div className="stat-title">Routes bloquées détectées</div>
                            <div className="stat-value text-error">{data.count ?? data.features.length}</div>
                            <div className="stat-desc">Source : OpenStreetMap / Overpass</div>
                        </div>
                    </div>
                )}

                {/* Carte */}
                <div className="card bg-base-100 shadow-sm overflow-hidden">
                    <div className="card-body p-0">
                        {loading ? (
                            <div className="h-96 flex items-center justify-center">
                                <span className="loading loading-spinner loading-lg text-error" />
                            </div>
                        ) : erreur ? (
                            <div className="h-96 flex items-center justify-center">
                                <div className="text-center text-base-content/50">
                                    <p className="text-error font-medium">{erreur}</p>
                                </div>
                            </div>
                        ) : (
                            <CarteAlertes data={data as any} className="h-[500px] w-full" />
                        )}
                    </div>
                </div>

                {/* Liste */}
                {data && data.features.length > 0 && (
                    <div className="card bg-base-100 shadow-sm">
                        <div className="card-body">
                            <h2 className="card-title text-base">Détail des routes bloquées</h2>
                            <div className="divide-y divide-base-200">
                                {data.features.map((f: AlerteFeature, i: number) => (
                                    <div key={i} className="py-3 flex items-center gap-3">
                                        <div className="w-3 h-3 rounded-full bg-error shrink-0" />
                                        <div>
                                            <p className="text-sm font-medium text-base-content">
                                                {f.properties.nom || "Route sans nom"}
                                            </p>
                                            {f.properties.ref && (
                                                <p className="text-xs text-base-content/50">Ref: {f.properties.ref}</p>
                                            )}
                                        </div>
                                    </div>
                                ))}
                            </div>
                        </div>
                    </div>
                )}

                {data && data.features.length === 0 && !loading && (
                    <div className="card bg-success/10 shadow-sm">
                        <div className="card-body items-center text-center py-10">
                            <svg className="w-12 h-12 text-success mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                            </svg>
                            <p className="font-medium text-success">Aucune route bloquée détectée</p>
                            <p className="text-sm text-base-content/50">La circulation est fluide sur les axes principaux</p>
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
}
