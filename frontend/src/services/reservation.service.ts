// src/services/reservation.service.ts

import { api } from "./api";

export interface Reservation {
  id: number;
  trajet_id: number;
  depart: string;
  destination: string;
  date_depart: string;
  conducteur: string;
  passager_nom?: string;
  passager_note?: number;
  prix_par_place: number;
  statut: "en_attente" | "confirmee" | "declinee" | "terminee";
  date_reservation: string;
}

// Passager — réserver une place
export interface ReserverPayload {
  trajet_id: number;
  prise_en_charge_lat?: number;
  prise_en_charge_lng?: number;
  depose_lat?: number;
  depose_lng?: number;
}
export const reserver = (data: ReserverPayload) =>
  api("/reservations/reserver/", "POST", data);

// Passager — mes réservations
export const mesReservations = () =>
  api("/reservations/mes_reservations/", "GET");

// Passager — annuler une réservation en attente
export const annulerReservation = (id: number) =>
  api(`/reservations/${id}/annuler/`, "POST");

// Conducteur — réservations reçues
export const reservationsRecues = () => api("/reservations/recues/", "GET");

// Conducteur — confirmer une réservation
export const confirmerReservation = (id: number) =>
  api(`/reservations/${id}/confirmer/`, "POST");

// Conducteur — décliner une réservation
export const declinerReservation = (id: number) =>
  api(`/reservations/${id}/decliner/`, "POST");

// Passager — historique des réservations
export const historiqueReservations = () =>
  api("/reservations/historique/", "GET");
