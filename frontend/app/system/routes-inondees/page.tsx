"use client";

import { useEffect, useState } from "react";
import CarteAlertes from "@/components/CarteAlertes";
import { getAlertesRoutes } from "@/src/services/trajet.service";

interface AlertesData {
    type: "FeatureCollection";
    features: { type: "Feature"; geometry: { type: string; coordinates: number[][] }; properties: { type_alerte: string; nom: string; ref: string } }[];
    count?: number;
}

export default function RoutesInondees() {
    const [data,    setData]    = useState<AlertesData | null>(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        getAlertesRoutes("inondable")
            .then((d) => setData(d as unknown as AlertesData))
            .catch(() => setData({ type: "FeatureCollection", features: [] }))
            .finally(() => setLoading(false));
    }, []);

    return (
        <div data-theme="winter" className="min-h-screen bg-base-200 p-6">
            <div className="max-w-5xl mx-auto space-y-6">

                <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-info/10 rounded-xl flex items-center justify-center">
                        <svg className="w-5 h-5 text-info" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
                        </svg>
                    </div>
                    <div>
                        <h1 className="text-xl font-bold text-base-content">Zones inondables</h1>
                        <p className="text-sm text-base-content/50">Routes susceptibles d'être inondées en saison des pluies</p>
                    </div>
                </div>

                <div className="alert alert-info">
                    <svg className="w-5 h-5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                            d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <span className="text-sm">
                        Ces zones sont identifiées par OpenStreetMap comme sujettes aux inondations.
                        En saison des pluies (avril–juin, août–octobre), évitez ces axes.
                    </span>
                </div>

                {data && (
                    <div className="stats shadow bg-base-100">
                        <div className="stat">
                            <div className="stat-figure text-info">
                                <svg className="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                                        d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z" />
                                </svg>
                            </div>
                            <div className="stat-title">Zones inondables répertoriées</div>
                            <div className="stat-value text-info">{data.count ?? data.features.length}</div>
                            <div className="stat-desc">Source : OpenStreetMap / Overpass</div>
                        </div>
                    </div>
                )}

                <div className="card bg-base-100 shadow-sm overflow-hidden">
                    <div className="card-body p-0">
                        {loading ? (
                            <div className="h-96 flex items-center justify-center">
                                <span className="loading loading-spinner loading-lg text-info" />
                            </div>
                        ) : (
                            <CarteAlertes data={data as any} className="h-[500px] w-full" />
                        )}
                    </div>
                </div>

                {data && data.features.length === 0 && !loading && (
                    <div className="card bg-base-100 shadow-sm">
                        <div className="card-body items-center text-center py-10">
                            <p className="font-medium text-base-content/60">
                                Aucune zone inondable signalée dans la base OSM
                            </p>
                            <p className="text-sm text-base-content/40">
                                Les données OSM sont mises à jour par la communauté locale
                            </p>
                        </div>
                    </div>
                )}

                {data && data.features.length > 0 && (
                    <div className="card bg-base-100 shadow-sm">
                        <div className="card-body">
                            <h2 className="card-title text-base">Zones à risque d'inondation</h2>
                            <div className="divide-y divide-base-200">
                                {data.features.map((f, i) => (
                                    <div key={i} className="py-3 flex items-center gap-3">
                                        <div className="w-3 h-3 rounded-full bg-info shrink-0" />
                                        <div>
                                            <p className="text-sm font-medium">{f.properties.nom || "Zone sans nom"}</p>
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
