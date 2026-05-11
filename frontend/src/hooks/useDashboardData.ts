import { useState, useEffect } from "react";
import { mesTrajets, Trajet } from "../services/trajet.service";
import { reservationsRecues, Reservation } from "../services/reservation.service";

export interface DashboardStats {
  trajetsProposes: number;
  reservationsEnAttente: number;
  revenusMensuels: number;
  noteMoyenne: number;
}

export const useDashboardData = () => {
  const [trajets, setTrajets] = useState<Trajet[]>([]);
  const [reservations, setReservations] = useState<Reservation[]>([]);
  const [stats, setStats] = useState<DashboardStats>({
    trajetsProposes: 0,
    reservationsEnAttente: 0,
    revenusMensuels: 0,
    noteMoyenne: 0,
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchDashboardData = async () => {
    try {
      setLoading(true);
      setError(null);

      // Récupérer les trajets et réservations en parallèle
      const [trajetsResponse, reservationsResponse] = await Promise.all([
        mesTrajets(),
        reservationsRecues(),
      ]);

      const trajetsData = Array.isArray(trajetsResponse) ? trajetsResponse : (trajetsResponse.data || []);
      const reservationsData = Array.isArray(reservationsResponse) ? reservationsResponse : (reservationsResponse.data || []);

      console.log("Type de trajetsResponse:", typeof trajetsResponse);
      console.log("Type de trajetsData:", typeof trajetsData);
      console.log("Données trajets récupérées:", trajetsData);
      console.log("Données réservations récupérées:", reservationsData);
      console.log("Réponse complète trajets:", trajetsResponse);
      console.log("Réponse complète réservations:", reservationsResponse);

      setTrajets(trajetsData);
      setReservations(reservationsData);

      // Calculer les statistiques
      const currentMonth = new Date().getMonth();
      const currentYear = new Date().getFullYear();

      // Trajets proposés (tous les trajets)
      const totalTrajets = trajetsData;

      // Trajets du mois en cours pour les revenus
      const trajetsCeMois = trajetsData.filter((trajet: Trajet) => {
        const trajetDate = new Date(trajet.date_heure_depart);
        return trajetDate.getMonth() === currentMonth && trajetDate.getFullYear() === currentYear;
      });

      // Réservations en attente
      const reservationsEnAttente = reservationsData.filter(
        (res: Reservation) => res.statut === "en_attente"
      );

      // Revenus mensuels (estimation basée sur les trajets confirmés du mois)
      const revenusMensuels = trajetsCeMois.reduce((total: number, trajet: Trajet) => {
        const reservationsConfirmees = reservationsData.filter(
          (res: Reservation) => res.trajet_id === trajet.id && res.statut === "confirmee"
        );
        return total + (reservationsConfirmees.length * trajet.prix_par_place);
      }, 0);

      // Note moyenne (à partir du profil utilisateur)
      // Cette valeur sera mise à jour depuis le contexte user
      const noteMoyenne = 0; // Sera mis à jour depuis useAuth

      setStats({
        trajetsProposes: totalTrajets.length,
        reservationsEnAttente: reservationsEnAttente.length,
        revenusMensuels,
        noteMoyenne,
      });
    } catch (err) {
      console.error("Erreur lors du chargement des données du dashboard:", err);
      setError("Impossible de charger les données du tableau de bord");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchDashboardData();
  }, []);

  // Rafraîchir les données
  const refresh = () => {
    fetchDashboardData();
  };

  return {
    trajets,
    reservations,
    stats,
    loading,
    error,
    refresh,
  };
};
