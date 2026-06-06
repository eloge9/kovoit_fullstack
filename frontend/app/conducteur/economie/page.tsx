"use client";

import { useEffect, useState } from "react";
import { CalendarDays, TrendingUp, Car, DollarSign, Filter, BarChart3 } from "lucide-react";
import ChartRevenus from "./components/ChartRevenus";
import { api } from "../../../src/services/api";

interface Trajet {
  id: string;
  date: string;
  trajet: string;
  passager: string;
  montant: number;
  commission: number;
  net: number;
}

interface Statistiques {
  periode: string;
  total_revenus: number;
  total_trajets: number;
  total_km: number;
  revenu_moyen_trajet: number;
  revenu_moyen_mensuel: number;
  meilleur_mois: {
    mois: number;
    mois_nom: string;
    revenus: number;
    trajets: number;
  } | null;
  evolution_mensuelle: Array<{
    mois: number;
    mois_nom: string;
    revenus: number;
    trajets: number;
  }>;
  dernier_trajet: {
    id: string;
    depart: string;
    destination: string;
    date: string;
    revenu: number;
  } | null;
  note_moyenne: number;
}

interface ResumeEconomie {
  type_utilisateur: string;
  chiffre_principal: number;
  libelle_chiffre: string;
  evolution_mois_precedent: number;
  nombre_operations: number;
  moyenne_operation: number;
}

interface ChartData {
  date: string;
  revenus: number;
  trajets: number;
}

