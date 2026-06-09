'use client';

import { useEffect, useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Link from 'next/link';
import dynamic from 'next/dynamic';

import trajetApi from '@/libs/trajet-api';
import { useTrajetWebSocket } from '@/src/hooks/useTrajetWebSocket';
import { Trajet, PositionActuelleResponse } from '@/types/trajet';

const CarteTrajet = dynamic(() => import('@/components/CarteTrajet'), { ssr: false });

const BADGE: Record<string, string> = {
    ouvert:   'badge-warning badge-outline',
    en_cours: 'badge-success badge-outline',
    termine:  'badge-info badge-outline',
    annule:   'badge-error badge-outline',
};
const LABEL: Record<string, string> = {
    ouvert:   'Ouvert',
    en_cours: 'En cours',
    termine:  'Terminé',
    annule:   'Annulé',
};

export default function GestionTrajetPage() {
    const params   = useParams();
    const router   = useRouter();
    const trajetId = params.id as string;

    const [trajet,        setTrajet]        = useState<Trajet | null>(null);
    const [positionData,  setPositionData]  = useState<PositionActuelleResponse | null>(null);
    const [loading,       setLoading]       = useState(true);
    const [actionLoading, setActionLoading] = useState(false);
    const [error,         setError]         = useState<string | null>(null);
    const [success,       setSuccess]       = useState<string | null>(null);
    const [gpsActif,      setGpsActif]      = useState(false);
    const [watchId,       setWatchId]       = useState<number | null>(null);

    const { isConnected: wsConnecte, sendPosition } = useTrajetWebSocket({
        trajetId: trajet?.statut === 'en_cours' ? trajetId : null,
    });

    // ── Chargement ─────────────────────────────────────────────────────────
    const chargerTrajet = async () => {
        try {
            const data = await trajetApi.getTrajet(trajetId);
            setTrajet(data);
            if (typeof window !== 'undefined') {
                const stored = localStorage.getItem('user');
                if (stored && JSON.parse(stored).id !== data.conducteur) {
                    setError("Vous n'êtes pas le conducteur de ce trajet.");
                    return;
                }
            }
            if (data.statut === 'en_cours') demarrerGps();
        } catch (err: any) {
            setError(err.response?.data?.error || 'Impossible de charger le trajet.');
        }
    };

    const chargerPosition = async () => {
        try {
            const pos = await trajetApi.getPositionActuelle(trajetId);
            setPositionData(pos);
        } catch {
            // silencieux si trajet non en cours
        }
    };

    useEffect(() => {
        const init = async () => {
            setLoading(true);
            await chargerTrajet();
            await chargerPosition();
            setLoading(false);
        };
        if (trajetId) init();
        return () => arreterGps();
    }, [trajetId]);

    useEffect(() => {
        if (trajet?.statut !== 'en_cours') return;
        const timer = setInterval(chargerPosition, 30_000);
        return () => clearInterval(timer);
    }, [trajet?.statut, trajetId]);

    // ── GPS ─────────────────────────────────────────────────────────────────
    const demarrerGps = () => {
        if (!navigator.geolocation) { setError('Géolocalisation non supportée.'); return; }
        setGpsActif(true);
        const id = navigator.geolocation.watchPosition(
            (pos) => {
                const data = {
                    latitude:    pos.coords.latitude,
                    longitude:   pos.coords.longitude,
                    vitesse_kmh: pos.coords.speed != null ? pos.coords.speed * 3.6 : undefined,
                    direction:   pos.coords.heading ?? undefined,
                };
                if (wsConnecte) {
                    sendPosition(data);
                    setPositionData({ position: data, latitude: data.latitude, longitude: data.longitude });
                } else {
                    trajetApi.mettreAJourPosition(trajetId, { ...data, altitude: pos.coords.altitude ?? undefined }).catch(() => {});
                }
            },
            (err) => setError('GPS : ' + err.message),
            { enableHighAccuracy: true, timeout: 10_000, maximumAge: 0 },
        );
        setWatchId(id);
    };

    const arreterGps = () => {
        if (watchId !== null) navigator.geolocation.clearWatch(watchId);
        setWatchId(null);
        setGpsActif(false);
    };

    // ── Actions ─────────────────────────────────────────────────────────────
    const commencer = async () => {
        setActionLoading(true); setError(null);
        try {
            const res = await trajetApi.commencerTrajet(trajetId);
            setTrajet(res.trajet);
            setSuccess(res.message);
            demarrerGps();
            setTimeout(chargerPosition, 1_000);
        } catch (err: any) {
            setError(err.response?.data?.error || 'Impossible de démarrer.');
        } finally { setActionLoading(false); }
    };

    const terminer = async () => {
        setActionLoading(true); setError(null);
        try {
            const res = await trajetApi.terminerTrajet(trajetId);
            setTrajet(res.trajet);
            setSuccess(res.message);
            arreterGps();
        } catch (err: any) {
            setError(err.response?.data?.error || 'Impossible de terminer.');
        } finally { setActionLoading(false); }
    };

    // ── États ────────────────────────────────────────────────────────────────
    if (loading) {
        return (
            <div className="max-w-4xl mx-auto space-y-4 animate-pulse">
                <div className="h-8 bg-base-300 rounded w-1/3" />
                <div className="h-32 bg-base-300 rounded-2xl" />
                <div className="h-80 bg-base-300 rounded-2xl" />
            </div>
        );
    }

    if (error && !trajet) {
        return (
            <div className="max-w-lg mx-auto py-16 text-center space-y-4">
                <div className="w-16 h-16 rounded-full bg-error/10 flex items-center justify-center mx-auto">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8 text-error" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                </div>
                <h1 className="text-xl font-bold text-base-content">{error}</h1>
                <Link href="/conducteur/trajets" className="btn btn-primary btn-sm rounded-full gap-2">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
                    </svg>
                    Mes trajets
                </Link>
            </div>
        );
    }

    return (
        <div className="max-w-4xl mx-auto space-y-6">

            {/* EN-TÊTE */}
            <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                    <Link href="/conducteur/trajets" className="btn btn-ghost btn-sm btn-square rounded-xl">
                        <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
                        </svg>
                    </Link>
                    <div>
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                            Gestion du trajet
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

                {/* Indicateurs */}
                <div className="flex items-center gap-2">
                    {wsConnecte ? (
                        <span className="badge badge-sm badge-success badge-outline gap-1">
                            <span className="w-1.5 h-1.5 rounded-full bg-success" />
                            Temps réel
                        </span>
                    ) : (
                        <span className="badge badge-sm badge-ghost gap-1">
                            <span className="w-1.5 h-1.5 rounded-full bg-base-content/30" />
                            Hors ligne
                        </span>
                    )}
                    {gpsActif && (
                        <span className="badge badge-sm badge-success badge-outline gap-1">
                            <span className="w-1.5 h-1.5 rounded-full bg-success animate-pulse" />
                            GPS
                        </span>
                    )}
                </div>
            </div>

            {/* ALERTES */}
            {success && (
                <div className="bg-success/10 border border-success/20 rounded-xl px-4 py-3 flex items-center gap-2">
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 text-success shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                    </svg>
                    <p className="text-sm text-success">{success}</p>
                </div>
            )}
            {error && (
                <div className="bg-error/10 border border-error/20 rounded-xl px-4 py-3">
                    <p className="text-sm text-error">{error}</p>
                </div>
            )}

            {trajet && (
                <>
                    {/* INFOS TRAJET */}
                    <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                        <div className="px-6 py-4 border-b border-base-200">
                            <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                                Détails du trajet
                            </p>
                        </div>
                        <div className="grid grid-cols-2 sm:grid-cols-4 divide-x divide-base-200">
                            {[
                                {
                                    label: "Itinéraire",
                                    value: `${trajet.depart} → ${trajet.destination}`,
                                },
                                {
                                    label: "Départ",
                                    value: new Date(trajet.date_heure_depart).toLocaleDateString("fr-FR", {
                                        day: "2-digit", month: "short", year: "numeric",
                                        hour: "2-digit", minute: "2-digit",
                                    }),
                                },
                                {
                                    label: "Places",
                                    value: `${trajet.places_restantes ?? trajet.places_disponibles} / ${trajet.places_disponibles}`,
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
                                <div key={i} className="px-5 py-4">
                                    <p className="text-xs text-base-content/40 uppercase tracking-wide mb-1">
                                        {item.label}
                                    </p>
                                    {item.custom ?? (
                                        <p className="text-sm font-medium text-base-content">{item.value}</p>
                                    )}
                                </div>
                            ))}
                        </div>
                    </div>

                    {/* ACTION CONDUCTEUR */}
                    <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-4">
                            Actions
                        </p>

                        {trajet.statut === 'ouvert' && (
                            <div className="flex items-center justify-between gap-4">
                                <div>
                                    <p className="font-medium text-base-content">Prêt à partir ?</p>
                                    <p className="text-sm text-base-content/50 mt-0.5">
                                        Le suivi GPS s'activera et vos passagers seront informés.
                                    </p>
                                </div>
                                <button
                                    onClick={commencer}
                                    disabled={actionLoading}
                                    className="btn btn-success btn-sm rounded-full shrink-0 gap-2"
                                >
                                    {actionLoading
                                        ? <span className="loading loading-spinner loading-xs" />
                                        : (
                                            <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="currentColor" viewBox="0 0 24 24">
                                                <path d="M8 5v14l11-7z" />
                                            </svg>
                                        )
                                    }
                                    Commencer
                                </button>
                            </div>
                        )}

                        {trajet.statut === 'en_cours' && (
                            <div className="flex items-center justify-between gap-4">
                                <div>
                                    <p className="font-medium text-base-content">Trajet en cours</p>
                                    <p className="text-sm text-base-content/50 mt-0.5">
                                        Suivi GPS actif. Cliquez pour terminer le trajet.
                                    </p>
                                </div>
                                <button
                                    onClick={terminer}
                                    disabled={actionLoading}
                                    className="btn btn-error btn-sm rounded-full shrink-0 gap-2"
                                >
                                    {actionLoading
                                        ? <span className="loading loading-spinner loading-xs" />
                                        : (
                                            <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="currentColor" viewBox="0 0 24 24">
                                                <path d="M6 6h12v12H6z" />
                                            </svg>
                                        )
                                    }
                                    Terminer
                                </button>
                            </div>
                        )}

                        {trajet.statut === 'termine' && (
                            <div className="text-center py-6 space-y-2">
                                <div className="w-12 h-12 rounded-full bg-success/10 flex items-center justify-center mx-auto">
                                    <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                                    </svg>
                                </div>
                                <p className="font-medium text-base-content">Trajet terminé</p>
                                <p className="text-sm text-base-content/40">
                                    Les passagers ont été notifiés.
                                </p>
                                <Link href="/conducteur/evaluations" className="btn btn-primary btn-sm rounded-full mt-2">
                                    Voir les évaluations
                                </Link>
                            </div>
                        )}

                        {trajet.statut === 'annule' && (
                            <div className="text-center py-4">
                                <span className="badge badge-error badge-outline rounded-full">Trajet annulé</span>
                            </div>
                        )}
                    </div>

                    {/* CARTE */}
                    <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
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
                </>
            )}
        </div>
    );
}
