"use client";

import { useEffect, useState } from "react";
import CarteAlertes from "@/components/CarteAlertes";
import { getAlertesRoutes } from "@/src/services/trajet.service";

interface AlertesData {
    type: "FeatureCollection";
    features: { type: "Feature"; geometry: { type: string; coordinates: number[][] }; properties: { type_alerte: string; nom: string; ref: string } }[];
    count?: number;
}

export default function Embouteillages() {
    const [data,    setData]    = useState<AlertesData | null>(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        getAlertesRoutes("impraticable")
            .then((d) => setData(d as unknown as AlertesData))
            .catch(() => setData({ type: "FeatureCollection", features: [] }))
            .finally(() => setLoading(false));
    }, []);

    return (
        <div data-theme="winter" className="min-h-screen bg-base-200 p-6">
            <div className="max-w-5xl mx-auto space-y-6">

                <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-warning/10 rounded-xl flex items-center justify-center">
                        <svg className="w-5 h-5 text-warning" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                    </div>
                    <div>
                        <h1 className="text-xl font-bold text-base-content">Embouteillages & ralentissements</h1>
                        <p className="text-sm text-base-content/50">Axes à circulation difficile à Lomé et environs</p>
                    </div>
                </div>

                {data && (
                    <div className="stats shadow bg-base-100">
                        <div className="stat">
                            <div className="stat-figure text-warning">
                                <svg className="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                        d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                                </svg>
                            </div>
                            <div className="stat-title">Zones de ralentissement</div>
                            <div className="stat-value text-warning">{data.count ?? data.features.length}</div>
                            <div className="stat-desc">Surface dégradée détectée par OSM</div>
                        </div>
                    </div>
                )}

                <div className="card bg-base-100 shadow-sm overflow-hidden">
                    <div className="card-body p-0">
                        {loading ? (
                            <div className="h-96 flex items-center justify-center">
                                <span className="loading loading-spinner loading-lg text-warning" />
                            </div>
                        ) : (
                            <CarteAlertes data={data as any} className="h-[500px] w-full" />
                        )}
                    </div>
                </div>

                {data && data.features.length === 0 && !loading && (
                    <div className="card bg-success/10 shadow-sm">
                        <div className="card-body items-center text-center py-10">
                            <svg className="w-12 h-12 text-success mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                            </svg>
                            <p className="font-medium text-success">Trafic fluide</p>
                            <p className="text-sm text-base-content/50">Aucun ralentissement majeur signalé</p>
                        </div>
                    </div>
                )}

                {data && data.features.length > 0 && (
                    <div className="card bg-base-100 shadow-sm">
                        <div className="card-body">
                            <h2 className="card-title text-base">Zones impactées</h2>
                            <div className="divide-y divide-base-200">
                                {data.features.map((f, i) => (
                                    <div key={i} className="py-3 flex items-center gap-3">
                                        <div className="w-3 h-3 rounded-full bg-warning shrink-0" />
                                        <div>
                                            <p className="text-sm font-medium">{f.properties.nom || "Axe sans nom"}</p>
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
            </div>
        </div>
    );
}