export default function EconomieConducteur() {
  const [periode, setPeriode] = useState("tous");
  const [dateDebut, setDateDebut] = useState("");
  const [dateFin, setDateFin] = useState("");
  const [statistiques, setStatistiques] = useState<Statistiques>({
    periode: "",
    total_revenus: 0,
    total_trajets: 0,
    total_km: 0,
    revenu_moyen_trajet: 0,
    revenu_moyen_mensuel: 0,
    meilleur_mois: null,
    evolution_mensuelle: [],
    dernier_trajet: null,
    note_moyenne: 0
  });
  const [resume, setResume] = useState<ResumeEconomie>({
    type_utilisateur: "conducteur",
    chiffre_principal: 0,
    libelle_chiffre: "Revenus ce mois",
    evolution_mois_precedent: 0,
    nombre_operations: 0,
    moyenne_operation: 0
  });
  const [trajets, setTrajets] = useState<Trajet[]>([]);
  const [chartData, setChartData] = useState<ChartData[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    fetchEconomies();
  }, [periode, dateDebut, dateFin]); // Ajouter les dépendances pour les filtres

  const fetchEconomies = async () => {
    setLoading(true);
    try {
      // Récupérer le résumé économique rapide
      const resumeData = await api('/statistiques/resume/');
      setResume(resumeData);

      // Récupérer les statistiques détaillées du conducteur
      const params = new URLSearchParams();

      // Convertir la période frontend vers backend
      let backendPeriode = 'mois';
      let annee = new Date().getFullYear();

      if (periode === "jour") {
        backendPeriode = 'mois';
      } else if (periode === "semaine") {
        backendPeriode = 'trimestre';
      } else if (periode === "mois") {
        backendPeriode = 'mois';
      } else if (periode === "tous") {
        backendPeriode = 'annee';
      } else if (periode === "personnalise" && dateDebut && dateFin) {
        // Pour la période personnalisée, on utilise le mois comme base mais on filtrera côté frontend
        backendPeriode = 'mois';
      }

      params.set('periode', backendPeriode);
      params.set('annee', annee.toString());

      const statsData = await api(`/statistiques/conducteur/?${params.toString()}`);
      setStatistiques(statsData);

      // Transformer les données pour le graphique
      if (statsData.evolution_mensuelle && statsData.evolution_mensuelle.length > 0) {
        const chartDataTransformed = statsData.evolution_mensuelle.map((item: any) => ({
          date: item.mois_nom.substring(0, 3), // Prendre les 3 premières lettres
          revenus: item.revenus,
          trajets: item.trajets
        }));
        setChartData(chartDataTransformed);
      } else {
        setChartData([]);
      }

      // Créer les trajets récents depuis le dernier trajet
      const trajetsRecents = [];
      if (statsData.dernier_trajet) {
        trajetsRecents.push({
          id: statsData.dernier_trajet.id,
          date: statsData.dernier_trajet.date,
          trajet: `${statsData.dernier_trajet.depart} → ${statsData.dernier_trajet.destination}`,
          passager: "Non spécifié",
          montant: statsData.dernier_trajet.revenu || 0,
          commission: (statsData.dernier_trajet.revenu || 0) * 0.1, // 10% de commission
          net: (statsData.dernier_trajet.revenu || 0) * 0.9
        });
      }
      setTrajets(trajetsRecents);

    } catch (error) {
      // Réinitialiser les données en cas d'erreur
      setStatistiques({
        periode: "",
        total_revenus: 0,
        total_trajets: 0,
        total_km: 0,
        revenu_moyen_trajet: 0,
        revenu_moyen_mensuel: 0,
        meilleur_mois: null,
        evolution_mensuelle: [],
        dernier_trajet: null,
        note_moyenne: 0
      });
      setChartData([]);
      setTrajets([]);
    } finally {
      setLoading(false);
    }
  };

  const handleFiltrer = () => {
    if (periode === "personnalise" && dateDebut && dateFin) {
      fetchEconomies();
    }
  };

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('fr-FR', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric'
    });
  };

  const formatMontant = (montant: number) => {
    return new Intl.NumberFormat('fr-FR', {
      style: 'currency',
      currency: 'XOF',
      minimumFractionDigits: 0
    }).format(montant);
  };

  return (
    <div className="space-y-8">
      {/* EN-TÊTE */}
      <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4 pb-6 border-b border-base-300">
        <div>
          <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">
            Conducteur
          </p>
          <h1 className="text-2xl font-bold text-base-content tracking-tight">
            Mes Économies
          </h1>
          <div className="text-base-content/40 mt-1 text-sm">
            {resume.nombre_operations} trajet{resume.nombre_operations > 1 ? "s" : ""} au total
          </div>
        </div>
      </div>

      {/* MINI BARRE DE NAVIGATION PÉRIODE */}
      <div className="flex gap-2 flex-wrap">
        <button
          onClick={() => setPeriode("tous")}
          className={`btn btn-sm rounded-full capitalize transition-all ${periode === "tous" ? "btn-primary" : "btn-ghost border border-base-300"
            }`}
        >
          Tous
        </button>
        {(["jour", "semaine", "mois"] as const).map((p) => (
          <button
            key={p}
            onClick={() => setPeriode(p)}
            className={`btn btn-sm rounded-full capitalize transition-all ${periode === p ? "btn-primary" : "btn-ghost border border-base-300"
              }`}
          >
            {p === "jour" ? "Aujourd'hui" : p === "semaine" ? "Cette semaine" : "Ce mois"}
          </button>
        ))}
        <button
          onClick={() => setPeriode("personnalise")}
          className={`btn btn-sm rounded-full capitalize transition-all ${periode === "personnalise" ? "btn-primary" : "btn-ghost border border-base-300"
            }`}
        >
          Personnalisé
        </button>
      </div>

      {/* FILTRES PERSONNALISÉS */}
      {periode === "personnalise" && (
        <div className="bg-base-100 rounded-xl p-6 border border-base-200">
          <div className="flex items-center gap-2 mb-4">
            <Filter className="w-4 h-4 text-base-content/60" />
            <h2 className="font-semibold text-base-content">Période personnalisée</h2>
          </div>

          <div className="flex flex-wrap gap-4">
            <input
              type="date"
              value={dateDebut}
              onChange={(e) => setDateDebut(e.target.value)}
              className="input input-bordered input-sm w-full sm:w-auto"
              placeholder="Date début"
            />
            <input
              type="date"
              value={dateFin}
              onChange={(e) => setDateFin(e.target.value)}
              className="input input-bordered input-sm w-full sm:w-auto"
              placeholder="Date fin"
            />
            <button
              onClick={handleFiltrer}
              className="btn btn-primary btn-sm"
              disabled={!dateDebut || !dateFin}
            >
              Filtrer
            </button>
          </div>
        </div>
      )}

      {/* Statistiques */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-base-100 rounded-xl p-6 border border-base-200">
          <div className="flex items-center justify-between mb-2">
            <span className="text-base-content/60 text-sm">{resume.libelle_chiffre}</span>
            <DollarSign className="w-4 h-4 text-green-500" />
          </div>
          <div className="text-2xl font-bold text-base-content">
            {formatMontant(resume.chiffre_principal)}
          </div>
          <div className={`text-xs mt-1 ${resume.evolution_mois_precedent >= 0 ? "text-green-500" : "text-red-500"
            }`}>
            {resume.evolution_mois_precedent >= 0 ? "+" : ""}{resume.evolution_mois_precedent.toFixed(1)}% vs période précédente
          </div>
        </div>

        <div className="bg-base-100 rounded-xl p-6 border border-base-200">
          <div className="flex items-center justify-between mb-2">
            <span className="text-base-content/60 text-sm">Nombre de trajets</span>
            <Car className="w-4 h-4 text-blue-500" />
          </div>
          <div className="text-2xl font-bold text-base-content">
            {resume.nombre_operations}
          </div>
          <div className="text-xs text-blue-500 mt-1">
            Moyenne: {formatMontant(resume.moyenne_operation)}
          </div>
        </div>

        <div className="bg-base-100 rounded-xl p-6 border border-base-200">
          <div className="flex items-center justify-between mb-2">
            <span className="text-base-content/60 text-sm">Distance parcourue</span>
            <TrendingUp className="w-4 h-4 text-orange-500" />
          </div>
          <div className="text-2xl font-bold text-base-content">
            {statistiques.total_km.toFixed(0)} km
          </div>
          <div className="text-xs text-base-content/60 mt-1">
            Total cette période
          </div>
        </div>

        <div className="bg-base-100 rounded-xl p-6 border border-base-200">
          <div className="flex items-center justify-between mb-2">
            <span className="text-base-content/60 text-sm">Note moyenne</span>
            <DollarSign className="w-4 h-4 text-green-600" />
          </div>
          <div className="text-2xl font-bold text-green-600">
            {statistiques.note_moyenne.toFixed(1)}/5
          </div>
          <div className="text-xs text-green-500 mt-1">
            Évaluation des passagers
          </div>
        </div>
      </div>

      {/* Graphique des revenus */}
      <div className="bg-base-100 rounded-xl border border-base-200">
        <div className="p-6 border-b border-base-200">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <BarChart3 className="w-4 h-4 text-base-content/60" />
              <h2 className="font-semibold text-base-content">Évolution des revenus</h2>
            </div>
            <div className="flex gap-2">
              <button
                className="btn btn-outline btn-xs"
                onClick={() => {/* Toggle chart type */ }}
              >
                Barres
              </button>
              <button
                className="btn btn-outline btn-xs"
                onClick={() => {/* Toggle chart type */ }}
              >
                Ligne
              </button>
            </div>
          </div>
        </div>
        <div className="p-6">
          {chartData.length > 0 ? (
            <ChartRevenus data={chartData} type="bar" />
          ) : (
            <div className="h-64 flex items-center justify-center text-base-content/60">
              Aucune donnée disponible pour cette période
            </div>
          )}
        </div>
      </div>

      {/* LISTE DES TRAJETS */}
      {loading ? (
        <div className="flex flex-col gap-3">
          {[1, 2, 3].map((i) => (
            <div key={i} className="bg-base-100 rounded-2xl border border-base-200 p-6 animate-pulse">
              <div className="h-4 bg-base-300 rounded w-1/3 mb-3" />
              <div className="h-3 bg-base-300 rounded w-1/2" />
            </div>
          ))}
        </div>
      ) : trajets.length === 0 ? (
        <div className="bg-base-100 rounded-2xl border border-base-200 p-12 text-center">
          <p className="text-base-content/40 text-sm">
            Aucun trajet trouvé pour cette période.
          </p>
        </div>
      ) : (
        <div className="flex flex-col gap-3">
          {trajets.map((trajet) => (
            <div
              key={trajet.id}
              className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden hover:shadow-sm transition-shadow"
            >
              <div className="flex flex-col sm:flex-row sm:items-center justify-between px-6 py-5 gap-4">
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    <p className="font-semibold text-base-content">
                      {trajet.trajet}
                    </p>
                  </div>
                  <div className="flex items-center gap-4 mt-1.5 flex-wrap">
                    <p className="text-xs text-base-content/40">{trajet.date}</p>
                    <p className="text-xs text-base-content/40">
                      Passager: {trajet.passager}
                    </p>
                    <p className="text-xs font-semibold text-primary">
                      {formatMontant(trajet.montant)}
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-4 shrink-0">
                  <div className="text-right">
                    <p className="text-xs text-base-content/40">Commission</p>
                    <p className="text-sm font-medium text-orange-500">{formatMontant(trajet.commission)}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-xs text-base-content/40">Net</p>
                    <p className="text-sm font-bold text-green-600">{formatMontant(trajet.net)}</p>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
