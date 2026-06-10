"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import {
  DOCUMENT_TYPE_LABELS,
  REQUIRED_DOCUMENTS,
  deleteDocument,
  getVerificationStatus,
  uploadDocument,
  type DriverDocument,
  type VerificationStatus,
} from "@/src/services/verification.service";

const OPTIONAL_DOCS = ["PASSPORT", "PROOF_OF_ADDRESS", "TRANSFER_CERTIFICATE", "OWNER_AUTHORIZATION"];

const DOC_GROUPS = [
  {
    title:   "Identité",
    docs:    ["CNI", "SELFIE_ID", "PORTRAIT", "PASSPORT"],
    icon:    "🪪",
  },
  {
    title:   "Conduite",
    docs:    ["DRIVING_LICENSE"],
    icon:    "🏎️",
  },
  {
    title:   "Véhicule",
    docs:    ["VEHICLE_REGISTRATION"],
    icon:    "📋",
  },
  {
    title:   "Assurance & Contrôle",
    docs:    ["INSURANCE", "TECHNICAL_INSPECTION"],
    icon:    "🛡️",
  },
  {
    title:   "Photos véhicule",
    docs:    ["VEHICLE_FRONT", "VEHICLE_REAR", "VEHICLE_LEFT", "VEHICLE_RIGHT", "VEHICLE_INTERIOR_FRONT", "VEHICLE_INTERIOR_REAR"],
    icon:    "📸",
  },
  {
    title:   "Documents optionnels",
    docs:    ["PROOF_OF_ADDRESS", "TRANSFER_CERTIFICATE", "OWNER_AUTHORIZATION"],
    icon:    "📁",
  },
];

const STATUS_CONFIG: Record<string, { label: string; cls: string }> = {
  PENDING:    { label: "En attente",   cls: "badge-warning" },
  PROCESSING: { label: "En cours",     cls: "badge-info" },
  VERIFIED:   { label: "Vérifié",      cls: "badge-success" },
  REJECTED:   { label: "Rejeté",       cls: "badge-error" },
  EXPIRED:    { label: "Expiré",       cls: "badge-error" },
};

function DocumentCard({
  docType,
  doc,
  onUpload,
  onDelete,
  uploading,
  locked,
}: {
  docType: string;
  doc: DriverDocument | undefined;
  onUpload: (type: string, file: File) => void;
  onDelete: (id: string) => void;
  uploading: boolean;
  locked: boolean;
}) {
  const inputRef = useRef<HTMLInputElement>(null);
  const isRequired = REQUIRED_DOCUMENTS.includes(docType);
  const label      = DOCUMENT_TYPE_LABELS[docType] ?? docType;
  const statusCfg  = doc ? (STATUS_CONFIG[doc.status] ?? { label: doc.status, cls: "badge-ghost" }) : null;

  return (
    <div className={`border rounded-xl p-4 flex flex-col gap-3 ${doc?.status === "VERIFIED" ? "border-success/40 bg-success/5" : doc?.status === "REJECTED" ? "border-error/30 bg-error/5" : "border-base-200 bg-base-100"}`}>
      <div className="flex items-start justify-between gap-2">
        <div>
          <p className="font-medium text-sm text-base-content">
            {label}
            {isRequired && <span className="text-error ml-1">*</span>}
          </p>
          {doc?.file_name && (
            <p className="text-xs text-base-content/40 mt-0.5 truncate max-w-[180px]">{doc.file_name}</p>
          )}
          {doc?.date_expiration && (
            <p className={`text-xs mt-0.5 ${doc.is_expired ? "text-error" : doc.days_until_expiration && doc.days_until_expiration <= 30 ? "text-warning" : "text-base-content/40"}`}>
              Exp. {new Date(doc.date_expiration).toLocaleDateString("fr-FR")}
              {doc.is_expired && " — EXPIRÉ"}
              {!doc.is_expired && doc.days_until_expiration !== null && doc.days_until_expiration <= 30 && ` — dans ${doc.days_until_expiration}j`}
            </p>
          )}
        </div>
        {statusCfg && (
          <span className={`badge badge-sm ${statusCfg.cls} shrink-0`}>{statusCfg.label}</span>
        )}
      </div>

      {doc?.rejection_reason && (
        <p className="text-xs text-error bg-error/10 rounded-lg p-2">{doc.rejection_reason}</p>
      )}

      <div className="flex gap-2 mt-auto">
        {!locked && (
          <>
            <input
              ref={inputRef}
              type="file"
              accept="image/jpeg,image/png,image/webp,application/pdf"
              className="hidden"
              onChange={(e) => {
                const f = e.target.files?.[0];
                if (f) onUpload(docType, f);
                e.target.value = "";
              }}
            />
            <button
              className="btn btn-xs btn-primary flex-1 rounded-full"
              onClick={() => inputRef.current?.click()}
              disabled={uploading}
            >
              {uploading ? <span className="loading loading-spinner loading-xs" /> : doc ? "Remplacer" : "Uploader"}
            </button>
            {doc && doc.status !== "VERIFIED" && (
              <button
                className="btn btn-xs btn-ghost rounded-full border border-base-200"
                onClick={() => onDelete(doc.id)}
                disabled={uploading}
              >
                Supprimer
              </button>
            )}
          </>
        )}
        {locked && doc?.file_url && (
          <a href={doc.file_url} target="_blank" rel="noreferrer" className="btn btn-xs btn-ghost btn-block rounded-full border border-base-200">
            Voir le fichier
          </a>
        )}
      </div>
    </div>
  );
}

