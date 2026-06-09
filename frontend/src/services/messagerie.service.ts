import { api } from "./api";

export const getConversations = () =>
    api("/messagerie/conversations/", "GET");

export const getHistorique = (userId: string) =>
    api(`/messagerie/messages/${userId}/`, "GET");

export const envoyerMessage = (userId: string, contenu: string) =>
    api(`/messagerie/messages/${userId}/envoyer/`, "POST", { contenu });

export const getNonLus = () =>
    api("/messagerie/non-lus/", "GET");

export const getInfoUtilisateur = (userId: string): Promise<{
    id: string;
    username: string;
    nom: string;
    photo_profil: string | null;
    role: string;
}> => api(`/messagerie/utilisateur/${userId}/`, "GET");

export const getQrCode = (reservationId: string) =>
    api(`/reservations/${reservationId}/qr-code/`, "GET");

export const scannerQr = (reservationId: string, token: string) =>
    api(`/reservations/${reservationId}/scanner-qr/`, "POST", { token });

export const declencherSos = (data: { latitude?: number; longitude?: number; trajet_id?: string }) =>
    api("/utilisateurs/ko/sos/", "POST", data);

export const mettreAJourContactUrgence = (data: {
    contact_urgence_nom: string;
    contact_urgence_telephone: string;
}) => api("/utilisateurs/ko/contact-urgence/", "POST", data);
