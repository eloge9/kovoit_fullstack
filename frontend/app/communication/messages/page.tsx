"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import { useSearchParams } from "next/navigation";
import { useAuth } from "@/src/hooks/useAuth";
import { useChat, ChatMessage } from "@/src/hooks/useChat";
import { getConversations, getHistorique, envoyerMessage, getInfoUtilisateur } from "@/src/services/messagerie.service";
import { getMediaUrl } from "@/src/utils/imageUtils";
import { Send, MessageSquare, Wifi, WifiOff } from "lucide-react";

// ── Types ─────────────────────────────────────────────────────────────────

interface Conversation {
    utilisateur: {
        id:          string;
        username:    string;
        nom:         string;
        photo_profil: string | null;
        role:        string;
    };
    dernier_message: {
        id:           number;
        contenu:      string;
        expediteur_id: string;
        timestamp:    string;
    };
    non_lus: number;
}

// ── Composant principal ───────────────────────────────────────────────────

export default function MessagesPage() {
    const { user }       = useAuth();
    const searchParams   = useSearchParams();
    const initUserId     = searchParams.get("avec");

    const [conversations,     setConversations]     = useState<Conversation[]>([]);
    const [selectedUserId,    setSelectedUserId]    = useState<string | null>(initUserId);
    const [selectedUser,      setSelectedUser]      = useState<Conversation["utilisateur"] | null>(null);
    const [messages,          setMessages]          = useState<ChatMessage[]>([]);
    const [input,             setInput]             = useState("");
    const [loadingConvs,      setLoadingConvs]      = useState(true);
    const [loadingMessages,   setLoadingMessages]   = useState(false);

    const messagesEndRef = useRef<HTMLDivElement>(null);
    const typingTimeout  = useRef<NodeJS.Timeout | null>(null);

    // ── WebSocket chat ─────────────────────────────────────────────────

    const handleNewMessage = useCallback((msg: ChatMessage) => {
        setMessages(prev => {
            // Éviter les doublons si le message est déjà dans la liste (REST fallback)
            if (prev.find(m => m.id === msg.id)) return prev;
            return [...prev, msg];
        });
    }, []);

    const { isConnected, isTyping, sendMessage, sendTyping, markAsRead } = useChat({
        otherUserId:   selectedUserId,
        currentUserId: user?.id ?? null,
        onMessage:     handleNewMessage,
    });

    // Marquer comme lu quand on ouvre une conversation
    useEffect(() => {
        if (selectedUserId && isConnected) markAsRead();
    }, [selectedUserId, isConnected, markAsRead]);

    // ── Scroll automatique ─────────────────────────────────────────────

    useEffect(() => {
        messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
    }, [messages]);

    // ── Charger les conversations ──────────────────────────────────────

    useEffect(() => {
        getConversations()
            .then(setConversations)
            .catch(() => {})
            .finally(() => setLoadingConvs(false));
    }, []);

    // ── Mettre à jour l'interlocuteur sélectionné ──────────────────────
    // Séparé de l'historique pour ne pas re-fetcher les messages quand
    // la liste des conversations change (ex: chargement initial).

    useEffect(() => {
        if (!selectedUserId) return;
        const conv = conversations.find(c => c.utilisateur.id === selectedUserId);
        if (conv) {
            setSelectedUser(conv.utilisateur);
        } else if (!selectedUser || selectedUser.id !== selectedUserId) {
            // Nouvelle conversation — récupérer les infos de l'interlocuteur
            getInfoUtilisateur(selectedUserId)
                .then(info => setSelectedUser(info))
                .catch(() => {});
        }
    }, [selectedUserId, conversations]);

    // ── Charger l'historique quand on change de conversation ──────────

    useEffect(() => {
        if (!selectedUserId) return;
        setLoadingMessages(true);
        setMessages([]);

        getHistorique(selectedUserId)
            .then((data: ChatMessage[]) => setMessages(data))
            .catch(() => {})
            .finally(() => setLoadingMessages(false));
    }, [selectedUserId]);

    // ── Envoi d'un message ─────────────────────────────────────────────

    const handleSend = () => {
        const contenu = input.trim();
        if (!contenu || !selectedUserId) return;
        setInput("");

        if (isConnected) {
            sendMessage(contenu);
        } else {
            // Fallback REST si WebSocket non connecté
            envoyerMessage(selectedUserId, contenu)
                .then((msg: ChatMessage) => {
                    setMessages(prev => [...prev, { ...msg, moi: true }]);
                })
                .catch(() => {});
        }
    };

    const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
        if (e.key === "Enter" && !e.shiftKey) {
            e.preventDefault();
            handleSend();
        } else {
            // Indicateur "en train d'écrire"
            sendTyping();
        }
    };

    const formatHeure = (iso: string) =>
        new Date(iso).toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" });

    const formatDate = (iso: string) =>
        new Date(iso).toLocaleDateString("fr-FR", { day: "numeric", month: "short" });

    // ── Rendu ──────────────────────────────────────────────────────────

    return (
        <div className="h-full flex bg-base-200">

            {/* ── Sidebar conversations ── */}
            <aside className="w-80 bg-base-100 border-r border-base-200 flex flex-col">
                <div className="p-4 border-b border-base-200">
                    <h2 className="text-lg font-bold text-base-content flex items-center gap-2">
                        <MessageSquare className="w-5 h-5 text-primary" />
                        Messages
                    </h2>
                </div>

                <div className="flex-1 overflow-y-auto">
                    {loadingConvs ? (
                        <div className="p-4 space-y-3">
                            {[1, 2, 3].map(i => (
                                <div key={i} className="flex gap-3 animate-pulse">
                                    <div className="w-10 h-10 rounded-full bg-base-300" />
                                    <div className="flex-1 space-y-2">
                                        <div className="h-3 bg-base-300 rounded w-3/4" />
                                        <div className="h-3 bg-base-300 rounded w-1/2" />
                                    </div>
                                </div>
                            ))}
                        </div>
                    ) : conversations.length === 0 ? (
                        <div className="p-8 text-center text-base-content/40">
                            <MessageSquare className="w-12 h-12 mx-auto mb-3 opacity-30" />
                            <p className="text-sm">Aucune conversation</p>
                        </div>
                    ) : (
                        conversations.map(conv => (
                            <button
                                key={conv.utilisateur.id}
                                onClick={() => setSelectedUserId(conv.utilisateur.id)}
                                className={`w-full flex items-center gap-3 p-4 border-b border-base-100 hover:bg-base-200 transition-colors text-left ${
                                    selectedUserId === conv.utilisateur.id ? "bg-primary/10" : ""
                                }`}
                            >
                                {/* Avatar */}
                                <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center shrink-0 relative">
                                    {conv.utilisateur.photo_profil ? (
                                        <img
                                            src={getMediaUrl(conv.utilisateur.photo_profil)}
                                            alt=""
                                            className="w-10 h-10 rounded-full object-cover"
                                        />
                                    ) : (
                                        <span className="text-sm font-bold text-primary">
                                            {conv.utilisateur.nom[0]?.toUpperCase()}
                                        </span>
                                    )}
                                    {conv.non_lus > 0 && (
                                        <span className="absolute -top-1 -right-1 bg-error text-white text-xs rounded-full w-4 h-4 flex items-center justify-center">
                                            {conv.non_lus}
                                        </span>
                                    )}
                                </div>

                                {/* Infos */}
                                <div className="flex-1 min-w-0">
                                    <div className="flex items-center justify-between">
                                        <p className={`text-sm font-medium truncate ${
                                            conv.non_lus > 0 ? "text-base-content" : "text-base-content/70"
                                        }`}>
                                            {conv.utilisateur.nom}
                                        </p>
                                        <p className="text-xs text-base-content/40 shrink-0 ml-1">
                                            {formatDate(conv.dernier_message.timestamp)}
                                        </p>
                                    </div>
                                    <p className={`text-xs truncate mt-0.5 ${
                                        conv.non_lus > 0 ? "text-base-content/70 font-medium" : "text-base-content/40"
                                    }`}>
                                        {conv.dernier_message.expediteur_id === user?.id ? "Vous : " : ""}
                                        {conv.dernier_message.contenu}
                                    </p>
                                </div>
                            </button>
                        ))
                    )}
                </div>
            </aside>

            {/* ── Zone de chat ── */}
            <main className="flex-1 flex flex-col">
                {selectedUserId && selectedUser ? (
                    <>
                        {/* Header conversation */}
                        <header className="bg-base-100 border-b border-base-200 px-6 py-3 flex items-center justify-between">
                            <div className="flex items-center gap-3">
                                <div className="w-9 h-9 rounded-full bg-primary/10 flex items-center justify-center">
                                    {selectedUser.photo_profil ? (
                                        <img
                                            src={getMediaUrl(selectedUser.photo_profil)}
                                            alt=""
                                            className="w-9 h-9 rounded-full object-cover"
                                        />
                                    ) : (
                                        <span className="text-sm font-bold text-primary">
                                            {selectedUser.nom[0]?.toUpperCase()}
                                        </span>
                                    )}
                                </div>
                                <div>
                                    <p className="font-semibold text-sm text-base-content">{selectedUser.nom}</p>
                                    <p className="text-xs text-base-content/40 capitalize">{selectedUser.role}</p>
                                </div>
                            </div>

                            {/* Indicateur connexion WS */}
                            <div className={`flex items-center gap-1.5 text-xs ${isConnected ? "text-success" : "text-warning"}`}>
                                {isConnected
                                    ? <><Wifi className="w-3.5 h-3.5" /> Connecté</>
                                    : <><WifiOff className="w-3.5 h-3.5" /> Reconnexion...</>
                                }
                            </div>
                        </header>

                        {/* Messages */}
                        <div className="flex-1 overflow-y-auto p-6 space-y-3">
                            {loadingMessages ? (
                                <div className="flex justify-center py-8">
                                    <span className="loading loading-spinner loading-md text-primary" />
                                </div>
                            ) : messages.length === 0 ? (
                                <div className="text-center py-12 text-base-content/30">
                                    <MessageSquare className="w-10 h-10 mx-auto mb-3 opacity-30" />
                                    <p className="text-sm">Démarrez la conversation</p>
                                </div>
                            ) : (
                                messages.map(msg => (
                                    <div
                                        key={`${msg.id}-${msg.timestamp}`}
                                        className={`flex ${msg.moi ? "justify-end" : "justify-start"}`}
                                    >
                                        <div className={`max-w-xs lg:max-w-md px-4 py-2.5 rounded-2xl ${
                                            msg.moi
                                                ? "bg-primary text-primary-content rounded-br-sm"
                                                : "bg-base-100 text-base-content border border-base-200 rounded-bl-sm"
                                        }`}>
                                            <p className="text-sm whitespace-pre-wrap break-words">
                                                {msg.contenu}
                                            </p>
                                            <p className={`text-xs mt-1 ${
                                                msg.moi ? "text-primary-content/60" : "text-base-content/40"
                                            }`}>
                                                {formatHeure(msg.timestamp)}
                                            </p>
                                        </div>
                                    </div>
                                ))
                            )}

                            {/* Indicateur "en train d'écrire" */}
                            {isTyping && (
                                <div className="flex justify-start">
                                    <div className="bg-base-100 border border-base-200 px-4 py-2.5 rounded-2xl rounded-bl-sm">
                                        <div className="flex gap-1 items-center">
                                            <span className="w-2 h-2 bg-base-content/30 rounded-full animate-bounce" style={{ animationDelay: "0ms" }} />
                                            <span className="w-2 h-2 bg-base-content/30 rounded-full animate-bounce" style={{ animationDelay: "150ms" }} />
                                            <span className="w-2 h-2 bg-base-content/30 rounded-full animate-bounce" style={{ animationDelay: "300ms" }} />
                                        </div>
                                    </div>
                                </div>
                            )}
                            <div ref={messagesEndRef} />
                        </div>

                        {/* Saisie */}
                        <div className="bg-base-100 border-t border-base-200 p-4">
                            <div className="flex items-end gap-3">
                                <textarea
                                    className="flex-1 textarea textarea-bordered resize-none text-sm min-h-10 max-h-32"
                                    placeholder="Écrivez un message..."
                                    value={input}
                                    rows={1}
                                    onChange={e => setInput(e.target.value)}
                                    onKeyDown={handleKeyDown}
                                />
                                <button
                                    onClick={handleSend}
                                    disabled={!input.trim()}
                                    className="btn btn-primary btn-square"
                                >
                                    <Send className="w-4 h-4" />
                                </button>
                            </div>
                            <p className="text-xs text-base-content/30 mt-1.5">
                                Entrée pour envoyer · Maj+Entrée pour sauter une ligne
                            </p>
                        </div>
                    </>
                ) : (
                    /* Écran vide — aucune conversation sélectionnée */
                    <div className="flex-1 flex flex-col items-center justify-center text-base-content/30">
                        <MessageSquare className="w-16 h-16 mb-4 opacity-20" />
                        <p className="text-lg font-medium">Sélectionnez une conversation</p>
                        <p className="text-sm mt-1">ou démarrez-en une depuis une réservation</p>
                    </div>
                )}
            </main>
        </div>
    );
}
