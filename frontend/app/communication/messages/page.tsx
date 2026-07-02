"use client";

import { Suspense, useEffect, useRef, useState, useCallback } from "react";
import { useSearchParams } from "next/navigation";
import { useAuth } from "@/src/hooks/useAuth";
import { useChat } from "@/src/hooks/useChat";
import {
  getConversations, getMessages,
  envoyerMessageRest, envoyerAudio,
  modifierMessage, supprimerMessage, reagirMessage,
  type ConversationItem, type ChatMessage, type InterlocuteurInfo, type ReplyInfo,
} from "@/src/services/messagerie.service";
import { getMediaUrl } from "@/src/utils/imageUtils";
import {
  Send, MessageSquare, Wifi, WifiOff,
  Lock, ChevronLeft, Car, Mic, MicOff,
  Play, Pause, Square, CornerUpLeft, Edit2,
  Trash2, SmilePlus, X, Check, CheckCheck,
} from "lucide-react";

// ── Utilitaires ───────────────────────────────────────────────────────────────

function Avatar({ user, size = 10 }: { user: InterlocuteurInfo; size?: number }) {
  const cls = `w-${size} h-${size} rounded-full object-cover`;
  if (user.photo_profil) return <img src={getMediaUrl(user.photo_profil)} alt="" className={cls} />;
  return (
    <div className={`w-${size} h-${size} rounded-full bg-primary/15 flex items-center justify-center shrink-0`}>
      <span className="text-sm font-bold text-primary">{user.nom[0]?.toUpperCase() ?? "?"}</span>
    </div>
  );
}

function fmtHeure(iso: string) {
  return new Date(iso).toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" });
}

function fmtDateLabel(iso: string) {
  const d    = new Date(iso);
  const diff = Math.floor((Date.now() - d.getTime()) / 86400000);
  if (diff === 0) return "Aujourd'hui";
  if (diff === 1) return "Hier";
  return d.toLocaleDateString("fr-FR", { day: "numeric", month: "short" });
}

function fmtDuration(sec: number | null) {
  if (!sec) return "0:00";
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  return `${m}:${s.toString().padStart(2, "0")}`;
}

const EMOJIS = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

// ── Lecteur audio ─────────────────────────────────────────────────────────────

