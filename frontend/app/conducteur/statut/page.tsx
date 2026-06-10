"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import {
  DRIVER_STATUS_COLORS,
  DRIVER_STATUS_LABELS,
  DOCUMENT_TYPE_LABELS,
  getVerificationStatus,
  getVerificationReport,
  startVerification,
  type VerificationReport,
  type VerificationStatus,
} from "@/src/services/verification.service";

function ScoreRing({ value, label, color = "text-primary" }: { value: number; label: string; color?: string }) {
  const radius      = 28;
  const circumference = 2 * Math.PI * radius;
  const filled      = (value / 100) * circumference;
  const stroke      = value >= 80 ? "#22c55e" : value >= 50 ? "#f59e0b" : "#ef4444";

  return (
    <div className="flex flex-col items-center gap-1">
      <div className="relative w-16 h-16">
        <svg className="w-full h-full -rotate-90" viewBox="0 0 70 70">
          <circle cx="35" cy="35" r={radius} fill="none" stroke="currentColor" strokeWidth="6" className="text-base-200" />
          <circle
            cx="35" cy="35" r={radius} fill="none"
            stroke={stroke} strokeWidth="6"
            strokeDasharray={circumference}
            strokeDashoffset={circumference - filled}
            strokeLinecap="round"
          />
        </svg>
        <span className="absolute inset-0 flex items-center justify-center text-xs font-bold text-base-content">
          {value}%
        </span>
      </div>
      <p className="text-xs text-base-content/50 text-center leading-tight">{label}</p>
    </div>
  );
}

function StatusStep({
  label,
  sublabel,
  done,
  active,
  failed,
}: {
  label: string;
  sublabel: string;
  done: boolean;
  active: boolean;
  failed: boolean;
}) {
  return (
    <div className={`flex items-start gap-3 p-4 rounded-xl border ${done ? "border-success/40 bg-success/5" : failed ? "border-error/30 bg-error/5" : active ? "border-primary/40 bg-primary/5" : "border-base-200 bg-base-100"}`}>
      <div className={`w-6 h-6 rounded-full flex items-center justify-center shrink-0 mt-0.5 text-xs font-bold ${done ? "bg-success text-white" : failed ? "bg-error text-white" : active ? "bg-primary text-white" : "bg-base-200 text-base-content/30"}`}>
        {done ? "✓" : failed ? "✗" : active ? <span className="loading loading-spinner loading-xs" /> : "·"}
      </div>
      <div>
        <p className={`text-sm font-medium ${done ? "text-success" : failed ? "text-error" : active ? "text-primary" : "text-base-content/50"}`}>
          {label}
        </p>
        <p className="text-xs text-base-content/40 mt-0.5">{sublabel}</p>
      </div>
    </div>
  );
}

