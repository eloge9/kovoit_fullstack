"use client";

import { useState } from "react";
import Link from "next/link";
import logoSrc from "@/public/logo/logo1.png";
import { usePathname, useRouter } from "next/navigation";
import { useAuth } from "@/src/hooks/useAuth";
import { useDriverVerification } from "@/src/hooks/useDriverVerification";
import { changerMode, deconnexion } from "@/src/services/auth.service";
import { getMediaUrl } from "@/src/utils/imageUtils";
import { DRIVER_STATUS_LABELS } from "@/src/services/verification.service";

const navItems = [
    { href: "/conducteur/dashboard",       label: "Tableau de bord" },
    { href: "/conducteur/trajets",         label: "Mes trajets" },
    { href: "/conducteur/reservations",    label: "Réservations" },
    { href: "/conducteur/historique",      label: "Historique" },
];

const moreItems = [
    { href: "/communication/messages",     label: "Messages" },
    { href: "/conducteur/portefeuille",    label: "Portefeuille" },
    { href: "/conducteur/economie",        label: "Économies" },
    { href: "/conducteur/evaluations",     label: "Évaluations" },
    { href: "/conducteur/profil",          label: "Profil & Paramètres" },
    { href: "/conducteur/verification",    label: "Mon compte" },
];

const STATUS_BANNER: Record<string, {
    bg: string;
    icon: string;
    text: string;
    cta: string;
    ctaHref: string;
    ctaCls: string;
}> = {
    DOCUMENTS_MISSING: {
        bg:      "bg-warning/10 border-b border-warning/30",
        icon:    "⚠️",
        text:    "Votre compte conducteur n'est pas encore activé. Envoyez vos documents pour commencer.",
        cta:     "Activer mon compte",
        ctaHref: "/conducteur/verification",
        ctaCls:  "btn-warning",
    },
    DRAFT: {
        bg:      "bg-warning/10 border-b border-warning/30",
        icon:    "📋",
        text:    "Votre dossier est en brouillon. Complétez vos documents pour activer votre compte.",
        cta:     "Compléter le dossier",
        ctaHref: "/conducteur/documents",
        ctaCls:  "btn-warning",
    },
    PENDING_AI_REVIEW: {
        bg:      "bg-info/10 border-b border-info/30",
        icon:    "🤖",
        text:    "Vos documents sont en cours de vérification par notre IA. Cela prend quelques minutes.",
        cta:     "Voir le statut",
        ctaHref: "/conducteur/statut",
        ctaCls:  "btn-info",
    },
    AI_APPROVED: {
        bg:      "bg-info/10 border-b border-info/30",
        icon:    "✅",
        text:    "Vérification IA réussie ! Votre dossier est en attente de validation par un administrateur.",
        cta:     "Voir le statut",
        ctaHref: "/conducteur/statut",
        ctaCls:  "btn-info",
    },
    AI_REJECTED: {
        bg:      "bg-error/10 border-b border-error/30",
        icon:    "❌",
        text:    "Votre dossier a été rejeté par la vérification IA. Vérifiez vos documents et recommencez.",
        cta:     "Corriger mes documents",
        ctaHref: "/conducteur/documents",
        ctaCls:  "btn-error",
    },
    PENDING_ADMIN_REVIEW: {
        bg:      "bg-info/10 border-b border-info/30",
        icon:    "⏳",
        text:    "Votre dossier est en attente de validation par un administrateur. Vous serez notifié.",
        cta:     "Voir le statut",
        ctaHref: "/conducteur/statut",
        ctaCls:  "btn-ghost",
    },
    SUSPENDED: {
        bg:      "bg-warning/10 border-b border-warning/30",
        icon:    "🚫",
        text:    "Votre compte est suspendu. Contactez le support ou consultez le motif.",
        cta:     "Voir le motif",
        ctaHref: "/conducteur/statut",
        ctaCls:  "btn-warning",
    },
    BLOCKED: {
        bg:      "bg-error/10 border-b border-error/30",
        icon:    "🔒",
        text:    "Votre compte est bloqué. Contactez le support.",
        cta:     "Contacter le support",
        ctaHref: "/conducteur/statut",
        ctaCls:  "btn-error",
    },
    REJECTED: {
        bg:      "bg-error/10 border-b border-error/30",
        icon:    "❌",
        text:    "Votre dossier a été rejeté. Vérifiez le motif et soumettez un nouveau dossier.",
        cta:     "Voir le motif",
        ctaHref: "/conducteur/statut",
        ctaCls:  "btn-error",
    },
};

