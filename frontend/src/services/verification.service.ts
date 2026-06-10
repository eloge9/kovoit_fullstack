import { api } from "./api";

const BASE = "/verification";

export interface VerificationStatus {
  status: string;
  is_verified: boolean;
  completion_percentage: number;
  can_publish_trip: boolean;
  required_documents: string[];
  uploaded_documents: string[];
  missing_documents: string[];
  latest_report: {
    id: string;
    decision: string | null;
    overall_score: number;
    fraud_score: number;
    confidence_score: number;
    completed_at: string | null;
    created_at: string;
  } | null;
  motif_rejet: string;
  motif_suspension: string;
}

export interface DriverDocument {
  id: string;
  document_type: string;
  status: string;
  file_url: string | null;
  file_name: string;
  date_expiration: string | null;
  rejection_reason: string;
  uploaded_at: string;
  is_expired: boolean;
  days_until_expiration: number | null;
}

export interface DriverProfile {
  id: string;
  user: {
    id: string;
    username: string;
    email: string;
    first_name: string;
    last_name: string;
    full_name: string;
  };
  status: string;
  is_verified: boolean;
  completion_percentage: number;
  can_publish_trip: boolean;
  documents: DriverDocument[];
  note_moyenne: number;
  nombre_trajets: number;
  nombre_annulations: number;
  motif_rejet: string;
  motif_suspension: string;
  created_at: string;
  verified_at: string | null;
}

export interface VerificationReport {
  id: string;
  decision: string | null;
  overall_score: number;
  fraud_score: number;
  confidence_score: number;
  summary: string;
  ocr_report: Record<string, unknown>;
  identity_report: Record<string, unknown>;
  vehicle_report: Record<string, unknown>;
  insurance_report: Record<string, unknown>;
  technical_report: Record<string, unknown>;
  fraud_report: Record<string, unknown>;
  compliance_report: Record<string, unknown>;
  completed_at: string | null;
  created_at: string;
}

export interface AdminDriver {
  id: string;
  user: {
    id: string;
    username: string;
    email: string;
    first_name: string;
    last_name: string;
    full_name: string;
    photo_profil: string | null;
  };
  status: string;
  is_verified: boolean;
  completion_percentage: number;
  note_moyenne: number;
  nombre_trajets: number;
  created_at: string;
  verified_at: string | null;
  latest_report: {
    id: string;
    decision: string | null;
    overall_score: number;
    fraud_score: number;
  } | null;
  signals_count: number;
}

// ── Conducteur ───────────────────────────────────────────────────────────────

export const getVerificationStatus = async (): Promise<VerificationStatus> =>
  api(`${BASE}/driver/verification/status/`, "GET");

export const getDriverProfile = async (): Promise<DriverProfile> =>
  api(`${BASE}/driver/verification/profile/`, "GET");

export const updateDriverProfile = async (data: Partial<DriverProfile>): Promise<DriverProfile> =>
  api(`${BASE}/driver/verification/profile/update/`, "PATCH", data);

export const getVerificationReport = async (): Promise<VerificationReport> =>
  api(`${BASE}/driver/verification/report/`, "GET");

export const startVerification = async (): Promise<{ message: string; status: string }> =>
  api(`${BASE}/driver/verification/start/`, "POST");

export const uploadDocument = async (documentType: string, file: File): Promise<DriverDocument> => {
  const form = new FormData();
  form.append("document_type", documentType);
  form.append("file", file);
  return api(`${BASE}/driver/verification/documents/upload/`, "POST", form);
};

export const deleteDocument = async (documentId: string): Promise<void> =>
  api(`${BASE}/driver/verification/${documentId}/delete/`, "DELETE");

// ── Admin ────────────────────────────────────────────────────────────────────

export const adminListDrivers = async (params?: {
  status?: string;
  search?: string;
  page?: number;
  limit?: number;
}): Promise<{ count: number; page: number; pages: number; results: AdminDriver[] }> => {
  const query = new URLSearchParams();
  if (params?.status) query.set("status", params.status);
  if (params?.search) query.set("search", params.search);
  if (params?.page)   query.set("page",   String(params.page));
  if (params?.limit)  query.set("limit",  String(params.limit));
  return api(`${BASE}/admin/drivers/?${query.toString()}`, "GET");
};

export const adminGetDriver = async (id: string): Promise<DriverProfile> =>
  api(`${BASE}/admin/drivers/${id}/`, "GET");

export const adminApproveDriver = async (id: string, notes?: string): Promise<void> =>
  api(`${BASE}/admin/drivers/${id}/approve/`, "POST", { action: "APPROVE", notes });

