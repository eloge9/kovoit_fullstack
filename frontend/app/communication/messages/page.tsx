"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import { useSearchParams } from "next/navigation";
import { useAuth } from "@/src/hooks/useAuth";
import { useChat, ChatMessage } from "@/src/hooks/useChat";
import {
  getConversations, getMessages, envoyerMessageRest,
  ConversationItem, InterlocuteurInfo,
} from "@/src/services/messagerie.service";
import { getMediaUrl } from "@/src/utils/imageUtils";
import {
  Send, MessageSquare, Wifi, WifiOff,
  Lock, ChevronLeft, Car, AlertCircle,
} from "lucide-react";

// ── Utilitaires d'affichage ───────────────────────────────────────────────────

function Avatar({ user, size = 10 }: { user: InterlocuteurInfo; size?: number }) {
  const cls = `w-${size} h-${size} rounded-full object-cover`;
  if (user.photo_profil) {
    return <img src={getMediaUrl(user.photo_profil)} alt="" className={cls} />;
  }
  return (
    <div className={`w-${size} h-${size} rounded-full bg-primary/15 flex items-center justify-center`}>
      <span className="text-sm font-bold text-primary">
        {user.nom[0]?.toUpperCase() ?? "?"}
      </span>
    </div>
  );
}

function formatHeure(iso: string) {
  return new Date(iso).toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" });
}

function formatDateLabel(iso: string) {
  const d = new Date(iso);
  const today = new Date();
  const diff = Math.floor((today.getTime() - d.getTime()) / 86400000);
  if (diff === 0) return "Aujourd'hui";
  if (diff === 1) return "Hier";
  return d.toLocaleDateString("fr-FR", { day: "numeric", month: "short" });
}

// ── Composant principal ───────────────────────────────────────────────────────

