import { api } from "./api";

// ── Types ────────────────────────────────────────────────────────────────────

export interface InterlocuteurInfo {
  id:          string;
  username:    string;
  nom:         string;
  photo_profil: string | null;
  role:        string;
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
  id:             number;
  statut:         'ouverte' | 'lecture_seule' | 'fermee';
  reservation_id: number | null;
  trajet:         TrajetInfo | null;
  interlocuteurs: InterlocuteurInfo[];
  dernier_message: DernierMessage | null;
  non_lus:        number;
  updated_at:     string;
}

export interface ChatMessage {
  id:        number;
  contenu:   string;
  auteur_id: string;
  username:  string;
  timestamp: string;
  moi:       boolean;
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

export const envoyerMessageRest = (convId: number, contenu: string): Promise<ChatMessage> =>
  api(`/messagerie/conversations/${convId}/envoyer/`, "POST", { contenu });

export const getNonLus = (): Promise<{ count: number }> =>
  api("/messagerie/non-lus/", "GET");

// ── QR code / code embarquement (utilisé sur la page réservation passager) ───

export const getQrCode = (reservationId: string): Promise<{ token: string }> =>
  api(`/reservations/${reservationId}/qr-code/`, "GET");

// ── Contact d'urgence (utilisé sur les pages de profil) ───────────────────────

export const mettreAJourContactUrgence = (data: {
  contact_urgence_nom: string;
  contact_urgence_telephone: string;
}): Promise<unknown> =>
  api("/utilisateurs/ko/contact-urgence/", "POST", data);
