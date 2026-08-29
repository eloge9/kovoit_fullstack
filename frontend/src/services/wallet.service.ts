import { api } from "./api";
import type { OperateurMobileMoney } from "./paiement.service";

export interface MonWallet {
  solde_disponible: number;
  solde_du: number;
  peut_retirer: boolean;
}

export type WalletTransactionType =
  | "DEPOSIT"
  | "WITHDRAWAL_REQUEST"
  | "WITHDRAWAL_COMPLETED"
  | "WITHDRAWAL_FAILED"
  | "RIDE_PAYMENT_CREDIT"
  | "COMMISSION_ELECTRONIC"
  | "COMMISSION_CASH_DUE"
  | "COMMISSION_CASH_SETTLED"
  | "REFUND"
  | "CANCELLATION_PENALTY"
  | "ADJUSTMENT";

export interface WalletTransaction {
  id: number;
  type: WalletTransactionType;
  sens: "CREDIT" | "DEBIT";
  montant: number;
  solde_disponible_apres: number;
  solde_du_apres: number;
  statut: string;
  description: string;
  created_at: string;
}

export type RetraitStatut = "EN_ATTENTE" | "EN_COURS" | "REUSSI" | "ECHOUE" | "ANNULE";

export interface Retrait {
  id: number;
  montant: number;
  moyen: OperateurMobileMoney;
  numero_destination: string;
  statut: RetraitStatut;
  motif_echec: string;
  date_demande: string;
  date_traitement: string | null;
}

export const WALLET_TYPE_LABEL: Record<WalletTransactionType, string> = {
  DEPOSIT:                 "Dépôt",
  WITHDRAWAL_REQUEST:      "Demande de retrait",
  WITHDRAWAL_COMPLETED:    "Retrait effectué",
  WITHDRAWAL_FAILED:       "Retrait échoué (remboursé)",
  RIDE_PAYMENT_CREDIT:     "Paiement de trajet",
  COMMISSION_ELECTRONIC:   "Commission KoVoit",
  COMMISSION_CASH_DUE:     "Commission due (espèces)",
  COMMISSION_CASH_SETTLED: "Commission réglée",
  REFUND:                  "Annulation — reprise",
  CANCELLATION_PENALTY:    "Pénalité d'annulation",
  ADJUSTMENT:              "Ajustement (admin)",
};

export const RETRAIT_STATUT_LABEL: Record<RetraitStatut, string> = {
  EN_ATTENTE: "En attente",
  EN_COURS:   "En cours",
  REUSSI:     "Réussi",
  ECHOUE:     "Échoué",
  ANNULE:     "Annulé",
};

export const getMonWallet = (): Promise<MonWallet> =>
  api("/paiements/wallet/mon_wallet/", "GET");

export const getMesTransactions = (): Promise<WalletTransaction[]> =>
  api("/paiements/wallet/mes_transactions/", "GET");

export const getMesRetraits = (): Promise<Retrait[]> =>
  api("/paiements/wallet/mes_retraits/", "GET");

export const deposerInitier = (data: {
  montant: number;
  phone_number: string;
  network: OperateurMobileMoney;
}): Promise<{ message: string; token: string; transref: string; payment_url: string; montant: number }> =>
  api("/paiements/wallet/deposer_initier/", "POST", data);

export const deposerVerifier = (
  token: string,
  transref: string,
): Promise<{ statut: string; message: string; solde_disponible?: number; solde_du?: number }> =>
  api("/paiements/wallet/deposer_verifier/", "POST", { token, transref });

export const demanderRetrait = (data: {
  montant: number;
  moyen: OperateurMobileMoney;
  numero_destination: string;
}): Promise<{ message: string; retrait: Retrait }> =>
  api("/paiements/wallet/retirer/", "POST", data);
