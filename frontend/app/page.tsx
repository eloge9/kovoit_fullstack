"use client";

import { useState, useEffect, useRef } from "react";
import Link from "next/link";
import Image from "next/image";

// ── Hook animation au scroll ──────────────────────────────────────────────
function useInView(threshold = 0.15) {
  const ref = useRef<HTMLDivElement>(null);
  const [inView, setInView] = useState(false);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) setInView(true); },
      { threshold }
    );
    if (ref.current) observer.observe(ref.current);
    return () => observer.disconnect();
  }, []);

  return { ref, inView };
}

// ── Données ───────────────────────────────────────────────────────────────
const trajets = [
  { depart: "Lomé", destination: "Kpalimé", prix: 2500, places: 2, date: "Aujourd'hui 08h00" },
  { depart: "Lomé", destination: "Atakpamé", prix: 3500, places: 3, date: "Aujourd'hui 10h30" },
  { depart: "Lomé", destination: "Sokodé", prix: 6500, places: 1, date: "Demain 06h00" },
  { depart: "Kpalimé", destination: "Lomé", prix: 2500, places: 4, date: "Demain 07h00" },
  { depart: "Atakpamé", destination: "Kara", prix: 4000, places: 2, date: "Demain 09h00" },
  { depart: "Lomé", destination: "Dapango", prix: 10000, places: 3, date: "07 Mar 05h30" },
];

const temoignages = [
  {
    nom: "Adjoua K.",
    role: "Passagère",
    ville: "Lomé",
    texte: "Depuis que j'utilise KoVoit pour aller à Kpalimé chaque semaine, j'économise énormément. Les conducteurs sont sérieux et ponctuels.",
  },
  {
    nom: "Koffi A.",
    role: "Conducteur",
    ville: "Atakpamé",
    texte: "Je fais Lomé–Atakpamé trois fois par semaine. KoVoit me permet de partager mes frais et de rencontrer des gens sympas.",
  },
  {
    nom: "Mawuli D.",
    role: "Passager",
    ville: "Sokodé",
    texte: "Interface simple, prix transparents, conducteurs évalués. Je ne prends plus le bus depuis que j'ai découvert KoVoit.",
  },
];

const faq = [
  {
    q: "Comment fonctionne KoVoit ?",
    r: "KoVoit met en relation des conducteurs qui font un trajet avec des passagers qui vont dans la même direction. Le conducteur propose son trajet, les passagers réservent une place, et chacun partage les frais."
  },
  {
    q: "Comment est calculé le prix ?",
    r: "Le prix est calculé automatiquement par notre système selon la distance du trajet, le coût du carburant au Togo et le nombre de places. Le conducteur ne fixe pas lui-même le prix — c'est transparent et juste pour tous."
  },
  {
    q: "Est-ce que KoVoit est sûr ?",
    r: "Tous les conducteurs sont vérifiés avec numéro de permis et informations véhicule. Chaque trajet est évalué par les passagers. Vous pouvez consulter les avis avant de réserver."
  },
  {
    q: "Je peux être conducteur ET passager ?",
    r: "Oui. Un seul compte suffit. Vous pouvez proposer un trajet quand vous conduisez, et réserver une place quand vous êtes passager — il suffit de changer de mode dans votre profil."
  },
  {
    q: "Comment payer ?",
    r: "Le paiement se fait directement entre conducteur et passager au moment du trajet. KoVoit ne prend pas de commission sur le prix — la plateforme est gratuite pour tous."
  },
];

// ── Composant FAQ item ────────────────────────────────────────────────────
function FaqItem({ q, r }: { q: string; r: string }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="border-b border-base-200 last:border-0">
      <button
        onClick={() => setOpen(!open)}
        className="w-full flex items-center justify-between py-5 text-left gap-4 group"
      >
        <span className="font-medium text-base-content group-hover:text-primary transition-colors">
          {q}
        </span>
        <span className={`text-base-content/30 transition-transform duration-300 shrink-0 ${open ? "rotate-45" : ""}`}>
          +
        </span>
      </button>
      <div className={`overflow-hidden transition-all duration-300 ${open ? "max-h-48 pb-5" : "max-h-0"}`}>
        <p className="text-sm text-base-content/60 leading-relaxed">{r}</p>
      </div>
    </div>
  );
}

