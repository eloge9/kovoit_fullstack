"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useCallback, useEffect, useState } from "react";
import {
  DOCUMENT_TYPE_LABELS,
  DRIVER_STATUS_COLORS,
  DRIVER_STATUS_LABELS,
  adminApproveDriver,
  adminBlockDriver,
  adminGetDriver,
  adminGetDriverHistory,
  adminGetDriverReports,
  adminGetDriverSignals,
  adminReactivateDriver,
  adminRejectDriver,
  adminSuspendDriver,
  type DriverProfile,
  type VerificationReport,
} from "@/src/services/verification.service";

function ActionModal({
  action,
  driverName,
  onConfirm,
  onClose,
  needMotif,
}: {
  action: string;
  driverName: string;
  onConfirm: (motif: string) => void;
  onClose: () => void;
  needMotif: boolean;
}) {
  const [motif, setMotif] = useState("");
  const [loading, setLoading] = useState(false);

  const ACTION_LABELS: Record<string, { label: string; cls: string }> = {
    APPROVE:    { label: "Approuver",  cls: "btn-success" },
    REJECT:     { label: "Rejeter",    cls: "btn-error" },
    SUSPEND:    { label: "Suspendre",  cls: "btn-warning" },
    BLOCK:      { label: "Bloquer",    cls: "btn-error" },
    REACTIVATE: { label: "Réactiver", cls: "btn-success" },
  };
  const cfg = ACTION_LABELS[action] ?? { label: action, cls: "btn-primary" };

  const handleConfirm = async () => {
    if (needMotif && !motif.trim()) return;
    setLoading(true);
    await onConfirm(motif);
    setLoading(false);
  };

  return (
    <div className="modal modal-open">
      <div className="modal-box rounded-2xl">
        <h3 className="font-bold text-lg">{cfg.label} — {driverName}</h3>
        <p className="text-sm text-base-content/60 mt-2">
          {needMotif ? "Veuillez indiquer un motif (obligatoire)." : "Confirmez cette action."}
        </p>
        {needMotif && (
          <textarea
            className="textarea textarea-bordered w-full mt-4 rounded-xl"
            placeholder="Motif..."
            rows={3}
            value={motif}
            onChange={(e) => setMotif(e.target.value)}
          />
        )}
        <div className="modal-action">
          <button className="btn btn-ghost rounded-full" onClick={onClose}>Annuler</button>
          <button
            className={`btn rounded-full ${cfg.cls}`}
            onClick={handleConfirm}
            disabled={loading || (needMotif && !motif.trim())}
          >
            {loading ? <span className="loading loading-spinner loading-sm" /> : cfg.label}
          </button>
        </div>
      </div>
      <div className="modal-backdrop" onClick={onClose} />
    </div>
  );
}

function ScoreBar({ label, value }: { label: string; value: number }) {
  const color = value >= 80 ? "progress-success" : value >= 50 ? "progress-warning" : "progress-error";
  return (
    <div className="flex items-center gap-3">
      <span className="text-xs text-base-content/50 w-28 shrink-0">{label}</span>
      <progress className={`progress ${color} flex-1 h-2`} value={value} max="100" />
      <span className="text-xs font-bold w-10 text-right">{value}%</span>
    </div>
  );
}

