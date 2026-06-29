const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://127.0.0.1:8000/api";

export interface ChatMessage {
  role:    "user" | "assistant";
  content: string;
}

export interface ChatResponse {
  response:   string;
  session_id: string;
  provider:   string;
}

function getAuthHeader(): Record<string, string> {
  if (typeof window === "undefined") return {};
  const token = localStorage.getItem("token");
  return token ? { Authorization: `Bearer ${token}` } : {};
}

/** Envoi classique (réponse complète en une fois) */
export async function sendChatMessage(
  message: string,
  sessionId: string,
  history: ChatMessage[],
): Promise<ChatResponse> {
  const res = await fetch(`${API_URL}/chat/`, {
    method:  "POST",
    headers: { "Content-Type": "application/json", ...getAuthHeader() },
    body:    JSON.stringify({ message, session_id: sessionId, conversation_history: history }),
  });
  if (!res.ok) throw new Error("Erreur réseau chatbot");
  return res.json();
}

/**
 * Streaming SSE — retourne un AsyncGenerator qui yield les chunks de texte.
 * Yield aussi { provider } comme premier objet.
 */
export async function* streamChatMessage(
  message: string,
  sessionId: string,
  history: ChatMessage[],
): AsyncGenerator<{ text?: string; provider?: string; done?: boolean }> {
  const res = await fetch(`${API_URL}/chat/stream/`, {
    method:  "POST",
    headers: { "Content-Type": "application/json", ...getAuthHeader() },
    body:    JSON.stringify({ message, session_id: sessionId, conversation_history: history }),
  });

  if (!res.ok || !res.body) throw new Error("Erreur réseau chatbot stream");

  const reader  = res.body.getReader();
  const decoder = new TextDecoder();
  let   buffer  = "";

  while (true) {
    const { value, done } = await reader.read();
    if (done) break;

    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split("\n");
    buffer = lines.pop() ?? "";

    for (const line of lines) {
      if (!line.startsWith("data: ")) continue;
      const raw = line.slice(6).trim();
      if (!raw) continue;
      try {
        const parsed = JSON.parse(raw);
        // Remettre les newlines escapés
        if (parsed.text) parsed.text = parsed.text.replace(/\\n/g, "\n");
        yield parsed;
      } catch { /* ignore malformed chunk */ }
    }
  }
}
