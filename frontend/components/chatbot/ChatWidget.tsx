"use client";
import { useState, useEffect, useRef } from "react";
import { useChatbot, type UIMessage } from "@/src/hooks/useChatbot";
import { MessageSquare, X, Send, RefreshCw, ChevronDown } from "lucide-react";
import DOMPurify from "dompurify";

// ── Rendu Markdown simple avec sanitisation XSS ───────────────────────────────

function renderMarkdown(text: string): string {
  // Échapper le HTML brut AVANT d'appliquer le Markdown
  const escaped = text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
  const withMarkdown = escaped
    .replace(/\*\*(.*?)\*\*/g, "<strong>$1</strong>")
    .replace(/\*(.*?)\*/g,     "<em>$1</em>")
    .replace(/\n/g,            "<br/>");
  return DOMPurify.sanitize(withMarkdown, { ALLOWED_TAGS: ["strong", "em", "br"] });
}

// ── Bulle de message ──────────────────────────────────────────────────────────

function ChatBubble({ msg }: { msg: UIMessage }) {
  const isUser = msg.role === "user";

  return (
    <div className={`flex items-end gap-2 mb-3 ${isUser ? "justify-end" : "justify-start"}`}>
      {/* Avatar Kovi */}
      {!isUser && (
        <div className="w-7 h-7 rounded-full bg-primary flex items-center justify-center shrink-0 text-white text-xs font-bold shadow-sm">
          K
        </div>
      )}

      <div className={`max-w-[80%] ${isUser ? "items-end" : "items-start"} flex flex-col`}>
        <div
          className={`px-3.5 py-2.5 rounded-2xl text-sm leading-relaxed shadow-sm ${
            isUser
              ? "bg-primary text-primary-content rounded-br-sm"
              : "bg-base-100 border border-base-200 text-base-content rounded-bl-sm"
          }`}
          dangerouslySetInnerHTML={{ __html: renderMarkdown(msg.content) }}
        />
        {/* Curseur de streaming */}
        {msg.streaming && (
          <span className="mt-1 ml-1 flex gap-1">
            {[0, 150, 300].map(d => (
              <span
                key={d}
                className="w-1.5 h-1.5 rounded-full bg-primary/50 animate-bounce"
                style={{ animationDelay: `${d}ms` }}
              />
            ))}
          </span>
        )}
      </div>
    </div>
  );
}

// ── Questions rapides ─────────────────────────────────────────────────────────

const QUICK_QUESTIONS = [
  "Comment réserver un trajet ?",
  "Comment devenir conducteur ?",
  "Comment payer sur Kovoit ?",
  "Contacter le support",
];

// ── Widget principal ──────────────────────────────────────────────────────────

export default function ChatWidget() {
  const [open,  setOpen]  = useState(false);
  const [input, setInput] = useState("");
  const [showQuick, setShowQuick] = useState(true);

  const { messages, isLoading, sendMessage, clearHistory } = useChatbot();
  const bottomRef  = useRef<HTMLDivElement>(null);
  const inputRef   = useRef<HTMLTextAreaElement>(null);

  // Scroll automatique vers le bas
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  // Focus input à l'ouverture
  useEffect(() => {
    if (open) setTimeout(() => inputRef.current?.focus(), 150);
  }, [open]);

  const handleSend = () => {
    const text = input.trim();
    if (!text || isLoading) return;
    setInput("");
    setShowQuick(false);
    sendMessage(text);
  };

  const handleQuick = (q: string) => {
    setShowQuick(false);
    sendMessage(q);
  };

  const handleKey = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  const unread = messages.filter(m => m.role === "assistant" && m.id !== "welcome").length;

  return (
    <>
      {/* ── Fenêtre de chat ──────────────────────────────────────────── */}
      {open && (
        <div className="fixed bottom-20 right-4 z-50 flex flex-col shadow-2xl rounded-2xl overflow-hidden border border-base-200
                        w-[calc(100vw-2rem)] max-w-sm h-[560px] md:w-[380px] md:h-[520px]
                        animate-in slide-in-from-bottom-4 duration-200">

          {/* Header */}
          <header className="bg-primary text-primary-content px-4 py-3 flex items-center gap-3 shrink-0">
            <div className="w-9 h-9 rounded-full bg-white/20 flex items-center justify-center font-bold text-lg">
              K
            </div>
            <div className="flex-1">
              <p className="font-semibold text-sm">Kovi</p>
              <p className="text-xs opacity-75">Assistant Kovoit • En ligne</p>
            </div>
            <button
              onClick={clearHistory}
              className="btn btn-ghost btn-xs btn-square text-primary-content/70 hover:text-primary-content"
              title="Nouvelle conversation"
            >
              <RefreshCw className="w-3.5 h-3.5" />
            </button>
            <button
              onClick={() => setOpen(false)}
              className="btn btn-ghost btn-xs btn-square text-primary-content/70 hover:text-primary-content"
            >
              <ChevronDown className="w-4 h-4" />
            </button>
          </header>

          {/* Messages */}
          <div className="flex-1 overflow-y-auto px-3 py-3 bg-base-200 space-y-0">
            {messages.map(msg => (
              <ChatBubble key={msg.id} msg={msg} />
            ))}

            {/* Questions rapides (au démarrage) */}
            {showQuick && messages.length === 1 && (
              <div className="flex flex-wrap gap-2 mt-2">
                {QUICK_QUESTIONS.map(q => (
                  <button
                    key={q}
                    onClick={() => handleQuick(q)}
                    className="text-xs bg-base-100 border border-base-300 rounded-full px-3 py-1.5
                               hover:bg-primary hover:text-primary-content hover:border-primary transition-colors"
                  >
                    {q}
                  </button>
                ))}
              </div>
            )}

            <div ref={bottomRef} />
          </div>

          {/* Zone de saisie */}
          <div className="bg-base-100 border-t border-base-200 p-2.5 shrink-0 flex items-end gap-2">
            <textarea
              ref={inputRef}
              className="flex-1 textarea textarea-bordered textarea-sm resize-none text-sm min-h-9 max-h-24 leading-relaxed"
              placeholder="Posez votre question…"
              value={input}
              rows={1}
              onChange={e => setInput(e.target.value)}
              onKeyDown={handleKey}
              disabled={isLoading}
            />
            <button
              onClick={handleSend}
              disabled={!input.trim() || isLoading}
              className="btn btn-primary btn-square btn-sm shrink-0"
            >
              {isLoading
                ? <span className="loading loading-spinner loading-xs" />
                : <Send className="w-3.5 h-3.5" />}
            </button>
          </div>
        </div>
      )}

      {/* ── Bouton flottant ──────────────────────────────────────────── */}
      <button
        onClick={() => setOpen(v => !v)}
        className="fixed bottom-4 right-4 z-50 w-14 h-14 rounded-full bg-primary shadow-xl
                   flex items-center justify-center hover:scale-105 active:scale-95 transition-transform"
        aria-label="Ouvrir le chatbot Kovi"
      >
        {open ? (
          <X className="w-6 h-6 text-primary-content" />
        ) : (
          <>
            <MessageSquare className="w-6 h-6 text-primary-content" />
            {!open && unread > 0 && (
              <span className="absolute -top-1 -right-1 w-5 h-5 bg-error text-error-content
                               text-[10px] font-bold rounded-full flex items-center justify-center">
                {unread > 9 ? "9+" : unread}
              </span>
            )}
          </>
        )}
      </button>
    </>
  );
}
