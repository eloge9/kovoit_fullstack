"use client";

import { useEffect, useState } from "react";
import { CalendarDays, TrendingUp, Car, DollarSign, Filter, BarChart3 } from "lucide-react";
import ChartRevenus from "./components/ChartRevenus";

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
  totalGagne: number;
  nombreTrajets: number;
  commissionPlateforme: number;
  montantNet: number;
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
    totalGagne: 0,
    nombreTrajets: 0,
    commissionPlateforme: 0,
    montantNet: 0
  });
  const [trajets, setTrajets] = useState<Trajet[]>([]);
  const [chartData, setChartData] = useState<ChartData[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    fetchEconomies();
  }, [periode]);

  const fetchEconomies = async () => {
    setLoading(true);
    try {
      const payload = {
        periode: periode,
        date_debut: periode === "personnalise" ? dateDebut : null,
        date_fin: periode === "personnalise" ? dateFin : null
      };

      // Simulation de données pour le moment
      // Remplacer par l'appel API réel quand le backend sera prêt
      setTimeout(() => {
        const mockStatistiques: Statistiques = {
          totalGagne: 1250.50,
          nombreTrajets: 15,
          commissionPlateforme: 125.05,
          montantNet: 1125.45
        };

        const mockTrajets: Trajet[] = [
          {
            id: "1",
            date: "11/05/2026",
            trajet: "Paris → Lyon",
            passager: "Jean Dupont",
            montant: 85.00,
            commission: 8.50,
            net: 76.50
          },
          {
            id: "2",
            date: "11/05/2026",
            trajet: "Lyon → Marseille",
            passager: "Marie Martin",
            montant: 65.00,
            commission: 6.50,
            net: 58.50
          },
          {
            id: "3",
            date: "12/05/2026",
            trajet: "Marseille → Nice",
            passager: "Pierre Durand",
            montant: 45.00,
            commission: 4.50,
            net: 40.50
          },
          {
            id: "4",
            date: "13/05/2026",
            trajet: "Nice → Toulon",
            passager: "Sophie Bernard",
            montant: 35.00,
            commission: 3.50,
            net: 31.50
          },
          {
            id: "5",
            date: "09/05/2026",
            trajet: "Toulon → Paris",
            passager: "Lucas Petit",
            montant: 95.00,
            commission: 9.50,
            net: 85.50
          }
        ];

        const mockChartData: ChartData[] = [
          { date: "Lun 05", revenus: 120, trajets: 2 },
          { date: "Mar 06", revenus: 85, trajets: 1 },
          { date: "Mer 07", revenus: 200, trajets: 3 },
          { date: "Jeu 08", revenus: 150, trajets: 2 },
          { date: "Ven 09", revenus: 180, trajets: 2 },
          { date: "Sam 10", revenus: 220, trajets: 3 },
          { date: "Dim 11", revenus: 295, trajets: 2 }
        ];

        setStatistiques(mockStatistiques);
        setTrajets(mockTrajets);
        setChartData(mockChartData);
        setLoading(false);
      }, 500);

      // const response = await fetch('/api/conducteur/economie', {
      //   method: 'POST',
      //   headers: { 'Content-Type': 'application/json' },
      //   body: JSON.stringify(payload)
      // });
      // const data = await response.json();
      // setStatistiques(data.statistiques);
      // setTrajets(data.trajets);
      // setChartData(data.chartData);
    } catch (error) {
      console.error('Erreur lors de la récupération des données:', error);
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
      currency: 'EUR'
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
          <p className="text-base-content/40 mt-1 text-sm">
            {trajets.length} trajet{trajets.length > 1 ? "s" : ""} au total
          </p>
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
            <span className="text-base-content/60 text-sm">Total gagné</span>
            <DollarSign className="w-4 h-4 text-green-500" />
          </div>
          <div className="text-2xl font-bold text-base-content">
            {formatMontant(statistiques.totalGagne)}
          </div>
          <div className="text-xs text-green-500 mt-1">
            +12% vs période précédente
          </div>
        </div>

        <div className="bg-base-100 rounded-xl p-6 border border-base-200">
          <div className="flex items-center justify-between mb-2">
            <span className="text-base-content/60 text-sm">Nombre de trajets</span>
            <Car className="w-4 h-4 text-blue-500" />
          </div>
          <div className="text-2xl font-bold text-base-content">
            {statistiques.nombreTrajets}
          </div>
          <div className="text-xs text-blue-500 mt-1">
            Moyenne: {formatMontant(statistiques.totalGagne / statistiques.nombreTrajets)}
          </div>
        </div>

        <div className="bg-base-100 rounded-xl p-6 border border-base-200">
          <div className="flex items-center justify-between mb-2">
            <span className="text-base-content/60 text-sm">Commission plateforme</span>
            <TrendingUp className="w-4 h-4 text-orange-500" />
          </div>
          <div className="text-2xl font-bold text-base-content">
            {formatMontant(statistiques.commissionPlateforme)}
          </div>
          <div className="text-xs text-base-content/60 mt-1">
            {((statistiques.commissionPlateforme / statistiques.totalGagne) * 100).toFixed(1)}% du total
          </div>
        </div>

        <div className="bg-base-100 rounded-xl p-6 border border-base-200">
          <div className="flex items-center justify-between mb-2">
            <span className="text-base-content/60 text-sm">Montant net reçu</span>
            <DollarSign className="w-4 h-4 text-green-600" />
          </div>
          <div className="text-2xl font-bold text-green-600">
            {formatMontant(statistiques.montantNet)}
          </div>
          <div className="text-xs text-green-500 mt-1">
            Revenu net après commission
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