export default function DocumentsPage() {
  const [status, setStatus]   = useState<VerificationStatus | null>(null);
  const [docsMap, setDocsMap] = useState<Record<string, DriverDocument>>({});
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState<string | null>(null);
  const [error, setError]     = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const locked = ["PENDING_AI_REVIEW", "PENDING_ADMIN_REVIEW", "ACTIVE"].includes(status?.status ?? "");

  const load = useCallback(async () => {
    try {
      const s = await getVerificationStatus();
      setStatus(s);

      // Charger le profil pour les docs
      const { getDriverProfile } = await import("@/src/services/verification.service");
      const profile = await getDriverProfile();
      const map: Record<string, DriverDocument> = {};
      for (const d of profile.documents) {
        map[d.document_type] = d;
      }
      setDocsMap(map);
    } catch {
      setError("Impossible de charger vos documents.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const handleUpload = async (type: string, file: File) => {
    setUploading(type);
    setError(null);
    setSuccess(null);
    try {
      const doc = await uploadDocument(type, file);
      setDocsMap((prev) => ({ ...prev, [type]: doc }));
      setSuccess(`${DOCUMENT_TYPE_LABELS[type] ?? type} uploadé avec succès.`);
      await load();
    } catch (e: unknown) {
      const err = e as { response?: { data?: { file?: string[]; detail?: string } } };
      setError(err?.response?.data?.file?.[0] ?? err?.response?.data?.detail ?? "Erreur lors de l'upload.");
    } finally {
      setUploading(null);
    }
  };

  const handleDelete = async (id: string) => {
    try {
      await deleteDocument(id);
      await load();
    } catch {
      setError("Erreur lors de la suppression.");
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <span className="loading loading-spinner loading-lg text-primary" />
      </div>
    );
  }

  const pct = status?.completion_percentage ?? 0;

  return (
    <div className="space-y-8">
      {/* En-tête */}
      <div className="pb-6 border-b border-base-300">
        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">
          Vérification — Documents
        </p>
        <h1 className="text-2xl font-bold text-base-content">Mes documents</h1>
        <p className="text-sm text-base-content/50 mt-1">
          Uploadez tous les documents obligatoires pour activer votre compte conducteur.
        </p>
      </div>

      {/* Barre de progression */}
      <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
        <div className="flex items-center justify-between mb-2">
          <p className="text-sm font-semibold text-base-content">Progression documents</p>
          <span className="text-sm font-bold text-primary">{pct}%</span>
        </div>
        <progress className="progress progress-primary w-full" value={pct} max="100" />
        <p className="text-xs text-base-content/40 mt-2">
          {status?.uploaded_documents.length ?? 0} / {status?.required_documents.length ?? 0} documents obligatoires uploadés
        </p>
      </div>

      {/* Bannière statut verrouillé */}
      {locked && (
        <div className="alert alert-info rounded-xl">
          <span className="text-sm">
            Votre dossier est en cours de vérification. Les documents ne peuvent pas être modifiés.
          </span>
        </div>
      )}

      {/* Alertes */}
      {error   && <div className="alert alert-error rounded-xl"><span>{error}</span></div>}
      {success && <div className="alert alert-success rounded-xl"><span>{success}</span></div>}

      {/* Groupes de documents */}
      <div className="space-y-6">
        {DOC_GROUPS.map((group) => (
          <div key={group.title} className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
            <div className="px-6 py-4 border-b border-base-200 flex items-center gap-2">
              <span>{group.icon}</span>
              <p className="font-semibold text-sm text-base-content">{group.title}</p>
              <span className="text-xs text-base-content/40 ml-auto">
                {group.docs.filter((d) => docsMap[d]).length} / {group.docs.length}
              </span>
            </div>
            <div className="p-4 grid sm:grid-cols-2 lg:grid-cols-3 gap-3">
              {group.docs.map((docType) => (
                <DocumentCard
                  key={docType}
                  docType={docType}
                  doc={docsMap[docType]}
                  onUpload={handleUpload}
                  onDelete={handleDelete}
                  uploading={uploading === docType}
                  locked={locked}
                />
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