export default function VerificationStatusPage() {
  const [status, setStatus]   = useState<VerificationStatus | null>(null);
  const [report, setReport]   = useState<VerificationReport | null>(null);
  const [loading, setLoading] = useState(true);
  const [starting, setStarting] = useState(false);
  const [message, setMessage]   = useState<{ type: "success" | "error"; text: string } | null>(null);

  const load = useCallback(async () => {
    try {
      const s = await getVerificationStatus();
      setStatus(s);
      if (s.latest_report) {
        try {
          const r = await getVerificationReport();
          setReport(r);
        } catch {
          // Pas de rapport encore
        }
      }
    } catch {
      setMessage({ type: "error", text: "Erreur lors du chargement du statut." });
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  // Rafraîchir automatiquement si en cours de vérification
  useEffect(() => {
    if (status?.status === "PENDING_AI_REVIEW") {
      const interval = setInterval(load, 10000);
      return () => clearInterval(interval);
    }
  }, [status?.status, load]);

  const handleStartVerification = async () => {
    setStarting(true);
    setMessage(null);
    try {
      const res = await startVerification();
      setMessage({ type: "success", text: res.message });
      await load();
    } catch (e: unknown) {
      const err = e as { response?: { data?: { message?: string; missing_documents?: string[] } } };
      const errMsg = err?.response?.data?.message ?? "Erreur lors du lancement.";
      setMessage({ type: "error", text: errMsg });
    } finally {
      setStarting(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <span className="loading loading-spinner loading-lg text-primary" />
      </div>
    );
  }

  const st = status?.status ?? "";
  const isActive   = st === "ACTIVE";
  const isPending  = st === "PENDING_AI_REVIEW" || st === "PENDING_ADMIN_REVIEW";
  const isRejected = st === "AI_REJECTED" || st === "REJECTED";
  const isSuspended = st === "SUSPENDED" || st === "BLOCKED";
  const canStart   = !isPending && !isActive && !isSuspended;

  // Sous-label dynamique pour l'étape Vérification IA
  const aiSublabel = (() => {
    if (st === "PENDING_AI_REVIEW")  return "Analyse en cours…";
    if (st === "AI_REJECTED")        return "Documents non conformes";
    if (report?.overall_score)       return `Terminée — score : ${report.overall_score}%`;
    if (["AI_APPROVED", "PENDING_ADMIN_REVIEW", "ACTIVE"].includes(st))
                                     return "Documents validés par l'IA";
    return "En attente du lancement";
  })();

  // Étapes du workflow
  const steps = [
    {
      label:    "Inscription",
      sublabel: "Compte créé",
      done:     true,
      active:   false,
      failed:   false,
    },
    {
      label:    "Documents uploadés",
      sublabel: `${status?.uploaded_documents.length ?? 0} / ${status?.required_documents.length ?? 0} documents`,
      done:     (status?.completion_percentage ?? 0) === 100,
      active:   (status?.completion_percentage ?? 0) > 0 && (status?.completion_percentage ?? 0) < 100,
      failed:   false,
    },
    {
      label:    "Vérification IA",
      sublabel: aiSublabel,
      done:     ["AI_APPROVED", "PENDING_ADMIN_REVIEW", "ACTIVE"].includes(st),
      active:   st === "PENDING_AI_REVIEW",
      failed:   st === "AI_REJECTED",
    },
    {
      label:    "Validation administrateur",
      sublabel: isActive ? "Compte activé" : st === "PENDING_ADMIN_REVIEW" ? "En attente de validation" : st === "AI_APPROVED" ? "Prête pour validation" : "Non démarrée",
      done:     isActive,
      active:   st === "PENDING_ADMIN_REVIEW" || st === "AI_APPROVED",
      failed:   st === "REJECTED",
    },
  ];

  return (
    <div className="space-y-8">
      {/* En-tête */}
      <div className="pb-6 border-b border-base-300">
        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">
          Vérification conducteur
        </p>
        <div className="flex items-center gap-3">
          <h1 className="text-2xl font-bold text-base-content">Statut de vérification</h1>
          <span className={`badge badge-sm font-medium ${DRIVER_STATUS_COLORS[st] ?? "badge-ghost"}`}>
            {DRIVER_STATUS_LABELS[st] ?? st}
          </span>
        </div>
      </div>

      {/* Alertes */}
      {message && (
        <div className={`alert ${message.type === "success" ? "alert-success" : "alert-error"} rounded-xl`}>
          <span className="text-sm">{message.text}</span>
        </div>
      )}

      {status?.motif_rejet && (
        <div className="alert alert-error rounded-xl">
          <div>
            <p className="font-semibold text-sm">Motif de rejet :</p>
            <p className="text-sm mt-1">{status.motif_rejet}</p>
          </div>
        </div>
      )}

      {status?.motif_suspension && (
        <div className="alert alert-warning rounded-xl">
          <div>
            <p className="font-semibold text-sm">Motif de suspension :</p>
            <p className="text-sm mt-1">{status.motif_suspension}</p>
          </div>
        </div>
      )}

      {/* Barre progression globale */}
      <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
        <div className="flex items-center justify-between mb-2">
          <p className="text-sm font-semibold">Progression globale</p>
          <span className="text-sm font-bold text-primary">{status?.completion_percentage ?? 0}%</span>
        </div>
        <progress className="progress progress-primary w-full" value={status?.completion_percentage ?? 0} max="100" />
      </div>

      {/* Workflow étapes */}
      <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
        <div className="px-6 py-4 border-b border-base-200">
          <p className="text-xs font-semibold text-base-content/50 uppercase tracking-widest">Workflow de vérification</p>
        </div>
        <div className="p-4 grid sm:grid-cols-2 gap-3">
          {steps.map((step) => (
            <StatusStep key={step.label} {...step} />
          ))}
        </div>
      </div>

      {/* Scores IA */}
      {report && report.overall_score > 0 && (
        <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
          <div className="px-6 py-4 border-b border-base-200">
            <p className="text-xs font-semibold text-base-content/50 uppercase tracking-widest">Résultats vérification IA</p>
          </div>
          <div className="p-6">
            <div className="flex flex-wrap justify-around gap-6 mb-6">
              <ScoreRing value={report.overall_score}  label="Score global" />
              <ScoreRing value={100 - report.fraud_score} label="Anti-fraude" />
              <ScoreRing value={report.confidence_score}  label="Confiance" />
            </div>
            {report.summary && (
              <div className="bg-base-200/60 rounded-xl p-4">
                <p className="text-xs font-semibold text-base-content/50 uppercase tracking-widest mb-2">Résumé IA</p>
                <pre className="text-xs text-base-content/70 whitespace-pre-wrap font-mono leading-relaxed">
                  {report.summary}
                </pre>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Documents manquants */}
      {(status?.missing_documents.length ?? 0) > 0 && (
        <div className="bg-base-100 rounded-2xl border border-warning/30 overflow-hidden">
          <div className="px-6 py-4 border-b border-warning/20 flex items-center justify-between">
            <p className="text-xs font-semibold text-warning uppercase tracking-widest">Documents manquants</p>
            <Link href="/conducteur/documents" className="btn btn-xs btn-warning btn-outline rounded-full">
              Uploader
            </Link>
          </div>
          <ul className="p-4 space-y-1">
            {status!.missing_documents.map((d) => (
              <li key={d} className="flex items-center gap-2 text-sm text-base-content/70">
                <span className="text-warning">•</span>
                {DOCUMENT_TYPE_LABELS[d] ?? d}
              </li>
            ))}
          </ul>
        </div>
      )}

      {/* Actions */}
      <div className="flex flex-wrap gap-3">
        {canStart && (status?.completion_percentage ?? 0) === 100 && (
          <button
            className="btn btn-primary rounded-full"
            onClick={handleStartVerification}
            disabled={starting}
          >
            {starting ? <span className="loading loading-spinner loading-sm" /> : "Lancer la vérification IA"}
          </button>
        )}

        {canStart && (status?.completion_percentage ?? 0) < 100 && (
          <Link href="/conducteur/documents" className="btn btn-primary rounded-full">
            Compléter mes documents
          </Link>
        )}

        {isActive && (
          <Link href="/conducteur/trajets/create" className="btn btn-success rounded-full">
            Proposer mon premier trajet
          </Link>
        )}

        <Link href="/conducteur/documents" className="btn btn-ghost rounded-full border border-base-200">
          Gérer mes documents
        </Link>
      </div>
    </div>
  );
}
