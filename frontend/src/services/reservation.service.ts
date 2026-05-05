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
  statut: "en_attente" | "confirmee" | "declinee";
  date_reservation: string;
}

// Passager — réserver une place
export const reserver = (data: { trajet_id: number }) =>
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
