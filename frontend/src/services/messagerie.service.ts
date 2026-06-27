import { api } from "./api";

// ── Types ────────────────────────────────────────────────────────────────────

export interface InterlocuteurInfo {
  id:           string;
  username:     string;
  nom:          string;
  photo_profil: string | null;
  role:         string;
}

export interface TrajetInfo {
  id:                 number;
  depart:             string;
  destination:        string;
  date:               string | null;
  statut_reservation: string;
  reservation_id:     number;
}

export interface DernierMessage {
  id:        number;
  contenu:   string;
  auteur_id: string;
  timestamp: string;
  moi:       boolean;
}

export interface ConversationItem {
  id:                 number;
  type:               'private' | 'trajet';
  is_groupe:          boolean;
  titre:              string | null;
  statut:             'ouverte' | 'lecture_seule' | 'fermee';
  reservation_id:     number | null;
  trajet_id:          number | null;
  trajet:             TrajetInfo | null;
  interlocuteurs:     InterlocuteurInfo[];
  participants_count: number;
  dernier_message:    DernierMessage | null;
  non_lus:            number;
  updated_at:         string;
  exists?:            boolean;
  created?:           boolean;
}

export interface ReplyInfo {
  id:           number;
  contenu:      string;
  username:     string;
  message_type: string;
}

export interface ReactionGroup {
  count: number;
  moi:   boolean;
}

export interface ChatMessage {
  id:             number;
  deleted:        boolean;
  contenu:        string;
  message_type:   'text' | 'audio' | 'image';
  audio_url:      string | null;
  audio_duration: number | null;
  auteur_id:      string;
  username:       string;
  timestamp:      string;
  moi:            boolean;
  is_edited:      boolean;
  edited_at:      string | null;
  reply_to:       ReplyInfo | null;
  reactions:      Record<string, ReactionGroup>;
  is_read:        boolean;
}

// ── API REST ─────────────────────────────────────────────────────────────────

export const getConversations = (): Promise<ConversationItem[]> =>
  api("/messagerie/conversations/", "GET");

export const getDetailConversation = (convId: number): Promise<ConversationItem> =>
  api(`/messagerie/conversations/${convId}/`, "GET");

export const getMessages = (convId: number, avantId?: number): Promise<ChatMessage[]> => {
  const qs = avantId ? `?avant=${avantId}` : "";
  return api(`/messagerie/conversations/${convId}/messages/${qs}`, "GET");
};

export const envoyerMessageRest = (
  convId: number,
  contenu: string,
  replyToId?: number,
): Promise<ChatMessage> =>
  api(`/messagerie/conversations/${convId}/envoyer/`, "POST", {
    contenu,
    ...(replyToId ? { reply_to_id: replyToId } : {}),
  });

export const envoyerAudio = (
  convId: number,
  audioBlob: Blob,
  duration?: number,
): Promise<ChatMessage> => {
  const form = new FormData();
  form.append("audio", audioBlob, "message.webm");
  if (duration !== undefined) form.append("duration", String(Math.round(duration)));
  return api(`/messagerie/conversations/${convId}/audio/`, "POST", form);
};

export const modifierMessage = (
  msgId: number,
  contenu: string,
): Promise<{ message_id: number; contenu: string; edited_at: string }> =>
  api(`/messagerie/messages/${msgId}/`, "PATCH", { contenu });

export const supprimerMessage = (
  msgId: number,
  pourTous: boolean,
): Promise<{ message_id: number; pour_tous: boolean }> =>
  api(`/messagerie/messages/${msgId}/supprimer/`, "DELETE", { pour_tous: pourTous });

export const reagirMessage = (
  msgId: number,
  emoji: string,
): Promise<{ message_id: number; emoji: string; action: 'add' | 'remove' }> =>
  api(`/messagerie/messages/${msgId}/reagir/`, "POST", { emoji });

export const getNonLus = (): Promise<{ count: number }> =>
  api("/messagerie/non-lus/", "GET");

export const getOrCreatePrivate = (userId: string): Promise<ConversationItem> =>
  api(`/messagerie/private/${userId}/`, "POST");

export const getGroupeTrajet = (trajetId: number): Promise<ConversationItem> =>
  api(`/messagerie/trajet/${trajetId}/groupe/`, "GET");

export const getOrCreateGroupeTrajet = (trajetId: number): Promise<ConversationItem> =>
  api(`/messagerie/trajet/${trajetId}/groupe/`, "POST");

// ── Divers ───────────────────────────────────────────────────────────────────

export const getQrCode = (reservationId: string): Promise<{ token: string }> =>
  api(`/reservations/${reservationId}/qr-code/`, "GET");

export const declencherSos = (data: {
  latitude?: number;
  longitude?: number;
}): Promise<{ message: string }> =>
  api("/utilisateurs/ko/sos/", "POST", data);

export const mettreAJourContactUrgence = (data: {
  contact_urgence_nom: string;
  contact_urgence_telephone: string;
}): Promise<unknown> =>
  api("/utilisateurs/ko/contact-urgence/", "POST", data);
