'use client';

import { useEffect, useRef, useState, useCallback } from 'react';
import { Bell, X, CheckCircle, AlertTriangle, Info, MessageSquare, AlertOctagon } from 'lucide-react';
import { useNotifs, NotifPayload } from '@/src/hooks/useNotifs';
import { declencherSos } from '@/src/services/messagerie.service';

// ── Types ─────────────────────────────────────────────────────────────────

interface Notification {
    id:        string;
    type:      'success' | 'error' | 'warning' | 'info' | 'message';
    title:     string;
    message:   string;
    timestamp: Date;
    read:      boolean;
    link?:     string;
}

// ── Titres lisibles par type de notification Django ───────────────────────

const NOTIF_LABELS: Record<string, { title: string; type: Notification['type'] }> = {
    nouvelle_reservation:          { title: 'Nouvelle réservation',          type: 'info'    },
    reservation_confirmee:         { title: 'Réservation confirmée',          type: 'success' },
    reservation_refusee:           { title: 'Réservation déclinée',           type: 'error'   },
    paiement_recu:                 { title: 'Paiement reçu',                 type: 'success' },
    trajet_demarre:                { title: 'Trajet démarré',                type: 'info'    },
    trajet_termine:                { title: 'Trajet terminé',                type: 'success' },
    conducteur_proche:             { title: 'Conducteur proche',             type: 'warning' },
    nouveau_message:               { title: 'Nouveau message',               type: 'message' },
    documents_valides:             { title: 'Documents validés ✓',            type: 'success' },
    documents_refuses:             { title: 'Documents refusés',             type: 'error'   },
    annulation_trajet:             { title: 'Trajet annulé',                 type: 'warning' },
    paiement_mobile_money_confirme:{ title: 'Paiement Mobile Money confirmé',type: 'success' },
};

// ── Bouton SOS ────────────────────────────────────────────────────────────

function BoutonSOS() {
    const DUREE_APPUI = 3000; // 3 secondes
    const pressRef    = useRef<NodeJS.Timeout | null>(null);
    const [progres,   setProgres]   = useState(0);
    const [appuye,    setAppuye]    = useState(false);
    const [confirme,  setConfirme]  = useState(false);
    const [enCours,   setEnCours]   = useState(false);
    const [resultat,  setResultat]  = useState<string | null>(null);
    const intervalRef = useRef<NodeJS.Timeout | null>(null);

    const startPress = () => {
        setAppuye(true);
        setProgres(0);
        const start = Date.now();
        intervalRef.current = setInterval(() => {
            const elapsed = Date.now() - start;
            const pct = Math.min((elapsed / DUREE_APPUI) * 100, 100);
            setProgres(pct);
            if (pct >= 100) {
                clearInterval(intervalRef.current!);
                setAppuye(false);
                setConfirme(true);
            }
        }, 50);
    };

    const stopPress = () => {
        if (intervalRef.current) clearInterval(intervalRef.current);
        setAppuye(false);
        setProgres(0);
    };

    const confirmerSOS = async () => {
        setConfirme(false);
        setEnCours(true);
        try {
            let lat: number | undefined;
            let lng: number | undefined;
            if (navigator.geolocation) {
                await new Promise<void>((resolve) => {
                    navigator.geolocation.getCurrentPosition(
                        (pos) => { lat = pos.coords.latitude; lng = pos.coords.longitude; resolve(); },
                        () => resolve(),
                        { timeout: 5000 }
                    );
                });
            }
            const res = await declencherSos({ latitude: lat, longitude: lng });
            setResultat(res.message);
        } catch {
            setResultat("Erreur lors de l'envoi du SOS.");
        } finally {
            setEnCours(false);
            setTimeout(() => setResultat(null), 5000);
        }
    };

    return (
        <>
            {/* Bouton SOS */}
            <div className="fixed bottom-6 left-6 z-50 select-none">
                <div className="relative">
                    <button
                        onMouseDown={startPress}
                        onMouseUp={stopPress}
                        onMouseLeave={stopPress}
                        onTouchStart={startPress}
                        onTouchEnd={stopPress}
                        className={`w-14 h-14 rounded-full flex items-center justify-center shadow-lg transition-transform ${
                            appuye ? 'scale-90' : 'hover:scale-105'
                        } ${enCours ? 'bg-error/50' : 'bg-error'}`}
                        title="Appuyez 3 secondes pour déclencher le SOS"
                    >
                        <AlertOctagon className="w-7 h-7 text-white" />
                    </button>
                    {/* Cercle de progression */}
                    {appuye && (
                        <svg className="absolute inset-0 w-14 h-14 -rotate-90" viewBox="0 0 56 56">
                            <circle
                                cx="28" cy="28" r="25"
                                fill="none"
                                stroke="white"
                                strokeWidth="3"
                                strokeDasharray={`${2 * Math.PI * 25}`}
                                strokeDashoffset={`${2 * Math.PI * 25 * (1 - progres / 100)}`}
                                strokeLinecap="round"
                                style={{ transition: 'stroke-dashoffset 0.05s linear' }}
                            />
                        </svg>
                    )}
                </div>
                <p className="text-xs text-base-content/40 mt-1 text-center">SOS</p>
            </div>

            {/* Modal confirmation SOS */}
            {confirme && (
                <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/60">
                    <div className="bg-base-100 rounded-2xl p-6 w-80 shadow-2xl">
                        <div className="flex items-center gap-3 mb-4">
                            <AlertOctagon className="w-8 h-8 text-error" />
                            <h3 className="text-lg font-bold text-base-content">Confirmer le SOS ?</h3>
                        </div>
                        <p className="text-sm text-base-content/60 mb-6">
                            Un SMS d'urgence sera envoyé à votre contact d'urgence avec votre position GPS.
                        </p>
                        <div className="flex gap-3">
                            <button
                                onClick={() => setConfirme(false)}
                                className="btn btn-ghost flex-1"
                            >
                                Annuler
                            </button>
                            <button
                                onClick={confirmerSOS}
                                className="btn btn-error flex-1 text-white"
                            >
                                Envoyer le SOS
                            </button>
                        </div>
                    </div>
                </div>
            )}

            {/* Toast résultat SOS */}
            {(enCours || resultat) && (
                <div className="fixed bottom-24 left-6 z-50 bg-error text-white rounded-xl px-4 py-3 shadow-lg max-w-xs">
                    {enCours ? (
                        <div className="flex items-center gap-2">
                            <span className="loading loading-spinner loading-xs" />
                            <span className="text-sm">Envoi du SOS...</span>
                        </div>
                    ) : (
                        <p className="text-sm">{resultat}</p>
                    )}
                </div>
            )}
        </>
    );
}

