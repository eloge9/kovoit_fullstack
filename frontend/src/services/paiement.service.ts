import { api } from "./api";

// Opérateurs Mobile Money disponibles via PayPlus Africa
export type OperateurMobileMoney = "FLOOZ" | "YAS";

export interface PaiementInitierPayload {
  reservation_id: number;
  phone_number: string;
  network: OperateurMobileMoney;
}

export interface PaiementEspecesPayload {
  reservation_id: number;
}

export interface PaiementResponse {
  message: string;
  token: string;
  transref: string;
  montant: number;
  commission_kovoit: number;
  montant_conducteur: number;
  network: OperateurMobileMoney;
  phone_number: string;
}

export interface PaiementEspecesResponse {
  message: string;
  paiement_id: number;
  montant: number;
  commission_kovoit: number;
  montant_conducteur: number;
  statut: string;
}

export interface PaiementStatut {
  statut: "en_attente" | "echouee" | "EN_ATTENTE_CONFIRMATION" | "CONFIRME" | "ANNULE" | "AUCUN";
  message?: string;
  pp_status?: string;
  token?: string;
  phone?: string;
  amount?: number;
  payment_method?: string;
  datetime?: string;
  paiement_id?: number;
  moyen_paiement?: string;
  montant?: number;
  date_creation?: string;
  date_confirmation?: string;
}

export interface PaiementReservationResponse {
  paiement_id?: number;
  statut: string;
  moyen_paiement?: string;
  montant?: number;
  date_creation?: string;
  date_confirmation?: string;
  message?: string;
}

export const OPERATEURS_MOBILE_MONEY: Record<OperateurMobileMoney, { label: string; prefix: string }> = {
  FLOOZ: { label: "Moov Flooz", prefix: "90 / 91 / 92" },
  YAS:   { label: "Mixx by Yas", prefix: "70 / 71 / 72 / 90" },
};

// Initier un paiement Mobile Money (Moov Flooz ou Mixx by Yas)
export const initierPaiement = (
  data: PaiementInitierPayload,
): Promise<PaiementResponse> => api("/paiements/initier/", "POST", data);

// Vérifier le statut d'un paiement PayPlus Africa
export const verifierPaiement = (token: string): Promise<PaiementStatut> =>
  api("/paiements/verifier/", "POST", { token });

// Initier un paiement en espèces
export const initierPaiementEspeces = (
  data: PaiementEspecesPayload,
): Promise<PaiementEspecesResponse> => api("/paiements/initier_especes/", "POST", data);

// Confirmer paiement en espèces (conducteur)
export const confirmerEspeces = (reservation_id: number) =>
  api("/paiements/confirmer_especes/", "POST", { reservation_id });

// Annuler un paiement Mobile Money en attente (passager)
export const annulerPaiement = (reservation_id: number) =>
  api("/paiements/annuler_paiement/", "POST", { reservation_id });

// Obtenir le statut de paiement d'une réservation
export const getStatutPaiementReservation = (
  reservation_id: number,
): Promise<PaiementReservationResponse> =>
  api(`/paiements/statut_reservation/?reservation_id=${reservation_id}`, "GET");

// Mes paiements (passager)
export const mesPaiements = () => api("/paiements/mes_paiements/", "GET");

// Paiements reçus par le conducteur
export const paiementsConducteur = (params?: {
  date_debut?: string;
  date_fin?: string;
  mois?: number;
  annee?: number;
}) => {
  const qs = params
    ? "?" + Object.entries(params)
        .filter(([, v]) => v !== undefined && v !== null)
        .map(([k, v]) => `${k}=${v}`)
        .join("&")
    : "";
  return api(`/paiements/paiements_conducteur/${qs}`, "GET");
};
