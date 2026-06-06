"use client";

import { useEffect, useState } from "react";
import { useAuth } from "@/src/hooks/useAuth";
import { getApiUrl } from "@/src/utils/apiUtils";

interface Utilisateur {
    id: string;
    username: string;
    email: string;
    role: string;
    numero_telephone: string;
    note: number;
    is_active: boolean;
    date_joined: string;
    statut_validation: string;
    photo_cni: string | null;
    photo_permis: string | null;
    nombre_trajets?: number;
    nombre_reservations?: number;
    nombre_evaluations_recues?: number;
    nombre_plaintes?: number;
}

export default function AdminUtilisateurs() {
    const { token } = useAuth();
    const [users, setUsers] = useState<Utilisateur[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState("");
    const [filterRole, setFilterRole] = useState<string>("");
    const [filterActif, setFilterActif] = useState<string>("");
    const [filterValidation, setFilterValidation] = useState<string>("");

    useEffect(() => {
        const fetchUsers = async () => {
            try {
                let url = `${getApiUrl()}/utilisateurs/admin/utilisateurs/`;
                const params = new URLSearchParams();
                if (filterRole)       params.append("role",              filterRole);
                if (filterActif)      params.append("actif",             filterActif);
                if (filterValidation) params.append("statut_validation", filterValidation);
                if (params.toString()) url += `?${params.toString()}`;

                const response = await fetch(url, {
                    headers: {
                        "Authorization": `Bearer ${token}`,
                        "Content-Type": "application/json",
                    },
                });

                if (!response.ok) throw new Error("Erreur lors du chargement");
                const data = await response.json();
                setUsers(Array.isArray(data) ? data : []);
            } catch (err: unknown) {
                setError(err instanceof Error ? err.message : String(err));
            } finally {
                setLoading(false);
            }
        };

        if (token) fetchUsers();
    }, [token, filterRole, filterActif, filterValidation]);

    const handleSuspendre = async (userId: string) => {
        if (!confirm("Êtes-vous sûr ?")) return;
        try {
            await fetch(
                `${getApiUrl()}/utilisateurs/admin/utilisateurs/${userId}/suspendre/`,
                {
                    method: "POST",
                    headers: {
                        "Authorization": `Bearer ${token}`,
                        "Content-Type": "application/json",
                    },
                }
            );
            setUsers(users.map(u => u.id === userId ? { ...u, is_active: false } : u));
        } catch (err: unknown) {
            alert("Erreur: " + (err instanceof Error ? err.message : String(err)));
        }
    };

    const handleActiver = async (userId: string) => {
        try {
            await fetch(
                `${getApiUrl()}/utilisateurs/admin/utilisateurs/${userId}/activer/`,
                {
                    method: "POST",
                    headers: {
                        "Authorization": `Bearer ${token}`,
                        "Content-Type": "application/json",
                    },
                }
            );
            setUsers(users.map(u => u.id === userId ? { ...u, is_active: true } : u));
        } catch (err: unknown) {
            alert("Erreur: " + (err instanceof Error ? err.message : String(err)));
        }
    };

    const handleValiderConducteur = async (userId: string) => {
        try {
            await fetch(
                `${getApiUrl()}/utilisateurs/admin/utilisateurs/${userId}/valider-conducteur/`,
                {
                    method: "POST",
                    headers: { "Authorization": `Bearer ${token}`, "Content-Type": "application/json" },
                }
            );
            alert("Conducteur validé et activé !");
            setUsers(users.map(u => u.id === userId ? { ...u, is_active: true } : u));
        } catch (err: unknown) {
            alert("Erreur: " + (err instanceof Error ? err.message : String(err)));
        }
    };

    const handleValiderDocuments = async (userId: string) => {
        if (!confirm("Valider les documents et activer ce compte ?")) return;
        try {
            await fetch(
                `${getApiUrl()}/utilisateurs/admin/utilisateurs/${userId}/valider-documents/`,
                {
                    method: "POST",
                    headers: { "Authorization": `Bearer ${token}`, "Content-Type": "application/json" },
                }
            );
            setUsers(users.map(u => u.id === userId ? { ...u, statut_validation: "valide", is_active: true } : u));
        } catch (err: unknown) {
            alert("Erreur: " + (err instanceof Error ? err.message : String(err)));
        }
    };

    const handleRejeterDocuments = async (userId: string) => {
        if (!confirm("Rejeter les documents de cet utilisateur ?")) return;
        try {
            await fetch(
                `${getApiUrl()}/utilisateurs/admin/utilisateurs/${userId}/rejeter-documents/`,
                {
                    method: "POST",
                    headers: { "Authorization": `Bearer ${token}`, "Content-Type": "application/json" },
                }
            );
            setUsers(users.map(u => u.id === userId ? { ...u, statut_validation: "rejete" } : u));
        } catch (err: unknown) {
            alert("Erreur: " + (err instanceof Error ? err.message : String(err)));
        }
    };

    if (loading) {
        return <div className="text-center py-8">Chargement...</div>;
    }

    return (
        <div className="space-y-6">

            {/* EN-TÊTE */}
            <div className="pb-6 border-b border-base-300">
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">
                    Gestion
                </p>
                <h1 className="text-3xl font-bold text-base-content tracking-tight">Utilisateurs</h1>
            </div>

            {/* FILTRES */}
            {error ? (
                <div className="alert alert-error">
                    <span>{error}</span>
                </div>
            ) : null}
            <div className="bg-base-100 rounded-2xl border border-base-200 p-6 space-y-4">
                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium">
                    Filtres
                </p>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <select
                        value={filterRole}
                        onChange={(e) => setFilterRole(e.target.value)}
                        className="select select-bordered select-sm rounded-xl"
                    >
                        <option value="">Tous les rôles</option>
                        <option value="conducteur">Conducteurs</option>
                        <option value="passager">Passagers</option>
                        <option value="admin">Admins</option>
                    </select>

                    <select
                        value={filterActif}
                        onChange={(e) => setFilterActif(e.target.value)}
                        className="select select-bordered select-sm rounded-xl"
                    >
                        <option value="">Tous les statuts</option>
                        <option value="true">Actifs</option>
                        <option value="false">Suspendus</option>
                    </select>

                    <select
                        value={filterValidation}
                        onChange={(e) => setFilterValidation(e.target.value)}
                        className="select select-bordered select-sm rounded-xl"
                    >
                        <option value="">Tous les docs</option>
                        <option value="en_attente">⏳ En attente</option>
                        <option value="valide">✅ Validés</option>
                        <option value="rejete">❌ Rejetés</option>
                        <option value="non_soumis">— Non soumis</option>
                    </select>
                </div>
            </div>

            {/* TABLEAU */}
            <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="table table-zebra w-full">
                        <thead className="bg-base-200">
                            <tr>
                                <th className="text-xs uppercase text-base-content/60">Utilisateur</th>
                                <th className="text-xs uppercase text-base-content/60">Rôle</th>
                                <th className="text-xs uppercase text-base-content/60">Compte</th>
                                <th className="text-xs uppercase text-base-content/60">Documents</th>
                                <th className="text-xs uppercase text-base-content/60">Note</th>
                                <th className="text-xs uppercase text-base-content/60">Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {users.length === 0 ? (
                                <tr>
                                    <td colSpan={5} className="text-center py-8 text-base-content/40">
                                        Aucun utilisateur trouvé
                                    </td>
                                </tr>
                            ) : (
                                users.map((u) => (
                                    <tr key={u.id} className="hover:bg-base-200/50">
                                        <td>
                                            <div>
                                                <p className="font-medium text-sm">{u.username}</p>
                                                <p className="text-xs text-base-content/60">{u.email}</p>
                                            </div>
                                        </td>
                                        <td>
                                            <div className="badge badge-sm">
                                                {u.role === "conducteur" ? "🚗" : u.role === "passager" ? "🚶" : "🔐"} {u.role}
                                            </div>
                                        </td>
                                        <td>
                                            <div className={`badge badge-sm ${u.is_active ? "badge-success" : "badge-error"}`}>
                                                {u.is_active ? "✓ Actif" : "✗ Suspendu"}
                                            </div>
                                        </td>
                                        {/* Colonne Documents */}
                                        <td>
                                            {(() => {
                                                const cfg: Record<string, { label: string; cls: string }> = {
                                                    non_soumis: { label: "—",          cls: "badge-ghost" },
                                                    en_attente: { label: "⏳ Attente",  cls: "badge-warning" },
                                                    valide:     { label: "✅ Validé",   cls: "badge-success" },
                                                    rejete:     { label: "❌ Rejeté",   cls: "badge-error" },
                                                };
                                                const s = u.statut_validation || "non_soumis";
                                                const c = cfg[s] || cfg["non_soumis"];
                                                return (
                                                    <span className={`badge badge-sm ${c.cls}`}>{c.label}</span>
                                                );
                                            })()}
                                        </td>
                                        <td>
                                            <span className="text-sm">{u.note?.toFixed(1) || "—"}</span>
                                        </td>
                                        <td>
                                            <div className="dropdown dropdown-end">
                                                <button className="btn btn-ghost btn-xs">⋮</button>
                                                <ul className="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-56">
                                                    {/* Valider / Rejeter documents */}
                                                    {u.statut_validation === "en_attente" && (
                                                        <>
                                                            <li>
                                                                <a onClick={() => handleValiderDocuments(u.id)} className="text-success">
                                                                    ✅ Valider documents
                                                                </a>
                                                            </li>
                                                            <li>
                                                                <a onClick={() => handleRejeterDocuments(u.id)} className="text-error">
                                                                    ❌ Rejeter documents
                                                                </a>
                                                            </li>
                                                        </>
                                                    )}
                                                    {u.statut_validation === "rejete" && (
                                                        <li>
                                                            <a onClick={() => handleValiderDocuments(u.id)} className="text-success">
                                                                ✅ Valider quand même
                                                            </a>
                                                        </li>
                                                    )}
                                                    {/* Ancien bouton conducteur */}
                                                    {u.role === "conducteur" && !u.is_active && u.statut_validation !== "en_attente" && (
                                                        <li>
                                                            <a onClick={() => handleValiderConducteur(u.id)}>
                                                                ✓ Activer conducteur
                                                            </a>
                                                        </li>
                                                    )}
                                                    <li className="divider my-0" />
                                                    {u.is_active ? (
                                                        <li>
                                                            <a onClick={() => handleSuspendre(u.id)} className="text-warning">
                                                                ⚠️ Suspendre
                                                            </a>
                                                        </li>
                                                    ) : (
                                                        <li>
                                                            <a onClick={() => handleActiver(u.id)} className="text-success">
                                                                ✓ Activer
                                                            </a>
                                                        </li>
                                                    )}
                                                </ul>
                                            </div>
                                        </td>
                                    </tr>
                                ))
                            )}
                        </tbody>
                    </table>
                </div>
            </div>

        </div>
    );
}
