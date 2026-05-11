import { useState, useEffect } from "react";
import { mesVehicules, Vehicule } from "../services/trajet.service";

export const useVehiculeData = () => {
  const [vehicules, setVehicules] = useState<Vehicule[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchVehicules = async () => {
    try {
      setLoading(true);
      setError(null);
      
      const response = await mesVehicules();
      const vehiculesData = Array.isArray(response) ? response : (response.data || []);
      
      console.log("Données véhicules récupérées:", vehiculesData);
      
      setVehicules(vehiculesData);
    } catch (err) {
      console.error("Erreur lors du chargement des véhicules:", err);
      setError("Impossible de charger les informations du véhicule");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchVehicules();
  }, []);

  // Prendre le premier véhicule actif comme véhicule principal
  const vehiculePrincipal = vehicules.find(v => v.est_actif) || vehicules[0];

  return {
    vehicules,
    vehiculePrincipal,
    loading,
    error,
    refresh: fetchVehicules,
  };
};
