"use client";

import { useState, useEffect, useRef } from "react";
import Link from "next/link";
import logoSrc from "@/public/logo/logo1.png";
import { usePathname, useRouter } from "next/navigation";
import { Shield } from "lucide-react";
import { useAuth } from "@/src/hooks/useAuth";
import { deconnexion } from "@/src/services/auth.service";

const DJANGO_ADMIN_URL = process.env.NEXT_PUBLIC_DJANGO_ADMIN_URL || "http://127.0.0.1:8000/admin/";

const NAV_GROUPS = [
    {
        label: "Utilisateurs",
        items: [
            { href: "/admin/utilisateurs", label: "Tous les utilisateurs" },
            { href: "/admin/conducteurs",  label: "Conducteurs" },
        ],
    },
    {
        label: "Activité",
        items: [
            { href: "/admin/trajets",      label: "Trajets" },
            { href: "/admin/reservations", label: "Réservations" },
            { href: "/admin/vehicules",    label: "Véhicules" },
        ],
    },
    {
        label: "Finance",
        items: [
            { href: "/admin/paiements",    label: "Paiements" },
            { href: "/admin/statistiques", label: "Statistiques" },
        ],
    },
    {
        label: "Modération",
        items: [
            { href: "/admin/evaluations", label: "Évaluations" },
            { href: "/admin/plaintes",    label: "Plaintes" },
            { href: "/admin/messagerie",  label: "Messagerie" },
        ],
    },
    {
        label: "Système",
        items: [
            { href: "/admin/notifications", label: "Notifications" },
            { href: "/admin/parametres",    label: "Paramètres" },
            { href: "/admin/audit",         label: "Journal d'audit" },
        ],
    },
];

// ── Sous-menu desktop géré par état React ─────────────────────────────────────
function NavGroup({ group, isActive, groupActive }: {
    group: typeof NAV_GROUPS[0];
    isActive: (href: string) => boolean;
    groupActive: (items: { href: string }[]) => boolean;
}) {
    const [open, setOpen] = useState(false);
    const ref = useRef<HTMLDivElement>(null);

    // Fermer si clic en dehors
    useEffect(() => {
        function handler(e: MouseEvent) {
            if (ref.current && !ref.current.contains(e.target as Node)) {
                setOpen(false);
            }
        }
        if (open) document.addEventListener("mousedown", handler);
        return () => document.removeEventListener("mousedown", handler);
    }, [open]);

    const active = groupActive(group.items);

    return (
        <div ref={ref} className="relative">
            <button
                onClick={() => setOpen(o => !o)}
                className={`px-3 py-1.5 rounded-lg text-sm transition-all flex items-center gap-1.5 select-none ${
                    active
                        ? "bg-primary/10 text-primary font-medium"
                        : "text-base-content/60 hover:text-base-content hover:bg-base-200"
                }`}
            >
                {group.label}
                <svg
                    className={`w-3 h-3 opacity-50 transition-transform ${open ? "rotate-180" : ""}`}
                    fill="none" viewBox="0 0 24 24" stroke="currentColor"
                >
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                </svg>
            </button>

            {open && (
                <ul className="absolute top-full left-0 mt-1.5 z-[200] bg-base-100 border border-base-200 rounded-xl shadow-lg p-1.5 w-52 min-w-max">
                    {group.items.map((item) => (
                        <li key={item.href}>
                            <Link
                                href={item.href}
                                onClick={() => setOpen(false)}
                                className={`block px-3 py-2 rounded-lg text-sm transition-colors ${
                                    isActive(item.href)
                                        ? "bg-primary text-primary-content font-medium"
                                        : "text-base-content/70 hover:bg-base-200 hover:text-base-content"
                                }`}
                            >
                                {item.label}
                            </Link>
                        </li>
                    ))}
                </ul>
            )}
        </div>
    );
}

