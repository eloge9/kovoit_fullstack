"use client";

import { useState } from "react";
import Link from "next/link";
import logoSrc from "@/public/logo/logo1.png";
import { usePathname, useRouter } from "next/navigation";
import { useAuth } from "@/src/hooks/useAuth";
import { changerMode, deconnexion } from "@/src/services/auth.service";
import { getMediaUrl } from "@/src/utils/imageUtils";

const navItems = [
    { href: "/passager/dashboard", label: "Tableau de bord" },
    { href: "/passager/trajets", label: "Rechercher" },
    { href: "/passager/reservations", label: "Réservations" },
    { href: "/passager/historique", label: "Historique" },
];

const moreItems = [
    { href: "/communication/messages", label: "Messages" },
    { href: "/passager/economie", label: "Économies" },
    { href: "/passager/evaluations", label: "Évaluations" },
    { href: "/passager/profil", label: "Profil & Paramètres" },
];

export default function PassagerLayout({ children }: { children: React.ReactNode }) {
    const pathname = usePathname();
    const router = useRouter();
    const { user, logout, updateUser } = useAuth();
    const [menuOpen, setMenuOpen] = useState(false);
    const [switching, setSwitching] = useState(false);

    // Logique de bascule vers le mode conducteur
    const handleSwitchToConducteur = async () => {
        // Aucun profil conducteur jamais créé → wizard
        const hasDriverProfile = user?.is_driver || user?.driver_profile_id;
        if (!hasDriverProfile) {
            router.push("/passager/devenir-conducteur");
            return;
        }
        // Profil existant (validé ou en cours) → bascule directe via API
        setSwitching(true);
        try {
            const res = await changerMode();
            updateUser(res.utilisateur, res.tokens?.access, res.tokens?.refresh);
            router.push("/conducteur/dashboard");
        } catch (e: any) {
            // Cas extrême : profil introuvable côté serveur → wizard
            if (e?.response?.data?.code === "NO_DRIVER_PROFILE") {
                router.push("/passager/devenir-conducteur");
            }
        } finally {
            setSwitching(false);
        }
    };

    const handleLogout = async () => {
        try {
            const refresh = localStorage.getItem("refresh");
            if (refresh) await deconnexion(refresh);
        } catch { }
        logout();
        router.push("/auth/connexion");
    };

    const isActive = (href: string) => pathname === href;

    return (
        <div data-theme="winter" className="min-h-screen bg-base-200">

            {/* NAVBAR */}
            <header className="bg-base-100 border-b border-base-200 sticky top-0 z-50">
                <div className="max-w-7xl mx-auto px-4 lg:px-8">
                    <div className="flex items-center justify-between h-14">

                        {/* Logo */}
                        <Link href="/passager/dashboard" className="flex items-center gap-3 shrink-0">
                            <img src={logoSrc.src} alt="KoVoit" width={28} height={28} className="object-contain" />
                            <div className="flex items-center gap-2">
                                <span className="font-bold text-base text-base-content tracking-tight">KoVoit</span>
                                <span className="hidden sm:block text-xs text-base-content/30 font-normal border-l border-base-300 pl-2">
                                    Passager
                                </span>
                            </div>
                        </Link>

                        {/* Nav — desktop */}
                        <nav className="hidden lg:flex items-center gap-1">
                            {navItems.map((item) => (
                                <Link
                                    key={item.href}
                                    href={item.href}
                                    className={`px-3 py-1.5 rounded-lg text-sm transition-all ${isActive(item.href)
                                        ? "bg-primary text-primary-content font-medium"
                                        : "text-base-content/60 hover:text-base-content hover:bg-base-200"
                                        }`}
                                >
                                    {item.label}
                                </Link>
                            ))}

                            {/* Plus */}
                            <div className="dropdown">
                                <div
                                    tabIndex={0}
                                    role="button"
                                    className="px-3 py-1.5 rounded-lg text-sm text-base-content/60 hover:text-base-content hover:bg-base-200 cursor-pointer transition-all"
                                >
                                    Plus
                                </div>
                                <ul tabIndex={0} className="dropdown-content bg-base-100 border border-base-200 rounded-xl shadow-lg w-48 p-1 mt-1 z-50">
                                    {moreItems.map((item) => (
                                        <li key={item.href}>
                                            <Link
                                                href={item.href}
                                                className={`block px-3 py-2 rounded-lg text-sm transition-colors ${isActive(item.href)
                                                    ? "bg-primary/10 text-primary font-medium"
                                                    : "text-base-content/70 hover:bg-base-200 hover:text-base-content"
                                                    }`}
                                            >
                                                {item.label}
                                            </Link>
                                        </li>
                                    ))}
                                </ul>
                            </div>
                        </nav>

                        {/* Droite */}
                        <div className="flex items-center gap-2">

                            {/* Bouton rechercher — desktop */}
                            <Link
                                href="/passager/trajets"
                                className="hidden lg:flex btn btn-primary btn-sm rounded-full px-5"
                            >
                                Rechercher un trajet
                            </Link>

                            {/* Avatar dropdown */}
                            <div className="dropdown dropdown-end">
                                <div tabIndex={0} role="button" className="flex items-center gap-2 cursor-pointer px-2 py-1 rounded-xl hover:bg-base-200 transition-colors">
                                    <div className="w-7 h-7 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                                        {user?.photo_profil ? (
                                            <img src={getMediaUrl(user.photo_profil)} alt="profil" className="w-7 h-7 rounded-full object-cover" />
                                        ) : (
                                            <span className="text-xs font-bold text-primary">
                                                {user?.username?.[0]?.toUpperCase() || "P"}
                                            </span>
                                        )}
                                    </div>
                                    <span className="hidden sm:block text-sm font-medium text-base-content">
                                        {user?.first_name || user?.username}
                                    </span>
                                </div>
                                <ul tabIndex={0} className="dropdown-content bg-base-100 border border-base-200 rounded-xl shadow-lg w-56 p-2 mt-2 z-50">
                                    <li className="px-3 py-2 border-b border-base-200 mb-1">
                                        <p className="text-sm font-semibold text-base-content">
                                            {user?.first_name} {user?.last_name}
                                        </p>
                                        <p className="text-xs text-base-content/40">{user?.email}</p>
                                    </li>
                                    <li>
                                        <Link
                                            href="/passager/profil"
                                            className="block px-3 py-2 rounded-lg text-sm text-base-content/70 hover:bg-base-200 hover:text-base-content transition-colors"
                                        >
                                            Profil & Paramètres
                                        </Link>
                                    </li>
                                    <li>
                                        <button onClick={handleSwitchToConducteur} disabled={switching}
                                            className="w-full text-left px-3 py-2 rounded-lg text-sm text-primary hover:bg-primary/5 transition-colors flex items-center gap-2">
                                            {switching && <span className="loading loading-spinner loading-xs" />}
                                            {user?.is_driver || user?.driver_profile_id
                                                ? "Passer en mode Conducteur"
                                                : "Devenir conducteur"}
                                        </button>
                                    </li>
                                    <li className="border-t border-base-200 mt-1 pt-1">
                                        <button
                                            onClick={handleLogout}
                                            className="w-full text-left px-3 py-2 rounded-lg text-sm text-error hover:bg-error/5 transition-colors"
                                        >
                                            Déconnexion
                                        </button>
                                    </li>
                                </ul>
                            </div>

                            {/* Burger mobile */}
                            <button
                                className="btn btn-ghost btn-sm btn-square lg:hidden"
                                onClick={() => setMenuOpen(!menuOpen)}
                                aria-label="Menu"
                            >
                                <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    {menuOpen
                                        ? <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M6 18L18 6M6 6l12 12" />
                                        : <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M4 6h16M4 12h16M4 18h16" />
                                    }
                                </svg>
                            </button>
                        </div>
                    </div>
                </div>

                {/* Menu mobile */}
                {menuOpen && (
                    <div className="lg:hidden border-t border-base-200 bg-base-100">
                        <nav className="max-w-7xl mx-auto px-4 py-3 flex flex-col gap-1">
                            {[...navItems, ...moreItems].map((item) => (
                                <Link
                                    key={item.href}
                                    href={item.href}
                                    onClick={() => setMenuOpen(false)}
                                    className={`px-3 py-2.5 rounded-xl text-sm transition-colors ${isActive(item.href)
                                        ? "bg-primary text-primary-content font-medium"
                                        : "text-base-content/70 hover:bg-base-200 hover:text-base-content"
                                        }`}
                                >
                                    {item.label}
                                </Link>
                            ))}
                            <div className="border-t border-base-200 mt-2 pt-2 space-y-1">
                                <button onClick={() => { setMenuOpen(false); handleSwitchToConducteur(); }} disabled={switching}
                                    className="w-full text-left px-3 py-2.5 rounded-xl text-sm text-primary hover:bg-primary/5 flex items-center gap-2">
                                    {switching && <span className="loading loading-spinner loading-xs" />}
                                    {user?.is_driver || user?.driver_profile_id
                                        ? "Passer en mode Conducteur"
                                        : "Devenir conducteur"}
                                </button>
                                <button
                                    onClick={handleLogout}
                                    className="w-full text-left px-3 py-2.5 rounded-xl text-sm text-error hover:bg-error/5"
                                >
                                    Déconnexion
                                </button>
                            </div>
                        </nav>
                    </div>
                )}
            </header>

            {/* CONTENU */}
            <main className="max-w-7xl mx-auto px-4 lg:px-8 py-8">
                {children}
            </main>

        </div>
    );
}