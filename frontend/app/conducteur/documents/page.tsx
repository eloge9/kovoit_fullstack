"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  DOCUMENT_TYPE_LABELS,
  REQUIRED_DOCUMENTS,
  deleteDocument,
  getVerificationStatus,
  getDriverProfile,
  startVerification,
  uploadDocument,
  type DriverDocument,
  type VerificationStatus,
} from "@/src/services/verification.service";

// ── Configuration des étapes ──────────────────────────────────────────────────

const STEPS = [
  {
    id: 1,
    icon: "1",
    title: "Vérification d'identité",
    description: "Prouvez votre identité avec une pièce officielle et une photo.",
    docs: ["CNI", "SELFIE_ID", "PORTRAIT"],
    hints: {
      CNI:      "Recto de votre carte nationale d'identité, bien éclairé et net.",
      SELFIE_ID:"Tenez votre CNI à côté de votre visage. Les deux doivent être lisibles.",
      PORTRAIT: "Photo de votre visage, fond neutre, bonne luminosité.",
    },
  },
  {
    id: 2,
    icon: "2",
    title: "Permis de conduire",
    description: "Votre permis valide est requis pour proposer des trajets.",
    docs: ["DRIVING_LICENSE"],
    hints: {
      DRIVING_LICENSE: "Recto de votre permis de conduire, photo nette et lisible.",
    },
  },
  {
    id: 3,
    icon: "3",
    title: "Documents du véhicule",
    description: "La carte grise confirme que vous êtes propriétaire ou autorisé à conduire.",
    docs: ["VEHICLE_REGISTRATION"],
    hints: {
      VEHICLE_REGISTRATION: "Carte grise du véhicule, toutes les informations lisibles.",
    },
  },
  {
    id: 4,
    icon: "4",
    title: "Assurance & Contrôle technique",
    description: "Votre véhicule doit être assuré et avoir passé le contrôle technique.",
    docs: ["INSURANCE", "TECHNICAL_INSPECTION"],
    hints: {
      INSURANCE:           "Attestation d'assurance en cours de validité.",
      TECHNICAL_INSPECTION:"Rapport de contrôle technique valide.",
    },
  },
  {
    id: 5,
    icon: "5",
    title: "Photos du véhicule",
    description: "Des photos claires de votre véhicule pour rassurer les passagers.",
    docs: ["VEHICLE_FRONT","VEHICLE_REAR","VEHICLE_LEFT","VEHICLE_RIGHT","VEHICLE_INTERIOR_FRONT","VEHICLE_INTERIOR_REAR"],
    hints: {
      VEHICLE_FRONT:          "Face avant du véhicule, plaque visible.",
      VEHICLE_REAR:           "Face arrière du véhicule, plaque visible.",
      VEHICLE_LEFT:           "Côté gauche complet du véhicule.",
      VEHICLE_RIGHT:          "Côté droit complet du véhicule.",
      VEHICLE_INTERIOR_FRONT: "Sièges avant et tableau de bord.",
      VEHICLE_INTERIOR_REAR:  "Sièges arrière, propreté visible.",
    },
  },
] as const;

const TOTAL_REQUIRED = REQUIRED_DOCUMENTS.length;

// ── Composant carte document ──────────────────────────────────────────────────