function AudioPlayer({ url, duration, isMine }: { url: string; duration: number | null; isMine: boolean }) {
  const [playing,  setPlaying]  = useState(false);
  const [errored,  setErrored]  = useState(false);
  const [current,  setCurrent]  = useState(0);
  const [total,    setTotal]    = useState(duration ?? 0);
  const [retryKey, setRetryKey] = useState(0);
  const audioRef = useRef<HTMLAudioElement | null>(null);

  useEffect(() => {
    if (!url) return;
    setErrored(false);
    const audio = new Audio(url);
    audioRef.current = audio;
    audio.onloadedmetadata = () => setTotal(Math.round(audio.duration));
    audio.ontimeupdate    = () => setCurrent(Math.round(audio.currentTime));
    audio.onended         = () => { setPlaying(false); setCurrent(0); };
    audio.onerror         = () => {
      setPlaying(false);
      setErrored(true);
      console.warn(
        `[AudioPlayer] echec chargement — url=${url} code=${audio.error?.code ?? "n/a"} ` +
        `message=${audio.error?.message || "n/a"} networkState=${audio.networkState} readyState=${audio.readyState}`,
      );
    };
    return () => { audio.pause(); audioRef.current = null; };
  }, [url, retryKey]);

  const toggle = () => {
    if (!audioRef.current || errored) return;
    if (playing) {
      audioRef.current.pause();
      setPlaying(false);
    } else {
      audioRef.current.play().then(() => setPlaying(true)).catch(err => {
        setPlaying(false);
        setErrored(true);
        console.warn(`[AudioPlayer] echec lecture — ${err?.name ?? "?"}: ${err?.message ?? err}`);
      });
    }
  };

  const ratio = total > 0 ? current / total : 0;
  const colorBtn = isMine ? "bg-white/20 hover:bg-white/30 text-white" : "bg-primary/10 hover:bg-primary/20 text-primary";
  const linkCls  = isMine ? "text-white/70 hover:text-white" : "text-primary hover:text-primary-focus";

  if (errored) {
    return (
      <div className="flex items-center gap-2 min-w-[220px]">
        <div className={`w-9 h-9 rounded-full flex items-center justify-center shrink-0 ${isMine ? "bg-white/20" : "bg-error/10"}`}>
          <MicOff className={`w-4 h-4 ${isMine ? "text-white" : "text-error"}`} />
        </div>
        <div className="flex-1 min-w-0">
          <p className={`text-xs ${isMine ? "text-white/80" : "text-error"}`}>
            Impossible de charger le message vocal.
          </p>
          <div className="flex gap-3 mt-0.5">
            <button onClick={() => setRetryKey(k => k + 1)} className={`text-[11px] underline ${linkCls}`}>
              Réessayer
            </button>
            <a href={url} download target="_blank" rel="noopener noreferrer" className={`text-[11px] underline ${linkCls}`}>
              Télécharger
            </a>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex items-center gap-3 min-w-[180px]">
      <button onClick={toggle}
        className={`w-9 h-9 rounded-full flex items-center justify-center shrink-0 transition ${colorBtn}`}>
        {playing ? <Pause className="w-4 h-4" /> : <Play className="w-4 h-4" />}
      </button>
      <div className="flex-1">
        <div className={`w-full h-1.5 rounded-full ${isMine ? "bg-white/20" : "bg-base-300"}`}>
          <div className={`h-full rounded-full transition-all ${isMine ? "bg-white" : "bg-primary"}`}
            style={{ width: `${ratio * 100}%` }} />
        </div>
        <p className={`text-[10px] mt-1 ${isMine ? "text-white/60" : "text-base-content/40"}`}>
          {fmtDuration(playing ? current : total)}
        </p>
      </div>
      <Mic className={`w-3.5 h-3.5 shrink-0 ${isMine ? "text-white/50" : "text-base-content/30"}`} />
    </div>
  );
}

// ── Enregistreur audio ────────────────────────────────────────────────────────

function AudioRecorder({ onSend, onCancel }: {
  onSend: (blob: Blob, duration: number) => void;
  onCancel: () => void;
}) {
  const [recording,  setRecording]  = useState(false);
  const [elapsed,    setElapsed]    = useState(0);
  const mediaRef    = useRef<MediaRecorder | null>(null);
  const chunksRef   = useRef<Blob[]>([]);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const start = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mr = new MediaRecorder(stream);
      mediaRef.current = mr;
      chunksRef.current = [];
      mr.ondataavailable = e => chunksRef.current.push(e.data);
      mr.start();
      setRecording(true);
      setElapsed(0);
      intervalRef.current = setInterval(() => setElapsed(s => s + 1), 1000);
    } catch { onCancel(); }
  };

  const stop = () => {
    if (!mediaRef.current) return;
    const duration = elapsed;
    mediaRef.current.onstop = () => {
      const blob = new Blob(chunksRef.current, { type: 'audio/webm' });
      onSend(blob, duration);
      mediaRef.current?.stream.getTracks().forEach(t => t.stop());
    };
    mediaRef.current.stop();
    setRecording(false);
    if (intervalRef.current) clearInterval(intervalRef.current);
  };

  useEffect(() => {
    start();
    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
      mediaRef.current?.stop();
    };
  }, []); // eslint-disable-line

  return (
    <div className="flex items-center gap-3 flex-1 bg-error/10 rounded-xl px-4 py-2 border border-error/20">
      <span className="w-2 h-2 rounded-full bg-error animate-pulse shrink-0" />
      <span className="text-sm text-error font-medium flex-1">
        {fmtDuration(elapsed)} — Enregistrement…
      </span>
      <button onClick={onCancel} className="btn btn-ghost btn-xs text-base-content/50">
        <X className="w-4 h-4" />
      </button>
      <button onClick={stop} className="btn btn-error btn-sm rounded-full gap-1">
        <Square className="w-3.5 h-3.5" /> Envoyer
      </button>
    </div>
  );
}

// ── Bulle de message ──────────────────────────────────────────────────────────

