"use client";

import { useState, useEffect } from "react";
import { useParams, useRouter } from "next/navigation";
import dynamic from "next/dynamic";
import { api } from "@/src/services/api";
import { getTrajet, type Trajet } from "@/src/services/trajet.service";
import { getQrCode } from "@/src/services/messagerie.service";
import { ajouterPlaces } from "@/src/services/reservation.service";
import { getOrCreateGroupeTrajet } from "@/src/services/messagerie.service";
import { QRCodeSVG } from "qrcode.react";

const MapView = dynamic(() => import("@/components/MapView"), { ssr: false });

interface ReservationDetail {
    id: number;
    trajet_id: number;
    depart: string;
    destination: string;
    date_depart: string;
    conducteur: string;
    conducteur_note: number;
    prix_par_place: number;
    prix_passager?: number;
    code_embarquement?: string;
    statut_embarquement?: "en_attente" | "embarque" | "depose";
    heure_embarquement?: string;
    heure_depose?: string;
    penalite_annulation?: number;
    statut: "en_attente" | "confirmee" | "declinee" | "terminee" | "annulee";
    date_reservation: string;
    places_reservees?: number;
    conversation_id?: number | null;
    groupe_conv_id?: number | null;
    trajet_info?: Trajet;
    paiement_statut?: string | null;
    paiement_moyen?: string | null;
}

