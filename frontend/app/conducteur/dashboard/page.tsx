"use client";

import Link from "next/link";
import { useAuth } from "@/src/hooks/useAuth";
import { useDashboardData } from "@/src/hooks/useDashboardData";
import { useVehiculeData } from "@/src/hooks/useVehiculeData";
import { useDriverVerification } from "@/src/hooks/useDriverVerification";

// ─── Carte d'activation selon statut ─────────────────────────────────────────
function ActivationCard({ driverStatus }: { driverStatus: string }) {
    const configs: Record<string, {
        bg: string; border: string; icon: string;
        title: string; desc: string; cta: string; ctaHref: string; ctaCls: string;
        steps?: string[];
    }> = {
        DOCUMENTS_MISSING: {
            bg: "bg-gradient-to-br from-warning/10 to-warning/5",
            border: "border-warning/30",
            title: "Activez votre compte conducteur",
            desc: "Pour proposer des trajets, accepter des réservations et recevoir des paiements, vous devez d'abord faire vérifier votre identité et vos documents de véhicule.",
            cta: "Commencer la vérification",
            ctaHref: "/conducteur/verification",
            ctaCls: "btn-warning",
            steps: [
                "Téléchargez vos documents (CNI, permis, carte grise…)",
                "Notre IA vérifie vos documents automatiquement",
                "Un administrateur valide votre dossier",
                "Vous accédez à toutes les fonctionnalités",
            ],
        },
        DRAFT: {
            bg: "bg-gradient-to-br from-warning/10 to-warning/5",
            border: "border-warning/30",
            icon: "📋",
            title: "Complétez votre dossier",
            desc: "Votre dossier est en brouillon. Ajoutez tous les documents requis pour lancer la vérification.",
            cta: "Compléter mes documents",
            ctaHref: "/conducteur/documents",
            ctaCls: "btn-warning",
        },
        PENDING_AI_REVIEW: {
            bg: "bg-gradient-to-br from-info/10 to-info/5",
            border: "border-info/30",
            icon: "🤖",
            title: "Vérification IA en cours…",
            desc: "Vos documents sont en cours d'analyse par notre système d'intelligence artificielle. Cette étape prend généralement quelques minutes.",
            cta: "Suivre la vérification",
            ctaHref: "/conducteur/statut",
            ctaCls: "btn-info",
        },
        AI_APPROVED: {
            bg: "bg-gradient-to-br from-info/10 to-info/5",
            border: "border-info/30",
            icon: "✅",
            title: "Vérification IA réussie !",
            desc: "Vos documents ont été validés par notre IA. Votre dossier est maintenant en attente de validation par un administrateur.",
            cta: "Voir le statut",
            ctaHref: "/conducteur/statut",
            ctaCls: "btn-info",
        },
        AI_REJECTED: {
            bg: "bg-gradient-to-br from-error/10 to-error/5",
            border: "border-error/30",
            icon: "❌",
            title: "Vérification refusée",
            desc: "Des problèmes ont été détectés dans vos documents. Consultez le rapport détaillé pour corriger votre dossier.",
            cta: "Voir le rapport & corriger",
            ctaHref: "/conducteur/statut",
            ctaCls: "btn-error",
        },
        PENDING_ADMIN_REVIEW: {
            bg: "bg-gradient-to-br from-info/10 to-info/5",
            border: "border-info/30",
            icon: "⏳",
            title: "En attente de validation",
            desc: "Votre dossier est examiné par un administrateur. Vous recevrez une notification dès la décision.",
            cta: "Consulter le statut",
            ctaHref: "/conducteur/statut",
            ctaCls: "btn-ghost border border-base-300",
        },
        SUSPENDED: {
            bg: "bg-gradient-to-br from-warning/10 to-warning/5",
            border: "border-warning/30",
            icon: "🚫",
            title: "Compte suspendu",
            desc: "Votre compte conducteur est temporairement suspendu. Consultez le motif et contactez le support si nécessaire.",
            cta: "Voir le motif",
            ctaHref: "/conducteur/statut",
            ctaCls: "btn-warning",
        },
        BLOCKED: {
            bg: "bg-gradient-to-br from-error/10 to-error/5",
            border: "border-error/30",
            icon: "🔒",
            title: "Compte bloqué",
            desc: "Votre compte a été bloqué. Contactez le support pour plus d'informations.",
            cta: "Contacter le support",
            ctaHref: "/conducteur/statut",
            ctaCls: "btn-error",
        },
        REJECTED: {
            bg: "bg-gradient-to-br from-error/10 to-error/5",
            border: "border-error/30",
            icon: "❌",
            title: "Dossier rejeté",
            desc: "Votre dossier de vérification a été refusé. Consultez le motif et soumettez un nouveau dossier si vous pensez que c'est une erreur.",
            cta: "Voir le motif",
            ctaHref: "/conducteur/statut",
            ctaCls: "btn-error",
        },
    };

    const cfg = configs[driverStatus] ?? configs.DOCUMENTS_MISSING;

    return (
        <div className={`rounded-2xl border p-6 ${cfg.bg} ${cfg.border}`}>
            <div className="flex flex-col sm:flex-row sm:items-start gap-5">
                <div className="text-4xl shrink-0">{cfg.icon}</div>
                <div className="flex-1 min-w-0">
                    <h2 className="text-xl font-bold text-base-content">{cfg.title}</h2>
                    <p className="text-sm text-base-content/60 mt-1 leading-relaxed">{cfg.desc}</p>

                    {cfg.steps && (
                        <ol className="mt-4 space-y-1.5">
                            {cfg.steps.map((step, i) => (
                                <li key={i} className="flex items-center gap-2.5 text-sm text-base-content/70">
                                    <span className="flex items-center justify-center w-5 h-5 rounded-full bg-warning text-warning-content text-xs font-bold shrink-0">
                                        {i + 1}
                                    </span>
                                    {step}
                                </li>
                            ))}
                        </ol>
                    )}

                    <div className="mt-5 flex flex-wrap gap-3">
                        <Link href={cfg.ctaHref} className={`btn btn-sm rounded-full px-6 ${cfg.ctaCls}`}>
                            {cfg.cta}
                        </Link>
                        {driverStatus === "DOCUMENTS_MISSING" && (
                            <Link href="/conducteur/documents" className="btn btn-sm btn-ghost rounded-full border border-base-200">
                                Voir les documents requis
                            </Link>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
}

// ─── Dashboard principal ──────────────────────────────────────────────────────
export default function ConducteurDashboard() {
    const { user } = useAuth();
    const { trajets, reservations, stats, loading, error, refresh } = useDashboardData();
    const { vehiculePrincipal, loading: vehiculeLoading } = useVehiculeData();
    const { isActive, loading: verifLoading, status: verifStatus } = useDriverVerification();

    const heure = new Date().getHours();
    const salutation = heure < 12 ? "Bonjour" : heure < 18 ? "Bon après-midi" : "Bonsoir";

    const driverStatus = verifStatus?.status ?? user?.driver_status ?? "DOCUMENTS_MISSING";

    const statsData = [
        { label: "Trajets proposés", value: stats.trajetsProposes.toString(), sub: "total" },
        { label: "Réservations reçues", value: stats.reservationsEnAttente.toString(), sub: "en attente" },
        { label: "Revenus", value: `${stats.revenusMensuels.toLocaleString("fr-FR")} FCFA`, sub: "ce mois" },
        { label: "Note", value: `${(user?.note ?? 0).toFixed(1)} / 5`, sub: "moyenne" },
    ];

    const formatTrajetDate = (dateString: string) => {
        const date = new Date(dateString);
        const today = new Date();
        const tomorrow = new Date(today);
        tomorrow.setDate(today.getDate() + 1);
        if (date.toDateString() === today.toDateString())
            return `Aujourd'hui, ${date.toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" })}`;
        if (date.toDateString() === tomorrow.toDateString())
            return `Demain, ${date.toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit" })}`;
        return date.toLocaleDateString("fr-FR", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" });
    };

    const trajetsRecents = trajets
        .sort((a, b) => new Date(b.date_heure_depart).getTime() - new Date(a.date_heure_depart).getTime())
        .slice(0, 5)
        .map(trajet => ({
            id: trajet.id,
            depart: trajet.depart,
            arrivee: trajet.destination,
            date: formatTrajetDate(trajet.date_heure_depart),
            places: trajet.places_restantes,
            statut: trajet.statut === "ouvert" ? "actif" : trajet.statut === "en_cours" ? "en cours" : trajet.statut,
        }));

    return (
        <div className="space-y-8">

            {/* EN-TÊTE */}
            <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4 pb-6 border-b border-base-300">
                <div>
                    <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">
                        Tableau de bord — Conducteur
                    </p>
                    <h1 className="text-3xl font-bold text-base-content tracking-tight">
                        {salutation}, {user?.first_name || user?.username}
                    </h1>
                    <p className="text-base-content/40 mt-1 text-sm">
                        {new Date().toLocaleDateString("fr-FR", {
                            weekday: "long", day: "numeric", month: "long", year: "numeric",
                        })}
                    </p>
                </div>

                {/* Bouton "Proposer" — visible uniquement si actif */}
                {!verifLoading && (
                    isActive ? (
                        <Link href="/conducteur/trajets/create" className="btn btn-primary btn-sm rounded-full px-6 w-fit">
                            Proposer un trajet
                        </Link>
                    ) : (
                        <Link href="/conducteur/verification" className="btn btn-warning btn-sm rounded-full px-6 w-fit gap-2">
                            <span>⚠️</span>
                            Activer mon compte
                        </Link>
                    )
                )}
            </div>

            {/* CARTE D'ACTIVATION — visible si compte non actif */}
            {!verifLoading && !isActive && (
                <ActivationCard driverStatus={driverStatus} />
            )}

            {/* STATS */}
            {loading ? (
                <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                    {[1, 2, 3, 4].map((i) => (
                        <div key={i} className="bg-base-100 rounded-2xl p-6 border border-base-200 animate-pulse">
                            <div className="h-8 bg-base-300 rounded mb-2"></div>
                            <div className="h-4 bg-base-300 rounded w-3/4"></div>
                            <div className="h-3 bg-base-300 rounded w-1/2 mt-1"></div>
                        </div>
                    ))}
                </div>
            ) : error ? (
                <div className="alert alert-error">
                    <span>{error}</span>
                    <button className="btn btn-sm btn-ghost" onClick={refresh}>Réessayer</button>
                </div>
            ) : (
                <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                    {statsData.map((stat) => (
                        <div key={stat.label} className={`bg-base-100 rounded-2xl p-6 border border-base-200 ${!isActive ? "opacity-50" : ""}`}>
                            <p className="text-3xl font-bold text-base-content tracking-tight">{stat.value}</p>
                            <p className="text-sm font-medium text-base-content mt-1">{stat.label}</p>
                            <p className="text-xs text-base-content/40 mt-0.5">{stat.sub}</p>
                        </div>
                    ))}
                </div>
            )}

            {/* CONTENU PRINCIPAL */}
            <div className="grid lg:grid-cols-3 gap-6">

                {/* Trajets récents */}
                <div className="lg:col-span-2 bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                    <div className="flex items-center justify-between px-6 py-4 border-b border-base-200">
                        <p className="text-xs font-semibold text-base-content/50 uppercase tracking-widest">
                            Trajets récents
                        </p>
                        <Link href="/conducteur/trajets" className="text-xs text-primary hover:underline">
                            Voir tout
                        </Link>
                    </div>
                    <div className="divide-y divide-base-200">
                        {loading ? (
                            [1, 2, 3].map((i) => (
                                <div key={i} className="flex items-center justify-between px-6 py-4 animate-pulse">
                                    <div className="space-y-1">
                                        <div className="h-4 bg-base-300 rounded w-32"></div>
                                        <div className="h-3 bg-base-300 rounded w-24"></div>
                                    </div>
                                    <div className="flex items-center gap-3">
                                        <div className="h-3 bg-base-300 rounded w-12"></div>
                                        <div className="h-6 bg-base-300 rounded-full w-16"></div>
                                    </div>
                                </div>
                            ))
                        ) : !isActive ? (
                            <div className="px-6 py-10 text-center space-y-3">
                                <p className="text-4xl">🔒</p>
                                <p className="text-sm font-medium text-base-content">
                                    Fonctionnalité verrouillée
                                </p>
                                <p className="text-xs text-base-content/40 max-w-xs mx-auto">
                                    Activez votre compte conducteur pour proposer des trajets et voir votre activité.
                                </p>
                                <Link href="/conducteur/verification" className="btn btn-warning btn-xs rounded-full mt-1">
                                    Activer le compte
                                </Link>
                            </div>
                        ) : trajetsRecents.length > 0 ? (
                            trajetsRecents.map((trajet) => (
                                <div key={trajet.id} className="flex items-center justify-between px-6 py-4 hover:bg-base-200/40 transition-colors">
                                    <div className="space-y-0.5">
                                        <p className="font-semibold text-sm text-base-content">
                                            {trajet.depart}
                                            <span className="text-base-content/25 mx-2 font-light">→</span>
                                            {trajet.arrivee}
                                        </p>
                                        <p className="text-xs text-base-content/40">{trajet.date}</p>
                                    </div>
                                    <div className="flex items-center gap-3">
                                        <span className="text-xs text-base-content/30">
                                            {trajet.places} place{trajet.places > 1 ? "s" : ""}
                                        </span>
                                        <span className={`badge badge-sm rounded-full font-medium ${trajet.statut === "actif" || trajet.statut === "ouvert"
                                            ? "badge-success badge-outline"
                                            : trajet.statut === "en cours"
                                                ? "badge-warning badge-outline"
                                                : "badge-error badge-outline"
                                            }`}>
                                            {trajet.statut === "ouvert" ? "actif" : trajet.statut}
                                        </span>
                                    </div>
                                </div>
                            ))
                        ) : (
                            <div className="px-6 py-8 text-center">
                                <p className="text-sm text-base-content/40">Aucun trajet proposé pour le moment</p>
                                <Link href="/conducteur/trajets/create" className="btn btn-primary btn-xs rounded-full mt-3">
                                    Proposer un trajet
                                </Link>
                            </div>
                        )}
                    </div>
                </div>

                {/* Colonne droite */}
                <div className="space-y-4">

                    {/* Véhicule */}
                    <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                        <div className="px-6 py-4 border-b border-base-200">
                            <p className="text-xs font-semibold text-base-content/50 uppercase tracking-widest">
                                Mon véhicule
                            </p>
                        </div>
                        <div className="px-6 py-4">
                            {vehiculeLoading ? (
                                <div className="space-y-3 animate-pulse">
                                    {[1, 2, 3, 4].map(i => <div key={i} className="h-4 bg-base-300 rounded"></div>)}
                                </div>
                            ) : vehiculePrincipal ? (
                                <div className="space-y-3">
                                    {[
                                        { label: "Véhicule", value: `${vehiculePrincipal.marque} ${vehiculePrincipal.modele}` },
                                        { label: "Type", value: vehiculePrincipal.type_vehicule },
                                        { label: "Couleur", value: vehiculePrincipal.couleur },
                                        { label: "Plaque", value: vehiculePrincipal.plaque },
                                    ].map((item) => (
                                        <div key={item.label} className="flex justify-between items-center">
                                            <span className="text-xs text-base-content/40 uppercase tracking-wide">{item.label}</span>
                                            <span className="text-sm font-medium text-base-content">{item.value}</span>
                                        </div>
                                    ))}
                                    <div className="pt-2">
                                        <Link href="/conducteur/profil" className="btn btn-ghost btn-xs rounded-full w-full border border-base-200">
                                            Modifier
                                        </Link>
                                    </div>
                                </div>
                            ) : (
                                <div className="py-6 text-center space-y-3">
                                    <p className="text-sm text-base-content/40">Aucun véhicule renseigné</p>
                                    <Link href="/conducteur/profil" className="btn btn-primary btn-xs rounded-full">
                                        Ajouter un véhicule
                                    </Link>
                                </div>
                            )}
                        </div>
                    </div>

                    {/* Navigation */}
                    <div className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden">
                        <div className="px-6 py-4 border-b border-base-200">
                            <p className="text-xs font-semibold text-base-content/50 uppercase tracking-widest">
                                Navigation
                            </p>
                        </div>
                        <div className="divide-y divide-base-200">
                            {[
                                { href: "/conducteur/verification", label: "Vérification du compte", highlight: !isActive },
                                { href: "/conducteur/documents", label: "Mes documents", highlight: !isActive },
                                { href: "/conducteur/reservations", label: "Réservations reçues", highlight: false },
                                { href: "/conducteur/historique", label: "Historique", highlight: false },
                                { href: "/conducteur/evaluations", label: "Évaluations", highlight: false },
                                { href: "/conducteur/profil", label: "Profil & Paramètres", highlight: false },
                            ].map((item) => (
                                <Link
                                    key={item.href}
                                    href={item.href}
                                    className="flex items-center justify-between px-6 py-3 hover:bg-base-200/50 transition-colors group"
                                >
                                    <span className={`text-sm transition-colors ${item.highlight
                                        ? "text-warning font-medium group-hover:text-warning"
                                        : "text-base-content/60 group-hover:text-base-content"
                                        }`}>
                                        {item.highlight && <span className="mr-1.5">⚠️</span>}
                                        {item.label}
                                    </span>
                                    <span className="text-base-content/20 group-hover:text-base-content/50 transition-colors text-xs">→</span>
                                </Link>
                            ))}
                        </div>
                    </div>

                </div>
            </div>

        </div>
    );
}