function MessageBubble({
  msg, isMine, interlocuteur, isGroupe, canEdit, onReply, onEdit, onDelete, onReact,
}: {
  msg:            ChatMessage;
  isMine:         boolean;
  interlocuteur:  InterlocuteurInfo | null;
  isGroupe:       boolean;
  canEdit:        boolean;
  onReply:        (msg: ChatMessage) => void;
  onEdit:         (msg: ChatMessage) => void;
  onDelete:       (msg: ChatMessage) => void;
  onReact:        (msg: ChatMessage, emoji: string) => void;
}) {
  const [showMenu,   setShowMenu]   = useState(false);
  const [showEmojis, setShowEmojis] = useState(false);

  if (msg.deleted) {
    return (
      <div className={`flex ${isMine ? "justify-end" : "justify-start"} mb-1`}>
        <div className="text-xs text-base-content/30 italic px-3 py-1.5 bg-base-200 rounded-xl border border-base-300">
          Ce message a été supprimé.
        </div>
      </div>
    );
  }

  const bubbleCls = isMine
    ? "bg-primary text-primary-content rounded-2xl rounded-br-sm"
    : "bg-base-100 text-base-content border border-base-200 rounded-2xl rounded-bl-sm";

  const avatarLetter = isGroupe
    ? (msg.username[0]?.toUpperCase() ?? "?")
    : (interlocuteur?.nom[0]?.toUpperCase() ?? "?");

  return (
    <div className={`flex ${isMine ? "justify-end" : "justify-start"} mb-1 group relative`}>
      {/* Avatar */}
      {!isMine && (
        <div className="w-7 h-7 rounded-full bg-primary/15 flex items-center justify-center text-xs font-bold text-primary mr-2 shrink-0 self-end mb-0.5">
          {avatarLetter}
        </div>
      )}

      <div className="max-w-[75%] md:max-w-md space-y-0.5">
        {/* Nom de l'auteur (groupes uniquement) */}
        {isGroupe && !isMine && (
          <p className="text-[11px] font-semibold text-primary/70 px-1">{msg.username}</p>
        )}
        {/* Réponse citée */}
        {msg.reply_to && (
          <div className={`text-xs px-3 py-1.5 rounded-t-xl border-l-2 border-primary/60 ${
            isMine ? "bg-white/10 text-white/70" : "bg-base-200 text-base-content/50"
          }`}>
            <p className="font-semibold">{msg.reply_to.username}</p>
            <p className="truncate">
              {msg.reply_to.message_type === 'audio' ? '🎵 Message vocal' : msg.reply_to.contenu}
            </p>
          </div>
        )}

        {/* Bulle principale */}
        <div
          className={`px-4 py-2.5 shadow-sm cursor-pointer select-text ${bubbleCls} ${msg.reply_to ? "rounded-tl-none" : ""}`}
          onClick={() => { setShowMenu(m => !m); setShowEmojis(false); }}
        >
          {msg.message_type === 'audio' && msg.audio_url ? (
            <AudioPlayer url={getMediaUrl(msg.audio_url)} duration={msg.audio_duration} isMine={isMine} />
          ) : (
            <p className="text-sm whitespace-pre-wrap break-words leading-relaxed">{msg.contenu}</p>
          )}

          {/* Heure + statuts */}
          <div className={`flex items-center gap-1 mt-1 justify-end`}>
            {msg.is_edited && (
              <span className={`text-[10px] ${isMine ? "text-primary-content/50" : "text-base-content/30"}`}>
                Modifié
              </span>
            )}
            <span className={`text-[10px] ${isMine ? "text-primary-content/60" : "text-base-content/40"}`}>
              {fmtHeure(msg.timestamp)}
            </span>
            {isMine && (
              msg.is_read
                ? <CheckCheck className="w-3 h-3 text-blue-400" />
                : <Check className="w-3 h-3 text-primary-content/40" />
            )}
          </div>
        </div>

        {/* Réactions affichées */}
        {Object.keys(msg.reactions).length > 0 && (
          <div className={`flex gap-1 flex-wrap ${isMine ? "justify-end" : "justify-start"}`}>
            {Object.entries(msg.reactions).map(([emoji, r]) => (
              <button
                key={emoji}
                onClick={() => onReact(msg, emoji)}
                className={`text-xs px-2 py-0.5 rounded-full border transition ${
                  r.moi
                    ? "bg-primary/15 border-primary/30 text-primary"
                    : "bg-base-200 border-base-300 text-base-content/60 hover:bg-base-300"
                }`}
              >
                {emoji} {r.count}
              </button>
            ))}
          </div>
        )}

        {/* Menu contextuel */}
        {showMenu && (
          <div className={`absolute z-30 mt-1 bg-base-100 border border-base-200 rounded-xl shadow-xl py-1 min-w-40 ${
            isMine ? "right-0" : "left-8"
          }`}>
            <button className="w-full flex items-center gap-2 px-3 py-2 text-sm hover:bg-base-200 text-left"
              onClick={() => { onReply(msg); setShowMenu(false); }}>
              <CornerUpLeft className="w-3.5 h-3.5 text-base-content/50" /> Répondre
            </button>
            {isMine && canEdit && msg.message_type === 'text' && (
              <button className="w-full flex items-center gap-2 px-3 py-2 text-sm hover:bg-base-200 text-left"
                onClick={() => { onEdit(msg); setShowMenu(false); }}>
                <Edit2 className="w-3.5 h-3.5 text-base-content/50" /> Modifier
              </button>
            )}
            <button className="w-full flex items-center gap-2 px-3 py-2 text-sm hover:bg-base-200 text-left"
              onClick={() => { setShowEmojis(v => !v); }}>
              <SmilePlus className="w-3.5 h-3.5 text-base-content/50" /> Réagir
            </button>
            {isMine && (
              <button className="w-full flex items-center gap-2 px-3 py-2 text-sm hover:bg-error/10 text-error text-left"
                onClick={() => { onDelete(msg); setShowMenu(false); }}>
                <Trash2 className="w-3.5 h-3.5" /> Supprimer
              </button>
            )}
          </div>
        )}

        {/* Sélecteur d'emojis */}
        {showEmojis && (
          <div className={`absolute z-30 mt-1 bg-base-100 border border-base-200 rounded-2xl shadow-xl px-3 py-2 flex gap-2 ${
            isMine ? "right-0" : "left-8"
          }`}>
            {EMOJIS.map(e => (
              <button key={e} onClick={() => { onReact(msg, e); setShowEmojis(false); setShowMenu(false); }}
                className="text-xl hover:scale-125 transition-transform">
                {e}
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

// ── Composant principal ───────────────────────────────────────────────────────

function MessagesContent() {
  const { user }     = useAuth();
  const searchParams = useSearchParams();
  const initConvId   = searchParams.get("conv") ? Number(searchParams.get("conv")) : null;

  const [conversations,   setConversations]   = useState<ConversationItem[]>([]);
  const [selectedConv,    setSelectedConv]    = useState<ConversationItem | null>(null);
  const [messages,        setMessages]        = useState<ChatMessage[]>([]);
  const [input,           setInput]           = useState("");
  const [loadingConvs,    setLoadingConvs]    = useState(true);
  const [loadingMsgs,     setLoadingMsgs]     = useState(false);
  const [showSidebar,     setShowSidebar]     = useState(true);
  const [recordingAudio,  setRecordingAudio]  = useState(false);
  const [sendingAudio,    setSendingAudio]    = useState(false);
  const [replyTo,         setReplyTo]         = useState<ChatMessage | null>(null);
  const [editingMsg,      setEditingMsg]      = useState<ChatMessage | null>(null);
  const [deleteTarget,    setDeleteTarget]    = useState<ChatMessage | null>(null);
  const [toast,           setToast]           = useState<{ text: string; convId: number } | null>(null);

  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef       = useRef<HTMLTextAreaElement>(null);

  const showToast = useCallback((text: string, convId: number) => {
    setToast({ text, convId });
    setTimeout(() => setToast(null), 4000);
  }, []);

  // ── Callbacks WebSocket ────────────────────────────────────────────────────

  const handleNewMessage = useCallback((msg: ChatMessage) => {
    setMessages(prev => prev.find(m => m.id === msg.id) ? prev : [...prev, msg]);
    setConversations(prev => prev.map(c =>
      c.id === selectedConv?.id
        ? { ...c, dernier_message: { id: msg.id, contenu: msg.message_type === 'audio' ? '🎵 Message vocal' : msg.contenu, auteur_id: msg.auteur_id, timestamp: msg.timestamp, moi: msg.moi }, non_lus: 0 }
        : c,
    ));
  }, [selectedConv?.id]);

  const handleMessageEdited = useCallback((msgId: number, contenu: string, editedAt: string) => {
    setMessages(prev => prev.map(m =>
      m.id === msgId ? { ...m, contenu, is_edited: true, edited_at: editedAt } : m,
    ));
  }, []);

  const handleMessageDeleted = useCallback((msgId: number, pourTous: boolean) => {
    if (pourTous) {
      setMessages(prev => prev.map(m =>
        m.id === msgId ? { ...m, deleted: true, contenu: 'Ce message a été supprimé.' } : m,
      ));
    } else {
      setMessages(prev => prev.filter(m => m.id !== msgId));
    }
  }, []);

  const handleReaction = useCallback((msgId: number, emoji: string, userId: string, action: 'add' | 'remove') => {
    setMessages(prev => prev.map(m => {
      if (m.id !== msgId) return m;
      const reactions = { ...m.reactions };
      const estMoi    = userId === user?.id;
      if (action === 'remove') {
        if (reactions[emoji]) {
          reactions[emoji] = { count: Math.max(0, reactions[emoji].count - 1), moi: estMoi ? false : reactions[emoji].moi };
          if (reactions[emoji].count === 0) delete reactions[emoji];
        }
      } else {
        reactions[emoji] = { count: (reactions[emoji]?.count ?? 0) + 1, moi: estMoi ? true : (reactions[emoji]?.moi ?? false) };
      }
      return { ...m, reactions };
    }));
  }, [user?.id]);

  const handleLu = useCallback((userId: string) => {
    if (userId !== user?.id) {
      setMessages(prev => prev.map(m => m.moi ? { ...m, is_read: true } : m));
    }
  }, [user?.id]);

  const {
    isConnected, isTyping, typingUsername, convStatut, interlocuteurEnLigne,
    sendMessage, sendEdit, sendDelete, sendReact, sendTyping, markAsRead,
  } = useChat({
    convId:           selectedConv?.id ?? null,
    currentUserId:    user?.id ?? null,
    onMessage:        handleNewMessage,
    onMessageEdited:  handleMessageEdited,
    onMessageDeleted: handleMessageDeleted,
    onReaction:       handleReaction,
    onLu:             handleLu,
    onNotification: (data) => {
      if (data.conv_id !== selectedConv?.id) {
        showToast(`${data.auteur} : ${data.contenu}`, data.conv_id as number);
        setConversations(prev => prev.map(c =>
          c.id === data.conv_id ? { ...c, non_lus: c.non_lus + 1 } : c,
        ));
      }
    },
  });

  const statutEffectif = convStatut ?? selectedConv?.statut ?? null;
  const peutEcrire     = statutEffectif === 'ouverte' && isConnected;

  useEffect(() => {
    if (selectedConv && isConnected) {
      markAsRead();
      setConversations(prev => prev.map(c => c.id === selectedConv.id ? { ...c, non_lus: 0 } : c));
    }
  }, [selectedConv?.id, isConnected, markAsRead]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  // ── Charger conversations ──────────────────────────────────────────────────

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

  const openConversation = useCallback((conv: ConversationItem) => {
    setSelectedConv(conv);
    setMessages([]);
    setReplyTo(null);
    setEditingMsg(null);
    setLoadingMsgs(true);
    setShowSidebar(false);
    getMessages(conv.id)
      .then(setMessages)
      .catch(() => {})
      .finally(() => setLoadingMsgs(false));
  }, []);

  // ── Envoi ──────────────────────────────────────────────────────────────────

  const handleSend = useCallback(() => {
    if (!selectedConv) return;

    // Mode édition
    if (editingMsg) {
      const contenu = input.trim();
      if (!contenu) return;
      setInput("");
      setEditingMsg(null);
      if (isConnected) {
        sendEdit(editingMsg.id, contenu);
      } else {
        modifierMessage(editingMsg.id, contenu)
          .then(r => handleMessageEdited(r.message_id, r.contenu, r.edited_at))
          .catch(() => {});
      }
      return;
    }

    const contenu = input.trim();
    if (!contenu) return;
    setInput("");
    setReplyTo(null);

    if (isConnected) {
      sendMessage(contenu, replyTo?.id);
    } else {
      envoyerMessageRest(selectedConv.id, contenu, replyTo?.id)
        .then(msg => setMessages(prev => [...prev, msg]))
        .catch(() => {});
    }
  }, [input, selectedConv, isConnected, editingMsg, replyTo, sendMessage, sendEdit, handleMessageEdited]);

  const handleAudio = useCallback(async (blob: Blob, duration: number) => {
    if (!selectedConv) return;
    setRecordingAudio(false);
    setSendingAudio(true);
    try {
      await envoyerAudio(selectedConv.id, blob, duration);
    } catch { /* ignore */ }
    finally { setSendingAudio(false); }
  }, [selectedConv]);

  const handleReact = useCallback((msg: ChatMessage, emoji: string) => {
    if (!selectedConv) return;
    if (isConnected) {
      sendReact(msg.id, emoji);
    } else {
      reagirMessage(msg.id, emoji)
        .then(r => handleReaction(r.message_id, r.emoji, user?.id ?? '', r.action))
        .catch(() => {});
    }
  }, [isConnected, sendReact, selectedConv, handleReaction, user?.id]);

  const handleDeleteConfirm = useCallback((pourTous: boolean) => {
    if (!deleteTarget) return;
    if (isConnected) {
      sendDelete(deleteTarget.id, pourTous);
    } else {
      supprimerMessage(deleteTarget.id, pourTous)
        .then(r => handleMessageDeleted(r.message_id, r.pour_tous))
        .catch(() => {});
    }
    setDeleteTarget(null);
  }, [deleteTarget, isConnected, sendDelete, handleMessageDeleted]);

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); handleSend(); }
    else sendTyping();
  };

  // Vérifier si le message peut encore être modifié (< 15 min)
  const canEditMsg = (msg: ChatMessage) => {
    return !msg.deleted && (Date.now() - new Date(msg.timestamp).getTime()) < 15 * 60 * 1000;
  };

  const interlocuteur = selectedConv?.interlocuteurs[0] ?? null;

  return (
    <div className="flex h-[calc(100vh-4rem)] bg-base-200 relative">

      {/* ── Toast ───────────────────────────────────────────────────────── */}
      {toast && (
        <div
          className="fixed top-20 right-4 z-50 bg-base-100 border border-base-300 shadow-xl rounded-xl px-4 py-3 flex items-start gap-3 max-w-xs cursor-pointer"
          onClick={() => { const c = conversations.find(x => x.id === toast.convId); if (c) openConversation(c); setToast(null); }}
        >
          <MessageSquare className="w-4 h-4 text-primary mt-0.5 shrink-0" />
          <p className="text-xs text-base-content">{toast.text}</p>
        </div>
      )}

      {/* ── Modal suppression ────────────────────────────────────────────── */}
      {deleteTarget && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
          <div className="bg-base-100 rounded-2xl p-6 shadow-xl max-w-xs w-full mx-4 space-y-4">
            <h3 className="font-bold text-base-content">Supprimer le message</h3>
            <p className="text-sm text-base-content/60">Que souhaitez-vous faire ?</p>
            <div className="flex flex-col gap-2">
              <button onClick={() => handleDeleteConfirm(false)}
                className="btn btn-outline btn-sm rounded-full">
                Supprimer pour moi
              </button>
              <button onClick={() => handleDeleteConfirm(true)}
                className="btn btn-error btn-sm rounded-full">
                Supprimer pour tout le monde
              </button>
              <button onClick={() => setDeleteTarget(null)}
                className="btn btn-ghost btn-sm rounded-full text-base-content/50">
                Annuler
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ════════════════════════════════════════════════════════════════
          Colonne gauche — Liste des conversations
      ═════════════════════════════════════════════════════════════════ */}
      <aside className={`w-full md:w-80 bg-base-100 border-r border-base-200 flex flex-col ${showSidebar ? "flex" : "hidden md:flex"}`}>
        <div className="p-4 border-b border-base-200 shrink-0">
          <h2 className="text-base font-bold flex items-center gap-2">
            <MessageSquare className="w-4 h-4 text-primary" /> Messages
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
              const isGroupe = conv.is_groupe;
              const autre    = conv.interlocuteurs[0];
              const isActive = selectedConv?.id === conv.id;
              const displayName = isGroupe
                  ? (conv.titre ?? "Groupe trajet")
                  : (autre?.nom ?? "Conversation");
              const lastMsgText = conv.dernier_message
                  ? (isGroupe && !conv.dernier_message.moi
                      ? `${conv.dernier_message.contenu}`
                      : (conv.dernier_message.moi ? `Vous : ${conv.dernier_message.contenu}` : conv.dernier_message.contenu))
                  : null;

              return (
                <button key={conv.id} onClick={() => openConversation(conv)}
                  className={`w-full flex items-center gap-3 px-4 py-3 border-b border-base-100 hover:bg-base-200 transition-colors text-left ${isActive ? "bg-primary/8" : ""}`}>
                  <div className="relative shrink-0">
                    {isGroupe ? (
                      <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">
                        <Car className="w-5 h-5 text-primary" />
                      </div>
                    ) : autre ? <Avatar user={autre} size={10} /> : (
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
                      <div className="flex items-center gap-1.5 min-w-0">
                        <p className={`text-sm truncate ${conv.non_lus > 0 ? "font-semibold text-base-content" : "text-base-content/80"}`}>
                          {displayName}
                        </p>
                        {isGroupe && (
                          <span className="shrink-0 text-[10px] bg-primary/10 text-primary px-1.5 py-0.5 rounded-full font-medium">
                            {conv.participants_count}
                          </span>
                        )}
                      </div>
                      {conv.dernier_message && (
                        <span className="text-xs text-base-content/40 shrink-0">{fmtDateLabel(conv.dernier_message.timestamp)}</span>
                      )}
                    </div>
                    {!isGroupe && conv.trajet && (
                      <p className="text-xs text-base-content/40 truncate flex items-center gap-1">
                        <Car className="w-3 h-3 inline shrink-0" />
                        {conv.trajet.depart} → {conv.trajet.destination}
                      </p>
                    )}
                    {lastMsgText ? (
                      <p className={`text-xs truncate ${conv.non_lus > 0 ? "text-base-content/60 font-medium" : "text-base-content/40"}`}>
                        {lastMsgText}
                      </p>
                    ) : (
                      <p className="text-xs text-base-content/30 italic">Démarrez la conversation</p>
                    )}
                  </div>
                  {conv.statut !== 'ouverte' && <Lock className="w-3.5 h-3.5 text-warning shrink-0" />}
                </button>
              );
            })
          )}
        </div>
      </aside>

      {/* ════════════════════════════════════════════════════════════════
          Colonne droite — Conversation active
      ═════════════════════════════════════════════════════════════════ */}
      <main className={`flex-1 flex flex-col min-w-0 ${!showSidebar ? "flex" : "hidden md:flex"}`}>
        {selectedConv ? (
          <>
            {/* ── Header ─────────────────────────────────────────────── */}
            <header className="bg-base-100 border-b border-base-200 px-4 py-3 flex items-center gap-3 shrink-0">
              <button className="md:hidden btn btn-ghost btn-sm btn-square" onClick={() => setShowSidebar(true)}>
                <ChevronLeft className="w-4 h-4" />
              </button>
              {selectedConv.is_groupe ? (
                <div className="w-9 h-9 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                  <Car className="w-4.5 h-4.5 text-primary" />
                </div>
              ) : interlocuteur ? (
                <Avatar user={interlocuteur} size={9} />
              ) : null}
              <div className="flex-1 min-w-0">
                <p className="font-semibold text-sm truncate">
                  {selectedConv.is_groupe
                    ? (selectedConv.titre ?? "Groupe trajet")
                    : (interlocuteur?.nom ?? "Conversation")}
                </p>
                <p className={`text-xs font-medium ${selectedConv.is_groupe ? "text-primary" : interlocuteurEnLigne ? "text-success" : "text-base-content/40"}`}>
                  {selectedConv.is_groupe
                    ? `${selectedConv.participants_count} participants`
                    : interlocuteurEnLigne ? "En ligne" : selectedConv.trajet
                      ? `${selectedConv.trajet.depart} → ${selectedConv.trajet.destination}`
                      : "Hors ligne"}
                </p>
              </div>
              <div className={`flex items-center gap-1.5 text-xs shrink-0 ${isConnected ? "text-success" : "text-warning"}`}>
                {isConnected ? <><Wifi className="w-3.5 h-3.5" /> Connecté</> : <><WifiOff className="w-3.5 h-3.5" /> Reconnexion…</>}
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
            <div className="flex-1 overflow-y-auto px-4 py-4 space-y-1">
              {loadingMsgs ? (
                <div className="flex justify-center py-10">
                  <span className="loading loading-spinner loading-md text-primary" />
                </div>
              ) : messages.length === 0 ? (
                <div className="text-center py-16 text-base-content/30">
                  <MessageSquare className="w-10 h-10 mx-auto mb-3 opacity-20" />
                  <p className="text-sm">Démarrez la conversation</p>
                </div>
              ) : (
                messages.map((msg, idx) => {
                  const isMine   = msg.auteur_id === user?.id;
                  const showDate = idx === 0 || (
                    new Date(msg.timestamp).toDateString() !== new Date(messages[idx - 1].timestamp).toDateString()
                  );
                  return (
                    <div key={msg.id}>
                      {showDate && (
                        <div className="text-center my-3">
                          <span className="text-xs bg-base-300 text-base-content/50 px-3 py-1 rounded-full">
                            {fmtDateLabel(msg.timestamp)}
                          </span>
                        </div>
                      )}
                      <MessageBubble
                        msg={msg}
                        isMine={isMine}
                        interlocuteur={interlocuteur}
                        isGroupe={selectedConv?.is_groupe ?? false}
                        canEdit={canEditMsg(msg)}
                        onReply={m => { setReplyTo(m); setEditingMsg(null); inputRef.current?.focus(); }}
                        onEdit={m => { setEditingMsg(m); setInput(m.contenu); setReplyTo(null); inputRef.current?.focus(); }}
                        onDelete={m => setDeleteTarget(m)}
                        onReact={handleReact}
                      />
                    </div>
                  );
                })
              )}

              {/* Indicateur "en train d'écrire" */}
              {isTyping && (
                <div className="flex items-center gap-2">
                  <div className="w-7 h-7 rounded-full bg-primary/15 flex items-center justify-center text-xs font-bold text-primary shrink-0">
                    {interlocuteur?.nom[0]?.toUpperCase() ?? "?"}
                  </div>
                  <div className="bg-base-100 border border-base-200 px-4 py-2.5 rounded-2xl rounded-bl-sm shadow-sm">
                    <p className="text-xs text-base-content/50 mb-1">{typingUsername} écrit…</p>
                    <div className="flex gap-1 items-center h-4">
                      {[0, 150, 300].map(d => (
                        <span key={d} className="w-2 h-2 bg-base-content/30 rounded-full animate-bounce"
                          style={{ animationDelay: `${d}ms` }} />
                      ))}
                    </div>
                  </div>
                </div>
              )}
              <div ref={messagesEndRef} />
            </div>

            {/* ── Zone de saisie ──────────────────────────────────────── */}
            <div className="bg-base-100 border-t border-base-200 p-3 shrink-0 space-y-2">

              {/* Aperçu réponse */}
              {replyTo && !editingMsg && (
                <div className="flex items-center gap-2 px-3 py-2 bg-primary/5 border border-primary/20 rounded-xl text-xs">
                  <CornerUpLeft className="w-3.5 h-3.5 text-primary shrink-0" />
                  <div className="flex-1 min-w-0">
                    <p className="font-semibold text-primary">{replyTo.username}</p>
                    <p className="text-base-content/50 truncate">
                      {replyTo.message_type === 'audio' ? '🎵 Message vocal' : replyTo.contenu}
                    </p>
                  </div>
                  <button onClick={() => setReplyTo(null)} className="text-base-content/30 hover:text-base-content">
                    <X className="w-3.5 h-3.5" />
                  </button>
                </div>
              )}

              {/* Bannière édition */}
              {editingMsg && (
                <div className="flex items-center gap-2 px-3 py-2 bg-warning/10 border border-warning/30 rounded-xl text-xs">
                  <Edit2 className="w-3.5 h-3.5 text-warning shrink-0" />
                  <p className="flex-1 text-warning">Modification du message</p>
                  <button onClick={() => { setEditingMsg(null); setInput(""); }} className="text-base-content/30">
                    <X className="w-3.5 h-3.5" />
                  </button>
                </div>
              )}

              {peutEcrire ? (
                recordingAudio ? (
                  <AudioRecorder
                    onSend={handleAudio}
                    onCancel={() => setRecordingAudio(false)}
                  />
                ) : (
                  <div className="flex items-end gap-2">
                    {/* Bouton micro (si pas en édition) — à gauche pour éviter le chatbot flottant à droite */}
                    {!editingMsg && !input.trim() && (
                      <button
                        onClick={() => setRecordingAudio(true)}
                        disabled={sendingAudio}
                        className="btn btn-ghost btn-square shrink-0 text-base-content/50 hover:text-primary"
                        title="Message vocal"
                      >
                        {sendingAudio
                          ? <span className="loading loading-spinner loading-xs" />
                          : <Mic className="w-5 h-5" />}
                      </button>
                    )}
                    <button
                      onClick={handleSend}
                      disabled={!input.trim()}
                      className="btn btn-primary btn-square shrink-0"
                    >
                      <Send className="w-4 h-4" />
                    </button>
                    <textarea
                      ref={inputRef}
                      className="flex-1 textarea textarea-bordered resize-none text-sm min-h-10 max-h-32 leading-relaxed"
                      placeholder={editingMsg ? "Modifier le message…" : "Écrivez un message…"}
                      value={input}
                      rows={1}
                      onChange={e => setInput(e.target.value)}
                      onKeyDown={handleKeyDown}
                    />
                  </div>
                )
              ) : (
                <div className="flex items-center gap-2 text-base-content/40 text-sm py-1">
                  {isConnected
                    ? <><Lock className="w-4 h-4" /> Conversation en lecture seule</>
                    : <><WifiOff className="w-4 h-4" /> Reconnexion en cours…</>}
                </div>
              )}
            </div>
          </>
        ) : (
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

export default function MessagesPage() {
  return (
    <Suspense>
      <MessagesContent />
    </Suspense>
  );
}
