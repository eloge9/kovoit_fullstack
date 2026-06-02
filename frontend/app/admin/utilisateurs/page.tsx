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

    useEffect(() => {
        const fetchUsers = async () => {
            try {
                let url = `${getApiUrl()}/utilisateurs/admin/utilisateurs/`;
                const params = new URLSearchParams();
                if (filterRole) params.append("role", filterRole);
                if (filterActif) params.append("actif", filterActif);
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
    }, [token, filterRole, filterActif]);

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
                    headers: {
                        "Authorization": `Bearer ${token}`,
                        "Content-Type": "application/json",
                    },
                }
            );
            alert("Conducteur validé et activé !");
            setUsers(users.map(u => u.id === userId ? { ...u, is_active: true } : u));
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
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
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
                                <th className="text-xs uppercase text-base-content/60">Statut</th>
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
                                        <td>
                                            <span className="text-sm">{u.note?.toFixed(1) || "—"}</span>
                                        </td>
                                        <td>
                                            <div className="dropdown dropdown-end">
                                                <button className="btn btn-ghost btn-xs">⋮</button>
                                                <ul className="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-52">
                                                    {u.role === "conducteur" && !u.is_active && (
                                                        <li>
                                                            <a onClick={() => handleValiderConducteur(u.id)}>
                                                                ✓ Valider conducteur
                                                            </a>
                                                        </li>
                                                    )}
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