export default function MessagesPage() {
  const { user }     = useAuth();
  const searchParams = useSearchParams();
  const initConvId   = searchParams.get("conv") ? Number(searchParams.get("conv")) : null;

  const [conversations,  setConversations]  = useState<ConversationItem[]>([]);
  const [selectedConv,   setSelectedConv]   = useState<ConversationItem | null>(null);
  const [messages,       setMessages]       = useState<ChatMessage[]>([]);
  const [input,          setInput]          = useState("");
  const [loadingConvs,   setLoadingConvs]   = useState(true);
  const [loadingMsgs,    setLoadingMsgs]    = useState(false);
  const [showSidebar,    setShowSidebar]    = useState(true);  // mobile toggle

  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef       = useRef<HTMLTextAreaElement>(null);

  // ── Notifications toast ────────────────────────────────────────────────────

  const [toast, setToast] = useState<{ text: string; convId: number } | null>(null);

  const showToast = useCallback((text: string, convId: number) => {
    setToast({ text, convId });
    setTimeout(() => setToast(null), 4000);
  }, []);

  // ── WebSocket de la conversation active ────────────────────────────────────

  const handleNewMessage = useCallback((msg: ChatMessage) => {
    setMessages(prev => prev.find(m => m.id === msg.id) ? prev : [...prev, msg]);
    // Mettre à jour le dernier message dans la liste
    setConversations(prev => prev.map(c =>
      c.id === selectedConv?.id
        ? { ...c, dernier_message: { id: msg.id, contenu: msg.contenu, auteur_id: msg.auteur_id, timestamp: msg.timestamp, moi: msg.moi }, non_lus: 0 }
        : c
    ));
  }, [selectedConv?.id]);

  const { isConnected, isTyping, sendMessage, sendTyping, markAsRead, convStatut } = useChat({
    convId:        selectedConv?.id ?? null,
    currentUserId: user?.id ?? null,
    onMessage:     handleNewMessage,
    onNotification: (data) => {
      if (data.conv_id !== selectedConv?.id) {
        showToast(`${data.auteur} : ${data.contenu}`, data.conv_id as number);
        setConversations(prev => prev.map(c =>
          c.id === data.conv_id ? { ...c, non_lus: c.non_lus + 1 } : c
        ));
      }
    },
  });

  // Statut temps réel de la conversation
  const statutEffectif = convStatut ?? selectedConv?.statut ?? null;
  const peutEcrire = statutEffectif === 'ouverte' && isConnected;

  // Marquer comme lu à l'ouverture
  useEffect(() => {
    if (selectedConv && isConnected) {
      markAsRead();
      setConversations(prev => prev.map(c =>
        c.id === selectedConv.id ? { ...c, non_lus: 0 } : c
      ));
    }
  }, [selectedConv?.id, isConnected, markAsRead]);

  // Scroll bas
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  // ── Charger les conversations ──────────────────────────────────────────────

  useEffect(() => {
    getConversations()
      .then(data => {
        setConversations(data);
        if (initConvId) {
          const found = data.find(c => c.id === initConvId);
          if (found) openConversation(found);
        }
      })
      .catch(() => {})
      .finally(() => setLoadingConvs(false));
  }, []); // eslint-disable-line

  // ── Ouvrir une conversation ────────────────────────────────────────────────

  const openConversation = useCallback((conv: ConversationItem) => {
    setSelectedConv(conv);
    setMessages([]);
    setLoadingMsgs(true);
    setShowSidebar(false);  // mobile: masquer sidebar
    getMessages(conv.id)
      .then(setMessages)
      .catch(() => {})
      .finally(() => setLoadingMsgs(false));
  }, []);

  // ── Envoi ──────────────────────────────────────────────────────────────────

  const handleSend = useCallback(() => {
    const contenu = input.trim();
    if (!contenu || !selectedConv) return;
    setInput("");
    inputRef.current?.focus();

    if (isConnected) {
      sendMessage(contenu);
    } else {
      // Fallback REST
      envoyerMessageRest(selectedConv.id, contenu)
        .then(msg => setMessages(prev => [...prev, msg]))
        .catch(() => {});
    }
  }, [input, selectedConv, isConnected, sendMessage]);

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    } else {
      sendTyping();
    }
  };

  // ── Interlocuteur principal d'une conversation ─────────────────────────────

  const interlocuteur = selectedConv?.interlocuteurs[0] ?? null;

  // ── Rendu ──────────────────────────────────────────────────────────────────

  return (
    <div className="flex h-[calc(100vh-4rem)] bg-base-200 relative">

      {/* ── Toast notification ──────────────────────────────────────────── */}
      {toast && (
        <div
          className="fixed top-20 right-4 z-50 bg-base-100 border border-base-300 shadow-xl rounded-xl px-4 py-3 flex items-start gap-3 max-w-xs cursor-pointer"
          onClick={() => {
            const c = conversations.find(x => x.id === toast.convId);
            if (c) openConversation(c);
            setToast(null);
          }}
        >
          <MessageSquare className="w-4 h-4 text-primary mt-0.5 shrink-0" />
          <p className="text-xs text-base-content">{toast.text}</p>
        </div>
      )}

      {/* ════════════════════════════════════════════════════════════════
          Colonne gauche — Liste des conversations
      ═════════════════════════════════════════════════════════════════ */}
      <aside className={`
        w-full md:w-80 bg-base-100 border-r border-base-200 flex flex-col
        ${showSidebar ? "flex" : "hidden md:flex"}
      `}>
        <div className="p-4 border-b border-base-200 shrink-0">
          <h2 className="text-base font-bold flex items-center gap-2">
            <MessageSquare className="w-4 h-4 text-primary" />
            Messages
          </h2>
        </div>

        <div className="flex-1 overflow-y-auto">
          {loadingConvs ? (
            <div className="p-4 space-y-3">
              {[1, 2, 3].map(i => (
                <div key={i} className="flex gap-3 animate-pulse">
                  <div className="w-10 h-10 rounded-full bg-base-300 shrink-0" />
                  <div className="flex-1 space-y-2 py-1">
                    <div className="h-3 bg-base-300 rounded w-3/4" />
                    <div className="h-3 bg-base-300 rounded w-1/2" />
                  </div>
                </div>
              ))}
            </div>
          ) : conversations.length === 0 ? (
            <div className="p-8 text-center text-base-content/40">
              <MessageSquare className="w-10 h-10 mx-auto mb-3 opacity-25" />
              <p className="text-sm">Aucune conversation</p>
              <p className="text-xs mt-1 opacity-70">Réservez un trajet pour démarrer</p>
            </div>
          ) : (
            conversations.map(conv => {
              const autre = conv.interlocuteurs[0];
              const isActive = selectedConv?.id === conv.id;
              return (
                <button
                  key={conv.id}
                  onClick={() => openConversation(conv)}
                  className={`w-full flex items-center gap-3 px-4 py-3 border-b border-base-100 hover:bg-base-200 transition-colors text-left ${isActive ? "bg-primary/8" : ""}`}
                >
                  <div className="relative shrink-0">
                    {autre ? <Avatar user={autre} size={10} /> : (
                      <div className="w-10 h-10 rounded-full bg-base-300 flex items-center justify-center">
                        <MessageSquare className="w-4 h-4 text-base-content/40" />
                      </div>
                    )}
                    {conv.non_lus > 0 && (
                      <span className="absolute -top-1 -right-1 bg-error text-error-content text-xs rounded-full w-4 h-4 flex items-center justify-center font-bold">
                        {conv.non_lus > 9 ? "9+" : conv.non_lus}
                      </span>
                    )}
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between gap-1">
                      <p className={`text-sm truncate ${conv.non_lus > 0 ? "font-semibold text-base-content" : "text-base-content/80"}`}>
                        {autre?.nom ?? "Conversation"}
                      </p>
                      {conv.dernier_message && (
                        <span className="text-xs text-base-content/40 shrink-0">
                          {formatDateLabel(conv.dernier_message.timestamp)}
                        </span>
                      )}
                    </div>

                    {conv.trajet && (
                      <p className="text-xs text-base-content/40 truncate flex items-center gap-1">
                        <Car className="w-3 h-3 inline shrink-0" />
                        {conv.trajet.depart} → {conv.trajet.destination}
                      </p>
                    )}

                    {conv.dernier_message ? (
                      <p className={`text-xs truncate ${conv.non_lus > 0 ? "text-base-content/60 font-medium" : "text-base-content/40"}`}>
                        {conv.dernier_message.moi ? "Vous : " : ""}
                        {conv.dernier_message.contenu}
                      </p>
                    ) : (
                      <p className="text-xs text-base-content/30 italic">Démarrez la conversation</p>
                    )}
                  </div>

                  {conv.statut !== 'ouverte' && (
                    <Lock className="w-3.5 h-3.5 text-warning shrink-0" />
                  )}
                </button>
              );
            })
          )}
        </div>
      </aside>

      {/* ════════════════════════════════════════════════════════════════
          Colonne droite — Conversation active
      ═════════════════════════════════════════════════════════════════ */}
      <main className={`
        flex-1 flex flex-col min-w-0
        ${!showSidebar ? "flex" : "hidden md:flex"}
      `}>
        {selectedConv && interlocuteur ? (
          <>
            {/* ── Header ─────────────────────────────────────────────── */}
            <header className="bg-base-100 border-b border-base-200 px-4 py-3 flex items-center gap-3 shrink-0">
              {/* Retour mobile */}
              <button
                className="md:hidden btn btn-ghost btn-sm btn-square"
                onClick={() => setShowSidebar(true)}
              >
                <ChevronLeft className="w-4 h-4" />
              </button>

              <Avatar user={interlocuteur} size={9} />

              <div className="flex-1 min-w-0">
                <p className="font-semibold text-sm truncate">{interlocuteur.nom}</p>
                {selectedConv.trajet && (
                  <p className="text-xs text-base-content/40 truncate">
                    {selectedConv.trajet.depart} → {selectedConv.trajet.destination}
                  </p>
                )}
              </div>

              <div className={`flex items-center gap-1.5 text-xs shrink-0 ${isConnected ? "text-success" : "text-warning"}`}>
                {isConnected
                  ? <><Wifi className="w-3.5 h-3.5" /> Connecté</>
                  : <><WifiOff className="w-3.5 h-3.5" /> Reconnexion...</>
                }
              </div>
            </header>

            {/* ── Bannière lecture seule ──────────────────────────────── */}
            {statutEffectif !== 'ouverte' && (
              <div className="bg-warning/10 border-b border-warning/30 px-4 py-2 flex items-center gap-2">
                <Lock className="w-3.5 h-3.5 text-warning" />
                <p className="text-xs text-warning-content">
                  {statutEffectif === 'lecture_seule'
                    ? "Conversation en lecture seule — la réservation a été refusée."
                    : "Cette conversation est fermée."}
                </p>
              </div>
            )}

            {/* ── Messages ────────────────────────────────────────────── */}
            <div className="flex-1 overflow-y-auto px-4 py-4 space-y-2">
              {loadingMsgs ? (
                <div className="flex justify-center py-10">
                  <span className="loading loading-spinner loading-md text-primary" />
                </div>
              ) : messages.length === 0 ? (
                <div className="text-center py-16 text-base-content/30">
                  <MessageSquare className="w-10 h-10 mx-auto mb-3 opacity-20" />
                  <p className="text-sm">Démarrez la conversation</p>
                  <p className="text-xs mt-1 opacity-70">Posez une question sur le trajet</p>
                </div>
              ) : (
                messages.map((msg, idx) => {
                  const showDate = idx === 0 || (
                    new Date(msg.timestamp).toDateString() !==
                    new Date(messages[idx - 1].timestamp).toDateString()
                  );
                  return (
                    <div key={msg.id}>
                      {showDate && (
                        <div className="text-center my-3">
                          <span className="text-xs bg-base-300 text-base-content/50 px-3 py-1 rounded-full">
                            {formatDateLabel(msg.timestamp)}
                          </span>
                        </div>
                      )}
                      <div className={`flex ${msg.moi ? "justify-end" : "justify-start"}`}>
                        {!msg.moi && (
                          <div className="w-7 h-7 rounded-full bg-primary/15 flex items-center justify-center text-xs font-bold text-primary mr-2 shrink-0 self-end mb-0.5">
                            {interlocuteur.nom[0]?.toUpperCase()}
                          </div>
                        )}
                        <div className={`max-w-[75%] md:max-w-md px-4 py-2.5 rounded-2xl shadow-sm ${
                          msg.moi
                            ? "bg-primary text-primary-content rounded-br-sm"
                            : "bg-base-100 text-base-content border border-base-200 rounded-bl-sm"
                        }`}>
                          <p className="text-sm whitespace-pre-wrap break-words leading-relaxed">
                            {msg.contenu}
                          </p>
                          <p className={`text-[10px] mt-1 text-right ${msg.moi ? "text-primary-content/60" : "text-base-content/40"}`}>
                            {formatHeure(msg.timestamp)}
                          </p>
                        </div>
                      </div>
                    </div>
                  );
                })
              )}

              {/* Indicateur "en train d'écrire" */}
              {isTyping && (
                <div className="flex items-center gap-2">
                  <div className="w-7 h-7 rounded-full bg-primary/15 flex items-center justify-center text-xs font-bold text-primary shrink-0">
                    {interlocuteur.nom[0]?.toUpperCase()}
                  </div>
                  <div className="bg-base-100 border border-base-200 px-4 py-2.5 rounded-2xl rounded-bl-sm shadow-sm">
                    <div className="flex gap-1 items-center h-4">
                      {[0, 150, 300].map(delay => (
                        <span
                          key={delay}
                          className="w-2 h-2 bg-base-content/30 rounded-full animate-bounce"
                          style={{ animationDelay: `${delay}ms` }}
                        />
                      ))}
                    </div>
                  </div>
                </div>
              )}
              <div ref={messagesEndRef} />
            </div>

            {/* ── Zone de saisie ──────────────────────────────────────── */}
            <div className="bg-base-100 border-t border-base-200 p-3 shrink-0">
              {peutEcrire ? (
                <div className="flex items-end gap-2">
                  <textarea
                    ref={inputRef}
                    className="flex-1 textarea textarea-bordered resize-none text-sm min-h-10 max-h-32 leading-relaxed"
                    placeholder="Écrivez un message..."
                    value={input}
                    rows={1}
                    onChange={e => setInput(e.target.value)}
                    onKeyDown={handleKeyDown}
                  />
                  <button
                    onClick={handleSend}
                    disabled={!input.trim()}
                    className="btn btn-primary btn-square shrink-0"
                  >
                    <Send className="w-4 h-4" />
                  </button>
                </div>
              ) : (
                <div className="flex items-center gap-2 text-base-content/40 text-sm py-1">
                  {isConnected
                    ? <><Lock className="w-4 h-4" /> Conversation en lecture seule</>
                    : <><WifiOff className="w-4 h-4" /> Reconnexion en cours...</>
                  }
                </div>
              )}
              {peutEcrire && (
                <p className="text-xs text-base-content/30 mt-1">
                  Entrée pour envoyer · Maj+Entrée pour sauter une ligne
                </p>
              )}
            </div>
          </>
        ) : (
          /* ── Écran vide ─────────────────────────────────────────────── */
          <div className="flex-1 flex flex-col items-center justify-center text-base-content/30 p-8">
            <MessageSquare className="w-16 h-16 mb-4 opacity-15" />
            <p className="text-lg font-medium">Sélectionnez une conversation</p>
            <p className="text-sm mt-1 text-center">
              Ou réservez un trajet pour démarrer une discussion avec un conducteur
            </p>
          </div>
        )}
      </main>
    </div>
  );
}
