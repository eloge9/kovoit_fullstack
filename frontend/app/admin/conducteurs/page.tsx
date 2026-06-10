"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import {
  DRIVER_STATUS_COLORS,
  DRIVER_STATUS_LABELS,
  adminListDrivers,
  adminGetStats,
  adminApproveDriver,
  adminSuspendDriver,
  adminReactivateDriver,
  type AdminDriver,
} from "@/src/services/verification.service";

const STATUS_FILTERS = [
  { value: "",                     label: "Tous" },
  { value: "ACTIVE",               label: "Actifs" },
  { value: "AI_APPROVED",          label: "IA approuvés" },
  { value: "PENDING_ADMIN_REVIEW", label: "En attente" },
  { value: "AI_REJECTED",          label: "IA rejetés" },
  { value: "SUSPENDED",            label: "Suspendus" },
  { value: "BLOCKED",              label: "Bloqués" },
  { value: "REJECTED",             label: "Rejetés" },
  { value: "DOCUMENTS_MISSING",    label: "Incomplets" },
];

function ScoreDot({ score }: { score: number }) {
  const color = score >= 80 ? "bg-success" : score >= 50 ? "bg-warning" : "bg-error";
  return (
    <span className="flex items-center gap-1.5">
      <span className={`w-2 h-2 rounded-full ${color}`} />
      <span className="text-sm">{score}%</span>
    </span>
  );
}