export default function DetailReservationPage() {
    const { id } = useParams();
    const router = useRouter();

    const [reservation, setReservation] = useState<ReservationDetail | null>(null);
    const [trajet, setTrajet] = useState<Trajet | null>(null);
    const [loading, setLoading] = useState(true);
    const [annulation, setAnnulation] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [qrToken, setQrToken] = useState<string | null>(null);
    const [qrLoading, setQrLoading] = useState(false);
    const [ajoutDialog, setAjoutDialog] = useState(false);
    const [ajoutPlaces, setAjoutPlaces] = useState(1);
    const [ajoutLoading, setAjoutLoading] = useState(false);
    const [groupeChatLoading, setGroupeChatLoading] = useState(false);

    useEffect(() => {
        const fetchReservation = async () => {
            setLoading(true);
            try {
                // Récupérer les détails de la réservation
                const reservationData = await api(`/reservations/${id}/`);
                setReservation(reservationData);

                // Récupérer les détails du trajet associé
                try {
                    const trajetData = await getTrajet(reservationData.trajet_id);
                    setTrajet(trajetData);
                } catch {
                    // Trajet non accessible (terminé/annulé) — on garde quand même la réservation
                    setTrajet(null);
                }
            } catch (err: any) {
                // Gérer les différents cas d'erreur
                if (err.response?.status === 404) {
                    setError("Cette réservation n'existe pas ou a été supprimée.");
                } else if (err.response?.status === 403) {
                    setError("Vous n'avez pas l'autorisation de voir cette réservation.");
                } else {
                    setError(err.response?.data?.error || "Réservation introuvable.");
                }
            } finally {
                setLoading(false);
            }
        };

        if (id) fetchReservation();
    }, [id]);

    const handleQrCode = async () => {
        if (!reservation) return;
        setQrLoading(true);
        try {
            const data = await getQrCode(String(reservation.id));
            setQrToken(data?.token ?? null);
        } catch {
            setQrToken(null);
        } finally {
            setQrLoading(false);
        }
    };

    const handleAjouterPlaces = async () => {
        if (!reservation) return;
        setAjoutLoading(true);
        setError(null);
        try {
            const result = await ajouterPlaces(reservation.id, ajoutPlaces) as any;
            const nouvellesPlaces = result?.places_reservees ?? ((reservation.places_reservees ?? 1) + ajoutPlaces);
            setReservation(prev => prev ? { ...prev, places_reservees: nouvellesPlaces } : prev);
            setAjoutDialog(false);
            setAjoutPlaces(1);
        } catch (err: any) {
            setError(err.response?.data?.error || "Erreur lors de l'ajout de places.");
        } finally {
            setAjoutLoading(false);
        }
    };

    const handleAnnuler = async () => {
        // Avertir si annulation tardive (<2h avant départ)
        const trajetDate = reservation?.date_depart ? new Date(reservation.date_depart) : null;
        const tardive = trajetDate && (trajetDate.getTime() - Date.now()) < 2 * 3600 * 1000;
        const msg = tardive
            ? "Ce trajet part dans moins de 2 heures. Une pénalité de 20% s'applique. Confirmer l'annulation ?"
            : "Confirmer l'annulation de cette réservation ?";
        if (!confirm(msg)) return;
        setAnnulation(true);
        setError(null);
        try {
            const res = await api(`/reservations/${id}/annuler/`, "POST");
            if (res?.penalite_fcfa > 0) {
                alert(`Annulation enregistrée. Pénalité appliquée : ${res.penalite_fcfa.toLocaleString("fr-FR")} FCFA.`);
            }
            router.push("/passager/reservations");
        } catch (err: any) {
            setError(err.response?.data?.error || "Erreur lors de l'annulation.");
            setAnnulation(false);
        }
    };

    const formatDate = (iso: string) =>
        new Date(iso).toLocaleDateString("fr-FR", {
            weekday: "long", day: "numeric", month: "long",
            year: "numeric", hour: "2-digit", minute: "2-digit",
        });

    const statutBadge = (statut: string) => {
        switch (statut) {
            case "en_attente": return "badge-warning badge-outline";
            case "confirmee": return "badge-success badge-outline";
            case "declinee": return "badge-error badge-outline";
            case "terminee": return "badge-info badge-outline";
            default: return "badge-ghost";
        }
    };

    const statutLabel = (statut: string) => {
        switch (statut) {
            case "en_attente": return "En attente de confirmation";
            case "confirmee": return "Place confirmée";
            case "declinee": return "Demande déclinée";
            case "terminee": return "Trajet terminé";
            default: return statut;
        }
    };

    // ── Chargement ──────────────────────────────────────────────────────
    if (loading) {
        return (
            <div className="max-w-2xl mx-auto space-y-4 animate-pulse">
                <div className="h-6 bg-base-300 rounded w-1/3" />
                <div className="h-64 bg-base-300 rounded-2xl" />
                <div className="h-32 bg-base-300 rounded-2xl" />
            </div>
        );
    }

    // ── Erreur ──────────────────────────────────────────────────────────
    if (!reservation) {
        return (
            <div className="max-w-lg mx-auto py-16 text-center">
                <p className="text-base-content/40">{error || "Réservation introuvable."}</p>
                <button onClick={() => router.back()} className="btn btn-ghost btn-sm rounded-full mt-4">
                    Retour
                </button>
            </div>
        );
    }

    return (
        <div className="max-w-2xl mx-auto space-y-6">

            {/* EN-TÊTE */}
            <div className="flex items-center gap-3 pb-4 border-b border-base-300">
                <button
                    onClick={() => router.back()}
                    className="btn btn-ghost btn-sm btn-square rounded-xl"
                >
                    <svg xmlns="http://www.w.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
                    </svg>
                </button>
                <div>
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                        Détail de la réservation
                    </p>
                    <h1 className="text-xl font-bold text-base-content tracking-tight">
                        {reservation.depart}
                        <span className="text-base-content/25 mx-2 font-light">→</span>
                        {reservation.destination}
                    </h1>
                </div>
            </div>

            {/* ERREUR */}
            {error && (
                <div className="bg-error/10 border border-error/20 rounded-xl px-4 py-3">
                    <p className="text-sm text-error">{error}</p>
                </div>
            )}

            {/* STATUT */}
            <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
                <div className="flex items-center justify-between">
                    <div>
                        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-2">
                            Statut de votre réservation
                        </p>
                        <div className="flex items-center gap-3">
                            <span className={`badge badge-md rounded-full font-medium ${statutBadge(reservation.statut)}`}>
                                {statutLabel(reservation.statut)}
                            </span>
                            <p className="text-sm text-base-content/60">
                                Réservée le {formatDate(reservation.date_reservation)}
                            </p>
                        </div>
                    </div>
                    <div className="text-right">
                        <p className="text-2xl font-bold text-primary">
                            {(Number(reservation.prix_par_place) * (reservation.places_reservees ?? 1)).toLocaleString("fr-FR")} FCFA
                        </p>
                        <p className="text-xs text-base-content/40">
                            {reservation.places_reservees && reservation.places_reservees > 1
                                ? `${(reservation.places_reservees)} place${reservation.places_reservees > 1 ? 's' : ''} × ${Number(reservation.prix_par_place).toLocaleString("fr-FR")} FCFA`
                                : "par place"
                            }
                        </p>
                    </div>
                </div>

                {/* Messages selon statut */}
                {reservation.statut === "en_attente" && (
                    <div className="mt-4 bg-warning/5 border border-warning/10 rounded-xl px-4 py-3">
                        <p className="text-sm text-warning/70">
                            Votre demande est en attente de confirmation par le conducteur. Vous serez notifié dès qu'il répondra.
                        </p>
                    </div>
                )}

                {reservation.statut === "confirmee" && (
                    <div className="mt-4 bg-success/5 border border-success/10 rounded-xl px-4 py-3">
                        <p className="text-sm text-success/70">
                            Votre place est confirmée ! Présentez-vous au point de départ à l'heure prévue.
                        </p>
                    </div>
                )}

                {reservation.statut === "declinee" && (
                    <div className="mt-4 bg-error/5 border border-error/10 rounded-xl px-4 py-3">
                        <p className="text-sm text-error/70">
                            Le conducteur a décliné votre demande. Vous pouvez rechercher un autre trajet.
                        </p>
                    </div>
                )}

                {reservation.statut === "terminee" && (
                    <div className="mt-4 bg-info/5 border border-info/10 rounded-xl px-4 py-3">
                        <p className="text-sm text-info/70">
                            🎉 Trajet terminé avec succès ! Merci d'avoir utilisé Kovoit pour votre voyage.
                        </p>
                    </div>
                )}
            </div>

            {/* CARTE */}
            {trajet && trajet.depart_lat && trajet.destination_lat ? (
                <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                    <div className="h-52">
                        <MapView
                            depart={{ nom: trajet.depart, lat: trajet.depart_lat, lng: trajet.depart_lng }}
                            destination={{ nom: trajet.destination, lat: trajet.destination_lat, lng: trajet.destination_lng }}
                        />
                    </div>
                </div>
            ) : (
                <div className="bg-base-100 rounded-2xl border border-base-200 p-8 text-center">
                    <div className="w-16 h-16 rounded-full bg-base-200 flex items-center justify-center mx-auto mb-4">
                        <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8 text-base-content/40" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7" />
                        </svg>
                    </div>
                    <p className="text-base-content/40 text-sm">
                        Carte du trajet non disponible
                    </p>
                    {reservation.statut === "terminee" && (
                        <p className="text-base-content/30 text-xs mt-2">
                            Le trajet est terminé
                        </p>
                    )}
                </div>
            )}

            {/* INFOS TRAJET */}
            <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                <div className="px-6 py-4 border-b border-base-200">
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                        Informations du trajet
                    </p>
                </div>
                <div className="divide-y divide-base-200">
                    {[
                        { label: "Départ", value: trajet ? trajet.depart : reservation.depart },
                        { label: "Arrivée", value: trajet ? trajet.destination : reservation.destination },
                        { label: "Date", value: trajet ? formatDate(trajet.date_heure_depart) : formatDate(reservation.date_depart) },
                        { label: "Distance", value: trajet?.distance_km ? `${trajet.distance_km} km` : "Non spécifiée" },
                        { label: "Statut du trajet", value: trajet ? (trajet.statut === 'termine' ? 'Terminé' : trajet.statut) : 'Terminé' },
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
            </div>

            {/* CONDUCTEUR */}
            <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-4">
                    Conducteur
                </p>
                <div className="flex items-center gap-4">
                    <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                        <span className="text-lg font-bold text-primary">
                            {reservation.conducteur?.[0]?.toUpperCase()}
                        </span>
                    </div>
                    <div>
                        <p className="font-semibold text-base-content">{reservation.conducteur}</p>
                        <div className="flex items-center gap-1 mt-0.5">
                            <div className="flex gap-0.5">
                                {[1, 2, 3, 4, 5].map((s) => (
                                    <div key={s} className={`w-2.5 h-2.5 rounded-sm ${s <= Math.round(reservation.conducteur_note || 0)
                                        ? "bg-warning" : "bg-base-300"
                                        }`} />
                                ))}
                            </div>
                            <span className="text-xs text-base-content/40 ml-1">
                                {reservation.conducteur_note || 0} / 5
                            </span>
                        </div>
                    </div>
                </div>
            </div>

            {/* CODE D'EMBARQUEMENT KVT-XXXX — visible si confirmée */}
            {reservation.statut === "confirmee" && (
                <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-4">
                        Code d'embarquement
                    </p>

                    {/* Statut d'embarquement */}
                    {reservation.statut_embarquement && reservation.statut_embarquement !== "en_attente" && (
                        <div className={`mb-4 rounded-xl px-4 py-3 ${reservation.statut_embarquement === "embarque" ? "bg-success/10 border border-success/20" : "bg-info/10 border border-info/20"}`}>
                            <p className={`text-sm font-medium ${reservation.statut_embarquement === "embarque" ? "text-success" : "text-info"}`}>
                                {reservation.statut_embarquement === "embarque"
                                    ? `Embarqué${reservation.heure_embarquement ? " — " + new Date(reservation.heure_embarquement).toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" }) : ""}`
                                    : `Déposé${reservation.heure_depose ? " — " + new Date(reservation.heure_depose).toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" }) : ""}`
                                }
                            </p>
                        </div>
                    )}

                    {/* PIN KVT-XXXX + QR code */}
                    {reservation.code_embarquement ? (
                        <div className="text-center space-y-4">
                            <p className="text-xs text-base-content/50">
                                Montrez ce code ou le QR au conducteur
                            </p>
                            <div className="inline-block bg-primary/5 border-2 border-primary/20 rounded-2xl px-8 py-5">
                                <p className="font-mono text-4xl font-black tracking-[0.25em] text-primary select-all">
                                    {reservation.code_embarquement}
                                </p>
                            </div>
                            <div className="flex justify-center">
                                <div className="bg-white p-3 rounded-2xl border border-base-200 inline-block">
                                    <QRCodeSVG
                                        value={reservation.code_embarquement}
                                        size={160}
                                        level="M"
                                        includeMargin={false}
                                    />
                                </div>
                            </div>
                            <p className="text-xs text-base-content/40">
                                Code unique de ce trajet — ne change pas.
                            </p>
                        </div>
                    ) : (
                        /* Fallback : ancien token HMAC */
                        <>
                            {qrToken ? (
                                <div className="text-center space-y-3">
                                    <div className="inline-block bg-base-200 rounded-2xl p-6">
                                        <p className="font-mono text-4xl font-bold tracking-[0.3em] text-primary select-all">
                                            {qrToken}
                                        </p>
                                    </div>
                                    <p className="text-xs text-base-content/40">
                                        Code valide 1 heure.
                                    </p>
                                    <button onClick={() => setQrToken(null)} className="btn btn-ghost btn-xs rounded-full">Masquer</button>
                                </div>
                            ) : (
                                <button onClick={handleQrCode} disabled={qrLoading} className="btn btn-outline btn-primary rounded-full w-full">
                                    {qrLoading ? <span className="loading loading-spinner loading-sm" /> : "Afficher mon code"}
                                </button>
                            )}
                        </>
                    )}
                </div>
            )}

            {/* ACTIONS — Messagerie */}
            {reservation.statut !== "annulee" && (
                <div className="flex flex-col gap-3">
                    {/* Conversation privée conducteur */}
                    {reservation.conversation_id && (
                        <button
                            onClick={() => router.push(`/communication/messages?conv=${reservation.conversation_id}`)}
                            className={`btn rounded-full w-full gap-2 ${reservation.statut === "declinee" ? "btn-ghost border border-base-300" : "btn-outline btn-primary"}`}
                        >
                            <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                            </svg>
                            {reservation.statut === "declinee" ? "Voir la conversation" : "Message conducteur"}
                        </button>
                    )}
                    {/* Chat de groupe du trajet */}
                    {(reservation.statut === "confirmee") && (
                        reservation.groupe_conv_id ? (
                            <button
                                onClick={() => router.push(`/communication/messages?conv=${reservation.groupe_conv_id}&groupe=true`)}
                                className="btn btn-outline rounded-full w-full gap-2"
                            >
                                <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
                                </svg>
                                Chat du trajet
                            </button>
                        ) : (
                            <button
                                onClick={async () => {
                                    setGroupeChatLoading(true);
                                    try {
                                        const conv = await getOrCreateGroupeTrajet(reservation.trajet_id);
                                        setReservation(prev => prev ? { ...prev, groupe_conv_id: conv.id } : prev);
                                        router.push(`/communication/messages?conv=${conv.id}&groupe=true`);
                                    } catch { /* silencieux */ }
                                    finally { setGroupeChatLoading(false); }
                                }}
                                disabled={groupeChatLoading}
                                className="btn btn-outline rounded-full w-full gap-2"
                            >
                                {groupeChatLoading
                                    ? <span className="loading loading-spinner loading-xs" />
                                    : (
                                        <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
                                        </svg>
                                    )
                                }
                                Chat du trajet
                            </button>
                        )
                    )}
                </div>
            )}

            {/* Modal ajouter des places */}
            {ajoutDialog && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm px-4">
                    <div className="bg-base-100 rounded-2xl p-6 w-full max-w-sm shadow-xl space-y-4">
                        <h3 className="text-lg font-bold">Ajouter des places</h3>
                        <p className="text-sm text-base-content/60">
                            Vous avez actuellement {reservation.places_reservees ?? 1} place(s).
                        </p>
                        <div className="flex items-center justify-center gap-4 py-2">
                            <button
                                onClick={() => setAjoutPlaces(p => Math.max(1, p - 1))}
                                disabled={ajoutPlaces <= 1}
                                className="btn btn-sm btn-square btn-ghost border border-base-300 rounded-xl disabled:opacity-30"
                            >−</button>
                            <span className="text-2xl font-black text-primary">+{ajoutPlaces}</span>
                            <button
                                onClick={() => setAjoutPlaces(p => Math.min(8 - (reservation.places_reservees ?? 1), p + 1))}
                                disabled={ajoutPlaces >= 8 - (reservation.places_reservees ?? 1)}
                                className="btn btn-sm btn-square btn-ghost border border-base-300 rounded-xl disabled:opacity-30"
                            >+</button>
                        </div>
                        <p className="text-center text-sm font-semibold text-primary">
                            Supplément : {(Number(reservation.prix_par_place) * ajoutPlaces).toLocaleString("fr-FR")} FCFA
                        </p>
                        {error && <p className="text-sm text-error">{error}</p>}
                        <div className="flex gap-3 pt-2">
                            <button onClick={() => { setAjoutDialog(false); setAjoutPlaces(1); setError(null); }}
                                className="btn btn-ghost rounded-full flex-1 border border-base-300">
                                Annuler
                            </button>
                            <button onClick={handleAjouterPlaces} disabled={ajoutLoading}
                                className="btn btn-primary rounded-full flex-1">
                                {ajoutLoading ? <span className="loading loading-spinner loading-sm" /> : "Confirmer"}
                            </button>
                        </div>
                    </div>
                </div>
            )}

            <div className="flex gap-3 flex-wrap">
                {(reservation.statut === "en_attente" || reservation.statut === "confirmee") && (
                    <button
                        onClick={() => setAjoutDialog(true)}
                        className="btn btn-outline rounded-full w-full"
                    >
                        + Ajouter des places
                    </button>
                )}

                {reservation.statut === "en_attente" && (
                    <>
                        <button
                            onClick={handleAnnuler}
                            disabled={annulation}
                            className="btn btn-error btn-outline rounded-full flex-1"
                        >
                            {annulation
                                ? <span className="loading loading-spinner loading-sm" />
                                : "Annuler la demande"
                            }
                        </button>
                        <button
                            onClick={() => router.push(`/passager/trajets/${reservation.trajet_id}`)}
                            className="btn btn-ghost rounded-full flex-1 border border-base-300"
                        >
                            Voir le trajet
                        </button>
                    </>
                )}

                {reservation.statut === "confirmee" && (
                    <>
                        {(() => {
                            const ps = reservation.paiement_statut;
                            if (ps === "PAYEE" || ps === "CONFIRME") {
                                return (
                                    <div className="flex items-center gap-2 flex-1 justify-center bg-success/10 border border-success/20 rounded-full px-4 py-2">
                                        <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                                        </svg>
                                        <span className="text-sm font-semibold text-success">Réservation payée</span>
                                    </div>
                                );
                            }
                            if (ps === "EN_ATTENTE_CONFIRMATION") {
                                return (
                                    <div className="flex items-center gap-2 flex-1 justify-center bg-warning/10 border border-warning/20 rounded-full px-4 py-2">
                                        <span className="text-sm font-semibold text-warning">Paiement espèces en attente</span>
                                    </div>
                                );
                            }
                            return (
                                <button
                                    onClick={() => router.push(`/passager/reservations/paiement/${reservation.id}`)}
                                    className="btn btn-primary rounded-full flex-1"
                                >
                                    Payer la réservation
                                </button>
                            );
                        })()}
                        <button
                            onClick={() => router.push(`/passager/trajets/${reservation.trajet_id}`)}
                            className="btn btn-ghost rounded-full flex-1 border border-base-300"
                        >
                            Voir le trajet
                        </button>
                    </>
                )}

                {reservation.statut === "declinee" && (
                    <>
                        <button
                            onClick={() => router.push("/passager/trajets")}
                            className="btn btn-primary rounded-full flex-1"
                        >
                            Rechercher un autre trajet
                        </button>
                        <button
                            onClick={() => router.push(`/passager/trajets/${reservation.trajet_id}`)}
                            className="btn btn-ghost rounded-full flex-1 border border-base-300"
                        >
                            Voir le trajet
                        </button>
                    </>
                )}

                {reservation.statut === "terminee" && (
                    <>
                        <button
                            onClick={() => router.push("/passager/trajets")}
                            className="btn btn-primary rounded-full flex-1"
                        >
                            Réserver un autre trajet
                        </button>
                        <button
                            onClick={() => router.push(`/passager/trajets/${reservation.trajet_id}`)}
                            className="btn btn-ghost rounded-full flex-1 border border-base-300"
                        >
                            Voir le trajet
                        </button>
                    </>
                )}
            </div>

        </div>
    );
}
