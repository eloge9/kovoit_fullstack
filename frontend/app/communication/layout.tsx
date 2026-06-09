"use client";

import Link from "next/link";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { useAuth } from "@/src/hooks/useAuth";
import { getMediaUrl } from "@/src/utils/imageUtils";

export default function CommunicationLayout({ children }: { children: React.ReactNode }) {
    const { user, logout } = useAuth();
    const router = useRouter();

    const role = user?.role ?? (typeof window !== "undefined" ? localStorage.getItem("user_role") : null);
    const backHref = role === "conducteur" ? "/conducteur/dashboard" : "/passager/dashboard";

    const handleLogout = async () => {
        await logout();
        router.push("/auth/connexion");
    };

    return (
        <div data-theme="winter" className="h-screen flex flex-col overflow-hidden bg-base-200">

            {/* ── Navbar ── */}
            <header className="h-16 shrink-0 bg-base-100 border-b border-base-200 sticky top-0 z-50">
                <div className="max-w-7xl mx-auto px-4 lg:px-8 h-full flex items-center justify-between">

                    {/* Gauche : retour + titre */}
                    <div className="flex items-center gap-3">
                        <Link
                            href={backHref}
                            className="btn btn-ghost btn-sm btn-square rounded-xl"
                            title="Retour au tableau de bord"
                        >
                            <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
                            </svg>
                        </Link>

                        <Link href="/" className="flex items-center gap-2">
                            <Image src="/logo/logo1.png" alt="KoVoit" width={28} height={28} />
                            <div className="hidden sm:block">
                                <p className="text-sm font-bold text-base-content leading-none">KoVoit</p>
                                <p className="text-xs text-base-content/40 leading-none">Messages</p>
                            </div>
                        </Link>
                    </div>

                    {/* Droite : avatar */}
                    {user && (
                        <div className="dropdown dropdown-end">
                            <button tabIndex={0} className="btn btn-ghost btn-circle btn-sm">
                                <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center overflow-hidden">
                                    {user.photo_profil ? (
                                        <img
                                            src={getMediaUrl(user.photo_profil)}
                                            alt=""
                                            className="w-8 h-8 rounded-full object-cover"
                                        />
                                    ) : (
                                        <span className="text-sm font-bold text-primary">
                                            {(user.first_name?.[0] || user.username?.[0] || "U").toUpperCase()}
                                        </span>
                                    )}
                                </div>
                            </button>
                            <ul tabIndex={0} className="dropdown-content menu bg-base-100 rounded-2xl border border-base-200 shadow-lg p-2 w-52 z-50 mt-1">
                                <li className="px-3 py-2">
                                    <p className="text-sm font-semibold text-base-content truncate">
                                        {user.first_name} {user.last_name || ""}
                                    </p>
                                    <p className="text-xs text-base-content/40 truncate capitalize">{role}</p>
                                </li>
                                <div className="divider my-0" />
                                <li>
                                    <Link href={backHref} className="text-sm">
                                        Tableau de bord
                                    </Link>
                                </li>
                                <li>
                                    <button onClick={handleLogout} className="text-sm text-error">
                                        Déconnexion
                                    </button>
                                </li>
                            </ul>
                        </div>
                    )}
                </div>
            </header>

            {/* ── Contenu ── */}
            <div className="flex-1 overflow-hidden">
                {children}
            </div>
        </div>
    );
}