// ── Layout principal ──────────────────────────────────────────────────────────
export default function AdminLayout({ children }: { children: React.ReactNode }) {
    const pathname = usePathname();
    const router   = useRouter();
    const { user, logout } = useAuth();
    const [mobileOpen, setMobileOpen] = useState(false);

    const handleLogout = async () => {
        try {
            const refresh = localStorage.getItem("refresh");
            if (refresh) await deconnexion(refresh);
        } catch { }
        logout();
        router.push("/auth/connexion");
    };

    const isActive    = (href: string) => pathname === href;
    const groupActive = (items: { href: string }[]) =>
        items.some(i => pathname === i.href || pathname.startsWith(i.href + "/"));

    // Fermer le menu mobile à chaque changement de page
    useEffect(() => { setMobileOpen(false); }, [pathname]);

    if (user?.role !== "admin") {
        return (
            <div className="min-h-screen flex items-center justify-center bg-base-200">
                <div className="text-center">
                    <h1 className="text-2xl font-bold mb-4">Accès refusé</h1>
                    <p className="text-base-content/60 mb-6">Vous n&apos;avez pas les permissions pour accéder à cette zone.</p>
                    <Link href="/passager/dashboard" className="btn btn-primary rounded-xl">Retourner au dashboard</Link>
                </div>
            </div>
        );
    }

    return (
        <div data-theme="winter" className="min-h-screen bg-base-200">

            {/* ── NAVBAR ── */}
            <header className="bg-base-100 border-b border-base-200 sticky top-0 z-50">
                <div className="max-w-7xl mx-auto px-4 lg:px-8">
                    <div className="flex items-center justify-between h-14 gap-4">

                        {/* Logo */}
                        <Link href="/admin/dashboard" className="flex items-center gap-2 shrink-0">
                            <img src={logoSrc.src} alt="KoVoit" width={28} height={28} className="object-contain" />
                            <span className="font-bold text-base tracking-tight">KoVoit</span>
                            <span className="hidden sm:block text-xs text-base-content/30 border-l border-base-300 pl-2">
                                Admin
                            </span>
                        </Link>

                        {/* ── Nav desktop ── */}
                        <nav className="hidden lg:flex items-center gap-0.5 flex-1">
                            <Link href="/admin/dashboard"
                                className={`px-3 py-1.5 rounded-lg text-sm transition-all ${
                                    isActive("/admin/dashboard")
                                        ? "bg-primary text-primary-content font-medium"
                                        : "text-base-content/60 hover:text-base-content hover:bg-base-200"
                                }`}>
                                Dashboard
                            </Link>

                            {NAV_GROUPS.map((group) => (
                                <NavGroup
                                    key={group.label}
                                    group={group}
                                    isActive={isActive}
                                    groupActive={groupActive}
                                />
                            ))}
                        </nav>

                        {/* ── Bouton menu mobile ── */}
                        <button
                            className="lg:hidden btn btn-ghost btn-sm rounded-lg"
                            onClick={() => setMobileOpen(o => !o)}
                        >
                            {mobileOpen ? "✕" : "☰"}
                        </button>

                        {/* ── User menu ── */}
                        <div className="hidden lg:block">
                            <div className="dropdown dropdown-end">
                                <div tabIndex={0} role="button"
                                    className="btn btn-ghost btn-sm rounded-xl gap-2 text-sm">
                                    <div className="w-6 h-6 rounded-full bg-primary/10 flex items-center justify-center text-xs font-bold text-primary">
                                        {(user?.username?.[0] || "A").toUpperCase()}
                                    </div>
                                    <span className="text-sm font-medium max-w-[100px] truncate">
                                        {user?.username}
                                    </span>
                                    <svg className="w-3 h-3 opacity-40" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                                    </svg>
                                </div>
                                <ul tabIndex={0}
                                    className="dropdown-content z-[200] menu menu-sm p-2 shadow-lg bg-base-100 border border-base-200 rounded-xl w-52">
                                    <li>
                                        <span className="text-xs text-base-content/40 pointer-events-none">{user?.email}</span>
                                    </li>
                                    <li><Link href="/admin/profile">Profil</Link></li>
                                    <li>
                                        <a href={DJANGO_ADMIN_URL} target="_blank" rel="noopener noreferrer">
                                            <Shield className="w-3.5 h-3.5" /> Django Admin
                                        </a>
                                    </li>
                                    <li className="border-t border-base-200 mt-1 pt-1">
                                        <a onClick={handleLogout} className="text-error cursor-pointer">Déconnexion</a>
                                    </li>
                                </ul>
                            </div>
                        </div>

                    </div>
                </div>

                {/* ── Menu mobile (panel sous la navbar) ── */}
                {mobileOpen && (
                    <div className="lg:hidden border-t border-base-200 bg-base-100 px-4 pb-4 max-h-[80vh] overflow-y-auto">
                        <Link href="/admin/dashboard"
                            className={`block px-3 py-2 mt-3 rounded-lg text-sm font-medium ${
                                isActive("/admin/dashboard") ? "bg-primary text-primary-content" : "text-base-content/70 hover:bg-base-200"
                            }`}>
                            Dashboard
                        </Link>

                        {NAV_GROUPS.map((group) => (
                            <div key={group.label} className="mt-4">
                                <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium px-3 mb-1">
                                    {group.label}
                                </p>
                                {group.items.map((item) => (
                                    <Link key={item.href} href={item.href}
                                        className={`block px-3 py-2 rounded-lg text-sm transition-colors ${
                                            isActive(item.href)
                                                ? "bg-primary text-primary-content font-medium"
                                                : "text-base-content/70 hover:bg-base-200"
                                        }`}>
                                        {item.label}
                                    </Link>
                                ))}
                            </div>
                        ))}

                        <div className="mt-4 pt-4 border-t border-base-200 space-y-1">
                            <Link href="/admin/profile"
                                className="block px-3 py-2 rounded-lg text-sm text-base-content/70 hover:bg-base-200">
                                Profil
                            </Link>
                            <a href={DJANGO_ADMIN_URL} target="_blank" rel="noopener noreferrer"
                                className="flex items-center gap-2 px-3 py-2 rounded-lg text-sm text-base-content/70 hover:bg-base-200">
                                <Shield className="w-3.5 h-3.5" /> Django Admin
                            </a>
                            <button onClick={handleLogout}
                                className="w-full text-left px-3 py-2 rounded-lg text-sm text-error hover:bg-error/5">
                                Déconnexion
                            </button>
                        </div>
                    </div>
                )}
            </header>

            {/* ── CONTENU ── */}
            <main className="max-w-7xl mx-auto px-4 lg:px-8 py-8">
                {children}
            </main>
        </div>
    );
}
