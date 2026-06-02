"use client";

import { type ReactNode } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import Image from "next/image";
import { Shield } from "lucide-react";
import { useAuth } from "@/src/hooks/useAuth";
import { deconnexion } from "@/src/services/auth.service";

const DJANGO_ADMIN_URL = process.env.NEXT_PUBLIC_DJANGO_ADMIN_URL || "http://127.0.0.1:8000/admin/";

type NavItem = {
    href: string;
    label: string;
    icon?: ReactNode;
};

const navItems: NavItem[] = [
    { href: "/admin/dashboard", label: "Tableau de bord" },
    { href: "/admin/utilisateurs", label: "Utilisateurs" },
    { href: "/admin/trajets", label: "Trajets" },
    { href: "/admin/paiements", label: "Paiements" },
    { href: "/admin/plaintes", label: "Plaintes" },
];

export default function AdminLayout({ children }: { children: React.ReactNode }) {
    const pathname = usePathname();
    const router = useRouter();
    const { user, logout } = useAuth();

    const handleLogout = async () => {
        try {
            const refresh = localStorage.getItem("refresh");
            if (refresh) await deconnexion(refresh);
        } catch { }
        logout();
        router.push("/auth/connexion");
    };

    const isActive = (href: string) => pathname === href;

    // Vérifier que l'utilisateur est admin
    if (user?.role !== "admin") {
        return (
            <div className="min-h-screen flex items-center justify-center bg-base-200">
                <div className="text-center">
                    <h1 className="text-2xl font-bold mb-4">Accès refusé</h1>
                    <p className="text-base-content/60 mb-6">Vous n&apos;avez pas les permissions pour accéder à cette zone.</p>
                    <Link href="/passager/dashboard" className="btn btn-primary rounded-xl">
                        Retourner au dashboard
                    </Link>
                </div>
            </div>
        );
    }

    return (
        <div data-theme="winter" className="min-h-screen bg-base-200">

            {/* NAVBAR */}
            <header className="bg-base-100 border-b border-base-200 sticky top-0 z-50">
                <div className="max-w-7xl mx-auto px-4 lg:px-8">
                    <div className="flex items-center justify-between h-14">

                        {/* Logo */}
                        <Link href="/admin/dashboard" className="flex items-center gap-3 shrink-0">
                            <Image src="/logo/logo1.png" alt="KoVoit" width={28} height={28} />
                            <div className="flex items-center gap-2">
                                <span className="font-bold text-base text-base-content tracking-tight">KoVoit</span>
                                <span className="hidden sm:block text-xs text-base-content/30 font-normal border-l border-base-300 pl-2">
                                    Administration
                                </span>
                            </div>
                        </Link>

                        {/* Nav — desktop */}
                        <nav className="hidden lg:flex items-center gap-1">
                            {navItems.map((item) => (
                                <Link
                                    key={item.href}
                                    href={item.href}
                                    className={`px-3 py-1.5 rounded-lg text-sm transition-all flex items-center gap-2 ${isActive(item.href)
                                        ? "bg-primary text-primary-content font-medium"
                                        : "text-base-content/60 hover:text-base-content hover:bg-base-200"
                                        }`}
                                >
                                    <span>{item.icon}</span>
                                    {item.label}
                                </Link>
                            ))}
                        </nav>

                        {/* Menu mobile */}
                        <div className="lg:hidden flex items-center gap-2">
                            <div className="dropdown dropdown-end">
                                <div tabIndex={0} role="button" className="btn btn-ghost btn-circle btn-sm">
                                    ☰
                                </div>
                                <ul tabIndex={0} className="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-52">
                                    {navItems.map((item) => (
                                        <li key={item.href}>
                                            <Link href={item.href}>
                                                {item.icon} {item.label}
                                            </Link>
                                        </li>
                                    ))}
                                    <li>
                                        <a href={DJANGO_ADMIN_URL} target="_blank" rel="noopener noreferrer" className="flex items-center gap-2">
                                            <Shield className="w-4 h-4" />
                                            Django Admin
                                        </a>
                                    </li>
                                </ul>
                            </div>
                        </div>



                        {/* User menu */}
                        <div className="dropdown dropdown-end">
                            <div tabIndex={0} role="button" className="btn btn-ghost btn-circle btn-sm">
                                👤
                            </div>
                            <ul tabIndex={0} className="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-52">
                                <li>
                                    <a className="text-xs text-base-content/60">
                                        {user?.username}
                                    </a>
                                </li>
                                <li>
                                    <a
                                        href={DJANGO_ADMIN_URL}
                                        rel="noopener noreferrer"
                                    >
                                        <Shield className="w-4 h-4" />
                                        Django Admin
                                    </a>
                                </li>
                                <li>
                                    <a onClick={handleLogout}>
                                        Déconnexion
                                    </a>
                                </li>
                            </ul>
                        </div>
                    </div>
                </div>
            </header>

            {/* CONTENU */}
            <main className="max-w-7xl mx-auto px-4 lg:px-8 py-8">
                {children}
            </main>
        </div>
    );
}
