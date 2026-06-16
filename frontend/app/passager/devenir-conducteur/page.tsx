"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useAuth } from "@/src/hooks/useAuth";
import { initierConducteur } from "@/src/services/auth.service";

// ── Types ──────────────────────────────────────────────────────────────────────

interface Step1 {
  numero_permis: string;
  experience_annees: string;
}

interface Step2 {
  type_vehicule: string;
  marque: string;
  modele: string;
  couleur: string;
  plaque: string;
}

const TYPE_VEHICULE_OPTIONS = [
  { value: "voiture",  label: "Voiture",  places: 4 },
  { value: "moto",     label: "Moto",     places: 1 },
  { value: "minibus",  label: "Minibus",  places: 12 },
  { value: "camion",   label: "Camion",   places: 3 },
];

// ── Composants étapes ─────────────────────────────────────────────────────────

function StepIndicator({ current, total }: { current: number; total: number }) {
  return (
    <div className="flex items-center gap-2">
      {Array.from({ length: total }, (_, i) => (
        <div key={i} className="flex items-center gap-2">
          <div className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold transition-all ${
            i + 1 < current  ? "bg-success text-white" :
            i + 1 === current ? "bg-primary text-white" :
            "bg-base-200 text-base-content/30"
          }`}>
            {i + 1 < current ? (
              <svg xmlns="http://www.w3.org/2000/svg" className="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
              </svg>
            ) : i + 1}
          </div>
          {i < total - 1 && (
            <div className={`h-0.5 w-6 rounded-full transition-all ${i + 1 < current ? "bg-success" : "bg-base-200"}`} />
          )}
        </div>
      ))}
    </div>
  );
}

// ── Page principale ───────────────────────────────────────────────────────────

export default function DevenirConducteurPage() {
  const router         = useRouter();
  const { user, updateUser } = useAuth();

  const [step,     setStep]     = useState(1);
  const [loading,  setLoading]  = useState(false);
  const [error,    setError]    = useState<string | null>(null);

  const [step1, setStep1] = useState<Step1>({ numero_permis: "", experience_annees: "0" });
  const [step2, setStep2] = useState<Step2>({ type_vehicule: "voiture", marque: "", modele: "", couleur: "", plaque: "" });

  // Rediriger si déjà conducteur ou a un profil (dans useEffect, jamais pendant le rendu)
  useEffect(() => {
    if (user && (user.is_driver || user.driver_profile_id)) {
      router.replace("/conducteur/dashboard");
    }
  }, [user, router]);

  // ── Validation ───────────────────────────────────────────────────────────
  const validateStep1 = () => {
    if (!step1.numero_permis.trim()) return "Le numéro de permis est requis.";
    return null;
  };

  const validateStep2 = () => {
    if (!step2.marque.trim())  return "La marque du véhicule est requise.";
    if (!step2.modele.trim())  return "Le modèle du véhicule est requis.";
    if (!step2.couleur.trim()) return "La couleur est requise.";
    if (!step2.plaque.trim())  return "La plaque d'immatriculation est requise.";
    return null;
  };

  const handleNext = () => {
    setError(null);
    if (step === 1) {
      const err = validateStep1();
      if (err) { setError(err); return; }
    }
    setStep(s => s + 1);
  };

  const handleSubmit = async () => {
    setError(null);
    const err = validateStep2();
    if (err) { setError(err); return; }

    setLoading(true);
    try {
      const res = await initierConducteur({
        numero_permis:     step1.numero_permis.trim(),
        experience_annees: parseInt(step1.experience_annees) || 0,
        type_vehicule:     step2.type_vehicule,
        marque:            step2.marque.trim(),
        modele:            step2.modele.trim(),
        couleur:           step2.couleur.trim(),
        plaque:            step2.plaque.trim().toUpperCase(),
      });
      // Mettre à jour le user en mémoire (role = conducteur, is_driver = true)
      if (res.utilisateur) updateUser(res.utilisateur);
      setStep(3);
    } catch (e: any) {
      const data = e?.response?.data ?? {};
      const msg  = data.error ?? data.plaque ?? data.marque ?? Object.values(data)[0] ?? "Une erreur est survenue.";
      setError(typeof msg === "string" ? msg : JSON.stringify(msg));
    } finally {
      setLoading(false);
    }
  };

  // ── Step TITLES ──────────────────────────────────────────────────────────
  const STEPS = ["Votre permis", "Votre véhicule", "Documents"];

  return (
    <div className="min-h-screen bg-base-200 flex items-start justify-center py-12 px-4">
      <div className="w-full max-w-lg space-y-6">

        {/* En-tête */}
        <div>
          <button onClick={() => router.back()} className="btn btn-ghost btn-sm gap-2 mb-4 -ml-2">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            Retour
          </button>
          <h1 className="text-2xl font-bold text-base-content">Devenir conducteur</h1>
          <p className="text-sm text-base-content/50 mt-1">
            Un compte, deux rôles. Continuez à utiliser le même email.
          </p>
        </div>

        {/* Stepper */}
        <div className="bg-base-100 rounded-2xl border border-base-200 p-5 flex items-center justify-between">
          <StepIndicator current={step} total={3} />
          <div className="text-right">
            <p className="text-xs text-base-content/40">Étape {Math.min(step, 3)} sur 3</p>
            <p className="text-sm font-semibold text-base-content">{STEPS[Math.min(step, 3) - 1]}</p>
          </div>
        </div>

        {/* Erreur */}
        {error && (
          <div className="alert alert-error rounded-xl text-sm">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            {error}
          </div>
        )}

        {/* ── ÉTAPE 1 : Permis ─────────────────────────────────────────────── */}
        {step === 1 && (
          <div className="bg-base-100 rounded-2xl border border-base-200 p-6 space-y-5">
            <div className="space-y-1">
              <h2 className="font-bold text-lg text-base-content">Informations du permis</h2>
              <p className="text-sm text-base-content/50">Ces informations seront vérifiées lors de l'analyse de vos documents.</p>
            </div>

            <div className="space-y-4">
              <div className="form-control">
                <label className="label pb-1">
                  <span className="label-text font-medium">Numéro du permis <span className="text-error">*</span></span>
                </label>
                <input
                  type="text"
                  placeholder="Ex : TG-123456-2020"
                  className="input input-bordered rounded-xl w-full"
                  value={step1.numero_permis}
                  onChange={(e) => setStep1(s => ({ ...s, numero_permis: e.target.value }))}
                />
              </div>

              <div className="form-control">
                <label className="label pb-1">
                  <span className="label-text font-medium">Années d'expérience</span>
                </label>
                <select
                  className="select select-bordered rounded-xl w-full"
                  value={step1.experience_annees}
                  onChange={(e) => setStep1(s => ({ ...s, experience_annees: e.target.value }))}
                >
                  {[0,1,2,3,4,5,6,7,8,9,10].map(n => (
                    <option key={n} value={n}>{n === 0 ? "Moins d'1 an" : `${n} an${n > 1 ? "s" : ""}`}</option>
                  ))}
                  <option value="15">Plus de 10 ans</option>
                </select>
              </div>
            </div>

            {/* Info compte unique */}
            <div className="bg-primary/5 border border-primary/20 rounded-xl p-4 flex gap-3">
              <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center shrink-0 mt-0.5">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <div className="text-sm text-base-content/70">
                <p className="font-semibold text-base-content">Compte unique</p>
                <p className="mt-0.5">Votre compte <strong>{user?.email}</strong> restera le même. Vous pourrez basculer entre passager et conducteur en 1 clic.</p>
              </div>
            </div>

            <button onClick={handleNext} className="btn btn-primary btn-block rounded-full">
              Continuer
            </button>
          </div>
        )}

        {/* ── ÉTAPE 2 : Véhicule ───────────────────────────────────────────── */}
        {step === 2 && (
          <div className="bg-base-100 rounded-2xl border border-base-200 p-6 space-y-5">
            <div className="space-y-1">
              <h2 className="font-bold text-lg text-base-content">Votre véhicule</h2>
              <p className="text-sm text-base-content/50">Informations sur le véhicule que vous utiliserez pour les trajets.</p>
            </div>

            <div className="space-y-4">
              {/* Type véhicule */}
              <div className="form-control">
                <label className="label pb-1">
                  <span className="label-text font-medium">Type de véhicule <span className="text-error">*</span></span>
                </label>
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                  {TYPE_VEHICULE_OPTIONS.map((opt) => (
                    <button
                      key={opt.value}
                      type="button"
                      onClick={() => setStep2(s => ({ ...s, type_vehicule: opt.value }))}
                      className={`rounded-xl border-2 p-3 text-center transition-all ${
                        step2.type_vehicule === opt.value
                          ? "border-primary bg-primary/10 text-primary"
                          : "border-base-200 hover:border-base-300"
                      }`}
                    >
                      <p className="text-sm font-semibold">{opt.label}</p>
                      <p className="text-xs text-base-content/40">{opt.places} place{opt.places > 1 ? "s" : ""}</p>
                    </button>
                  ))}
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="form-control">
                  <label className="label pb-1"><span className="label-text font-medium">Marque <span className="text-error">*</span></span></label>
                  <input type="text" placeholder="Toyota" className="input input-bordered rounded-xl w-full"
                    value={step2.marque} onChange={(e) => setStep2(s => ({ ...s, marque: e.target.value }))} />
                </div>
                <div className="form-control">
                  <label className="label pb-1"><span className="label-text font-medium">Modèle <span className="text-error">*</span></span></label>
                  <input type="text" placeholder="Corolla" className="input input-bordered rounded-xl w-full"
                    value={step2.modele} onChange={(e) => setStep2(s => ({ ...s, modele: e.target.value }))} />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="form-control">
                  <label className="label pb-1"><span className="label-text font-medium">Couleur <span className="text-error">*</span></span></label>
                  <input type="text" placeholder="Blanc" className="input input-bordered rounded-xl w-full"
                    value={step2.couleur} onChange={(e) => setStep2(s => ({ ...s, couleur: e.target.value }))} />
                </div>
                <div className="form-control">
                  <label className="label pb-1"><span className="label-text font-medium">Plaque <span className="text-error">*</span></span></label>
                  <input type="text" placeholder="AB-1234-TG" className="input input-bordered rounded-xl w-full uppercase"
                    value={step2.plaque} onChange={(e) => setStep2(s => ({ ...s, plaque: e.target.value.toUpperCase() }))} />
                </div>
              </div>
            </div>

            <div className="flex gap-3">
              <button onClick={() => setStep(1)} className="btn btn-ghost rounded-full border border-base-200 flex-1">
                Retour
              </button>
              <button onClick={handleSubmit} disabled={loading} className="btn btn-primary rounded-full flex-1 gap-2">
                {loading
                  ? <><span className="loading loading-spinner loading-sm" /> Création…</>
                  : "Créer mon profil"}
              </button>
            </div>
          </div>
        )}

        {/* ── ÉTAPE 3 : Documents (confirmation + redirection) ──────────────── */}
        {step === 3 && (
          <div className="bg-base-100 rounded-2xl border-2 border-success/40 p-6 sm:p-8 space-y-6">
            <div className="text-center space-y-2">
              <div className="w-16 h-16 rounded-full bg-success/15 flex items-center justify-center mx-auto">
                <svg xmlns="http://www.w3.org/2000/svg" className="h-8 w-8 text-success" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <h2 className="text-xl font-bold text-base-content">Profil conducteur créé !</h2>
              <p className="text-sm text-base-content/60">
                Votre profil et votre véhicule ont été enregistrés. Il reste une dernière étape : déposer vos documents pour que notre équipe puisse les vérifier.
              </p>
            </div>

            {/* Étapes restantes */}
            <div className="space-y-3">
              {[
                { num: "1", done: true,  label: "Profil et véhicule enregistrés" },
                { num: "2", done: false, label: "Déposer vos documents obligatoires" },
                { num: "3", done: false, label: "Vérification automatique par IA" },
                { num: "4", done: false, label: "Validation par notre équipe" },
              ].map((s) => (
                <div key={s.num} className="flex items-center gap-3">
                  <div className={`w-6 h-6 rounded-full flex items-center justify-center shrink-0 ${
                    s.done ? "bg-success" : "bg-base-200"
                  }`}>
                    {s.done ? (
                      <svg xmlns="http://www.w3.org/2000/svg" className="h-3 w-3 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
                      </svg>
                    ) : (
                      <span className="text-xs font-bold text-base-content/30">{s.num}</span>
                    )}
                  </div>
                  <span className={`text-sm ${s.done ? "text-success font-medium" : "text-base-content/70"}`}>
                    {s.label}
                  </span>
                </div>
              ))}
            </div>

            <button
              onClick={() => router.push("/conducteur/documents")}
              className="btn btn-primary btn-block rounded-full font-semibold gap-2">
              <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
              Déposer mes documents
            </button>
          </div>
        )}

      </div>
    </div>
  );
}
