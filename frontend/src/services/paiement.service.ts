import { api } from "./api";

export interface PaiementInitierPayload {
  reservation_id: number;
  phone_number: string;
  network: "FLOOZ" | "TMONEY";
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

export interface PaiementStatut {
  statut: "payee" | "en_attente" | "echouee";
  message: string;
  pg_status: number;
  tx_reference: string;
  payment_reference: string;
  payment_method: string;
  datetime: string;
}

// Initier un paiement mobile (Flooz ou TMoney)
export const initierPaiement = (
  data: PaiementInitierPayload,
): Promise<PaiementResponse> => api("/paiements/initier/", "POST", data);

// Vérifier le statut d'un paiement
export const verifierPaiement = (identifier: string): Promise<PaiementStatut> =>
  api("/paiements/verifier/", "POST", { identifier });

// Confirmer paiement en espèces (conducteur)
export const confirmerEspeces = (reservation_id: number) =>
  api("/paiements/confirmer_especes/", "POST", { reservation_id });

// Mes paiements (passager)
export const mesPaiements = () => api("/paiements/mes_paiements/", "GET");