export const adminRejectDriver = async (id: string, motif: string): Promise<void> =>
  api(`${BASE}/admin/drivers/${id}/reject/`, "POST", { action: "REJECT", motif });

export const adminSuspendDriver = async (id: string, motif: string): Promise<void> =>
  api(`${BASE}/admin/drivers/${id}/suspend/`, "POST", { action: "SUSPEND", motif });

export const adminBlockDriver = async (id: string, motif: string): Promise<void> =>
  api(`${BASE}/admin/drivers/${id}/block/`, "POST", { action: "BLOCK", motif });

export const adminReactivateDriver = async (id: string, motif?: string): Promise<void> =>
  api(`${BASE}/admin/drivers/${id}/reactivate/`, "POST", { motif });

export const adminGetDriverHistory = async (id: string) =>
  api(`${BASE}/admin/drivers/${id}/history/`, "GET");

export const adminGetDriverReports = async (id: string) =>
  api(`${BASE}/admin/drivers/${id}/reports/`, "GET");

export const adminGetDriverSignals = async (id: string) =>
  api(`${BASE}/admin/drivers/${id}/signals/`, "GET");

export const adminGetStats = async () =>
  api(`${BASE}/admin/drivers/stats/`, "GET");

// ── Signal (passager) ────────────────────────────────────────────────────────

export const signalDriver = async (driverProfileId: string, data: {
  signal_type: string;
  description: string;
  trajet?: string;
}): Promise<void> =>
  api(`${BASE}/drivers/${driverProfileId}/signal/`, "POST", data);

// ── Labels ───────────────────────────────────────────────────────────────────

export const DRIVER_STATUS_LABELS: Record<string, string> = {
  DRAFT:                "Brouillon",
  DOCUMENTS_MISSING:    "Documents manquants",
  PENDING_AI_REVIEW:    "Vérification IA en cours",
  AI_APPROVED:          "Approuvé par IA",
  AI_REJECTED:          "Rejeté par IA",
  PENDING_ADMIN_REVIEW: "En attente admin",
  ACTIVE:               "Actif",
  SUSPENDED:            "Suspendu",
  BLOCKED:              "Bloqué",
  REJECTED:             "Rejeté",
};

export const DRIVER_STATUS_COLORS: Record<string, string> = {
  DRAFT:                "badge-ghost",
  DOCUMENTS_MISSING:    "badge-warning",
  PENDING_AI_REVIEW:    "badge-info",
  AI_APPROVED:          "badge-success",
  AI_REJECTED:          "badge-error",
  PENDING_ADMIN_REVIEW: "badge-warning",
  ACTIVE:               "badge-success",
  SUSPENDED:            "badge-warning",
  BLOCKED:              "badge-error",
  REJECTED:             "badge-error",
};

export const DOCUMENT_TYPE_LABELS: Record<string, string> = {
  CNI:                    "Carte nationale d'identité",
  PASSPORT:               "Passeport",
  SELFIE_ID:              "Selfie avec pièce d'identité",
  PORTRAIT:               "Photo portrait récente",
  DRIVING_LICENSE:        "Permis de conduire",
  VEHICLE_REGISTRATION:   "Carte grise",
  INSURANCE:              "Attestation d'assurance",
  TECHNICAL_INSPECTION:   "Contrôle technique",
  VEHICLE_FRONT:          "Photo véhicule — Face avant",
  VEHICLE_REAR:           "Photo véhicule — Face arrière",
  VEHICLE_LEFT:           "Photo véhicule — Côté gauche",
  VEHICLE_RIGHT:          "Photo véhicule — Côté droit",
  VEHICLE_INTERIOR_FRONT: "Photo véhicule — Intérieur avant",
  VEHICLE_INTERIOR_REAR:  "Photo véhicule — Intérieur arrière",
  PROOF_OF_ADDRESS:       "Justificatif de domicile",
  TRANSFER_CERTIFICATE:   "Certificat de cession",
  OWNER_AUTHORIZATION:    "Autorisation propriétaire",
};

export const REQUIRED_DOCUMENTS = [
  "CNI", "SELFIE_ID", "PORTRAIT",
  "DRIVING_LICENSE",
  "VEHICLE_REGISTRATION",
  "INSURANCE",
  "TECHNICAL_INSPECTION",
  "VEHICLE_FRONT", "VEHICLE_REAR",
  "VEHICLE_LEFT", "VEHICLE_RIGHT",
  "VEHICLE_INTERIOR_FRONT", "VEHICLE_INTERIOR_REAR",
];