// ── Composant principal ───────────────────────────────────────────────────

export default function NotificationSystem() {
    const [notifications, setNotifications] = useState<Notification[]>([]);
    const [showPanel,     setShowPanel]     = useState(false);

    const addNotif = useCallback((notif: Omit<Notification, 'id' | 'timestamp' | 'read'>) => {
        const n: Notification = {
            ...notif,
            id:        Date.now().toString(),
            timestamp: new Date(),
            read:      false,
        };
        setNotifications(prev => [n, ...prev].slice(0, 50));
        if (notif.type === 'success') {
            setTimeout(() => removeNotif(n.id), 8000);
        }
    }, []);

    const removeNotif = (id: string) =>
        setNotifications(prev => prev.filter(n => n.id !== id));

    const markRead = (id: string) =>
        setNotifications(prev => prev.map(n => n.id === id ? { ...n, read: true } : n));

    const markAllRead = () =>
        setNotifications(prev => prev.map(n => ({ ...n, read: true })));

    // ── WebSocket notifications ────────────────────────────────────────

    const handleWsNotif = useCallback((payload: NotifPayload) => {
        const label = NOTIF_LABELS[payload.type] ?? { title: payload.type, type: 'info' as const };
        const data  = payload.data as Record<string, string>;
        addNotif({
            type:    label.type,
            title:   label.title,
            message: data.message || data.detail || JSON.stringify(payload.data),
            link:    data.link,
        });
    }, [addNotif]);

    // Écouter aussi les événements DOM legacy (GPS consumer, etc.)
    useEffect(() => {
        const handlers: Array<[string, EventListenerOrEventListenerObject]> = [
            ['trajet-commence', (e: any) => addNotif({ type: 'info',    title: 'Trajet commencé',  message: e.detail?.message || '' })],
            ['trajet-termine',  (e: any) => addNotif({ type: 'success', title: 'Trajet terminé',   message: e.detail?.message || '' })],
            ['position-update', (e: any) => addNotif({ type: 'info',    title: 'Position mise à jour', message: '' })],
        ];
        handlers.forEach(([evt, fn]) => window.addEventListener(evt, fn));
        return () => handlers.forEach(([evt, fn]) => window.removeEventListener(evt, fn));
    }, [addNotif]);

    useNotifs({ onNotification: handleWsNotif });

    const unread = notifications.filter(n => !n.read).length;

    const getIcon = (type: Notification['type']) => {
        switch (type) {
            case 'success': return <CheckCircle className="w-4 h-4 text-success" />;
            case 'error':   return <AlertTriangle className="w-4 h-4 text-error" />;
            case 'warning': return <AlertTriangle className="w-4 h-4 text-warning" />;
            case 'message': return <MessageSquare className="w-4 h-4 text-info" />;
            default:        return <Info className="w-4 h-4 text-info" />;
        }
    };

    const fmtTime = (d: Date) =>
        d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });

    return (
        <>
            {/* ── Cloche ── */}
            <div className="relative">
                <button
                    onClick={() => { setShowPanel(v => !v); if (!showPanel) markAllRead(); }}
                    className="relative p-2 rounded-xl hover:bg-base-200 transition-colors"
                    title="Notifications"
                >
                    <Bell className="w-5 h-5 text-base-content/60" />
                    {unread > 0 && (
                        <span className="absolute -top-0.5 -right-0.5 bg-error text-white text-[10px] rounded-full w-4 h-4 flex items-center justify-center font-bold">
                            {unread > 9 ? '9+' : unread}
                        </span>
                    )}
                </button>

                {/* ── Panneau ── */}
                {showPanel && (
                    <div className="absolute right-0 top-10 z-50 w-80 bg-base-100 rounded-2xl shadow-2xl border border-base-200 overflow-hidden">
                        <div className="flex items-center justify-between p-4 border-b border-base-200">
                            <h3 className="font-semibold text-sm text-base-content">Notifications</h3>
                            <button onClick={() => setShowPanel(false)} className="text-base-content/40 hover:text-base-content">
                                <X className="w-4 h-4" />
                            </button>
                        </div>

                        <div className="max-h-96 overflow-y-auto divide-y divide-base-200">
                            {notifications.length === 0 ? (
                                <div className="p-8 text-center text-base-content/30">
                                    <Bell className="w-10 h-10 mx-auto mb-3 opacity-20" />
                                    <p className="text-sm">Aucune notification</p>
                                </div>
                            ) : (
                                notifications.map(n => (
                                    <div
                                        key={n.id}
                                        onClick={() => markRead(n.id)}
                                        className={`p-4 cursor-pointer hover:bg-base-200 transition-colors ${!n.read ? 'bg-primary/5' : ''}`}
                                    >
                                        <div className="flex items-start gap-3">
                                            <div className="mt-0.5">{getIcon(n.type)}</div>
                                            <div className="flex-1 min-w-0">
                                                <div className="flex items-center justify-between">
                                                    <p className="text-sm font-medium text-base-content truncate">{n.title}</p>
                                                    <button
                                                        onClick={e => { e.stopPropagation(); removeNotif(n.id); }}
                                                        className="text-base-content/30 hover:text-base-content/60 ml-2 shrink-0"
                                                    >
                                                        <X className="w-3.5 h-3.5" />
                                                    </button>
                                                </div>
                                                {n.message && (
                                                    <p className="text-xs text-base-content/50 mt-0.5 line-clamp-2">{n.message}</p>
                                                )}
                                                <p className="text-xs text-base-content/30 mt-1">{fmtTime(n.timestamp)}</p>
                                            </div>
                                        </div>
                                    </div>
                                ))
                            )}
                        </div>
                    </div>
                )}
            </div>

            {/* ── Toasts (3 plus récents non lus) ── */}
            <div className="fixed bottom-24 right-4 z-50 space-y-2 pointer-events-none">
                {notifications.filter(n => !n.read).slice(0, 3).map(n => (
                    <div
                        key={n.id}
                        className="bg-base-100 border border-base-200 rounded-xl shadow-xl p-3 w-72 flex items-start gap-3 pointer-events-auto"
                    >
                        <div className="mt-0.5">{getIcon(n.type)}</div>
                        <div className="flex-1 min-w-0">
                            <p className="text-sm font-medium text-base-content">{n.title}</p>
                            {n.message && <p className="text-xs text-base-content/50 mt-0.5 line-clamp-2">{n.message}</p>}
                        </div>
                        <button onClick={() => removeNotif(n.id)} className="text-base-content/30 hover:text-base-content/60 shrink-0">
                            <X className="w-4 h-4" />
                        </button>
                    </div>
                ))}
            </div>

            {/* ── Bouton SOS (fixe en bas à gauche) ── */}
            <BoutonSOS />
        </>
    );
}

// ── Hook utilitaire (compatibilité rétrograde) ────────────────────────────
export const useNotification = () => ({
    notifyTrajetCommence: (msg: string) =>
        window.dispatchEvent(new CustomEvent('trajet-commence', { detail: { message: msg } })),
    notifyTrajetTermine: (msg: string) =>
        window.dispatchEvent(new CustomEvent('trajet-termine', { detail: { message: msg } })),
    notifyPositionUpdate: (msg: string) =>
        window.dispatchEvent(new CustomEvent('position-update', { detail: { message: msg } })),
});