// Pages où la bannière ne s'affiche pas (déjà dans le bon contexte)
const BANNER_HIDDEN_ON = [
    "/conducteur/verification",
    "/conducteur/documents",
    "/conducteur/statut",
];

export default function ConducteurLayout({ children }: { children: React.ReactNode }) {
    const pathname  = usePathname();
    const router    = useRouter();
    const { user, logout, updateUser } = useAuth();
    const [switching, setSwitching] = useState(false);

    const handleSwitchToPassager = async () => {
        setSwitching(true);
        try {
            const res = await changerMode();
            updateUser(res.utilisateur, res.tokens?.access, res.tokens?.refresh);
            router.push("/passager/dashboard");
        } catch {
            router.push("/passager/dashboard");
        } finally {
            setSwitching(false);
        }
    };
    const { isActive, loading: verifLoading, status: verifStatus } = useDriverVerification();
    const [menuOpen, setMenuOpen] = useState(false);

    const handleLogout = async () => {
        try {
            const refresh = localStorage.getItem("refresh");
            if (refresh) await deconnexion(refresh);
        } catch { }
        logout();
        router.push("/auth/connexion");
    };

    const isActive_ = (href: string) => pathname === href;

    // Bannière à afficher ?
    const driverSt      = verifStatus?.status ?? user?.driver_status ?? "DOCUMENTS_MISSING";
    const showBanner    = !verifLoading && !isActive && !BANNER_HIDDEN_ON.includes(pathname);
    const bannerConfig  = STATUS_BANNER[driverSt];

    return (
        <div data-theme="winter" className="min-h-screen bg-base-200">

            {/* NAVBAR */}
            <header className="bg-base-100 border-b border-base-200 sticky top-0 z-50">
                <div className="max-w-7xl mx-auto px-4 lg:px-8">
                    <div className="flex items-center justify-between h-14">

                        {/* Logo */}
                        <Link href="/conducteur/dashboard" className="flex items-center gap-3 shrink-0">
                            <img src={logoSrc.src} alt="KoVoit" width={28} height={28} className="object-contain" />
                            <div className="flex items-center gap-2">
                                <span className="font-bold text-base text-base-content tracking-tight">KoVoit</span>
                                <span className="hidden sm:block text-xs text-base-content/30 font-normal border-l border-base-300 pl-2">
                                    Conducteur
                                </span>
                            </div>
                        </Link>

                        {/* Nav — desktop */}
                        <nav className="hidden lg:flex items-center gap-1">
                            {navItems.map((item) => (
                                <Link
                                    key={item.href}
                                    href={item.href}
                                    className={`px-3 py-1.5 rounded-lg text-sm transition-all ${isActive_(item.href)
                                        ? "bg-primary text-primary-content font-medium"
                                        : "text-base-content/60 hover:text-base-content hover:bg-base-200"
                                        }`}
                                >
                                    {item.label}
                                </Link>
                            ))}

                            {/* Proposer — masqué si pas actif */}
                            {isActive ? (
                                <Link
                                    href="/conducteur/trajets/create"
                                    className={`px-3 py-1.5 rounded-lg text-sm transition-all ${isActive_("/conducteur/trajets/create")
                                        ? "bg-primary text-primary-content font-medium"
                                        : "text-base-content/60 hover:text-base-content hover:bg-base-200"
                                        }`}
                                >
                                    Proposer
                                </Link>
                            ) : (
                                <Link
                                    href="/conducteur/verification"
                                    className="px-3 py-1.5 rounded-lg text-sm text-warning font-medium hover:bg-warning/10 transition-all flex items-center gap-1"
                                >
                                    <span className="text-xs">⚠️</span>
                                    Activer le compte
                                </Link>
                            )}

                            {/* Plus */}
                            <div className="dropdown">
                                <div tabIndex={0} role="button" className="px-3 py-1.5 rounded-lg text-sm text-base-content/60 hover:text-base-content hover:bg-base-200 cursor-pointer transition-all">
                                    Plus
                                </div>
                                <ul tabIndex={0} className="dropdown-content bg-base-100 border border-base-200 rounded-xl shadow-lg w-48 p-1 mt-1 z-50">
                                    {moreItems.map((item) => (
                                        <li key={item.href}>
                                            <Link
                                                href={item.href}
                                                className={`block px-3 py-2 rounded-lg text-sm transition-colors ${isActive_(item.href)
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
                            <div className="dropdown dropdown-end">
                                <div tabIndex={0} role="button" className="flex items-center gap-2 cursor-pointer px-2 py-1 rounded-xl hover:bg-base-200 transition-colors">
                                    <div className="w-7 h-7 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                                        {user?.photo_profil ? (
                                            <img src={getMediaUrl(user.photo_profil)} alt="profil" className="w-7 h-7 rounded-full object-cover" />
                                        ) : (
                                            <span className="text-xs font-bold text-primary">
                                                {user?.username?.[0]?.toUpperCase() || "C"}
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
                                        {!isActive && (
                                            <p className="text-xs text-warning font-medium mt-0.5">
                                                ⚠️ Compte non activé
                                            </p>
                                        )}
                                    </li>
                                    <li>
                                        <Link href="/conducteur/profil" className="block px-3 py-2 rounded-lg text-sm text-base-content/70 hover:bg-base-200 hover:text-base-content transition-colors">
                                            Profil & Paramètres
                                        </Link>
                                    </li>
                                    <li>
                                        <Link href="/conducteur/verification" className="block px-3 py-2 rounded-lg text-sm text-base-content/70 hover:bg-base-200 hover:text-base-content transition-colors">
                                            Vérification du compte
                                        </Link>
                                    </li>
                                    <li>
                                        <button onClick={handleSwitchToPassager} disabled={switching}
                                            className="w-full text-left px-3 py-2 rounded-lg text-sm text-primary hover:bg-primary/5 transition-colors flex items-center gap-2">
                                            {switching && <span className="loading loading-spinner loading-xs" />}
                                            Utiliser comme passager
                                        </button>
                                    </li>
                                    <li className="border-t border-base-200 mt-1 pt-1">
                                        <button onClick={handleLogout} className="w-full text-left px-3 py-2 rounded-lg text-sm text-error hover:bg-error/5 transition-colors">
                                            Déconnexion
                                        </button>
                                    </li>
                                </ul>
                            </div>

                            {/* Burger mobile */}
                            <button className="btn btn-ghost btn-sm btn-square lg:hidden" onClick={() => setMenuOpen(!menuOpen)} aria-label="Menu">
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
                                    className={`px-3 py-2.5 rounded-xl text-sm transition-colors ${isActive_(item.href)
                                        ? "bg-primary text-primary-content font-medium"
                                        : "text-base-content/70 hover:bg-base-200 hover:text-base-content"
                                        }`}
                                >
                                    {item.label}
                                </Link>
                            ))}
                            {!isActive && (
                                <Link
                                    href="/conducteur/verification"
                                    onClick={() => setMenuOpen(false)}
                                    className="px-3 py-2.5 rounded-xl text-sm text-warning font-semibold hover:bg-warning/10"
                                >
                                    ⚠️ Activer mon compte conducteur
                                </Link>
                            )}
                            <div className="border-t border-base-200 mt-2 pt-2 space-y-1">
                                <button onClick={() => { setMenuOpen(false); handleSwitchToPassager(); }} disabled={switching}
                                    className="w-full text-left px-3 py-2.5 rounded-xl text-sm text-primary hover:bg-primary/5 flex items-center gap-2">
                                    {switching && <span className="loading loading-spinner loading-xs" />}
                                    Utiliser comme passager
                                </button>
                                <button onClick={handleLogout} className="w-full text-left px-3 py-2.5 rounded-xl text-sm text-error hover:bg-error/5">
                                    Déconnexion
                                </button>
                            </div>
                        </nav>
                    </div>
                )}
            </header>

            {/* BANNIÈRE D'ACTIVATION — persistante si compte non actif */}
            {showBanner && bannerConfig && (
                <div className={`${bannerConfig.bg}`}>
                    <div className="max-w-7xl mx-auto px-4 lg:px-8 py-3 flex items-center justify-between gap-4 flex-wrap">
                        <p className="text-sm text-base-content/80 flex items-center gap-2">
                            <span>{bannerConfig.icon}</span>
                            {bannerConfig.text}
                        </p>
                        <Link
                            href={bannerConfig.ctaHref}
                            className={`btn btn-sm rounded-full shrink-0 ${bannerConfig.ctaCls}`}
                        >
                            {bannerConfig.cta}
                        </Link>
                    </div>
                </div>
            )}

            {/* CONTENU */}
            <main className="max-w-7xl mx-auto px-4 lg:px-8 py-8">
                {children}
            </main>

        </div>
    );
}
