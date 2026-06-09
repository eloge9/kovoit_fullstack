'use client';

import { useEffect, useState, useCallback } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import dynamic from 'next/dynamic';

import trajetApi from '@/libs/trajet-api';
import { useTrajetWebSocket, type PositionPayload } from '@/src/hooks/useTrajetWebSocket';
import { Trajet, PositionActuelleResponse } from '@/types/trajet';

const CarteTrajet  = dynamic(() => import('@/components/CarteTrajet'),  { ssr: false });
const InfoSuivi    = dynamic(() => import('@/components/InfoSuivi'),    { ssr: false });

const BADGE: Record<string, string> = {
    ouvert:   'badge-warning badge-outline',
    en_cours: 'badge-success badge-outline',
    termine:  'badge-info badge-outline',
    annule:   'badge-error badge-outline',
};
const LABEL: Record<string, string> = {
    ouvert:   'Pas encore démarré',
    en_cours: 'En cours',
    termine:  'Terminé',
    annule:   'Annulé',
};

export default function SuiviTrajetPage() {
    const params   = useParams();
    const router   = useRouter();
    const trajetId = params.id as string;

    const [trajet,       setTrajet]       = useState<Trajet | null>(null);
    const [positionData, setPositionData] = useState<PositionActuelleResponse | null>(null);
    const [loading,      setLoading]      = useState(true);
    const [error,        setError]        = useState<string | null>(null);
    const [refreshing,   setRefreshing]   = useState(false);

    // WebSocket — écoute la position en temps réel
    const { isConnected: wsConnected } = useTrajetWebSocket({
        trajetId: trajet?.statut === 'en_cours' ? trajetId : null,
        onPosition: useCallback((pos: PositionPayload) => {
            setPositionData((prev) => ({
                ...prev,
                position: {
                    latitude:    pos.latitude,
                    longitude:   pos.longitude,
                    vitesse_kmh: pos.vitesse_kmh,
                    direction:   pos.direction,
                    timestamp:   pos.timestamp,
                },
            }));
            setError(null);
        }, []),
    });

    const loadTrajet = async () => {
        try {
            const data = await trajetApi.getTrajet(trajetId);
            setTrajet(data);
        } catch (err: any) {
            setError(err.response?.data?.error || 'Impossible de charger les informations du trajet.');
        }
    };

    const loadPosition = async () => {
        try {
            const data = await trajetApi.getPositionActuelle(trajetId);
            setPositionData(data);
            setError(null);
        } catch (err: any) {
            if (err.response?.status === 400) {
                setError('Ce trajet n\'est pas encore en cours.');
            } else if (err.response?.status === 404) {
                setError('Aucune position GPS disponible pour le moment.');
            }
        }
    };

    const refreshData = async () => {
        setRefreshing(true);
        await Promise.all([loadTrajet(), loadPosition()]);
        setRefreshing(false);
    };

    useEffect(() => {
        const init = async () => {
            setLoading(true);
            await loadTrajet();
            await loadPosition();
            setLoading(false);
        };
        if (trajetId) init();
    }, [trajetId]);

    // Fallback REST : polling 5s si WebSocket déconnecté
    useEffect(() => {
        if (trajet?.statut !== 'en_cours' || wsConnected) return;
        const timer = setInterval(loadPosition, 5_000);
        return () => clearInterval(timer);
    }, [trajet?.statut, trajetId, wsConnected]);

    // ── Skeleton ─────────────────────────────────────────────────────────
    if (loading) {
        return (
            <div className="max-w-4xl mx-auto space-y-4 animate-pulse">
                <div className="h-8 bg-base-300 rounded w-1/3" />
                <div className="h-24 bg-base-300 rounded-2xl" />
                <div className="h-80 bg-base-300 rounded-2xl" />
            </div>
        );
    }

    // ── Erreur fatale ─────────────────────────────────────────────────────
    if (error && !trajet) {
        return (
            <div className="max-w-lg mx-auto py-16 text-center space-y-4">
                <div className="w-16 h-16 rounded-full bg-error/10 flex items-center justify-center mx-auto">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8 text-error" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                </div>
                <h1 className="text-xl font-bold text-base-content">{error}</h1>
                <Link href="/passager/reservations" className="btn btn-primary btn-sm rounded-full gap-2">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
                    </svg>
                    Mes réservations
                </Link>
            </div>
        );
    }

    return (
        <div className="max-w-4xl mx-auto space-y-6">

            {/* EN-TÊTE */}
            <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                    <Link href="/passager/reservations" className="btn btn-ghost btn-sm btn-square rounded-xl">
                        <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
                        </svg>
                    </Link>
                    <div>
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                            Suivi en temps réel
                        </p>
                        {trajet && (
                            <h1 className="text-xl font-bold text-base-content tracking-tight">
                                {trajet.depart}
                                <span className="text-base-content/25 mx-2 font-light">→</span>
                                {trajet.destination}
                            </h1>
                        )}
                    </div>
                </div>

                <div className="flex items-center gap-2">
                    {/* Indicateur WS */}
                    {trajet?.statut === 'en_cours' && (
                        wsConnected ? (
                            <span className="badge badge-sm badge-success badge-outline gap-1">
                                <span className="w-1.5 h-1.5 rounded-full bg-success animate-pulse" />
                                Temps réel
                            </span>
                        ) : (
                            <span className="badge badge-sm badge-ghost gap-1">
                                <span className="w-1.5 h-1.5 rounded-full bg-base-content/30" />
                                Reconnexion…
                            </span>
                        )
                    )}
                    <button
                        onClick={refreshData}
                        disabled={refreshing}
                        className="btn btn-ghost btn-sm btn-square rounded-xl"
                        title="Actualiser"
                    >
                        <svg xmlns="http://www.w3.org/2000/svg" className={`h-4 w-4 ${refreshing ? 'animate-spin' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                        </svg>
                    </button>
                </div>
            </div>

            {/* INFO TRAJET */}
            {trajet && (
                <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                    <div className="grid grid-cols-2 sm:grid-cols-4 divide-x divide-base-200">
                        {[
                            {
                                label: "Conducteur",
                                value: trajet.conducteur_nom || "—",
                                sub: trajet.conducteur_note ? `${trajet.conducteur_note}/5 ★` : undefined,
                            },
                            {
                                label: "Véhicule",
                                value: trajet.vehicule_info
                                    ? `${trajet.vehicule_info.marque} ${trajet.vehicule_info.modele}`
                                    : "Non spécifié",
                                sub: trajet.vehicule_info?.couleur,
                            },
                            {
                                label: "Distance",
                                value: trajet.distance_km ? `${trajet.distance_km} km` : "—",
                                sub: trajet.prix_par_place ? `${Number(trajet.prix_par_place).toLocaleString("fr-FR")} FCFA` : undefined,
                            },
                            {
                                label: "Statut",
                                custom: (
                                    <span className={`badge badge-sm rounded-full font-medium ${BADGE[trajet.statut] ?? "badge-ghost"}`}>
                                        {LABEL[trajet.statut] ?? trajet.statut}
                                    </span>
                                ),
                            },
                        ].map((item, i) => (
                            <div key={i} className="px-4 py-4">
                                <p className="text-xs text-base-content/40 uppercase tracking-wide mb-1">
                                    {item.label}
                                </p>
                                {item.custom ?? (
                                    <>
                                        <p className="text-sm font-semibold text-base-content leading-tight">
                                            {item.value}
                                        </p>
                                        {item.sub && (
                                            <p className="text-xs text-base-content/50 mt-0.5">{item.sub}</p>
                                        )}
                                    </>
                                )}
                            </div>
                        ))}
                    </div>
                </div>
            )}

            {/* ALERTE NON FATALE */}
            {error && trajet && (
                <div className="bg-warning/10 border border-warning/20 rounded-xl px-4 py-3 flex items-center gap-2">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 text-warning shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <p className="text-sm text-warning">{error}</p>
                </div>
            )}

            {/* CARTE + INFOS SUIVI */}
            {trajet && (
                <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                    {/* Carte */}
                    <div className="lg:col-span-2 bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                        <div className="px-6 py-4 border-b border-base-200">
                            <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                                Carte de suivi
                            </p>
                        </div>
                        <div className="h-80">
                            <CarteTrajet
                                positionActuelle={positionData?.position}
                                departLat={trajet.depart_lat}
                                departLng={trajet.depart_lng}
                                destinationLat={trajet.destination_lat}
                                destinationLng={trajet.destination_lng}
                                suiviInfo={positionData?.suivi}
                                className="h-full w-full"
                            />
                        </div>
                    </div>

                    {/* Infos temps réel */}
                    <div className="lg:col-span-1">
                        <InfoSuivi
                            positionActuelle={positionData?.position}
                            suiviInfo={positionData?.suivi}
                            statutTrajet={trajet.statut}
                        />
                    </div>
                </div>
            )}

            {/* MESSAGE CONTEXTUEL */}
            {trajet?.statut === 'ouvert' && (
                <div className="bg-info/5 border border-info/20 rounded-2xl p-5 space-y-1">
                    <p className="font-medium text-base-content text-sm">Le trajet n'a pas encore commencé</p>
                    <p className="text-sm text-base-content/60">
                        Le conducteur démarrera prochainement. La carte de suivi s'activera automatiquement.
                    </p>
                </div>
            )}

            {trajet?.statut === 'termine' && (
                <div className="bg-success/5 border border-success/20 rounded-2xl p-5 flex items-center justify-between gap-4">
                    <div>
                        <p className="font-medium text-base-content text-sm">Trajet terminé 🎉</p>
                        <p className="text-sm text-base-content/60 mt-0.5">
                            Merci d'avoir voyagé avec KoVoit !
                        </p>
                    </div>
                    <Link href="/passager/reservations" className="btn btn-primary btn-sm rounded-full shrink-0">
                        Mes réservations
                    </Link>
                </div>
            )}
        </div>
    );
}