function DocCard({
  docType, doc, hint, onUpload, onDelete, uploading, locked,
}: {
  docType: string;
  doc: DriverDocument | undefined;
  hint: string;
  onUpload: (t: string, f: File) => void;
  onDelete: (id: string) => void;
  uploading: boolean;
  locked: boolean;
}) {
  const inputRef = useRef<HTMLInputElement>(null);
  const label    = DOCUMENT_TYPE_LABELS[docType] ?? docType;

  const statusStyle = doc?.status === "VERIFIED"
    ? { border: "border-success/40 bg-success/5", badge: "badge-success", text: "Vérifié" }
    : doc?.status === "REJECTED"
    ? { border: "border-error/30 bg-error/5",    badge: "badge-error",   text: "Rejeté" }
    : doc?.status === "PENDING" || doc?.status === "PROCESSING"
    ? { border: "border-primary/30 bg-primary/5", badge: "badge-info",   text: "En attente" }
    : { border: "border-base-200 bg-base-50",      badge: "",             text: "" };  return (
    <div className={`rounded-2xl border-2 p-5 flex flex-col gap-4 transition-all duration-200 ${statusStyle.border}`}>

      {/* Header */}
      <div className="flex items-start justify-between gap-3">
        <div className="flex-1">
          <p className="font-semibold text-sm text-base-content">{label}</p>
          <p className="text-xs text-base-content/50 mt-0.5 leading-relaxed">{hint}</p>
        </div>
        {doc && statusStyle.text && (
          <span className={`badge badge-sm shrink-0 ${statusStyle.badge}`}>{statusStyle.text}</span>
        )}
      </div>

      {/* Aperçu image */}
      {doc?.file_url && (
        <div className="relative rounded-xl overflow-hidden bg-base-200 aspect-video">
          {doc.file_url.match(/\.(jpg|jpeg|png|webp)$/i) ? (
            <img src={doc.file_url} alt={label} className="w-full h-full object-cover" />
          ) : (
            <div className="flex items-center justify-center h-full gap-2 text-base-content/40">
              <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
              <span className="text-sm">{doc.file_name}</span>
            </div>
          )}
          {doc.status === "VERIFIED" && (
            <div className="absolute inset-0 bg-success/10 flex items-center justify-center">
              <div className="bg-success text-white rounded-full p-2">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
                </svg>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Zone upload vide */}
      {!doc && !locked && (
        <button
          onClick={() => inputRef.current?.click()}
          disabled={uploading}
          className="border-2 border-dashed border-base-300 rounded-xl p-6 flex flex-col items-center gap-2 hover:border-primary/50 hover:bg-primary/5 transition-all group"
        >
          {uploading ? (
            <span className="loading loading-spinner loading-md text-primary" />
          ) : (
            <>
              <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8 text-base-content/30 group-hover:text-primary transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
              </svg>
              <span className="text-sm text-base-content/50 group-hover:text-primary transition-colors font-medium">
                Choisir un fichier
              </span>
              <span className="text-xs text-base-content/30">JPG, PNG, PDF — max 10 Mo</span>
            </>
          )}
        </button>
      )}

      {/* Motif rejet */}
      {doc?.rejection_reason && (
        <div className="flex gap-2 bg-error/10 rounded-xl p-3">
          <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 text-error shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <p className="text-xs text-error leading-relaxed">{doc.rejection_reason}</p>
        </div>
      )}

      {/* Actions */}
      <input ref={inputRef} type="file" accept="image/jpeg,image/png,image/webp,application/pdf" className="hidden"
        onChange={(e) => { const f = e.target.files?.[0]; if (f) onUpload(docType, f); e.target.value = ""; }} />

      {!locked && doc && (
        <div className="flex gap-2">
          <button onClick={() => inputRef.current?.click()} disabled={uploading}
            className="btn btn-sm btn-primary flex-1 rounded-full">
            {uploading ? <span className="loading loading-spinner loading-xs" /> : "Remplacer"}
          </button>
          {doc.status !== "VERIFIED" && (
            <button onClick={() => onDelete(doc.id)} disabled={uploading}
              className="btn btn-sm btn-ghost rounded-full border border-base-200">
              Supprimer
            </button>
          )}
        </div>
      )}
      {locked && doc?.file_url && (
        <a href={doc.file_url} target="_blank" rel="noreferrer"
          className="btn btn-sm btn-ghost btn-block rounded-full border border-base-200">
          Voir le document
        </a>
      )}
    </div>
  );
}

// ── Page principale ───────────────────────────────────────────────────────────

export default function DocumentsPage() {
  const router  = useRouter();
  const [step,        setStep]       = useState(0); // index dans STEPS
  const [status,      setStatus]     = useState<VerificationStatus | null>(null);
  const [docsMap,     setDocsMap]    = useState<Record<string, DriverDocument>>({});
  const [loading,     setLoading]    = useState(true);
  const [uploading,   setUploading]  = useState<string | null>(null);
  const [error,       setError]      = useState<string | null>(null);
  const [success,     setSuccess]    = useState<string | null>(null);
  const [launching,   setLaunching]  = useState(false);

  const locked = ["PENDING_AI_REVIEW", "PENDING_ADMIN_REVIEW", "ACTIVE"].includes(status?.status ?? "");

  const load = useCallback(async () => {
    try {
      const [s, profile] = await Promise.all([getVerificationStatus(), getDriverProfile()]);
      setStatus(s);
      const map: Record<string, DriverDocument> = {};
      for (const d of profile.documents) map[d.document_type] = d;
      setDocsMap(map);
    } catch {
      setError("Impossible de charger vos documents.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  // Dismiss alertes après 4s
  useEffect(() => {
    if (!success && !error) return;
    const t = setTimeout(() => { setSuccess(null); setError(null); }, 4000);
    return () => clearTimeout(t);
  }, [success, error]);

  const handleUpload = async (type: string, file: File) => {
    setUploading(type); setError(null); setSuccess(null);
    try {
      await uploadDocument(type, file);
      setSuccess(`${DOCUMENT_TYPE_LABELS[type] ?? type} enregistré`);
      await load();
    } catch (e: unknown) {
      const err = e as { response?: { data?: { file?: string[]; detail?: string } } };
      setError(err?.response?.data?.file?.[0] ?? err?.response?.data?.detail ?? "Erreur lors de l'upload.");
    } finally {
      setUploading(null);
    }
  };

  const handleDelete = async (id: string) => {
    try { await deleteDocument(id); await load(); }
    catch { setError("Erreur lors de la suppression."); }
  };

  const handleLaunch = async () => {
    setLaunching(true); setError(null);
    try {
      await startVerification();
      router.push("/conducteur/verification");
    } catch (e: unknown) {
      const err = e as { response?: { data?: { message?: string } } };
      setError(err?.response?.data?.message ?? "Impossible de lancer la vérification.");
      setLaunching(false);
    }
  };

  // ── Métriques globales ────────────────────────────────────────────────────
  const uploadedCount  = REQUIRED_DOCUMENTS.filter((d) => docsMap[d]).length;
  const pct            = Math.round((uploadedCount / TOTAL_REQUIRED) * 100);
  const allDone        = uploadedCount === TOTAL_REQUIRED;
  const currentStep    = STEPS[step];
  const stepDocs       = currentStep.docs as readonly string[];
  const stepUploaded   = stepDocs.filter((d) => docsMap[d]).length;
  const requiredInStep = stepDocs.filter((d) => REQUIRED_DOCUMENTS.includes(d));
  const canNext        = requiredInStep.every((d) => !!docsMap[d]);

  // ── Skeleton ──────────────────────────────────────────────────────────────
  if (loading) {
    return (
      <div className="space-y-6 animate-pulse">
        <div className="h-28 bg-base-200 rounded-2xl" />
        <div className="h-8 bg-base-200 rounded-2xl w-2/3" />
        <div className="grid sm:grid-cols-2 gap-4">
          {[1,2,3].map(i => <div key={i} className="h-56 bg-base-200 rounded-2xl" />)}
        </div>
      </div>
    );
  }

  // ── Vue verrouillée ───────────────────────────────────────────────────────
  if (locked) {
    return (
      <div className="space-y-6">
        <Header pct={pct} uploaded={uploadedCount} total={TOTAL_REQUIRED} />
        <div className="bg-info/10 border border-info/30 rounded-2xl p-6 flex items-start gap-4">
          <div className="w-10 h-10 rounded-full bg-info/15 flex items-center justify-center shrink-0">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-info" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
            </svg>
          </div>
          <div>
            <p className="font-semibold text-base-content">Dossier en cours de vérification</p>
            <p className="text-sm text-base-content/60 mt-1">
              Votre dossier est actuellement analysé. Les documents ne peuvent pas être modifiés pendant cette phase.
            </p>
            <button onClick={() => router.push("/conducteur/verification")}
              className="btn btn-sm btn-primary rounded-full mt-3">
              Suivre l'avancement →
            </button>
          </div>
        </div>
      </div>
    );
  }

  // ── Vue normale : étapes ──────────────────────────────────────────────────
  return (
    <div className="space-y-6 pb-8">

      {/* Header global */}
      <Header pct={pct} uploaded={uploadedCount} total={TOTAL_REQUIRED} />

      {/* Toast alertes */}
      {(error || success) && (
        <div className={`alert ${error ? "alert-error" : "alert-success"} rounded-xl shadow-md`}>
          <span className="text-sm">{error ?? success}</span>
        </div>
      )}

      {/* Stepper horizontal */}
      <div className="bg-base-100 rounded-2xl border border-base-200 p-4">
        <div className="flex items-center justify-between overflow-x-auto pb-1 gap-1">
          {STEPS.map((s, i) => {
            const stepDone = s.docs.filter(d => REQUIRED_DOCUMENTS.includes(d)).every(d => !!docsMap[d]);
            const isActive = i === step;
            return (
              <button key={s.id} onClick={() => setStep(i)}
                className={`flex flex-col items-center gap-1.5 px-3 py-2 rounded-xl transition-all min-w-[64px] flex-1 ${
                  isActive ? "bg-primary/10" : "hover:bg-base-200/60"
                }`}>
                <div className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold transition-all ${
                  stepDone  ? "bg-success text-white" :
                  isActive  ? "bg-primary text-white" :
                  "bg-base-200 text-base-content/40"
                }`}>
                  {stepDone ? (
                    <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
                    </svg>
                  ) : (
                    <span>{s.icon}</span>
                  )}
                </div>
                <span className={`text-xs font-medium leading-tight text-center hidden sm:block ${
                  isActive ? "text-primary" : stepDone ? "text-success" : "text-base-content/40"
                }`}>
                  {s.title.split(" ")[0]}
                </span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Carte étape courante */}
      <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">

        {/* En-tête étape */}
        <div className="px-6 py-5 border-b border-base-200 bg-gradient-to-r from-base-100 to-base-200/30">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                <span className="text-sm font-bold text-primary">{step + 1}</span>
              </div>
              <div>
                <p className="text-xs text-base-content/40 font-medium mb-0.5">
                  Étape {step + 1} sur {STEPS.length}
                </p>
                <h2 className="text-lg font-bold text-base-content">{currentStep.title}</h2>
              </div>
            </div>
            <span className={`badge badge-sm font-semibold ${
              stepUploaded === stepDocs.length ? "badge-success" :
              stepUploaded > 0 ? "badge-warning" : "badge-ghost"
            }`}>
              {stepUploaded}/{stepDocs.length}
            </span>
          </div>
          <p className="text-sm text-base-content/50 mt-2 ml-12">
            {currentStep.description}
          </p>
        </div>

        {/* Documents de l'étape */}
        <div className="p-5">
          <div className={`grid gap-4 ${
            stepDocs.length === 1 ? "grid-cols-1 max-w-sm" :
            stepDocs.length <= 3 ? "sm:grid-cols-2 lg:grid-cols-3" :
            "sm:grid-cols-2 lg:grid-cols-3"
          }`}>
            {stepDocs.map((docType) => (
              <DocCard
                key={docType}
                docType={docType}
                doc={docsMap[docType]}
                hint={(currentStep.hints as Record<string, string>)[docType] ?? ""}
                onUpload={handleUpload}
                onDelete={handleDelete}
                uploading={uploading === docType}
                locked={locked}
              />
            ))}
          </div>
        </div>

        {/* Navigation */}
        <div className="px-5 py-4 border-t border-base-200 flex items-center justify-between gap-3">
          <button
            onClick={() => setStep(s => Math.max(0, s - 1))}
            disabled={step === 0}
            className="btn btn-ghost rounded-full border border-base-200 gap-2"
          >
            ← Précédent
          </button>

          <div className="flex items-center gap-1.5">
            {STEPS.map((_, i) => (
              <div key={i} className={`rounded-full transition-all ${
                i === step ? "w-6 h-2 bg-primary" :
                i < step   ? "w-2 h-2 bg-success" :
                "w-2 h-2 bg-base-300"
              }`} />
            ))}
          </div>

          {step < STEPS.length - 1 ? (
            <button
              onClick={() => setStep(s => Math.min(STEPS.length - 1, s + 1))}
              disabled={!canNext}
              className="btn btn-primary rounded-full gap-2 relative"
            >
              Continuer →
              {!canNext && (
                <div className="tooltip tooltip-top" data-tip="Documents obligatoires manquants">
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 opacity-70" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
              )}
            </button>
          ) : (
            <button
              onClick={handleLaunch}
              disabled={!allDone || launching}
              className="btn btn-success rounded-full gap-2"
            >
              {launching
                ? <><span className="loading loading-spinner loading-xs" /> Lancement…</>
                : "Terminer"
              }
            </button>
          )}
        </div>
      </div>

      {/* Résumé des étapes */}
      <div className="grid grid-cols-5 gap-2">
        {STEPS.map((s, i) => {
          const done = s.docs.filter(d => REQUIRED_DOCUMENTS.includes(d)).every(d => !!docsMap[d]);
          return (
            <button key={s.id} onClick={() => setStep(i)}
              className={`rounded-xl p-3 text-center transition-all border ${
                i === step ? "border-primary bg-primary/5" :
                done ? "border-success/40 bg-success/5" :
                "border-base-200 hover:border-base-300"
              }`}>
              <div className="flex items-center justify-center h-6">
                {done ? (
                  <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
                  </svg>
                ) : (
                  <span className="text-sm font-bold text-base-content/40">{s.id}</span>
                )}
              </div>
              <p className="text-xs mt-1 font-medium leading-tight hidden sm:block text-base-content/60">
                {s.title.length > 12 ? s.title.slice(0, 12) + "…" : s.title}
              </p>
            </button>
          );
        })}
      </div>

    </div>
  );
}

// ── Header global ─────────────────────────────────────────────────────────────

function Header({ pct, uploaded, total }: { pct: number; uploaded: number; total: number }) {
  const remaining = total - uploaded;
  return (
    <div className="bg-gradient-to-br from-base-100 to-base-200/40 rounded-2xl border border-base-200 p-6 space-y-4">
      <div>
        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">
          Conducteur · Activation
        </p>
        <h1 className="text-2xl font-bold text-base-content">Activation du compte conducteur</h1>
        <p className="text-sm text-base-content/50 mt-1">
          Complétez votre dossier pour commencer à proposer des trajets.
        </p>
      </div>

      <div className="space-y-2">
        <div className="flex items-center justify-between text-sm">
          <span className="text-base-content/60 font-medium">
            {uploaded} / {total} documents complétés
          </span>
          <span className="font-bold text-primary text-base">{pct}%</span>
        </div>
        <div className="w-full bg-base-200 rounded-full h-2.5 overflow-hidden">
          <div
            className="h-full rounded-full bg-gradient-to-r from-primary to-primary/80 transition-all duration-700"
            style={{ width: `${pct}%` }}
          />
        </div>
        <div className="flex items-center justify-between text-xs text-base-content/40">
          {remaining > 0 ? (
            <span>Encore <strong className="text-base-content/70">{remaining} document{remaining > 1 ? "s" : ""}</strong> à fournir</span>
          ) : (
            <span className="text-success font-semibold">Tous les documents sont fournis</span>
          )}
          <span>~5 min</span>
        </div>
      </div>
    </div>
  );
}
