"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import logoSrc from "@/public/logo/logo1.png";
import { usePathname, useRouter } from "next/navigation";
import { useAuth } from "@/src/hooks/useAuth";
import { deconnexion } from "@/src/services/auth.service";
import { getMediaUrl } from "@/src/utils/imageUtils";

const NAV: Record<string, { main: { href: string; label: string }[]; more: { href: string; label: string }[] }> = {
    passager: {
        main: [
            { href: "/passager/dashboard",    label: "Tableau de bord" },
            { href: "/passager/trajets",       label: "Rechercher" },
            { href: "/passager/reservations",  label: "Réservations" },
            { href: "/passager/historique",    label: "Historique" },
        ],
        more: [
            { href: "/communication/messages", label: "Messages" },
            { href: "/passager/economie",      label: "Économies" },
            { href: "/passager/evaluations",   label: "Évaluations" },
            { href: "/passager/profil",        label: "Profil & Paramètres" },
        ],
    },
    conducteur: {
        main: [
            { href: "/conducteur/dashboard",    label: "Tableau de bord" },
            { href: "/conducteur/trajets",       label: "Mes trajets" },
            { href: "/conducteur/reservations",  label: "Réservations" },
            { href: "/conducteur/historique",    label: "Historique" },
        ],
        more: [
            { href: "/communication/messages",  label: "Messages" },
            { href: "/conducteur/economie",     label: "Économies" },
            { href: "/conducteur/evaluations",  label: "Évaluations" },
            { href: "/conducteur/profil",       label: "Profil & Paramètres" },
        ],
    },
};

export default function CommunicationLayout({ children }: { children: React.ReactNode }) {
    const pathname = usePathname();
    const router   = useRouter();
    const { user, logout } = useAuth();
    const [menuOpen, setMenuOpen] = useState(false);

    const [role, setRole] = useState<string>("passager");
    useEffect(() => {
        const r = (user?.role as string) ?? localStorage.getItem("user_role") ?? "passager";
        setRole(r);
    }, [user?.role]);
    const nav  = NAV[role] ?? NAV.passager;
    const dashHref = role === "conducteur" ? "/conducteur/dashboard" : "/passager/dashboard";
    const altHref  = role === "conducteur" ? "/passager/dashboard"   : "/conducteur/dashboard";
    const altLabel = role === "conducteur" ? "Mode Passager"         : "Mode Conducteur";

    const handleLogout = async () => {
        try {
            const refresh = localStorage.getItem("refresh");
            if (refresh) await deconnexion(refresh);
        } catch { /* ignore */ }
        logout();
        router.push("/auth/connexion");
    };

    const isActive = (href: string) => pathname === href || pathname.startsWith(href + "?");

    return (
        <div data-theme="winter" className="h-screen flex flex-col overflow-hidden bg-base-200">

            {/* ── Navbar ── */}
            <header className="bg-base-100 border-b border-base-200 sticky top-0 z-50 shrink-0">
                <div className="max-w-7xl mx-auto px-4 lg:px-8">
                    <div className="flex items-center justify-between h-14">

                        {/* Logo */}
                        <Link href={dashHref} className="flex items-center gap-3 shrink-0">
                            <img src={logoSrc.src} alt="KoVoit" width={28} height={28} className="object-contain" />
                            <div className="flex items-center gap-2">
                                <span className="font-bold text-base text-base-content tracking-tight">KoVoit</span>
                                <span className="hidden sm:block text-xs text-base-content/30 font-normal border-l border-base-300 pl-2 capitalize">
                                    {role}
                                </span>
                            </div>
                        </Link>

                        {/* Nav desktop */}
                        <nav className="hidden lg:flex items-center gap-1">
                            {nav.main.map((item) => (
                                <Link
                                    key={item.href}
                                    href={item.href}
                                    className={`px-3 py-1.5 rounded-lg text-sm transition-all ${
                                        isActive(item.href)
                                            ? "bg-primary text-primary-content font-medium"
                                            : "text-base-content/60 hover:text-base-content hover:bg-base-200"
                                    }`}
                                >
                                    {item.label}
                                </Link>
                            ))}

                            <div className="dropdown">
                                <div tabIndex={0} role="button"
                                    className="px-3 py-1.5 rounded-lg text-sm text-base-content/60 hover:text-base-content hover:bg-base-200 cursor-pointer transition-all">
                                    Plus
                                </div>
                                <ul tabIndex={0} className="dropdown-content bg-base-100 border border-base-200 rounded-xl shadow-lg w-48 p-1 mt-1 z-50">
                                    {nav.more.map((item) => (
                                        <li key={item.href}>
                                            <Link href={item.href}
                                                className={`block px-3 py-2 rounded-lg text-sm transition-colors ${
                                                    isActive(item.href)
                                                        ? "bg-primary/10 text-primary font-medium"
                                                        : "text-base-content/70 hover:bg-base-200 hover:text-base-content"
                                                }`}>
                                                {item.label}
                                            </Link>
                                        </li>
                                    ))}
                                </ul>
                            </div>
                        </nav>

                        {/* Droite */}
                        <div className="flex items-center gap-2">
                            {/* Avatar dropdown */}
                            <div className="dropdown dropdown-end">
                                <div tabIndex={0} role="button"
                                    className="flex items-center gap-2 cursor-pointer px-2 py-1 rounded-xl hover:bg-base-200 transition-colors">
                                    <div className="w-7 h-7 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                                        {user?.photo_profil ? (
                                            <img src={getMediaUrl(user.photo_profil)} alt="profil" className="w-7 h-7 rounded-full object-cover" />
                                        ) : (
                                            <span className="text-xs font-bold text-primary">
                                                {user?.username?.[0]?.toUpperCase() || "U"}
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
                                        <Link href={`/${role}/profil`}
                                            className="block px-3 py-2 rounded-lg text-sm text-base-content/70 hover:bg-base-200 hover:text-base-content transition-colors">
                                            Profil & Paramètres
                                        </Link>
                                    </li>
                                    <li>
                                        <Link href={altHref}
                                            className="block px-3 py-2 rounded-lg text-sm text-primary hover:bg-primary/5 transition-colors">
                                            {altLabel}
                                        </Link>
                                    </li>
                                    <li className="border-t border-base-200 mt-1 pt-1">
                                        <button onClick={handleLogout}
                                            className="w-full text-left px-3 py-2 rounded-lg text-sm text-error hover:bg-error/5 transition-colors">
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
                            {[...nav.main, ...nav.more].map((item) => (
                                <Link key={item.href} href={item.href}
                                    onClick={() => setMenuOpen(false)}
                                    className={`px-3 py-2.5 rounded-xl text-sm transition-colors ${
                                        isActive(item.href)
                                            ? "bg-primary text-primary-content font-medium"
                                            : "text-base-content/70 hover:bg-base-200 hover:text-base-content"
                                    }`}>
                                    {item.label}
                                </Link>
                            ))}
                            <div className="border-t border-base-200 mt-2 pt-2 space-y-1">
                                <Link href={altHref} onClick={() => setMenuOpen(false)}
                                    className="block px-3 py-2.5 rounded-xl text-sm text-primary hover:bg-primary/5">
                                    {altLabel}
                                </Link>
                                <button onClick={handleLogout}
                                    className="w-full text-left px-3 py-2.5 rounded-xl text-sm text-error hover:bg-error/5">
                                    Déconnexion
                                </button>
                            </div>
                        </nav>
                    </div>
                )}
            </header>

            {/* ── Contenu (pleine hauteur restante) ── */}
            <div className="flex-1 overflow-hidden">
                {children}
            </div>
        </div>
    );
}