// Modal léger pour les actions rapides avec motif
function QuickActionModal({
  driver,
  action,
  onConfirm,
  onClose,
}: {
  driver: AdminDriver;
  action: "APPROVE" | "SUSPEND" | "REACTIVATE";
  onConfirm: () => void;
  onClose: () => void;
}) {
  const [motif, setMotif] = useState("");
  const [loading, setLoading] = useState(false);

  const cfg = {
    APPROVE:    { label: "Activer",    desc: "Le conducteur pourra publier des trajets.",  cls: "btn-success", needMotif: false },
    SUSPEND:    { label: "Suspendre",  desc: "Indiquez le motif de suspension.",           cls: "btn-warning", needMotif: true },
    REACTIVATE: { label: "Réactiver",  desc: "Le compte sera restauré.",                  cls: "btn-success", needMotif: false },
  }[action];

  const name = driver.user.full_name || driver.user.username;

  const handle = async () => {
    if (cfg.needMotif && !motif.trim()) return;
    setLoading(true);
    try {
      if (action === "APPROVE")    await adminApproveDriver(driver.id);
      if (action === "SUSPEND")    await adminSuspendDriver(driver.id, motif);
      if (action === "REACTIVATE") await adminReactivateDriver(driver.id);
      onConfirm();
    } catch {
      // l'erreur sera gérée par le parent si besoin
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal modal-open">
      <div className="modal-box rounded-2xl max-w-sm">
        <h3 className="font-bold text-base">{cfg.label} — {name}</h3>
        <p className="text-sm text-base-content/60 mt-1">{cfg.desc}</p>
        {cfg.needMotif && (
          <textarea
            className="textarea textarea-bordered w-full mt-3 rounded-xl text-sm"
            placeholder="Motif (obligatoire)..."
            rows={2}
            value={motif}
            onChange={(e) => setMotif(e.target.value)}
          />
        )}
        <div className="modal-action gap-2">
          <button className="btn btn-ghost btn-sm rounded-full" onClick={onClose}>Annuler</button>
          <button
            className={`btn btn-sm rounded-full ${cfg.cls}`}
            onClick={handle}
            disabled={loading || (cfg.needMotif && !motif.trim())}
          >
            {loading ? <span className="loading loading-spinner loading-xs" /> : cfg.label}
          </button>
        </div>
      </div>
      <div className="modal-backdrop" onClick={onClose} />
    </div>
  );
}

export default function AdminConducteursPage() {
  const [drivers, setDrivers]         = useState<AdminDriver[]>([]);
  const [stats, setStats]             = useState<Record<string, number>>({});
  const [loading, setLoading]         = useState(true);
  const [statusFilter, setStatusFilter] = useState("");
  const [search, setSearch]           = useState("");
  const [page, setPage]               = useState(1);
  const [totalPages, setTotalPages]   = useState(1);
  const [total, setTotal]             = useState(0);
  const [quickAction, setQuickAction] = useState<{
    driver: AdminDriver;
    action: "APPROVE" | "SUSPEND" | "REACTIVATE";
  } | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [res, statsRes] = await Promise.all([
        adminListDrivers({ status: statusFilter || undefined, search: search || undefined, page }),
        adminGetStats(),
      ]);
      setDrivers(res.results);
      setTotalPages(res.pages);
      setTotal(res.count);
      setStats(statsRes);
    } catch {
      // silently fail
    } finally {
      setLoading(false);
    }
  }, [statusFilter, search, page]);

  useEffect(() => { load(); }, [load]);
  useEffect(() => { setPage(1); }, [statusFilter, search]);

  return (
    <div className="space-y-6">

      {quickAction && (
        <QuickActionModal
          driver={quickAction.driver}
          action={quickAction.action}
          onConfirm={() => { setQuickAction(null); load(); }}
          onClose={() => setQuickAction(null)}
        />
      )}

      {/* En-tête */}
      <div className="pb-6 border-b border-base-300">
        <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">Administration</p>
        <h1 className="text-2xl font-bold text-base-content">Conducteurs</h1>
        <p className="text-sm text-base-content/50 mt-1">{total} conducteur(s) au total</p>
      </div>

      {/* Stats cliquables */}
      <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
        {[
          { key: "ACTIVE",               label: "Actifs",       color: "text-success" },
          { key: "AI_APPROVED",          label: "IA approuvés", color: "text-info" },
          { key: "PENDING_ADMIN_REVIEW", label: "En attente",   color: "text-warning" },
          { key: "SUSPENDED",            label: "Suspendus",    color: "text-warning" },
          { key: "BLOCKED",              label: "Bloqués",      color: "text-error" },
          { key: "DOCUMENTS_MISSING",    label: "Incomplets",   color: "text-base-content/40" },
        ].map((item) => (
          <button
            key={item.key}
            onClick={() => setStatusFilter(item.key === statusFilter ? "" : item.key)}
            className={`bg-base-100 rounded-xl border p-4 text-left hover:border-primary/40 transition-colors ${statusFilter === item.key ? "border-primary" : "border-base-200"}`}
          >
            <p className={`text-2xl font-bold ${item.color}`}>{stats[item.key] ?? 0}</p>
            <p className="text-xs text-base-content/50 mt-0.5">{item.label}</p>
          </button>
        ))}
      </div>

      {/* Filtres */}
      <div className="flex flex-col sm:flex-row gap-3">
        <input
          type="text"
          placeholder="Rechercher par nom, email..."
          className="input input-bordered input-sm rounded-xl flex-1"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <div className="flex flex-wrap gap-2">
          {STATUS_FILTERS.map((f) => (
            <button
              key={f.value}
              onClick={() => setStatusFilter(f.value)}
              className={`btn btn-xs rounded-full ${statusFilter === f.value ? "btn-primary" : "btn-ghost border border-base-200"}`}
            >
              {f.label}
            </button>
          ))}
        </div>
      </div>

      {/* Table */}
      <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="table table-sm w-full">
            <thead>
              <tr className="border-b border-base-200 text-xs text-base-content/40 uppercase tracking-widest">
                <th>Conducteur</th>
                <th>Statut</th>
                <th>Complétion</th>
                <th>Score IA</th>
                <th>Anti-fraude</th>
                <th>Signalements</th>
                <th>Inscrit le</th>
                <th className="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                [...Array(5)].map((_, i) => (
                  <tr key={i} className="animate-pulse border-b border-base-200">
                    {[...Array(8)].map((__, j) => (
                      <td key={j}><div className="h-4 bg-base-300 rounded w-20" /></td>
                    ))}
                  </tr>
                ))
              ) : drivers.length === 0 ? (
                <tr>
                  <td colSpan={8} className="text-center py-12 text-base-content/40 text-sm">
                    Aucun conducteur trouvé
                  </td>
                </tr>
              ) : (
                drivers.map((driver) => {
                  const st = driver.status;
                  // L'admin peut activer n'importe quel conducteur non-actif et non-bloqué
                  const canActivate   = st !== "ACTIVE" && st !== "BLOCKED";
                  const canSuspend    = st === "ACTIVE";
                  const canReactivate = false; // canActivate couvre déjà SUSPENDED/REJECTED

                  return (
                    <tr key={driver.id} className="border-b border-base-200 hover:bg-base-200/30 transition-colors">
                      <td>
                        <div className="flex items-center gap-2">
                          {driver.user.photo_profil ? (
                            <img src={driver.user.photo_profil} alt="" className="w-8 h-8 rounded-full object-cover" />
                          ) : (
                            <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center text-xs font-bold text-primary">
                              {(driver.user.first_name?.[0] ?? driver.user.username[0]).toUpperCase()}
                            </div>
                          )}
                          <div>
                            <p className="font-medium text-sm text-base-content">
                              {driver.user.full_name || driver.user.username}
                            </p>
                            <p className="text-xs text-base-content/40">{driver.user.email}</p>
                          </div>
                        </div>
                      </td>
                      <td>
                        <span className={`badge badge-sm font-medium ${DRIVER_STATUS_COLORS[st] ?? "badge-ghost"}`}>
                          {DRIVER_STATUS_LABELS[st] ?? st}
                        </span>
                      </td>
                      <td>
                        <div className="flex items-center gap-2">
                          <progress className="progress progress-primary w-14 h-1.5" value={driver.completion_percentage} max="100" />
                          <span className="text-xs text-base-content/50">{driver.completion_percentage}%</span>
                        </div>
                      </td>
                      <td>
                        {driver.latest_report
                          ? <ScoreDot score={driver.latest_report.overall_score} />
                          : <span className="text-xs text-base-content/30">—</span>}
                      </td>
                      <td>
                        {driver.latest_report
                          ? <ScoreDot score={100 - driver.latest_report.fraud_score} />
                          : <span className="text-xs text-base-content/30">—</span>}
                      </td>
                      <td>
                        {driver.signals_count > 0 ? (
                          <span className={`badge badge-sm ${driver.signals_count >= 3 ? "badge-error" : "badge-warning"}`}>
                            {driver.signals_count}
                          </span>
                        ) : (
                          <span className="text-xs text-base-content/30">0</span>
                        )}
                      </td>
                      <td className="text-xs text-base-content/40">
                        {new Date(driver.created_at).toLocaleDateString("fr-FR")}
                      </td>
                      <td>
                        <div className="flex items-center justify-end gap-1.5">
                          {/* Bouton Activer */}
                          {canActivate && (
                            <button
                              className="btn btn-xs btn-success rounded-full"
                              onClick={() => setQuickAction({ driver, action: "APPROVE" })}
                            >
                              Activer
                            </button>
                          )}
                          {/* Bouton Suspendre */}
                          {canSuspend && (
                            <button
                              className="btn btn-xs btn-warning rounded-full"
                              onClick={() => setQuickAction({ driver, action: "SUSPEND" })}
                            >
                              Suspendre
                            </button>
                          )}
                          {/* Bouton Réactiver */}
                          {!canActivate && canReactivate && (
                            <button
                              className="btn btn-xs btn-ghost rounded-full border border-success/40 text-success"
                              onClick={() => setQuickAction({ driver, action: "REACTIVATE" })}
                            >
                              Réactiver
                            </button>
                          )}
                          {/* Voir la fiche */}
                          <Link
                            href={`/admin/conducteurs/${driver.id}`}
                            className="btn btn-xs btn-ghost rounded-full border border-base-200"
                          >
                            Voir
                          </Link>
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        {totalPages > 1 && (
          <div className="flex items-center justify-between px-6 py-3 border-t border-base-200">
            <p className="text-xs text-base-content/40">Page {page} / {totalPages}</p>
            <div className="join">
              <button className="join-item btn btn-xs" onClick={() => setPage((p) => Math.max(1, p - 1))} disabled={page === 1}>«</button>
              {[...Array(Math.min(5, totalPages))].map((_, i) => {
                const p = i + 1;
                return (
                  <button key={p} className={`join-item btn btn-xs ${page === p ? "btn-primary" : ""}`} onClick={() => setPage(p)}>
                    {p}
                  </button>
                );
              })}
              <button className="join-item btn btn-xs" onClick={() => setPage((p) => Math.min(totalPages, p + 1))} disabled={page === totalPages}>»</button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
