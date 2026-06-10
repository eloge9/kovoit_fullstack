"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import {
  DOCUMENT_TYPE_LABELS,
  DRIVER_STATUS_COLORS,
  DRIVER_STATUS_LABELS,
  REQUIRED_DOCUMENTS,
  getVerificationStatus,
  type VerificationStatus,
} from "@/src/services/verification.service";

const WORKFLOW_STEPS = [
  {
    id:    "profile",
    label: "Profil complété",
    href:  "/conducteur/profil",
  },
  {
    id:    "documents",
    label: "Documents uploadés",
    href:  "/conducteur/documents",
  },
  {
    id:    "ai",
    label: "Vérification IA",
    href:  "/conducteur/statut",
  },
  {
    id:    "admin",
    label: "Validation admin",
    href:  "/conducteur/statut",
  },
];

function ProgressBar({ label, pct }: { label: string; pct: number }) {
  const color = pct === 100 ? "progress-success" : pct >= 50 ? "progress-warning" : "progress-error";
  return (
    <div>
      <div className="flex justify-between mb-1">
        <span className="text-xs text-base-content/60">{label}</span>
        <span className="text-xs font-bold">{pct}%</span>
      </div>
      <progress className={`progress ${color} w-full h-2`} value={pct} max="100" />
    </div>
  );
}

export default function VerificationPage() {
  const [status, setStatus]   = useState<VerificationStatus | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getVerificationStatus()
      .then(setStatus)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <span className="loading loading-spinner loading-lg text-primary" />
      </div>
    );
  }

  const st   = status?.status ?? "DOCUMENTS_MISSING";
  const pct  = status?.completion_percentage ?? 0;

  const aiPct    = status?.latest_report ? Math.round(status.latest_report.overall_score) : 0;
  const adminPct = st === "ACTIVE" ? 100 : st === "PENDING_ADMIN_REVIEW" ? 50 : 0;

  const rows = [
    { label: "Profil complété",   pct: 100 },
    { label: "Documents uploadés", pct },
    { label: "Vérification IA",    pct: aiPct },
    { label: "Validation admin",   pct: adminPct, note: st === "PENDING_ADMIN_REVIEW" ? "En attente" : st === "ACTIVE" ? "Approuvé" : "" },
  ];

  return (
    <div className="space-y-8">
      {/* En-tête */}
      <div className="pb-6 border-b border-base-300">
        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">
          Conducteur
        </p>
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
          <div>
            <h1 className="text-2xl font-bold text-base-content">Vérification du compte</h1>
            <p className="text-sm text-base-content/50 mt-1">
              Suivez la progression de l'activation de votre compte conducteur.
            </p>
          </div>
          <span className={`badge font-medium w-fit ${DRIVER_STATUS_COLORS[st] ?? "badge-ghost"}`}>
            {DRIVER_STATUS_LABELS[st] ?? st}
          </span>
        </div>
      </div>

      {/* Statut ACTIVE */}
      {st === "ACTIVE" && (
        <div className="alert alert-success rounded-xl">
          <div>
            <p className="font-semibold">🎉 Votre compte conducteur est actif !</p>
            <p className="text-sm mt-1">Vous pouvez maintenant publier des trajets et accueillir des passagers.</p>
          </div>
          <Link href="/conducteur/trajets/create" className="btn btn-sm btn-success btn-outline rounded-full shrink-0">
            Proposer un trajet
          </Link>
        </div>
      )}

      {/* Motif rejet/suspension */}
      {status?.motif_rejet && (
        <div className="alert alert-error rounded-xl">
          <p className="text-sm"><strong>Rejet :</strong> {status.motif_rejet}</p>
        </div>
      )}
      {status?.motif_suspension && (
        <div className="alert alert-warning rounded-xl">
          <p className="text-sm"><strong>Suspension :</strong> {status.motif_suspension}</p>
        </div>
      )}

      {/* Barre de progression */}
      <div className="bg-base-100 rounded-2xl border border-base-200 p-6 space-y-4">
        <p className="text-xs font-semibold text-base-content/50 uppercase tracking-widest mb-2">
          Progression globale
        </p>
        {rows.map((row) => (
          <ProgressBar key={row.label} label={`${row.label}${row.note ? ` — ${row.note}` : ""}`} pct={row.pct} />
        ))}
      </div>

      {/* Navigation rapide */}
      <div className="grid sm:grid-cols-2 gap-4">
        <Link
          href="/conducteur/documents"
          className="bg-base-100 rounded-2xl border border-base-200 p-6 hover:border-primary/40 transition-colors group"
        >
          <div className="flex items-center gap-3 mb-2">
            <span className="text-2xl">📁</span>
            <p className="font-semibold text-base-content group-hover:text-primary transition-colors">
              Mes documents
            </p>
          </div>
          <p className="text-sm text-base-content/50">
            {pct}% des documents obligatoires uploadés
          </p>
          <div className="mt-3">
            <progress className="progress progress-primary w-full h-1.5" value={pct} max="100" />
          </div>
        </Link>

        <Link
          href="/conducteur/statut"
          className="bg-base-100 rounded-2xl border border-base-200 p-6 hover:border-primary/40 transition-colors group"
        >
          <div className="flex items-center gap-3 mb-2">
            <span className="text-2xl">🤖</span>
            <p className="font-semibold text-base-content group-hover:text-primary transition-colors">
              Statut de vérification
            </p>
          </div>
          <p className="text-sm text-base-content/50">
            {status?.latest_report ? `Rapport IA disponible — score ${aiPct}%` : "En attente de vérification"}
          </p>
          <div className="mt-3">
            <progress className="progress progress-info w-full h-1.5" value={aiPct} max="100" />
          </div>
        </Link>
      </div>

      {/* Ce qui est bloqué */}
      {st !== "ACTIVE" && (
        <div className="bg-base-100 rounded-2xl border border-error/20 overflow-hidden">
          <div className="px-6 py-4 border-b border-error/10">
            <p className="text-xs font-semibold text-error/80 uppercase tracking-widest">
              Fonctionnalités restreintes
            </p>
          </div>
          <div className="p-4 grid sm:grid-cols-2 gap-2">
            {[
              "Publier un trajet",
              "Accepter des réservations",
              "Recevoir des paiements",
              "Apparaître dans les recherches",
            ].map((item) => (
              <div key={item} className="flex items-center gap-2 text-sm text-base-content/50 py-1">
                <span className="text-error">✗</span>
                {item}
              </div>
            ))}
          </div>
          <div className="px-6 pb-4">
            <p className="text-xs text-base-content/40">
              Ces fonctionnalités seront débloquées une fois votre compte vérifié et activé par un administrateur.
            </p>
          </div>
        </div>
      )}

      {/* Documents manquants */}
      {(status?.missing_documents.length ?? 0) > 0 && (
        <div className="bg-base-100 rounded-2xl border border-warning/30 overflow-hidden">
          <div className="px-6 py-4 border-b border-warning/20 flex items-center justify-between">
            <p className="text-xs font-semibold text-warning uppercase tracking-widest">
              {status!.missing_documents.length} document(s) manquant(s)
            </p>
            <Link href="/conducteur/documents" className="btn btn-xs btn-warning btn-outline rounded-full">
              Uploader maintenant
            </Link>
          </div>
          <div className="p-4 grid sm:grid-cols-2 gap-1">
            {status!.missing_documents.map((d) => (
              <p key={d} className="text-sm text-base-content/60 py-0.5">
                <span className="text-warning mr-1">•</span>
                {DOCUMENT_TYPE_LABELS[d] ?? d}
              </p>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
