import { api } from "./api";

export interface PaiementInitierPayload {
  reservation_id: number;
  phone_number: string;
  network: "FLOOZ" | "TMONEY";
}

export interface PaiementEspecesPayload {
  reservation_id: number;
}

export interface PaiementResponse {
  message: string;
  tx_reference: string;
  identifier: string;
  montant: number;
  commission_kovoit: number;
  montant_conducteur: number;
  network: string;
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
  statut: "payee" | "en_attente" | "echouee" | "EN_ATTENTE_CONFIRMATION" | "CONFIRME" | "ANNULE" | "AUCUN";
  message?: string;
  pg_status?: number;
  tx_reference?: string;
  payment_reference?: string;
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

// Initier un paiement mobile (Flooz ou TMONEY)
export const initierPaiement = (
  data: PaiementInitierPayload,
): Promise<PaiementResponse> => api("/paiements/initier/", "POST", data);

// Vérifier le statut d'un paiement
export const verifierPaiement = (identifier: string): Promise<PaiementStatut> =>
  api("/paiements/verifier/", "POST", { identifier });

// Initier un paiement en espèces
export const initierPaiementEspeces = (
  data: PaiementEspecesPayload,
): Promise<PaiementEspecesResponse> => api("/paiements/initier_especes/", "POST", data);

// Confirmer paiement en espèces (conducteur)
export const confirmerEspeces = (reservation_id: number) =>
  api("/paiements/confirmer_especes/", "POST", { reservation_id });

// Obtenir le statut de paiement d'une réservation
export const getStatutPaiementReservation = (reservation_id: number): Promise<PaiementReservationResponse> =>
  api(`/paiements/statut_reservation/?reservation_id=${reservation_id}`, "GET");

// Mes paiements (passager)
export const mesPaiements = () => api("/paiements/mes_paiements/", "GET");

// ── T-Money / Flooz manuel ────────────────────────────────────────────────

export interface SoumettreReferenceMobilePayload {
  reservation_id: number;
  reference_mobile: string;
  network: "FLOOZ" | "TMONEY";
}

export interface SoumettreReferenceMobileResponse {
  message: string;
  paiement_id: number;
  reference_mobile: string;
  montant: number;
  commission_kovoit: number;
  statut: string;
}

// Passager soumet sa référence USSD après virement manuel
export const soumettreReferenceMobile = (
  data: SoumettreReferenceMobilePayload,
): Promise<SoumettreReferenceMobileResponse> =>
  api("/paiements/soumettre_reference_mobile/", "POST", data);

// Conducteur confirme la réception du virement mobile money
export const confirmerMobile = (reservation_id: number) =>
  api("/paiements/confirmer_mobile/", "POST", { reservation_id });
