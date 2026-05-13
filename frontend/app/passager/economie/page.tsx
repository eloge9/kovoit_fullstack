"use client";

import { useEffect, useState } from "react";
import { TrendingDown, Car, DollarSign, Filter, BarChart3, PiggyBank, Target, AlertCircle } from "lucide-react";
import ChartEconomies from "./components/ChartEconomies";
import { api } from "../../../src/services/api";
import { useAuth } from "../../../src/hooks/useAuth";
import Link from "next/link";

interface TrajetEconomie {
  reservation_id: string;
  trajet: string;
  date: string;
  distance_km: number;
  type_vehicule: string;
  places_reservees: number;
  prix_kovoit_total: number;
  prix_reference_total: number;
  economie: number;
  pourcentage_economie: number;
  reference_type: string;
}

interface StatistiquesEconomie {
  periode: string;
  total_economie: number;
  total_depense_kovoit: number;
  total_depense_reference: number;
  nombre_reservations: number;
  economie_moyenne_reservation: number;
  details_reservations: TrajetEconomie[];
}

interface ComparaisonType {
  [type: string]: {
    nombre_reservations: number;
    total_economie: number;
    total_distance: number;
    economie_moyenne: number;
  };
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
  economies: number;
  reservations: number;
}

export default function EconomiePassager() {
  const { user, token, loading: authLoading } = useAuth();
  const [periode, setPeriode] = useState("tous");
  const [dateDebut, setDateDebut] = useState("");
  const [dateFin, setDateFin] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [statistiques, setStatistiques] = useState<StatistiquesEconomie>({
    periode: "",
    total_economie: 0,
    total_depense_kovoit: 0,
    total_depense_reference: 0,
    nombre_reservations: 0,
    economie_moyenne_reservation: 0,
    details_reservations: []
  });
  const [resume, setResume] = useState<ResumeEconomie>({
    type_utilisateur: "passager",
    chiffre_principal: 0,
    libelle_chiffre: "Économies ce mois",
    evolution_mois_precedent: 0,
    nombre_operations: 0,
    moyenne_operation: 0
  });
  const [comparaisonTypes, setComparaisonTypes] = useState<{ periode: string; stats_par_type: ComparaisonType; total_general: any }>({
    periode: "",
    stats_par_type: {},
    total_general: { economie_totale: 0, nombre_total_reservations: 0 }
  });
  const [chartData, setChartData] = useState<ChartData[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (token) {
      fetchEconomies();
    }
  }, [periode, dateDebut, dateFin, token]);

  const fetchEconomies = async () => {
    if (!token) {
      setError("Veuillez vous connecter pour voir vos économies.");
      return;
    }

    setLoading(true);
    setError(null);
    try {
      // Récupérer les économies du passager
      const params = new URLSearchParams();

      if (periode === "aujourdhui") {
        const today = new Date();
        const todayStr = today.toISOString().split('T')[0];

        params.set('date_debut', todayStr);
        params.set('date_fin', todayStr);
      } else if (periode === "semaine") {
        const now = new Date();
        const dayOfWeek = now.getDay(); // 0 = Dimanche, 1 = Lundi, ...
        const diff = now.getDate() - dayOfWeek + (dayOfWeek === 0 ? -6 : 1); // Ajuster pour commencer lundi
        const monday = new Date(now.setDate(diff));
        const sunday = new Date(now.setDate(diff + 6));

        params.set('date_debut', monday.toISOString().split('T')[0]);
        params.set('date_fin', sunday.toISOString().split('T')[0]);
      } else if (periode === "mois") {
        const now = new Date();
        params.set('mois', (now.getMonth() + 1).toString());
        params.set('annee', now.getFullYear().toString());
      } else if (periode === "annee") {
        const now = new Date();
        params.set('annee', now.getFullYear().toString());
      }
      // Pour "tous", on ne filtre pas

      console.log('Appel API économies avec params:', params.toString());
      const statsData = await api(`/economie/mes_economies/?${params.toString()}`);
      console.log('Données économies reçues:', statsData);
      setStatistiques(statsData);

      // Mettre à jour le résumé
      const libelleMap = {
        tous: "Économies totales",
        aujourdhui: "Économies aujourd'hui",
        semaine: "Économies cette semaine",
        mois: "Économies ce mois",
        annee: "Économies cette année",
        personnalise: "Économies période"
      };

      setResume({
        type_utilisateur: "passager",
        chiffre_principal: statsData.total_economie || 0,
        libelle_chiffre: libelleMap[periode as keyof typeof libelleMap] || "Économies",
        evolution_mois_precedent: 0, // TODO: calculer l'évolution
        nombre_operations: statsData.nombre_reservations || 0,
        moyenne_operation: statsData.economie_moyenne_reservation || 0
      });

      // Transformer les données pour le graphique
      if (statsData.details_reservations && statsData.details_reservations.length > 0) {
        // Grouper par mois pour le graphique
        const groupedData = statsData.details_reservations.reduce((acc: any, trajet: TrajetEconomie) => {
          const date = new Date(trajet.date);
          const monthKey = date.toLocaleDateString('fr-FR', { month: 'short', year: 'numeric' });

          if (!acc[monthKey]) {
            acc[monthKey] = { month: monthKey, economies: 0, reservations: 0 };
          }

          acc[monthKey].economies += trajet.economie;
          acc[monthKey].reservations += 1;

          return acc;
        }, {});

        const chartDataTransformed = Object.values(groupedData).map((item: any) => ({
          date: item.month.split(' ')[0], // Prendre seulement le mois
          economies: item.economies,
          reservations: item.reservations
        }));

        setChartData(chartDataTransformed);
      } else {
        setChartData([]);
      }

      // Récupérer la comparaison par type de véhicule
      const comparaisonData = await api('/economie/comparaison_types_vehicule/');
      console.log('Données comparaison reçues:', comparaisonData);
      setComparaisonTypes(comparaisonData);

    } catch (error: any) {
      console.error('Erreur lors de la récupération des données économiques:', error);
      if (error.response?.status === 401) {
        setError("Session expirée. Veuillez vous reconnecter.");
      } else if (error.response?.status === 403) {
        setError("Accès refusé. Veuillez vous connecter.");
      } else if (error.response?.status >= 500) {
        setError("Serveur indisponible. Veuillez réessayer plus tard.");
      } else {
        setError("Impossible de charger vos données économiques.");
      }
      // Réinitialiser les données en cas d'erreur
      setStatistiques({
        periode: "",
        total_economie: 0,
        total_depense_kovoit: 0,
        total_depense_reference: 0,
        nombre_reservations: 0,
        economie_moyenne_reservation: 0,
        details_reservations: []
      });
      setChartData([]);
      setComparaisonTypes({
        periode: "",
        stats_par_type: {},
        total_general: { economie_totale: 0, nombre_total_reservations: 0 }
      });
    } finally {
      setLoading(false);
    }
  };

  const handleFiltrer = () => {
    if (periode === "personnalise" && dateDebut && dateFin) {
      fetchEconomies();
    }
  };

  const formatMontant = (montant: number) => {
    return new Intl.NumberFormat('fr-FR', {
      style: 'currency',
      currency: 'XOF',
      minimumFractionDigits: 0
    }).format(montant);
  };

  const getTypeVehiculeIcon = (type: string) => {
    switch (type) {
      case 'moto': return '🏍️';
      case 'voiture': return '🚗';
      case 'minibus': return '🚌';
      case 'camion': return '🚚';
      default: return '🚗';
    }
  };

  // Afficher le chargement de l'authentification
  if (authLoading) {
    return (
      <div className="flex items-center justify-center min-h-96">
        <div className="loading loading-spinner loading-lg"></div>
      </div>
    );
  }

  // Afficher l'erreur d'authentification
  if (!token) {
    return (
      <div className="flex items-center justify-center min-h-96">
        <div className="text-center space-y-4">
          <AlertCircle className="w-16 h-16 text-warning mx-auto" />
          <div>
            <h2 className="text-xl font-semibold mb-2">Connexion requise</h2>
            <p className="text-base-content/60 mb-4">Veuillez vous connecter pour voir vos économies</p>
            <Link href="/auth/connexion" className="btn btn-primary">
              Se connecter
            </Link>
          </div>
        </div>
      </div>
    );
  }

  // Afficher l'erreur de chargement des données
  if (error) {
    return (
      <div className="flex items-center justify-center min-h-96">
        <div className="text-center space-y-4">
          <AlertCircle className="w-16 h-16 text-error mx-auto" />
          <div>
            <h2 className="text-xl font-semibold mb-2">Erreur de chargement</h2>
            <p className="text-base-content/60 mb-4">{error}</p>
            <button onClick={fetchEconomies} className="btn btn-primary">
              Réessayer
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* EN-TÊTE */}
      <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4 pb-6 border-b border-base-300">
        <div>
          <p className="text-xs text-base-content/40 uppercase tracking-widest font-medium mb-1">
            Passager
          </p>
          <h1 className="text-2xl font-bold text-base-content tracking-tight">
            Mes Économies
          </h1>
          <div className="text-base-content/40 mt-1 text-sm">
            {resume.nombre_operations} réservation{resume.nombre_operations > 1 ? "s" : ""} au total
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
        {(["aujourdhui", "semaine", "mois", "annee"] as const).map((p) => (
          <button
            key={p}
            onClick={() => setPeriode(p)}
            className={`btn btn-sm rounded-full capitalize transition-all ${periode === p ? "btn-primary" : "btn-ghost border border-base-300"
              }`}
          >
            {p === "aujourdhui" ? "Aujourd'hui" : p === "semaine" ? "Cette semaine" : p === "mois" ? "Ce mois" : "Cette année"}
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
            <PiggyBank className="w-4 h-4 text-green-500" />
          </div>
          <div className="text-2xl font-bold text-green-600">
            {formatMontant(resume.chiffre_principal)}
          </div>
          <div className={`text-xs mt-1 ${resume.evolution_mois_precedent >= 0 ? "text-green-500" : "text-red-500"
            }`}>
            {resume.evolution_mois_precedent >= 0 ? "+" : ""}{resume.evolution_mois_precedent.toFixed(1)}% vs période précédente
          </div>
        </div>

        <div className="bg-base-100 rounded-xl p-6 border border-base-200">
          <div className="flex items-center justify-between mb-2">
            <span className="text-base-content/60 text-sm">Nombre de réservations</span>
            <Car className="w-4 h-4 text-blue-500" />
          </div>
          <div className="text-2xl font-bold text-base-content">
            {resume.nombre_operations}
          </div>
          <div className="text-xs text-blue-500 mt-1">
            Moyenne: {formatMontant(resume.moyenne_operation)} économisée
          </div>
        </div>

        <div className="bg-base-100 rounded-xl p-6 border border-base-200">
          <div className="flex items-center justify-between mb-2">
            <span className="text-base-content/60 text-sm">Dépenses Kovoit</span>
            <DollarSign className="w-4 h-4 text-orange-500" />
          </div>
          <div className="text-2xl font-bold text-base-content">
            {formatMontant(statistiques.total_depense_kovoit)}
          </div>
          <div className="text-xs text-base-content/60 mt-1">
            Total cette période
          </div>
        </div>

        <div className="bg-base-100 rounded-xl p-6 border border-base-200">
          <div className="flex items-center justify-between mb-2">
            <span className="text-base-content/60 text-sm">Économie moyenne</span>
            <Target className="w-4 h-4 text-green-600" />
          </div>
          <div className="text-2xl font-bold text-green-600">
            {resume.nombre_operations > 0 ?
              ((resume.chiffre_principal / resume.nombre_operations) * 100).toFixed(1) : 0}%
          </div>
          <div className="text-xs text-green-500 mt-1">
            Par rapport au taxi/Gozem
          </div>
        </div>
      </div>

      {/* Graphique des économies */}
      <div className="bg-base-100 rounded-xl border border-base-200">
        <div className="p-6 border-b border-base-200">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <BarChart3 className="w-4 h-4 text-base-content/60" />
              <h2 className="font-semibold text-base-content">Évolution des économies</h2>
            </div>
          </div>
        </div>
        <div className="p-6">
          {chartData.length > 0 ? (
            <ChartEconomies data={chartData} type="bar" />
          ) : (
            <div className="h-64 flex items-center justify-center text-base-content/60">
              Aucune donnée disponible pour cette période
            </div>
          )}
        </div>
      </div>

      {/* Comparaison par type de véhicule */}
      {Object.keys(comparaisonTypes.stats_par_type).length > 0 && (
        <div className="bg-base-100 rounded-xl border border-base-200">
          <div className="p-6 border-b border-base-200">
            <div className="flex items-center gap-2">
              <TrendingDown className="w-4 h-4 text-base-content/60" />
              <h2 className="font-semibold text-base-content">Économies par type de véhicule</h2>
            </div>
          </div>
          <div className="p-6">
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
              {Object.entries(comparaisonTypes.stats_par_type).map(([type, stats]) => (
                <div key={type} className="bg-base-200 rounded-lg p-4">
                  <div className="flex items-center gap-2 mb-2">
                    <span className="text-2xl">{getTypeVehiculeIcon(type)}</span>
                    <span className="font-medium capitalize">{type}</span>
                  </div>
                  <div className="text-lg font-bold text-green-600">
                    {formatMontant(stats.total_economie)}
                  </div>
                  <div className="text-xs text-base-content/60">
                    {stats.nombre_reservations} réservations
                  </div>
                  <div className="text-xs text-base-content/60">
                    Moyenne: {formatMontant(stats.economie_moyenne)}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* LISTE DES RÉSERVATIONS */}
      {loading ? (
        <div className="flex flex-col gap-3">
          {[1, 2, 3].map((i) => (
            <div key={i} className="bg-base-100 rounded-2xl border border-base-200 p-6 animate-pulse">
              <div className="h-4 bg-base-300 rounded w-1/3 mb-3" />
              <div className="h-3 bg-base-300 rounded w-1/2" />
            </div>
          ))}
        </div>
      ) : statistiques.details_reservations.length === 0 ? (
        <div className="bg-base-100 rounded-2xl border border-base-200 p-12 text-center">
          <p className="text-base-content/40 text-sm">
            Aucune réservation trouvée pour cette période.
          </p>
        </div>
      ) : (
        <div className="flex flex-col gap-3">
          {statistiques.details_reservations.map((trajet) => (
            <div
              key={trajet.reservation_id}
              className="bg-base-100 rounded-2xl border border-base-200 overflow-hidden hover:shadow-sm transition-shadow"
            >
              <div className="flex flex-col sm:flex-row sm:items-center justify-between px-6 py-5 gap-4">
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className="text-lg">{getTypeVehiculeIcon(trajet.type_vehicule)}</span>
                    <p className="font-semibold text-base-content">
                      {trajet.trajet}
                    </p>
                  </div>
                  <div className="flex items-center gap-4 mt-1.5 flex-wrap">
                    <p className="text-xs text-base-content/40">{trajet.date}</p>
                    <p className="text-xs text-base-content/40">
                      {trajet.distance_km} km
                    </p>
                    <p className="text-xs text-base-content/40">
                      {trajet.places_reservees} place{trajet.places_reservees > 1 ? "s" : ""}
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-4 shrink-0">
                  <div className="text-right">
                    <p className="text-xs text-base-content/40">Prix Kovoit</p>
                    <p className="text-sm font-medium text-blue-600">{formatMontant(trajet.prix_kovoit_total)}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-xs text-base-content/40">Prix {trajet.reference_type}</p>
                    <p className="text-sm font-medium text-orange-500">{formatMontant(trajet.prix_reference_total)}</p>
                  </div>
                  <div className="text-right">
                    <p className="text-xs text-base-content/40">Économie</p>
                    <p className="text-sm font-bold text-green-600">{formatMontant(trajet.economie)}</p>
                    <p className="text-xs text-green-500">
                      {trajet.pourcentage_economie ? `(${trajet.pourcentage_economie.toFixed(1)}%)` : ''}
                    </p>
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
