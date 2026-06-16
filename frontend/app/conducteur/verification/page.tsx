"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import {
  DOCUMENT_TYPE_LABELS,
  getVerificationStatus,
  getVerificationReport,
  startVerification,
  type VerificationReport,
  type VerificationStatus,
} from "@/src/services/verification.service";

// ── Types ─────────────────────────────────────────────────────────────────────

type TimelineState = "done" | "active" | "pending" | "error";

interface TimelineStep {
  id: string;
  label: string;
  sublabel: string;
  state: TimelineState;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function deriveTimeline(status: VerificationStatus): TimelineStep[] {
  const st       = status.status;
  const pct      = status.completion_percentage;
  const docsDone = pct === 100;

  return [
    {
      id: "profile",
      label: "Profil",
      sublabel: "Compte créé",
      state: "done",
    },
    {
      id: "documents",
      label: "Documents",
      sublabel: docsDone
        ? `${status.uploaded_documents.length} documents fournis`
        : `${status.uploaded_documents.length}/${status.required_documents.length} documents`,
      state: docsDone ? "done" : pct > 0 ? "active" : "pending",
    },
    {
      id: "ai",
      label: "Analyse IA",
      sublabel:
        st === "PENDING_AI_REVIEW"                                    ? "En cours…"          :
        st === "AI_REJECTED"                                          ? "Non conforme"        :
        ["AI_APPROVED","PENDING_ADMIN_REVIEW","ACTIVE"].includes(st)  ? "Validé"              :
        "En attente",
      state:
        ["AI_APPROVED","PENDING_ADMIN_REVIEW","ACTIVE"].includes(st)  ? "done"    :
        st === "PENDING_AI_REVIEW"                                    ? "active"  :
        st === "AI_REJECTED"                                          ? "error"   :
        "pending",
    },
    {
      id: "admin",
      label: "Validation",
      sublabel:
        st === "ACTIVE"               ? "Compte activé"        :
        st === "PENDING_ADMIN_REVIEW" ? "En cours"             :
        st === "AI_APPROVED"          ? "Prêt"                 :
        st === "REJECTED"             ? "Rejeté"               :
        "En attente",
      state:
        st === "ACTIVE"                                             ? "done"   :
        ["PENDING_ADMIN_REVIEW","AI_APPROVED"].includes(st)         ? "active" :
        st === "REJECTED"                                           ? "error"  :
        "pending",
    },
  ];
}

// ── Timeline ──────────────────────────────────────────────────────────────────

function TimelineDot({ state }: { state: TimelineState }) {
  if (state === "done")
    return (
      <div className="w-10 h-10 rounded-full bg-success flex items-center justify-center shadow-md shadow-success/30 z-10">
        <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
        </svg>
      </div>
    );
  if (state === "active")
    return (
      <div className="w-10 h-10 rounded-full bg-primary flex items-center justify-center shadow-md shadow-primary/30 z-10">
        <span className="loading loading-spinner loading-sm text-white" />
      </div>
    );
  if (state === "error")
    return (
      <div className="w-10 h-10 rounded-full bg-error flex items-center justify-center shadow-md shadow-error/30 z-10">
        <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M6 18L18 6M6 6l12 12" />
        </svg>
      </div>
    );
  return (
    <div className="w-10 h-10 rounded-full bg-base-200 border-2 border-base-300 flex items-center justify-center z-10">
      <div className="w-2 h-2 rounded-full bg-base-300" />
    </div>
  );
}

function Timeline({ steps }: { steps: TimelineStep[] }) {
  const donePct = (steps.filter(s => s.state === "done").length / (steps.length - 1)) * (100 - 100 / steps.length);
  return (
    <div className="bg-base-100 rounded-2xl border border-base-200 p-6">
      <div className="flex items-start relative">
        <div className="absolute top-5 left-5 right-5 h-0.5 bg-base-200 z-0" />
        <div className="absolute top-5 left-5 h-0.5 bg-success z-0 transition-all duration-700"
          style={{ width: `${donePct}%` }} />
        {steps.map((step) => (
          <div key={step.id} className="flex-1 flex flex-col items-center gap-2">
            <TimelineDot state={step.state} />
            <div className="text-center">
              <p className={`text-xs font-bold leading-tight ${
                step.state === "done"   ? "text-success" :
                step.state === "active" ? "text-primary" :
                step.state === "error"  ? "text-error"   :
                "text-base-content/30"
              }`}>{step.label}</p>
              <p className="text-xs text-base-content/40 mt-0.5 leading-tight max-w-[72px]">{step.sublabel}</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Carte principale ──────────────────────────────────────────────────────────

function MainCard({
  status, report, onStart, starting,
}: {
  status: VerificationStatus;
  report: VerificationReport | null;
  onStart: () => void;
  starting: boolean;
}) {
  const st      = status.status;
  const missing = status.missing_documents ?? [];
  const total   = status.required_documents?.length ?? 13;
  const done    = status.uploaded_documents?.length ?? 0;
  const pct     = Math.round((done / total) * 100);

  // ── Documents manquants / DRAFT ────────────────────────────────────────
  if (["DRAFT", "DOCUMENTS_MISSING"].includes(st) || status.completion_percentage < 100) {
    return (
      <div className="rounded-2xl border-2 border-warning overflow-hidden">

        {/* Bandeau supérieur */}
        <div className="bg-warning px-6 py-4 flex items-center gap-3">
          <div className="w-9 h-9 rounded-full bg-white/20 flex items-center justify-center shrink-0">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M12 9v2m0 4h.01M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z" />
            </svg>
          </div>
          <div>
            <p className="text-white font-bold text-base leading-tight">Votre compte n'est pas encore actif</p>
            <p className="text-white/80 text-xs mt-0.5">Complétez votre dossier pour commencer à conduire</p>
          </div>
        </div>

        {/* Corps */}
        <div className="bg-base-100 p-6 space-y-5">

          {/* Explication claire */}
          <div className="space-y-1">
            <p className="font-semibold text-base-content text-sm">Comment activer votre compte ?</p>
            <p className="text-sm text-base-content/60 leading-relaxed">
              Pour pouvoir proposer des trajets sur KoVoit, vous devez fournir tous vos documents justificatifs.
              Une fois déposés, notre système les vérifie automatiquement puis un administrateur valide votre dossier.
            </p>
          </div>

          {/* Barre de progression */}
          <div className="space-y-2">
            <div className="flex items-center justify-between text-sm">
              <span className="font-medium text-base-content">{done} document{done > 1 ? "s" : ""} fourni{done > 1 ? "s" : ""} sur {total}</span>
              <span className="font-bold text-warning">{pct}%</span>
            </div>
            <div className="w-full bg-base-200 rounded-full h-3 overflow-hidden">
              <div className="h-full rounded-full bg-warning transition-all duration-700"
                style={{ width: `${pct}%` }} />
            </div>
            <p className="text-xs text-base-content/40">
              {missing.length} document{missing.length > 1 ? "s" : ""} manquant{missing.length > 1 ? "s" : ""}
            </p>
          </div>

          {/* Liste des documents manquants */}
          {missing.length > 0 && (
            <div className="rounded-xl border border-warning/30 bg-warning/5 divide-y divide-warning/10">
              {missing.map((d) => (
                <div key={d} className="flex items-center gap-3 px-4 py-2.5">
                  <div className="w-1.5 h-1.5 rounded-full bg-warning shrink-0" />
                  <span className="text-sm text-base-content/70">{DOCUMENT_TYPE_LABELS[d] ?? d}</span>
                  <span className="ml-auto text-xs text-warning font-medium">À fournir</span>
                </div>
              ))}
            </div>
          )}

          {/* CTA principal */}
          <Link href="/conducteur/documents"
            className="btn btn-warning btn-block rounded-full text-base font-semibold shadow-md shadow-warning/20 gap-2">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            Compléter mes documents
          </Link>

          {/* Étapes suivantes */}
          <div className="grid grid-cols-3 gap-3 pt-1">
            {[
              { num: "1", text: "Déposez vos documents" },
              { num: "2", text: "Analyse automatique" },
              { num: "3", text: "Compte activé" },
            ].map((s) => (
              <div key={s.num} className="text-center">
                <div className="w-7 h-7 rounded-full bg-base-200 flex items-center justify-center mx-auto mb-1.5">
                  <span className="text-xs font-bold text-base-content/40">{s.num}</span>
                </div>
                <p className="text-xs text-base-content/40 leading-tight">{s.text}</p>
              </div>
            ))}
          </div>

        </div>
      </div>
    );
  }

  // ── Docs complets, prêt à lancer ───────────────────────────────────────
  if (status.completion_percentage === 100 && !["PENDING_AI_REVIEW","PENDING_ADMIN_REVIEW","ACTIVE","REJECTED","BLOCKED","SUSPENDED"].includes(st)) {
    return (
      <div className="bg-base-100 rounded-2xl border-2 border-primary/30 p-6 sm:p-8 space-y-5">
        <div className="flex items-start gap-4">
          <div className="w-12 h-12 rounded-2xl bg-primary/10 flex items-center justify-center shrink-0">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <div>
            <p className="text-xs font-semibold text-primary uppercase tracking-widest mb-1">Dossier complet</p>
            <h3 className="text-xl font-bold text-base-content">Tous les documents fournis</h3>
            <p className="text-sm text-base-content/60 mt-1">
              Lancez la vérification automatique pour activer votre compte.
            </p>
          </div>
        </div>
        <button onClick={onStart} disabled={starting} className="btn btn-primary btn-block rounded-full gap-2">
          {starting
            ? <><span className="loading loading-spinner loading-sm" /> Lancement…</>
            : "Lancer la vérification"}
        </button>
      </div>
    );
  }

  // ── IA en cours ────────────────────────────────────────────────────────
  if (st === "PENDING_AI_REVIEW") {
    return (
      <div className="bg-base-100 rounded-2xl border-2 border-info/30 p-6 sm:p-8 space-y-5">
        <div className="flex items-start gap-4">
          <div className="w-12 h-12 rounded-2xl bg-info/10 flex items-center justify-center shrink-0">
            <span className="loading loading-spinner loading-md text-info" />
          </div>
          <div>
            <p className="text-xs font-semibold text-info uppercase tracking-widest mb-1">Vérification en cours</p>
            <h3 className="text-xl font-bold text-base-content">Analyse de vos documents</h3>
            <p className="text-sm text-base-content/60 mt-1">
              Notre système examine chaque document. Aucune action n'est requise de votre part.
            </p>
          </div>
        </div>
        <div className="bg-info/10 rounded-xl p-4 flex items-center justify-between gap-4">
          <div>
            <p className="text-sm font-semibold text-base-content">Durée estimée</p>
            <p className="text-xs text-base-content/50 mt-0.5">Moins de 5 minutes</p>
          </div>
          <span className="loading loading-dots loading-md text-info" />
        </div>
        <p className="text-xs text-base-content/40 text-center">Cette page se rafraîchit automatiquement.</p>
      </div>
    );
  }

  // ── IA rejetée ─────────────────────────────────────────────────────────
  if (st === "AI_REJECTED") {
    return (
      <div className="bg-base-100 rounded-2xl border-2 border-error/30 p-6 sm:p-8 space-y-5">
        <div className="flex items-start gap-4">
          <div className="w-12 h-12 rounded-2xl bg-error/10 flex items-center justify-center shrink-0">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6 text-error" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <div>
            <p className="text-xs font-semibold text-error uppercase tracking-widest mb-1">Documents non conformes</p>
            <h3 className="text-xl font-bold text-base-content">Vérification échouée</h3>
            <p className="text-sm text-base-content/60 mt-1">
              Certains documents n'ont pas passé la vérification. Corrigez-les et relancez.
            </p>
          </div>
        </div>
        {status.motif_rejet && (
          <div className="bg-error/10 rounded-xl p-4">
            <p className="text-xs font-semibold text-error uppercase tracking-widest mb-1">Motif</p>
            <p className="text-sm text-base-content/70">{status.motif_rejet}</p>
          </div>
        )}
        <Link href="/conducteur/documents" className="btn btn-error btn-outline btn-block rounded-full gap-2">
          Corriger mes documents
        </Link>
      </div>
    );
  }

  // ── En attente admin ───────────────────────────────────────────────────
  if (st === "PENDING_ADMIN_REVIEW") {
    return (
      <div className="bg-base-100 rounded-2xl border-2 border-success/30 p-6 sm:p-8 space-y-5">
        <div className="flex items-start gap-4">
          <div className="w-12 h-12 rounded-2xl bg-success/10 flex items-center justify-center shrink-0">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <div>
            <p className="text-xs font-semibold text-success uppercase tracking-widest mb-1">Dernière étape</p>
            <h3 className="text-xl font-bold text-base-content">Validation par l'équipe</h3>
            <p className="text-sm text-base-content/60 mt-1">
              Votre dossier a été validé automatiquement. Un membre de l'équipe KoVoit fait la vérification finale.
            </p>
          </div>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div className="bg-base-200/60 rounded-xl p-4 text-center">
            <p className="text-xs text-base-content/40 mb-1">Délai habituel</p>
            <p className="font-bold text-base-content">24 – 48h</p>
          </div>
          <div className="bg-base-200/60 rounded-xl p-4 text-center">
            <p className="text-xs text-base-content/40 mb-1">Statut</p>
            <p className="font-bold text-warning">En attente</p>
          </div>
        </div>
        <p className="text-xs text-base-content/40 text-center">
          Vous recevrez un email dès que la décision est prise.
        </p>
      </div>
    );
  }

  // ── Compte actif ───────────────────────────────────────────────────────
  if (st === "ACTIVE") {
    return (
      <div className="bg-gradient-to-br from-success/10 to-success/5 rounded-2xl border-2 border-success/40 p-6 sm:p-8 space-y-5">
        <div className="text-center space-y-2">
          <div className="w-16 h-16 rounded-full bg-success/15 flex items-center justify-center mx-auto">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
            </svg>
          </div>
          <p className="text-xs font-semibold text-success uppercase tracking-widest">Compte activé</p>
          <h3 className="text-2xl font-bold text-base-content">Vous êtes prêt à conduire !</h3>
          <p className="text-sm text-base-content/60">
            Votre dossier est vérifié et validé. Vous pouvez maintenant proposer des trajets.
          </p>
        </div>
        <div className="bg-success/10 rounded-xl p-4 space-y-2.5">
          {["Proposer des trajets","Recevoir des réservations","Recevoir des paiements","Apparaître dans les recherches"].map((f) => (
            <div key={f} className="flex items-center gap-2 text-sm">
              <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 text-success shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
              </svg>
              <span className="text-base-content/70">{f}</span>
            </div>
          ))}
        </div>
        <Link href="/conducteur/trajets/create"
          className="btn btn-success btn-block rounded-full text-base font-semibold shadow-lg shadow-success/20">
          Proposer mon premier trajet
        </Link>
      </div>
    );
  }

  // ── Suspendu / Bloqué ──────────────────────────────────────────────────
  if (["SUSPENDED","BLOCKED"].includes(st)) {
    return (
      <div className="bg-base-100 rounded-2xl border-2 border-error/30 p-6 sm:p-8 space-y-5">
        <div className="flex items-start gap-4">
          <div className="w-12 h-12 rounded-2xl bg-error/10 flex items-center justify-center shrink-0">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6 text-error" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636" />
            </svg>
          </div>
          <div>
            <p className="text-xs font-semibold text-error uppercase tracking-widest mb-1">
              {st === "BLOCKED" ? "Compte bloqué" : "Compte suspendu"}
            </p>
            <h3 className="text-xl font-bold text-base-content">Accès restreint</h3>
            {(status.motif_suspension || status.motif_rejet) && (
              <p className="text-sm text-base-content/60 mt-1">
                {status.motif_suspension || status.motif_rejet}
              </p>
            )}
          </div>
        </div>
        <p className="text-xs text-base-content/40">
          Contactez le support KoVoit pour plus d'informations.
        </p>
      </div>
    );
  }

  return null;
}

// ── Rapport IA ────────────────────────────────────────────────────────────────

function AIReport({ report }: { report: VerificationReport }) {
  const scores = [
    { key: "overall",    label: "Score global",  score: report.overall_score },
    { key: "fraud",      label: "Anti-fraude",   score: 100 - report.fraud_score },
    { key: "confidence", label: "Confiance",      score: report.confidence_score },
  ];

  const docResults = [
    { label: "Carte d'identité",   ok: !!(report.identity_report  as Record<string,unknown>)?.identity_valid },
    { label: "Permis de conduire", ok: !!(report.ocr_report        as Record<string,unknown>)?.license_valid  },
    { label: "Véhicule",           ok: !!(report.vehicle_report    as Record<string,unknown>)?.vehicle_valid  },
    { label: "Assurance",          ok: !!(report.insurance_report  as Record<string,unknown>)?.insurance_valid},
    { label: "Contrôle technique", ok: !!(report.technical_report  as Record<string,unknown>)?.technical_valid},
    { label: "Anti-fraude",        ok: (report.fraud_score ?? 100) < 30 },
  ];

  return (
    <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
      <div className="px-6 py-4 border-b border-base-200 flex items-center gap-3">
        <div className="w-8 h-8 rounded-xl bg-base-200 flex items-center justify-center">
          <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 text-base-content/50" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
        </div>
        <div>
          <h3 className="font-bold text-base-content text-sm">Rapport d'analyse IA</h3>
          <p className="text-xs text-base-content/40">
            {report.completed_at
              ? `Terminé le ${new Date(report.completed_at).toLocaleDateString("fr-FR")}`
              : "En cours"}
          </p>
        </div>
        <span className={`ml-auto badge font-semibold ${
          report.decision === "APPROVED" ? "badge-success" :
          report.decision === "REJECTED" ? "badge-error"   : "badge-warning"
        }`}>
          {report.decision === "APPROVED" ? "Approuvé" :
           report.decision === "REJECTED" ? "Rejeté"   : "En attente"}
        </span>
      </div>

      <div className="p-6 space-y-6">
        {/* Scores circulaires */}
        <div className="grid grid-cols-3 gap-4">
          {scores.map((item) => (
            <div key={item.key} className="text-center">
              <div className="relative w-16 h-16 mx-auto mb-2">
                <svg className="w-full h-full -rotate-90" viewBox="0 0 68 68">
                  <circle cx="34" cy="34" r="28" fill="none" strokeWidth="6" stroke="currentColor" className="text-base-200" />
                  <circle cx="34" cy="34" r="28" fill="none" strokeWidth="6" strokeLinecap="round"
                    stroke={item.score >= 80 ? "#22c55e" : item.score >= 50 ? "#f59e0b" : "#ef4444"}
                    strokeDasharray={2 * Math.PI * 28}
                    strokeDashoffset={2 * Math.PI * 28 * (1 - item.score / 100)}
                    className="transition-all duration-1000"
                  />
                </svg>
                <span className="absolute inset-0 flex items-center justify-center text-xs font-bold">
                  {Math.round(item.score)}%
                </span>
              </div>
              <p className="text-xs text-base-content/50 font-medium">{item.label}</p>
            </div>
          ))}
        </div>

        {/* Détail par document */}
        <div className="space-y-2">
          <p className="text-xs font-semibold text-base-content/50 uppercase tracking-widest">Détail par document</p>
          {docResults.map((d) => (
            <div key={d.label} className={`flex items-center gap-3 p-3 rounded-xl border ${
              d.ok ? "bg-success/5 border-success/20" : "bg-error/5 border-error/20"
            }`}>
              <div className={`w-5 h-5 rounded-full flex items-center justify-center shrink-0 ${d.ok ? "bg-success" : "bg-error"}`}>
                <svg xmlns="http://www.w3.org/2000/svg" className="h-3 w-3 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  {d.ok
                    ? <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
                    : <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M6 18L18 6M6 6l12 12" />
                  }
                </svg>
              </div>
              <span className="text-sm text-base-content/70 flex-1">{d.label}</span>
              {!d.ok && <span className="text-xs text-error font-medium">À corriger</span>}
            </div>
          ))}
        </div>

        {/* Résumé texte */}
        {report.summary && (
          <div className="bg-base-200/60 rounded-xl p-4">
            <p className="text-xs font-semibold text-base-content/50 uppercase tracking-widest mb-2">Résumé</p>
            <p className="text-sm text-base-content/70 leading-relaxed whitespace-pre-wrap">{report.summary}</p>
          </div>
        )}
      </div>
    </div>
  );
}

// ── Badge statut ──────────────────────────────────────────────────────────────

function StatusBadge({ status }: { status: string }) {
  const cfg: Record<string, { cls: string; label: string }> = {
    DRAFT:                { cls: "badge-ghost",   label: "Brouillon"         },
    DOCUMENTS_MISSING:    { cls: "badge-warning", label: "Documents requis"  },
    PENDING_AI_REVIEW:    { cls: "badge-info",    label: "Analyse en cours"  },
    AI_APPROVED:          { cls: "badge-success", label: "IA approuvée"      },
    AI_REJECTED:          { cls: "badge-error",   label: "IA rejetée"        },
    PENDING_ADMIN_REVIEW: { cls: "badge-warning", label: "Attente validation"},
    ACTIVE:               { cls: "badge-success", label: "Actif"             },
    SUSPENDED:            { cls: "badge-warning", label: "Suspendu"          },
    BLOCKED:              { cls: "badge-error",   label: "Bloqué"            },
    REJECTED:             { cls: "badge-error",   label: "Rejeté"            },
  };
  const c = cfg[status] ?? { cls: "badge-ghost", label: status };
  return <span className={`badge badge-md font-semibold shrink-0 ${c.cls}`}>{c.label}</span>;
}

// ── Page principale ───────────────────────────────────────────────────────────

export default function VerificationPage() {
  const [status,   setStatus]   = useState<VerificationStatus | null>(null);
  const [report,   setReport]   = useState<VerificationReport | null>(null);
  const [loading,  setLoading]  = useState(true);
  const [starting, setStarting] = useState(false);
  const [toast,    setToast]    = useState<{ type: "success" | "error"; text: string } | null>(null);

  const load = useCallback(async () => {
    try {
      const s = await getVerificationStatus();
      setStatus(s);
      if (s.latest_report) {
        try { setReport(await getVerificationReport()); } catch { /* rapport pas encore disponible */ }
      }
    } catch {
      setToast({ type: "error", text: "Impossible de charger le statut." });
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  useEffect(() => {
    if (status?.status !== "PENDING_AI_REVIEW") return;
    const id = setInterval(load, 8000);
    return () => clearInterval(id);
  }, [status?.status, load]);

  useEffect(() => {
    if (!toast) return;
    const t = setTimeout(() => setToast(null), 4000);
    return () => clearTimeout(t);
  }, [toast]);

  const handleStart = async () => {
    setStarting(true);
    try {
      const res = await startVerification();
      setToast({ type: "success", text: res.message });
      await load();
    } catch (e: unknown) {
      const err = e as { response?: { data?: { message?: string } } };
      setToast({ type: "error", text: err?.response?.data?.message ?? "Erreur lors du lancement." });
    } finally {
      setStarting(false);
    }
  };

  if (loading) {
    return (
      <div className="space-y-6 animate-pulse">
        <div className="h-24 bg-base-200 rounded-2xl" />
        <div className="h-28 bg-base-200 rounded-2xl" />
        <div className="h-64 bg-base-200 rounded-2xl" />
      </div>
    );
  }

  if (!status) return null;

  const st        = status.status;
  const timeline  = deriveTimeline(status);
  const hasReport = report && report.overall_score > 0;

  return (
    <div className="space-y-5 pb-8">

      {/* En-tête */}
      <div className="bg-gradient-to-br from-base-100 to-base-200/40 rounded-2xl border border-base-200 p-6">
        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">
          Conducteur · Activation
        </p>
        <div className="flex items-start justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-base-content">Activation du compte</h1>
            <p className="text-sm text-base-content/50 mt-1">
              Suivez l'avancement de votre dossier en temps réel.
            </p>
          </div>
          <StatusBadge status={st} />
        </div>
      </div>

      {/* Toast */}
      {toast && (
        <div className={`alert ${toast.type === "success" ? "alert-success" : "alert-error"} rounded-xl shadow-md`}>
          <span className="text-sm">{toast.text}</span>
        </div>
      )}

      {/* Timeline */}
      <Timeline steps={timeline} />

      {/* Carte principale */}
      <MainCard status={status} report={report} onStart={handleStart} starting={starting} />

      {/* Rapport IA */}
      {hasReport && <AIReport report={report!} />}

      {/* Lien documents (sauf compte actif) */}
      {st !== "ACTIVE" && (
        <Link href="/conducteur/documents"
          className="btn btn-ghost btn-block rounded-full border border-base-200 gap-2">
          <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z" />
          </svg>
          Gérer mes documents
        </Link>
      )}

    </div>
  );
}
