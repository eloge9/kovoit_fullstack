import { useState, useEffect } from "react";
import { mesReservations, Reservation } from "../services/reservation.service";
import { rechercherTrajets, Trajet } from "../services/trajet.service";

export interface PassagerDashboardStats {
  trajetsEffectues: number;
  reservationsActives: number;
  economiesMensuelles: number;
  noteMoyenne: number;
}

export interface PointsEconomies {
  pointsAccumules: number;
  economiesTotales: number;
  trajetsCeMois: number;
  co2Economise: number;
}

export const usePassagerDashboardData = () => {
  const [reservations, setReservations] = useState<Reservation[]>([]);
  const [stats, setStats] = useState<PassagerDashboardStats>({
    trajetsEffectues: 0,
    reservationsActives: 0,
    economiesMensuelles: 0,
    noteMoyenne: 0,
  });
  const [pointsEconomies, setPointsEconomies] = useState<PointsEconomies>({
    pointsAccumules: 0,
    economiesTotales: 0,
    trajetsCeMois: 0,
    co2Economise: 0,
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchPassagerData = async () => {
    try {
      setLoading(true);
      setError(null);

      // Récupérer les réservations du passager
      const reservationsResponse = await mesReservations();
      const reservationsData = Array.isArray(reservationsResponse) ? reservationsResponse : (reservationsResponse.data || []);

      console.log("Données réservations passager:", reservationsData);
      setReservations(reservationsData);

      // Calculer les statistiques
      const currentMonth = new Date().getMonth();
      const currentYear = new Date().getFullYear();

      // Trajets effectués (réservations confirmées)
      const trajetsEffectues = reservationsData.filter(
        (res: Reservation) => res.statut === "confirmee"
      ).length;

      // Réservations actives (en attente ou confirmées)
      const reservationsActives = reservationsData.filter(
        (res: Reservation) => res.statut === "en_attente" || res.statut === "confirmee"
      ).length;

      // Économies mensuelles (estimation basée sur les trajets du mois)
      const trajetsCeMois = reservationsData.filter((res: Reservation) => {
        const resDate = new Date(res.date_reservation);
        return resDate.getMonth() === currentMonth && resDate.getFullYear() === currentYear &&
          res.statut === "confirmee";
      });

      // Économies mensuelles basées sur les réservations confirmées du mois
      const economiesMensuelles = trajetsCeMois.reduce((total: number, res: Reservation) => {
        // Économie estimée : 25% du prix (covoiturage vs transport individuel)
        return total + (res.prix_par_place * 0.25);
      }, 0);

      // Points basés sur les trajets réellement confirmés
      const pointsAccumules = trajetsEffectues * 10; // 10 points par trajet confirmé

      // Économies totales basées sur toutes les réservations confirmées
      const economiesTotales = reservationsData.reduce((total: number, res: Reservation) => {
        if (res.statut === "confirmee") {
          // Économie : 25% du prix du trajet
          return total + (res.prix_par_place * 0.25);
        }
        return total;
      }, 0);

      const trajetsCeMoisCount = trajetsCeMois.length;

      // CO2 économisé basé sur une estimation réaliste
      const co2Economise = reservationsData.reduce((total: number, res: Reservation) => {
        if (res.statut === "confirmee") {
          // Estimation CO2 : 8kg par trajet partagé (vs 16kg en voiture individuelle)
          return total + 8; // 8kg CO2 économisé par trajet
        }
        return total;
      }, 0);

      setStats({
        trajetsEffectues,
        reservationsActives,
        economiesMensuelles,
        noteMoyenne: 0, // Sera mis à jour depuis useAuth
      });

      setPointsEconomies({
        pointsAccumules,
        economiesTotales,
        trajetsCeMois: trajetsCeMoisCount,
        co2Economise,
      });

    } catch (err) {
      console.error("Erreur lors du chargement des données du dashboard passager:", err);
      setError("Impossible de charger les données du tableau de bord");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPassagerData();
  }, []);

  const refresh = () => {
    fetchPassagerData();
  };

  return {
    reservations,
    stats,
    pointsEconomies,
    loading,
    error,
    refresh,
  };
};