export default function AdminDriverDetailPage() {
  const params = useParams();
  const router = useRouter();
  const id     = params.id as string;

  const [profile, setProfile]   = useState<DriverProfile | null>(null);
  const [reports, setReports]   = useState<VerificationReport[]>([]);
  const [history, setHistory]   = useState<unknown[]>([]);
  const [signals, setSignals]   = useState<unknown[]>([]);
  const [loading, setLoading]   = useState(true);
  const [activeTab, setActiveTab] = useState<"overview" | "docs" | "report" | "history" | "signals">("overview");
  const [modal, setModal]       = useState<string | null>(null);
  const [message, setMessage]   = useState<{ type: "success" | "error"; text: string } | null>(null);

  const load = useCallback(async () => {
    try {
      const [p, r, h, s] = await Promise.all([
        adminGetDriver(id),
        adminGetDriverReports(id),
        adminGetDriverHistory(id),
        adminGetDriverSignals(id),
      ]);
      setProfile(p);
      setReports(r as VerificationReport[]);
      setHistory(h as unknown[]);
      setSignals(s as unknown[]);
    } catch {
      setMessage({ type: "error", text: "Impossible de charger les données." });
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => { load(); }, [load]);

  const handleAction = async (action: string, motif: string) => {
    setModal(null);
    setMessage(null);
    try {
      if (action === "APPROVE")    await adminApproveDriver(id, motif);
      if (action === "REJECT")     await adminRejectDriver(id, motif);
      if (action === "SUSPEND")    await adminSuspendDriver(id, motif);
      if (action === "BLOCK")      await adminBlockDriver(id, motif);
      if (action === "REACTIVATE") await adminReactivateDriver(id, motif);
      setMessage({ type: "success", text: "Action effectuée avec succès." });
      await load();
    } catch (e: unknown) {
      const err = e as { response?: { data?: { detail?: string } } };
      setMessage({ type: "error", text: err?.response?.data?.detail ?? "Erreur lors de l'action." });
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <span className="loading loading-spinner loading-lg text-primary" />
      </div>
    );
  }

  if (!profile) {
    return (
      <div className="text-center py-20">
        <p className="text-base-content/40">Conducteur introuvable.</p>
        <Link href="/admin/conducteurs" className="btn btn-ghost rounded-full mt-4">Retour</Link>
      </div>
    );
  }

  const st       = profile.status;
  const report   = reports[0];
  // L'admin peut activer/désactiver n'importe quel conducteur, peu importe le statut
  const canApprove    = st !== "ACTIVE" && st !== "BLOCKED";
  const canReject     = st !== "REJECTED" && st !== "BLOCKED";
  const canSuspend    = st === "ACTIVE";
  const canBlock      = st !== "BLOCKED";
  const canReactivate = st === "BLOCKED"; // uniquement pour débloquer un compte bloqué

  const ACTIONS = [
    { key: "APPROVE",    label: "Approuver",  cls: "btn-success",  show: canApprove,    needMotif: false },
    { key: "REJECT",     label: "Rejeter",    cls: "btn-error",    show: canReject,     needMotif: true },
    { key: "SUSPEND",    label: "Suspendre",  cls: "btn-warning",  show: canSuspend,    needMotif: true },
    { key: "BLOCK",      label: "Bloquer",    cls: "btn-error btn-outline", show: canBlock, needMotif: true },
    { key: "REACTIVATE", label: "Réactiver",  cls: "btn-success btn-outline", show: canReactivate, needMotif: false },
  ].filter((a) => a.show);

  const driverName = profile.user.full_name || profile.user.username;

  return (
    <div className="space-y-6">
      {modal && (
        <ActionModal
          action={modal}
          driverName={driverName}
          needMotif={ACTIONS.find((a) => a.key === modal)?.needMotif ?? false}
          onConfirm={(motif) => handleAction(modal, motif)}
          onClose={() => setModal(null)}
        />
      )}

      {/* En-tête */}
      <div className="flex items-start justify-between gap-4">
        <div className="flex items-center gap-3">
          <Link href="/admin/conducteurs" className="btn btn-ghost btn-sm btn-circle">←</Link>
          <div>
            <h1 className="text-xl font-bold text-base-content">{driverName}</h1>
            <p className="text-sm text-base-content/50">{profile.user.email}</p>
          </div>
          <span className={`badge font-medium ${DRIVER_STATUS_COLORS[st] ?? "badge-ghost"}`}>
            {DRIVER_STATUS_LABELS[st] ?? st}
          </span>
        </div>
        <div className="flex flex-wrap gap-2">
          {ACTIONS.map((action) => (
            <button
              key={action.key}
              className={`btn btn-sm rounded-full ${action.cls}`}
              onClick={() => setModal(action.key)}
            >
              {action.label}
            </button>
          ))}
        </div>
      </div>

      {message && (
        <div className={`alert ${message.type === "success" ? "alert-success" : "alert-error"} rounded-xl`}>
          <span>{message.text}</span>
        </div>
      )}

      {/* Tabs */}
      <div className="tabs tabs-bordered border-b border-base-200">
        {(["overview", "docs", "report", "history", "signals"] as const).map((tab) => (
          <button
            key={tab}
            className={`tab tab-sm ${activeTab === tab ? "tab-active font-semibold" : ""}`}
            onClick={() => setActiveTab(tab)}
          >
            {tab === "overview"  && "Vue d'ensemble"}
            {tab === "docs"      && `Documents (${profile.documents.length})`}
            {tab === "report"    && "Rapport IA"}
            {tab === "history"   && `Historique (${(history as unknown[]).length})`}
            {tab === "signals"   && `Signalements (${(signals as unknown[]).length})`}
          </button>
        ))}
      </div>

      {/* Vue d'ensemble */}
      {activeTab === "overview" && (
        <div className="grid lg:grid-cols-2 gap-6">
          <div className="bg-base-100 rounded-2xl border border-base-200 p-6 space-y-4">
            <p className="text-xs font-semibold text-base-content/50 uppercase tracking-widest">Profil</p>
            {[
              ["Nom complet",    driverName],
              ["Email",          profile.user.email],
              ["Note moyenne",   `${profile.note_moyenne}/5`],
              ["Nb trajets",     String(profile.nombre_trajets)],
              ["Nb annulations", String(profile.nombre_annulations)],
              ["Inscrit le",     new Date(profile.created_at).toLocaleDateString("fr-FR")],
              ["Vérifié le",     profile.verified_at ? new Date(profile.verified_at).toLocaleDateString("fr-FR") : "—"],
            ].map(([label, value]) => (
              <div key={label} className="flex justify-between items-center">
                <span className="text-xs text-base-content/40 uppercase tracking-wide">{label}</span>
                <span className="text-sm font-medium">{value}</span>
              </div>
            ))}
          </div>

          {report && (
            <div className="bg-base-100 rounded-2xl border border-base-200 p-6 space-y-4">
              <div className="flex items-center justify-between">
                <p className="text-xs font-semibold text-base-content/50 uppercase tracking-widest">Scores IA</p>
                {report.decision && (
                  <span className={`badge badge-sm ${report.decision === "APPROVED" ? "badge-success" : report.decision === "REJECTED" ? "badge-error" : "badge-warning"}`}>
                    {report.decision}
                  </span>
                )}
              </div>
              <div className="space-y-3">
                <ScoreBar label="Score global"  value={report.overall_score} />
                <ScoreBar label="Anti-fraude"   value={100 - report.fraud_score} />
                <ScoreBar label="Confiance"     value={report.confidence_score} />
              </div>
              {report.summary && (
                <details className="mt-2">
                  <summary className="text-xs text-primary cursor-pointer">Voir le résumé complet</summary>
                  <pre className="text-xs text-base-content/70 mt-2 whitespace-pre-wrap font-mono bg-base-200/60 p-3 rounded-xl">
                    {report.summary}
                  </pre>
                </details>
              )}
            </div>
          )}

          {profile.motif_rejet && (
            <div className="bg-error/5 border border-error/30 rounded-2xl p-4 lg:col-span-2">
              <p className="text-sm font-semibold text-error">Motif de rejet</p>
              <p className="text-sm text-base-content/70 mt-1">{profile.motif_rejet}</p>
            </div>
          )}
          {profile.motif_suspension && (
            <div className="bg-warning/5 border border-warning/30 rounded-2xl p-4 lg:col-span-2">
              <p className="text-sm font-semibold text-warning">Motif de suspension</p>
              <p className="text-sm text-base-content/70 mt-1">{profile.motif_suspension}</p>
            </div>
          )}
        </div>
      )}

      {/* Documents */}
      {activeTab === "docs" && (
        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {profile.documents.length === 0 && (
            <p className="col-span-full text-center text-base-content/40 text-sm py-8">Aucun document uploadé.</p>
          )}
          {profile.documents.map((doc) => {
            const url = doc.file_url ?? "";
            const isImg = /\.(jpg|jpeg|png|webp|gif|bmp)$/i.test(url.split("?")[0]);
            const isPdf = /\.pdf$/i.test(url.split("?")[0]);
            // OCR data from the latest report
            const ocrResults = (report?.ocr_report as Record<string, unknown> | undefined)?.results as Record<string, Record<string, unknown>> | undefined;
            const docOcr = ocrResults?.[doc.document_type];
            const ocrData = docOcr?.data as Record<string, unknown> | undefined;
            const ocrValid = docOcr?.document_valid !== false;

            const borderCls = doc.status === "VERIFIED"
              ? "border-success/40"
              : doc.status === "REJECTED"
              ? "border-error/40"
              : "border-base-200";
            const badgeCls = doc.status === "VERIFIED"
              ? "badge-success"
              : doc.status === "REJECTED"
              ? "badge-error"
              : "badge-warning";

            return (
              <div key={doc.id} className={`rounded-2xl border overflow-hidden bg-base-100 ${borderCls}`}>
                {/* Aperçu fichier */}
                {url && isImg ? (
                  <a href={url} target="_blank" rel="noreferrer" title="Voir en taille réelle">
                    <img
                      src={url}
                      alt={DOCUMENT_TYPE_LABELS[doc.document_type] ?? doc.document_type}
                      className="w-full h-40 object-cover hover:opacity-90 transition-opacity"
                    />
                  </a>
                ) : url && isPdf ? (
                  <a href={url} target="_blank" rel="noreferrer" className="block bg-base-200/60 h-28 flex items-center justify-center hover:bg-base-200 transition-colors">
                    <div className="text-center">
                      <span className="text-3xl">📄</span>
                      <p className="text-xs text-base-content/50 mt-1">PDF</p>
                    </div>
                  </a>
                ) : url ? (
                  <div className="bg-base-200/60 h-16 flex items-center justify-center">
                    <span className="text-xs text-base-content/40">Fichier</span>
                  </div>
                ) : (
                  <div className="bg-base-200/30 h-16 flex items-center justify-center">
                    <span className="text-xs text-base-content/30">Pas de fichier</span>
                  </div>
                )}

                <div className="p-4 space-y-2">
                  {/* En-tête doc */}
                  <div className="flex justify-between items-start gap-2">
                    <p className="text-sm font-semibold text-base-content leading-tight">
                      {DOCUMENT_TYPE_LABELS[doc.document_type] ?? doc.document_type}
                    </p>
                    <span className={`badge badge-xs shrink-0 ${badgeCls}`}>
                      {doc.status}
                    </span>
                  </div>

                  {/* Invalidité OCR */}
                  {docOcr && !ocrValid && (
                    <p className="text-xs text-error bg-error/5 rounded px-2 py-1">
                      ⚠ OCR: {(docOcr?.invalid_reason as string) || "Document non conforme"}
                    </p>
                  )}

                  {/* Données OCR extraites */}
                  {ocrData && Object.keys(ocrData).filter((k) => k !== "document_valid" && ocrData[k] && String(ocrData[k]).trim()).length > 0 && (
                    <details>
                      <summary className="text-xs text-primary cursor-pointer hover:underline">
                        Données OCR extraites
                      </summary>
                      <div className="mt-2 space-y-1">
                        {Object.entries(ocrData)
                          .filter(([k, v]) => k !== "document_valid" && v && String(v).trim())
                          .slice(0, 8)
                          .map(([k, v]) => (
                            <div key={k} className="flex justify-between gap-2 text-xs">
                              <span className="text-base-content/40 shrink-0 capitalize">{k.replace(/_/g, " ")}:</span>
                              <span className="text-right text-base-content/70 break-all">{String(v)}</span>
                            </div>
                          ))}
                      </div>
                    </details>
                  )}

                  {/* Date expiration */}
                  {doc.date_expiration && (
                    <p className={`text-xs ${(doc as unknown as { is_expired?: boolean }).is_expired ? "text-error font-medium" : "text-base-content/40"}`}>
                      Exp. {new Date(doc.date_expiration).toLocaleDateString("fr-FR")}
                      {(doc as unknown as { is_expired?: boolean }).is_expired && " — EXPIRÉ"}
                    </p>
                  )}

                  {/* Motif rejet */}
                  {(doc as unknown as { rejection_reason?: string }).rejection_reason && (
                    <p className="text-xs text-error">{(doc as unknown as { rejection_reason?: string }).rejection_reason}</p>
                  )}

                  {/* Lien fichier */}
                  {url && (
                    <a
                      href={url}
                      target="_blank"
                      rel="noreferrer"
                      className="btn btn-xs btn-ghost rounded-full border border-base-200 w-full"
                    >
                      {isPdf ? "Ouvrir le PDF" : "Voir en taille réelle"}
                    </a>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Rapport IA */}
      {activeTab === "report" && (
        <div className="space-y-4">
          {reports.length === 0 ? (
            <p className="text-base-content/40 text-sm text-center py-8">Aucun rapport disponible.</p>
          ) : (
            reports.map((r) => (
              <div key={r.id} className="bg-base-100 rounded-2xl border border-base-200 p-6">
                <div className="flex items-center justify-between mb-4">
                  <p className="text-sm font-semibold">
                    Rapport du {new Date(r.created_at).toLocaleDateString("fr-FR")}
                  </p>
                  {r.decision && (
                    <span className={`badge ${r.decision === "APPROVED" ? "badge-success" : r.decision === "REJECTED" ? "badge-error" : "badge-warning"}`}>
                      {r.decision}
                    </span>
                  )}
                </div>
                <div className="space-y-2 mb-4">
                  <ScoreBar label="Score global"   value={r.overall_score} />
                  <ScoreBar label="Anti-fraude"    value={100 - r.fraud_score} />
                  <ScoreBar label="Confiance"      value={r.confidence_score} />
                </div>
                {r.summary && (
                  <pre className="text-xs text-base-content/70 whitespace-pre-wrap font-mono bg-base-200/50 p-4 rounded-xl mt-4">
                    {r.summary}
                  </pre>
                )}
              </div>
            ))
          )}
        </div>
      )}

      {/* Historique */}
      {activeTab === "history" && (
        <div className="space-y-2">
          {(history as Array<{ id: string; old_status: string; new_status: string; reason: string; is_automatic: boolean; changed_by?: { full_name?: string }; created_at: string }>).map((h) => (
            <div key={h.id} className="bg-base-100 rounded-xl border border-base-200 p-4 flex items-start gap-3">
              <div className={`w-2 h-2 rounded-full mt-2 shrink-0 ${h.new_status === "ACTIVE" ? "bg-success" : h.new_status === "REJECTED" || h.new_status === "BLOCKED" ? "bg-error" : h.new_status === "SUSPENDED" ? "bg-warning" : "bg-primary"}`} />
              <div className="flex-1">
                <div className="flex items-center gap-2 flex-wrap">
                  <span className="text-sm font-medium text-base-content">
                    {h.old_status || "—"} → {h.new_status}
                  </span>
                  {h.is_automatic && <span className="badge badge-xs badge-ghost">Auto</span>}
                  {h.changed_by && (
                    <span className="text-xs text-base-content/40">par {h.changed_by.full_name}</span>
                  )}
                </div>
                {h.reason && <p className="text-xs text-base-content/50 mt-1">{h.reason}</p>}
                <p className="text-xs text-base-content/30 mt-1">
                  {new Date(h.created_at).toLocaleString("fr-FR")}
                </p>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Signalements */}
      {activeTab === "signals" && (
        <div className="space-y-3">
          {(signals as Array<{ id: string; signal_type: string; description: string; is_processed: boolean; reporter?: { full_name?: string; username?: string }; created_at: string }>).map((s) => (
            <div key={s.id} className="bg-base-100 rounded-xl border border-base-200 p-4">
              <div className="flex items-center justify-between mb-2">
                <span className="text-sm font-semibold text-base-content">{s.signal_type}</span>
                <span className={`badge badge-xs ${s.is_processed ? "badge-success" : "badge-warning"}`}>
                  {s.is_processed ? "Traité" : "En attente"}
                </span>
              </div>
              <p className="text-sm text-base-content/70">{s.description}</p>
              <div className="flex items-center justify-between mt-2">
                <span className="text-xs text-base-content/40">
                  Par {s.reporter?.full_name ?? s.reporter?.username ?? "Anonyme"}
                </span>
                <span className="text-xs text-base-content/30">
                  {new Date(s.created_at).toLocaleDateString("fr-FR")}
                </span>
              </div>
            </div>
          ))}
          {signals.length === 0 && (
            <p className="text-base-content/40 text-sm text-center py-8">Aucun signalement.</p>
          )}
        </div>
      )}
    </div>
  );
}