// ── Page principale ───────────────────────────────────────────────────────
export default function LandingPage() {
  const hero = useInView(0.1);
  const comment = useInView(0.1);
  const avantages = useInView(0.1);
  const trajetsSec = useInView(0.1);
  const temoSec = useInView(0.1);
  const faqSec = useInView(0.1);

  // Compteur animé
  const [counts, setCounts] = useState({ trajets: 0, utilisateurs: 0, villes: 0 });
  const statsRef = useInView(0.3);

  useEffect(() => {
    if (!statsRef.inView) return;
    const targets = { trajets: 1240, utilisateurs: 3800, villes: 24 };
    const duration = 1500;
    const steps = 60;
    const interval = duration / steps;
    let step = 0;
    const timer = setInterval(() => {
      step++;
      const progress = step / steps;
      const ease = 1 - Math.pow(1 - progress, 3);
      setCounts({
        trajets: Math.round(targets.trajets * ease),
        utilisateurs: Math.round(targets.utilisateurs * ease),
        villes: Math.round(targets.villes * ease),
      });
      if (step >= steps) clearInterval(timer);
    }, interval);
    return () => clearInterval(timer);
  }, [statsRef.inView]);

  return (
    <div data-theme="winter" className="min-h-screen bg-base-100">

      {/* ── NAVBAR ─────────────────────────────────────────────── */}
      <header className="fixed top-0 left-0 right-0 z-50 bg-base-100/90 backdrop-blur-sm border-b border-base-200">
        <div className="max-w-6xl mx-auto px-4 lg:px-8 flex items-center justify-between h-14">
          <Link href="/" className="flex items-center gap-2">
            <Image src="/logo/logo1.png" alt="KoVoit" width={28} height={28} />
            <span className="font-bold text-base tracking-tight text-base-content">KoVoit</span>
          </Link>
          <nav className="hidden md:flex items-center gap-6">
            {[
              { href: "#comment", label: "Comment ça marche" },
              { href: "#trajets", label: "Trajets" },
              { href: "#faq", label: "FAQ" },
            ].map((item) => (
              <a
                key={item.href}
                href={item.href}
                className="text-sm text-base-content/60 hover:text-base-content transition-colors"
              >
                {item.label}
              </a>
            ))}
          </nav>
          <div className="flex items-center gap-2">
            <Link href="/auth/connexion" className="btn btn-ghost btn-sm rounded-full px-4 text-sm">
              Connexion
            </Link>
            <Link href="/auth/inscription" className="btn btn-primary btn-sm rounded-full px-4 text-sm">
              S'inscrire
            </Link>
          </div>
        </div>
      </header>

      {/* ── HERO ───────────────────────────────────────────────── */}
      <section className="pt-32 pb-24 px-4">
        <div
          ref={hero.ref}
          className="max-w-4xl mx-auto text-center space-y-8"
          style={{
            opacity: hero.inView ? 1 : 0,
            transform: hero.inView ? "translateY(0)" : "translateY(32px)",
            transition: "opacity 0.7s ease, transform 0.7s ease",
          }}
        >
          <div className="inline-flex items-center gap-2 bg-primary/10 text-primary text-xs font-semibold px-4 py-1.5 rounded-full">
            Covoiturage au Togo
          </div>

          <h1 className="text-5xl sm:text-6xl lg:text-7xl font-bold text-base-content tracking-tight leading-tight">
            Voyagez ensemble,
            <br />
            <span className="text-primary">dépensez moins</span>
          </h1>

          <p className="text-lg text-base-content/50 max-w-xl mx-auto leading-relaxed">
            KoVoit connecte conducteurs et passagers sur les routes du Togo.
            Partagez vos trajets, réduisez vos coûts, rencontrez des gens.
          </p>

          <div className="flex flex-col sm:flex-row items-center justify-center gap-3">
            <Link
              href="/auth/inscription"
              className="btn btn-primary rounded-full px-8 py-3 text-base font-semibold shadow-lg shadow-primary/20 hover:shadow-primary/30 transition-shadow"
            >
              Commencer gratuitement
            </Link>
            <a
              href="#comment"
              className="btn btn-ghost rounded-full px-8 py-3 text-base border border-base-300"
            >
              Comment ça marche
            </a>
          </div>

          {/* Villes populaires */}
          <div className="flex flex-wrap items-center justify-center gap-2 pt-4">
            <span className="text-xs text-base-content/30 mr-1">Trajets populaires :</span>
            {["Lomé → Kpalimé", "Lomé → Atakpamé", "Lomé → Sokodé", "Lomé → Kara"].map((t) => (
              <span
                key={t}
                className="text-xs bg-base-200 text-base-content/60 px-3 py-1 rounded-full"
              >
                {t}
              </span>
            ))}
          </div>
        </div>
      </section>

      {/* ── STATS ──────────────────────────────────────────────── */}
      <section className="py-16 bg-base-200/50">
        <div
          ref={statsRef.ref}
          className="max-w-4xl mx-auto px-4 grid grid-cols-3 gap-8 text-center"
          style={{
            opacity: statsRef.inView ? 1 : 0,
            transform: statsRef.inView ? "translateY(0)" : "translateY(24px)",
            transition: "opacity 0.6s ease, transform 0.6s ease",
          }}
        >
          {[
            { value: counts.trajets, label: "Trajets effectués", suffix: "+" },
            { value: counts.utilisateurs, label: "Utilisateurs actifs", suffix: "+" },
            { value: counts.villes, label: "Villes desservies", suffix: "" },
          ].map((stat) => (
            <div key={stat.label}>
              <p className="text-4xl font-bold text-base-content tracking-tight">
                {stat.value.toLocaleString("fr-FR")}{stat.suffix}
              </p>
              <p className="text-sm text-base-content/40 mt-1">{stat.label}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ── COMMENT ÇA MARCHE ──────────────────────────────────── */}
      <section id="comment" className="py-24 px-4">
        <div className="max-w-5xl mx-auto">
          <div
            ref={comment.ref}
            style={{
              opacity: comment.inView ? 1 : 0,
              transform: comment.inView ? "translateY(0)" : "translateY(24px)",
              transition: "opacity 0.6s ease, transform 0.6s ease",
            }}
          >
            <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium text-center mb-3">
              Simple comme bonjour
            </p>
            <h2 className="text-3xl font-bold text-base-content text-center tracking-tight mb-16">
              Comment ça marche
            </h2>

            <div className="grid md:grid-cols-3 gap-8">
              {[
                {
                  num: "01",
                  titre: "Créez votre compte",
                  desc: "Inscrivez-vous en 2 minutes. Choisissez votre rôle : passager pour réserver, conducteur pour proposer des trajets. Un seul compte pour les deux."
                },
                {
                  num: "02",
                  titre: "Trouvez ou proposez",
                  desc: "Conducteur : publiez votre trajet avec départ, destination et horaire. Le prix est calculé automatiquement. Passager : cherchez un trajet par ville et date."
                },
                {
                  num: "03",
                  titre: "Voyagez ensemble",
                  desc: "Réservez votre place en un clic. Retrouvez-vous au point de départ, voyagez ensemble et partagez les frais. Évaluez-vous mutuellement à l'arrivée."
                },
              ].map((step, i) => (
                <div
                  key={step.num}
                  className="bg-base-100 rounded-2xl border border-base-200 p-8 hover:shadow-md transition-shadow"
                  style={{
                    opacity: comment.inView ? 1 : 0,
                    transform: comment.inView ? "translateY(0)" : "translateY(32px)",
                    transition: `opacity 0.6s ease ${i * 0.15}s, transform 0.6s ease ${i * 0.15}s`,
                  }}
                >
                  <p className="text-4xl font-bold text-primary/20 mb-4">{step.num}</p>
                  <p className="font-semibold text-base-content mb-2">{step.titre}</p>
                  <p className="text-sm text-base-content/50 leading-relaxed">{step.desc}</p>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* ── AVANTAGES ──────────────────────────────────────────── */}
      <section className="py-24 px-4 bg-base-200/40">
        <div className="max-w-5xl mx-auto">
          <div
            ref={avantages.ref}
            style={{
              opacity: avantages.inView ? 1 : 0,
              transform: avantages.inView ? "translateY(0)" : "translateY(24px)",
              transition: "opacity 0.6s ease, transform 0.6s ease",
            }}
          >
            <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium text-center mb-3">
              Pourquoi KoVoit
            </p>
            <h2 className="text-3xl font-bold text-base-content text-center tracking-tight mb-16">
              Fait pour le Togo
            </h2>

            <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-5">
              {[
                {
                  titre: "Prix transparents",
                  desc: "Le prix est calculé automatiquement selon la distance. Pas de négociation, pas de surprise — conducteur et passager savent à l'avance.",
                },
                {
                  titre: "Conducteurs vérifiés",
                  desc: "Chaque conducteur fournit son numéro de permis et ses informations véhicule. Les évaluations passagers garantissent la qualité.",
                },
                {
                  titre: "Routes du Togo",
                  desc: "Conçu pour les trajets inter-villes togolais. Lomé, Kpalimé, Atakpamé, Sokodé, Kara, Dapango — toutes les routes principales couvertes.",
                },
                {
                  titre: "Un compte, deux modes",
                  desc: "Passager aujourd'hui, conducteur demain. Changez de mode depuis votre profil sans créer un second compte.",
                },
                {
                  titre: "Gratuit pour tous",
                  desc: "KoVoit ne prend pas de commission. Le prix affiché est exactement ce que le passager paie au conducteur. La plateforme est entièrement gratuite.",
                },
                {
                  titre: "Évaluations mutuelles",
                  desc: "Après chaque trajet, conducteur et passager s'évaluent. Un système de confiance qui garantit des voyages agréables pour tout le monde.",
                },
              ].map((av, i) => (
                <div
                  key={av.titre}
                  className="bg-base-100 rounded-2xl border border-base-200 p-6 hover:border-primary/30 hover:shadow-sm transition-all"
                  style={{
                    opacity: avantages.inView ? 1 : 0,
                    transform: avantages.inView ? "translateY(0)" : "translateY(24px)",
                    transition: `opacity 0.5s ease ${i * 0.1}s, transform 0.5s ease ${i * 0.1}s`,
                  }}
                >
                  <div className="w-1 h-6 bg-primary rounded-full mb-4" />
                  <p className="font-semibold text-base-content mb-2">{av.titre}</p>
                  <p className="text-sm text-base-content/50 leading-relaxed">{av.desc}</p>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* ── TRAJETS DISPONIBLES ────────────────────────────────── */}
      <section id="trajets" className="py-24 px-4">
        <div className="max-w-5xl mx-auto">
          <div
            ref={trajetsSec.ref}
            style={{
              opacity: trajetsSec.inView ? 1 : 0,
              transform: trajetsSec.inView ? "translateY(0)" : "translateY(24px)",
              transition: "opacity 0.6s ease, transform 0.6s ease",
            }}
          >
            <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium text-center mb-3">
              Trajets disponibles
            </p>
            <h2 className="text-3xl font-bold text-base-content text-center tracking-tight mb-4">
              Partez dès aujourd'hui
            </h2>
            <p className="text-base-content/40 text-center text-sm mb-16">
              Des trajets disponibles chaque jour sur les routes du Togo
            </p>

            <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-4 mb-10">
              {trajets.map((t, i) => (
                <div
                  key={i}
                  className="bg-base-100 rounded-2xl border border-base-200 p-5 hover:shadow-md hover:border-primary/20 transition-all"
                  style={{
                    opacity: trajetsSec.inView ? 1 : 0,
                    transform: trajetsSec.inView ? "translateY(0)" : "translateY(24px)",
                    transition: `opacity 0.5s ease ${i * 0.08}s, transform 0.5s ease ${i * 0.08}s`,
                  }}
                >
                  <div className="flex items-center justify-between mb-3">
                    <p className="font-semibold text-base-content text-sm">
                      {t.depart}
                      <span className="text-base-content/25 mx-2">→</span>
                      {t.destination}
                    </p>
                    <span className="badge badge-success badge-outline badge-sm rounded-full">
                      ouvert
                    </span>
                  </div>
                  <div className="flex items-center justify-between">
                    <div className="space-y-0.5">
                      <p className="text-xs text-base-content/40">{t.date}</p>
                      <p className="text-xs text-base-content/40">{t.places} place{t.places > 1 ? "s" : ""} disponible{t.places > 1 ? "s" : ""}</p>
                    </div>
                    <p className="text-lg font-bold text-primary">
                      {t.prix.toLocaleString("fr-FR")} <span className="text-xs font-normal">FCFA</span>
                    </p>
                  </div>
                </div>
              ))}
            </div>

            <div className="text-center">
              <Link
                href="/auth/inscription"
                className="btn btn-primary rounded-full px-8"
              >
                Voir tous les trajets
              </Link>
            </div>
          </div>
        </div>
      </section>

      {/* ── TÉMOIGNAGES ────────────────────────────────────────── */}
      <section className="py-24 px-4 bg-base-200/40">
        <div className="max-w-5xl mx-auto">
          <div
            ref={temoSec.ref}
            style={{
              opacity: temoSec.inView ? 1 : 0,
              transform: temoSec.inView ? "translateY(0)" : "translateY(24px)",
              transition: "opacity 0.6s ease, transform 0.6s ease",
            }}
          >
            <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium text-center mb-3">
              Ils témoignent
            </p>
            <h2 className="text-3xl font-bold text-base-content text-center tracking-tight mb-16">
              Ce qu'ils disent de KoVoit
            </h2>

            <div className="grid md:grid-cols-3 gap-6">
              {temoignages.map((t, i) => (
                <div
                  key={t.nom}
                  className="bg-base-100 rounded-2xl border border-base-200 p-6 flex flex-col gap-4"
                  style={{
                    opacity: temoSec.inView ? 1 : 0,
                    transform: temoSec.inView ? "translateY(0)" : "translateY(32px)",
                    transition: `opacity 0.6s ease ${i * 0.15}s, transform 0.6s ease ${i * 0.15}s`,
                  }}
                >
                  {/* Étoiles */}
                  <div className="flex gap-0.5">
                    {[1, 2, 3, 4, 5].map((s) => (
                      <div key={s} className="w-3 h-3 bg-warning rounded-sm" />
                    ))}
                  </div>
                  <p className="text-sm text-base-content/70 leading-relaxed flex-1">
                    "{t.texte}"
                  </p>
                  <div className="flex items-center gap-3 pt-2 border-t border-base-200">
                    <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center">
                      <span className="text-xs font-bold text-primary">
                        {t.nom[0]}
                      </span>
                    </div>
                    <div>
                      <p className="text-sm font-semibold text-base-content">{t.nom}</p>
                      <p className="text-xs text-base-content/40">{t.role} · {t.ville}</p>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* ── FAQ ────────────────────────────────────────────────── */}
      <section id="faq" className="py-24 px-4">
        <div className="max-w-2xl mx-auto">
          <div
            ref={faqSec.ref}
            style={{
              opacity: faqSec.inView ? 1 : 0,
              transform: faqSec.inView ? "translateY(0)" : "translateY(24px)",
              transition: "opacity 0.6s ease, transform 0.6s ease",
            }}
          >
            <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium text-center mb-3">
              Questions fréquentes
            </p>
            <h2 className="text-3xl font-bold text-base-content text-center tracking-tight mb-16">
              FAQ
            </h2>
            <div className="bg-base-100 rounded-2xl border border-base-200 px-8">
              {faq.map((item) => (
                <FaqItem key={item.q} q={item.q} r={item.r} />
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* ── CTA FINAL ──────────────────────────────────────────── */}
      <section className="py-24 px-4 bg-primary">
        <div className="max-w-2xl mx-auto text-center space-y-6">
          <h2 className="text-3xl font-bold text-primary-content tracking-tight">
            Prêt à covoiturer au Togo ?
          </h2>
          <p className="text-primary-content/70">
            Rejoignez des milliers d'utilisateurs qui voyagent mieux et dépensent moins grâce à KoVoit.
          </p>
          <div className="flex flex-col sm:flex-row items-center justify-center gap-3">
            <Link
              href="/auth/inscription"
              className="btn bg-white text-primary hover:bg-white/90 rounded-full px-8 border-0 font-semibold"
            >
              Créer mon compte
            </Link>
            <Link
              href="/auth/connexion"
              className="btn btn-ghost text-primary-content border border-primary-content/30 rounded-full px-8"
            >
              Se connecter
            </Link>
          </div>
        </div>
      </section>

      {/* ── FOOTER ─────────────────────────────────────────────── */}
      <footer className="bg-base-200/60 border-t border-base-200 py-12 px-4">
        <div className="max-w-5xl mx-auto">
          <div className="grid sm:grid-cols-3 gap-8 mb-10">
            <div>
              <div className="flex items-center gap-2 mb-3">
                <Image src="/logo/logo1.png" alt="KoVoit" width={24} height={24} />
                <span className="font-bold text-base-content">KoVoit</span>
              </div>
              <p className="text-sm text-base-content/40 leading-relaxed">
                La plateforme de covoiturage togolaise. Voyagez ensemble, dépensez moins.
              </p>
            </div>

            <div>
              <p className="text-xs font-semibold text-base-content/50 uppercase tracking-widest mb-4">
                Plateforme
              </p>
              <ul className="space-y-2">
                {[
                  { href: "/auth/inscription", label: "S'inscrire" },
                  { href: "/auth/connexion", label: "Se connecter" },
                  { href: "#comment", label: "Comment ça marche" },
                  { href: "#faq", label: "FAQ" },
                ].map((l) => (
                  <li key={l.label}>
                    <a href={l.href} className="text-sm text-base-content/50 hover:text-base-content transition-colors">
                      {l.label}
                    </a>
                  </li>
                ))}
              </ul>
            </div>

            <div>
              <p className="text-xs font-semibold text-base-content/50 uppercase tracking-widest mb-4">
                Trajets populaires
              </p>
              <ul className="space-y-2">
                {[
                  "Lomé → Kpalimé",
                  "Lomé → Atakpamé",
                  "Lomé → Sokodé",
                  "Lomé → Kara",
                  "Lomé → Dapango",
                ].map((t) => (
                  <li key={t}>
                    <a href="/auth/inscription" className="text-sm text-base-content/50 hover:text-base-content transition-colors">
                      {t}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          </div>

          <div className="border-t border-base-300 pt-6 flex flex-col sm:flex-row items-center justify-between gap-2">
            <p className="text-xs text-base-content/30">
              © 2026 KoVoit — Lomé, Togo
            </p>
            <p className="text-xs text-base-content/30">
              Tous droits réservés
            </p>
          </div>
        </div>
      </footer>

    </div>
  );
}