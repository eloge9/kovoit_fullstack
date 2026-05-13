import { useState, useEffect } from "react";
import { mesReservations, Reservation } from "../services/reservation.service";
import { rechercherTrajets, Trajet } from "../services/trajet.service";
import { api } from "../services/api";

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

  const fetchRealEconomies = async () => {
    try {
      const currentMonth = new Date().getMonth() + 1;
      const currentYear = new Date().getFullYear();

      const response = await api(`/economie/mes_economies/?mois=${currentMonth}&annee=${currentYear}`);
      const data = response.data || response;

      return {
        economiesMensuelles: data.total_economie || 0,
        economiesTotales: data.total_economie || 0,
        trajetsCeMois: data.nombre_reservations || 0,
      };
    } catch (err) {
      console.error('Erreur lors de la récupération des économies:', err);
      return {
        economiesMensuelles: 0,
        economiesTotales: 0,
        trajetsCeMois: 0,
      };
    }
  };

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

      // Trajets effectués (réservations confirmées ou terminées)
      const trajetsEffectues = reservationsData.filter(
        (res: Reservation) => res.statut === "confirmee" || res.statut === "terminee"
      ).length;

      // Réservations actives (en attente ou confirmées)
      const reservationsActives = reservationsData.filter(
        (res: Reservation) => res.statut === "en_attente" || res.statut === "confirmee"
      ).length;

      // Récupérer les vraies économies depuis l'API
      const realEconomies = await fetchRealEconomies();

      // Points basés sur les trajets réellement confirmés ou terminés
      const pointsAccumules = trajetsEffectues * 10; // 10 points par trajet confirmé/terminé

      // CO2 économisé basé sur une estimation réaliste (8kg par trajet partagé)
      const co2Economise = trajetsEffectues * 8;

      setStats({
        trajetsEffectues,
        reservationsActives,
        economiesMensuelles: realEconomies.economiesMensuelles,
        noteMoyenne: 0, // Sera mis à jour depuis useAuth
      });

      setPointsEconomies({
        pointsAccumules,
        economiesTotales: realEconomies.economiesTotales,
        trajetsCeMois: realEconomies.trajetsCeMois,
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
